import 'package:flutter/foundation.dart';

import '../models/survey.dart';
import '../models/survey_response.dart';
import '../services/survey_service.dart';

class SurveyProvider extends ChangeNotifier {
  final _service = SurveyService();

  List<Survey> _surveys = [];
  bool _loading = false;
  String? _error;

  List<Survey> get surveys => _surveys;
  bool get loading => _loading;
  String? get error => _error;

  void watchSurveys() {
    _service.watchAll().listen((list) {
      _surveys = list;
      notifyListeners();
    });
  }

  Future<Survey?> getSurvey(String id) => _service.getById(id);

  Stream<List<SurveyResponse>> watchResponses(String surveyId) =>
      _service.watchResponses(surveyId);

  Future<int> getResponseCount(String surveyId) =>
      _service.getResponseCount(surveyId);

  Future<void> setActive(String surveyId, {required bool active}) =>
      _service.setActive(surveyId, active: active);

  Future<void> submitResponse(SurveyResponse response) =>
      _service.submitResponse(response);

  Future<void> deleteResponse(String responseId) =>
      _service.deleteResponse(responseId);

  Future<String> createSurvey(Survey survey) =>
      _service.createSurvey(survey);

  Future<void> updateSurveyMeta(String id, Map<String, dynamic> data) =>
      _service.updateSurveyMeta(id, data);

  Future<void> updateSurveySections(String id, List<SurveySection> sections) =>
      _service.updateSurveySections(id, sections);

  Future<void> deleteSurvey(String id) => _service.deleteSurvey(id);

  Future<void> seedIfNeeded() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final exists = await _service.surveysExist();
      if (!exists) await _service.seedSurveys();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reseed() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.seedSurveys();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
