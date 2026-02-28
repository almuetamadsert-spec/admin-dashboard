const express = require('express');
const router = express.Router();

router.get('/', async (req, res) => {
    const db = req.db;

    try {
        // 1. Fetch active home sections
        const sections = await db.prepare(`
      SELECT * FROM home_sections 
      WHERE is_active = 1 
      ORDER BY sort_order ASC
    `).all();

        const homeData = [];

        for (const section of sections) {
            let products = [];

            // 2. Fetch products based on content_source
            if (section.content_source === 'latest') {
                products = await db.prepare(`
          SELECT id, name_ar, name_en, price, discount_percent, image_path, stock,
                 company, colors, sizes, storage_capacities, battery_capacities,
                 short_description, long_description
          FROM products WHERE is_active = 1 
          ORDER BY created_at DESC LIMIT ?
        `).all(section.items_limit);
            }
            else if (section.content_source === 'sale') {
                products = await db.prepare(`
          SELECT id, name_ar, name_en, price, discount_percent, image_path, stock,
                 company, colors, sizes, storage_capacities, battery_capacities,
                 short_description, long_description
          FROM products WHERE is_active = 1 AND discount_percent > 0 
          ORDER BY discount_percent DESC LIMIT ?
        `).all(section.items_limit);
            }
            else if (section.content_source === 'category' && section.category_id) {
                products = await db.prepare(`
          SELECT id, name_ar, name_en, price, discount_percent, image_path, stock,
                 company, colors, sizes, storage_capacities, battery_capacities,
                 short_description, long_description
          FROM products WHERE is_active = 1 AND category_id = ? 
          ORDER BY created_at DESC LIMIT ?
        `).all(section.category_id, section.items_limit);
            }
            else if (section.content_source === 'manual') {
                products = await db.prepare(`
          SELECT p.id, p.name_ar, p.name_en, p.price, p.discount_percent, p.image_path, p.stock,
                    p.company, p.colors, p.sizes, p.storage_capacities, p.battery_capacities,
                    p.short_description, p.long_description
          FROM products p
          JOIN home_section_items hsi ON p.id = hsi.product_id
          WHERE hsi.section_id = ? AND p.is_active = 1
          ORDER BY hsi.sort_order ASC
                    `).all(section.id);
            }

            // Format products
            const formattedProducts = products.map(p => {
                const price = Number(p.price) || 0;
                const discount = Number(p.discount_percent) || 0;
                return {
                    id: p.id,
                    name_ar: p.name_ar,
                    name_en: p.name_en,
                    price: price,
                    discount_percent: discount,
                    final_price: Math.round(price * (1 - discount / 100) * 100) / 100,
                    image_path: p.image_path,
                    stock: p.stock,
                    company: p.company,
                    colors: p.colors,
                    sizes: p.sizes,
                    storage_capacities: p.storage_capacities,
                    battery_capacities: p.battery_capacities,
                    description: p.long_description,
                    short_description: p.short_description
                };
            });

            homeData.push({
                id: section.id,
                title_ar: section.title_ar,
                title_en: section.title_en,
                section_type: section.section_type,
                products: formattedProducts
            });
        }

        res.json({ ok: true, sections: homeData });
    } catch (error) {
        console.error('Home API Error:', error);
        res.status(500).json({ ok: false, message: 'Internal Server Error' });
    }
});

module.exports = router;
