const express = require('express');
const router = express.Router();

// List all sections
router.get('/', async (req, res) => {
    const db = req.db;
    const sections = await db.prepare('SELECT * FROM home_sections ORDER BY sort_order ASC').all();
    const categories = await db.prepare('SELECT id, name_ar FROM categories').all();
    res.render('home_sections/list', {
        sections,
        categories,
        title: 'إدارة الصفحة الرئيسية',
        adminUsername: req.session.adminUsername
    });
});

// Add new section
router.post('/add', async (req, res) => {
    const db = req.db;
    const { title_ar, title_en, section_type, content_source, category_id, items_limit, sort_order } = req.body;

    await db.prepare(`
    INSERT INTO home_sections (title_ar, title_en, section_type, content_source, category_id, items_limit, sort_order, is_active)
    VALUES (?, ?, ?, ?, ?, ?, ?, 1)
  `).run(title_ar, title_en, section_type, content_source, category_id || null, items_limit || 10, sort_order || 0);

    res.redirect('/admin/home-sections');
});

// Update section
router.post('/edit/:id', async (req, res) => {
    const db = req.db;
    const { title_ar, title_en, section_type, content_source, category_id, items_limit, sort_order } = req.body;

    await db.prepare(`
        UPDATE home_sections 
        SET title_ar = ?, title_en = ?, section_type = ?, content_source = ?, category_id = ?, items_limit = ?, sort_order = ?
        WHERE id = ?
    `).run(title_ar, title_en, section_type, content_source, category_id || null, items_limit || 10, sort_order || 0, req.params.id);

    res.redirect('/admin/home-sections');
});

// Delete section
router.post('/delete/:id', async (req, res) => {
    const db = req.db;
    await db.prepare('DELETE FROM home_sections WHERE id = ?').run(req.params.id);
    res.redirect('/admin/home-sections');
});

// Toggle status
router.post('/toggle/:id', async (req, res) => {
    const db = req.db;
    const section = await db.prepare('SELECT is_active FROM home_sections WHERE id = ?').get(req.params.id);
    if (section) {
        const newStatus = section.is_active === 1 ? 0 : 1;
        await db.prepare('UPDATE home_sections SET is_active = ? WHERE id = ?').run(newStatus, req.params.id);
    }
    res.redirect('/admin/home-sections');
});

module.exports = router;
