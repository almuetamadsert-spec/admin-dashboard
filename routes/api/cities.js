const express = require('express');

const router = express.Router();

router.get('/', async (req, res) => {
  const db = req.db;
  const cities = await db.prepare('SELECT id, name, delivery_fee FROM cities WHERE is_active = 1 ORDER BY name').all();
  res.json({ ok: true, cities });
});

module.exports = router;
