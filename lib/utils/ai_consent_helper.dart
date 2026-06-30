import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiConsentHelper {
  static const _key = 'ai_consent_v1_shown';

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return;

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _AiConsentDialog(),
    );
  }

  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

class _AiConsentDialog extends StatelessWidget {
  const _AiConsentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.purple.shade600, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('AI Features — Data Notice', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app includes AI-powered features (text enhancement, spell check, '
              'resolution generation, and survey analysis).',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.amber.shade800, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Text is sent to Google Gemini',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When you use an AI feature, the text you enter is transmitted to '
                    'Google\'s Gemini AI service for processing. This is subject to '
                    'Google\'s privacy and AI usage policies.',
                    style: TextStyle(fontSize: 13, color: Colors.amber.shade900, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Avoid entering sensitive personal data (national IDs, bank details, '
              'medical specifics) in AI-assisted text fields.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            AiConsentHelper.markShown();
          },
          child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
