<?php
/**
 * نظام المعتمد – حقل المدينة في صفحة الدفع
 */
if (!defined('ABSPATH')) { return; }

add_filter('woocommerce_billing_fields', 'fix_libya_cities_dropdown_v14', 100);
function fix_libya_cities_dropdown_v14($fields)
{
    $merchants = get_libya_merchants_v14();
    $cities = [];
    foreach ($merchants as $m) {
        $cities[$m['city']] = $m['city'];
    }
    $options = array('' => 'الرجاء اختيار المدينة...');
    foreach ($cities as $city) {
        $options[$city] = $city;
    }

    if (isset($fields['billing_city'])) {
        $fields['billing_city']['type'] = 'select';
        $fields['billing_city']['options'] = $options;
        $fields['billing_city']['class'] = array('form-row-wide', 'address-field', 'update_totals_on_change');
        $fields['billing_city']['required'] = true;
    }
    return $fields;
}
