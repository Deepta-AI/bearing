# clinicdesk

Multi-tenant front desk software for outpatient clinics. Each clinic is a
tenant. Receptionists manage patients and doctors today; appointment
booking is the next feature.

- Database: PostgreSQL (see docs/adr/0001-use-postgres.md).
- Migrations: goose SQL files in `migrations/`, applied in order.
- Product docs: `docs/product/`.
