import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'recommendations_screen.dart';

// ══════════════════════════════════════════════════════════
//  DRONE SIMULATION SCREEN
//  Drone animé sur la grille · Start/Pause/Reset · Stats
// ══════════════════════════════════════════════════════════

class DroneSimulationScreen extends StatefulWidget {
  const DroneSimulationScreen({super.key});
  @override
  State<DroneSimulationScreen> createState() => _DroneSimulationScreenState();
}

class _DroneSimulationScreenState extends State<DroneSimulationScreen>
    with TickerProviderStateMixin {

  // ── État simulation ───────────────────────────────────
  bool _isRunning   = false;
  bool _isDone      = false;
  int  _dronePos    = 0;
  int  _zonesTraited = 0;
  int  _elapsedSec  = 0;
  Timer? _timer;

  // ── Animation drone ───────────────────────────────────
  late AnimationController _droneHover;
  late AnimationController _pulseCtrl;

  // ── Grille (même pattern que field map) ──────────────
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

  // Zones infectées (M ou S) à traiter
  late final List<int> _infectedCells;
  final Set<int> _treatedCells = {};

  @override
  void initState() {
    super.initState();
    _infectedCells = [];
    for (int i = 0; i < _pattern.length; i++) {
      if (_pattern[i] == 'M' || _pattern[i] == 'S') {
        _infectedCells.add(i);
      }
    }

    _droneHover = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _droneHover.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Contrôles ─────────────────────────────────────────
  void _start() {
    if (_isDone) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSec++;
        if (_zonesTraited < _infectedCells.length) {
          _treatedCells.add(_infectedCells[_zonesTraited]);
          _dronePos = _infectedCells[_zonesTraited];
          _zonesTraited++;
        } else {
          _isDone = true;
          _isRunning = false;
          _timer?.cancel();
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning    = false;
      _isDone       = false;
      _dronePos     = 0;
      _zonesTraited = 0;
      _elapsedSec   = 0;
      _treatedCells.clear();
    });
  }

  // ── Helpers ───────────────────────────────────────────
  double get _progress =>
      _infectedCells.isEmpty ? 0 : _zonesTraited / _infectedCells.length;

  String get _elapsedLabel {
    final m = (_elapsedSec ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Litres économisés (simulation)
  double get _litresSaved => _zonesTraited * 0.8;
  // Surface traitée en m²
  int get _surfaceM2 => _zonesTraited * 100;

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
      Expanded(flex: 6,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildDroneArena(arenaWidth: double.infinity),
                  ]))),
      Container(width: 1.5, color: AppColors.border),
      SizedBox(width: 340,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tableau de bord', style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: AppColors.g900)),
                    const SizedBox(height: 4),
                    Text('Simulation de traitement par drone',
                        style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
                    const SizedBox(height: 20),
                    _buildControls(),
                    const SizedBox(height: 20),
                    _buildProgressCard(),
                    const SizedBox(height: 20),
                    _buildStatsCards(),
                    const SizedBox(height: 20),
                    if (_isDone) _buildDoneCard(),
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
                  left: 20, right: 20, bottom: 14),
              child: _buildHeader())),
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _buildDroneArena(arenaWidth: double.infinity),
            const SizedBox(height: 14),
            _buildControls(),
            const SizedBox(height: 14),
            _buildProgressCard(),
            const SizedBox(height: 14),
            _buildStatsCards(),
            if (_isDone) ...[const SizedBox(height: 14), _buildDoneCard()],
          ]))),
    ]);
  }

  // ════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════
  Widget _buildHeader() => Row(children: [
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
      Text('Simulation drone', style: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.g900)),
      Text('Traitement ciblé des zones infectées',
          style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
    ]),
  ]);

  // ════════════════════════════════════════════════════
  //  ARÈNE DRONE
  // ════════════════════════════════════════════════════
  Widget _buildDroneArena({required double arenaWidth}) {
    return Container(
        width: arenaWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Vue aérienne du champ', style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1)),
                const Spacer(),
                if (_isRunning)
                  Row(children: [
                    AnimatedBuilder(animation: _pulseCtrl, builder: (_, __) =>
                        Opacity(opacity: 0.3 + 0.7 * _pulseCtrl.value,
                            child: Container(width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.green, shape: BoxShape.circle)))),
                    const SizedBox(width: 6),
                    Text('En vol', style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppColors.green)),
                  ]),
              ]),
              const SizedBox(height: 14),
              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 10,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3),
                  itemCount: _pattern.length,
                  itemBuilder: (_, i) {
                    final isDrone   = i == _dronePos && _isRunning;
                    final isTreated = _treatedCells.contains(i);
                    final isInfected = _pattern[i] == 'M' || _pattern[i] == 'S';

                    Color bg;
                    if (isDrone) bg = AppColors.g700;
                    else if (isTreated) bg = AppColors.g500.withOpacity(0.7);
                    else if (isInfected) bg = _pattern[i] == 'S'
                        ? AppColors.red : AppColors.amber;
                    else bg = AppColors.g500;

                    return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(3),
                            border: isDrone ? Border.all(
                                color: Colors.white, width: 2) : null),
                        child: isDrone ? Center(
                            child: AnimatedBuilder(animation: _droneHover,
                                builder: (_, __) => Transform.translate(
                                    offset: Offset(0, -2 + 4 * _droneHover.value),
                                    child: const Text('🚁',
                                        style: TextStyle(fontSize: 10))))) : null);
                  }),
              const SizedBox(height: 10),
              // Légende
              Wrap(spacing: 12, runSpacing: 6, children: [
                _LegDot(AppColors.g500, 'Saine'),
                _LegDot(AppColors.amber, 'À traiter'),
                _LegDot(AppColors.red, 'Grave'),
                _LegDot(AppColors.g500.withOpacity(0.7), 'Traitée ✓'),
                _LegDot(AppColors.g700, '🚁 Drone'),
              ]),
            ]));
  }

  // ════════════════════════════════════════════════════
  //  CONTRÔLES
  // ════════════════════════════════════════════════════
  Widget _buildControls() {
    return Row(children: [
      Expanded(child: ElevatedButton(
          onPressed: _isRunning ? _pause : (_isDone ? null : _start),
          style: ElevatedButton.styleFrom(
              backgroundColor: _isRunning ? AppColors.amber : AppColors.g700,
              foregroundColor: Colors.white, elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20),
                const SizedBox(width: 8),
                Text(_isRunning ? 'Pause' : _isDone ? 'Terminé' : 'Démarrer',
                    style: GoogleFonts.nunito(fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ]))),
      const SizedBox(width: 10),
      OutlinedButton(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.t2,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              side: const BorderSide(color: AppColors.border, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Row(children: [
            const Icon(Icons.refresh_rounded, size: 18),
            const SizedBox(width: 6),
            Text('Reset', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700)),
          ])),
    ]);
  }

  // ════════════════════════════════════════════════════
  //  PROGRESSION
  // ════════════════════════════════════════════════════
  Widget _buildProgressCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Progression du traitement',
                  style: GoogleFonts.nunito(fontSize: 13,
                      fontWeight: FontWeight.w800, color: AppColors.t1)),
              const Spacer(),
              Text('$_zonesTraited/${_infectedCells.length} zones',
                  style: GoogleFonts.nunito(fontSize: 13,
                      fontWeight: FontWeight.w800, color: AppColors.g700)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                    value: _progress, minHeight: 10,
                    backgroundColor: AppColors.surface2,
                    valueColor: AlwaysStoppedAnimation(
                        _isDone ? AppColors.green : AppColors.g600))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('⏱ $_elapsedLabel',
                      style: GoogleFonts.nunito(fontSize: 12,
                          fontWeight: FontWeight.w600, color: AppColors.t3)),
                  Text('${(_progress * 100).round()}%',
                      style: GoogleFonts.nunito(fontSize: 14,
                          fontWeight: FontWeight.w900, color: AppColors.g700)),
                ]),
          ]));

  // ════════════════════════════════════════════════════
  //  STATS
  // ════════════════════════════════════════════════════
  Widget _buildStatsCards() => GridView.count(
      crossAxisCount: 2, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _StatTile('💧', '${_litresSaved.toStringAsFixed(1)} L',
            'Produit pulvérisé', AppColors.g700),
        _StatTile('📐', '${_surfaceM2} m²',
            'Surface traitée', AppColors.g600),
        _StatTile('⚡', '${(_zonesTraited * 0.15).toStringAsFixed(1)} kWh',
            'Énergie consommée', AppColors.amber),
        _StatTile('💰', '${(_zonesTraited * 2.4).toStringAsFixed(0)} DH',
            'Coût estimé', AppColors.green),
      ]);

  // ════════════════════════════════════════════════════
  //  CARTE TERMINÉ
  // ════════════════════════════════════════════════════
  Widget _buildDoneCard() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFD8F0DC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.g300, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('✅', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Traitement terminé !',
                        style: GoogleFonts.nunito(fontSize: 15,
                            fontWeight: FontWeight.w900, color: AppColors.green)),
                    Text('${_infectedCells.length} zones traitées en $_elapsedLabel',
                        style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t2)),
                  ])),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.push(context, PageRouteBuilder(
                        pageBuilder: (_, a, __) => const RecommendationsScreen(),
                        transitionsBuilder: (_, a, __, child) =>
                            SlideTransition(
                                position: Tween(
                                    begin: const Offset(1, 0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: a,
                                    curve: Curves.easeOut)),
                                child: child),
                        transitionDuration: const Duration(milliseconds: 300))),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.g700, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💊', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text('Voir les recommandations',
                              style: GoogleFonts.nunito(fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                        ]))),
          ]));
}

// ── Widgets helpers ───────────────────────────────────────

class _LegDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 11, color: AppColors.t2)),
      ]);
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _StatTile(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontSize: 14,
                fontWeight: FontWeight.w900, color: color)),
            Text(label, style: GoogleFonts.nunitoSans(
                fontSize: 10, color: AppColors.t3)),
          ]));
}
