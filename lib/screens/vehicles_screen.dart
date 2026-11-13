import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell.dart';
import '../theme/phosphor.dart';
import '../utils/format.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  VehicleClass? _class; // null = all
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = MockData.vehicles
        .where((v) => _class == null || v.vehicleClass == _class)
        .where((v) => v.name.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(title: 'Vehicles', caption: 'Directory fills in after launch'),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SearchPill(
                  controller: null,
                  hint: 'Search vehicles',
                  onChanged: (q) => setState(() => _query = q),
                ),
              ),
              const SizedBox(height: 14),
              PillChips<VehicleClass?>(
                items: [null, ...VehicleClass.values],
                selected: _class,
                labelOf: (c) => c?.label ?? 'All',
                onSelected: (c) => setState(() => _class = c),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (list.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: PhosphorIconsRegular.car,
              title: 'No vehicles found',
              message: 'Try another name or class.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, kNavClearance),
            sliver: SliverGrid.builder(
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, i) => _VehicleCard(vehicle: list[i]),
            ),
          ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final speed = vehicle.specs.topSpeedMph;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      onTap: () => _showVehicle(context, vehicle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: Icon(vehicle.vehicleClass.icon, size: 44, color: AppColors.text.withValues(alpha: 0.85)),
                ),
                if (vehicle.exclusiveTo != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Tooltip(
                      message: '${vehicle.exclusiveTo!.label} only',
                      child: const Icon(PhosphorIconsRegular.crownSimple, size: 18, color: AppColors.rumour),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(vehicle.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle(context)),
          const SizedBox(height: 2),
          Text(
            speed == null ? vehicle.vehicleClass.label : '${vehicle.vehicleClass.label} · ${wholeNumber(speed)} mph',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.numeric(AppText.caption(context)),
          ),
        ],
      ),
    );
  }
}

/// Spec rows that apply to this kind of vehicle (no doors on a bike).
List<(String, String?)> _specRows(Vehicle v) {
  final s = v.specs;
  final isCar = v.vehicleClass == VehicleClass.cars;
  final hasGears = isCar || v.vehicleClass == VehicleClass.bikes;
  return [
    ('Manufacturer', s.manufacturer),
    ('Class', v.vehicleClass.label),
    ('Top speed', s.topSpeedMph == null ? null : '${wholeNumber(s.topSpeedMph!)} mph'),
    ('Seats', s.seats?.toString()),
    if (isCar) ('Doors', s.doors?.toString()),
    if (isCar) ('Drivetrain', s.drivetrain),
    if (hasGears) ('Gears', s.gears?.toString()),
    ('Weight', s.weightKg == null ? null : '${thousands(s.weightKg!)} kg'),
  ];
}

void _showVehicle(BuildContext context, Vehicle v) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SafeArea(child: _VehicleSheet(vehicle: v)),
    ),
  );
}

class _VehicleSheet extends StatelessWidget {
  const _VehicleSheet({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final rank = speedRankInClass(v, MockData.vehicles);
    final tags = [
      if (v.addedIn != null) InfoTag(icon: PhosphorIconsRegular.tag, label: 'Added in ${v.addedIn}'),
      if (v.exclusiveTo != null)
        InfoTag(
          icon: PhosphorIconsRegular.crownSimple,
          label: '${v.exclusiveTo!.label} only',
          color: AppColors.rumour,
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [if (v.specs.manufacturer != null) v.specs.manufacturer!, v.vehicleClass.label].join(' · '),
                      style: AppText.caption(context),
                    ),
                    const SizedBox(height: 2),
                    Text(v.name, style: AppText.cardTitle(context)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(status: v.status),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: tags),
          ],
          if (rank != null) ...[
            const SizedBox(height: 18),
            _RankLine(position: rank.position, total: rank.total, className: v.vehicleClass.label),
          ],
          const SizedBox(height: 18),
          Text('Specs', style: AppText.heading(context)),
          const SizedBox(height: 4),
          SpecGrid(rows: _specRows(v)),
          const SizedBox(height: 18),
          Text('Performance', style: AppText.heading(context)),
          const SizedBox(height: 12),
          for (final stat in PerformanceStat.values) ...[
            MeterBar(
              label: stat.label,
              value: v.performance[stat] == null ? 'TBD' : '${(v.performance[stat]! * 100).round()}',
              progress: v.performance[stat] ?? 0,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Text(
            'TBD values are filled in once they are measured in the released game.',
            style: AppText.caption(context),
          ),
        ],
      ),
    );
  }
}

/// "2nd of 3 Cars · by top speed".
class _RankLine extends StatelessWidget {
  const _RankLine({required this.position, required this.total, required this.className});
  final int position;
  final int total;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ranked ${ordinal(position)} of $total $className by top speed',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.trophy,
            size: 20,
            color: position == 1 ? AppColors.rumour : AppColors.accentSoft,
          ),
          const SizedBox(width: 10),
          Text(ordinal(position), style: AppText.numeric(AppText.heading(context))),
          const SizedBox(width: 6),
          Expanded(
            child: Text('of $total $className · by top speed', style: AppText.numeric(AppText.caption(context))),
          ),
        ],
      ),
    );
  }
}
