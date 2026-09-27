// Postgres access. The connection string comes from DATABASE_URL; the pg
// driver is loaded lazily so unit tests run without a database.
export async function connect() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is not set");
  const { default: pg } = await import("pg");
  const pool = new pg.Pool({ connectionString: url });
  return pool;
}
