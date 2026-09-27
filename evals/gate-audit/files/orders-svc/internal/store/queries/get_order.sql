SELECT id, customer_id, status, total_paise, created_at
FROM orders
WHERE id = $1;
