import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/inr.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(billRepoProvider).dashboard();
  }

  void _refresh() {
    setState(() {
      _future = ref.read(billRepoProvider).dashboard();
    });
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DT.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Today's overview",
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: DT.s16),
          FutureBuilder<Map<String, dynamic>?>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _errorBox(snap.error.toString());
              }
              final data = snap.data ?? const <String, dynamic>{};
              final today = Map<String, dynamic>.from(
                  data['today'] as Map? ?? data);
              final sales = _num(today['sales_total'] ?? data['sales_total']);
              final cash = _num(today['cash_total'] ?? data['cash_total']);
              final cyl = _num(today['cylinders_sold'] ??
                  data['cylinders_sold'] ??
                  0);
              final outstanding = _num(data['outstanding_total'] ??
                  data['outstanding'] ??
                  today['outstanding'] ??
                  0);
              return Wrap(
                spacing: DT.s16,
                runSpacing: DT.s16,
                children: [
                  _Kpi(
                    label: "Today's Sales",
                    value: fmtINR(sales),
                    icon: Icons.trending_up,
                    tint: DT.brand50,
                    fg: DT.brand700,
                  ),
                  _Kpi(
                    label: "Cash Collected",
                    value: fmtINR(cash),
                    icon: Icons.payments_outlined,
                    tint: DT.ok50,
                    fg: DT.ok700,
                  ),
                  _Kpi(
                    label: "Cylinders Sold",
                    value: cyl.toInt().toString(),
                    icon: Icons.propane_tank_outlined,
                    tint: DT.info500.withValues(alpha: .08),
                    fg: DT.info600,
                  ),
                  _Kpi(
                    label: "Outstanding Dues",
                    value: fmtINR(outstanding),
                    icon: Icons.warning_amber_outlined,
                    tint: DT.warn50,
                    fg: DT.warn700,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: DT.s32),
          Text('Quick actions',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: DT.s12),
          Wrap(
            spacing: DT.s12,
            runSpacing: DT.s12,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/bills/new'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Bill'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/customers'),
                icon: const Icon(Icons.person_add_alt, size: 16),
                label: const Text('Add Customer'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/products'),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Manage Products'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(DT.s16),
        decoration: BoxDecoration(
          color: DT.err50,
          borderRadius: BorderRadius.circular(DT.rSm),
          border: Border.all(color: DT.err500.withValues(alpha: .3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: DT.err700, size: 18),
            const SizedBox(width: DT.s8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: DT.err700, fontSize: DT.fsSm)),
            ),
          ],
        ),
      );
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Color fg;
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(DT.s16),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(DT.rSm),
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: DT.s12),
          Text(label,
              style: const TextStyle(color: DT.text2, fontSize: DT.fsSm)),
          const SizedBox(height: DT.s4),
          Text(value, style: AppTheme.mono(size: 22, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
