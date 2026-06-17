import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import * as sgMail from '@sendgrid/mail';

admin.initializeApp();

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

export const sendAgreementEmail = functions.https.onCall(
  async (request: functions.https.CallableRequest<SendAgreementData>) => {
    const {
      recipients,
      agentName,
      agentEmail,
      subject,
      bodyText,
      pdfBase64,
      filename,
    } = request.data;

    if (!recipients?.length || !pdfBase64 || !filename) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields.'
      );
    }

    const apiKey = functions.config().sendgrid.api_key;
    const from = {
      email: functions.config().sendgrid.from_email || 'hello@auaha.app',
      name: `${agentName} via Threshold`,
    };

    sgMail.setApiKey(apiKey);

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
