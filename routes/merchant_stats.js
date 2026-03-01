const express = require('express');
const router = express.Router();

/** إحصائيات الأداء للتجار (عدد الطلبات، تم التسليم، تحويل، ملغي/تعذر) */
router.get('/', async (req, res) => {
  const db = req.db;
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const q = req.query.q || '';
  const date_from = req.query.date_from || '';
  const date_to = req.query.date_to || '';
  const limit = 50;
  const offset = (page - 1) * limit;

  let whereOrders = ' 1=1 ';
  let whereMerchants = ' 1=1 ';
  const paramsOrders = [];
  const paramsMerchants = [];

  if (q.trim()) {
    const search = '%' + q.trim() + '%';
    whereMerchants += ' AND (m.name LIKE ? OR m.store_name LIKE ? OR m.email LIKE ?)';
    paramsMerchants.push(search, search, search);
  }

  if (date_from.trim()) {
    whereOrders += ' AND date(o.created_at) >= ?';
    paramsOrders.push(date_from.trim());
  }
  if (date_to.trim()) {
    whereOrders += ' AND date(o.created_at) <= ?';
    paramsOrders.push(date_to.trim());
  }

  // 1. Fetch Total Count for Pagination (filtered by merchant search)
  const totalRow = await db.prepare(`SELECT COUNT(*) as total FROM merchants m WHERE ${whereMerchants}`).get(...paramsMerchants);
  const totalCount = totalRow ? totalRow.total : 0;
  const totalPages = Math.ceil(totalCount / limit);

  // 2. Fetch Global Performance Totals (filtered by date range and potentially merchant search)
  const globalStatsRow = await db.prepare(`
    SELECT 
      COUNT(o.id) as totalOrders,
      SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END) as totalDelivered,
      SUM(CASE WHEN o.status IN ('cancelled', 'customer_refused') THEN 1 ELSE 0 END) as totalCancelled,
      SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) as totalSalesValue
    FROM orders o
    JOIN merchants m ON o.merchant_id = m.id
    WHERE ${whereOrders} AND ${whereMerchants}
  `).get(...paramsOrders, ...paramsMerchants);

  // 3. Fetch Paginated Merchant Stats (filtered by both)
  const list = await db.prepare(`
    SELECT m.id, m.name, m.store_name, m.email, c.name as city_name,
           COUNT(o.id) as total,
           SUM(CASE WHEN o.status = 'delivered' THEN 1 ELSE 0 END) as delivered,
           SUM(CASE WHEN o.status IN ('cancelled', 'customer_refused') THEN 1 ELSE 0 END) as cancelled,
           SUM(CASE WHEN o.status = 'delivered' THEN o.total_amount ELSE 0 END) as totalSales
    FROM merchants m
    LEFT JOIN cities c ON m.city_id = c.id
    LEFT JOIN orders o ON m.id = o.merchant_id AND ${whereOrders.replace(/o\./g, 'o.')}
    WHERE ${whereMerchants}
    GROUP BY m.id
    ORDER BY m.name
    LIMIT ? OFFSET ?
  `).all(...paramsOrders, ...paramsMerchants, limit, offset);

  res.render('merchant_stats/list', {
    list,
    currentPage: page,
    totalPages,
    totalCount,
    filters: { q, date_from, date_to },
    queryString: [q && 'q=' + encodeURIComponent(q), date_from && 'date_from=' + date_from, date_to && 'date_to=' + date_to].filter(Boolean).join('&'),
    globalStats: {
      totalOrders: globalStatsRow.totalOrders || 0,
      totalDelivered: globalStatsRow.totalDelivered || 0,
      totalCancelled: globalStatsRow.totalCancelled || 0,
      totalSalesValue: globalStatsRow.totalSalesValue || 0
    },
    adminUsername: req.session.adminUsername,
  });
});

module.exports = router;
