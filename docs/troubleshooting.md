# Troubleshooting

Common issues and solutions for the Dayflow headless daemon.

## Permission Issues

### "Screen recording permission not granted"

**Symptoms:**
- Daemon starts but captures blank frames
- Log shows `ERROR: Screen capture permission denied`

**Solution:**
1. Open **System Settings** → **Privacy & Security** → **Screen & System Audio Recording**
2. Click the **+** button and add `/usr/local/bin/dayflow-headless`
3. Toggle the checkbox to enable
4. Restart the daemon:
   ```bash
   launchctl stop com.dayflow.headless
   launchctl start com.dayflow.headless
   ```

**Note:** On macOS Sequoia (15+), you may need to grant permission to Terminal.app or your SSH client if running remotely.

### Permission revoked after update

If you rebuild and reinstall the daemon, macOS may revoke permissions because the binary signature changed.

**Solution:**
1. Remove the old entry from Screen Recording permissions
2. Add the new binary path
3. Restart the daemon

## Webhook Issues

### "Connection refused" or timeout errors

**Symptoms:**
- Log shows `ERROR: Webhook failed: Connection refused`
- Payloads accumulating in queue

**Diagnosis:**
```bash
# Test webhook endpoint
curl -X POST -H "Content-Type: application/json" \
  -d '{"test": true}' \
  https://your-webhook-endpoint.com/dayflow

# Check queue size
ls -la ~/.local/share/dayflow/queue/
```

**Solutions:**
1. Verify the webhook URL is correct in config
2. Check network connectivity
3. Verify the endpoint is accepting POST requests
4. Check for firewall rules blocking outbound connections

### "401 Unauthorized" errors

**Symptoms:**
- Log shows `ERROR: Webhook returned 401`

**Solutions:**
1. Verify `Authorization` header in config matches expected token
2. Check if the token has expired
3. Ensure header format is correct (e.g., `Bearer TOKEN` vs just `TOKEN`)

### Payloads stuck in queue

**Symptoms:**
- Queue directory has many `.json` files
- Webhook endpoint is working

**Solution:**
```bash
# Force retry queued payloads
kill -HUP $(pgrep dayflow-headless)

# Or manually clear (data loss):
rm ~/.local/share/dayflow/queue/*.json
```

## API Issues

### "Invalid API key" from Gemini

**Symptoms:**
- Log shows `ERROR: Gemini API returned 403`
- Analysis batches failing

**Solutions:**
1. Verify API key in config or `GEMINI_API_KEY` environment variable
2. Check API key permissions at [Google AI Studio](https://aistudio.google.com/apikey)
3. Ensure the key hasn't been revoked or rate-limited

### Rate limiting

**Symptoms:**
- Intermittent `429 Too Many Requests` errors
- Some analysis batches failing

**Solutions:**
1. Increase `analysis.batchIntervalMinutes` to reduce API calls
2. Check your Gemini API quota
3. Consider upgrading to a paid tier for higher limits

## Database Issues

### "Database is locked"

**Symptoms:**
- Log shows `ERROR: SQLite database is locked`
- Operations failing intermittently

**Solutions:**
1. Ensure only one daemon instance is running:
   ```bash
   pgrep -l dayflow-headless
   # Should show only one process
   ```
2. Enable WAL mode in config:
   ```json
   "database": { "walMode": true }
   ```
3. Check for stale lock files:
   ```bash
   ls -la ~/Library/Application\ Support/Dayflow/*.sqlite*
   # Remove -wal and -shm files if daemon is stopped
   ```

### Database corruption

**Symptoms:**
- `ERROR: malformed database schema`
- Daemon crashes on startup

**Solution:**
```bash
# Stop daemon
launchctl stop com.dayflow.headless

# Backup and reset database
cd ~/Library/Application\ Support/Dayflow/
mv chunks.sqlite chunks.sqlite.backup
mv chunks.sqlite-wal chunks.sqlite-wal.backup 2>/dev/null
mv chunks.sqlite-shm chunks.sqlite-shm.backup 2>/dev/null

# Restart - will create fresh database
launchctl start com.dayflow.headless
```

## Launch Agent Issues

### Daemon not starting on boot

**Symptoms:**
- Daemon doesn't run after reboot
- `launchctl list | grep dayflow` shows no results

**Solutions:**
1. Verify plist is in correct location:
   ```bash
   ls -la ~/Library/LaunchAgents/com.dayflow.headless.plist
   ```
2. Load the agent:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.dayflow.headless.plist
   ```
3. Check plist syntax:
   ```bash
   plutil -lint ~/Library/LaunchAgents/com.dayflow.headless.plist
   ```

### Daemon keeps restarting

**Symptoms:**
- Log shows repeated startup messages
- High CPU from constant restarts

**Diagnosis:**
```bash
# Check exit codes
launchctl list | grep dayflow
# Non-zero exit code indicates crash

# Check recent logs
tail -100 /tmp/dayflow-headless.log | grep -i error
```

**Common causes:**
1. Invalid config file (JSON syntax error)
2. Missing required config values
3. Permission issues on startup

## Performance Issues

### High CPU usage

**Symptoms:**
- `dayflow-headless` using >10% CPU
- System feels sluggish

**Solutions:**
1. Reduce capture FPS:
   ```json
   "recording": { "fps": 1, "resolution": "low" }
   ```
2. Increase analysis interval:
   ```json
   "analysis": { "batchIntervalMinutes": 30 }
   ```

### High memory usage

**Symptoms:**
- Memory usage growing over time
- Eventually crashes with OOM

**Solutions:**
1. Restart daemon periodically (memory leak mitigation)
2. Report issue with memory profile if consistent

## Log Analysis

### Enable verbose logging

```bash
# Set environment variable before starting
export DAYFLOW_LOG_LEVEL=DEBUG
dayflow-headless
```

### Common log patterns

| Pattern | Meaning |
|---------|---------|
| `INFO: Capture started` | Normal startup |
| `INFO: Analysis batch complete` | Successful AI analysis |
| `WARN: Webhook retry 2/10` | Transient network issue |
| `ERROR: Permission denied` | Need to grant permissions |
| `ERROR: API key invalid` | Check Gemini API key |

## Getting Help

If issues persist:

1. Collect logs: `cat /tmp/dayflow-headless.log`
2. Note your macOS version: `sw_vers`
3. Check daemon version: `dayflow-headless --version`
4. Open an issue at [GitHub Issues](https://github.com/JerryZLiu/Dayflow/issues)
