const express = require('express');

const router = express.Router();

router.get('/', (req, res) => {
  const db = req.db;
  const list = db.prepare('SELECT * FROM activity_log ORDER BY id DESC LIMIT 200').all();
  res.render('activity/list', { list, adminUsername: req.session.adminUsername });
});

module.exports = router;
