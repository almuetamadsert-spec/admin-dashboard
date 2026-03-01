const express = require('express');

const router = express.Router();

router.get('/', async (req, res) => {
  const db = req.db;
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = 50;
  const offset = (page - 1) * limit;

  const totalRow = await db.prepare('SELECT COUNT(*) as total FROM activity_log').get();
  const totalCount = totalRow ? totalRow.total : 0;
  const totalPages = Math.ceil(totalCount / limit);

  const list = await db.prepare('SELECT * FROM activity_log ORDER BY id DESC LIMIT ? OFFSET ?').all(limit, offset);

  res.render('activity/list', {
    list,
    currentPage: page,
    totalPages,
    totalCount,
    adminUsername: req.session.adminUsername
  });
});

module.exports = router;
