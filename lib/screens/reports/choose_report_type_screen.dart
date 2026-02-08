import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChooseReportTypeScreen extends StatelessWidget {
  const ChooseReportTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/admin-hub'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'Select Report Type',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose the type of report you want to create',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 720;
                      return Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          SizedBox(
                            width: isNarrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 2,
                            child: _buildReportTypeCard(
                              context: context,
                              title: 'Petty Cash Report',
                              description:
                                  'Track petty cash disbursements and reconcile cash on hand',
                              icon: Icons.account_balance_wallet,
                              color: Colors.blue,
                              onTap: () => context.go('/reports/new/petty-cash'),
                            ),
                          ),
                          SizedBox(
                            width: isNarrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 2,
                            child: _buildReportTypeCard(
                              context: context,
                              title: 'Project Report',
                              description:
                                  'Manage project budgets and track expenses against allocated funds',
                              icon: Icons.folder_special,
                              color: Colors.green,
                              onTap: () => context.go('/reports/new/project'),
                            ),
                          ),
                          SizedBox(
                            width: isNarrow
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 24) / 2,
                            child: _buildReportTypeCard(
                              context: context,
                              title: 'Advance Settlement Report',
                              description:
                                  'Generate the advance settlement form for finance review',
                              icon: Icons.request_page,
                              color: Colors.orange,
                              onTap: () =>
                                  context.go('/reports/new/advance-settlement'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportTypeCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: color),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
