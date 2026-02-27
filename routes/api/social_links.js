const express = require('express');
const { getSettings } = require('../../lib/settings');

const router = express.Router();

const PLATFORMS = [
  { key: 'social_facebook_url', id: 'facebook', label: 'فيسبوك' },
  { key: 'social_instagram_url', id: 'instagram', label: 'انستقرام' },
  { key: 'social_whatsapp_url', id: 'whatsapp', label: 'واتساب' },
  { key: 'social_tiktok_url', id: 'tiktok', label: 'تيك توك' },
  { key: 'social_youtube_url', id: 'youtube', label: 'يوتيوب' },
  { key: 'social_twitter_url', id: 'twitter', label: 'تويتر' },
  { key: 'social_telegram_url', id: 'telegram', label: 'تيليجرام' },
];

/**
 * GET /api/social-links — روابط السوشيال ميديا وإعدادات شكل الأيقونات للتطبيق.
 */
router.get('/', async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  try {
    const db = req.db;
    const settings = await getSettings(db);
    const links = PLATFORMS
      .map((p) => ({
        id: p.id,
        label: p.label,
        url: (settings[p.key] || '').trim(),
      }))
      .filter((l) => l.url.length > 0);
    res.json({
      ok: true,
      links,
      icon_shape: settings.social_icon_shape || 'circle',
      icon_bg_color: settings.social_icon_bg_color || '#06A3E7',
      icon_symbol_color: settings.social_icon_symbol_color || '#ffffff',
    });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
});

module.exports = router;
