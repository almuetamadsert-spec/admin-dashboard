const https = require('https');
const fs = require('fs');
const path = require('path');

/**
 * Downloads an image from a URL and saves it to the specified directory.
 * @param {string} url - The URL of the image to download.
 * @param {string} targetDir - The absolute path of the directory to save the image in.
 * @returns {Promise<string|null>} - The filename of the saved image, or null if it fails.
 */
async function downloadImage(url, targetDir) {
    if (!url || !url.startsWith('http')) return null;

    try {
        const ext = path.extname(new URL(url).pathname) || '.jpg';
        const filename = `prod_${Date.now()}_${Math.floor(Math.random() * 1000)}${ext}`;
        const filePath = path.join(targetDir, filename);

        if (!fs.existsSync(targetDir)) {
            fs.mkdirSync(targetDir, { recursive: true });
        }

        return new Promise((resolve, reject) => {
            https.get(url, (res) => {
                if (res.statusCode !== 200) {
                    resolve(null);
                    return;
                }

                const fileStream = fs.createWriteStream(filePath);
                res.pipe(fileStream);

                fileStream.on('finish', () => {
                    fileStream.close();
                    resolve(filename);
                });

                fileStream.on('error', (err) => {
                    fs.unlink(filePath, () => { }); // Cleanup
                    resolve(null);
                });
            }).on('error', (err) => {
                resolve(null);
            });
        });
    } catch (err) {
        console.error('Download error:', url, err.message);
        return null;
    }
}

module.exports = { downloadImage };
