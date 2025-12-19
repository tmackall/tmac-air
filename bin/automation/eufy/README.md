# Eufy Camera Event Capture

Programmatically capture motion, person detection, doorbell, and other events from your Eufy Security cameras.

## Prerequisites

### 1. Create a Guest Account

**Important:** You cannot use the same credentials for both the Eufy mobile app and this library simultaneously. Create a dedicated guest account:

1. Open the Eufy Security app
2. Go to your device settings
3. Share your devices with a new email address
4. Set up the new account with a password

### 2. Enable Push Notifications

The library relies on push notifications to receive events. In the Eufy Security app (logged into your **main** account):

1. Go to each camera's settings
2. Enable **all** push notifications:
   - Motion Detection
   - Person Detection  
   - Pet Detection (if available)
   - Vehicle Detection (if available)
   - Doorbell events (if applicable)

### 3. Select the Correct Country

The country setting must match what's configured in your Eufy app. Common values:
- `US` - United States
- `GB` - United Kingdom
- `DE` - Germany
- `AU` - Australia

## Installation

```bash
npm install
```

## Configuration

Set your credentials via environment variables:

```bash
export EUFY_USERNAME="your-guest-email@example.com"
export EUFY_PASSWORD="your-password"
export EUFY_COUNTRY="US"
```

Or create a `.env` file (you'll need to add `dotenv` package):

```
EUFY_USERNAME=your-guest-email@example.com
EUFY_PASSWORD=your-password
EUFY_COUNTRY=US
```

## Usage

```bash
npm start
```

The script will:
1. Connect to Eufy Security cloud
2. Discover all shared devices
3. Listen for events and log them to console and `data/events.json`

## Captured Events

| Event Type | Description |
|------------|-------------|
| `motion_detected` | Motion detected by camera |
| `person_detected` | Person detected (with optional name if face recognition is set up) |
| `pet_detected` | Pet detected |
| `vehicle_detected` | Vehicle detected |
| `sound_detected` | Sound detected |
| `crying_detected` | Baby crying detected |
| `doorbell_pressed` | Doorbell button pressed |
| `sensor_open` | Door/window sensor opened |
| `lock_status` | Smart lock locked/unlocked |

## Customizing Event Handlers

Edit the `handleEvent()` function in `index.js` to add your own integrations:

```javascript
async function handleEvent(event) {
    switch (event.type) {
        case 'person_detected':
            // Send webhook
            await fetch('https://your-server.com/webhook', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(event)
            });
            break;
        
        case 'motion_detected':
            // Trigger home automation
            // ... your code here
            break;
    }
}
```

## Running as a Service

### Using systemd (Linux)

Create `/etc/systemd/system/eufy-events.service`:

```ini
[Unit]
Description=Eufy Event Capture
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/eufy-events
Environment=EUFY_USERNAME=your-email
Environment=EUFY_PASSWORD=your-password
Environment=EUFY_COUNTRY=US
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then:
```bash
sudo systemctl enable eufy-events
sudo systemctl start eufy-events
```

### Using PM2

```bash
npm install -g pm2
pm2 start index.js --name eufy-events
pm2 save
pm2 startup
```

## Troubleshooting

### Two-Factor Authentication

If you have 2FA enabled on the guest account, you'll get a `tfa request` event. Either:
- Disable 2FA on the guest account, or
- Handle the TFA flow programmatically

### Captcha Required

After failed login attempts, Eufy may require a captcha. Wait 24 hours or:
1. Log into the Eufy web portal
2. Solve the captcha there
3. Try connecting again

### Events Not Arriving

1. Ensure push notifications are enabled in the Eufy app
2. Check that the country setting matches your app
3. Verify the guest account has proper device access

### Connection Issues

- Check your internet connection
- Ensure no firewall is blocking outbound connections
- Try setting `p2pConnectionSetup: 1` (cloud only) if local P2P fails

## API Reference

The `eufy-security-client` library provides many more features:

- Start/stop RTSP streams
- Download recorded videos
- Capture snapshots
- Control camera settings (motion sensitivity, LED, etc.)
- Arm/disarm security modes

See: https://github.com/bropat/eufy-security-client

## License

MIT
