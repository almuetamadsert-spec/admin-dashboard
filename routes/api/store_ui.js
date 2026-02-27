const express = require('express');
const { getSettings } = require('../../lib/settings');

const router = express.Router();

/** GET /api/store-ui/slider — شرائح الإعلانات ووقت التبديل وإعداد عرض المنتجات */
router.get('/slider', async (req, res) => {
  const db = req.db;
  const [slides, settings] = await Promise.all([
    db.prepare('SELECT id, image_path, corner_style, sort_order FROM store_slides ORDER BY sort_order ASC, id ASC').all(),
    getSettings(db)
  ]);
  const intervalSeconds = parseInt(settings.store_slider_interval || '5', 10) || 5;
  const productLayout = (settings.store_product_layout || 'grid_2').replace(/[^a-z0-9_]/g, '') || 'grid_2';
  const cardBg = settings.store_product_card_bg || '#ffffff';
  const cardRadius = settings.store_product_card_radius || 'rounded';
  const showAddToCart = settings.store_product_card_show_add_to_cart !== '0';
  const showBuyNow = settings.store_product_card_show_buy_now !== '0';
  const brandPos = settings.store_card_brand_position || 'left';
  const nameAlign = settings.store_card_name_align || 'right';
  const priceAlign = settings.store_card_price_align || 'right';
  const addBtnStyle = settings.store_card_add_btn_style || 'small_rounded';
  const addBtnPosition = settings.store_card_add_btn_position || 'right';
  const addBtnColor = settings.store_card_add_btn_color || '#06A3E7';
  const baseUrl = (req.protocol || 'http') + '://' + (req.get('host') || 'localhost:3000');
  res.json({
    ok: true,
    interval_seconds: Math.max(2, Math.min(60, intervalSeconds)),
    product_layout: ['grid_2', 'grid_3', 'slider'].includes(productLayout) ? productLayout : 'grid_2',
    product_card: {
      bg_color: cardBg,
      radius: ['sharp', 'rounded', 'medium'].includes(cardRadius) ? cardRadius : 'rounded',
      show_add_to_cart: !!showAddToCart,
      show_buy_now: !!showBuyNow,
      brand_position: ['left', 'right', 'top', 'bottom'].includes(brandPos) ? brandPos : 'left',
      name_align: ['left', 'center', 'right'].includes(nameAlign) ? nameAlign : 'right',
      price_align: ['left', 'center', 'right'].includes(priceAlign) ? priceAlign : 'right',
      add_btn_style: ['small_rounded', 'full_rounded', 'sharp'].includes(addBtnStyle) ? addBtnStyle : 'small_rounded',
      add_btn_position: ['left', 'right'].includes(addBtnPosition) ? addBtnPosition : 'right',
      add_btn_color: addBtnColor || '#06A3E7',
    },
    base_url: baseUrl,
    slides: slides.map(s => {
      const path = (s.image_path || '').replace(/^\/+/, '');
      return {
        id: s.id,
        image_url: path ? baseUrl + '/uploads/' + path : '',
        image_path: path,
        corner_style: s.corner_style || 'rounded'
      };
    })
  });
});

module.exports = router;
