const express = require('express');
const router = express.Router();

/** إحصائيات الأداء للتجار (عدد الطلبات، تم التسليم، تحويل، ملغي/تعذر) */
router.get('/', async (req, res) => {
  const db = req.db;
  const merchants = await db.prepare(`
    SELECT m.id, m.name, m.store_name, m.email, c.name as city_name
    FROM merchants m
    LEFT JOIN cities c ON m.city_id = c.id
    ORDER BY m.name
  `).all();

  const statsByMerchant = {};
  for (const m of merchants) {
    statsByMerchant[m.id] = {
      merchant: m,
      total: 0,
      delivered: 0,
      cancelled: 0,
      totalSales: 0,
    };
  }

  const orders = await db.prepare(`
    SELECT merchant_id, status, total_amount
    FROM orders
    WHERE merchant_id IS NOT NULL
  `).all();

  for (const o of orders) {
    const mid = o.merchant_id;
    if (!statsByMerchant[mid]) continue;
    const s = statsByMerchant[mid];
    s.total++;
    if (o.status === 'delivered') {
      s.delivered++;
      s.totalSales += Number(o.total_amount) || 0;
    } else if (o.status === 'cancelled' || o.status === 'customer_refused') {
      s.cancelled++;
    }
  }

  const list = Object.values(statsByMerchant).map(s => ({
    ...s.merchant,
    total: s.total,
    delivered: s.delivered,
    cancelled: s.cancelled,
    totalSales: s.totalSales,
  }));

  res.render('merchant_stats/list', {
    list,
    adminUsername: req.session.adminUsername,
  });
});

module.exports = router;
