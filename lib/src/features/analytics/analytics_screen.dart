import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../core/l10n.dart';
import '../../domain/models/boiler_house.dart';
import '../auth/auth_providers.dart';
import '../boilerhouse/boilerhouse_providers.dart';

/// Consumption metric the "by district" / "top 5" sections are pivoted on.
enum _Metric { gas, electricity, water, heat }

extension on _Metric {
  String label(AppL10n l) {
    switch (this) {
      case _Metric.gas:
        return l.fieldNaturalGas;
      case _Metric.electricity:
        return l.fieldElectricity;
      case _Metric.water:
        return l.fieldColdWater;
      case _Metric.heat:
        return l.analyticsHeat;
    }
  }

  double valueOf(BoilerHouse h) {
    switch (this) {
      case _Metric.gas:
        return h.annualGas;
      case _Metric.electricity:
        return h.annualElectricity;
      case _Metric.water:
        return h.annualWater;
      case _Metric.heat:
        return h.annualHeatProduction;
    }
  }
}

/// StatusChip colors from the design tokens (same mapping as the list screen).
const _statusColors = <BoilerHouseStatus, Color>{
  BoilerHouseStatus.operating: AppTheme.success,
  BoilerHouseStatus.maintenance: AppTheme.warning,
  BoilerHouseStatus.emergencyShutdown: AppTheme.error,
  BoilerHouseStatus.mothballed: AppTheme.inkFaint,
};

final NumberFormat _grouped = NumberFormat('#,###', 'en_US');

/// Formats with thin-space (U+202F) thousands separators. The locale is pinned
/// so the grouping character is always known before being replaced.
String _fmt(num value) {
  final rounded = value.round();
  if (rounded == 0) return '0';
  return _grouped.format(rounded).replaceAll(',', ' ');
}

/// Analytics over the loaded boiler house passports: fleet totals, per-district
/// bars, top consumers and status breakdown. Pushed screen (no bottom nav).
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Metric _metric = _Metric.gas;

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(l10nProvider);
    final houses = ref.watch(boilerHouseListProvider);

    return GlassScaffold(
      title: l.analyticsTitle,
      body: houses.isEmpty
          ? _EmptyState(message: l.boilerhouseNotFound)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                _SectionTitle(l.analyticsTotals),
                _TotalsCard(houses: houses, l: l),
                const SizedBox(height: 20),
                _metricSelector(l),
                const SizedBox(height: 20),
                _SectionTitle(l.analyticsByDistrict),
                _DistrictCard(houses: houses, metric: _metric),
                const SizedBox(height: 20),
                _SectionTitle(l.analyticsTop),
                _TopCard(houses: houses, metric: _metric),
                const SizedBox(height: 20),
                _SectionTitle(l.analyticsStatuses),
                _StatusCard(houses: houses, l: l),
              ],
            ),
    );
  }

  Widget _metricSelector(AppL10n l) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final m in _Metric.values) ...[
            if (m != _Metric.values.first) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(m.label(l)),
              selected: m == _metric,
              onSelected: (_) => setState(() => _metric = m),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: m == _metric ? FontWeight.w700 : FontWeight.w500,
                color: m == _metric ? Colors.white : AppTheme.inkSoft,
              ),
              selectedColor: AppTheme.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              side: BorderSide(color: m == _metric ? AppTheme.primary : AppTheme.glassBorder),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.query_stats_rounded, size: 48, color: AppTheme.inkFaint.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(fontSize: 14, color: AppTheme.inkFaint)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// 2x2 grid of fleet-wide annual totals.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.houses, required this.l});

  final List<BoilerHouse> houses;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    double gas = 0, electricity = 0, water = 0, heat = 0;
    for (final h in houses) {
      gas += h.annualGas;
      electricity += h.annualElectricity;
      water += h.annualWater;
      heat += h.annualHeatProduction;
    }
    return GlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatTile(value: gas, caption: l.fieldNaturalGas, unit: l.unitM3)),
              const SizedBox(width: 14),
              Expanded(child: _StatTile(value: electricity, caption: l.fieldElectricity, unit: l.unitKw)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatTile(value: water, caption: l.fieldColdWater, unit: l.unitM3)),
              const SizedBox(width: 14),
              Expanded(child: _StatTile(value: heat, caption: l.analyticsHeat, unit: 'Гкал')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.caption, required this.unit});

  final double value;
  final String caption;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _fmt(value),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.ink,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$caption, $unit',
          maxLines: 2,
          style: const TextStyle(fontSize: 11.5, color: AppTheme.inkSoft, height: 1.3),
        ),
      ],
    );
  }
}

/// Horizontal bar rows, one per district, sorted by the selected metric.
class _DistrictCard extends StatelessWidget {
  const _DistrictCard({required this.houses, required this.metric});

  final List<BoilerHouse> houses;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final h in houses) {
      final district = h.district.isEmpty ? '—' : h.district;
      totals[district] = (totals[district] ?? 0) + metric.valueOf(h);
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 0.0 : entries.first.value;

    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _DistrictRow(
              name: entries[i].key,
              value: entries[i].value,
              fraction: max <= 0 ? 0 : (entries[i].value / max).clamp(0.0, 1.0).toDouble(),
            ),
          ],
        ],
      ),
    );
  }
}

class _DistrictRow extends StatelessWidget {
  const _DistrictRow({required this.name, required this.value, required this.fraction});

  final String name;
  final double value;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.ink),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _fmt(value),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: [
                Container(
                  width: width,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  width: width * fraction,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.primary]),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Top-5 boiler houses by the selected metric.
class _TopCard extends StatelessWidget {
  const _TopCard({required this.houses, required this.metric});

  final List<BoilerHouse> houses;
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final sorted = [...houses]..sort((a, b) => metric.valueOf(b).compareTo(metric.valueOf(a)));
    final top = sorted.take(5).toList();

    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _TopRow(rank: i + 1, house: top[i], value: metric.valueOf(top[i])),
          ],
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({required this.rank, required this.house, required this.value});

  final int rank;
  final BoilerHouse house;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withValues(alpha: 0.12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
          ),
          child: Text(
            '$rank',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                house.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (house.district.isNotEmpty)
                Text(
                  house.district,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.inkSoft),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _fmt(value),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary),
        ),
      ],
    );
  }
}

/// Status breakdown plus a defects counter.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.houses, required this.l});

  final List<BoilerHouse> houses;
  final AppL10n l;

  @override
  Widget build(BuildContext context) {
    final counts = <BoilerHouseStatus, int>{};
    var defects = 0;
    for (final h in houses) {
      counts[h.status] = (counts[h.status] ?? 0) + 1;
      if (h.defects.trim().isNotEmpty) defects++;
    }
    final rows = <Widget>[
      for (final status in BoilerHouseStatus.values)
        if (counts.containsKey(status))
          _statusRow(
            StatusChip(label: status.label(l), color: _statusColors[status]!),
            counts[status]!,
            _statusColors[status]!,
          ),
      _statusRow(
        StatusChip(label: l.analyticsDefects, color: AppTheme.warning, icon: Icons.report_problem_outlined),
        defects,
        AppTheme.warning,
      ),
    ];

    return GlassCard(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _statusRow(StatusChip chip, int count, Color color) {
    return Row(
      children: [
        chip,
        const Spacer(),
        Text('$count', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
