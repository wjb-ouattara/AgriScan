import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/ml_service.dart';
import 'field_map_screen.dart';
import 'drone_simulation_screen.dart';
import 'recommendations_screen.dart';
import 'marketplace_screen.dart';

// ══════════════════════════════════════════════════════════
//  DISEASE RESULT SCREEN — Résultats ML réels
// ══════════════════════════════════════════════════════════

class DiseaseResultScreen extends StatelessWidget {
  final DiseaseDetectionResult? result;
  final File?                   imageFile;
  final String?                 scanId;

  const DiseaseResultScreen({
    super.key,
    this.result,
    this.imageFile,
    this.scanId,
  });

  // Données à afficher (réelles ou démo)
  String get _diseaseName {
    if (result == null) return 'Rouille de la tige';
    return _localizeDisease(result!.diseaseName);
  }

  String get _plantName {
    if (result == null) return 'Maïs';
    return result!.plantType == PlantType.maize ? 'Maïs' : 'Tomate';
  }

  String get _severity {
    if (result == null) return 'Modéré';
    return result!.severityLabel;
  }

  double get _confidence => result?.confidence ?? 0.94;

  String get _modelName {
    if (result == null) return 'MobileViT';
    return result!.modelUsed.displayName;
  }

  int get _inferenceMs => result?.inferenceMs ?? 0;

  bool get _isHealthy => result?.isHealthy ?? false;

  String _localizeDisease(String name) {
    const map = {
      // ── Classes Maïs (modèle de votre ami) ──────────
      'f_GLS'   : 'Tache Grise (Gray Leaf Spot)',
      'f_NLB'   : 'Brûlure Nordique (NLB)',
      'Healthy' : 'Plante saine',
      'v_MLN'   : 'Nécrose Létale (MLN)',
      'v_MSV'   : 'Striure du Maïs (MSV)',
      // ── Classes Tomate ───────────────────────────────
      'Alternariose'     : 'Alternariose',
      'Mildiou'          : 'Mildiou',
      'Oidium'           : 'Oïdium',
      'Saine'            : 'Plante saine',
      'Septoriose'       : 'Septoriose',
      'Tache_Bact'       : 'Tache bactérienne',
      'Tache_Cible'      : 'Tache cible',
      'Acariens'         : 'Acariens',
      'Moisissure'       : 'Moisissure grise',
      'Mosaique'         : 'Mosaïque virale',
      'Enroulement_Jaune': 'Enroulement jaune',
    };
    return map[name] ?? name;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: w >= 900
          ? _DesktopResult(screen: this)
          : _MobileResult(screen: this),
    );
  }
}

class _DesktopResult extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _DesktopResult({required this.screen});

  @override
  Widget build(BuildContext context) {
    final rightPanel = <Widget>[
      Text('Explorer les résultats', style: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.g900)),
      const SizedBox(height: 4),
      Text('Analyse complète', style: GoogleFonts.nunitoSans(
          fontSize: 13, color: AppColors.t3)),
      const SizedBox(height: 20),
      _NavCards(screen: screen, isDesktop: true),
      const SizedBox(height: 24),
      const _SectionLabel('Répartition des zones'),
      const _ZoneChart(),
    ];
    if (screen.result != null) {
      rightPanel.insertAll(6, [
        const _SectionLabel('Confiance par classe'),
        _ConfidenceList(screen: screen),
        const SizedBox(height: 24),
      ]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 6,
          child: SingleChildScrollView(child: Column(children: [
            _HeroSection(screen: screen),
            Padding(padding: const EdgeInsets.all(24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DiseaseName(screen: screen),
                      const SizedBox(height: 16),
                      _SeverityCard(screen: screen),
                      const SizedBox(height: 16),
                      _MetricsGrid(screen: screen),
                      const SizedBox(height: 20),
                      const _SectionLabel('Actions immédiates'),
                      _TreatmentSteps(screen: screen),
                    ])),
          ]))),
      Container(width: 1.5, color: AppColors.border),
      SizedBox(width: 360,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rightPanel))),
    ]);
  }
}

class _MobileResult extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _MobileResult({required this.screen});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _HeroSection(screen: screen)),
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _DiseaseName(screen: screen),
            const SizedBox(height: 14),
            _SeverityCard(screen: screen),
            const SizedBox(height: 14),
            _MetricsGrid(screen: screen),
            const SizedBox(height: 16),
            const _SectionLabel('Explorer les résultats'),
            _NavCards(screen: screen, isDesktop: false),
            const SizedBox(height: 16),
            const _SectionLabel('Actions immédiates'),
            _TreatmentSteps(screen: screen),
            const SizedBox(height: 16),
            if (screen.result != null) ...[
              const _SectionLabel('Confiance par classe'),
              _ConfidenceList(screen: screen),
              const SizedBox(height: 16),
            ],
            const _SectionLabel('Répartition des zones'),
            const _ZoneChart(),
          ]))),
    ]);
  }
}

// ── Hero section ──────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _HeroSection({required this.screen});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return SizedBox(height: isDesktop ? 260 : 220,
        child: Stack(children: [
          // Fond : vraie image ou gradient
          Positioned.fill(child: screen.imageFile != null
              ? Image.file(screen.imageFile!, fit: BoxFit.cover)
              : Container(decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3820), Color(0xFF152815)])))),
          // Overlay teinté
          Positioned.fill(child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.5)])))),
          // Taches de chaleur
          if (screen.imageFile == null) ...[
            Positioned.fill(child: Container(decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(0.3, 0.2), radius: 0.5,
                    colors: [Colors.orange.withOpacity(0.22), Colors.transparent])))),
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            Positioned(top: 70, left: 100, width: 160, height: 110,
                child: Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.orange.withOpacity(0.85), width: 2),
                        borderRadius: BorderRadius.circular(6)),
                    child: Align(alignment: Alignment.topLeft,
                        child: Transform.translate(offset: const Offset(0, -22),
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('⚠ Zone infectée', style: GoogleFonts.nunito(
                                    fontSize: 10, fontWeight: FontWeight.w700,
                                    color: Colors.white))))))),
          ],
          // Top bar
          Positioned(top: 0, left: 0, right: 0,
              child: Container(
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 12,
                      left: 20, right: 20, bottom: 12),
                  child: Row(children: [
                    GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(width: 40, height: 40,
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.3))),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 16))),
                    const Spacer(),
                    // Temps d'inférence
                    if (screen._inferenceMs > 0)
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.2))),
                          child: Text('⚡ ${screen._inferenceMs}ms',
                              style: GoogleFonts.nunito(fontSize: 11,
                                  fontWeight: FontWeight.w700, color: Colors.white))),
                    const SizedBox(width: 8),
                    Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3))),
                        child: const Icon(Icons.ios_share_rounded,
                            color: Colors.white, size: 18)),
                  ]))),
          // Chips bas
          Positioned(bottom: 16, left: 20,
              child: Row(children: [
                _HeroChip(
                    screen._isHealthy ? '✅ Plante saine' : '⚠️ Maladie détectée',
                    screen._isHealthy
                        ? Colors.green.withOpacity(0.8)
                        : Colors.orange.withOpacity(0.85)),
                const SizedBox(width: 8),
                _HeroChip('${(screen._confidence * 100).round()}% confiance',
                    Colors.white.withOpacity(0.2)),
              ])),
          // Dégradé bas
          Positioned(bottom: 0, left: 0, right: 0, height: 70,
              child: Container(decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [AppColors.bg, AppColors.bg.withOpacity(0)])))),
        ]));
  }
}

class _HeroChip extends StatelessWidget {
  final String label; final Color bg;
  const _HeroChip(this.label, this.bg);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: Text(label, style: GoogleFonts.nunito(fontSize: 12,
          fontWeight: FontWeight.w700, color: Colors.white)));
}

// ── Nom maladie ───────────────────────────────────────────
class _DiseaseName extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _DiseaseName({required this.screen});
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(screen._diseaseName, style: GoogleFonts.nunito(
        fontSize: 26, fontWeight: FontWeight.w900,
        color: AppColors.g900, height: 1.15)),
    const SizedBox(height: 4),
    Row(children: [
      Text('${screen._plantName} · ', style: GoogleFonts.nunitoSans(
          fontSize: 13, color: AppColors.t3)),
      Text('Modèle : ${screen._modelName}',
          style: GoogleFonts.nunitoSans(
              fontSize: 13, color: AppColors.t3,
              fontStyle: FontStyle.italic)),
    ]),
  ]);
}

// ── Sévérité ──────────────────────────────────────────────
class _SeverityCard extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _SeverityCard({required this.screen});
  @override
  Widget build(BuildContext context) {
    final sev = screen._severity;
    Color activeColor;
    int activeIndex;
    switch (sev) {
      case 'Grave':  activeColor = AppColors.red;   activeIndex = 2; break;
      case 'Modéré': activeColor = AppColors.amber; activeIndex = 1; break;
      case 'Saine':  activeColor = AppColors.green; activeIndex = 0; break;
      default:       activeColor = AppColors.green; activeIndex = 0;
    }

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Niveau de gravité', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1)),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: activeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: activeColor.withOpacity(0.4))),
                child: Text(sev, style: GoogleFonts.nunito(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: activeColor))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Container(height: 8, decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4), bottomLeft: Radius.circular(4))))),
            const SizedBox(width: 3),
            Expanded(child: Container(height: 8, color: AppColors.amber)),
            const SizedBox(width: 3),
            Expanded(child: Container(height: 8, decoration: BoxDecoration(
                color: activeIndex == 2 ? AppColors.red : AppColors.surface2,
                border: activeIndex != 2
                    ? Border.all(color: AppColors.border) : null,
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4), bottomRight: Radius.circular(4))))),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('🟢 Faible', style: GoogleFonts.nunito(fontSize: 11,
                fontWeight: FontWeight.w600, color: AppColors.green)),
            Text('🟡 Modéré', style: GoogleFonts.nunito(fontSize: 11,
                fontWeight: FontWeight.w700, color: AppColors.amber)),
            Text('🔴 Grave', style: GoogleFonts.nunito(
                fontSize: 11, color: AppColors.red)),
          ]),
        ]));
  }
}

// ── Métriques ─────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _MetricsGrid({required this.screen});

  @override
  Widget build(BuildContext context) {
    final type = screen.result?.plantType == PlantType.maize
        ? '🌽 Maïs' : '🍅 Tomate';
    final urgency = screen._isHealthy ? 'Aucune' :
    screen._severity == 'Grave' ? '⏰ 24h' : '⏰ 48h';
    final conf = '${(screen._confidence * 100).round()}%';
    final ms = screen._inferenceMs > 0
        ? '${screen._inferenceMs}ms' : 'N/A';

    return Column(children: [
      Row(children: [
        Expanded(child: _MetricCard('Culture',   type,    'Plante analysée',   const Color(0xFF2D6530))),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard('Urgence',   urgency, 'Intervention',      const Color(0xFFC0321A))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _MetricCard('Certitude', conf,    'Fiabilité IA',      const Color(0xFF1D6B2A))),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard('Inférence', ms,      'Temps d\'analyse',  const Color(0xFF2D6530))),
      ]),
    ]);
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, sub;
  final Color color;
  const _MetricCard(this.label, this.value, this.sub, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: GoogleFonts.nunito(fontSize: 10,
                fontWeight: FontWeight.w700, color: AppColors.t3, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.nunito(fontSize: 15,
                fontWeight: FontWeight.w900, color: color)),
            Text(sub, style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.t3)),
          ]));
}

// ── Nav cards ─────────────────────────────────────────────
class _NavCards extends StatelessWidget {
  final DiseaseResultScreen screen;
  final bool isDesktop;
  const _NavCards({required this.screen, required this.isDesktop});

  static const _cards = [
    ('🗺️', 'Carte du champ',  'Zones infectées',          AppColors.g50,          AppColors.g300),
    ('🚁', 'Simulation drone', 'Traitement ciblé',         Color(0xFFF0F9F1),      Color(0xFFA8D5AC)),
    ('💊', 'Recommandations',  'Produit + dosage',         Color(0xFFFAEEDA),      Color(0xFFFAC775)),
    ('🛒', 'Boutique',         'Acheter les traitements',  Color(0xFFFEF0D6),      Color(0xFFE8920A)),
    ('📊', 'Historique',       'Sauvegarder',              AppColors.surface2,     AppColors.border),
  ];

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Column(children: _cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _NavTile(c: c, isDesktop: true,
              onTap: () => _navigate(context, c.$1, screen)))).toList());
    }
    return Column(children: [
      Row(children: [
        Expanded(child: _NavTile(c: _cards[0], isDesktop: false,
            onTap: () => _navigate(context, _cards[0].$1, screen))),
        const SizedBox(width: 10),
        Expanded(child: _NavTile(c: _cards[1], isDesktop: false,
            onTap: () => _navigate(context, _cards[1].$1, screen))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _NavTile(c: _cards[2], isDesktop: false,
            onTap: () => _navigate(context, _cards[2].$1, screen))),
        const SizedBox(width: 10),
        Expanded(child: _NavTile(c: _cards[3], isDesktop: false,
            onTap: () => _navigate(context, _cards[3].$1, screen))),
      ]),
      const SizedBox(height: 10),
      _NavTile(c: _cards[4], isDesktop: false,
          onTap: () => _navigate(context, _cards[4].$1, screen)),
    ]);
  }

  static void _navigate(BuildContext context, String emoji,
      DiseaseResultScreen screen) {
    Widget? target;
    switch (emoji) {
      case '🗺️': target = const FieldMapScreen(); break;
      case '🚁': target = const DroneSimulationScreen(); break;
      case '💊': target = RecommendationsScreen(
          diseaseName  : screen._diseaseName,
          plantName    : screen._plantName,
          severityLevel: screen._severity,
          confidence   : screen._confidence); break;
      case '🛒': target = MarketplaceScreen(
          diseaseCode  : screen.result?.diseaseName,
          diseaseName  : screen._diseaseName); break;
      default: return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => target!));
  }
}

class _NavTile extends StatelessWidget {
  final (String, String, String, Color, Color) c;
  final bool isDesktop;
  final VoidCallback onTap;
  const _NavTile({required this.c, required this.isDesktop, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.$4,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.$5, width: 1.5),
              boxShadow: AppShadows.sm),
          child: isDesktop
              ? Row(children: [
            Text(c.$1, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(c.$2, style: GoogleFonts.nunito(fontSize: 14,
                  fontWeight: FontWeight.w800, color: AppColors.t1)),
              Text(c.$3, style: GoogleFonts.nunitoSans(
                  fontSize: 12, color: AppColors.t3)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.t4),
          ])
              : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
            Text(c.$1, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(c.$2, style: GoogleFonts.nunito(fontSize: 13,
                fontWeight: FontWeight.w800, color: AppColors.t1)),
            Text(c.$3, style: GoogleFonts.nunitoSans(
                fontSize: 11, color: AppColors.t3)),
          ])));
}

// ── Treatment steps ───────────────────────────────────────
class _TreatmentSteps extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _TreatmentSteps({required this.screen});

  List<(String, String, String)> get _steps {
    if (screen._isHealthy) return [
      ('1', 'Plante en bonne santé',
      'Aucun traitement nécessaire. Continuez la surveillance.'),
      ('2', 'Prévention recommandée',
      'Maintenez une bonne aération et évitez l\'humidité excessive.'),
    ];
    return [
      ('1', 'Isolez les plants malades',
      'Retirez et brûlez les feuilles infectées immédiatement.'),
      ('2', 'Appliquez un fongicide',
      'Voir les recommandations IA pour le produit adapté.'),
      ('3', 'Surveillez l\'évolution',
      'Réévaluez dans 48h et photographiez les zones traitées.'),
    ];
  }

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(children: _steps.asMap().entries.map((e) {
        final i = e.key; final s = e.value;
        return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(border: Border(bottom:
            i < _steps.length - 1
                ? const BorderSide(color: AppColors.surface2, width: 1.5)
                : BorderSide.none)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 30, height: 30,
                  decoration: const BoxDecoration(
                      color: AppColors.g700, shape: BoxShape.circle),
                  child: Center(child: Text(s.$1, style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$2, style: GoogleFonts.nunito(fontSize: 14,
                    fontWeight: FontWeight.w800, color: AppColors.t1)),
                const SizedBox(height: 3),
                Text(s.$3, style: GoogleFonts.nunitoSans(fontSize: 13,
                    color: AppColors.t2, height: 1.4)),
              ])),
            ]));
      }).toList()));
}

// ── Confidence list ───────────────────────────────────────
class _ConfidenceList extends StatelessWidget {
  final DiseaseResultScreen screen;
  const _ConfidenceList({required this.screen});

  @override
  Widget build(BuildContext context) {
    final scores = screen.result?.allScores ?? [];
    if (scores.isEmpty) return const SizedBox.shrink();
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: scores.take(4).toList().asMap().entries.map((e) {
          final i = e.key; final c = e.value;
          final color = i == 0 ? AppColors.amber : const Color(0xFF9E9E9E);
          return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (i == 0) ...[
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: Text(c.label, style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: i == 0 ? AppColors.t1 : AppColors.t3))),
                      Text('${(c.score * 100).round()}%',
                          style: GoogleFonts.nunito(fontSize: 13,
                              fontWeight: FontWeight.w800, color: color)),
                    ]),
                    const SizedBox(height: 4),
                    ClipRRect(borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                            value: c.score, minHeight: 6,
                            backgroundColor: AppColors.surface2,
                            valueColor: AlwaysStoppedAnimation(color))),
                  ]));
        }).toList()));
  }
}

// ── Zone chart ────────────────────────────────────────────
class _ZoneChart extends StatelessWidget {
  const _ZoneChart();
  static const _zones = [
    ('Zone saine',        '58%', Color(0xFF4A9050), 0.58),
    ('Infection modérée', '28%', Color(0xFFE8920A), 0.28),
    ('Infection grave',   '14%', Color(0xFFC0321A), 0.14),
  ];
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Row(children: _zones.map((z) =>
                Expanded(flex: (z.$4 * 100).round(),
                    child: Container(height: 16, color: z.$3))).toList())),
        const SizedBox(height: 14),
        ..._zones.map((z) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: z.$3,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(child: Text(z.$1, style: GoogleFonts.nunitoSans(
                  fontSize: 13, color: AppColors.t2))),
              Text(z.$2, style: GoogleFonts.nunito(fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: z.$3 == const Color(0xFF4A9050) ? AppColors.green : z.$3)),
            ]))),
      ]));
}

// ── Helpers ───────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.t3, letterSpacing: 1.5)));
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}