import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/glass.dart';
import '../../domain/models/boiler_house.dart';
import '../auth/auth_providers.dart';
import 'boilerhouse_providers.dart';

class BoilerHouseListScreen extends ConsumerStatefulWidget {
  const BoilerHouseListScreen({super.key});

  @override
  ConsumerState<BoilerHouseListScreen> createState() => _BoilerHouseListScreenState();
}

class _BoilerHouseListScreenState extends ConsumerState<BoilerHouseListScreen> {
  String _search = '';
  String _selectedDistrict = '';

  static const _districts = [
    '', 'Урганч шаҳар', 'Шовот', 'Хонка', 'Қўшкўпир', 'Хазорасп',
    'Тупроккала', 'Янгиариқ', 'Урганч туман', 'Боғот', 'Янгибозор', 'Гурлан', 'Хива',
  ];

  @override
  Widget build(BuildContext context) {
    final allHouses = ref.watch(boilerHouseListProvider);
    final l = ref.watch(l10nProvider);
    var houses = allHouses;
    if (_selectedDistrict.isNotEmpty) {
      houses = houses.where((h) => h.district == _selectedDistrict).toList();
    }
    if (_search.isNotEmpty) {
      houses = houses.where((h) => h.name.toLowerCase().contains(_search) || h.address.toLowerCase().contains(_search)).toList();
    }

    return GlassScaffold(
      title: l.boilerhousesTitle,
      leading: BackButton(onPressed: () => context.go('/home')),
      tab: AppTab.boilerhouses,
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _districts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _districts[i];
                final selected = d == _selectedDistrict;
                return ChoiceChip(
                  label: Text(d.isEmpty ? l.allDistricts : d),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedDistrict = d),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : AppTheme.inkSoft,
                  ),
                  selectedColor: AppTheme.primary,
                  backgroundColor: Colors.white.withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  side: BorderSide(color: selected ? AppTheme.primary : AppTheme.glassBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: GlassSearchField(
              hint: '${l.boilerhousesTitle}...',
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: houses.isEmpty
                ? Center(child: Text(l.boilerhouseNotFound, style: const TextStyle(color: AppTheme.inkFaint)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, kBottomNavSpace),
                    itemCount: houses.length,
                    scrollCacheExtent: ScrollCacheExtent.pixels(300),
                    addAutomaticKeepAlives: false,
                    itemBuilder: (context, index) {
                      final bh = houses[index];
                      return RepaintBoundary(
                        child: _BoilerHouseCard(boilerHouse: bh, l: l),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

const _statusColors = <BoilerHouseStatus, Color>{
  BoilerHouseStatus.operating: AppTheme.success,
  BoilerHouseStatus.maintenance: AppTheme.warning,
  BoilerHouseStatus.emergencyShutdown: AppTheme.error,
  BoilerHouseStatus.mothballed: AppTheme.inkFaint,
};

class _BoilerHouseCard extends StatelessWidget {
  final BoilerHouse boilerHouse;
  final dynamic l;
  const _BoilerHouseCard({required this.boilerHouse, required this.l});

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[boilerHouse.status]!;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/boilerhouses/${boilerHouse.id}'),
      child: Row(
        children: [
          const GlassIconTile(icon: Icons.factory_outlined, color: AppTheme.primary, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  boilerHouse.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${boilerHouse.installedCapacity} Гкал/с • ${boilerHouse.address}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: boilerHouse.status.label(l), color: color),
        ],
      ),
    );
  }
}
