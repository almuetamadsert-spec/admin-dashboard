<?php
if (!defined('ABSPATH')) { return; }

function get_libya_system_scripts_v14()
{
    // إضافة SweetAlert2 للنافذة المنبثقة
    wp_enqueue_script('sweetalert2', 'https://cdn.jsdelivr.net/npm/sweetalert2@11', [], null, true);

    ob_start();
?>
    <!-- تحميل SweetAlert2 مباشرة لضمان العمل في الصفحات التي لا تحمل الفوتر -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <style>
        .swal2-popup {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
        }

        .swal2-title {
            font-size: 1.5em !important;
            margin-bottom: 0.5em !important;
        }

        .swal2-html-container {
            font-size: 1.1em !important;
        }

        .swal2-radio {
            display: grid !important;
            grid-template-columns: 1fr;
            gap: 10px;
            text-align: right;
        }

        .swal2-radio label {
            justify-content: flex-start !important;
            background: #f8fafc;
            padding: 10px;
            border-radius: 8px;
            border: 1px solid #cbd5e1;
            cursor: pointer;
            transition: all 0.2s;
        }

        .swal2-radio label:hover {
            background: #e2e8f0;
        }

        /* تصميم الأزرار الاحترافي - تحديث عالي الجودة */
        .libya-btn {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            border: none;
            cursor: pointer;
            transition: all 0.2s ease;
            outline: none;
            user-select: none;
            text-align: center;
            vertical-align: middle;
            position: relative;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            font-weight: 600;
            font-size: 13px;
            width: 100%;
            padding: 10px 15px;
            border-radius: 10px;
            margin: 0;
            text-decoration: none !important;
            box-shadow: none;
        }

        .libya-btn:active:not(:disabled) {
            transform: translateY(1px);
            opacity: 0.8;
        }

        .btn-green {
            background: linear-gradient(135deg, #059669 0%, #10b981 100%) !important;
            color: #ffffff !important;
            border: none !important;
        }

        .btn-red {
            background: linear-gradient(135deg, #dc3545 0%, #ef4444 100%) !important;
            color: #ffffff !important;
            border: none !important;
        }

        .btn-yellow {
            background: linear-gradient(135deg, #d97706 0%, #f59e0b 100%) !important;
            color: #ffffff !important;
            border: none !important;
        }

        .btn-primary {
            background: linear-gradient(135deg, #0284c7 0%, #04acf4 100%) !important;
            color: #ffffff !important;
            border: none !important;
        }

        .btn-icon {
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .btn-icon-circle {
            background: rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            padding: 4px;
            display: flex;
            width: 26px;
            height: 26px;
            align-items: center;
            justify-content: center;
        }

        .btn-icon-circle svg {
            stroke: currentColor;
        }

        .libya-btn {
            width: 100%;
            /* جميع الأزرار بنفس العرض */
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s ease;
            /* تأثير سلس */
        }

        /* عداد المهلة - نفس نمط الأزرار، تدرج أزرق الهوية والخط أبيض */
        #libya-deadline-timer {
            background: linear-gradient(135deg, #0284c7 0%, #04acf4 100%) !important;
            color: #ffffff !important;
            transition: opacity 0.35s ease, max-height 0.35s ease, margin 0.35s ease, padding 0.35s ease;
            border: none !important;
            padding: 14px 18px !important;
            border-radius: 10px !important;
            margin-bottom: 16px !important;
            text-align: center !important;
            font-weight: 600 !important;
            font-size: 14px !important;
            transition: all 0.5s ease !important;
        }

        /* عند قرب انتهاء الوقت — تدرج أحمر وخط أبيض */
        #libya-deadline-timer.low-time {
            background: linear-gradient(135deg, #dc3545 0%, #ef4444 100%) !important;
            color: #ffffff !important;
            border: none !important;
        }

        /* تأثير عند التمرير (للكمبيوتر) */
        .libya-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(0, 0, 0, 0.15);
        }

        /* تأثير عند الضغط */
        .libya-btn:active {
            transform: scale(0.96);
            box-shadow: 0 2px 6px rgba(0, 0, 0, 0.2);
        }

        /* تأثيرات خاصة لكل لون عند الضغط */
        .btn-primary:active {
            background: linear-gradient(135deg, #0369a1 0%, #0284c7 100%) !important;
            border-color: #0369a1 !important;
        }

        .btn-green:active {
            background: linear-gradient(135deg, #047857 0%, #059669 100%) !important;
            border-color: #065f46 !important;
        }

        .btn-yellow:active {
            background: linear-gradient(135deg, #b45309 0%, #d97706 100%) !important;
            border-color: #92400e !important;
        }

        .btn-red:active {
            background: linear-gradient(135deg, #c82333 0%, #dc3545 100%) !important;
            border-color: #bd2130 !important;
        }

        .libya-buttons-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            align-items: stretch;
            gap: 12px;
            margin-top: 12px;
        }

        .libya-buttons-grid>div {
            min-width: 0;
            width: 100%;
            transition: opacity 0.3s ease, max-height 0.3s ease, margin 0.3s ease;
        }

        .libya-buttons-grid>div.libya-btn-hiding {
            opacity: 0;
            max-height: 0;
            margin: 0;
            padding: 0;
            overflow: hidden;
            pointer-events: none;
        }

        .libya-post-confirm {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            grid-column: span 2;
            width: 100%;
        }

        .libya-post-confirm>div {
            min-width: 0;
        }

        .libya-buttons-grid .libya-btn,
        .libya-buttons-grid .libya-btn-link {
            min-height: 62px;
            height: 62px;
            box-sizing: border-box;
            display: flex !important;
            align-items: center;
            justify-content: center;
            padding: 10px 12px !important;
            font-size: 13px !important;
            line-height: 1.3 !important;
            white-space: normal !important;
            text-align: center;
            gap: 8px;
            border-radius: 10px;
        }

        .libya-call-confirm-link,
        .libya-wa-link,
        .libya-sms-link {
            -webkit-user-select: none;
            user-select: none;
            -webkit-touch-callout: none;
        }

        /* موبايل ووضعين (زرين أو أربعة) — ارتفاع وعرض منظم وأنيق */
        @media only screen and (max-width: 768px) {
            .libya-buttons-grid {
                gap: 10px;
            }

            .libya-post-confirm {
                gap: 10px;
            }

            .libya-buttons-grid .libya-btn,
            .libya-buttons-grid .libya-btn-link {
                min-height: 60px;
                height: 60px;
                font-size: 13px !important;
                padding: 10px 10px !important;
            }
        }

        @media only screen and (max-width: 480px) {
            .libya-buttons-grid {
                gap: 8px;
            }

            .libya-post-confirm {
                gap: 8px;
            }

            .libya-buttons-grid .libya-btn,
            .libya-buttons-grid .libya-btn-link {
                min-height: 58px;
                height: 58px;
                font-size: 12px !important;
                padding: 8px 8px !important;
                border-radius: 10px;
            }

            .btn-icon-circle {
                width: 22px;
                height: 22px;
            }

            #libya-deadline-timer {
                padding: 10px 12px !important;
                font-size: 13px !important;
            }
        }

        .btn-full {
            grid-column: span 2;
        }

        .btn-loading {
            background: #94a3b8 !important;
            border-bottom: 4px solid #64748b !important;
        }

        .btn-completed {
            opacity: 0.9;
        }

        @keyframes libya-spin {
            from {
                transform: rotate(0deg);
            }

            to {
                transform: rotate(360deg);
            }
        }

        /* رسائل النتائج */
        .libya-message {
            margin: 20px auto;
            padding: 16px 20px;
            border-radius: 8px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 500px;
            text-align: right;
            direction: rtl;
            line-height: 1.5;
        }

        .message-success {
            background-color: #d4edda;
            border: 1px solid #c3e6cb;
            color: #155724;
        }

        .message-error {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
        }

        .message-warning {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            color: #856404;
        }

        .message-header {
            font-weight: 600;
            margin-bottom: 8px;
        }

        .message-icon {
            margin-left: 8px;
            font-weight: bold;
        }

        .libya-buttons-container {
            text-align: center;
            margin: 20px 0;
        }

        #libya-result-message {
            min-height: 20px;
            margin-top: 20px;
        }

        /* إشعار الحالة — نمط أنيق (مربع بلون الحالة + رمز في مربع أصغر) */
        .libya-state-notification {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            padding: 16px 20px;
            border-radius: 12px;
            text-align: right;
            direction: rtl;
            font-size: 15px;
            font-weight: 600;
            line-height: 1.5;
            margin-top: 12px;
        }

        .libya-state-notification.libya-notif-green {
            background: linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%);
            color: #065f46;
        }

        .libya-state-notification.libya-notif-green .libya-notif-icon {
            background: #059669;
            color: #fff;
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .libya-state-notification.libya-notif-red {
            background: linear-gradient(135deg, #fee2e2 0%, #fecaca 100%);
            color: #991b1b;
        }

        .libya-state-notification.libya-notif-red .libya-notif-icon {
            background: #dc3545;
            color: #fff;
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .libya-state-notification.libya-notif-yellow {
            background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
            color: #92400e;
        }

        .libya-state-notification.libya-notif-yellow .libya-notif-icon {
            background: #d97706;
            color: #fff;
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .libya-state-notification.libya-notif-blue {
            background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
            color: #1e40af;
        }

        .libya-state-notification.libya-notif-blue .libya-notif-icon {
            background: #04acf4;
            color: #fff;
            width: 36px;
            height: 36px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }
    </style>

    <script>
        // وضع Debug - غيّر إلى true لتفعيل رسائل التنقيح
        const LIBYA_DEBUG = false;

        function debugLog() {
            if (LIBYA_DEBUG && console && console.log) console.log.apply(console, arguments);
        }

        document.addEventListener('DOMContentLoaded', function() {
            document.body.addEventListener('click', function(e) {
                var waEl = e.target.closest('.libya-wa-link');
                if (waEl) {
                    e.preventDefault();
                    var wa = waEl.getAttribute('data-wa');
                    var params = new URLSearchParams(window.location.search);
                    params.set('order_action', 'log_wa_open');
                    params.set('ajax', '1');
                    var logUrl = window.location.href.split('?')[0] + '?' + params.toString();
                    fetch(logUrl, {
                        method: 'GET',
                        headers: {
                            'X-Requested-With': 'XMLHttpRequest'
                        }
                    }).then(function() {
                        if (wa) window.location.href = 'https://wa.me/' + wa;
                    });
                    return;
                }
                var smsEl = e.target.closest('.libya-sms-link');
                if (smsEl) {
                    e.preventDefault();
                    var sms = smsEl.getAttribute('data-sms');
                    var params2 = new URLSearchParams(window.location.search);
                    params2.set('order_action', 'log_sms_open');
                    params2.set('ajax', '1');
                    var logUrl2 = window.location.href.split('?')[0] + '?' + params2.toString();
                    fetch(logUrl2, {
                        method: 'GET',
                        headers: {
                            'X-Requested-With': 'XMLHttpRequest'
                        }
                    }).then(function() {
                        if (sms) window.location.href = 'sms:' + sms;
                    });
                    return;
                }
                const callLink = e.target.closest('.libya-call-confirm-link');
                if (callLink) {
                    e.preventDefault();
                    var wrap = callLink.closest('.libya-call-btn-wrap');
                    if (!wrap) return;
                    var data = {};
                    try {
                        data = JSON.parse(wrap.getAttribute('data-ajax-payload') || '{}');
                    } catch (err) {
                        return;
                    }
                    var baseUrl = window.location.href.split('?')[0];
                    var params = new URLSearchParams(window.location.search);
                    params.delete('libya_action');
                    params.delete('order_action');
                    params.delete('admin_action');
                    params.delete('ajax');
                    params.set('order_action', 'confirm_attendance');
                    params.set('order_id', data.order_id);
                    params.set('m_email', data.m_email);
                    params.set('secret', data.secret);
                    params.set('libya_nonce', data.nonce);
                    var url = baseUrl + '?' + params.toString() + '&ajax=1';
                    fetch(url, {
                            method: 'GET',
                            headers: {
                                'X-Requested-With': 'XMLHttpRequest'
                            }
                        })
                        .then(function(r) {
                            return r.text();
                        })
                        .then(function(responseText) {
                            var result;
                            try {
                                result = JSON.parse(responseText);
                            } catch (e) {
                                result = {
                                    success: false
                                };
                            }
                            if (result.success) {
                                if (typeof window.libyaSwitchToExtraTime === 'function') window.libyaSwitchToExtraTime();
                                var grid = wrap.closest('.libya-buttons-grid');
                                if (grid) {
                                    var toHide = [];
                                    var preRejected = grid.querySelector('.libya-pre-confirm-rejected');
                                    if (preRejected) toHide.push(preRejected);
                                    grid.querySelectorAll('.libya-ajax-btn').forEach(function(b) {
                                        var w = b.closest('.libya-buttons-grid > div') || b.parentElement;
                                        if (w && b.dataset.action === 'transfer_order') toHide.push(w);
                                    });
                                    toHide.forEach(function(el) {
                                        el.classList.add('libya-btn-hiding');
                                    });
                                    var postConfirm = grid.querySelector('.libya-post-confirm');
                                    if (postConfirm) {
                                        postConfirm.style.opacity = '0';
                                        postConfirm.style.display = '';
                                        postConfirm.offsetHeight;
                                        postConfirm.style.transition = 'opacity 0.3s ease';
                                        postConfirm.style.opacity = '1';
                                    }
                                    setTimeout(function() {
                                        toHide.forEach(function(el) {
                                            el.style.display = 'none';
                                            el.classList.remove('libya-btn-hiding');
                                        });
                                    }, 320);
                                }
                                window.location.href = 'tel:' + (callLink.getAttribute('data-phone') || '');
                            } else {
                                alert(result.message || 'حدث خطأ');
                            }
                        })
                        .catch(function() {
                            alert('حدث خطأ في الاتصال');
                        });
                    return;
                }
                const btn = e.target.closest('.libya-ajax-btn');
                if (btn) {
                    e.preventDefault();
                    const action = btn.getAttribute('data-action');
                    let data = {};
                    try {
                        data = JSON.parse(btn.getAttribute('data-payload'));
                    } catch (err) {
                        console.error('Error parsing JSON payload', err);
                        return;
                    }

                    if (action === 'rejected' || action === 'transfer_order') {
                        if (typeof Swal !== 'undefined') {
                            showRejectionReasonPopup(btn.id, action, data);
                        } else {
                            // Fallback if Swal is not loaded
                            const reason = prompt(action === 'rejected' ? 'سبب عدم التسليم:' : 'سبب تحويل الطلب:');
                            if (reason) {
                                data.reason_key = 'custom';
                                data.reason_note = reason;
                                processLibyaAction(btn.id, action, data);
                            }
                        }
                    } else {
                        processLibyaAction(btn.id, action, data);
                    }
                }
            });
            document.body.addEventListener('contextmenu', function(e) {
                if (e.target.closest('.libya-call-confirm-link, .libya-wa-link, .libya-sms-link')) e.preventDefault();
            });
        });

        function showRejectionReasonPopup(buttonId, action, data) {
            const title = action === 'rejected' ? 'سبب عدم التسليم' : 'سبب تحويل الطلب';
            const confirmBtnText = action === 'rejected' ? 'تأكيد الرفض' : 'تأكيد التحويل';
            const confirmBtnColor = action === 'rejected' ? '#dc3545' : '#ffc107';

            Swal.fire({
                title: title,
                input: 'textarea',
                inputLabel: 'يرجى توضيح السبب:',
                inputPlaceholder: 'اكتب السبب هنا...',
                inputAttributes: {
                    'aria-label': 'اكتب السبب هنا'
                },
                inputValidator: (value) => {
                    if (!value) {
                        return 'يجب كتابة السبب للمتابعة';
                    }
                },
                showCancelButton: true,
                confirmButtonText: confirmBtnText,
                cancelButtonText: 'إلغاء',
                confirmButtonColor: confirmBtnColor
            }).then((result) => {
                if (result.isConfirmed) {
                    // نرسل النص المكتوب كـ reason_note ونضع المفتاح 'custom'
                    data.reason_key = 'custom';
                    data.reason_note = result.value;

                    processLibyaAction(buttonId, action, data);
                }
            });
        }

        function processLibyaAction(buttonId, action, data) {
            debugLog('processLibyaAction called:', {
                buttonId,
                action,
                data
            });

            const btn = document.getElementById(buttonId);
            if (!btn) {
                console.error('Button not found:', buttonId);
                return;
            }

            const container = btn.closest('.libya-buttons-container') || btn.parentElement;
            const resultDiv = document.getElementById('libya-result-message') || createResultDiv(container);

            // إخفاء جميع الأزرار الأخرى أثناء المعالجة
            container.querySelectorAll('.libya-ajax-btn').forEach(function(otherBtn) {
                if (otherBtn.id !== buttonId) {
                    var wrap = otherBtn.closest('.libya-buttons-grid > div') || otherBtn.parentElement;
                    if (wrap) wrap.style.display = 'none';
                }
            });

            // تحديث الزر للحالة قيد المعالجة
            const originalText = btn.querySelector('.btn-text').textContent;
            btn.disabled = true;
            btn.className = btn.className.replace(/btn-\w+/, 'btn-loading');
            btn.querySelector('.btn-icon').innerHTML = '○';
            btn.querySelector('.btn-text').textContent = 'جاري المعالجة...';

            // بناء URL الطلب
            // استخدام عنوان URL الأساسي مع الحفاظ على المسار الصحيح
            // في ووردبريس، window.location.pathname قد يكون المسار الفرعي للمجلد، نحتاج لرابط الصفحة الحالية
            const baseUrl = window.location.href.split('?')[0];
            const params = new URLSearchParams(window.location.search);

            // مسح البارامترات القديمة للإجراءات لتجنب التكرار
            params.delete('libya_action');
            params.delete('order_action');
            params.delete('admin_action');
            params.delete('ajax'); // مسح ajax القديم إن وجد

            // إضافة بارامترات الإجراء الجديد
            if (action === 'delivered' || action === 'rejected' || action === 'transfer_order' || action === 'confirm_processing' || action === 'confirm_attendance') {
                params.set('order_action', action);
                params.set('order_id', data.order_id);
                params.set('m_email', data.m_email);
                params.set('secret', data.secret);
                params.set('libya_nonce', data.nonce);

                if (data.reason_key) {
                    params.set('reason_key', data.reason_key);
                    params.set('reason_note', data.reason_note || '');
                }
            } else if (action === 'confirm_payment') {
                params.set('libya_action', action);
                params.set('m_email', data.m_email);
                params.set('secret', data.secret);
                params.set('libya_nonce', data.nonce);
            } else if (action === 'payment_received' || action === 'payment_not_received') {
                params.set('admin_action', action);
                params.set('m_email', data.m_email);
                params.set('secret', data.secret);
                params.set('libya_nonce', data.nonce);
            }

            // بناء الرابط النهائي
            const url = baseUrl + '?' + params.toString();
            debugLog('Request URL:', url + '&ajax=1');

            // إرسال طلب AJAX
            fetch(url + '&ajax=1', {
                    method: 'GET',
                    headers: {
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                })
                .then(response => response.text())
                .then(responseText => {
                    debugLog('Server Response:', responseText);
                    let result;
                    try {
                        result = JSON.parse(responseText);
                    } catch (e) {
                        console.error('JSON Parse Error:', e);
                        // محاولة استخراج رسالة الخطأ إذا كانت PHP Error
                        const errorMatch = responseText.match(/<b>Fatal error<\/b>:(.*?)<br/);
                        const cleanError = errorMatch ? errorMatch[1].trim() : 'حدث خطأ غير متوقع من السيرفر.';

                        result = {
                            success: false,
                            message: 'خطأ في النظام: ' + cleanError + ' (انظر للكونسول للتفاصيل)',
                            action: action
                        };
                    }

                    // التعامل مع حالة التوجيه (لـ confirm_processing)
                    if (result.redirect && result.content) {
                        document.body.innerHTML = result.content;
                        return;
                    }

                    // عرض النتيجة
                    if (result.success) {
                        if (action === 'confirm_attendance') {
                            if (typeof window.libyaSwitchToExtraTime === 'function') window.libyaSwitchToExtraTime();
                            var grid = container.querySelector('.libya-buttons-grid');
                            if (grid) {
                                var toHide = [];
                                var callWrap = grid.querySelector('.libya-call-btn-wrap');
                                if (callWrap) toHide.push(callWrap);
                                var preRejected = grid.querySelector('.libya-pre-confirm-rejected');
                                if (preRejected) toHide.push(preRejected);
                                grid.querySelectorAll('.libya-ajax-btn').forEach(function(b) {
                                    var wrap = b.closest('.libya-buttons-grid > div') || b.parentElement;
                                    if (wrap && (b.dataset.action === 'confirm_attendance' || b.dataset.action === 'transfer_order')) toHide.push(wrap);
                                });
                                toHide.forEach(function(el) {
                                    el.classList.add('libya-btn-hiding');
                                });
                                var postConfirm = grid.querySelector('.libya-post-confirm');
                                if (postConfirm) {
                                    postConfirm.style.opacity = '0';
                                    postConfirm.style.display = '';
                                    postConfirm.offsetHeight;
                                    postConfirm.style.transition = 'opacity 0.3s ease';
                                    postConfirm.style.opacity = '1';
                                }
                                setTimeout(function() {
                                    toHide.forEach(function(el) {
                                        el.style.display = 'none';
                                        el.classList.remove('libya-btn-hiding');
                                    });
                                }, 320);
                            }
                            resultDiv.innerHTML = getStateNotificationHtml('delivered', result.message);
                            resultDiv.style.marginTop = '12px';
                            setTimeout(function() {
                                resultDiv.innerHTML = '';
                            }, 4000);
                            return;
                        }

                        if (action === 'delivered' || action === 'rejected' || action === 'transfer_order') {
                            if (typeof window.libyaStopAndHideTimer === 'function') {
                                window.libyaStopAndHideTimer();
                            }
                            var contactWrap = document.querySelector('.libya-contact-links-wrap');
                            if (contactWrap) contactWrap.style.display = 'none';
                            var grid = container.querySelector('.libya-buttons-grid');
                            if (grid) {
                                grid.style.transition = 'opacity 0.25s ease';
                                grid.style.opacity = '0';
                                setTimeout(function() {
                                    grid.style.display = 'none';
                                    var notif = document.createElement('div');
                                    notif.innerHTML = getStateNotificationHtml(action, result.message);
                                    grid.parentNode.insertBefore(notif.firstElementChild, grid);
                                }, 260);
                            }
                            return;
                        }

                        resultDiv.innerHTML = getStateNotificationHtml('delivered', result.message);
                    } else {
                        // في حالة الخطأ، نبقي الزر ونظهر الرسالة تحته
                        showResult(btn, result, originalText, action);
                        showMessage(resultDiv, result);
                    }
                })
                .catch(error => {
                    console.error('خطأ في الطلب:', error);
                    showResult(btn, {
                        success: false,
                        message: 'حدث خطأ في الاتصال، يرجى المحاولة مرة أخرى'
                    }, originalText, action);
                    showMessage(resultDiv, {
                        success: false,
                        message: 'حدث خطأ في الاتصال: ' + error.message
                    });
                });
        }

        // دالة مساعدة لبناء الرابط (تم دمج منطقها في processLibyaAction لضمان الدقة)
        function buildActionUrl_deprecated(action, data) {
            return '';
        }

        function showResult(btn, result, originalText, action) {
            const icons = {
                delivered: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>',
                rejected: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>',
                transfer_order: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"></polyline><polyline points="1 20 1 14 7 14"></polyline><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path></svg>',
                confirm_payment: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>',
                payment_received: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>',
                payment_not_received: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>',
                confirm_processing: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle></svg>'
            };

            const completedTexts = {
                delivered: 'تم التسليم',
                rejected: 'تم الرفض',
                transfer_order: 'تم التحويل',
                confirm_payment: 'تم التأكيد',
                payment_received: 'تم الاستلام',
                payment_not_received: 'لم يتم الاستلام',
                confirm_processing: 'تم القبول'
            };

            if (result.success) {
                btn.className = btn.className.replace('btn-loading', 'btn-completed btn-' + getActionColor(action));
                btn.querySelector('.btn-icon').innerHTML = icons[action] || '✓';
                btn.querySelector('.btn-text').textContent = completedTexts[action] || 'تم بنجاح';
            } else {
                btn.className = btn.className.replace('btn-loading', 'btn-error');
                btn.style.backgroundColor = '#dc3545';
                btn.querySelector('.btn-icon').innerHTML = '✕';
                btn.querySelector('.btn-text').textContent = 'حدث خطأ';
                btn.disabled = false;
            }
        }

        function getActionColor(action) {
            const colors = {
                delivered: 'green',
                rejected: 'red',
                transfer_order: 'yellow',
                confirm_payment: 'green',
                payment_received: 'green',
                payment_not_received: 'red',
                confirm_processing: 'blue'
            };
            return colors[action] || 'info';
        }

        function getStateNotificationHtml(type, message) {
            var iconSvg = '';
            var notifClass = 'libya-notif-green';
            if (type === 'delivered') {
                notifClass = 'libya-notif-green';
                iconSvg = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
            } else if (type === 'rejected') {
                notifClass = 'libya-notif-red';
                iconSvg = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>';
            } else if (type === 'transfer_order') {
                notifClass = 'libya-notif-yellow';
                iconSvg = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="23 4 23 10 17 10"></polyline><polyline points="1 20 1 14 7 14"></polyline><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"></path></svg>';
            } else if (type === 'deadline1') {
                notifClass = 'libya-notif-yellow';
                iconSvg = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>';
            } else if (type === 'deadline2') {
                notifClass = 'libya-notif-green';
                iconSvg = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
            } else {
                iconSvg = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>';
            }
            return '<div class="libya-state-notification ' + notifClass + '"><span class="libya-notif-icon">' + iconSvg + '</span><span>' + message + '</span></div>';
        }
        window.getStateNotificationHtml = getStateNotificationHtml;

        function showMessage(resultDiv, result) {
            const messageClass = result.success ? 'message-success' : 'message-error';
            const icon = result.success ? '✓' : '✕';

            resultDiv.innerHTML = `
            <div class="libya-message ${messageClass}">
                <div class="message-header">
                    <span class="message-icon">${icon}</span>
                    <span>${result.success ? 'تم بنجاح' : 'حدث خطأ'}</span>
                </div>
                <div class="message-content">${result.message}</div>
            </div>
        `;
        }

        function createResultDiv(container) {
            const resultDiv = document.createElement('div');
            resultDiv.id = 'libya-result-message';
            container.parentNode.insertBefore(resultDiv, container.nextSibling);
            return resultDiv;
        }
    </script>
<?php
    return ob_get_clean();
}

function libya_ajax_styles_and_scripts_v14()
{
    // تم نقل الكود إلى get_libya_system_scripts_v14 لضمان التحميل المباشر
    return;
}