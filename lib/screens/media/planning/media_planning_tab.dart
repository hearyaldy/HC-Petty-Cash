import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../models/media_production_planning.dart';
import '../../../providers/media_planning_provider.dart';
import '../../../services/media_planning_pdf_service.dart';
import '../../../utils/responsive_helper.dart';
import '../../../widgets/media_planning_stage_rail.dart';
import 'steps/approvals_step.dart';
import 'steps/audience_step.dart';
import 'steps/budget_step.dart';
import 'steps/distribution_step.dart';
import 'steps/market_research_step.dart';
import 'steps/objective_step.dart';
import 'steps/program_identity_step.dart';
import 'steps/strategic_intent_step.dart';
import 'steps/summary_step.dart';

/// The "Planning" tab of a Media Production's detail screen — digitizes
/// Workflow HC's 8-step Planning stage directly on the production
/// record, with a stage rail (vertical on wide screens, a horizontal
/// strip on phone width) and Gemini-backed drafting on the
/// research-heavy steps.
class MediaPlanningTab extends StatefulWidget {
  const MediaPlanningTab({
    super.key,
    required this.productionId,
    required this.productionTitle,
  });

  final String productionId;
  final String productionTitle;

  static const stepTitles = [
    'Objective',
    'Audience',
    'Strategic Intent',
    'Market Research',
    'Program Identity',
    'Distribution',
    'Budget',
    'Summary',
    'Approvals',
  ];

  @override
  State<MediaPlanningTab> createState() => _MediaPlanningTabState();
}

class _MediaPlanningTabState extends State<MediaPlanningTab> {
  int _currentStep = 0;
  final _pdfService = MediaPlanningPdfService();
  bool _isExporting = false;

  Future<void> _exportPdf(MediaProductionPlanning planning) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _pdfService.exportPlanning(
        productionTitle: widget.productionTitle,
        planning: planning,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Planning document: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Moves to the next step after a successful Save — the wizard reads
  /// top-to-bottom, so finishing one section should hand the user
  /// straight to the next instead of leaving them to find the rail.
  void _advance() {
    if (_currentStep < MediaPlanningTab.stepTitles.length - 1) {
      setState(() => _currentStep += 1);
    }
  }

  Widget _stepBody(int index) {
    switch (index) {
      case 0:
        return ObjectiveStep(onSaved: _advance);
      case 1:
        return AudienceStep(onSaved: _advance);
      case 2:
        return StrategicIntentStep(onSaved: _advance);
      case 3:
        return MarketResearchStep(onSaved: _advance);
      case 4:
        return ProgramIdentityStep(onSaved: _advance);
      case 5:
        return DistributionStep(onSaved: _advance);
      case 6:
        return BudgetStep(onSaved: _advance);
      case 7:
        return SummaryStep(onContinue: _advance, onEditStep: (i) => setState(() => _currentStep = i));
      case 8:
      default:
        return const ApprovalsStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MediaPlanningProvider>(
      // Keyed by productionId so switching productions always creates a
      // fresh provider (and reloads Firestore) even if this tab's own
      // State gets reused by the framework — ChangeNotifierProvider's
      // `create` otherwise only ever runs once per element.
      key: ValueKey(widget.productionId),
      create: (_) => MediaPlanningProvider()..loadPlanning(widget.productionId),
      child: Consumer<MediaPlanningProvider>(
        builder: (context, provider, _) {
          final planning = provider.planning;

          if (provider.isLoading && planning == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (planning == null) {
            return const Center(child: Text('Could not load Planning data.'));
          }

          // One flag per section, computed directly rather than from the
          // running completedStepCount — with a "Summary" step spliced
          // in between Budget and Approvals, a simple "first N steps
          // done" count no longer lines up with step indices.
          final sectionsFilled = [
            !planning.objective.isEmpty,
            !planning.audience.isEmpty,
            !planning.strategicIntent.isEmpty,
            !planning.marketResearch.isEmpty,
            !planning.identity.isEmpty,
            !planning.distribution.isEmpty,
            !planning.budget.isEmpty,
          ];
          final completed = [
            ...sectionsFilled,
            sectionsFilled.every((filled) => filled), // Summary "done" once every section is filled
            planning.isApprovalsComplete,
          ];

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.getMaxContentWidth(context),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getScreenPadding(context).horizontal / 2,
                ),
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.description_outlined, size: 18, color: Colors.pink.shade400),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Planning Document',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isExporting ? null : () => _exportPdf(planning),
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.print, size: 18),
                            label: Text(_isExporting ? 'Preparing…' : 'Print / Save PDF'),
                            style: TextButton.styleFrom(foregroundColor: Colors.pink.shade700),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    LinearProgressIndicator(
                      value: planning.completedStepCount / MediaProductionPlanning.totalStepCount,
                      color: Colors.pink,
                      backgroundColor: Colors.pink.shade50,
                      minHeight: 3,
                    ),
                    if (!provider.aiAvailable)
                      Container(
                        width: double.infinity,
                        color: Colors.amber.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'AI drafting is unavailable — set AI_API_KEY in .env to enable it.',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 760;
                          final rail = MediaPlanningStageRail(
                            steps: MediaPlanningTab.stepTitles,
                            currentIndex: _currentStep,
                            completed: completed,
                            horizontal: isNarrow,
                            onStepSelected: (i) => setState(() => _currentStep = i),
                          );

                          if (isNarrow) {
                            return Column(
                              children: [
                                SizedBox(height: 52, child: rail),
                                const Divider(height: 1),
                                Expanded(child: _stepBody(_currentStep)),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              SizedBox(
                                width: 220,
                                child: Padding(padding: const EdgeInsets.all(12), child: rail),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(child: _stepBody(_currentStep)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
