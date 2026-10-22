import { Receiver } from '@upstash/qstash';

function qstashReceiver() {
  const currentSigningKey = process.env.QSTASH_CURRENT_SIGNING_KEY;
  const nextSigningKey = process.env.QSTASH_NEXT_SIGNING_KEY;
  if (!currentSigningKey || !nextSigningKey) {
    throw new Error('QStash signing keys are not configured');
  }
  return new Receiver({ currentSigningKey, nextSigningKey });
}

export async function verifyQstashSignature({ signature, rawBody, url }) {
  const receiver = qstashReceiver();
  await receiver.verify({
    signature,
    body: rawBody,
    url,
  });
}
