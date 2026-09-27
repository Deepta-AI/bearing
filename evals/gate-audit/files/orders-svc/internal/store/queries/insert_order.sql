INSERT INTO orders (customer_id, status, total_paise)
VALUES ($1, 'pending', $2)
RETURNING id, created_at;
