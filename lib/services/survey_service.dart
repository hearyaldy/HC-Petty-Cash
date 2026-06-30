import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/survey.dart';
import '../models/survey_response.dart';

class SurveyService {
  final _db = FirebaseFirestore.instance;
  static const _surveys = 'surveys';
  static const _responses = 'survey_responses';

  // ── Read ──────────────────────────────────────────────────────────────────

  Stream<List<Survey>> watchAll() => _db
      .collection(_surveys)
      .orderBy('code')
      .snapshots()
      .map((s) => s.docs.map(Survey.fromFirestore).toList());

  Future<Survey?> getById(String id) async {
    final doc = await _db.collection(_surveys).doc(id).get();
    if (!doc.exists) return null;
    return Survey.fromFirestore(doc);
  }

  Stream<List<SurveyResponse>> watchResponses(String surveyId) => _db
      .collection(_responses)
      .where('surveyId', isEqualTo: surveyId)
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SurveyResponse.fromFirestore).toList());

  Future<int> getResponseCount(String surveyId) async {
    final snap = await _db
        .collection(_responses)
        .where('surveyId', isEqualTo: surveyId)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> setActive(String surveyId, {required bool active}) =>
      _db.collection(_surveys).doc(surveyId).update({'isActive': active});

  Future<void> submitResponse(SurveyResponse response) =>
      _db.collection(_responses).add(response.toFirestore());

  Future<void> deleteResponse(String responseId) =>
      _db.collection(_responses).doc(responseId).delete();

  Future<String> createSurvey(Survey survey) async {
    final ref = survey.id.isEmpty
        ? _db.collection(_surveys).doc()
        : _db.collection(_surveys).doc(survey.id);
    await ref.set(survey.toFirestore());
    return ref.id;
  }

  Future<void> updateSurveyMeta(String id, Map<String, dynamic> data) =>
      _db.collection(_surveys).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateSurveySections(String id, List<SurveySection> sections) =>
      _db.collection(_surveys).doc(id).update({
        'sections': sections.map((s) => s.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteSurvey(String id) =>
      _db.collection(_surveys).doc(id).delete();

  // ── Seed ──────────────────────────────────────────────────────────────────

  Future<bool> surveysExist() async {
    final snap = await _db.collection(_surveys).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<void> seedSurveys() async {
    final batch = _db.batch();
    for (final survey in _buildSurveys()) {
      final ref = _db.collection(_surveys).doc(survey.id);
      batch.set(ref, survey.toFirestore());
    }
    await batch.commit();
  }

  // ── Seed data ─────────────────────────────────────────────────────────────

  static List<Survey> _buildSurveys() => [_surveyA(), _surveyB(), _surveyC()];

  static Map<String, dynamic> _q(
    String id,
    String code,
    String text,
    String type, {
    List<String> opts = const [],
    bool req = true,
    int? maxSel,
    int? sMin,
    int? sMax,
    String? sMinLbl,
    String? sMaxLbl,
    String? note,
    String? condOn,
    List<String>? condVals,
  }) =>
      {
        'id': id,
        'code': code,
        'text': text,
        'type': type,
        'options': opts,
        'isRequired': req,
        'maxSelections': ?maxSel,
        'scaleMin': ?sMin,
        'scaleMax': ?sMax,
        'scaleMinLabel': ?sMinLbl,
        'scaleMaxLabel': ?sMaxLbl,
        'note': ?note,
        'conditionalOnId': ?condOn,
        'conditionalOnValues': ?condVals,
      };

  static Map<String, dynamic> _section(
          String title, String subtitle, List<Map<String, dynamic>> questions) =>
      {'title': title, 'subtitle': subtitle, 'questions': questions};

  static const _countries = [
    'Cambodia', 'Laos', 'Malaysia', 'Brunei', 'Thailand', 'Vietnam', 'Other'
  ];

  // ── Survey A ──────────────────────────────────────────────────────────────

  static Survey _surveyA() {
    final sections = [
      _section('A1 — Personal Background', 'Helps us understand who our audience is', [
        _q('A1Q1', 'Q1', 'What is your age group?', 'singleChoice',
            opts: ['Under 18', '18–24', '25–34', '35–44', '45–54', '55–64', '65 or older']),
        _q('A1Q2', 'Q2', 'What is your gender?', 'singleChoice',
            opts: ['Male', 'Female', 'Prefer not to say']),
        _q('A1Q3', 'Q3', 'What country are you currently living in?', 'singleChoice',
            opts: _countries),
        _q('A1Q4', 'Q4', 'What is your current area of residence?', 'singleChoice',
            opts: ['Major city', 'Small city / town', 'Rural area / village']),
        _q('A1Q5', 'Q5', 'What is your highest level of education completed?', 'singleChoice',
            req: false,
            opts: ['No formal schooling', 'Primary school', 'Secondary school',
                'Diploma / Vocational', 'University / Bachelor\'s degree', 'Postgraduate']),
        _q('A1Q6', 'Q6', 'What is your primary occupation?', 'singleChoice',
            req: false,
            opts: ['Student', 'Employed (full-time)', 'Employed (part-time)',
                'Self-employed / Business owner', 'Homemaker', 'Unemployed', 'Retired']),
        _q('A1Q7', 'Q7', 'What is your religious background?', 'singleChoice',
            opts: ['Buddhist', 'Muslim', 'Christian (Catholic)',
                'Christian (Protestant / Evangelical)', 'Hindu',
                'Animist / Traditional beliefs', 'Atheist / No religion', 'Other']),
        _q('A1Q8', 'Q8', 'How would you describe your current level of spiritual practice?', 'singleChoice',
            opts: ['Very active — I practise my faith regularly',
                'Somewhat active — I participate occasionally',
                'Inactive — I have a faith background but don\'t practise',
                'I am exploring / searching spiritually',
                'I do not have a religious or spiritual practice']),
      ]),
      _section('A2 — Life & Felt Needs', 'Identifies the primary doorway through which the audience enters faith conversations', [
        _q('A2Q9', 'Q9', 'Which of the following best describes what you are most looking for in life right now? (Select up to 2)', 'multipleChoice',
            maxSel: 2,
            opts: ['A sense of meaning and purpose',
                'Healing or comfort from pain, loss, or difficulty',
                'Answers to big questions about life, truth, and the world',
                'Belonging — genuine friendship and community',
                'Peace and stability in uncertain or difficult times',
                'Success in my career or education',
                'A better family life or relationships', 'Something else']),
        _q('A2Q10', 'Q10', 'When you are going through a difficult time, what do you typically do? (Select all that apply)', 'multipleChoice',
            opts: ['Talk to a friend or family member',
                'Watch videos or listen to music online', 'Pray or meditate',
                'Search for answers online', 'Read books or articles',
                'Seek help from a counsellor or community leader',
                'Nothing — I keep it to myself', 'Other']),
        _q('A2Q11', 'Q11', 'I am searching for something deeper in life — beyond everyday routine.', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Strongly Disagree', sMaxLbl: 'Strongly Agree'),
        _q('A2Q12', 'Q12', 'I am curious about faith and spiritual questions, even if I don\'t consider myself religious.', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Strongly Disagree', sMaxLbl: 'Strongly Agree'),
        _q('A2Q13', 'Q13', 'Which topic would most interest you in a video or programme? (Select up to 3)', 'multipleChoice',
            maxSel: 3,
            opts: ['How to find purpose and meaning in life',
                'Stories of people overcoming hardship',
                'Questions about God, faith, and religion',
                'Practical tips for health and wellness',
                'Relationship and family advice',
                'Stories of community and belonging',
                'End times, prophecy, and world events',
                'Stories of forgiveness and new beginnings',
                'Meditation, mindfulness, and inner peace']),
        _q('A2Q14', 'Q14', 'In your own words, what is the biggest challenge or question you face in life right now?', 'openText',
            req: false,
            note: 'Most valuable question in the survey — encourage honesty'),
      ]),
      _section('A3 — Media & Platform Habits', 'Shapes HCSEA\'s distribution plan', [
        _q('A3Q15', 'Q15', 'How many hours per day do you typically spend watching or consuming content online?', 'singleChoice',
            opts: ['Less than 1 hour', '1–2 hours', '3–4 hours', '5–6 hours', 'More than 6 hours']),
        _q('A3Q16', 'Q16', 'Which devices do you mainly use to watch online content? (Select all that apply)', 'multipleChoice',
            opts: ['Smartphone', 'Tablet', 'Laptop or desktop computer',
                'Smart TV', 'I do not regularly watch online content']),
        _q('A3Q17', 'Q17', 'Which platforms do you use most frequently? (Select all that apply)', 'multipleChoice',
            opts: ['YouTube', 'Facebook', 'TikTok', 'Instagram', 'X (formerly Twitter)',
                'Telegram', 'WhatsApp (videos/channels)', 'Netflix or other streaming services',
                'Traditional TV', 'Other']),
        _q('A3Q18', 'Q18', 'What times of day do you most often watch online content? (Select all that apply)', 'multipleChoice',
            opts: ['Early morning (5 AM–8 AM)', 'Morning (8 AM–12 PM)',
                'Afternoon (12 PM–5 PM)', 'Evening (5 PM–9 PM)',
                'Late night (9 PM–12 AM)', 'After midnight']),
        _q('A3Q19', 'Q19', 'What type of content do you most enjoy watching? (Select up to 3)', 'multipleChoice',
            maxSel: 3,
            opts: ['Short clips (under 3 minutes)', 'Medium videos (5–15 minutes)',
                'Long-form documentaries or talks (30 min+)', 'Livestreams',
                'Drama and short films', 'Music and worship', 'Educational content',
                'Motivational / inspiring stories', 'Comedy and entertainment']),
        _q('A3Q20', 'Q20', 'What language do you prefer to watch content in? (Select all that apply)', 'multipleChoice',
            opts: ['My local language', 'English', 'Another language']),
        _q('A3Q21', 'Q21', 'What makes you stop and watch a video rather than scrolling past?', 'openText',
            req: false),
        _q('A3Q22', 'Q22', 'Have you ever watched religious or faith-based content online?', 'yesNo'),
        _q('A3Q23', 'Q23', 'If yes — what made you watch it? What kept you watching?', 'openText',
            req: false, condOn: 'A3Q22', condVals: ['Yes']),
        _q('A3Q24', 'Q24', 'If no — what would make you consider watching a faith-related video?', 'openText',
            req: false, condOn: 'A3Q22', condVals: ['No', 'Not Sure']),
      ]),
      _section('A4 — Engagement & Connection Readiness', 'Identifies the audience\'s willingness to take a next step', [
        _q('A4Q25', 'Q25', 'If you watched a video that deeply resonated with you, what would you be most likely to do next? (Select all that apply)', 'multipleChoice',
            opts: ['Share it with a friend or family member',
                'Like and comment on the video', 'Subscribe to the channel',
                'Visit a website for more information',
                'Sign up for a newsletter or follow-up content',
                'Join an online group or community',
                'Attend an event or gathering in my area',
                'Nothing — I would just keep watching', 'Other']),
        _q('A4Q26', 'Q26', 'Would you be open to receiving regular short videos or messages about faith, purpose, and life?', 'singleChoice',
            opts: ['Yes — via WhatsApp', 'Yes — via YouTube subscription',
                'Yes — via email', 'Yes — via social media',
                'No — I prefer not to receive regular content',
                'Maybe — it depends on the content']),
        _q('A4Q27', 'Q27', 'How open are you to attending a community event or gathering focused on life\'s big questions?', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Not open at all', sMaxLbl: 'Very open'),
        _q('A4Q28', 'Q28', 'Would you be willing to talk with someone about spiritual questions or life challenges?', 'singleChoice',
            opts: ['Yes, definitely', 'Maybe, if I knew more about them',
                'Probably not', 'No']),
        _q('A4Q29', 'Q29', 'What would need to be true for you to feel comfortable engaging with a faith-based community? (Select all that apply)', 'multipleChoice',
            req: false,
            opts: ['The community welcomes people from all backgrounds',
                'It is not pushy or pressuring',
                'I can engage anonymously at first',
                'There are people who look and think like me',
                'It is relevant to my real-life questions',
                'There is no obligation to join or commit', 'Other']),
        _q('A4Q30', 'Q30', 'Is there anything you would like to tell us about yourself or your community that would help us serve you better?', 'openText',
            req: false),
      ]),
    ];

    return Survey(
      id: 'survey_a',
      code: 'A',
      title: 'Audience Research Survey',
      description: 'For: General Public — Community Members (Non-Adventist). '
          'This survey is designed to help Hope Channel Southeast Asia understand '
          'the people we are trying to reach — their daily lives, media habits, '
          'spiritual background, and felt needs.',
      targetAudience: 'public',
      isActive: false,
      isPublic: true,
      estimatedMinutes: 10,
      sections: sections.map(SurveySection.fromMap).toList(),
      createdAt: DateTime.now(),
    );
  }

  // ── Survey B ──────────────────────────────────────────────────────────────

  static Survey _surveyB() {
    final sections = [
      _section('B1 — Church Profile', 'Establishes baseline context for each church', [
        _q('B1Q1', 'Q1', 'What country is your church located in?', 'singleChoice',
            opts: ['Cambodia', 'Laos', 'Malaysia', 'Brunei', 'Thailand', 'Vietnam']),
        _q('B1Q2', 'Q2', 'What is the approximate attendance at your church each Sabbath?', 'singleChoice',
            opts: ['Under 20', '20–50', '51–100', '101–200', '201–500', 'Over 500']),
        _q('B1Q3', 'Q3', 'How would you describe your church\'s primary location?', 'singleChoice',
            opts: ['Major city centre', 'City suburb', 'Small town', 'Rural / village area']),
        _q('B1Q4', 'Q4', 'What is the primary language used in your church services? (Select all that apply)', 'multipleChoice',
            opts: ['English', 'Malay', 'Thai', 'Khmer (Cambodian)', 'Vietnamese', 'Lao', 'Other']),
        _q('B1Q5', 'Q5', 'What is the approximate age profile of your active congregation? (Estimate %)', 'openText',
            req: false,
            note: 'e.g. Under 18: 20%, 18–35: 30%, 36–60: 35%, 60+: 15%'),
      ]),
      _section('B2 — Ministry Capacity', 'Assesses what the church can offer to new contacts', [
        _q('B2Q6', 'Q6', 'Which of the following ministries does your church currently have active? (Select all that apply)', 'multipleChoice',
            opts: ['Personal Ministries / Evangelism', 'Youth Ministry',
                'Women\'s Ministry', 'Men\'s Ministry', 'Community Services / ADRA',
                'Health Ministry', 'Bible Correspondence School',
                'Small Groups / Home Fellowship', 'Online Ministry / Social Media',
                'Children\'s Ministry (Adventurers/Pathfinders)', 'Music Ministry']),
        _q('B2Q7', 'Q7', 'Does your church have a designated person responsible for following up with new contacts or visitors?', 'yesNo'),
        _q('B2Q8', 'Q8', 'If a new person expressed interest in learning more about faith through an online Hope Channel video, how would your church respond?', 'singleChoice',
            opts: ['We have a clear process — someone would contact them within 24–48 hours',
                'We would try to follow up but the process is informal',
                'We would welcome them to visit a service but have no structured follow-up',
                'We currently have no capacity to follow up with new contacts', 'Other']),
        _q('B2Q9', 'Q9', 'How many new visitors or contacts can your church realistically engage per month?', 'singleChoice',
            opts: ['1–2', '3–5', '6–10', '11–20', 'More than 20', 'We are not sure']),
        _q('B2Q10', 'Q10', 'What types of entry points exist for a non-Adventist newcomer at your church? (Select all that apply)', 'multipleChoice',
            opts: ['Open public Sabbath services', 'Mid-week Bible study',
                'Community events (health programmes, social events)',
                'Online meetings or Bible studies',
                'One-on-one pastoral conversations',
                'No clear entry point for outsiders currently']),
        _q('B2Q11', 'Q11', 'How welcoming is your church environment to people from non-Christian backgrounds?', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Not welcoming', sMaxLbl: 'Very welcoming'),
        _q('B2Q12', 'Q12', 'Does your church offer Bible studies or discipleship materials in the local language?', 'yesNo'),
        _q('B2Q13', 'Q13', 'Are there trained Bible workers or lay evangelists in your church?', 'singleChoice',
            opts: ['Yes — multiple trained people', 'Yes — one trained person',
                'We have willing people but they are not formally trained', 'No']),
      ]),
      _section('B3 — Digital & Media Engagement', 'Assesses church readiness to support HCSEA\'s digital outreach', [
        _q('B3Q14', 'Q14', 'Does your church have an active social media presence? (Select all that apply)', 'multipleChoice',
            opts: ['Facebook page', 'YouTube channel', 'WhatsApp group (for members or outreach)',
                'Instagram account', 'TikTok account', 'Website',
                'No active social media presence']),
        _q('B3Q15', 'Q15', 'Has your church ever used Hope Channel content in any outreach or discipleship activity?', 'yesNo'),
        _q('B3Q16', 'Q16', 'If yes — how was Hope Channel content used?', 'openText',
            req: false, condOn: 'B3Q15', condVals: ['Yes']),
        _q('B3Q17', 'Q17', 'How comfortable is your church leadership with using digital media as an evangelism tool?', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Not comfortable', sMaxLbl: 'Very comfortable'),
        _q('B3Q18', 'Q18', 'If Hope Channel referred a digital contact to your church, how would you prefer to receive that referral?', 'singleChoice',
            opts: ['WhatsApp message with contact details', 'Email',
                'Through a shared online form or database', 'Direct phone call',
                'We do not currently have a system for this']),
        _q('B3Q19', 'Q19', 'Does your church have the capacity to run an online Bible study group for new contacts?', 'singleChoice',
            opts: ['Yes — we already do this', 'Yes — we could with some support',
                'Possibly — we would need training',
                'No — we don\'t have the capacity right now']),
      ]),
      _section('B4 — Church Penetration & Community Presence', 'Assesses the church\'s visibility and reach in its community', [
        _q('B4Q20', 'Q20', 'What percentage of the people in your immediate neighbourhood are aware that your church exists?', 'singleChoice',
            opts: ['Almost none — we are largely unknown',
                'A small minority — a few local people know',
                'A moderate number — perhaps 20–30%',
                'Many — we are well known in the community',
                'We are very visible and well connected in our community']),
        _q('B4Q21', 'Q21', 'Does your church have regular contact with non-Adventist community members?', 'singleChoice',
            opts: ['Yes — regularly', 'Yes — occasionally', 'Rarely',
                'No — our activities are mainly for members']),
        _q('B4Q22', 'Q22', 'What community needs are most visible in the area around your church? (Select all that apply)', 'multipleChoice',
            req: false,
            opts: ['Poverty or economic hardship', 'Family breakdown or domestic issues',
                'Mental health challenges', 'Loneliness and social isolation',
                'Youth at risk', 'Lack of access to education',
                'Spiritual emptiness or searching', 'Addiction', 'Other']),
        _q('B4Q23', 'Q23', 'Which of these community needs is your church currently addressing? (Select all that apply)', 'multipleChoice',
            req: false,
            opts: ['Poverty / food assistance', 'Family counselling or support',
                'Mental health support', 'Youth programmes', 'Educational programmes',
                'Health or wellness programmes', 'None currently', 'Other']),
        _q('B4Q24', 'Q24', 'What is the single biggest barrier your church faces in reaching non-Adventists in your community?', 'openText',
            note: 'Most strategic question in Survey B — analyse carefully'),
      ]),
      _section('B5 — Partnership Readiness', 'Identifies how HCSEA and local churches can work together', [
        _q('B5Q25', 'Q25', 'How interested is your church leadership in partnering with Hope Channel Southeast Asia?', 'scale',
            sMin: 1, sMax: 10, sMinLbl: 'Not at all', sMaxLbl: 'Very much'),
        _q('B5Q26', 'Q26', 'What kind of support would most help your church in its outreach? (Select up to 3)', 'multipleChoice',
            maxSel: 3,
            opts: ['Ready-made video content for social media sharing',
                'Training in digital evangelism and social media',
                'A referral system for digital contacts from HCSEA',
                'Evangelistic programmes or campaigns',
                'Discipleship materials in local language',
                'Equipment or technical support',
                'Funding for community outreach events',
                'Prayer support and partnership network']),
        _q('B5Q27', 'Q27', 'Would your church be willing to host a local event tied to an HCSEA digital campaign?', 'singleChoice',
            opts: ['Yes — we would be very interested',
                'Yes — with some planning and support',
                'Maybe — we would need to discuss it', 'Not at this time']),
        _q('B5Q28', 'Q28', 'Would your church be willing to participate in a Field Correspondent programme?', 'yesNo'),
        _q('B5Q29', 'Q29', 'Is there anything else you would like Hope Channel Southeast Asia to know about your church or community?', 'openText',
            req: false),
      ]),
    ];

    return Survey(
      id: 'survey_b',
      code: 'B',
      title: 'Church Capacity Survey',
      description: 'For: Local SDA Church Leaders, Pastors & Communication Directors. '
          'This survey helps Hope Channel Southeast Asia understand the capacity of '
          'local SDA churches to receive and disciple new contacts generated through '
          'HCSEA\'s digital outreach.',
      targetAudience: 'leaders',
      isActive: false,
      isPublic: false,
      estimatedMinutes: 12,
      sections: sections.map(SurveySection.fromMap).toList(),
      createdAt: DateTime.now(),
    );
  }

  // ── Survey C ──────────────────────────────────────────────────────────────

  static Survey _surveyC() {
    final sections = [
      _section('C1 — Personal Background', 'Helps us understand who our members are across the region', [
        _q('C1Q1', 'Q1', 'What country are you currently living in?', 'singleChoice',
            opts: _countries),
        _q('C1Q2', 'Q2', 'What is your age group?', 'singleChoice',
            opts: ['Under 18', '18–24', '25–34', '35–44', '45–54', '55–64', '65 or older']),
        _q('C1Q3', 'Q3', 'What is your gender?', 'singleChoice',
            opts: ['Male', 'Female', 'Prefer not to say']),
        _q('C1Q4', 'Q4', 'How long have you been a Seventh-day Adventist?', 'singleChoice',
            opts: ['Less than 1 year', '1–5 years', '6–10 years',
                '11–20 years', 'More than 20 years', 'I grew up in the church']),
        _q('C1Q5', 'Q5', 'How actively involved are you in your local SDA church?', 'singleChoice',
            opts: ['Very active — I attend regularly and serve in a ministry or role',
                'Active — I attend regularly',
                'Occasionally active — I attend sometimes',
                'Inactive — I rarely attend']),
        _q('C1Q6', 'Q6', 'What is your primary occupation?', 'singleChoice',
            opts: ['Student', 'Employed (full-time)', 'Employed (part-time)',
                'Self-employed / Business owner', 'Homemaker', 'Unemployed', 'Retired']),
        _q('C1Q7', 'Q7', 'What is your current area of residence?', 'singleChoice',
            opts: ['Major city', 'Small city / town', 'Rural area / village']),
      ]),
      _section('C2 — Personal Media Habits', 'Reveals how members consume and share content', [
        _q('C2Q8', 'Q8', 'How many hours per day do you typically spend watching or consuming content online?', 'singleChoice',
            opts: ['Less than 1 hour', '1–2 hours', '3–4 hours', '5–6 hours', 'More than 6 hours']),
        _q('C2Q9', 'Q9', 'Which platforms do you use most frequently? (Select all that apply)', 'multipleChoice',
            opts: ['YouTube', 'Facebook', 'TikTok', 'Instagram', 'X (formerly Twitter)',
                'Telegram', 'WhatsApp (videos/channels)', 'Netflix or other streaming services',
                'Traditional TV', 'Other']),
        _q('C2Q10', 'Q10', 'What type of content do you most enjoy watching online? (Select up to 3)', 'multipleChoice',
            maxSel: 3,
            opts: ['Short clips (under 3 minutes)', 'Medium videos (5–15 minutes)',
                'Long-form talks or documentaries (30 min+)', 'Livestreams',
                'Drama and short films', 'Music and worship', 'Sermons and Bible studies',
                'Motivational or inspiring stories', 'Educational content', 'Comedy or entertainment']),
        _q('C2Q11', 'Q11', 'What times of day do you most often watch online content? (Select all that apply)', 'multipleChoice',
            opts: ['Early morning (5 AM–8 AM)', 'Morning (8 AM–12 PM)',
                'Afternoon (12 PM–5 PM)', 'Evening (5 PM–9 PM)', 'Late night (9 PM–12 AM)']),
        _q('C2Q12', 'Q12', 'What language do you prefer to consume content in? (Select all that apply)', 'multipleChoice',
            opts: ['English', 'Malay', 'Thai', 'Khmer (Cambodian)', 'Vietnamese', 'Lao', 'Other']),
        _q('C2Q13', 'Q13', 'Are you aware that Hope Channel Southeast Asia produces content on YouTube, Facebook, and other platforms?', 'yesNo'),
        _q('C2Q14', 'Q14', 'Have you watched any Hope Channel Southeast Asia content in the past 3 months?', 'singleChoice',
            opts: ['Yes — regularly (more than once a week)',
                'Yes — occasionally (a few times)', 'Once or twice',
                'No', 'I was not aware of it until now']),
        _q('C2Q15', 'Q15', 'What type of Hope Channel content have you found most useful or meaningful? (Select all that apply)', 'multipleChoice',
            opts: ['Devotional and prayer content', 'Evangelistic programmes',
                'Health and wellness content', 'Youth-focused content',
                'Music and worship', 'Documentary or news content',
                'Sermon series', 'Children\'s content', 'I have not watched HCSEA content']),
        _q('C2Q16', 'Q16', 'How satisfied are you with the quality and relevance of Hope Channel Southeast Asia content?', 'scale',
            req: false, sMin: 1, sMax: 5, sMinLbl: 'Very unsatisfied', sMaxLbl: 'Very satisfied'),
        _q('C2Q17', 'Q17', 'What would make you watch Hope Channel content more often? (Select all that apply)', 'multipleChoice',
            opts: ['More content in my local language',
                'Shorter, more shareable videos',
                'Content I can easily share with non-Adventist friends',
                'Better quality production', 'More relevant topics for my daily life',
                'More youth-focused content', 'Notification when new content is posted',
                'Content my non-Christian friends would enjoy',
                'Nothing — I already watch regularly']),
      ]),
      _section('C3 — Content Sharing & Personal Witness', 'Understanding how members spread content is key to HCSEA\'s organic reach strategy', [
        _q('C3Q18', 'Q18', 'How often do you share faith-related content with non-Adventist friends or family?', 'singleChoice',
            opts: ['Regularly — at least once a week',
                'Occasionally — a few times a month',
                'Rarely — once or twice a year', 'Never',
                'I have not thought about doing this']),
        _q('C3Q19', 'Q19', 'When you share content with a non-Adventist friend or family member, what platforms do you typically use? (Select all that apply)', 'multipleChoice',
            opts: ['WhatsApp (personal message)', 'WhatsApp (group)',
                'Facebook (personal page or story)', 'Facebook Messenger',
                'Instagram', 'TikTok', 'Email',
                'Face-to-face conversation (without digital sharing)',
                'I do not share content with non-Adventists']),
        _q('C3Q20', 'Q20', 'What kinds of content are you most comfortable sharing with a non-Adventist friend? (Select all that apply)', 'multipleChoice',
            opts: ['Short inspiring videos (1–3 minutes)',
                'Health and wellness tips',
                'Stories of personal transformation',
                'Music and worship songs',
                'Videos about family and relationships',
                'Content about finding hope in difficult times',
                'Bible prophecy or end-time content',
                'Direct evangelistic or sermon content',
                'I am not comfortable sharing any faith content with non-Adventists']),
        _q('C3Q21', 'Q21', 'What holds you back from sharing more faith content with non-Adventist friends? (Select all that apply)', 'multipleChoice',
            opts: ['I don\'t want to seem pushy or preachy',
                'The content doesn\'t feel relevant to them',
                'I don\'t know which content would interest them',
                'I am not confident in my own faith enough to share',
                'I have not found content that feels natural to share',
                'My non-Adventist relationships are limited',
                'Nothing holds me back — I share freely', 'Other']),
        _q('C3Q22', 'Q22', 'If HCSEA created a short video specifically designed for you to share with a non-Adventist friend — how likely would you be to share it?', 'scale',
            sMin: 1, sMax: 10, sMinLbl: 'Very unlikely', sMaxLbl: 'Very likely'),
        _q('C3Q23', 'Q23', 'Describe the non-Adventist person in your life you most wish could encounter the Gospel. What is their background, what do they care about, and what are they searching for?', 'openText',
            req: false,
            note: 'Most important question in Survey C — shapes audience persona development'),
      ]),
      _section('C4 — Community Observations', 'Member eyes and ears in the community', [
        _q('C4Q24', 'Q24', 'In your community, what do you observe as the most common struggle or felt need among non-Adventist people? (Select up to 3)', 'multipleChoice',
            maxSel: 3,
            opts: ['Loneliness and isolation', 'Family conflict or breakdown',
                'Economic hardship or unemployment', 'Mental health and anxiety',
                'Searching for meaning and purpose', 'Questions about faith and truth',
                'Grief or loss', 'Fear about the future', 'Health concerns',
                'Addiction', 'Youth at risk', 'Other']),
        _q('C4Q25', 'Q25', 'What topics do you notice non-Adventist people in your community talking about or interested in on social media?', 'openText',
            note: 'Specific observations are gold — e.g. "My Thai colleagues share mindfulness videos"'),
        _q('C4Q26', 'Q26', 'Which platforms are most popular among non-Adventist people in your community? (Select all that apply)', 'multipleChoice',
            opts: ['Facebook', 'TikTok', 'YouTube', 'Instagram', 'WhatsApp',
                'Telegram', 'X (formerly Twitter)', 'Traditional TV', 'Other']),
        _q('C4Q27', 'Q27', 'What kind of content do non-Adventist people in your community most engage with online? (Select all that apply)', 'multipleChoice',
            opts: ['Entertainment and humour', 'Music', 'News and current events',
                'Food and lifestyle', 'Health and wellness',
                'Motivational and self-improvement', 'Religious or spiritual content',
                'Family and relationships', 'Drama and storytelling',
                'Gaming and youth content']),
        _q('C4Q28', 'Q28', 'How open are the non-Adventist people in your community to conversations about faith and spirituality?', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Very closed', sMaxLbl: 'Very open'),
        _q('C4Q29', 'Q29', 'Have you ever had a non-Adventist friend or family member express interest in learning more about your faith or the Bible?', 'singleChoice',
            opts: ['Yes — more than once', 'Yes — once',
                'Not directly, but I have sensed openness', 'No']),
        _q('C4Q30', 'Q30', 'If yes — what prompted their interest? What were they going through at the time?', 'openText',
            req: false, condOn: 'C4Q29',
            condVals: ['Yes — more than once', 'Yes — once']),
        _q('C4Q31', 'Q31', 'What do you think is the single biggest misconception that non-Adventists in your community have about Christianity or the SDA church?', 'openText',
            req: false),
      ]),
      _section('C5 — Personal Witness Capacity', 'Identifies members who are ready and willing to be active outreach multipliers', [
        _q('C5Q32', 'Q32', 'How confident do you feel in sharing your faith with a non-Adventist friend in a natural, non-pressuring way?', 'scale',
            sMin: 1, sMax: 5, sMinLbl: 'Not confident at all', sMaxLbl: 'Very confident'),
        _q('C5Q33', 'Q33', 'Have you ever invited a non-Adventist friend to a church event, online programme, or evangelistic series?', 'singleChoice',
            opts: ['Yes — multiple times', 'Yes — once',
                'I have wanted to but haven\'t yet',
                'No — I have not thought about doing this']),
        _q('C5Q34', 'Q34', 'What tools or resources from HCSEA would most help you in sharing your faith? (Select up to 3)', 'multipleChoice',
            maxSel: 3,
            opts: ['Short shareable videos in my language on topics my friends care about',
                'Training on how to share my faith naturally online',
                'A WhatsApp message series I can forward to a non-Adventist friend',
                'Invitation cards or links to community events',
                'A guided Bible study I can do with a friend',
                'Content packages for specific occasions (Christmas, Hari Raya, Songkran, etc.)',
                'An online community where I can get support and encouragement',
                'Access to a pastor or Bible worker who can follow up with my contact']),
        _q('C5Q35', 'Q35', 'Would you be willing to be part of a Hope Channel Content Multiplier Network?', 'singleChoice',
            opts: ['Yes — I am very interested',
                'Yes — if I understood more about what it involves',
                'Maybe', 'No']),
        _q('C5Q36', 'Q36', 'Would you be willing to share your story of faith in a short video for Hope Channel Southeast Asia?', 'singleChoice',
            opts: ['Yes — I would love to',
                'Yes — if I felt supported in doing it',
                'Maybe — I would need more information',
                'No — I am not comfortable on camera']),
      ]),
      _section('C6 — Hope Channel Feedback & Suggestions', 'Direct member input into HCSEA\'s content strategy', [
        _q('C6Q37', 'Q37', 'What is one topic or theme you wish Hope Channel Southeast Asia would produce content on — specifically for non-Adventist audiences in your country?', 'openText'),
        _q('C6Q38', 'Q38', 'Is there a specific style of content you think would work well with non-Adventists in your community?', 'openText', req: false,
            note: 'e.g. drama, documentary, testimony, talk show, animated, music'),
        _q('C6Q39', 'Q39', 'What language(s) does HCSEA most urgently need to produce more content in, for the people in your community?', 'openText'),
        _q('C6Q40', 'Q40', 'On a scale of 1–10, how well does current HCSEA content connect with the non-Adventist people in your community?', 'scale',
            req: false, sMin: 1, sMax: 10, sMinLbl: 'Not at all', sMaxLbl: 'Very well'),
        _q('C6Q41', 'Q41', 'Is there anything else you would like to share with Hope Channel Southeast Asia about your community, your non-Adventist relationships, or what content would help your witness?', 'openText',
            req: false),
      ]),
    ];

    return Survey(
      id: 'survey_c',
      code: 'C',
      title: 'Church Member MI Survey',
      description: 'For: SDA Church Members — Groups A & B. '
          'Your observations about your community and your own media habits help us '
          'create better content that reaches the people around you.',
      targetAudience: 'members',
      isActive: false,
      isPublic: false,
      estimatedMinutes: 12,
      sections: sections.map(SurveySection.fromMap).toList(),
      createdAt: DateTime.now(),
    );
  }
}
