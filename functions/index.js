// Deploy marker: forces redeploy to pick up rotated functions.config() secrets (2026-09-01)
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config({ path: '../.env' });
admin.initializeApp();

const GEMINI_BASE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models';
const GRAPH_TOKEN_URL_BASE = 'https://login.microsoftonline.com';
const GRAPH_API_BASE = 'https://graph.microsoft.com/v1.0';

exports.financeAiReport = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const authHeader = req.headers.authorization || '';
  if (!authHeader.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing Firebase auth token' });
    return;
  }
  try {
    await admin.auth().verifyIdToken(authHeader.substring('Bearer '.length));
  } catch (error) {
    res.status(401).json({ error: 'Invalid Firebase auth token' });
    return;
  }

  const configKey =
    typeof functions.config === 'function'
      ? functions.config()?.ai?.api_key
      : undefined;
  const configModel =
    typeof functions.config === 'function'
      ? functions.config()?.ai?.model
      : undefined;
  const apiKey = process.env.AI_API_KEY || configKey;
  const model = process.env.AI_MODEL || configModel || 'gemini-2.0-flash';
  if (!apiKey) {
    res.status(500).json({ error: 'AI_API_KEY is not configured' });
    return;
  }

  try {
    const payload = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const prompt = buildPrompt(payload || {});

    const response = await fetch(
      `${GEMINI_BASE_URL}/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 500,
        },
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      res.status(500).json({
        error: `AI request failed: ${response.status} ${text}`,
      });
      return;
    }

    const data = await response.json();
    const text =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ||
      'No feedback generated.';

    res.status(200).json({ text });
  } catch (error) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

exports.sendStyledMeetingInvitation = functions.https.onRequest(
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    try {
      const authHeader = req.headers.authorization || '';
      if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing Firebase auth token' });
        return;
      }

      const firebaseToken = authHeader.substring('Bearer '.length);
      const decodedToken = await admin.auth().verifyIdToken(firebaseToken);
      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(decodedToken.uid)
        .get();

      if (!userDoc.exists) {
        res.status(403).json({ error: 'User profile not found' });
        return;
      }

      const userData = userDoc.data() || {};
      const isAdmin = userData.role === 'admin';
      const canEditMeetings =
        isAdmin ||
        userData.sectionPermissions?.meetingsEdit === true;

      if (!canEditMeetings) {
        res.status(403).json({ error: 'You do not have permission to send meeting invitations' });
        return;
      }

      const payload =
        typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
      const recipientEmail = String(payload.recipientEmail || '').trim();
      const recipientName = String(payload.recipientName || '').trim();
      const subject = String(payload.subject || '').trim();
      const htmlBody = String(payload.htmlBody || '').trim();

      if (!recipientEmail || !subject || !htmlBody) {
        res.status(400).json({
          error: 'recipientEmail, subject, and htmlBody are required',
        });
        return;
      }

      const graphAccessToken = await getMicrosoftGraphAccessToken();
      const senderUserId = getMicrosoftEmailConfig().senderUserId;
      const sendMailResponse = await fetch(
        `${GRAPH_API_BASE}/users/${encodeURIComponent(senderUserId)}/sendMail`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${graphAccessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              subject,
              body: {
                contentType: 'HTML',
                content: htmlBody,
              },
              toRecipients: [
                {
                  emailAddress: {
                    address: recipientEmail,
                    ...(recipientName ? { name: recipientName } : {}),
                  },
                },
              ],
            },
            saveToSentItems: true,
          }),
        },
      );

      if (!sendMailResponse.ok) {
        const errorText = await sendMailResponse.text();
        res.status(500).json({
          error: `Microsoft Graph sendMail failed: ${sendMailResponse.status} ${errorText}`,
        });
        return;
      }

      res.status(200).json({ success: true });
    } catch (error) {
      res.status(500).json({ error: error?.message || String(error) });
    }
  },
);

exports.sendEmailWithAttachment = functions.https.onRequest(
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    try {
      const authHeader = req.headers.authorization || '';
      if (!authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing Firebase auth token' });
        return;
      }

      const firebaseToken = authHeader.substring('Bearer '.length);
      const decodedToken = await admin.auth().verifyIdToken(firebaseToken);

      const payload =
        typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
      const requestId = String(payload.requestId || '').trim();
      const recipientEmail = String(payload.recipientEmail || '').trim();
      const recipientName = String(payload.recipientName || '').trim();
      const subject = String(payload.subject || '').trim();
      const htmlBody = String(payload.htmlBody || '').trim();
      const attachmentBase64 = String(payload.attachmentBase64 || '').trim();
      const attachmentName = String(payload.attachmentName || '').trim();

      if (!requestId || !recipientEmail || !subject || !htmlBody) {
        res.status(400).json({
          error: 'requestId, recipientEmail, subject, and htmlBody are required',
        });
        return;
      }

      // Mirror the transportation_requests Firestore read rule: only the
      // request's owner, or an admin/manager/finance user, may email it.
      const requestDoc = await admin
        .firestore()
        .collection('transportation_requests')
        .doc(requestId)
        .get();

      if (!requestDoc.exists) {
        res.status(404).json({ error: 'Transportation request not found' });
        return;
      }

      const userDoc = await admin
        .firestore()
        .collection('users')
        .doc(decodedToken.uid)
        .get();
      const userData = userDoc.exists ? userDoc.data() || {} : {};
      const role = userData.role;
      const isOwner = requestDoc.data().requesterId === decodedToken.uid;
      const isPrivileged =
        role === 'admin' || role === 'manager' || role === 'finance';

      if (!isOwner && !isPrivileged) {
        res.status(403).json({
          error: 'You do not have permission to email this request',
        });
        return;
      }

      const graphAccessToken = await getMicrosoftGraphAccessToken();
      const senderUserId = getMicrosoftEmailConfig().senderUserId;
      const sendMailResponse = await fetch(
        `${GRAPH_API_BASE}/users/${encodeURIComponent(senderUserId)}/sendMail`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${graphAccessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              subject,
              body: {
                contentType: 'HTML',
                content: htmlBody,
              },
              toRecipients: [
                {
                  emailAddress: {
                    address: recipientEmail,
                    ...(recipientName ? { name: recipientName } : {}),
                  },
                },
              ],
              ...(attachmentBase64 && attachmentName
                ? {
                    attachments: [
                      {
                        '@odata.type': '#microsoft.graph.fileAttachment',
                        name: attachmentName,
                        contentType: 'application/pdf',
                        contentBytes: attachmentBase64,
                      },
                    ],
                  }
                : {}),
            },
            saveToSentItems: true,
          }),
        },
      );

      if (!sendMailResponse.ok) {
        const errorText = await sendMailResponse.text();
        res.status(500).json({
          error: `Microsoft Graph sendMail failed: ${sendMailResponse.status} ${errorText}`,
        });
        return;
      }

      res.status(200).json({ success: true });
    } catch (error) {
      res.status(500).json({ error: error?.message || String(error) });
    }
  },
);

function getMicrosoftEmailConfig() {
  const tenantId =
    process.env.MICROSOFT_TENANT_ID ||
    functions.config?.()?.microsoft?.tenant_id;
  const clientId =
    process.env.MICROSOFT_CLIENT_ID ||
    functions.config?.()?.microsoft?.client_id;
  const clientSecret =
    process.env.MICROSOFT_CLIENT_SECRET ||
    functions.config?.()?.microsoft?.client_secret;
  const senderUserId =
    process.env.MICROSOFT_SENDER_USER_ID ||
    functions.config?.()?.microsoft?.sender_user_id;

  if (!tenantId || !clientId || !clientSecret || !senderUserId) {
    throw new Error(
      'Microsoft 365 email config is incomplete. Set MICROSOFT_TENANT_ID, MICROSOFT_CLIENT_ID, MICROSOFT_CLIENT_SECRET, and MICROSOFT_SENDER_USER_ID.',
    );
  }

  return { tenantId, clientId, clientSecret, senderUserId };
}

async function getMicrosoftGraphAccessToken() {
  const { tenantId, clientId, clientSecret } = getMicrosoftEmailConfig();
  const tokenResponse = await fetch(
    `${GRAPH_TOKEN_URL_BASE}/${encodeURIComponent(tenantId)}/oauth2/v2.0/token`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        scope: 'https://graph.microsoft.com/.default',
        grant_type: 'client_credentials',
      }),
    },
  );

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(
      `Microsoft token request failed: ${tokenResponse.status} ${errorText}`,
    );
  }

  const tokenData = await tokenResponse.json();
  if (!tokenData.access_token) {
    throw new Error('Microsoft token response did not include access_token');
  }

  return tokenData.access_token;
}

function buildPrompt(payload) {
  const range = payload.range || {};
  const totals = payload.totals || {};
  const cashFlow = payload.cashFlow || {};
  const scopes = payload.scopes || {};
  const trend = payload.trend || [];
  const categories = payload.categories || {};

  return `You are a finance analyst. Analyze the financial data and provide structured feedback.

**Data:**
- Period: ${range.start || 'N/A'} to ${range.end || 'N/A'}
- Inflow: ${totals.inflow ?? 0}, Outflow: ${totals.outflow ?? 0}, Net: ${totals.net ?? 0}
- Cash Flow: Opening ${cashFlow.opening ?? 0}, Disbursed ${cashFlow.disbursed ?? 0}, Closing ${cashFlow.closing ?? 0}
- Data Sources: ${JSON.stringify(scopes)}
- Trend: ${JSON.stringify(trend)}
- Categories: ${JSON.stringify(categories)}

**Instructions:**
Generate a report using markdown format with these sections:

## Key Observations
- List 3-4 key observations about cash flow, spending patterns, or trends

## Risks & Concerns
- Identify 2-3 potential risks (budget overruns, category concentration, cash depletion, etc.)

## Recommendations
- Provide 2-3 actionable recommendations

Keep each bullet point concise (1-2 sentences). Use bold for important numbers or terms.`;
}
