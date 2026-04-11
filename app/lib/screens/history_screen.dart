import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';
import '../widgets/common_widgets.dart';
import 'disease_result_screen.dart';
import 'weeds_result_screen.dart';

// ═══════════════════════════════════════════════════════
// HISTORY SCREEN
// ═══════════════════════════════════════════════════════

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filterIndex = 0;
  final List<String> _filters = ['Toutes', 'Maladies', 'Herbes', 'Saines'];
  final List<ScanHistory> _allHistory = ScanHistory.demoList;

  List<ScanHistory> get _filtered {
    switch (_filterIndex) {
      case 1: return _allHistory.where((h) => h.status == ScanStatus.maladie).toList();
      case 2: return _allHistory.where((h) => h.status == ScanStatus.herbes).toList();
      case 3: return _allHistory.where((h) => h.status == ScanStatus.sain).toList();
      default: return _allHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _filtered.where(
      (h) => h.date.day == DateTime.now().day,
    ).toList();
    final yesterday = _filtered.where(
      (h) => h.date.day == DateTime.now().day - 1,
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ──
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 20, right: 20, bottom: 16,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes analyses',
                  style: GoogleFonts.nunito(
                    fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.g900,
                  ),
                ),
                const SizedBox(height: 14),
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: StatMiniCard(
                        value: '127', label: 'Analyses', valueColor: AppColors.g700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatMiniCard(
                        value: '14', label: 'Maladies', valueColor: AppColors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatMiniCard(
                        value: '97%', label: 'Précision', valueColor: AppColors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Search
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(
                        'Chercher une culture, maladie…',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 15, color: AppColors.t3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter chips
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => setState(() => _filterIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _filterIndex == i ? AppColors.g700 : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: _filterIndex == i ? AppColors.g700 : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _filters[i],
                            style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _filterIndex == i ? Colors.white : AppColors.t2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Mini chart
                  _MiniBarChart(),
                  const SizedBox(height: 14),
                  // Today group
                  if (today.isNotEmpty) ...[
                    _DateLabel('Aujourd\'hui'),
                    ...today.map((h) => _HistoryCard(history: h, onTap: () => _onItemTap(h))),
                  ],
                  // Yesterday group
                  if (yesterday.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _DateLabel('Hier'),
                    ...yesterday.map((h) => _HistoryCard(history: h, onTap: () => _onItemTap(h))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTap(ScanHistory history) {
    if (history.type == ScanType.weeds) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WeedsResultScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DiseaseResultScreen()),
      );
    }
  }
}

class _DateLabel extends StatelessWidget {
  final String text;
  const _DateLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.t3, letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanHistory history;
  final VoidCallback onTap;

  const _HistoryCard({required this.history, required this.onTap});

  ScanStatusColor get _statusColor {
    switch (history.status) {
      case ScanStatus.sain:    return ScanStatusColor.sain;
      case ScanStatus.maladie: return ScanStatusColor.maladie;
      case ScanStatus.herbes:  return ScanStatusColor.herbes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HistoryItem(
      emoji: history.emoji,
      title: history.cropName,
      subtitle: '${history.fieldName} · ${_formatTime(history.date)}',
      statusLabel: history.statusLabel,
      confidence: history.confidence,
      statusColor: _statusColor,
      onTap: onTap,
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day) {
      return 'Aujourd\'hui ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Hier ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ── Mini bar chart ────────────────────────────────────────
class _MiniBarChart extends StatelessWidget {
  final List<double> greenBars = const [28, 44, 20, 54, 38, 48, 34];
  final List<double> amberBars = const [10, 20, 8, 24, 16, 20, 14];
  final List<String> labels = const ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analyses · 7 derniers jours',
                style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1,
                ),
              ),
              Row(
                children: [
                  _LegendDot(color: AppColors.g600, label: 'Saines'),
                  const SizedBox(width: 12),
                  _LegendDot(color: AppColors.amber, label: 'Maladies'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final maxH = 72.0;
                final maxVal = 72.0;
                final gH = (greenBars[i] / maxVal * maxH).clamp(4.0, maxH);
                final aH = (amberBars[i] / maxVal * maxH).clamp(4.0, maxH);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            height: gH,
                            decoration: BoxDecoration(
                              color: AppColors.g600.withOpacity(i == 3 ? 1.0 : 0.5),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Expanded(
                          child: Container(
                            height: aH,
                            decoration: BoxDecoration(
                              color: AppColors.amber.withOpacity(i == 3 ? 1.0 : 0.45),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: labels.map((l) => Expanded(
              child: Text(
                l, textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.t3),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3)),
      ],
    );
  }
}
