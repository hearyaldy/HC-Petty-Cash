const functions = require('firebase-functions');
const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config({ path: '../.env' });
admin.initializeApp();

const GEMINI_BASE_URL =
  'https://generativelanguage.googleapis.com/v1beta/models';

exports.financeAiReport = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
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
