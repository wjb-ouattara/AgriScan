import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════
//  DISEASE META — référence partagée couleur/emoji/sévérité
//  pour les 6 classes du modèle CropNet (maïs).
//  Utilisé par l'analyse vidéo (timeline, donut, priorités).
// ══════════════════════════════════════════════════════════

class DiseaseMeta {
  final String code;        // ex: 'f_GLS'
  final String labelFr;     // ex: 'Cercosporiose (GLS)'
  final String emoji;
  final Color  color;
  final double severity;    // 0.0 (sain) → 1.0 (très grave)
  final bool   isViral;

  const DiseaseMeta({
    required this.code,
    required this.labelFr,
    required this.emoji,
    required this.color,
    required this.severity,
    this.isViral = false,
  });

  bool get isHealthy => code == 'Healthy';

  String get severityLabel {
    if (isHealthy) return 'Sain';
    if (severity >= 0.8) return 'Grave';
    if (severity >= 0.5) return 'Modéré';
    return 'Faible';
  }

  static const Map<String, DiseaseMeta> all = {
    'Healthy': DiseaseMeta(
        code: 'Healthy', labelFr: 'Sain', emoji: '🌿',
        color: Color(0xFF4CAF6D), severity: 0.0),
    'f_GLS': DiseaseMeta(
        code: 'f_GLS', labelFr: 'Cercosporiose (GLS)', emoji: '🟡',
        color: Color(0xFFE8A33D), severity: 0.55),
    'f_NLB': DiseaseMeta(
        code: 'f_NLB', labelFr: 'Helminthosporiose (NLB)', emoji: '🟠',
        color: Color(0xFFD4722C), severity: 0.6),
    'f_RUST': DiseaseMeta(
        code: 'f_RUST', labelFr: 'Rouille commune', emoji: '🔴',
        color: Color(0xFFC0504D), severity: 0.5),
    'v_MLN': DiseaseMeta(
        code: 'v_MLN', labelFr: 'Nécrose Létale (MLN)', emoji: '🟣',
        color: Color(0xFF8E44AD), severity: 1.0, isViral: true),
    'v_MSV': DiseaseMeta(
        code: 'v_MSV', labelFr: 'Striure (MSV)', emoji: '🔵',
        color: Color(0xFF2E75B6), severity: 0.85, isViral: true),
  };

  static DiseaseMeta of(String code) =>
      all[code] ?? const DiseaseMeta(
          code: '?', labelFr: 'Inconnu', emoji: '❓',
          color: Color(0xFF9E9E9E), severity: 0.5);
}

// ── Helper formatage durée mm:ss ──────────────────────────
String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}