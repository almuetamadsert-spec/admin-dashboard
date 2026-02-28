const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, 'data', 'shop.db');
const wasmDir = path.join(__dirname, 'node_modules', 'sql.js', 'dist');

async function fix() {
    try {
        console.log('Loading database...');
        const SQL = await initSqlJs({
            locateFile: file => path.join(wasmDir, file)
        });

        if (!fs.existsSync(dbPath)) {
            console.error('Database file not found at:', dbPath);
            return;
        }

        const buf = fs.readFileSync(dbPath);
        const db = new SQL.Database(new Uint8Array(buf));

        console.log('Updating stock...');
        db.exec("UPDATE products SET stock = 99 WHERE (stock = 0 OR stock IS NULL) AND is_active = 1");

        const data = db.export();
        fs.writeFileSync(dbPath, Buffer.from(data));
        console.log('Successfully updated stock for existing products.');
    } catch (err) {
        console.error('Error fixing database:', err);
    }
}

fix();
