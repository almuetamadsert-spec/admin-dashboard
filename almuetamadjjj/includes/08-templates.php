<?php
/**
 * نظام المعتمد – قوالب الرسائل والأزرار
 */
if (!defined('ABSPATH')) { return; }

function get_libya_msg_template_v14($title, $content, $footer = 'المعتمد | 0914479920', $type = 'info', $show_check = false, $is_admin_email = false)
{
    $colors = ['info' => '#04acf4', 'success' => '#28a745', 'warning' => '#ffc107', 'danger' => '#dc3545', 'primary' => '#04acf4', 'secondary' => '#6c757d'];
    $color = $colors[$type] ?? $colors['info'];
    $text_color = ($type === 'warning') ? '#1a202c' : '#ffffff';

    $icons = [
        'info'    => '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-bottom:15px;color:#04acf4"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>',
        'success' => '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-bottom:15px;color:#28a745"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>',
        'warning' => '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-bottom:15px;color:#ffc107"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>',
        'danger'  => '<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-bottom:15px;color:#dc3545"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>'
    ];
    $icon = $show_check ? $icons['success'] : ($icons[$type] ?? $icons['info']);

    $scripts = get_libya_system_scripts_v14();

    $box_shadow = $is_admin_email ? '' : 'box-shadow: 0 2px 5px rgba(0,0,0,0.02);';

    return "
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    {$scripts}
    <style>
        @media only screen and (max-width: 600px) {
            .container-v14 { width: 100% !important; margin: 0 !important; border-radius: 0 !important; }
            .content-v14 { padding: 20px !important; }
            .title-v14 { font-size: 18px !important; }
        }
    </style>
    <div class='container-v14' dir='rtl' style='font-family: \"Segoe UI\", Tahoma, Geneva, Verdana, sans-serif; width: 95%; max-width: 600px; margin: 20px auto; border: 1px solid #eef2f7; border-radius: 16px; overflow: hidden; {$box_shadow} background-color: #f9fafb;'>
        <div style='background-color: #ffffff; border-bottom: 2px solid {$color}; padding: 25px 20px; text-align: center;'>
            <div style='display: inline-block;'>{$icon}</div>
            <h2 class='title-v14' style='color: #1a202c; margin: 10px 0 0 0; font-size: 22px; font-weight: 800; line-height: 1.3;'>{$title}</h2>
        </div>
        <div class='content-v14' style='padding: 30px 25px; line-height: 1.8; color: #4a5568; font-size: 16px; text-align: center;'>
            <div style='margin-bottom: 0;'>{$content}</div>
        </div>
        " . ($footer ? "<div style='background-color: #e2e8f0; padding: 20px; border-top: 1px solid #cbd5e1; text-align: center; font-size: 13px; color: #718096; font-weight: 500;'>{$footer}</div>" : "") . "
    </div>";
}

function get_libya_btn_v14($text, $url, $color_type = 'info', $large = false)
{
    $colors = ['green' => '#38a169', 'yellow' => '#ecc94b', 'red' => '#e53e3e', 'info' => '#04acf4', 'blue' => '#04acf4', 'primary' => '#04acf4', 'light-blue' => '#bae6fd'];
    $bg = $colors[$color_type] ?? $colors['info'];
    $txt = ($color_type === 'yellow' || $color_type === 'light-blue') ? '#0369a1' : '#ffffff';
    $url_safe = esc_url($url);
    $fs = $large ? '18px' : '16px';
    $fw = $large ? '800' : '700';
    return "<div style='text-align: center; margin: 20px 0;'><a href='{$url_safe}' target='_blank' style='display: inline-block; width: 200px; padding: 14px 0; background-color: {$bg}; color: {$txt}; text-decoration: none; border-radius: 12px; font-weight: {$fw}; font-size: {$fs}; text-align: center; box-shadow: 0 2px 6px rgba(0,0,0,0.05);'>{$text}</a></div>";
}

function get_libya_ajax_btn_v14($text, $action, $data, $color_type = 'info', $icon = '')
{
    $colors = [
        'green' => ['bg' => '#28a745', 'txt' => '#ffffff'],
        'red' => ['bg' => '#dc3545', 'txt' => '#ffffff'],
        'yellow' => ['bg' => '#ffc107', 'txt' => '#212529'],
        'blue' => ['bg' => '#17a2b8', 'txt' => '#ffffff'],
        'info' => ['bg' => '#17a2b8', 'txt' => '#ffffff']
    ];
    $color = $colors[$color_type] ?? $colors['info'];
    $btn_id = 'libya-btn-' . uniqid();
    $icon_html = "<span class='btn-icon'>{$icon}</span>";

    $data_json = htmlspecialchars(json_encode($data), ENT_QUOTES, 'UTF-8');

    return "<div style='text-align: center; margin: 10px 5px; display: inline-block; width: 100%; max-width: 200px;'>
        <button id='{$btn_id}' 
                class='libya-btn libya-ajax-btn btn-{$color_type}' 
                data-action='{$action}'
                data-payload='{$data_json}'
                style='display: block; width: 100%; padding: 10px 8px; font-size: 13px; line-height: 1.25; white-space: normal; text-align: center;'>
            {$icon_html}
            <span class='btn-text'>{$text}</span>
        </button>
    </div>";
}
