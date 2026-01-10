# 🔥 EmberBurn Web UI - Quick Start Guide

**Get the Dashboard Running in 60 Seconds**

By Patrick Ryan, CTO - Fireball Industries

---

## The Absolute Fastest Way

### 1. Start the Server

```bash
python opcua_server.py -c config/config_web_ui.json
```

### 2. Open Your Browser

```
http://localhost:5000/
```

### 3. Done!

You should see the EmberBurn dashboard with:
- 🔥 ASCII art branding (Fireball Industries + EmberBurn)
- 📊 Live tag values updating every 2 seconds
- 📡 Publisher status cards
- 🚨 Alarm monitoring

---

## What You're Looking At

### Dashboard (Home Screen)

**Top Cards:**
- **Active Tags** - Number of live OPC UA tags
- **Publishers** - How many protocols are enabled (should show "3 / 12" with default config)
- **Active Alarms** - Any warnings or critical alarms

**Bottom Table:**
- Live tag values (Temperature, Pressure, Flow Rate, etc.)
- Updates automatically every 2 seconds
- "LIVE" badge pulses to show it's working

### Tag Monitor 🏷️

Full list of all tags with:
- Tag name (OPC UA node ID)
- Current value (in big yellow numbers)
- Data type (float, int, string, bool)
- Last update timestamp

### Publishers 📡

Cards for each protocol showing:
- Protocol name and icon
- ENABLED (green) or DISABLED (gray) status
- Toggle button to enable/disable
- Config button (coming soon)

**With default config, you should see:**
- ✅ REST API - ENABLED (green)
- ✅ GraphQL - ENABLED (green)
- ✅ Alarms - ENABLED (green)
- ⬜ All others - DISABLED (gray)

**Try It:** Click the toggle button on MQTT to enable it (it'll fail without a broker, but you'll see the UI work)

### Alarms 🚨

Shows active alarms if any are triggered.

**Default Config Has 3 Rules:**
1. HighTemperature - Triggers if temp > 26°C
2. HighPressure - Triggers if pressure > 103 kPa
3. LowFlowRate - Triggers if flow < 12 L/min

**To See Alarms:** Just wait - the simulated tags will eventually cross thresholds. When they do, you'll see them appear here with priority badges (WARNING/CRITICAL).

### Configuration ⚙️

System info and quick actions (mostly placeholders for now).

---

## Testing the UI

### Watch Live Updates

1. Go to **Dashboard** view
2. Watch the tag values change every 2 seconds
3. Notice the "LIVE" badges pulsing

**The values should be changing because:**
- Temperature: Sine wave (22.5 ± 5°C)
- Pressure: Random (98-105 kPa)
- Flow Rate: Random (10-20 L/min)
- Counter: Incrementing (0-10000)

### Enable/Disable Publishers

1. Go to **Publishers** view
2. Click "▶️ Enable" on MQTT publisher
3. Watch it attempt to connect
4. Check server logs to see the error (no broker running)
5. Click "⏸️ Disable" to turn it back off

**Expected:** The UI will update the badge to show ENABLED/DISABLED. The server will log the attempt.

### Monitor Alarms

1. Go to **Alarms** view
2. Initially: "All Systems Normal" ✅
3. Wait 30-60 seconds...
4. Temperature or Pressure will cross a threshold
5. An alarm appears in the table!

**Alarm Table Shows:**
- Priority (WARNING = orange, CRITICAL = red)
- Rule name (e.g., "HighTemperature")
- Tag that triggered it
- Value that caused the alarm
- Message explaining what happened
- Timestamp

---

## Customizing for Your Demo

### Change Tag Values

Edit `config/config_web_ui.json` and modify:

```json
"Temperature": {
  "type": "float",
  "initial_value": 22.5,
  "simulation_type": "sine",
  "amplitude": 5.0,      // ← Make bigger for more variation
  "offset": 22.5,        // ← Change baseline
  "period": 60.0         // ← Faster/slower oscillation
}
```

Restart the server to see changes.

### Enable More Publishers

Edit `config/config_web_ui.json` and change:

```json
"mqtt": {
  "enabled": true,       // ← Change false to true
  "broker": "localhost",
  "port": 1883
}
```

**Note:** You'll need the actual services running (MQTT broker, Kafka cluster, etc.)

### Add More Alarm Rules

Edit the `alarms` section:

```json
"rules": [
  {
    "name": "CriticalVibration",
    "tag": "ns=2;i=10",              // Vibration sensor
    "condition": ">",
    "threshold": 1.5,
    "priority": "CRITICAL",
    "message": "Dangerous vibration levels!"
  }
]
```

---

## Troubleshooting

### "Can't connect to API"

**Check:**
```bash
# Is the server running?
ps aux | grep opcua_server.py

# Is port 5000 accessible?
curl http://localhost:5000/api/tags
```

**Fix:** Make sure you started the server with REST API enabled (it's in `config_web_ui.json`)

### "UI is blank/broken"

**Check browser console (F12 → Console tab):**
- Are there any red errors?
- Did React/Babel load from CDN?
- Is your internet working? (CDN dependencies need internet)

**Fix:** Try hard refresh (Ctrl+Shift+R) or use Chrome/Firefox/Edge (not IE11)

### "No tag data showing"

**Check:**
```bash
# Test API directly
curl http://localhost:5000/api/tags

# Should return JSON with tags
```

**Fix:** 
- Is `rest_api` publisher enabled in config?
- Are tags being simulated? (check `"simulate": true`)
- Look at server logs: `tail -f opcua_server.log`

### "Publishers won't toggle"

**Check server logs:**
```bash
tail -f opcua_server.log
```

**Common Issues:**
- **MQTT**: No broker running (install mosquitto)
- **Kafka**: No Kafka cluster (install Kafka)
- **GraphQL**: Port 5002 already in use
- **InfluxDB**: No InfluxDB instance (install InfluxDB)

**Fix:** Either install the required service or just leave it disabled

### "Alarms never trigger"

**Check alarm rules in config:**

```json
"rules": [
  {
    "name": "HighTemperature",
    "tag": "ns=2;i=2",     // ← Does this match your tag's node ID?
    "threshold": 26.0      // ← Will your tag ever reach this value?
  }
]
```

**Fix:**
- Verify tag node IDs match (check server logs on startup)
- Adjust thresholds to match your tag ranges
- Check `debounce_seconds` isn't too long (default: 30s)

---

## Next Steps

### Learn More

- Read [docs/WEB_UI.md](WEB_UI.md) for complete documentation
- Customize the UI (edit `web/index.html`)
- Add more protocols (see integration guides)

### Production Deployment

1. **Use a real WSGI server:**
   ```bash
   pip install gunicorn
   gunicorn -w 4 -b 0.0.0.0:5000 your_wsgi_app:app
   ```

2. **Add security:**
   - Enable HTTPS (use nginx with SSL)
   - Add authentication (JWT tokens)
   - Configure CORS properly

3. **Deploy to K3s/Docker:**
   - See deployment guide (coming soon)
   - Use environment variables for config
   - Set up ingress controller

### Customize the UI

Want to change colors, add features, or modify layouts?

**All the code is in ONE file:** `web/index.html`

Open it, find the React components, and edit away. No build step needed!

**Some ideas:**
- Add charts (Recharts is already included!)
- Change the color scheme
- Add tag write functionality
- Create custom dashboards
- Add user login

---

## Demo Script

**For showing this to management/customers:**

1. **Open the dashboard:**
   - "This is EmberBurn, our industrial IoT gateway platform"
   - Point out the fire-themed branding

2. **Show live data:**
   - "All these values are updating in real-time from our OPC UA server"
   - Watch the counter increment
   - Point out the pulse animation on "LIVE" badges

3. **Explain multi-protocol:**
   - Click to Publishers view
   - "We support 12 different industrial protocols"
   - "Can enable/disable any of them with one click"

4. **Show alarm monitoring:**
   - Click to Alarms view
   - If there's an alarm: "See, it automatically detected this condition"
   - If no alarms: "Everything is running normally - when issues occur, they appear here instantly"

5. **Emphasize ease of use:**
   - "No command line needed"
   - "No JSON file editing"
   - "Everything through this clean interface"

6. **Mention integrations:**
   - "This feeds into Grafana for visualization"
   - "Sends alerts via email, Slack, or SMS"
   - "Publishes to MQTT, Kafka, and more"

---

## FAQ

**Q: Do I need Node.js/npm?**
A: Nope! It's a single HTML file that loads React from CDN.

**Q: Can I use this without internet?**
A: You'll need internet for the CDN dependencies (React, Babel). Or download them locally.

**Q: Can I customize the look?**
A: Absolutely! Edit the CSS in `web/index.html`. All styles are inline.

**Q: What browsers work?**
A: Chrome, Firefox, Edge, Safari (modern versions). Not IE11.

**Q: Is this production-ready?**
A: For internal networks, yes. For public internet, add security first.

**Q: Can I white-label this?**
A: Sure! Change the ASCII art, colors, and company name in the HTML.

**Q: How do I add more tags?**
A: Edit `config/config_web_ui.json`, add tags to the `"tags"` section, restart server.

---

**You're all set! Enjoy your new industrial IoT dashboard!** 🔥

*Questions? Read the full docs at [docs/WEB_UI.md](WEB_UI.md)*

*Built with 🔥 by Patrick Ryan - Fireball Industries*
