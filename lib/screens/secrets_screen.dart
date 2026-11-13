import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell.dart';
import '../theme/phosphor.dart';

/// Map placeholder (P2) plus the Easter eggs & secrets list (P1).
class SecretsScreen extends StatelessWidget {
  const SecretsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: kNavClearance),
      children: [
        const ScreenHeader(title: 'Map & Secrets', caption: 'Discoveries across Leonida'),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  const Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navSurface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Row(
                        children: [
                          const Icon(PhosphorIconsRegular.mapTrifold, size: 24, color: AppColors.accentSoft),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Interactive map', style: AppText.heading(context)),
                                Text('Arrives after launch, built from tested locations.',
                                    style: AppText.caption(context)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text('Easter eggs & secrets', style: AppText.heading(context)),
        ),
        const SizedBox(height: 10),
        for (final s in MockData.secrets)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(PhosphorIconsRegular.sparkle, size: 22, color: AppColors.accentSoft),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: AppText.itemTitle(context)),
                        Text(s.area, style: AppText.caption(context)),
                        const SizedBox(height: 8),
                        Text(s.summary, style: AppText.body(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: s.status, compact: true),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Decorative map grid with a few pins: a stand-in, not real geography.
class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final dot = Paint()..color = AppColors.accent;
    for (final f in const [Offset(0.22, 0.28), Offset(0.58, 0.18), Offset(0.78, 0.42), Offset(0.4, 0.46)]) {
      final c = Offset(f.dx * size.width, f.dy * size.height);
      canvas.drawCircle(c, 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
