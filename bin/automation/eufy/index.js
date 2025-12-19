/**
 * Eufy Camera Event Capture
 * 
 * Captures motion, person detection, and other events from Eufy cameras
 * using the eufy-security-client library.
 * 
 * Prerequisites:
 * 1. Create a guest account in the Eufy app and share your devices with it
 * 2. Enable all push notifications in the Eufy app for the devices
 * 3. Set your credentials in a .env file or environment variables
 */

const { EufySecurity, Device, Station } = require('eufy-security-client');
const fs = require('fs');
const path = require('path');

// Configuration - set these via environment variables or .env file
const config = {
    username: process.env.EUFY_USERNAME || 'your-guest-email@example.com',
    password: process.env.EUFY_PASSWORD || 'your-password',
    country: process.env.EUFY_COUNTRY || 'US',  // Must match your Eufy app setting
    language: 'en',
    persistentDir: './data',
    eventRecordingSeconds: 30,
    p2pConnectionSetup: 2,  // 0=only local, 1=only cloud, 2=prefer local
    pollingIntervalMinutes: 10,
    acceptInvitations: true,
};

// Ensure data directory exists
if (!fs.existsSync(config.persistentDir)) {
    fs.mkdirSync(config.persistentDir, { recursive: true });
}

// Event log file
const eventLogPath = path.join(config.persistentDir, 'events.json');

/**
 * Log an event to file and console
 */
function logEvent(eventType, deviceName, data) {
    const event = {
        timestamp: new Date().toISOString(),
        type: eventType,
        device: deviceName,
        data: data
    };
    
    console.log(`[${event.timestamp}] ${eventType} - ${deviceName}:`, JSON.stringify(data, null, 2));
    
    // Append to event log file
    let events = [];
    if (fs.existsSync(eventLogPath)) {
        try {
            events = JSON.parse(fs.readFileSync(eventLogPath, 'utf8'));
        } catch (e) {
            events = [];
        }
    }
    events.push(event);
    
    // Keep last 1000 events
    if (events.length > 1000) {
        events = events.slice(-1000);
    }
    
    fs.writeFileSync(eventLogPath, JSON.stringify(events, null, 2));
    
    return event;
}

/**
 * Handle custom actions when events occur
 * Modify this function to integrate with your systems
 */
async function handleEvent(event) {
    // Example integrations you could add:
    // - Send webhook to your server
    // - Trigger home automation
    // - Send notification via Pushover/Telegram
    // - Save thumbnail to disk
    // - Record video clip
    
    switch (event.type) {
        case 'motion_detected':
            console.log(`🚨 Motion detected on ${event.device}!`);
            break;
        case 'person_detected':
            console.log(`👤 Person detected on ${event.device}!`);
            break;
        case 'doorbell_pressed':
            console.log(`🔔 Doorbell pressed on ${event.device}!`);
            break;
        case 'crying_detected':
            console.log(`👶 Crying detected on ${event.device}!`);
            break;
        case 'pet_detected':
            console.log(`🐕 Pet detected on ${event.device}!`);
            break;
        case 'vehicle_detected':
            console.log(`🚗 Vehicle detected on ${event.device}!`);
            break;
        default:
            console.log(`📢 Event on ${event.device}: ${event.type}`);
    }
}

async function main() {
    console.log('Starting Eufy Security Event Monitor...');
    console.log('Configuration:', { 
        username: config.username.replace(/(.{3}).*(@.*)/, '$1***$2'),
        country: config.country 
    });

    // Create the EufySecurity client
    const eufySecurity = await EufySecurity.initialize(config);

    // ========== Connection Events ==========
    
    eufySecurity.on('connect', () => {
        console.log('✅ Connected to Eufy Security cloud');
    });

    eufySecurity.on('close', () => {
        console.log('❌ Disconnected from Eufy Security cloud');
    });

    eufySecurity.on('push connect', () => {
        console.log('✅ Push notification service connected');
    });

    eufySecurity.on('push close', () => {
        console.log('❌ Push notification service disconnected');
    });

    // ========== Station Events ==========
    
    eufySecurity.on('station added', (station) => {
        console.log(`📍 Station discovered: ${station.getName()} (${station.getSerial()})`);
    });

    eufySecurity.on('station connect', (station) => {
        console.log(`📍 Station connected: ${station.getName()}`);
    });

    eufySecurity.on('station close', (station) => {
        console.log(`📍 Station disconnected: ${station.getName()}`);
    });

    eufySecurity.on('station command result', (station, result) => {
        console.log(`📍 Station command result from ${station.getName()}:`, result);
    });

    // ========== Device Events ==========
    
    eufySecurity.on('device added', (device) => {
        console.log(`📷 Device discovered: ${device.getName()} (${device.getSerial()}) - Model: ${device.getModel()}`);
    });

    // Motion Detection
    eufySecurity.on('device motion detected', (device, state) => {
        const event = logEvent('motion_detected', device.getName(), { 
            state,
            serial: device.getSerial(),
            model: device.getModel()
        });
        handleEvent(event);
    });

    // Person Detection
    eufySecurity.on('device person detected', (device, state, person) => {
        const event = logEvent('person_detected', device.getName(), { 
            state,
            person: person || 'unknown',
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Pet Detection
    eufySecurity.on('device pet detected', (device, state) => {
        const event = logEvent('pet_detected', device.getName(), { 
            state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Vehicle Detection
    eufySecurity.on('device vehicle detected', (device, state) => {
        const event = logEvent('vehicle_detected', device.getName(), { 
            state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Sound Detection
    eufySecurity.on('device sound detected', (device, state) => {
        const event = logEvent('sound_detected', device.getName(), { 
            state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Crying Detection
    eufySecurity.on('device crying detected', (device, state) => {
        const event = logEvent('crying_detected', device.getName(), { 
            state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Doorbell Ring
    eufySecurity.on('device rings', (device, state) => {
        const event = logEvent('doorbell_pressed', device.getName(), { 
            state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Device Property Changes (battery, status, etc.)
    eufySecurity.on('device property changed', (device, name, value, ready) => {
        // Only log important property changes to avoid spam
        const importantProps = ['battery', 'batteryLow', 'wifiRssi', 'motionDetected', 'personDetected'];
        if (importantProps.includes(name)) {
            console.log(`🔧 ${device.getName()} - ${name}: ${value}`);
        }
    });

    // Sensor Events
    eufySecurity.on('device sensor open', (device, state) => {
        const event = logEvent('sensor_open', device.getName(), { 
            state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // Lock Events
    eufySecurity.on('device locked', (device, state) => {
        const event = logEvent('lock_status', device.getName(), { 
            locked: state,
            serial: device.getSerial()
        });
        handleEvent(event);
    });

    // ========== Push Notification Events (raw) ==========
    
    eufySecurity.on('push message', (message) => {
        // Raw push notifications - useful for debugging or capturing events
        // that don't have specific handlers
        console.log('📬 Raw push message:', JSON.stringify(message, null, 2));
    });

    // ========== Error Handling ==========
    
    eufySecurity.on('tfa request', () => {
        console.error('⚠️ Two-factor authentication required!');
        console.error('Please disable 2FA for your guest account or use the captcha workaround.');
    });

    eufySecurity.on('captcha request', (captchaId, captcha) => {
        console.error('⚠️ Captcha required! This usually happens after failed login attempts.');
        console.error('Captcha ID:', captchaId);
        // You would need to solve this captcha and call: 
        // eufySecurity.connect({ captcha: { captchaId, captchaCode: 'SOLVED_CODE' } });
    });

    // ========== Connect and Start ==========
    
    try {
        console.log('Connecting to Eufy Security...');
        await eufySecurity.connect();
        
        // List all discovered devices
        console.log('\n=== Discovered Devices ===');
        const devices = eufySecurity.getDevices();
        for (const [serial, device] of devices) {
            console.log(`- ${device.getName()} (${serial})`);
            console.log(`  Model: ${device.getModel()}`);
            console.log(`  Battery: ${device.getBattery()}%`);
            console.log(`  WiFi RSSI: ${device.getWifiRssi()}`);
        }
        console.log('==========================\n');

        console.log('🎯 Event monitoring active. Press Ctrl+C to stop.');
        
    } catch (error) {
        console.error('Failed to connect:', error.message);
        process.exit(1);
    }

    // Handle graceful shutdown
    process.on('SIGINT', async () => {
        console.log('\nShutting down...');
        await eufySecurity.close();
        process.exit(0);
    });

    process.on('SIGTERM', async () => {
        console.log('\nShutting down...');
        await eufySecurity.close();
        process.exit(0);
    });
}

// Run the main function
main().catch(console.error);
