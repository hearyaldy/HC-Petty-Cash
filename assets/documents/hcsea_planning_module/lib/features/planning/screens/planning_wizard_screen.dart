import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/planning_project_provider.dart';
import '../widgets/stage_progress_rail.dart';
import 'steps/approvals_step.dart';
import 'steps/audience_step.dart';
import 'steps/budget_step.dart';
import 'steps/distribution_step.dart';
import 'steps/market_research_step.dart';
import 'steps/objective_step.dart';
import 'steps/program_identity_step.dart';
import 'steps/strategic_intent_step.dart';

/// The main Planning screen for one project — an 8-step wizard with a
/// stage rail on the side (collapsing to a top tab bar on phone width,
/// matching the responsive pattern from the original proposal page).
///
/// Usage: wrap in a `ChangeNotifierProvider<PlanningProjectProvider>`
/// higher up the widget tree (see README.md), then push this screen
/// with a `projectId` and call `provider.loadProject(projectId)`.
class PlanningWizardScreen extends StatefulWidget {
  const PlanningWizardScreen({super.key, required this.projectId});

  final String projectId;

  static const stepTitles = [
    'Objective',
    'Audience',
    'Strategic Intent',
    'Market Research',
    'Program Identity',
    'Distribution',
    'Budget',
    'Approvals',
  ];

  @override
  State<PlanningWizardScreen> createState() => _PlanningWizardScreenState();
}

class _PlanningWizardScreenState extends State<PlanningWizardScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanningProjectProvider>().loadProject(widget.projectId);
    });
  }

  Widget _stepBody(int index) {
    switch (index) {
      case 0:
        return const ObjectiveStep();
      case 1:
        return const AudienceStep();
      case 2:
        return const StrategicIntentStep();
      case 3:
        return const MarketResearchStep();
      case 4:
        return const ProgramIdentityStep();
      case 5:
        return const DistributionStep();
      case 6:
        return const BudgetStep();
      case 7:
      default:
        return const ApprovalsStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanningProjectProvider>();
    final project = provider.project;

    if (provider.isLoading || project == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final completed = List.generate(
      PlanningWizardScreen.stepTitles.length,
      (i) => i < project.completedStepCount,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title.isEmpty ? 'Untitled project' : project.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: project.completedStepCount / PlanningWizardScreen.stepTitles.length,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;
          final rail = StageProgressRail(
            steps: PlanningWizardScreen.stepTitles,
            currentIndex: _currentStep,
            completed: completed,
            onStepSelected: (i) => setState(() => _currentStep = i),
          );

          if (isNarrow) {
            return Column(
              children: [
                SizedBox(height: 56, child: rail),
                const Divider(height: 1),
                Expanded(child: _stepBody(_currentStep)),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(width: 220, child: Padding(padding: const EdgeInsets.all(12), child: rail)),
              const VerticalDivider(width: 1),
              Expanded(child: _stepBody(_currentStep)),
            ],
          );
        },
      ),
    );
  }
}
