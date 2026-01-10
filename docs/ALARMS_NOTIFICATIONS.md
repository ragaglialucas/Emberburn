# Alarms & Notifications System Guide

*By Patrick Ryan, CTO - Fireball Industries*  
*"Because finding out your reactor melted down via Twitter is not a good look"*

---

## What This Is

An intelligent alarming and notification system that monitors your OPC UA tags 24/7 and screams at you (via email, Slack, or SMS) when things go sideways.

**Features:**
- 🎯 **Threshold-based alerting** - Set rules like "if temp > 24°C, panic"
- 📧 **Multi-channel notifications** - Email, Slack, SMS, or just logs
- ⏱️ **Debouncing** - Won't spam you with 47 emails in 30 seconds
- 📊 **Alarm history** - Know what happened and when
- 🚦 **Priority levels** - INFO, WARNING, CRITICAL (with appropriate panic levels)
- ✅ **Auto-clear** - Alarms clear themselves when values return to normal
- 🔔 **Acknowledgment** - Mark alarms as "yeah, I know, I'm on it"

---

## Quick Start

### Step 1: Basic Configuration

Create `config_alarms.json` or add to your existing config:

```json
{
  "publishers": {
    "alarms": {
      "enabled": true,
      "rules": [
        {
          "name": "High Temperature Alert",
          "tag": "Temperature",
          "condition": ">",
          "threshold": 24.0,
          "priority": "CRITICAL",
          "debounce_seconds": 60,
          "message": "Temperature is too high!",
          "auto_clear": true,
          "channels": ["log", "slack"]
        }
      ],
      "notifications": {
        "slack": {
          "enabled": true,
          "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        }
      },
      "history_size": 1000
    }
  }
}
```

### Step 2: Run the Server

```bash
python opcua_server.py -c config/config_alarms.json
```

### Step 3: Watch It Work

When `Temperature` exceeds 24°C:
```
⚠️ ALARM TRIGGERED: High Temperature Alert - Temperature=25.3 > 24.0 - Temperature is too high!
```

When it goes back below:
```
✅ ALARM CLEARED: High Temperature Alert - Temperature=23.8 (was 25.3)
```

---

## Alarm Rules Configuration

### Rule Structure

```json
{
  "name": "My Alarm Rule",          // Human-readable name
  "tag": "TagName",                 // OPC UA tag to monitor
  "condition": ">",                 // Comparison operator
  "threshold": 100.0,               // Threshold value
  "priority": "CRITICAL",           // INFO, WARNING, or CRITICAL
  "debounce_seconds": 60,           // Min seconds between notifications
  "message": "Something went wrong!", // Alert message
  "auto_clear": true,               // Auto-clear when value returns to normal
  "channels": ["log", "email", "slack", "sms"]  // Notification channels
}
```

### Conditions

| Condition | Description | Example |
|-----------|-------------|---------|
| `>` | Greater than | `temp > 25` |
| `>=` | Greater than or equal | `pressure >= 100` |
| `<` | Less than | `flow < 50` |
| `<=` | Less than or equal | `level <= 10` |
| `==` | Equal to | `status == "error"` |
| `!=` | Not equal to | `running != true` |

### Priority Levels

**INFO** ℹ️
- Non-critical notifications
- Informational alerts
- Example: "Production counter approaching rollover"

**WARNING** ⚠️
- Potential issues
- Should be investigated
- Example: "Temperature trending high"

**CRITICAL** 🚨
- Immediate attention required
- System safety concerns
- Example: "Pressure exceeds safe limits"

---

## Notification Channels

### 1. Log (Always Enabled)

Writes to the standard logger. Always works, no config needed.

**Output:**
```
2026-01-10 14:32:15 WARNING: 🚨 ALARM TRIGGERED: High Pressure - Pressure=103.2 > 102.5
2026-01-10 14:35:42 INFO: ✅ ALARM CLEARED: High Pressure - Pressure=101.8 (was 103.2)
```

### 2. Email (SMTP)

Send email notifications via any SMTP server.

**Configuration:**
```json
{
  "email": {
    "enabled": true,
    "smtp_server": "smtp.gmail.com",
    "smtp_port": 587,
    "username": "your-email@gmail.com",
    "password": "your-app-password",
    "from": "opcua-alarms@fireball.local",
    "to": [
      "ops-team@fireball.local",
      "manager@fireball.local"
    ]
  }
}
```

**Gmail Setup:**
1. Enable 2FA on your Google account
2. Generate an "App Password" (Google Account → Security → App Passwords)
3. Use the app password in the config (not your regular password)

**Email Format:**
```
Subject: [CRITICAL] High Temperature Alert - Temperature

Alarm: High Temperature Alert
Priority: CRITICAL
Tag: Temperature
Value: 25.3
Condition: > 24.0
Message: Temperature is too high!
Time: 2026-01-10 14:32:15
Status: ACTIVE
```

### 3. Slack (Webhook)

Post formatted messages to Slack channels.

**Configuration:**
```json
{
  "slack": {
    "enabled": true,
    "webhook_url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
    "channel": "#alarms",
    "username": "OPC UA Alarm Bot"
  }
}
```

**Setup Slack Webhook:**
1. Go to https://api.slack.com/apps
2. Create new app → Incoming Webhooks
3. Activate webhooks
4. Add webhook to workspace
5. Select channel
6. Copy webhook URL

**Slack Message:**
```
[CRITICAL] High Temperature Alert
Temperature is too high!

Tag: Temperature        Value: 25.3
Condition: > 24.0       Status: ACTIVE
```

Color-coded by priority:
- 🟢 INFO - Green
- 🟡 WARNING - Orange  
- 🔴 CRITICAL - Red

### 4. SMS (Twilio)

Send text messages for critical alerts.

**Configuration:**
```json
{
  "sms": {
    "enabled": true,
    "account_sid": "AC1234567890abcdef",
    "auth_token": "your-auth-token",
    "from_number": "+15555551234",
    "to_numbers": [
      "+15555555678",
      "+15555559999"
    ]
  }
}
```

**Twilio Setup:**
1. Sign up at https://www.twilio.com/
2. Get a phone number
3. Copy Account SID and Auth Token
4. Add to config

**Install Twilio:**
```bash
pip install twilio
```

**SMS Format:**
```
[CRITICAL] High Temperature Alert: Temperature=25.3 > 24.0. Temperature is too high!
```

---

## Example Alarm Rules

### Manufacturing Line Monitoring

```json
{
  "rules": [
    {
      "name": "Production Line Stopped",
      "tag": "IsRunning",
      "condition": "==",
      "threshold": false,
      "priority": "CRITICAL",
      "debounce_seconds": 300,
      "message": "Production line has stopped!",
      "channels": ["log", "email", "sms"]
    },
    {
      "name": "Low Production Rate",
      "tag": "FlowRate",
      "condition": "<",
      "threshold": 80,
      "priority": "WARNING",
      "debounce_seconds": 600,
      "message": "Production rate below target",
      "channels": ["log", "slack"]
    },
    {
      "name": "Quality Issue",
      "tag": "DefectRate",
      "condition": ">",
      "threshold": 5.0,
      "priority": "WARNING",
      "debounce_seconds": 180,
      "message": "Defect rate exceeds acceptable limit",
      "channels": ["log", "email"]
    }
  ]
}
```

### HVAC Monitoring

```json
{
  "rules": [
    {
      "name": "Server Room Too Hot",
      "tag": "ServerRoomTemp",
      "condition": ">",
      "threshold": 26.0,
      "priority": "CRITICAL",
      "debounce_seconds": 120,
      "message": "Server room temperature critical!",
      "channels": ["log", "email", "sms", "slack"]
    },
    {
      "name": "Server Room Too Cold",
      "tag": "ServerRoomTemp",
      "condition": "<",
      "threshold": 18.0,
      "priority": "WARNING",
      "debounce_seconds": 300,
      "message": "Server room temperature low",
      "channels": ["log", "slack"]
    },
    {
      "name": "HVAC System Offline",
      "tag": "HVACStatus",
      "condition": "!=",
      "threshold": "Running",
      "priority": "CRITICAL",
      "debounce_seconds": 60,
      "message": "HVAC system not running!",
      "channels": ["log", "email", "sms"]
    }
  ]
}
```

### Process Control

```json
{
  "rules": [
    {
      "name": "Reactor Overpressure",
      "tag": "ReactorPressure",
      "condition": ">",
      "threshold": 150.0,
      "priority": "CRITICAL",
      "debounce_seconds": 10,
      "message": "EMERGENCY: Reactor pressure exceeds safety limits!",
      "channels": ["log", "email", "sms", "slack"]
    },
    {
      "name": "Feed Tank Low Level",
      "tag": "FeedTankLevel",
      "condition": "<",
      "threshold": 20.0,
      "priority": "WARNING",
      "debounce_seconds": 300,
      "message": "Feed tank level low - refill needed",
      "channels": ["log", "slack"]
    },
    {
      "name": "Pump Vibration High",
      "tag": "PumpVibration",
      "condition": ">",
      "threshold": 5.0,
      "priority": "WARNING",
      "debounce_seconds": 180,
      "message": "Pump vibration elevated - schedule maintenance",
      "channels": ["log", "email"]
    }
  ]
}
```

---

## Debouncing

**Problem:** Tag oscillates around threshold, causing notification spam.

**Solution:** Debouncing - minimum time between notifications for the same alarm.

**Example:**
```json
{
  "debounce_seconds": 60
}
```

**Timeline:**
```
14:00:00 - Temp = 24.5 → Alarm triggered, notification sent
14:00:15 - Temp = 23.8 → Alarm cleared (auto_clear: true)
14:00:30 - Temp = 24.6 → Alarm triggered, but DEBOUNCED (only 30s since last)
14:01:15 - Temp = 24.7 → Alarm triggered, notification sent (60s passed)
```

**Recommendations:**
- **CRITICAL alarms:** 10-60 seconds (fast response)
- **WARNING alarms:** 60-300 seconds (avoid noise)
- **INFO alarms:** 300-600 seconds (rarely urgent)

---

## Auto-Clear

When `auto_clear: true`, alarms automatically clear when the value returns to acceptable range.

**Example:**
```json
{
  "name": "High Temp",
  "condition": ">",
  "threshold": 25.0,
  "auto_clear": true
}
```

**Behavior:**
- Temp = 26°C → Alarm ACTIVE
- Temp = 24°C → Alarm CLEARED automatically

**When to use:**
- Process values that fluctuate (temperature, pressure, flow)
- Temporary conditions

**When NOT to use:**
- Conditions requiring manual intervention
- Critical failures needing acknowledgment
- Set `auto_clear: false` and clear manually

---

## Alarm History

Every alarm (triggered and cleared) is stored in history.

**Access via API** (if you add REST endpoints):
```bash
# Get active alarms
GET /api/alarms/active

# Get alarm history
GET /api/alarms/history?limit=100

# Acknowledge alarm
POST /api/alarms/acknowledge
{
  "rule_name": "High Temperature Alert",
  "tag_name": "Temperature",
  "user": "patrick.ryan"
}
```

**History Record:**
```json
{
  "rule_name": "High Temperature Alert",
  "tag": "Temperature",
  "priority": "CRITICAL",
  "message": "Temperature is too high!",
  "condition": "> 24.0",
  "triggered_value": 25.3,
  "triggered_at": 1736524335.123,
  "cleared_at": 1736524542.456,
  "cleared_value": 23.8,
  "status": "CLEARED"
}
```

**History Size:**
```json
{
  "history_size": 1000  // Keep last 1000 alarms
}
```

---

## Integration with InfluxDB

Store alarm events in InfluxDB for long-term analysis.

**Add both publishers:**
```json
{
  "publishers": {
    "alarms": {
      "enabled": true,
      "rules": [...]
    },
    "influxdb": {
      "enabled": true,
      "url": "http://localhost:8086",
      "bucket": "industrial-data"
    }
  }
}
```

**Query alarms in Grafana:**
```flux
from(bucket: "industrial-data")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "opcua_tags")
  |> filter(fn: (r) => r.tag == "Temperature")
  |> filter(fn: (r) => r._value > 24.0)
```

**Create alarm annotation:**
```flux
// Show alarm events as vertical lines on graphs
from(bucket: "alarms")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r.priority == "CRITICAL")
```

---

## Best Practices

### 1. **Start Simple**
Begin with log-only alarms, then add notifications:
```json
{
  "channels": ["log"]  // Start here
}
```

Then graduate to:
```json
{
  "channels": ["log", "slack"]  // Add Slack
}
```

### 2. **Use Priority Wisely**
- **CRITICAL:** Wakes people up at 3 AM (use sparingly)
- **WARNING:** Check during business hours
- **INFO:** Nice to know, not urgent

### 3. **Set Appropriate Debounce**
Too short = notification spam  
Too long = delayed awareness

Start with 60-120 seconds, adjust based on tag behavior.

### 4. **Test Your Notifications**
```bash
# Temporarily lower threshold to trigger alarm
python opcua_server.py -c config/config_alarms.json
```

Verify emails/Slack/SMS actually work BEFORE going to production.

### 5. **Monitor the Monitors**
If alarm system fails silently, you're in trouble. Consider:
- Heartbeat alarm (triggers every hour to confirm system works)
- Monitor alarm system logs
- Alert if no alarms triggered in X days (might mean system is down)

### 6. **Don't Cry Wolf**
Too many false alarms = people ignore them.

Tune thresholds based on normal operating ranges:
```
Normal range: 18-23°C
Warning: < 17 or > 24°C (1°C buffer)
Critical: < 15 or > 26°C (3°C buffer)
```

---

## Troubleshooting

### "Alarms not triggering"

**Check:**
- Is alarms publisher enabled? `"enabled": true`
- Are thresholds correct? (not inverted)
- Is tag name spelled correctly?
- Check logs: `python opcua_server.py -l DEBUG`

### "Too many notifications"

**Fix:**
- Increase `debounce_seconds`
- Widen threshold buffer zone
- Check if tag is oscillating (use InfluxDB to visualize)

### "Emails not sending"

**Check:**
- SMTP server/port correct?
- Using app password (not account password) for Gmail?
- Firewall blocking port 587/465?
- Try `telnet smtp.gmail.com 587` to test connectivity

### "Slack messages not appearing"

**Check:**
- Webhook URL correct? (should start with `https://hooks.slack.com/`)
- Slack app installed in workspace?
- Channel exists?
- Test webhook: `curl -X POST webhook_url -d '{"text":"test"}'`

### "SMS not sending"

**Check:**
- Twilio library installed? `pip install twilio`
- Account SID and Auth Token correct?
- Phone numbers in E.164 format? (`+15555551234`)
- Twilio account has credit?

---

## Advanced: Custom Notification Channels

Want to send alarms to Discord, Teams, PagerDuty, etc.? Easy!

**Add custom method in AlarmsPublisher:**
```python
def _send_custom(self, alarm: Dict):
    custom_config = self.notifications_config.get("custom", {})
    webhook_url = custom_config.get("webhook_url")
    
    payload = {
        "alarm": alarm["rule_name"],
        "value": alarm["triggered_value"],
        "priority": alarm["priority"]
    }
    
    requests.post(webhook_url, json=payload)
```

**Register in channels:**
```python
elif channel == "custom":
    self._send_custom(alarm)
```

---

## Production Deployment

### Docker/K3s Secrets

Don't hardcode passwords in config!

**K3s Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alarm-secrets
stringData:
  smtp-password: "your-smtp-password"
  slack-webhook: "https://hooks.slack.com/..."
  twilio-token: "your-twilio-token"
```

**Load from environment:**
```python
import os

email_password = os.getenv("SMTP_PASSWORD", config.get("password"))
slack_webhook = os.getenv("SLACK_WEBHOOK", config.get("webhook_url"))
```

### Monitoring

Add health check:
```python
# Heartbeat alarm - triggers every hour to confirm system works
{
  "name": "Alarm System Heartbeat",
  "tag": "Heartbeat",
  "condition": ">",
  "threshold": 0,
  "priority": "INFO",
  "channels": ["log"]
}
```

---

## Summary

You now have a professional-grade alarming system that:

✅ Monitors unlimited tags with custom rules  
✅ Sends notifications via email, Slack, SMS  
✅ Prevents notification spam with debouncing  
✅ Maintains alarm history  
✅ Auto-clears when conditions normalize  
✅ Supports priority levels  
✅ Integrates with your existing infrastructure  

Now go set some thresholds and sleep better knowing you'll actually find out when things go wrong.

---

*Last updated: 2026-01-10*  
*Written at 2 AM after being paged one too many times*

**Patrick Ryan**  
*CTO, Fireball Industries*  
*"The only thing worse than an alarm going off is an alarm NOT going off when it should"*
