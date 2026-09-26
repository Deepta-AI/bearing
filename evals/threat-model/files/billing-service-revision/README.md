# billing-service

Multi-tenant invoicing for clinics. Each clinic is a tenant; staff log in
with a session cookie. Payments are collected through Razorpay, which
calls our webhook when a payment is captured. Admins can bulk import
customers from a CSV exported from their old system.
