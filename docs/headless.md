# Dayflow Headless Daemon

A lightweight background daemon for Dayflow that runs without a GUI, perfect for headless servers, CI environments, or automated workflows.

## Overview

The headless daemon captures screen activity, analyzes it with Gemini AI, and sends summaries to a webhook endpoint. It's designed for:

- **Server environments** - Run on headless macOS machines
- **Automation workflows** - Integrate with n8n, Zapier, or custom pipelines
- **Resource-constrained systems** - Lower overhead than the full GUI app
- **Custom integrations** - JSON/Markdown webhooks for any destination

## Requirements

- macOS 13.0+ (Ventura) or macOS 15.0+ (Sequoia)
- Screen Recording permission granted
- Gemini API key (for AI analysis)
- Webhook endpoint to receive activity data

## Installation

### Build from Source

```bash
git clone https://github.com/JerryZLiu/Dayflow.git
cd Dayflow
swift build -c release
cp .build/release/dayflow-headless /usr/local/bin/
```

### Install as Launch Agent

```bash
# Generate and install the launch agent
dayflow-headless install

# Or manually:
dayflow-headless generate-plist > ~/Library/LaunchAgents/com.dayflow.headless.plist
launchctl load ~/Library/LaunchAgents/com.dayflow.headless.plist
```

## Configuration

Create a config file at `~/.config/dayflow/config.json`:

```json
{
  "geminiApiKey": "YOUR_GEMINI_API_KEY",
  "webhook": {
    "url": "https://your-webhook-endpoint.com/dayflow",
    "sendJson": true,
    "sendMarkdown": true,
    "headers": {
      "Authorization": "Bearer YOUR_TOKEN"
    },
    "retryStrategy": {
      "initialDelaySeconds": 5,
      "maxDelaySeconds": 300,
      "multiplier": 2,
      "maxAttempts": 10
    }
  },
  "recording": {
    "fps": 1,
    "resolution": "low"
  },
  "analysis": {
    "batchIntervalMinutes": 15
  },
  "database": {
    "walMode": true
  }
}
```

### Configuration Options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `geminiApiKey` | string | required | Your Google Gemini API key |
| `webhook.url` | string | required | Destination URL for activity data |
| `webhook.sendJson` | bool | true | Send JSON payload |
| `webhook.sendMarkdown` | bool | true | Send Markdown summary |
| `webhook.headers` | object | {} | Custom HTTP headers |
| `webhook.retryStrategy.initialDelaySeconds` | int | 5 | First retry delay |
| `webhook.retryStrategy.maxDelaySeconds` | int | 300 | Maximum retry delay |
| `webhook.retryStrategy.multiplier` | int | 2 | Exponential backoff multiplier |
| `webhook.retryStrategy.maxAttempts` | int | 10 | Maximum retry attempts |
| `recording.fps` | int | 1 | Frames per second |
| `recording.resolution` | string | "low" | Capture resolution |
| `analysis.batchIntervalMinutes` | int | 15 | Analysis frequency |
| `database.walMode` | bool | true | Enable SQLite WAL mode |

### Environment Variables

You can override config values with environment variables:

```bash
export GEMINI_API_KEY="your-key"    # Overrides geminiApiKey
export DAYFLOW_WEBHOOK_URL="https://..." # Overrides webhook.url
```

**Security Note**: For production, prefer environment variables over storing API keys in config files.

## Usage

### Run Manually

```bash
# Run with default config location
dayflow-headless

# Run with custom config
dayflow-headless --config /path/to/config.json

# Check version
dayflow-headless --version
```

### Run as Service

```bash
# Start the service
launchctl start com.dayflow.headless

# Stop the service
launchctl stop com.dayflow.headless

# Check status
launchctl list | grep dayflow

# View logs
tail -f /tmp/dayflow-headless.log
```

### Uninstall

```bash
# Unload and remove launch agent
launchctl unload ~/Library/LaunchAgents/com.dayflow.headless.plist
rm ~/Library/LaunchAgents/com.dayflow.headless.plist
rm /usr/local/bin/dayflow-headless
```

## Webhook Payload

### JSON Format

```json
{
  "timestamp": "2025-12-05T18:00:00Z",
  "activities": [
    {
      "appName": "VS Code",
      "windowTitle": "project/main.swift",
      "category": "Development",
      "duration": 1800,
      "startTime": "2025-12-05T17:30:00Z",
      "endTime": "2025-12-05T18:00:00Z"
    }
  ],
  "summary": "Coding session focused on Swift development",
  "totalDuration": 1800
}
```

### Markdown Format

```markdown
# Activity Summary

## Development

- **VS Code**: project/main.swift (30m)

---
**Total: 30m**
```

## Retry Behavior

The daemon uses exponential backoff for webhook failures:

1. First failure: wait 5 seconds
2. Second failure: wait 10 seconds
3. Third failure: wait 20 seconds
4. ...continues doubling up to 300 seconds max
5. After 10 attempts: payload queued to disk

Failed payloads are stored in `~/.local/share/dayflow/queue/` and retried on next successful connection.

## Permissions

### Screen Recording

Grant permission in System Settings:
1. Open **System Settings** → **Privacy & Security** → **Screen & System Audio Recording**
2. Enable **dayflow-headless**
3. Restart the daemon

### Automation (Optional)

For URL scheme integration:
1. Open **System Settings** → **Privacy & Security** → **Automation**
2. Allow **dayflow-headless** to control other apps

## Signals

The daemon responds to standard Unix signals:

| Signal | Behavior |
|--------|----------|
| `SIGTERM` | Graceful shutdown (flush queue, save state) |
| `SIGINT` | Same as SIGTERM |
| `SIGHUP` | Reload configuration |

```bash
# Graceful restart
kill -HUP $(pgrep dayflow-headless)

# Graceful stop
kill -TERM $(pgrep dayflow-headless)
```

## Logs

Logs are written to `/tmp/dayflow-headless.log` by default. Log levels:

- `INFO` - Normal operation
- `WARN` - Recoverable issues (retry, permission check)
- `ERROR` - Failures requiring attention

```bash
# Watch logs in real-time
tail -f /tmp/dayflow-headless.log

# Filter for errors
grep ERROR /tmp/dayflow-headless.log
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DaemonCoordinator                        │
│  Orchestrates capture, analysis, and export                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
       ┌──────────────┼──────────────┐
       │              │              │
       ▼              ▼              ▼
┌─────────────┐ ┌───────────┐ ┌─────────────┐
│   Screen    │ │   AI      │ │   Webhook   │
│   Capture   │ │  Analysis │ │   Service   │
│             │ │ (Gemini)  │ │             │
└─────────────┘ └───────────┘ └──────┬──────┘
                                     │
                              ┌──────┴──────┐
                              │  BatchQueue │
                              │ (disk-backed│
                              │   failover) │
                              └─────────────┘
```

## See Also

- [Troubleshooting](troubleshooting.md)
- [macOS Sequoia Notes](sequoia-notes.md)
- [n8n Integration Guide](n8n-integration.md)
- [Main Dayflow App](../README.md)
