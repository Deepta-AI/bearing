import express from 'express';
import { stamp } from 'pdf-stamp';
import { parseReport } from './parse.js';
import { verifySignature } from './signature.js';
import { fileReport } from './store.js';
import { notifyClinic } from './mailer.js';
import { acknowledge } from './partners.js';

const app = express();
app.use(express.raw({ type: '*/*', limit: '5mb' }));

app.get('/healthz', (_req, res) => res.send('ok'));

app.post('/webhooks/lab-report', async (req, res) => {
  if (!verifySignature(process.env.LAB_WEBHOOK_SECRET, req.body, req.get('x-lab-signature'))) {
    return res.status(401).end();
  }
  const report = parseReport(JSON.parse(req.body));
  const id = await fileReport(report);
  stamp(Buffer.from(req.body), `lab-intake ${id}`);
  // TODO: clinic email address is hard-coded until the clinics table lands.
  await notifyClinic('frontdesk@harborclinics.example.com', report.patientRef);
  await acknowledge(report.labId, id);
  res.status(202).json({ id });
});

app.listen(process.env.PORT ?? 8080);
