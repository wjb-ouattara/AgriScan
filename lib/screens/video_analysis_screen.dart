import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ml_service.dart';
import '../services/video_analysis_service.dart';
import '../utils/disease_meta.dart';
import 'video_results_screen.dart';

// ══════════════════════════════════════════════════════════
//  VIDEO ANALYSIS SCREEN
//  Import vidéo → configuration intervalle → traitement
// ══════════════════════════════════════════════════════════

class VideoAnalysisScreen extends StatefulWidget {
  const VideoAnalysisScreen({super.key});
  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  final _service = VideoAnalysisService();
  final _picker  = ImagePicker();

  File?     _videoFile;
  Duration? _videoDuration;
  double    _intervalSeconds = 1.0; // 0.5 - 5.0

  bool   _loadingMeta = false;
  bool   _processing  = false;
  String _error       = '';

  VideoProgress? _progress;
  final List<Color> _liveColors = [];

  // ── Import depuis la galerie ──────────────────────────
  Future<void> _pickVideo() async {
    setState(() => _error = '');
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      await _loadVideo(File(file.path));
    } catch (e) {
      setState(() => _error = 'Impossible de charger la vidéo : $e');
    }
  }

  Future<void> _loadVideo(File file) async {
    setState(() {
      _loadingMeta  = true;
      _videoFile    = file;
      _videoDuration = null;
    });
    try {
      final d = await _service.getVideoDuration(file);
      if (mounted) setState(() {
        _videoDuration = d;
        _loadingMeta   = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loadingMeta = false;
        _error = 'Vidéo illisible : $e';
        _videoFile = null;
      });
    }
  }

  void _reset() {
    setState(() {
      _videoFile     = null;
      _videoDuration = null;
      _progress      = null;
      _liveColors.clear();
      _error         = '';
    });
  }

  Duration get _interval =>
      Duration(milliseconds: (_intervalSeconds * 1000).round());

  int get _estimatedFrames {
    if (_videoDuration == null || _videoDuration!.inMilliseconds == 0) return 0;
    return (_videoDuration!.inMilliseconds / _interval.inMilliseconds)
        .ceil()
        .clamp(1, 9999);
  }

  // ── Lancer l'analyse ───────────────────────────────────
  Future<void> _startAnalysis() async {
    if (_videoFile == null) return;
    setState(() {
      _processing = true;
      _progress   = null;
      _liveColors.clear();
      _error      = '';
    });

    try {
      final result = await _service.analyzeVideo(
        videoFile: _videoFile!,
        interval : _interval,
        plantType: PlantType.maize,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _liveColors.add(
                DiseaseMeta.of(p.lastDisease ?? 'Healthy').color);
          });
        },
      );

      if (!mounted) return;
      final pushed = await Navigator.push(context, MaterialPageRoute(
          builder: (_) => VideoResultsScreen(result: result)));

      if (mounted) {
        setState(() => _processing = false);
        if (pushed != false) _reset();
      }
    } catch (e) {
      if (mounted) setState(() {
        _processing = false;
        _error = 'Erreur pendant l\'analyse : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.bg,
        body: CustomScrollView(slivers: [
          _buildAppBar(),
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(delegate: SliverChildListDelegate([
                if (_error.isNotEmpty) _buildErrorBanner(),
                if (_processing)
                  _buildProcessingCard()
                else if (_videoFile != null)
                  _buildConfigCard()
                else
                  _buildImportCard(),
              ]))),
        ]));
  }

  // ── App bar ────────────────────────────────────────────
  Widget _buildAppBar() => SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: AppColors.g700,
      foregroundColor: Colors.white,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _processing ? null : () => Navigator.pop(context)),
      flexibleSpace: FlexibleSpaceBar(
          background: Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF1E3820), Color(0xFF2D6530)])),
              child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Analyse vidéo', style: GoogleFonts.nunito(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Simulation de survol drone — détection sur séquence',
                            style: GoogleFonts.nunitoSans(fontSize: 13,
                                color: Colors.white.withOpacity(0.75))),
                        const SizedBox(height: 16),
                      ]))),
          ),
      ),
  );
  Widget _buildErrorBanner() => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: AppColors.red.withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.red.withOpacity(0.3))),
    child: Row(children: [
    const Text('⚠️', style: TextStyle(fontSize: 16)),
    const SizedBox(width: 10),
    Expanded(child: Text(_error, style: GoogleFonts.nunitoSans(
    fontSize: 13, color: AppColors.red))),
  ]));

  // ── Carte d'import ─────────────────────────────────────
  Widget _buildImportCard() => Column(children: [
  GestureDetector(
  onTap: _pickVideo,
  child: Container(
  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
  color: AppColors.g300, width: 1.5,
  style: BorderStyle.solid)),
  child: Column(children: [
  Container(width: 64, height: 64,
  decoration: BoxDecoration(
  color: AppColors.g50, shape: BoxShape.circle),
  child: const Icon(Icons.video_file_rounded,
  size: 30, color: AppColors.g700)),
  const SizedBox(height: 16),
  Text('Importer une vidéo', style: GoogleFonts.nunito(
  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
  const SizedBox(height: 6),
  Text('Sélectionnez une vidéo de survol depuis votre galerie',
  textAlign: TextAlign.center,
  style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
  if (_loadingMeta) ...[
  const SizedBox(height: 16),
  const CircularProgressIndicator(
  color: AppColors.g600, strokeWidth: 2.5),
  ],
  ]))),
  const SizedBox(height: 20),
  _InfoBanner(
  emoji: '💡',
  text: 'La vidéo sera découpée en images à intervalles réguliers, '
  'chacune analysée par l\'IA CropNet. Plus la vidéo est longue, '
  'plus l\'analyse prendra de temps.'),
  ]);

  // ── Carte de configuration ─────────────────────────────
  Widget _buildConfigCard() => Column(children: [
  // Aperçu vidéo
  Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: AppShadows.sm),
  child: Row(children: [
  Container(width: 56, height: 56,
  decoration: BoxDecoration(
  color: AppColors.g50, borderRadius: BorderRadius.circular(14)),
  child: const Icon(Icons.movie_rounded,
  size: 26, color: AppColors.g700)),
  const SizedBox(width: 14),
  Expanded(child: Column(
  crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(_videoFile!.path.split('/').last,
  style: GoogleFonts.nunito(fontSize: 14,
  fontWeight: FontWeight.w800, color: AppColors.t1),
  overflow: TextOverflow.ellipsis),
  const SizedBox(height: 2),
  Text(_videoDuration != null
  ? 'Durée : ${formatDuration(_videoDuration!)}'
      : 'Lecture des informations...',
  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3)),
  ])),
  GestureDetector(
  onTap: _reset,
  child: Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
  color: AppColors.surface2, shape: BoxShape.circle),
  child: const Icon(Icons.close_rounded,
  size: 18, color: AppColors.t3))),
  ])),
  const SizedBox(height: 20),

  // Intervalle de capture
  Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: AppShadows.sm),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Row(children: [
  const Text('⏱️', style: TextStyle(fontSize: 18)),
  const SizedBox(width: 8),
  Expanded(child: Text('Intervalle d\'analyse',
  style: GoogleFonts.nunito(fontSize: 15,
  fontWeight: FontWeight.w800, color: AppColors.g900))),
  Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
  color: AppColors.g50, borderRadius: BorderRadius.circular(100),
  border: Border.all(color: AppColors.g300)),
  child: Text('1 image / ${_intervalSeconds.toStringAsFixed(1)}s',
  style: GoogleFonts.nunito(fontSize: 13,
  fontWeight: FontWeight.w800, color: AppColors.g700))),
  ]),
  SliderTheme(
  data: SliderTheme.of(context).copyWith(
  activeTrackColor: AppColors.g700,
  thumbColor: AppColors.g700,
  overlayColor: AppColors.g700.withOpacity(0.1),
  inactiveTrackColor: AppColors.border),
  child: Slider(
  value: _intervalSeconds, min: 0.5, max: 5.0, divisions: 9,
  onChanged: (v) => setState(() => _intervalSeconds = v))),
  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  Text('Précis (0.5s)', style: GoogleFonts.nunitoSans(
  fontSize: 11, color: AppColors.t4)),
  Text('Rapide (5s)', style: GoogleFonts.nunitoSans(
  fontSize: 11, color: AppColors.t4)),
  ]),
  if (_videoDuration != null) ...[
  const Divider(color: AppColors.surface2, height: 24),
  Row(children: [
  const Text('🖼️', style: TextStyle(fontSize: 16)),
  const SizedBox(width: 8),
  Expanded(child: Text('Images à analyser (estimation)',
  style: GoogleFonts.nunito(fontSize: 13,
  fontWeight: FontWeight.w700, color: AppColors.t2))),
  Text('$_estimatedFrames', style: GoogleFonts.nunito(
  fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.g700)),
  ]),
  ],
  ])),
  const SizedBox(height: 24),

  // Lancer
  SizedBox(width: double.infinity, height: 54,
  child: ElevatedButton(
  onPressed: _videoDuration == null ? null : _startAnalysis,
  style: ElevatedButton.styleFrom(
  backgroundColor: AppColors.g700,
  shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16)),
  elevation: 0),
  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
  const Icon(Icons.play_circle_fill_rounded,
  color: Colors.white, size: 22),
  const SizedBox(width: 10),
  Text('Lancer l\'analyse', style: GoogleFonts.nunito(
  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
  ]))),
  ]);

  // ── Carte de traitement (progress) ─────────────────────
  Widget _buildProcessingCard() {
  final p = _progress;
  final lastMeta = p?.lastDisease != null
  ? DiseaseMeta.of(p!.lastDisease!) : null;

  return Column(children: [
  Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: AppShadows.md),
  child: Column(children: [
  // Spinner + titre
  const SizedBox(width: 48, height: 48,
  child: CircularProgressIndicator(
  color: AppColors.g600, strokeWidth: 3)),
  const SizedBox(height: 16),
  Text('Analyse en cours...', style: GoogleFonts.nunito(
  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.t1)),
  const SizedBox(height: 4),
  Text(p == null
  ? 'Initialisation...'
      : 'Image ${p.current} / ${p.total} · ${formatDuration(p.timestamp)}',
  style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
  const SizedBox(height: 18),

  // Barre de progression
  ClipRRect(borderRadius: BorderRadius.circular(100),
  child: LinearProgressIndicator(
  value: p?.fraction ?? 0, minHeight: 8,
  backgroundColor: AppColors.surface2,
  valueColor: const AlwaysStoppedAnimation(AppColors.g700))),

  // Dernier résultat live
  if (lastMeta != null) ...[
  const SizedBox(height: 18),
  Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  decoration: BoxDecoration(
  color: lastMeta.color.withOpacity(0.1),
  borderRadius: BorderRadius.circular(100),
  border: Border.all(color: lastMeta.color.withOpacity(0.35))),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
  Text(lastMeta.emoji, style: const TextStyle(fontSize: 16)),
  const SizedBox(width: 8),
  Text(lastMeta.labelFr, style: GoogleFonts.nunito(
  fontSize: 13, fontWeight: FontWeight.w800,
  color: lastMeta.color)),
  const SizedBox(width: 8),
  Text('${(p!.lastConfidence! * 100).round()}%',
  style: GoogleFonts.nunito(fontSize: 13,
  fontWeight: FontWeight.w700, color: lastMeta.color)),
  ])),
  ],
  ])),
  const SizedBox(height: 20),

  // Mini timeline live
  if (_liveColors.isNotEmpty)
  Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border, width: 1.5)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text('Aperçu en temps réel', style: GoogleFonts.nunito(
  fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.t2)),
  const SizedBox(height: 10),
  Wrap(spacing: 4, runSpacing: 4,
  children: _liveColors.map((c) => Container(
  width: 16, height: 16,
  decoration: BoxDecoration(
  color: c, borderRadius: BorderRadius.circular(4)))).toList()),
  ])),

  const SizedBox(height: 16),
  _InfoBanner(emoji: 'ℹ️',
  text: 'Veuillez patienter, ne quittez pas cet écran. '
  'L\'analyse complète peut prendre plusieurs minutes selon '
  'la durée de la vidéo et l\'intervalle choisi.'),
  ]);
  }
}

// ── Bandeau d'info réutilisable ─────────────────────────
class _InfoBanner extends StatelessWidget {
  final String emoji, text;
  const _InfoBanner({required this.emoji, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.g50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.g300, width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.nunitoSans(
            fontSize: 12.5, color: AppColors.t2, height: 1.5))),
      ]));
}