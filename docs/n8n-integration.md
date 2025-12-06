# n8n Integration Guide

Connect Dayflow headless daemon to n8n for powerful workflow automation.

## Overview

n8n is an open-source workflow automation tool. This guide shows how to:
1. Set up a webhook node to receive Dayflow activity data
2. Process and transform the data
3. Route to various destinations (Notion, Slack, Google Sheets, etc.)

## Basic Webhook Setup

### Step 1: Create Webhook Node

1. Open n8n and create a new workflow
2. Add a **Webhook** node
3. Configure:
   - **HTTP Method:** POST
   - **Path:** `/dayflow`
   - **Response Mode:** Immediately respond with "Received"

4. Copy the webhook URL (e.g., `https://your-n8n.com/webhook/dayflow`)

### Step 2: Configure Dayflow

Update your `~/.config/dayflow/config.json`:

```json
{
  "webhook": {
    "url": "https://your-n8n.com/webhook/dayflow",
    "sendJson": true,
    "sendMarkdown": true,
    "headers": {
      "X-Dayflow-Secret": "your-shared-secret"
    }
  }
}
```

### Step 3: Test Connection

1. Activate the webhook node in n8n (toggle on)
2. Restart Dayflow daemon
3. Wait for next analysis batch (or trigger manually)
4. Check n8n execution history for incoming data

## Example Workflows

### Daily Summary to Slack

```
[Webhook] → [IF] → [Slack]
             ↓
        Check if end of day
```

**Workflow:**
1. **Webhook** - Receives Dayflow data
2. **IF** - Check if time is after 6 PM
3. **Slack** - Post daily summary to #daily-log channel

**IF Node Expression:**
```javascript
{{ $now.hour >= 18 }}
```

**Slack Message:**
```
📊 *Dayflow Daily Summary*

{{ $json.markdown }}

Total time tracked: {{ Math.round($json.totalDuration / 60) }} minutes
```

### Activity Log to Notion

```
[Webhook] → [Code] → [Notion]
```

**Workflow:**
1. **Webhook** - Receives activity data
2. **Code** - Transform to Notion page format
3. **Notion** - Create page in Activity Database

**Code Node:**
```javascript
const activities = $input.all()[0].json.activities;

return activities.map(activity => ({
  json: {
    title: `${activity.appName}: ${activity.windowTitle}`,
    category: activity.category,
    duration: Math.round(activity.duration / 60),
    date: activity.startTime.split('T')[0]
  }
}));
```

**Notion Properties:**
- Title: `{{ $json.title }}`
- Category (Select): `{{ $json.category }}`
- Duration (Number): `{{ $json.duration }}`
- Date (Date): `{{ $json.date }}`

### Distraction Alert

```
[Webhook] → [Code] → [IF] → [Telegram]
```

**Workflow:**
1. **Webhook** - Receives activity data
2. **Code** - Calculate distraction score
3. **IF** - Check if score exceeds threshold
4. **Telegram** - Send alert

**Code Node:**
```javascript
const activities = $input.all()[0].json.activities;

const distractionApps = ['Twitter', 'Reddit', 'YouTube', 'TikTok', 'Instagram'];
const distractionTime = activities
  .filter(a => distractionApps.some(d => a.appName.includes(d)))
  .reduce((sum, a) => sum + a.duration, 0);

const totalTime = activities.reduce((sum, a) => sum + a.duration, 0);
const distractionPercent = (distractionTime / totalTime) * 100;

return [{
  json: {
    distractionPercent: Math.round(distractionPercent),
    distractionMinutes: Math.round(distractionTime / 60),
    shouldAlert: distractionPercent > 25
  }
}];
```

**IF Condition:**
```javascript
{{ $json.shouldAlert === true }}
```

**Telegram Message:**
```
⚠️ Distraction Alert

You've spent {{ $json.distractionMinutes }} minutes ({{ $json.distractionPercent }}%) on distracting apps.

Consider taking a focus break!
```

### Weekly Report to Google Sheets

```
[Schedule] → [HTTP] → [Code] → [Google Sheets]
```

**Note:** This workflow pulls from a summary endpoint if available, or aggregates from stored data.

## Webhook Security

### Verify Webhook Secret

Add a **Code** node after Webhook to validate:

```javascript
const expectedSecret = 'your-shared-secret';
const receivedSecret = $input.all()[0].json.headers['x-dayflow-secret'];

if (receivedSecret !== expectedSecret) {
  throw new Error('Invalid webhook secret');
}

return $input.all();
```

### IP Whitelisting

If your Dayflow daemon has a static IP, configure n8n to only accept requests from that IP.

## Data Schema Reference

### Incoming JSON Structure

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
  "totalDuration": 1800,
  "markdown": "# Activity Summary\n\n## Development\n\n- **VS Code**: project/main.swift (30m)\n\n---\n**Total: 30m**"
}
```

### Activity Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `appName` | string | Application name |
| `windowTitle` | string | Window/document title |
| `category` | string | AI-assigned category |
| `duration` | number | Duration in seconds |
| `startTime` | string | ISO 8601 timestamp |
| `endTime` | string | ISO 8601 timestamp |

## Troubleshooting

### Webhook not receiving data

1. Verify n8n webhook is activated (toggle on)
2. Check Dayflow logs: `grep webhook /tmp/dayflow-headless.log`
3. Test webhook directly:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
     -d '{"test": true}' \
     https://your-n8n.com/webhook/dayflow
   ```

### n8n showing "Unknown error"

1. Check n8n execution details for full error
2. Verify JSON is valid (no trailing commas, etc.)
3. Check n8n logs: `docker logs n8n` (if using Docker)

### Rate limiting

If you're hitting n8n rate limits:
1. Increase Dayflow `batchIntervalMinutes`
2. Use n8n's built-in rate limiting
3. Consider self-hosting n8n for unlimited executions

## Advanced: Custom Processing

### Aggregation Workflow

Create a workflow that aggregates Dayflow data over time:

```
[Webhook] → [Postgres] → (store)
            ↓
[Schedule] → [Postgres] → [Code] → [Email]
            (weekly)     (aggregate)  (report)
```

### AI Enhancement

Use n8n's AI nodes to further analyze activity:

```
[Webhook] → [OpenAI] → [Notion]
           (enhance summary)
```

**OpenAI Prompt:**
```
Analyze this work activity and provide:
1. Productivity score (1-10)
2. Main accomplishment
3. Suggestion for tomorrow

Activity data: {{ JSON.stringify($json) }}
```

## See Also

- [n8n Documentation](https://docs.n8n.io/)
- [Dayflow Headless Setup](headless.md)
- [Troubleshooting](troubleshooting.md)
