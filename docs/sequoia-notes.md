# macOS Sequoia (15+) Notes

Important changes and considerations for running Dayflow headless daemon on macOS Sequoia.

## Permission Changes

### New "Screen & System Audio Recording" Permission

macOS Sequoia renamed and consolidated screen capture permissions:

- **Old (macOS 14 and earlier):** "Screen Recording" under Privacy & Security
- **New (macOS 15+):** "Screen & System Audio Recording"

The permission prompt text also changed. Users may see a new prompt even if they previously granted permission on an earlier macOS version.

### SSH and Remote Access

Sequoia has stricter requirements for headless/remote screen capture:

1. **Terminal.app** must have Screen Recording permission if running daemon from Terminal
2. **SSH sessions** may require the SSH daemon to have permission
3. **Remote Desktop** apps need their own permission entries

**Workaround for remote deployment:**
```bash
# Grant permission via MDM profile or:
# 1. Connect via Screen Sharing (once)
# 2. Grant permission in System Settings
# 3. Then SSH works for subsequent sessions
```

## ScreenCaptureKit Changes

### Async API Updates

Sequoia's ScreenCaptureKit uses Swift's modern async/await patterns exclusively. The daemon handles this with:

```swift
let content = try await SCShareableContent.excludingDesktopWindows(
    false,
    onScreenWindowsOnly: true
)
```

### Permission Check Behavior

On Sequoia, `SCShareableContent` queries return empty results (not errors) when permission is denied. The daemon detects this:

```swift
if content.displays.isEmpty {
    // Permission likely not granted
    delegate?.permissionRevoked()
}
```

## Energy Efficiency

### App Nap Resistance

Sequoia's App Nap is more aggressive. The daemon uses `ProcessInfo` assertions to prevent napping during active capture:

```swift
ProcessInfo.processInfo.beginActivity(
    options: [.userInitiated, .idleSystemSleepDisabled],
    reason: "Screen capture in progress"
)
```

### Low Power Mode

When Low Power Mode is enabled, the daemon automatically:
- Reduces capture FPS to 0.5
- Increases analysis batch interval to 30 minutes
- Logs a warning about degraded mode

## Notarization Requirements

### Hardened Runtime

Sequoia requires notarized apps for Gatekeeper approval. The daemon must be built with:

```bash
swift build -c release \
  --product dayflow-headless \
  -Xswiftc -enable-library-evolution
```

And signed:
```bash
codesign --sign "Developer ID" \
  --options runtime \
  --entitlements entitlements.plist \
  .build/release/dayflow-headless
```

### Entitlements

Required entitlements for headless operation:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

## Version Detection

The daemon detects Sequoia and adjusts behavior:

```swift
let version = ProcessInfo.processInfo.operatingSystemVersion
let isSequoia = version.majorVersion >= 15

if isSequoia {
    // Use Sequoia-specific code paths
}
```

## Known Issues

### Issue: Permission prompt doesn't appear

**Symptom:** Daemon runs but captures blank, no permission prompt shown.

**Cause:** Sequoia requires user interaction to trigger the prompt.

**Workaround:** Run once from Terminal manually, then approve when prompted.

### Issue: Capture stops after wake from sleep

**Symptom:** After machine wakes, capture produces blank frames.

**Status:** Under investigation. Current workaround: restart daemon after wake.

### Issue: Multiple display capture

**Symptom:** Only primary display captured on multi-monitor setups.

**Note:** This is expected behavior in headless mode. The daemon captures the primary display only to reduce resource usage.

## Migration from Monterey/Ventura

If upgrading from macOS 13/14 to 15:

1. **Re-grant permissions** - Sequoia may reset screen recording permission
2. **Update config** - No config changes required, but verify paths
3. **Rebuild daemon** - Recompile against Sequoia SDK for best compatibility:
   ```bash
   swift build -c release
   ```

## Testing on Sequoia

Run the Sequoia-specific test:

```bash
swift test --filter testSequoiaDetectionReturnsCorrectValue
```

Expected behavior:
- On macOS 15+: `isRunningOnSequoia() == true`
- On macOS 14 and earlier: `isRunningOnSequoia() == false`

## References

- [Apple: What's new in ScreenCaptureKit](https://developer.apple.com/videos/play/wwdc2024/10107/)
- [Apple: Screen Recording permission](https://support.apple.com/guide/mac-help/mchld6aa7d23/mac)
- [Dayflow Troubleshooting](troubleshooting.md)
