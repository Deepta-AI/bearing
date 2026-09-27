import nodemailer from 'nodemailer';

const transport = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: 587,
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASSWORD },
});

export function notifyClinic(to, patientRef) {
  return transport.sendMail({
    from: 'reports@harborclinics.example.com',
    to,
    subject: `New lab report for ${patientRef}`,
    text: 'A new lab report has been filed. Open the clinic portal to view it.',
  });
}
