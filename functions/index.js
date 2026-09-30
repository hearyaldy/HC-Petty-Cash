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

// Proxies the 5 Media Production Planning drafting assistants through
// Gemini, so the Flutter client never holds AI_API_KEY itself — the web
// build especially can't keep a client-side secret private (anything
// bundled as a web asset is a public URL). Mirrors the financeAiReport
// pattern above: auth-gated, same AI_API_KEY config, same Gemini call
// shape, just genericized across 5 prompt-building tasks instead of one.
exports.mediaPlanningAi = functions.https.onRequest(async (req, res) => {
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
  const apiKey = process.env.AI_API_KEY || configKey;
  // gemini-2.5-flash (and financeAiReport's gemini-2.0-flash) were
  // retired by Google — both now 404. gemini-3.6-flash is the current
  // model for this API key as of this writing.
  const model = process.env.MEDIA_PLANNING_AI_MODEL || 'gemini-3.6-flash';
  if (!apiKey) {
    res.status(500).json({ error: 'AI_API_KEY is not configured' });
    return;
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const task = String(body.task || '');
    const payload = body.payload || {};
    const prompt = buildMediaPlanningPrompt(task, payload);
    if (!prompt) {
      res.status(400).json({ error: `Unknown task: ${task}` });
      return;
    }

    const response = await fetch(
      `${GEMINI_BASE_URL}/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.4,
            responseMimeType: 'application/json',
          },
        }),
      },
    );

    if (!response.ok) {
      const text = await response.text();
      res.status(500).json({ error: `AI request failed: ${response.status} ${text}` });
      return;
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      res.status(500).json({ error: 'Gemini returned an empty response' });
      return;
    }

    res.status(200).json({ data: JSON.parse(text) });
  } catch (error) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

function buildMediaPlanningPrompt(task, payload) {
  switch (task) {
    case 'objective': {
      const bullets = Array.isArray(payload.bullets) ? payload.bullets : [];
      return `You are helping a Hope Channel media producer fill in the "General
Objective of the Project" section of their production Planning
template. The template asks exactly these questions:
- What pains do we need to attend?
- Why does this program exist?
- Do we have practical conditions to meet this pain?

From the producer's rough notes below, draft clear, specific answers.
Do not invent facts the notes do not support — if practical conditions
are not mentioned, say so plainly rather than guessing.

Producer's notes:
${bullets.map((b) => `- ${b}`).join('\n')}

Respond as JSON with exactly these keys:
{"pains": ["..."], "whyItExists": "...", "practicalConditions": "...", "metricPriority": ["reach"|"engagement"|"connection", ...]}
metricPriority should order reach/engagement/connection by what the notes imply matters most.`;
    }
    case 'strategicIntent': {
      const bullets = Array.isArray(payload.bullets) ? payload.bullets : [];
      return `Draft the "Strategic Intent" section of a Hope Channel media Planning
document from the producer's notes below. The template asks:
- What transformation do we want to generate with this program?
- What will attract the audience to our program?
- How can we build audience to return to our program regularly?
- What metrics will guide our project?

Producer's notes:
${bullets.map((b) => `- ${b}`).join('\n')}

Respond as JSON: {"transformation": "...", "attractionHook": "...", "retentionPlan": "...", "metrics": ["..."]}`;
    }
    case 'audience': {
      const rawNotes = String(payload.rawNotes || '');
      return `You are drafting the "Audience" section of a Hope Channel media
Planning document from raw observations below. The template asks for:
Gender, Age, Social situation, Activity (student, entrepreneur,
farmer, etc.), Geography, and — importantly — who is NOT the target
audience.

Raw notes / observations:
${rawNotes}

Respond as JSON: {"gender": "...", "ageRange": "...", "socialSituation": "...", "activity": "...", "geography": "...", "notAudience": "..."}
Keep each field to one or two sentences. If the notes don't support a field, write "Not specified in notes" rather than guessing.`;
    }
    case 'marketResearch': {
      const programIdea = String(payload.programIdea || '');
      const preferredPlatform = String(payload.preferredPlatform || '');
      return `A Hope Channel media producer is planning a new program. Program idea:
"${programIdea}".
${preferredPlatform ? `They are leaning toward: ${preferredPlatform}.` : ''}

Draft the "Format: market research" section of their Planning
document. Workflow HC requires exactly 3 references from similar or
related programs, a platform recommendation, a content style
(podcast, documentary, shorts, talk show, etc.), and an aspect ratio
choice (16:9 landscape or 9:16 portrait).

Respond as JSON:
{
  "references": [{"title": "...", "url": "", "whatWorks": "..."}, ...exactly 3...],
  "preferredPlatforms": ["..."],
  "style": "...",
  "aspectRatio": "landscape_16_9" | "portrait_9_16"
}
Leave "url" empty if you are not certain of a real URL — never invent one.`;
    }
    case 'editorialCalendar': {
      const platforms = Array.isArray(payload.platforms) ? payload.platforms : [];
      const frequency = String(payload.frequency || '');
      const launchDate = String(payload.launchDate || '');
      const numberOfEntries = Number(payload.numberOfEntries) || 8;
      return `Draft an editorial calendar skeleton for a Hope Channel media program
launching ${launchDate}, publishing
on: ${platforms.join(', ')}, at this frequency: ${frequency}.

Produce exactly ${numberOfEntries} entries, spaced according to the
stated frequency starting on the launch date. These are placeholders
for the producer to refine, not final content.

Respond as JSON: {"entries": [{"date": "YYYY-MM-DD", "theme": "...", "format": "...", "channel": "...", "status": "Planned"}, ...]}`;
    }
    default:
      return null;
  }
}

// Proxies a Gemini historical-exchange-rate lookup, used by the "AI Rate"
// button on the report transaction currency dialogs (report_detail_screen.dart).
// This used to run client-side in AITextService, holding AI_API_KEY directly
// in the Flutter app — broken two ways: the app's .env is never declared as
// a Flutter asset (see pubspec.yaml), so dotenv.load() silently fails in any
// real build and the key never loads; and even if it did, that shipped the
// key inside every client build, the exact risk mediaPlanningAi/financeAiReport
// were built to avoid. This proxies through the same server-side AI_API_KEY
// and current model instead.
exports.exchangeRateAi = functions.https.onRequest(async (req, res) => {
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
  const apiKey = process.env.AI_API_KEY || configKey;
  const model = process.env.MEDIA_PLANNING_AI_MODEL || 'gemini-3.6-flash';
  if (!apiKey) {
    res.status(500).json({ error: 'AI_API_KEY is not configured' });
    return;
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const fromCurrency = String(body.fromCurrency || '').trim().toUpperCase();
    const dateStr = String(body.date || '').trim();
    if (!fromCurrency || !dateStr) {
      res.status(400).json({ error: 'fromCurrency and date are required' });
      return;
    }

    const prompt = `You are a financial assistant with knowledge of historical currency exchange rates.

Provide the exchange rate for 1 ${fromCurrency} to THB (Thai Baht) on ${dateStr}.

Return ONLY a JSON object in this exact format, nothing else:
{
  "rate": 8.45,
  "note": "Approximate rate based on historical data for ${dateStr}"
}

The "rate" must be a number (how many THB you get for 1 ${fromCurrency}).
If you are not certain of the exact rate, provide your best estimate based on historical data.
Do not include any explanation outside the JSON.`;

    const response = await fetch(
      `${GEMINI_BASE_URL}/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: 'application/json',
          },
        }),
      }
    );

    if (!response.ok) {
      const text = await response.text();
      res.status(500).json({ error: `AI request failed: ${response.status} ${text}` });
      return;
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      res.status(500).json({ error: 'Gemini returned an empty response' });
      return;
    }

    const parsed = JSON.parse(text);
    const rate = Number(parsed?.rate);
    if (!rate || rate <= 0) {
      res.status(500).json({ error: 'Invalid exchange rate returned by AI' });
      return;
    }

    res.status(200).json({ data: { rate, note: parsed?.note || null } });
  } catch (error) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

// Proxies the ADCOM agenda editor's AI Spell Check / AI Enhance Text
// buttons (adcom_agenda_edit_screen.dart) through Gemini, same reasoning
// and shape as mediaPlanningAi/exchangeRateAi above: AITextService used
// to run these client-side off a .env-loaded AI_API_KEY that never
// actually loads in a real build (.env isn't a declared Flutter asset),
// and shipping the key client-side would defeat the point of the other
// proxies anyway.
exports.agendaAi = functions.https.onRequest(async (req, res) => {
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
  const apiKey = process.env.AI_API_KEY || configKey;
  const model = process.env.MEDIA_PLANNING_AI_MODEL || 'gemini-3.6-flash';
  if (!apiKey) {
    res.status(500).json({ error: 'AI_API_KEY is not configured' });
    return;
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body || {};
    const task = String(body.task || '');
    const payload = body.payload || {};
    const prompt = buildAgendaAiPrompt(task, payload);
    if (!prompt) {
      res.status(400).json({ error: `Unknown task: ${task}` });
      return;
    }

    const response = await fetch(
      `${GEMINI_BASE_URL}/${model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: 'application/json',
          },
        }),
      },
    );

    if (!response.ok) {
      const text = await response.text();
      res.status(500).json({ error: `AI request failed: ${response.status} ${text}` });
      return;
    }

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      res.status(500).json({ error: 'Gemini returned an empty response' });
      return;
    }

    res.status(200).json({ data: JSON.parse(text) });
  } catch (error) {
    res.status(500).json({ error: error?.message || String(error) });
  }
});

function buildAgendaAiPrompt(task, payload) {
  switch (task) {
    case 'spellCheck': {
      const text = String(payload.text || '');
      return `Check the following text for spelling and grammar errors.

Return ONLY a JSON object in this exact format, nothing else:
{
  "correctedText": "the corrected version of the text",
  "issues": [
    {"original": "misspeled", "correction": "misspelled", "type": "spelling"},
    {"original": "grammer error", "correction": "grammar error", "type": "grammar"}
  ]
}

If there are no errors, return "issues": [] and "correctedText" equal to the original text.

Text to check:
${text}`;
    }
    case 'enhanceText': {
      const text = String(payload.text || '');
      const context = String(payload.context || '');
      return `${context ? `Context: This is for ${context}.\n\n` : ''}Please improve the following text to be more professional, clear, and well-structured.
Keep the same meaning but enhance the language, grammar, and flow.

Return ONLY a JSON object in this exact format, nothing else:
{"text": "the improved text"}

Original text:
${text}`;
    }
    default:
      return null;
  }
}

// Proxies Apify's Facebook Posts Scraper actor so the Flutter client never
// holds APIFY_TOKEN (same reasoning as AI_API_KEY above — a web build can't
// keep a client-side secret private). Client sends a productionId, not a
// raw URL — the Page URL is looked up server-side from that production's
// own Firestore doc. This matters because the endpoint only checks for
// *any* signed-in user (like financeAiReport/mediaPlanningAi do), not a
// specific role; accepting an arbitrary client-supplied URL would let any
// authenticated user spend Apify credits scraping whatever page they want.
// Scoping to productions that already exist in our own Firestore closes
// that off. Returns aggregated totals for the client to save as a
// MediaEngagement record via the existing addEngagement flow — it does not
// write to Firestore itself, mirroring financeAiReport/mediaPlanningAi.
exports.mediaEngagementSync = functions.https.onRequest(async (req, res) => {
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

  const configToken =
    typeof functions.config === 'function'
      ? functions.config()?.apify?.token
      : undefined;
  const apifyToken = process.env.APIFY_TOKEN || configToken;
  if (!apifyToken) {
    res.status(500).json({ error: 'APIFY_TOKEN is not configured' });
    return;
  }

  try {
    const payload = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const productionId = String(payload?.productionId || '').trim();
    const resultsLimit = Math.min(Number(payload?.resultsLimit) || 20, 50);

    if (!productionId) {
      res.status(400).json({ error: 'productionId is required' });
      return;
    }

    const productionDoc = await admin
      .firestore()
      .collection('media_productions')
      .doc(productionId)
      .get();
    const pageUrl = String(productionDoc.data()?.facebookPageUrl || '').trim();

    if (!pageUrl) {
      res.status(400).json({ error: 'This production has no Facebook Page URL set' });
      return;
    }

    let hostname;
    try {
      hostname = new URL(pageUrl).hostname.replace(/^www\.|^m\./, '');
    } catch (_) {
      hostname = '';
    }
    if (hostname !== 'facebook.com') {
      res.status(400).json({ error: 'facebookPageUrl must be a facebook.com URL' });
      return;
    }

    const response = await fetch(
      'https://api.apify.com/v2/acts/apify~facebook-posts-scraper/run-sync-get-dataset-items',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apifyToken}`,
        },
        body: JSON.stringify({
          startUrls: [{ url: pageUrl }],
          resultsLimit,
        }),
      }
    );

    if (!response.ok) {
      const text = await response.text();
      res.status(500).json({ error: `Apify request failed: ${response.status} ${text}` });
      return;
    }

    const posts = await response.json();
    if (!Array.isArray(posts) || posts.length === 0) {
      res.status(200).json({
        data: { postCount: 0, views: 0, likes: 0, comments: 0, shares: 0, earliestPostDate: null },
      });
      return;
    }

    let views = 0;
    let likes = 0;
    let comments = 0;
    let shares = 0;
    let earliestTimestamp = null;

    for (const post of posts) {
      views += Number(post.viewsCount) || 0;
      likes += Number(post.likes) || 0;
      comments += Number(post.comments) || 0;
      shares += Number(post.shares) || 0;

      const postTime = post.timestamp || post.time || post.date;
      if (postTime) {
        const parsed = new Date(postTime);
        if (!isNaN(parsed.getTime()) && (!earliestTimestamp || parsed < earliestTimestamp)) {
          earliestTimestamp = parsed;
        }
      }
    }

    res.status(200).json({
      data: {
        postCount: posts.length,
        views,
        likes,
        comments,
        shares,
        earliestPostDate: earliestTimestamp ? earliestTimestamp.toISOString() : null,
      },
    });
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
