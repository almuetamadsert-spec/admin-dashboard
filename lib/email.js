/**
 * إرسال بريد إلكتروني للتجار (إشعار طلب جديد).
 * الإعدادات من متغيرات البيئة: MAIL_HOST, MAIL_PORT, MAIL_USER, MAIL_PASS, MAIL_FROM
 * إن لم تُضبط لا يُرسل أي بريد.
 */
let transporter = null;

function getTransporter() {
  if (transporter !== undefined) return transporter;
  const host = (process.env.MAIL_HOST || '').trim();
  const user = (process.env.MAIL_USER || '').trim();
  const pass = (process.env.MAIL_PASS || '').trim();
  if (!host || !user || !pass) {
    transporter = null;
    return null;
  }
  try {
    const nodemailer = require('nodemailer');
    transporter = nodemailer.createTransport({
      host,
      port: parseInt(process.env.MAIL_PORT || '587', 10),
      secure: process.env.MAIL_SECURE === '1' || process.env.MAIL_SECURE === 'true',
      auth: { user, pass }
    });
  } catch (e) {
    transporter = null;
  }
  return transporter;
}

/**
 * إرسال إيميل "طلب جديد" إلى عنوان واحد.
 * @param {string} to - البريد الإلكتروني للمستلم
 * @param {object} opts - { orderNumber, totalAmount, customerName?, customerPhone? }
 * @returns {Promise<{ ok: boolean, error?: string }>}
 */
function sendNewOrderEmail(to, opts = {}) {
  const t = getTransporter();
  if (!t) return Promise.resolve({ ok: false, error: 'mail_not_configured' });

  const from = (process.env.MAIL_FROM || process.env.MAIL_USER || '').trim();
  const orderNumber = opts.orderNumber || '';
  const totalAmount = Number(opts.totalAmount || 0).toFixed(2);
  const customerLine = [opts.customerName, opts.customerPhone].filter(Boolean).join(' — ') || '—';
  const subject = `طلب جديد ${orderNumber}`;
  const text = `طلب جديد: ${orderNumber}\nالعميل: ${customerLine}\nالمبلغ الإجمالي: ${totalAmount} د.ل`;

  return t.sendMail({ from, to: to.trim(), subject, text })
    .then(() => ({ ok: true }))
    .catch(err => ({ ok: false, error: err.message }));
}

/**
 * إرسال إيميل طلب جديد لجميع عناوين التجار المحددين (بدون انتظار).
 */
function sendNewOrderEmailToMerchants(emails, opts) {
  const list = (Array.isArray(emails) ? emails : [emails]).map(e => (e || '').trim()).filter(Boolean);
  if (list.length === 0) return Promise.resolve({ ok: true });
  return Promise.all(list.map(to => sendNewOrderEmail(to, opts))).then(() => ({ ok: true }));
}

module.exports = { getTransporter, sendNewOrderEmail, sendNewOrderEmailToMerchants };
