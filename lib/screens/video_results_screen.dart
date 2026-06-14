import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/ml_service.dart';
import '../services/video_analysis_service.dart';
import '../utils/disease_meta.dart';
import 'recommendations_screen.dart';

// ══════════════════════════════════════════════════════════
//  VIDEO RESULTS SCREEN
//  Rapport de survol : score de santé global, répartition
//  des maladies, timeline colorée, liste des détections
//  prioritaires + accès aux recommandations.
// ══════════════════════════════════════════════════════════

class VideoResultsScreen extends StatelessWidget {
  final VideoAnalysisResult result;
  const VideoResultsScreen({super.key, required this.result});

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.green;
    if (score >= 50) return AppColors.amber;
    return AppColors.red;
  }

  String _scoreLabel(double score) {
    if (score >= 80) return 'Champ globalement sain';
    if (score >= 50) return 'Surveillance recommandée';
    return 'Intervention requise';
  }

  @override
  Widget build(BuildContext context) {
    final score = result.healthScore;
    final color = _scoreColor(score);
    final detections = result.priorityDetections;

    return Scaffold(
        backgroundColor: AppColors.bg,
        body: CustomScrollView(slivers: [
          _buildAppBar(context),
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              sliver: SliverList(delegate: SliverChildListDelegate([
                _buildInfoRow(),
                const SizedBox(height: 20),
                _buildHealthScoreCard(score, color),
                const SizedBox(height: 20),
                _buildDistributionCard(),
                const SizedBox(height: 20),
                _buildTimelineCard(),
                const SizedBox(height: 20),
                _buildDetectionsSection(detections),
                const SizedBox(height: 8),
              ]))),
        ]));
  }

  // ── App bar ────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) => SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: AppColors.g700,
      foregroundColor: Colors.white,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context)),
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
                        Text('Rapport de survol', style: GoogleFonts.nunito(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(result.videoName,
                            style: GoogleFonts.nunitoSans(fontSize: 13,
                                color: Colors.white.withOpacity(0.75)),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 16),
                      ]))),
          ),
      ),
  );

      // ── Infos vidéo ────────────────────────────────────────
      Widget _buildInfoRow() => Row(children: [
  Expanded(child: _InfoChip(
  emoji: '⏱️', label: 'Durée',
  value: formatDuration(result.videoDuration))),
  const SizedBox(width: 10),
  Expanded(child: _InfoChip(
  emoji: '🖼️', label: 'Images analysées',
  value: '${result.totalFrames}')),
  const SizedBox(width: 10),
  Expanded(child: _InfoChip(
  emoji: '📅', label: 'Date',
  value: '${result.analyzedAt.day.toString().padLeft(2,'0')}/'
  '${result.analyzedAt.month.toString().padLeft(2,'0')}')),
  ]);

  // ── Score de santé global ──────────────────────────────
  Widget _buildHealthScoreCard(double score, Color color) => Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: AppShadows.md),
  child: Column(children: [
  SizedBox(
  width: 160, height: 160,
  child: CustomPaint(
  painter: _HealthDonutPainter(
  distribution: result.distribution,
  totalFrames : result.totalFrames),
  child: Center(child: Column(
  mainAxisSize: MainAxisSize.min, children: [
  Text('${score.round()}%', style: GoogleFonts.nunito(
  fontSize: 34, fontWeight: FontWeight.w900, color: color)),
  Text('Santé globale', style: GoogleFonts.nunitoSans(
  fontSize: 12, color: AppColors.t3)),
  ]))),
  ),
  const SizedBox(height: 16),
  Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
  color: color.withOpacity(0.1),
  borderRadius: BorderRadius.circular(100),
  border: Border.all(color: color.withOpacity(0.3))),
  child: Text(_scoreLabel(score), style: GoogleFonts.nunito(
  fontSize: 13, fontWeight: FontWeight.w800, color: color))),
  ]));

  // ── Répartition des maladies ───────────────────────────
  Widget _buildDistributionCard() {
  final entries = result.distribution.entries.toList()
  ..sort((a, b) => b.value.compareTo(a.value));

  return Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: AppShadows.sm),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Row(children: [
  const Text('📊', style: TextStyle(fontSize: 18)),
  const SizedBox(width: 8),
  Text('Répartition sur le survol', style: GoogleFonts.nunito(
  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.g900)),
  ]),
  const SizedBox(height: 14),
  ...entries.map((e) {
  final meta = DiseaseMeta.of(e.key);
  final pct = result.totalFrames == 0
  ? 0.0 : e.value / result.totalFrames * 100;
  return Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Row(children: [
  Text(meta.emoji, style: const TextStyle(fontSize: 14)),
  const SizedBox(width: 8),
  Expanded(child: Text(meta.labelFr, style: GoogleFonts.nunito(
  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.t1))),
  Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.nunito(
  fontSize: 13, fontWeight: FontWeight.w800, color: meta.color)),
  ]),
  const SizedBox(height: 6),
  ClipRRect(borderRadius: BorderRadius.circular(100),
  child: LinearProgressIndicator(
  value: pct / 100, minHeight: 6,
  backgroundColor: AppColors.surface2,
  valueColor: AlwaysStoppedAnimation(meta.color))),
  ]));
  }),
  ]));
  }

  // ── Timeline colorée ────────────────────────────────────
  Widget _buildTimelineCard() {
  final total = result.segments.fold<int>(0, (a, s) => a + s.frameCount);
  if (total == 0) return const SizedBox.shrink();

  return Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.border, width: 1.5),
  boxShadow: AppShadows.sm),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Row(children: [
  const Text('🗺️', style: TextStyle(fontSize: 18)),
  const SizedBox(width: 8),
  Text('Timeline du survol', style: GoogleFonts.nunito(
  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.g900)),
  ]),
  const SizedBox(height: 14),
  ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: SizedBox(height: 28, child: Row(
  children: result.segments.map((s) => Expanded(
  flex: s.frameCount,
  child: Container(color: DiseaseMeta.of(s.diseaseName).color),
  )).toList()))),
  const SizedBox(height: 6),
  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  Text('0:00', style: GoogleFonts.nunitoSans(
  fontSize: 11, color: AppColors.t4)),
  Text(formatDuration(result.videoDuration), style: GoogleFonts.nunitoSans(
  fontSize: 11, color: AppColors.t4)),
  ]),
  const SizedBox(height: 12),
  Wrap(spacing: 12, runSpacing: 8,
  children: result.distribution.keys.map((code) {
  final meta = DiseaseMeta.of(code);
  return Row(mainAxisSize: MainAxisSize.min, children: [
  Container(width: 10, height: 10,
  decoration: BoxDecoration(
  color: meta.color, borderRadius: BorderRadius.circular(3))),
  const SizedBox(width: 6),
  Text(meta.labelFr, style: GoogleFonts.nunitoSans(
  fontSize: 11, color: AppColors.t2)),
  ]);
  }).toList()),
  ]));
  }

  // ── Liste des détections prioritaires ──────────────────
  Widget _buildDetectionsSection(List<VideoSegment> detections) {
  if (detections.isEmpty) {
  return Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
  color: AppColors.g50,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: AppColors.g300, width: 1.5)),
  child: Row(children: [
  const Text('✅', style: TextStyle(fontSize: 28)),
  const SizedBox(width: 14),
  Expanded(child: Column(
  crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text('Aucune anomalie détectée', style: GoogleFonts.nunito(
  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.g700)),
  const SizedBox(height: 2),
  Text('Toutes les zones survolées semblent saines.',
  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t2)),
  ])),
  ]));
  }

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Padding(
  padding: const EdgeInsets.only(bottom: 12, left: 4),
  child: Row(children: [
  const Text('🎯', style: TextStyle(fontSize: 18)),
  const SizedBox(width: 8),
  Text('Détections prioritaires', style: GoogleFonts.nunito(
  fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.g900)),
  const SizedBox(width: 8),
  Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  decoration: BoxDecoration(
  color: AppColors.surface2, borderRadius: BorderRadius.circular(100)),
  child: Text('${detections.length}', style: GoogleFonts.nunito(
  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.t2))),
  ])),
  ...detections.map((s) => _DetectionCard(
  segment: s, totalFrames: result.totalFrames,
  plantType: result.plantType)),
  ]);
  }

}

// ══════════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final String emoji, label, value;
  const _InfoChip({required this.emoji, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.t1)),
        Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 10, color: AppColors.t3)),
      ]));
}

class _DetectionCard extends StatelessWidget {
  final VideoSegment segment;
  final int totalFrames;
  final PlantType plantType;
  const _DetectionCard({
    required this.segment,
    required this.totalFrames,
    required this.plantType,
  });

  String get _plantName => plantType == PlantType.maize ? 'Maïs' : 'Tomate';

  @override
  Widget build(BuildContext context) {
    final meta = DiseaseMeta.of(segment.diseaseName);
    final pct = totalFrames == 0
        ? 0.0 : segment.frameCount / totalFrames * 100;

    return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Bandeau de couleur signalant la sévérité
          Container(height: 4, color: meta.color),

          Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                // Thumbnail
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: segment.thumbnailPath != null
                        ? Image.file(File(segment.thumbnailPath!),
                        width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(meta))
                        : _fallbackThumb(meta)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(meta.emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(meta.labelFr, style: GoogleFonts.nunito(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1),
                        overflow: TextOverflow.ellipsis)),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: meta.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: meta.color.withOpacity(0.3))),
                        child: Text(meta.severityLabel, style: GoogleFonts.nunito(
                            fontSize: 10, fontWeight: FontWeight.w800, color: meta.color))),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 13, color: AppColors.t4),
                    const SizedBox(width: 4),
                    Text('${formatDuration(segment.start)} - ${formatDuration(segment.end)}',
                        style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3)),
                    const SizedBox(width: 10),
                    Icon(Icons.donut_small_rounded, size: 13, color: AppColors.t4),
                    const SizedBox(width: 4),
                    Text('${pct.toStringAsFixed(0)}% du survol',
                        style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3)),
                  ]),
                  const SizedBox(height: 2),
                  Text('Confiance moyenne : ${(segment.avgConfidence * 100).round()}%',
                      style: GoogleFonts.nunitoSans(fontSize: 11, color: AppColors.t4)),
                ])),
              ])),

          // ── Bouton recommandations dédié à cette maladie ──
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => RecommendationsScreen(
                  diseaseName  : segment.diseaseName,
                  plantName    : _plantName,
                  severityLevel: meta.severityLabel,
                  confidence   : segment.avgConfidence,
                ))),
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                    color: meta.color.withOpacity(0.06),
                    border: Border(top: BorderSide(
                        color: AppColors.surface2, width: 1))),
                child: Row(children: [
                  Container(width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: meta.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(9)),
                      child: Center(child: Text('💊', style: TextStyle(
                          fontSize: 14)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                      'Recommandations & traitement',
                      style: GoogleFonts.nunito(fontSize: 13,
                          fontWeight: FontWeight.w800, color: meta.color))),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: meta.color),
                ])),
          ),
        ]));
  }

  Widget _fallbackThumb(DiseaseMeta meta) => Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
          color: meta.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(meta.emoji, style: const TextStyle(fontSize: 24))));
}

// ══════════════════════════════════════════════════════════
//  DONUT CHART — santé globale (multi-segments)
// ══════════════════════════════════════════════════════════

class _HealthDonutPainter extends CustomPainter {
  final Map<String, int> distribution;
  final int totalFrames;
  const _HealthDonutPainter({
    required this.distribution, required this.totalFrames});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalFrames == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    const strokeWidth = 16.0;

    // Fond
    final bgPaint = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Segments
    double startAngle = -pi / 2;
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final e in entries) {
      final sweep = (e.value / totalFrames) * 2 * pi;
      final paint = Paint()
        ..color = DiseaseMeta.of(e.key).color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _HealthDonutPainter old) =>
      old.distribution != distribution || old.totalFrames != totalFrames;
}