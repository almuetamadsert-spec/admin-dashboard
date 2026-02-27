<?php
if (!defined('ABSPATH')) {
    return;
}

// ========================================================================
//  صفحة تتبع الطلب للعميل (بنفس تصميم الصورة المرفقة)
// ========================================================================
function libya_render_order_track_page_v14($order_id)
{
    $order = wc_get_order($order_id);
    if (!$order) {
        wp_die('الطلب غير موجود.');
    }
    $order_number = $order->get_order_number();
    $status = $order->get_status();
    $notified_processing = get_post_meta($order_id, LIBYA_META_NOTIFIED_PROCESSING, true) === 'yes';
    $contact_confirmed = get_post_meta($order_id, LIBYA_META_ATTENDANCE_CONFIRMED, true) === 'yes';
    $processing_since = (int) get_post_meta($order_id, LIBYA_META_PROCESSING_SINCE, true);
    $elapsed = $processing_since > 0 ? (time() - $processing_since) : 999;
    // بعد 3 ثوانٍ من ضغط "متوفر" ننتقل تلقائياً لعرض "سيتم التواصل معك الان" (يومض حتى يتصل التاجر أو يحوّل)
    $step2_done = $notified_processing && ($elapsed >= 3);
    $step3_done = $contact_confirmed;

    // المراحل: 1 تم الاستلام، 2 جاري تجهيز طلبك (يومض حتى مرور 3 ثوانٍ)، 3 سيتم التواصل معك الان (يومض حتى اتصال أو تحويل)، 4 تم التسليم / تعذر التسليم
    $step1_done = true; // الطلب وصل للمتجر
    $step4_done = $status === 'completed';
    $step4_rejected = $status === 'cancelled';

    $active_step = 0;
    if ($notified_processing && $elapsed < 3) $active_step = 2; // جاري التجهيز يومض أول 3 ثوانٍ بعد "متوفر"
    elseif ($notified_processing && !$step3_done) $active_step = 3; // سيتم التواصل معك الان يومض حتى اتصال التاجر أو تحويله
    elseif (!$step4_done && !$step4_rejected) $active_step = 4;

    // واتساب واتصال يتواصلان مع الدعم (المسؤول)
    $support_phone = defined('LIBYA_SUPPORT_PHONE_V14') ? LIBYA_SUPPORT_PHONE_V14 : '0914479920';
    $support_clean = preg_replace('/[^0-9]/', '', $support_phone);
    if (substr($support_clean, 0, 1) === '0') $support_clean = '218' . substr($support_clean, 1);
    $wa_url = 'https://wa.me/' . $support_clean;
    $tel_url = 'tel:' . preg_replace('/[^0-9+]/', '', $support_phone);

    $back_url = home_url('/');
    header('Content-Type: text/html; charset=utf-8');
?>
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">

    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>تتبع الطلب #<?php echo esc_html($order_number); ?></title>
        <style>
            * {
                box-sizing: border-box;
            }

            html,
            body {
                margin: 0;
                padding: 0;
                min-height: 100vh;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                background: #fff;
                color: #1a202c;
                display: flex;
                flex-direction: column;
            }

            .track-header {
                display: flex;
                align-items: center;
                justify-content: space-between;
                padding: 14px 16px;
                border-bottom: 1px solid #e2e8f0;
                flex-shrink: 0;
            }

            .track-header h1 {
                margin: 0;
                font-size: 18px;
                font-weight: 700;
            }

            .track-header a {
                color: #4a5568;
                text-decoration: none;
                display: flex;
                align-items: center;
            }

            .track-header a.track-close:hover {
                color: #1a202c;
            }

            .track-wrap {
                flex: 1;
                padding: 16px;
                display: flex;
                flex-direction: column;
                min-height: 0;
            }

            .track-card {
                background: #f7fafc;
                border-radius: 14px;
                padding: 24px 20px;
                flex: 1;
                border: 1px solid #e2e8f0;
                min-height: 280px;
            }

            .track-card h2 {
                margin: 0 0 24px 0;
                font-size: 17px;
                font-weight: 600;
                color: #2d3748;
            }

            .timeline {
                position: relative;
                padding-right: 0;
            }

            .timeline-item {
                display: flex;
                align-items: flex-start;
                gap: 16px;
                margin-bottom: 28px;
                position: relative;
                min-height: 44px;
            }

            .timeline-item:last-child {
                margin-bottom: 0;
            }

            .timeline-connector {
                position: absolute;
                right: 15px;
                top: 40px;
                bottom: -28px;
                width: 2px;
                background: #e2e8f0;
            }

            .timeline-item:last-child .timeline-connector {
                display: none;
            }

            .timeline-dot {
                width: 32px;
                height: 32px;
                border-radius: 50%;
                flex-shrink: 0;
                display: flex;
                align-items: center;
                justify-content: center;
                position: relative;
                z-index: 1;
            }

            .timeline-dot.done {
                background: #38a169;
                color: #fff;
            }

            .timeline-dot.active {
                background: #3182ce;
                color: #fff;
                animation: libya-pulse 1.2s ease-in-out infinite;
            }

            .timeline-dot.pending {
                background: #e2e8f0;
                color: #a0aec0;
            }

            .timeline-dot.rejected {
                background: #e53e3e;
                color: #fff;
                animation: libya-pulse-red 1.2s ease-in-out infinite;
            }

            @keyframes libya-pulse {

                0%,
                100% {
                    box-shadow: 0 0 0 0 rgba(49, 130, 206, 0.5);
                }

                50% {
                    box-shadow: 0 0 0 10px rgba(49, 130, 206, 0);
                }
            }

            @keyframes libya-pulse-red {

                0%,
                100% {
                    box-shadow: 0 0 0 0 rgba(229, 62, 62, 0.5);
                }

                50% {
                    box-shadow: 0 0 0 10px rgba(229, 62, 62, 0);
                }
            }

            .timeline-text {
                flex: 1;
                display: flex;
                align-items: center;
                min-height: 32px;
            }

            .timeline-text .label {
                font-size: 16px;
                font-weight: 600;
                color: #2d3748;
                line-height: 1.35;
            }

            .timeline-text.active .label {
                color: #3182ce;
            }

            .timeline-text .label.final-ok {
                color: #38a169;
            }

            .timeline-text .label.final-fail {
                color: #e53e3e;
            }

            .help-section {
                flex-shrink: 0;
                padding: 28px 16px 24px;
                text-align: center;
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
            }

            .help-section p {
                margin: 0 0 16px 0;
                font-size: 16px;
                color: #4a5568;
            }

            .help-btns {
                display: flex;
                gap: 14px;
                flex-wrap: wrap;
                justify-content: center;
                max-width: 320px;
            }

            .help-btn {
                display: inline-flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                padding: 16px 28px;
                border-radius: 12px;
                font-size: 16px;
                font-weight: 600;
                text-decoration: none;
                color: #fff;
                min-width: 150px;
            }

            .help-btn.wa {
                background: #25d366;
            }

            .help-btn.call {
                background: #3182ce;
            }
        </style>
    </head>

    <body>
        <script>
            document.addEventListener('DOMContentLoaded', function() {
                var btn = document.getElementById('libya-track-close');
                if (btn) btn.addEventListener('click', function(e) {
                    e.preventDefault();
                    window.close();
                    if (!window.closed) window.history.back();
                });
            });
        </script>
        <div class="track-header">
            <a href="#" class="track-close" id="libya-track-close" title="إغلاق"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <line x1="18" y1="6" x2="6" y2="18" />
                    <line x1="6" y1="6" x2="18" y2="18" />
                </svg></a>
            <h1>طلب #<?php echo esc_html($order_number); ?></h1>
            <span></span>
        </div>

        <div class="track-wrap">
            <div class="track-card">
                <h2>خط سير الطلب</h2>
                <div class="timeline">
                    <div class="timeline-item">
                        <span class="timeline-connector"></span>
                        <div class="timeline-dot <?php echo $step1_done ? 'done' : 'pending'; ?>"><?php if ($step1_done) { ?><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                    <polyline points="20 6 9 17 4 12" />
                                </svg><?php } ?></div>
                        <div class="timeline-text"><span class="label">تم الاستلام</span></div>
                    </div>
                    <div class="timeline-item">
                        <span class="timeline-connector"></span>
                        <div class="timeline-dot <?php echo $step2_done ? 'done' : ($active_step === 2 ? 'active' : 'pending'); ?>"><?php if ($step2_done) { ?><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                    <polyline points="20 6 9 17 4 12" />
                                </svg><?php } ?></div>
                        <div class="timeline-text <?php echo $active_step === 2 ? 'active' : ''; ?>"><span class="label">جاري تجهيز طلبك</span></div>
                    </div>
                    <div class="timeline-item">
                        <span class="timeline-connector"></span>
                        <div class="timeline-dot <?php echo $step3_done ? 'done' : ($active_step === 3 ? 'active' : 'pending'); ?>"><?php if ($step3_done) { ?><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                    <polyline points="20 6 9 17 4 12" />
                                </svg><?php } ?></div>
                        <div class="timeline-text <?php echo $active_step === 3 ? 'active' : ''; ?>"><span class="label">سيتم التواصل معك الان</span></div>
                    </div>
                    <div class="timeline-item">
                        <span class="timeline-connector"></span>
                        <div class="timeline-dot <?php echo $step4_done ? 'done' : ($step4_rejected ? 'rejected' : ($active_step === 4 ? 'active' : 'pending')); ?>"><?php if ($step4_done) { ?><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                                    <polyline points="20 6 9 17 4 12" />
                                </svg><?php } elseif ($step4_rejected) { ?><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <circle cx="12" cy="12" r="10" />
                                    <line x1="15" y1="9" x2="9" y2="15" />
                                    <line x1="9" y1="9" x2="15" y2="15" />
                                </svg><?php } ?></div>
                        <div class="timeline-text"><span class="label <?php echo $step4_done ? 'final-ok' : ($step4_rejected ? 'final-fail' : ''); ?>"><?php echo $step4_done ? 'تم التسليم' : ($step4_rejected ? 'تعذر التسليم' : ''); ?></span></div>
                    </div>
                </div>
            </div>

            <div class="help-section">
                <p>هل تحتاج مساعدة؟</p>
                <div class="help-btns">
                    <a class="help-btn wa" href="<?php echo esc_url($wa_url); ?>" target="_blank" rel="noopener">واتساب الدعم</a>
                    <a class="help-btn call" href="<?php echo esc_attr($tel_url); ?>">اتصال بالدعم</a>
                </div>
            </div>
        </div>
    </body>

    </html>
<?php
}
