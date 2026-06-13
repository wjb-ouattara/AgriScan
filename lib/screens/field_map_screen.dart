import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'drone_simulation_screen.dart';

// ══════════════════════════════════════════════════════════
//  FIELD MAP SCREEN
//  Grille interactive 10×8 du champ
// ══════════════════════════════════════════════════════════

class FieldMapScreen extends StatefulWidget {
  const FieldMapScreen({super.key});
  @override
  State<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends State<FieldMapScreen> {
  int? _selectedCell;

  // Carte du champ : H=sain, M=modéré, S=grave, E=non analysé
  static const _pattern = [
    'H','H','H','H','H','M','H','H','H','H',
    'H','H','M','M','H','H','H','H','H','H',
    'H','M','M','S','M','H','H','H','H','H',
    'H','H','M','S','S','M','H','H','H','H',
    'H','H','H','M','S','M','M','H','H','H',
    'H','H','H','H','M','M','H','H','H','H',
    'H','H','H','H','H','M','H','H','H','H',
    'H','H','H','H','H','H','H','H','H','H',
  ];

  Color _cellColor(String t, bool selected) {
    if (selected) return AppColors.g700;
    switch (t) {
      case 'M': return AppColors.amber;
      case 'S': return AppColors.red;
      case 'E': return AppColors.surface2;
      default:  return AppColors.g500;
    }
  }

  String _cellLabel(int i) {
    final t = _pattern[i];
    final row = (i ~/ 10) + 1;
    final col = (i % 10) + 1;
    switch (t) {
      case 'M': return 'Zone R$row·C$col — Modérée';
      case 'S': return 'Zone R$row·C$col — Grave ⚠';
      case 'E': return 'Zone R$row·C$col — Non analysé';
      default:  return 'Zone R$row·C$col — Saine ✓';
    }
  }

  int get _countH => _pattern.where((t) => t == 'H').length;
  int get _countM => _pattern.where((t) => t == 'M').length;
  int get _countS => _pattern.where((t) => t == 'S').length;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: w >= 900 ? _buildDesktop() : _buildMobile(),
    );
  }

  // ════════════════════════════════════════════════════
  //  DESKTOP
  // ════════════════════════════════════════════════════
  Widget _buildDesktop() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          flex: 6,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    _buildStatsRow(),
                    const SizedBox(height: 20),
                    _buildGridCard(),
                  ]))),
      Container(width: 1.5, color: AppColors.border),
      SizedBox(
          width: 340,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Détail par zone', style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: AppColors.g900)),
                    const SizedBox(height: 4),
                    Text('Champ A · Blé · 2.4 ha',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 13, color: AppColors.t3)),
                    const SizedBox(height: 20),
                    _buildLegend(),
                    const SizedBox(height: 20),
                    _buildZonePanel(),
                    const SizedBox(height: 20),
                    if (_selectedCell != null) _buildCellDetail(),
                    const SizedBox(height: 20),
                    _buildDroneButton(context),
                  ]))),
    ]);
  }

  // ════════════════════════════════════════════════════
  //  MOBILE
  // ════════════════════════════════════════════════════
  Widget _buildMobile() {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 20, right: 20),
              child: _buildHeader(context))),
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _buildStatsRow(),
            const SizedBox(height: 14),
            _buildLegend(),
            const SizedBox(height: 14),
            _buildGridCard(),
            const SizedBox(height: 14),
            _buildZonePanel(),
            const SizedBox(height: 14),
            if (_selectedCell != null) ...[
              _buildCellDetail(),
              const SizedBox(height: 14),
            ],
            _buildDroneButton(context),
          ]))),
    ]);
  }

  // ════════════════════════════════════════════════════
  //  WIDGETS
  // ════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    return Row(children: [
      GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: AppColors.surface, shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: AppShadows.sm),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppColors.t1))),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Carte du champ', style: GoogleFonts.nunito(
            fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.g900)),
        Text('Champ A · Blé · 2.4 ha', style: GoogleFonts.nunitoSans(
            fontSize: 13, color: AppColors.t3)),
      ]),
    ]);
  }

  Widget _buildStatsRow() {
    final total = _pattern.length;
    return Row(children: [
      Expanded(child: _StatCard('${(_countH/total*100).round()}%',
          'Saine', AppColors.green)),
      const SizedBox(width: 8),
      Expanded(child: _StatCard('${(_countM/total*100).round()}%',
          'Modérée', AppColors.amber)),
      const SizedBox(width: 8),
      Expanded(child: _StatCard('${(_countS/total*100).round()}%',
          'Grave', AppColors.red)),
    ]);
  }

  Widget _buildLegend() {
    return Wrap(spacing: 12, runSpacing: 8, children: [
      _LegItem(AppColors.g500, 'Zone saine'),
      _LegItem(AppColors.amber, 'Infection modérée'),
      _LegItem(AppColors.red,   'Infection grave'),
      _LegItem(AppColors.surface2, 'Non analysé', border: AppColors.border),
    ]);
  }

  Widget _buildGridCard() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Vue aérienne reconstituée',
                    style: GoogleFonts.nunito(fontSize: 14,
                        fontWeight: FontWeight.w800, color: AppColors.t1)),
                const Spacer(),
                Text('1 case ≈ 100 m²', style: GoogleFonts.nunitoSans(
                    fontSize: 11, color: AppColors.t3)),
              ]),
              const SizedBox(height: 14),
              // Grille
              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 10,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3),
                  itemCount: _pattern.length,
                  itemBuilder: (_, i) {
                    final selected = _selectedCell == i;
                    return GestureDetector(
                        onTap: () => setState(() =>
                        _selectedCell = _selectedCell == i ? null : i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                              color: _cellColor(_pattern[i], selected),
                              borderRadius: BorderRadius.circular(3),
                              border: selected ? Border.all(
                                  color: Colors.white, width: 2) : null),
                        ));
                  }),
            ]));
  }

  Widget _buildZonePanel() {
    final zones = [
      ('Zone saine',        AppColors.g500,  AppColors.green,
      'Aucun traitement requis',           '${(_countH/80*100).round()}%'),
      ('Infection modérée', AppColors.amber, AppColors.amber,
      'Traitement préventif conseillé',    '${(_countM/80*100).round()}%'),
      ('Infection grave',   AppColors.red,   AppColors.red,
      'Traitement immédiat urgent',        '${(_countS/80*100).round()}%'),
    ];
    return Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: zones.asMap().entries.map((e) {
          final i = e.key;
          final z = e.value;
          return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  border: Border(bottom: i < zones.length - 1
                      ? const BorderSide(color: AppColors.surface2, width: 1.5)
                      : BorderSide.none)),
              child: Row(children: [
                Container(width: 14, height: 14,
                    decoration: BoxDecoration(
                        color: z.$2,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(z.$1, style: GoogleFonts.nunito(fontSize: 13,
                      fontWeight: FontWeight.w700, color: AppColors.t1)),
                  Text(z.$4, style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.t3)),
                ])),
                Text(z.$5, style: GoogleFonts.nunito(fontSize: 16,
                    fontWeight: FontWeight.w900, color: z.$3)),
              ]));
        }).toList()));
  }

  Widget _buildCellDetail() {
    final i = _selectedCell!;
    final t = _pattern[i];
    final row = (i ~/ 10) + 1;
    final col = (i % 10) + 1;
    final (label, color, bg) = t == 'S'
        ? ('Infection grave', AppColors.red, AppColors.red2)
        : t == 'M'
        ? ('Infection modérée', AppColors.amber, AppColors.amber2)
        : ('Zone saine', AppColors.green, const Color(0xFFD8F0DC));
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(
                  t == 'S' ? '🔴' : t == 'M' ? '🟡' : '🟢',
                  style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Zone R$row · Colonne $col',
                style: GoogleFonts.nunito(fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.t1)),
            Text(label, style: GoogleFonts.nunitoSans(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ])),
          GestureDetector(
              onTap: () => setState(() => _selectedCell = null),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.t3)),
        ]));
  }

  Widget _buildDroneButton(BuildContext context) {
    return SizedBox(width: double.infinity,
        child: ElevatedButton(
            onPressed: () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, a, __) => const DroneSimulationScreen(),
                transitionsBuilder: (_, a, __, child) =>
                    SlideTransition(
                        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                            .animate(CurvedAnimation(parent: a,
                            curve: Curves.easeOut)),
                        child: child),
                transitionDuration: const Duration(milliseconds: 300))),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g700, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
                shadowColor: AppColors.g700.withOpacity(0.4)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚁', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text('Lancer la simulation de traitement',
                      style: GoogleFonts.nunito(fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ])));
  }
}

// ── Widgets helpers ───────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatCard(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(children: [
        Text(value, style: GoogleFonts.nunito(fontSize: 22,
            fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.t3)),
      ]));
}

class _LegItem extends StatelessWidget {
  final Color color;
  final String label;
  final Color? border;
  const _LegItem(this.color, this.label, {this.border});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: color,
                borderRadius: BorderRadius.circular(3),
                border: border != null
                    ? Border.all(color: border!, width: 1) : null)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 12, color: AppColors.t2)),
      ]);
}
