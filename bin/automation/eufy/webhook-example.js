/**
 * Eufy Event Webhook Example
 * 
 * This variant sends events to a webhook endpoint and can also
 * save thumbnails/snapshots when events occur.
 */

const { EufySecurity } = require('eufy-security-client');
const fs = require('fs');
const path = require('path');

const config = {
    username: process.env.EUFY_USERNAME,
    password: process.env.EUFY_PASSWORD,
    country: process.env.EUFY_COUNTRY || 'US',
    language: 'en',
    persistentDir: './data',
    p2pConnectionSetup: 2,
};

// Webhook configuration
const WEBHOOK_URL = process.env.WEBHOOK_URL || 'http://localhost:3000/eufy-events';
const SAVE_THUMBNAILS = process.env.SAVE_THUMBNAILS === 'true';
const THUMBNAIL_DIR = './thumbnails';

if (SAVE_THUMBNAILS && !fs.existsSync(THUMBNAIL_DIR)) {
    fs.mkdirSync(THUMBNAIL_DIR, { recursive: true });
}

if (!fs.existsSync(config.persistentDir)) {
    fs.mkdirSync(config.persistentDir, { recursive: true });
}

/**
 * Send event to webhook
 */
async function sendWebhook(eventType, deviceName, deviceSerial, data) {
    const payload = {
        timestamp: new Date().toISOString(),
        event_type: eventType,
        device_name: deviceName,
        device_serial: deviceSerial,
        data: data
    };

    try {
        const response = await fetch(WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Eufy-Event': eventType
            },
            body: JSON.stringify(payload)
        });
        
        if (!response.ok) {
            console.error(`Webhook failed: ${response.status} ${response.statusText}`);
        } else {
            console.log(`✅ Webhook sent: ${eventType} from ${deviceName}`);
        }
    } catch (error) {
        console.error('Webhook error:', error.message);
    }
    
    return payload;
}

/**
 * Download and save thumbnail from a camera
 */
async function saveThumbnail(eufySecurity, device, eventType) {
    if (!SAVE_THUMBNAILS) return null;
    
    try {
        const imageUrl = device.getLastCameraImageURL();
        if (!imageUrl) return null;
        
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const filename = `${device.getSerial()}_${eventType}_${timestamp}.jpg`;
        const filepath = path.join(THUMBNAIL_DIR, filename);
        
        // The eufy-security-client handles authentication for image URLs
        console.log(`📸 Saving thumbnail: ${filename}`);
        
        // You would need to implement the actual download here
        // This is a placeholder showing the concept
        return filepath;
        
    } catch (error) {
        console.error('Thumbnail save error:', error.message);
        return null;
    }
}

async function main() {
    console.log('Starting Eufy Security Webhook Monitor...');
    console.log(`Webhook URL: ${WEBHOOK_URL}`);
    console.log(`Save thumbnails: ${SAVE_THUMBNAILS}`);

    const eufySecurity = await EufySecurity.initialize(config);

    // Connection events
    eufySecurity.on('connect', () => {
        console.log('✅ Connected to Eufy Security');
        sendWebhook('connection', 'system', 'system', { status: 'connected' });
    });

    eufySecurity.on('close', () => {
        console.log('❌ Disconnected from Eufy Security');
        sendWebhook('connection', 'system', 'system', { status: 'disconnected' });
    });

    // Motion detection
    eufySecurity.on('device motion detected', async (device, state) => {
        if (state) {  // Only trigger on state=true (motion started)
            const thumbnail = await saveThumbnail(eufySecurity, device, 'motion');
            await sendWebhook('motion_detected', device.getName(), device.getSerial(), {
                thumbnail_path: thumbnail,
                battery: device.getBattery()
            });
        }
    });

    // Person detection
    eufySecurity.on('device person detected', async (device, state, person) => {
        if (state) {
            const thumbnail = await saveThumbnail(eufySecurity, device, 'person');
            await sendWebhook('person_detected', device.getName(), device.getSerial(), {
                person_name: person || 'unknown',
                thumbnail_path: thumbnail,
                battery: device.getBattery()
            });
        }
    });

    // Pet detection
    eufySecurity.on('device pet detected', async (device, state) => {
        if (state) {
            const thumbnail = await saveThumbnail(eufySecurity, device, 'pet');
            await sendWebhook('pet_detected', device.getName(), device.getSerial(), {
                thumbnail_path: thumbnail
            });
        }
    });

    // Vehicle detection
    eufySecurity.on('device vehicle detected', async (device, state) => {
        if (state) {
            const thumbnail = await saveThumbnail(eufySecurity, device, 'vehicle');
            await sendWebhook('vehicle_detected', device.getName(), device.getSerial(), {
                thumbnail_path: thumbnail
            });
        }
    });

    // Doorbell
    eufySecurity.on('device rings', async (device, state) => {
        if (state) {
            const thumbnail = await saveThumbnail(eufySecurity, device, 'doorbell');
            await sendWebhook('doorbell_ring', device.getName(), device.getSerial(), {
                thumbnail_path: thumbnail
            });
        }
    });

    // Sensor events
    eufySecurity.on('device sensor open', async (device, state) => {
        await sendWebhook('sensor_state', device.getName(), device.getSerial(), {
            open: state
        });
    });

    // Lock events
    eufySecurity.on('device locked', async (device, state) => {
        await sendWebhook('lock_state', device.getName(), device.getSerial(), {
            locked: state
        });
    });

    // Raw push messages (for debugging or custom handling)
    eufySecurity.on('push message', async (message) => {
        // Uncomment to send all raw push messages:
        // await sendWebhook('raw_push', 'system', message.device_sn || 'unknown', message);
    });

    // Error handling
    eufySecurity.on('tfa request', () => {
        console.error('⚠️ Two-factor authentication required!');
        sendWebhook('error', 'system', 'system', { error: '2FA required' });
    });

    try {
        await eufySecurity.connect();
        
        console.log('\n=== Devices ===');
        for (const [serial, device] of eufySecurity.getDevices()) {
            console.log(`- ${device.getName()} (${serial})`);
        }
        console.log('===============\n');
        
        console.log('🎯 Monitoring active. Events will be sent to webhook.');
        
    } catch (error) {
        console.error('Connection failed:', error.message);
        process.exit(1);
    }

    // Graceful shutdown
    const shutdown = async () => {
        console.log('\nShutting down...');
        await sendWebhook('connection', 'system', 'system', { status: 'shutdown' });
        await eufySecurity.close();
        process.exit(0);
    };
    
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
}

main().catch(console.error);
