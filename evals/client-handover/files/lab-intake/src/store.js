import pg from 'pg';

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

export async function fileReport(report) {
  // TODO: move to a unique index on (lab_id, patient_ref, collected_at); see the July postmortem.
  const { rows } = await pool.query(
    `INSERT INTO reports (lab_id, patient_ref, collected_at, results)
     VALUES ($1, $2, $3, $4) RETURNING id`,
    [report.labId, report.patientRef, report.collectedAt, JSON.stringify(report.results)],
  );
  return rows[0].id;
}
