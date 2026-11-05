import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ist_time.dart';
import '../../prediction/data/model_repository.dart';
import '../data/report_store.dart';
import '../domain/arrival_report.dart';

/// The rider's ground-truth reports, how well the model did on them, and export for Colab.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider).value ?? const <ArrivalReport>[];
    final model = ref.watch(delayModelProvider).value;
    final theme = Theme.of(context);

    final n = reports.length;
    double avg(Iterable<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    final avgDelay = avg(reports.map((r) => r.delayMin));
    final mae = avg(reports.map((r) => r.errorMin.abs()));
    final hit = n == 0 ? 0 : reports.where((r) => r.withinQ90).length / n;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your reports'),
        actions: [
          if (n > 0)
            IconButton(
              tooltip: 'Delete all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete all reports?'),
                    content: const Text('This removes them from this phone. Export first if you want to keep them.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) await ref.read(reportsProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (model != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.model_training),
                title: Text('Model ${model.version}'),
                subtitle: Text(
                  'Trained on ${model.trainedOn}. Test error ${model.metrics['mae_q50_min']} min '
                  '(schedule alone: ${model.metrics['mae_schedule_baseline_min']} min), '
                  '90% bound holds ${((model.metrics['q90_coverage'] ?? 0) * 100).round()}% of the time.'
                  '${model.isPriorOnly ? '\nEarly estimate: your reports make it better.' : ''}',
                ),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 8),
          Row(children: [
            _Stat(label: 'Reports', value: '$n'),
            _Stat(label: 'Avg delay', value: n == 0 ? '-' : formatDelay(avgDelay)),
            _Stat(label: 'Model error', value: n == 0 ? '-' : '${mae.toStringAsFixed(1)} min'),
            _Stat(label: 'Within 90%', value: n == 0 ? '-' : '${(hit * 100).round()}%'),
          ]),
          const SizedBox(height: 12),
          if (n == 0)
            const Card(
              child: ListTile(
                leading: Icon(Icons.where_to_vote_outlined),
                title: Text('No reports yet'),
                subtitle: Text('At your stop, tap "Arrived" when your bus comes. '
                    'Each report is real ground truth for the model.'),
              ),
            )
          else ...[
            FilledButton.tonalIcon(
              key: const Key('export-csv'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: reportsToCsv(reports)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('CSV copied. Paste it into reports.csv in Colab and run '
                        'train_delay_model.py --reports reports.csv'),
                  ));
                }
              },
              icon: const Icon(Icons.copy_all),
              label: const Text('Copy reports as CSV (for Colab retraining)'),
            ),
            const SizedBox(height: 8),
            for (final r in reports)
              Card(
                child: ListTile(
                  title: Text('${r.routeShort} at ${r.stopName}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Scheduled ${formatTime(r.scheduled)} · arrived ${formatTime(r.reportedAt)}'
                      ' · predicted ${formatDelay(r.predictedQ50)}${r.rainMode ? ' · rain' : ''}'),
                  trailing: Text(formatDelay(r.delayMin), style: theme.textTheme.titleMedium),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(children: [
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}
