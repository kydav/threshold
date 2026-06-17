import * as admin from 'firebase-admin';
import * as sgMail from '@sendgrid/mail';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

admin.initializeApp();

const sendgridApiKey = defineSecret('SENDGRID_API_KEY');
const fromEmail = defineSecret('SENDGRID_FROM_EMAIL');

interface Recipient {
  email: string;
  name: string;
}

interface SendAgreementData {
  recipients: Recipient[];
  agentName: string;
  agentEmail: string;
  subject: string;
  bodyText: string;
  pdfBase64: string;
  filename: string;
}

export const sendAgreementEmail = onCall(
  { secrets: [sendgridApiKey, fromEmail] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const {
      recipients,
      agentName,
      agentEmail,
      subject,
      bodyText,
      pdfBase64,
      filename,
    } = request.data as SendAgreementData;

    if (!recipients?.length || !pdfBase64 || !filename) {
      throw new HttpsError('invalid-argument', 'Missing required fields.');
    }

    sgMail.setApiKey(sendgridApiKey.value());

    const from = {
      email: fromEmail.value() || 'hello@auaha.app',
      name: `${agentName} via Threshold`,
    };

    for (const recipient of recipients) {
      await sgMail.send({
        to: recipient,
        from,
        replyTo: { email: agentEmail, name: agentName },
        subject,
        text: bodyText,
        attachments: [
          {
            content: pdfBase64,
            filename,
            type: 'application/pdf',
            disposition: 'attachment',
          },
        ],
      });
    }

    return { success: true };
  }
);
