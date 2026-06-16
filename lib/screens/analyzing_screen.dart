import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/ml_service.dart';
import '../services/database_service.dart';
import '../services/dataset_service.dart';
import 'disease_result_screen.dart';

// ══════════════════════════════════════════════════════════
//  ANALYZING SCREEN — Pipeline ML réel
//  YOLO → crop → MobileViT/ConvNeXt → résultat
// ══════════════════════════════════════════════════════════

class AnalyzingScreen extends StatefulWidget {
  final File?       imageFile;
  final PlantType plantType;
  final String?     scanId;
  final bool        isVideo;

  const AnalyzingScreen({
    super.key,
    this.imageFile,
    this.plantType = PlantType.maize,
    this.scanId,
    this.isVideo = false,
  });

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with TickerProviderStateMixin {

  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;
  late AnimationController _progressCtrl;
  late Animation<double>   _progressAnim;

  double  _progress   = 0.0;
  int     _stepIndex  = 0;
  String  _currentMsg = 'Initialisation de l\'analyse…';
  String  _errorMsg   = '';
  bool    _hasError   = false;

  DiseaseDetectionResult? _result;

  static const _steps = [
    _Step('📸', 'Préparation de l\'image',    'Optimisation qualité…'),
    _Step('🔍', 'Détection de la plante',     'YOLOv8 en cours…'),
    _Step('🧠', 'Classification de maladie',  'MobileViT analyse…'),
    _Step('📊', 'Calcul du diagnostic',       'Finalisation…'),
  ];

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..repeat();
    _ring2 = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat();
    _ring3 = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600))..repeat();
    _progressCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 4000));
    _progressAnim = Tween<double>(begin: 0, end: 0.9)
        .animate(CurvedAnimation(
        parent: _progressCtrl, curve: Curves.easeOut));
    _progressAnim.addListener(() {
      setState(() => _progress = _progressAnim.value);
    });
    _progressCtrl.forward();
    _runAnalysis();
  }

  @override
  void dispose() {
    _ring1.dispose(); _ring2.dispose();
    _ring3.dispose(); _progressCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════
  //  PIPELINE ML RÉEL
  // ════════════════════════════════════════════════════
  Future<void> _runAnalysis() async {
    try {
      // Étape 1 — Initialisation
      _setStep(0, 'Chargement des modèles IA…');
      await Future.delayed(const Duration(milliseconds: 500));
      await AgriScanMLService().initialize();

      // Étape 2 — YOLO
      _setStep(1, 'Détection de la plante…');
      await Future.delayed(const Duration(milliseconds: 300));

      // Étape 3 — Classification
      _setStep(2, 'Analyse des symptômes…');

      DiseaseDetectionResult result;

      if (widget.imageFile != null) {
        // Vrai pipeline ML avec l'image
        result = await AgriScanMLService().predict(
          imageFile     : widget.imageFile!,
          forcePlantType: widget.plantType,
        );
      } else {
        // Mode démo — pas d'image réelle
        await Future.delayed(const Duration(milliseconds: 1500));
        result = _demoResult();
      }

      // Étape 4 — Finalisation
      _setStep(3, 'Préparation du rapport…');
      await Future.delayed(const Duration(milliseconds: 400));

      // Mettre à jour le scan en BD avec le vrai résultat
      if (widget.scanId != null) {
        await _updateScanResult(result);
      }

      // Mettre en cache pour le dataset ML
      if (widget.imageFile != null) {
        DatasetService().cacheImageForDataset(
          originalImage: widget.imageFile!,
          plantType: result.plantType.name,
          diseaseName: result.diseaseName,
        );
      }

      // Progression → 100%
      setState(() => _progress = 1.0);
      await Future.delayed(const Duration(milliseconds: 600));

      // Navigation vers résultat
      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
            pageBuilder: (_, a, __) => DiseaseResultScreen(
              result    : result,
              imageFile : widget.imageFile,
              scanId    : widget.scanId,
            ),
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: CurvedAnimation(
                    parent: a, curve: Curves.easeOut), child: child),
            transitionDuration: const Duration(milliseconds: 400)));
      }

    } on PlantNotFoundException catch (e) {
      _showError('🌿 Plante non reconnue',
          e.message + '\n\nConseils :\n• Rapprochez-vous de la feuille\n'
              '• Assurez-vous d\'avoir sélectionné la bonne culture\n'
              '• Bonne lumière, fond neutre');
    } on ModelNotLoadedException catch (e) {
      _showError('⚙️ Modèle non chargé', e.message);
    } catch (e) {
      _showError('Erreur d\'analyse', e.toString());
    }
  }

  void _setStep(int index, String msg) {
    if (mounted) setState(() {
      _stepIndex  = index;
      _currentMsg = msg;
    });
  }

  // ── Met à jour l'enregistrement "En cours..." créé par
  //    ScannerScreen avec le résultat réel de la prédiction
  //    (au lieu de laisser un placeholder fantôme). ────────
  Future<void> _updateScanResult(DiseaseDetectionResult result) async {
    if (widget.scanId == null) return;
    await DatabaseService().updateScanResult(
      scanId     : widget.scanId!,
      diseaseName: result.diseaseName,
      severity   : result.severityLabel,
      confidence : result.confidence,
      modelUsed  : result.modelUsed.displayName,
    );
  }

  DiseaseDetectionResult _demoResult() {
    return DiseaseDetectionResult(
      diseaseName: 'Rust',
      confidence : 0.87,
      plantType  : widget.plantType,
      modelUsed  : ModelVersion.mobileViT,
      allScores  : [
        ClassScore('Rust',    0.87),
        ClassScore('Blight',  0.08),
        ClassScore('Spot',    0.03),
        ClassScore('Healthy', 0.02),
      ],
      inferenceMs: 245,
    );
  }

  void _showError(String title, String msg) {
    if (mounted) setState(() {
      _hasError  = true;
      _errorMsg  = msg;
      _currentMsg = title;
      _progress   = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: w >= 900 ? _buildDesktop() : _buildMobile(),
    );
  }

  Widget _buildDesktop() => Row(children: [
    Expanded(flex: 5,
        child: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A3D1C), Color(0xFF234F26)])),
            child: Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              if (!_hasError) ...[
                _buildSpinner(180),
                const SizedBox(height: 28),
                Text('Analyse en cours', style: GoogleFonts.nunito(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: Colors.white)),
                const SizedBox(height: 10),
                SizedBox(width: 300, child: Text(_currentMsg,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunitoSans(
                        fontSize: 14, color: Colors.white.withOpacity(0.7)))),
                const SizedBox(height: 28),
                _buildProgressBar(300),
              ] else
                _buildErrorWidget(isDesktop: true),
            ])))),
    Container(width: 1.5, color: AppColors.border),
    SizedBox(width: 360,
        child: _buildStepsPanel(isDesktop: true)),
  ]);

  Widget _buildMobile() => SafeArea(
      child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: _hasError
              ? _buildErrorWidget(isDesktop: false)
              : Column(children: [
            _buildSpinner(160),
            const SizedBox(height: 24),
            Text('L\'IA examine votre plante',
                style: GoogleFonts.nunito(fontSize: 20,
                    fontWeight: FontWeight.w900, color: AppColors.g900)),
            const SizedBox(height: 8),
            Text(_currentMsg, textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    fontSize: 14, color: AppColors.t2)),
            const SizedBox(height: 20),
            _buildProgressBar(double.infinity),
            const SizedBox(height: 28),
            _buildStepsPanel(isDesktop: false),
          ])));

  Widget _buildSpinner(double size) {
    return SizedBox(width: size, height: size,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: _ring1, builder: (_, __) =>
              Transform.rotate(angle: _ring1.value * 6.28,
                  child: Container(width: size, height: size,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.g600.withOpacity(0.9), width: 3))))),
          AnimatedBuilder(animation: _ring2, builder: (_, __) =>
              Transform.rotate(angle: -_ring2.value * 6.28,
                  child: Container(width: size - 28, height: size - 28,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.g500.withOpacity(0.5), width: 2))))),
          AnimatedBuilder(animation: _ring3, builder: (_, __) =>
              Transform.rotate(angle: _ring3.value * 6.28,
                  child: Container(width: size - 56, height: size - 56,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.amber.withOpacity(0.4), width: 2))))),
          Container(
              width: size - 80, height: size - 80,
              decoration: BoxDecoration(
                  color: AppColors.surface, shape: BoxShape.circle,
                  boxShadow: AppShadows.md),
              child: const Center(
                  child: Text('🔬', style: TextStyle(fontSize: 36)))),
        ]));
  }

  Widget _buildProgressBar(double width) {
    final pct = (_progress * 100).round();
    return SizedBox(
        width: width == double.infinity ? null : width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                      value: _progress, minHeight: 10,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.g600))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progression', style: GoogleFonts.nunito(
                        fontSize: 12, color: AppColors.t3)),
                    Text('$pct%', style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: AppColors.g700)),
                  ]),
            ]));
  }

  Widget _buildStepsPanel({required bool isDesktop}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Étapes d\'analyse', style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.g900)),
                    const SizedBox(height: 4),
                    Text('Pipeline IA AgriScan', style: GoogleFonts.nunitoSans(
                        fontSize: 13, color: AppColors.t3)),
                  ])),
          Padding(
              padding: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 20)
                  : EdgeInsets.zero,
              child: Column(children: _steps.asMap().entries.map((e) {
                final i     = e.key;
                final s     = e.value;
                final done  = i < _stepIndex;
                final active= i == _stepIndex && !_hasError;
                final wait  = i > _stepIndex;

                return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: done ? AppColors.g50 : active
                            ? AppColors.surface : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: done ? AppColors.g300 : active
                                ? AppColors.g600 : AppColors.border,
                            width: active || done ? 2 : 1.5)),
                    child: Row(children: [
                      Container(width: 42, height: 42,
                          decoration: BoxDecoration(
                              color: done ? AppColors.g700 : active
                                  ? AppColors.g100 : AppColors.surface2,
                              borderRadius: BorderRadius.circular(13)),
                          child: Center(child: Text(
                              done ? '✅' : s.icon,
                              style: const TextStyle(fontSize: 20)))),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, style: GoogleFonts.nunito(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: done ? AppColors.g700 : active
                                    ? AppColors.t1 : AppColors.t3)),
                            const SizedBox(height: 2),
                            Text(done ? 'Terminé ✓' : active
                                ? _currentMsg : 'En attente…',
                                style: GoogleFonts.nunitoSans(
                                    fontSize: 12, color: done
                                    ? AppColors.g600 : AppColors.t3)),
                          ])),
                      if (active && !_hasError)
                        SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.g600))
                      else if (done)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: AppColors.g50,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                    color: const Color(0xFFA8D9B0))),
                            child: Text('✓', style: GoogleFonts.nunito(
                                fontSize: 12, fontWeight: FontWeight.w800,
                                color: AppColors.green))),
                    ]));
              }).toList())),
        ]);
  }

  Widget _buildErrorWidget({required bool isDesktop}) {
    return Container(
        padding: const EdgeInsets.all(24),
        margin: isDesktop ? const EdgeInsets.all(32) : EdgeInsets.zero,
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.red.withOpacity(0.3), width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(_currentMsg, style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.g900)),
          const SizedBox(height: 10),
          Text(_errorMsg, textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(
                  fontSize: 13, color: AppColors.t2, height: 1.5)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.t2,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Retour', style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
                onPressed: () {
                  setState(() { _hasError = false; _progress = 0; });
                  _runAnalysis();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.g700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                child: Text('Réessayer', style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: Colors.white)))),
          ]),
        ]));
  }
}

class _Step {
  final String icon, title, subtitle;
  const _Step(this.icon, this.title, this.subtitle);
}