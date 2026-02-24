const express = require('express');
const router = express.Router();

router.get('/', (req, res) => {
  const baseUrl = req.protocol + '://' + req.get('host');
  res.render('api-docs/index', {
    baseUrl,
    adminUsername: req.session.adminUsername
  });
});

module.exports = router;
