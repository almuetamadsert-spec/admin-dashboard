const path = require('path');
const fs = require('fs');

async function test() {
    const dbInit = require('./db/init');
    const db = await dbInit;

    const keys = await db.prepare('SELECT id, name, consumer_key, consumer_secret, is_active FROM api_keys').all();
    console.log('API Keys in DB:', JSON.stringify(keys, null, 2));

    const targetKey = 'ck_7406e875f6b39c44e347960e95a711c942ad76b455fe0b03';
    const targetSecret = 'cs_dd26ccc21d27aa75f8b294fc5ca9d1a6142b52444949fce0b0d8050fdf52ad26';

    const match = await db.prepare('SELECT id FROM api_keys WHERE consumer_key = ? AND consumer_secret = ? AND is_active = 1').get(targetKey, targetSecret);

    if (match) {
        console.log('Match found! ID:', match.id);
    } else {
        console.log('No match found for the keys in Config.dart');
    }

    process.exit(0);
}

test().catch(err => {
    console.error(err);
    process.exit(1);
});
