import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/agriscan_ai_service.dart';

// ══════════════════════════════════════════════════════════
//  RECOMMENDATIONS SCREEN V2 — Powered by Agriscan Ai
//  Les recommandations sont générées dynamiquement par l'IA
// ══════════════════════════════════════════════════════════

class RecommendationsScreen extends StatefulWidget {
  final String diseaseName;
  final String plantName;
  final String severityLevel;
  final double confidence;

  const RecommendationsScreen({
    super.key,
    this.diseaseName  = 'Rouille de la tige',
    this.plantName    = 'Maïs',
    this.severityLevel = 'Modéré',
    this.confidence   = 0.94,
  });

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _ai = AgriScanAIService();

  AIRecommendation? _reco;
  bool   _loading = true;
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final reco = await _ai.analyzeDisease(
        diseaseName  : widget.diseaseName,
        plantName    : widget.plantName,
        severityLevel: widget.severityLevel,
        confidence   : widget.confidence,
        region       : 'Maroc',
      );
      if (mounted) setState(() { _reco = reco; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _reco    = AIRecommendation.offline(
            widget.diseaseName, widget.plantName);
        _loading = false;
        _error   = e.toString();
      });
    }
  }

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
                    if (_loading) _buildLoading()
                    else if (_reco != null) ...[
                      _buildDiseaseCard(),
                      const SizedBox(height: 20),
                      _buildProductsSection(),
                    ],
                  ]))),
      Container(width: 1.5, color: AppColors.border),
      SizedBox(width: 360,
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_loading && _reco != null) ...[
                      Text('Plan d\'application', style: GoogleFonts.nunito(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: AppColors.g900)),
                      const SizedBox(height: 4),
                      Text('Calendrier Gemini IA',
                          style: GoogleFonts.nunitoSans(
                              fontSize: 13, color: AppColors.t3)),
                      const SizedBox(height: 20),
                      _buildSchedule(),
                      const SizedBox(height: 20),
                      _buildPreventionSection(),
                      const SizedBox(height: 20),
                      _buildEconomicImpact(),
                      const SizedBox(height: 20),
                      _buildGeminiBadge(),
                    ],
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
              child: _buildHeader())),
      SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            if (_loading)
              _buildLoading()
            else if (_reco != null) ...[
              _buildDiseaseCard(),
              const SizedBox(height: 14),
              _buildProductsSection(),
              const SizedBox(height: 14),
              _buildSchedule(),
              const SizedBox(height: 14),
              _buildPreventionSection(),
              const SizedBox(height: 14),
              _buildEconomicImpact(),
              const SizedBox(height: 14),
              _buildGeminiBadge(),
            ],
            if (_error.isNotEmpty)
              _buildErrorBanner(),
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
            decoration: BoxDecoration(color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: AppShadows.sm),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: AppColors.t1))),
    const SizedBox(width: 14),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recommandations IA', style: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.g900)),
      Text('${widget.plantName} · ${widget.diseaseName}',
          style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
    ]),
  ]);

  // ════════════════════════════════════════════════════
  //  LOADING
  // ════════════════════════════════════════════════════
  Widget _buildLoading() => Container(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
                color: AppColors.g600, strokeWidth: 3)),
        const SizedBox(height: 20),
        Text('Agrisan AI analyse la maladie…',
            style: GoogleFonts.nunito(fontSize: 16,
                fontWeight: FontWeight.w700, color: AppColors.t1)),
        const SizedBox(height: 8),
        Text('Génération des recommandations personnalisées pour le Maroc',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
      ]));

  // ════════════════════════════════════════════════════
  //  CARTE MALADIE
  // ════════════════════════════════════════════════════
  Widget _buildDiseaseCard() {
    final r = _reco!;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🔬', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.diseaseNameFr, style: GoogleFonts.nunito(fontSize: 18,
                  fontWeight: FontWeight.w900, color: AppColors.g900)),
              Text(r.diseaseNameScientific,
                  style: GoogleFonts.nunitoSans(fontSize: 12,
                      color: AppColors.t3, fontStyle: FontStyle.italic)),
            ])),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: _urgencyColor(r.urgency).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: _urgencyColor(r.urgency).withOpacity(0.4))),
                child: Text(r.urgencyLabel, style: GoogleFonts.nunito(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: _urgencyColor(r.urgency)))),
          ]),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border),
          const SizedBox(height: 10),
          Text(r.description, style: GoogleFonts.nunitoSans(
              fontSize: 14, color: AppColors.t2, height: 1.5)),
          const SizedBox(height: 10),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.amber2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber3)),
              child: Row(children: [
                const Text('⚠️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(r.severityExplanation,
                    style: GoogleFonts.nunitoSans(fontSize: 13,
                        color: AppColors.t1, height: 1.4))),
              ])),
          if (r.weatherConditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Text('🌤️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.weatherConditions,
                  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3))),
            ]),
          ],
        ]));
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'immediate': return AppColors.red;
      case '24h':       return AppColors.red;
      default:          return AppColors.amber;
    }
  }

  // ════════════════════════════════════════════════════
  //  ÉTAPES DE TRAITEMENT
  // ════════════════════════════════════════════════════
  Widget _buildProductsSection() {
    final r = _reco!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Étapes de traitement
      _Label('ÉTAPES DE TRAITEMENT'),
      Container(
          decoration: BoxDecoration(color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: AppShadows.sm),
          child: Column(children: r.treatmentSteps.asMap().entries.map((e) {
            final i = e.key; final s = e.value;
            return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border(bottom:
                i < r.treatmentSteps.length - 1
                    ? const BorderSide(color: AppColors.surface2, width: 1.5)
                    : BorderSide.none)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 30, height: 30,
                          decoration: const BoxDecoration(
                              color: AppColors.g700, shape: BoxShape.circle),
                          child: Center(child: Text('${s.step}',
                              style: GoogleFonts.nunito(fontSize: 13,
                                  fontWeight: FontWeight.w800, color: Colors.white)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                                fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1)),
                        const SizedBox(height: 2),
                        Text(s.timing,
                            style: GoogleFonts.nunito(
                                fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.t3)),
                        const SizedBox(height: 3),
                        Text(s.description,
                            style: GoogleFonts.nunitoSans(
                                fontSize: 13, color: AppColors.t2, height: 1.4)),
                      ])),
                    ]));
          }).toList())),
      const SizedBox(height: 20),
      // Produits recommandés
      if (r.products.isNotEmpty) ...[
        _Label('PRODUITS RECOMMANDÉS'),
        ...r.products.map((p) => _ProductCard(product: p)),
      ],
    ]);
  }

  // ════════════════════════════════════════════════════
  //  CALENDRIER
  // ════════════════════════════════════════════════════
  Widget _buildSchedule() {
    final r = _reco!;
    if (r.applicationSchedule.isEmpty) return const SizedBox.shrink();
    return Container(
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: r.applicationSchedule.asMap().entries.map((e) {
          final i = e.key; final s = e.value;
          final isLast = i == r.applicationSchedule.length - 1;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const SizedBox(height: 14),
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: i == 0 ? AppColors.g700 : AppColors.surface2,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: i == 0 ? AppColors.g700 : AppColors.border, width: 1.5)),
                  child: Center(child: Text(s.day, style: GoogleFonts.nunito(
                      fontSize: i == 0 ? 9 : 10, fontWeight: FontWeight.w800,
                      color: i == 0 ? Colors.white : AppColors.t2)))),
              if (!isLast) Container(width: 2, height: 36, color: AppColors.surface2),
            ]),
            const SizedBox(width: 14),
            Expanded(child: Padding(
                padding: EdgeInsets.only(
                    top: 14, bottom: isLast ? 14 : 0, right: 14),
                child: Text(s.action, style: GoogleFonts.nunitoSans(
                    fontSize: 13, color: AppColors.t2, height: 1.4)))),
          ]);
        }).toList()));
  }

  // ════════════════════════════════════════════════════
  //  PRÉVENTION
  // ════════════════════════════════════════════════════
  Widget _buildPreventionSection() {
    final tips = _reco!.preventionTips;
    if (tips.isEmpty) return const SizedBox.shrink();
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.g50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.g300, width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💡 Prévention', style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.g900)),
          const SizedBox(height: 12),
          ...tips.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('✓ ', style: TextStyle(
                    color: AppColors.green, fontWeight: FontWeight.bold)),
                Expanded(child: Text(t, style: GoogleFonts.nunitoSans(
                    fontSize: 13, color: AppColors.t2, height: 1.4))),
              ]))),
        ]));
  }

  // ════════════════════════════════════════════════════
  //  IMPACT ÉCONOMIQUE
  // ════════════════════════════════════════════════════
  Widget _buildEconomicImpact() {
    final eco = _reco!.economicImpact;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Impact économique', style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1)),
          const SizedBox(height: 12),
          _EcoRow('📉', 'Perte sans traitement', eco.yieldLossWithoutTreatment),
          _EcoRow('💊', 'Coût du traitement',    eco.treatmentCost),
          _EcoRow('💰', 'Retour sur investissement', eco.roi),
        ]));
  }

  // ════════════════════════════════════════════════════
  //  BADGE GEMINI
  // ════════════════════════════════════════════════════
  Widget _buildGeminiBadge() => Center(
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Analyse propulsée par AgriScan IA 🌿',
                style: GoogleFonts.nunitoSans(
                    fontSize: 12, color: AppColors.t3)),
          ])));

  Widget _buildErrorBanner() => Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.amber2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.amber3)),
      child: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Analyse hors ligne', style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amber)),
              Text('Recommandations de base affichées. '
                  'Connectez-vous pour les recommandations Gemini.',
                  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t2)),
              const SizedBox(height: 6),
              GestureDetector(
                  onTap: _loadRecommendations,
                  child: Text('↻ Réessayer', style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.g700))),
            ])),
      ]));
}

// ── Widgets helpers ───────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ProductRecommendation product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💊', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, style: GoogleFonts.nunito(fontSize: 15,
                fontWeight: FontWeight.w900, color: AppColors.g900)),
            Text(product.activeIngredient,
                style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3)),
          ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.g50,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.g300)),
              child: Text(product.type, style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.g700))),
        ]),
        const SizedBox(height: 12),
        const Divider(color: AppColors.border),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 6, children: [
          _InfoChip('⚗️ ${product.dosePerHa}',    'Dose/ha'),
          _InfoChip('💧 ${product.waterVolume}',   'Volume eau'),
          _InfoChip('🔄 ${product.frequency}',     'Fréquence'),
          _InfoChip('⏰ ${product.preHarvestDelay}','Délai récolte'),
          _InfoChip('💰 ${product.estimatedCostDh}','Coût estimé'),
        ]),
        if (product.availabilityMorocco) ...[
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('Disponible au Maroc', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
          ]),
        ],
      ]));
}

class _InfoChip extends StatelessWidget {
  final String value, label;
  const _InfoChip(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: GoogleFonts.nunito(fontSize: 12,
            fontWeight: FontWeight.w700, color: AppColors.t1)),
        Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 10, color: AppColors.t3)),
      ]));
}

class _EcoRow extends StatelessWidget {
  final String emoji, label, value;
  const _EcoRow(this.emoji, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 13, color: AppColors.t2))),
        Flexible(child: Text(value, style: GoogleFonts.nunito(fontSize: 13,
            fontWeight: FontWeight.w700, color: AppColors.t1),
            textAlign: TextAlign.right)),
      ]));
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.t3, letterSpacing: 1.5)));
}