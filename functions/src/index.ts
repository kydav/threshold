import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';

admin.initializeApp();

// Auaha's own Resend account (not a client's), with auaha.app verified.
const resendApiKey = defineSecret('RESEND_API_KEY');

const FROM_ADDRESS = 'agreements@auaha.app';

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

/** A display name safe inside "Name <address>". */
const displayName = (s: string) => (s || '').replace(/[<>"\r\n]/g, '').trim();

/**
 * Emails a signed agreement PDF to each recipient, separately (buyers don't
 * see each other's addresses), from agreements@auaha.app with replies going
 * to the agent. Signed-in agents only, so it can't be used to send mail as
 * auaha.app.
 */
export const sendAgreementEmail = onCall(
  {
    secrets: [resendApiKey],
    region: 'us-central1',
    invoker: 'public',
    memory: '256MiB',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to send agreements.');
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

    if (!recipients?.length || recipients.length > 5 || !pdfBase64 || !filename) {
      throw new HttpsError('invalid-argument', 'Missing or invalid fields.');
    }

    const from = `${displayName(agentName) || 'Your agent'} via Threshold <${FROM_ADDRESS}>`;
    for (const r of recipients) {
      if (!r?.email || !r.email.includes('@')) continue;
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${resendApiKey.value()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to: [r.name ? `${displayName(r.name)} <${r.email}>` : r.email],
          reply_to: agentEmail || undefined,
          subject,
          text: bodyText,
          attachments: [{ filename, content: pdfBase64 }],
        }),
      });
      if (!res.ok) {
        console.error('Resend error', res.status, await res.text());
        throw new HttpsError('unavailable', 'Email service rejected the send.');
      }
    }
    return { success: true };
  }
);
export { mapFormFields } from './mapFields';
export { startFormMapping, processFormJob, getFormJob, confirmFormMap } from './formJobs';
