import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planning_project.dart';
import '../services/planning_repository.dart';
import '../state/planning_project_provider.dart';
import 'planning_wizard_screen.dart';

/// Entry point for the Planning module: lists existing projects with
/// their Planning progress (x / 8 steps) and lets the user start a
/// new one. Drop this into hopechannel.asia's navigation wherever
/// "Planning" or "Mission Intelligence" belongs alongside the other
/// stages.
class PlanningDashboardScreen extends StatelessWidget {
  const PlanningDashboardScreen({
    super.key,
    required this.currentUserUid,
    required this.currentUserName,
  });

  final String currentUserUid;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    final repository = PlanningRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Planning')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New project'),
        onPressed: () => _showNewProjectDialog(context, repository),
      ),
      body: StreamBuilder<List<PlanningProject>>(
        stream: repository.watchProjects(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snapshot.data!;
          if (projects.isEmpty) {
            return const Center(child: Text('No projects yet — start one with the button below.'));
          }
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final p = projects[index];
              return ListTile(
                title: Text(p.title.isEmpty ? 'Untitled project' : p.title),
                subtitle: Text('${p.country} · ${p.completedStepCount}/${PlanningProject.totalStepCount} steps'),
                trailing: SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                    value: p.completedStepCount / PlanningProject.totalStepCount,
                  ),
                ),
                onTap: () => _openProject(context, repository, p.id),
              );
            },
          );
        },
      ),
    );
  }

  void _openProject(BuildContext context, PlanningRepository repository, String projectId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          // Supply your real Gemini API key via your existing secrets
          // management (e.g. the same source LPMI 4.0 reads from) —
          // never hardcode it here.
          create: (_) => PlanningProjectProvider(
            repository: repository,
            geminiService: throw UnimplementedError(
              'Construct GeminiPlanningService(apiKey: <your key>) here.',
            ),
          ),
          child: PlanningWizardScreen(projectId: projectId),
        ),
      ),
    );
  }

  Future<void> _showNewProjectDialog(BuildContext context, PlanningRepository repository) async {
    final titleController = TextEditingController();
    String country = 'Thailand';

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Project title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: country,
              decoration: const InputDecoration(labelText: 'Country'),
              items: const [
                'Cambodia',
                'Laos',
                'Malaysia',
                'Brunei',
                'Thailand',
                'Vietnam',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => country = v ?? country,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final project = await repository.createProject(
                title: titleController.text.trim(),
                country: country,
                ownerUid: currentUserUid,
                ownerName: currentUserName,
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) _openProject(context, repository, project.id);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
