/**
 * إعداد Socket.io للإشعارات الفورية للتجار.
 * التاجر يتصل ويرسل التوكن في handshake.auth.token؛ نتحقق منه ونجعله ينضم لغرفة مدينةه city:${cityId}.
 * عند إنشاء طلب جديد نرسل حدث new_order لغرفة مدينة الطلب فقط.
 */

function setupSocket(io, getDb) {
  io.use((socket, next) => {
    const db = typeof getDb === 'function' ? getDb() : getDb;
    if (!db) return next();

    const token = (socket.handshake.auth && socket.handshake.auth.token) || (socket.handshake.query && socket.handshake.query.token) || '';
    if (!token) {
      socket.merchantCityId = null;
      return next();
    }

    (async () => {
      try {
        const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
        const session = await db.prepare(`
          SELECT s.user_id, u.id, u.email, u.role, u.merchant_id
          FROM app_sessions s
          JOIN app_users u ON u.id = s.user_id
          WHERE s.token = ? AND s.expires_at > ?
        `).get(token, now);
        if (!session || session.role !== 'merchant' || session.merchant_id == null) {
          socket.merchantCityId = null;
          return next();
        }
        const merchant = await db.prepare('SELECT city_id FROM merchants WHERE id = ?').get(session.merchant_id);
        const cityId = merchant && merchant.city_id != null ? merchant.city_id : null;
        socket.merchantId = session.merchant_id;
        socket.merchantCityId = cityId;
        next();
      } catch (e) {
        socket.merchantCityId = null;
        next();
      }
    })();
  });

  io.on('connection', (socket) => {
    if (socket.merchantCityId != null) {
      const room = 'city:' + socket.merchantCityId;
      socket.join(room);
    }
  });

  return io;
}

/**
 * إرسال إشعار طلب جديد للتجار في مدينة معينة.
 * استدعِها من مسار إنشاء الطلب بعد الإدراج.
 * @param {object} io - نسخة Socket.io
 * @param {number} cityId - معرف مدينة الطلب
 * @param {object} payload - { order_id, order_number, total_amount, city_id }
 */
function emitNewOrder(io, cityId, payload) {
  if (!io || cityId == null) return;
  io.to('city:' + cityId).emit('new_order', payload);
}

module.exports = { setupSocket, emitNewOrder };
