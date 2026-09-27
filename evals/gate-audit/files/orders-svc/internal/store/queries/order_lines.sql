SELECT ol.*
FROM order_lines ol
WHERE ol.order_id = $1
ORDER BY ol.sku;
