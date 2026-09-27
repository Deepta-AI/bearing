SELECT *
FROM orders
WHERE customer_id = $1
ORDER BY created_at DESC
LIMIT $2;
