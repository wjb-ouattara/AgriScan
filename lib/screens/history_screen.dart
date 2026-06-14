import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../utils/disease_meta.dart';
import 'disease_result_screen.dart';
import 'recommendations_screen.dart';

// ── Helpers d'affichage ────────────────────────────────────
String diseaseDisplayName(String code) =>
    DiseaseMeta.all.containsKey(code) ? DiseaseMeta.of(code).labelFr : code;

String plantDisplayName(String raw) {
  final l = raw.toLowerCase();
  if (l.contains('maïs') || l.contains('maize')) return 'Maïs';
  if (l.contains('tomate') || l.contains('tomato')) return 'Tomate';
  return raw;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();

  List<ScanRecord> _scans    = [];
  List<ScanRecord> _filtered = [];
  bool   _loading = true;
  String _filter  = 'Tous';
  String _search  = '';
  late TabController _tabs;

  static const _filters = ['Tous', 'Maïs', 'Tomate', 'Malade', 'Sain'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadScans();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadScans() async {
    setState(() => _loading = true);
    try {
      final userId = await _db.getCurrentUserId();
      final scans  = await _db.getScans(userId: userId, limit: 200);
      if (mounted) setState(() {
        _scans    = scans;
        _filtered = scans;
        _loading  = false;
      });
      _applyFilter();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    List<ScanRecord> result = List.from(_scans);
    switch (_filter) {
      case 'Maïs':
        result = result.where((s) =>
        s.plantType.toLowerCase().contains('maïs') ||
            s.plantType.toLowerCase().contains('maize')).toList();
        break;
      case 'Tomate':
        result = result.where((s) =>
            s.plantType.toLowerCase().contains('tomate')).toList();
        break;
      case 'Malade':
        result = result.where((s) =>
        !s.diseaseName.toLowerCase().contains('sain') &&
            !s.diseaseName.toLowerCase().contains('healthy')).toList();
        break;
      case 'Sain':
        result = result.where((s) =>
        s.diseaseName.toLowerCase().contains('sain') ||
            s.diseaseName.toLowerCase().contains('healthy')).toList();
        break;
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((s) =>
      s.diseaseName.toLowerCase().contains(q) ||
          diseaseDisplayName(s.diseaseName).toLowerCase().contains(q) ||
          s.plantType.toLowerCase().contains(q) ||
          (s.customLabel?.toLowerCase().contains(q) ?? false)).toList();
    }
    setState(() => _filtered = result);
  }

  bool _isHealthy(ScanRecord s) =>
      s.diseaseName.toLowerCase().contains('sain') ||
          s.diseaseName.toLowerCase().contains('healthy');

  // ── Renommer (étiquette personnalisée) ─────────────────
  Future<void> _renameScan(ScanRecord scan) async {
    final ctrl = TextEditingController(text: scan.customLabel ?? '');
    final result = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Renommer l\'analyse', style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
            content: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Donnez un nom à ce scan pour le retrouver facilement '
                      '(ex: parcelle, champ...).',
                      style: GoogleFonts.nunitoSans(fontSize: 12.5, color: AppColors.t3)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: ctrl, autofocus: true,
                      style: GoogleFonts.nunitoSans(fontSize: 14),
                      decoration: InputDecoration(
                          hintText: 'Ex : Champ Nord - Parcelle 3',
                          hintStyle: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
                ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g700, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white))),
            ]));
    if (result == null) return;
    await _db.updateScanLabel(scan.id, result.isEmpty ? null : result);
    await _loadScans();
  }

  // ── Supprimer ────────────────────────────────────────────
  Future<void> _deleteScan(ScanRecord scan) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Supprimer cette analyse ?', style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
            content: Text('Cette action est irréversible.',
                style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t2)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Supprimer', style: TextStyle(color: Colors.white))),
            ]));
    if (confirm != true) return;
    await _db.deleteScan(scan.id);
    await _loadScans();
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
  Widget _buildDesktop() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: Column(children: [
          _buildTopBar(),
          _buildTabs(),
          Expanded(child: _tabs.index == 0
              ? _buildListView()
              : _buildDashboard()),
        ])),
        Container(width: 1.5, color: AppColors.border),
        SizedBox(width: 340, child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildDashboard())),
      ]);

  // ════════════════════════════════════════════════════
  //  MOBILE
  // ════════════════════════════════════════════════════
  Widget _buildMobile() => Column(children: [
    SizedBox(height: MediaQuery.of(context).padding.top + 8),
    _buildTopBar(),
    _buildTabs(),
    Expanded(child: _tabs.index == 0
        ? _buildListView()
        : _buildDashboard()),
  ]);

  // ════════════════════════════════════════════════════
  //  TOP BAR
  // ════════════════════════════════════════════════════
  Widget _buildTopBar() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Historique', style: GoogleFonts.nunito(
              fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.g900)),
          Text('${_scans.length} analyse${_scans.length > 1 ? "s" : ""} enregistrée${_scans.length > 1 ? "s" : ""}',
              style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
        ])),
        GestureDetector(
            onTap: _loadScans,
            child: Container(width: 38, height: 38,
                decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border, width: 1.5)),
                child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.t2))),
      ]));

  // ════════════════════════════════════════════════════
  //  TABS — Liste / Tableau de bord
  // ════════════════════════════════════════════════════
  Widget _buildTabs() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1.5)),
          child: Row(children: [
            Expanded(child: _SegmentBtn(
                emoji: '📋', label: 'Liste', active: _tabs.index == 0,
                onTap: () { setState(() => _tabs.index = 0); })),
            Expanded(child: _SegmentBtn(
                emoji: '📊', label: 'Tableau de bord', active: _tabs.index == 1,
                onTap: () { setState(() => _tabs.index = 1); })),
          ])));

  // ════════════════════════════════════════════════════
  //  VUE LISTE
  // ════════════════════════════════════════════════════
  Widget _buildListView() => Column(children: [
    _buildFilterBar(),
    _buildSearchBar(),
    Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.g600))
        : _filtered.isEmpty
        ? _buildEmpty()
        : _buildList()),
  ]);

  Widget _buildSearchBar() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
          height: 42,
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5)),
          child: TextField(
              onChanged: (v) { _search = v; _applyFilter(); },
              style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t1),
              decoration: InputDecoration(
                  hintText: 'Rechercher une maladie ou une étiquette...',
                  hintStyle: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t4),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.t3),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10)))));

  static const Map<String, String> _filterEmojis = {
    'Tous': '🗂️', 'Maïs': '🌽', 'Tomate': '🍅',
    'Malade': '🔴', 'Sain': '🟢',
  };

  Widget _buildFilterBar() => Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(children: [
        Expanded(child: GestureDetector(
            onTap: _showFilterMenu,
            child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.5)),
                child: Row(children: [
                  Text(_filterEmojis[_filter] ?? '🗂️',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                      _filter == 'Tous' ? 'Toutes les analyses' : _filter,
                      style: GoogleFonts.nunito(fontSize: 13,
                          fontWeight: FontWeight.w700, color: AppColors.t1))),
                  const Icon(Icons.expand_more_rounded,
                      size: 20, color: AppColors.t3),
                ]))),
        ),
        if (_filter != 'Tous') ...[
          const SizedBox(width: 8),
          GestureDetector(
              onTap: () { setState(() => _filter = 'Tous'); _applyFilter(); },
              child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.5)),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.t3))),
        ],
      ]));

  void _showFilterMenu() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(100))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(children: [
                    Text('Filtrer les analyses', style: GoogleFonts.nunito(
                        fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.g900)),
                  ])),
              const SizedBox(height: 4),
              ..._filters.map((f) {
                final active = _filter == f;
                return InkWell(
                    onTap: () {
                      setState(() => _filter = f);
                      _applyFilter();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Container(width: 36, height: 36,
                              decoration: BoxDecoration(
                                  color: active ? AppColors.g700 : AppColors.surface2,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Center(child: Text(_filterEmojis[f] ?? '🗂️',
                                  style: const TextStyle(fontSize: 17)))),
                          const SizedBox(width: 14),
                          Expanded(child: Text(
                              f == 'Tous' ? 'Toutes les analyses' : f,
                              style: GoogleFonts.nunito(fontSize: 14,
                                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                  color: active ? AppColors.g700 : AppColors.t1))),
                          if (active) const Icon(Icons.check_circle_rounded,
                              color: AppColors.g700, size: 20),
                        ])));
              }),
              const SizedBox(height: 8),
            ])));
  }

  Widget _buildList() => ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ScanCard(
          scan: _filtered[i],
          onTap: () => Navigator.push(context, PageRouteBuilder(
              pageBuilder: (_, a, __) => const DiseaseResultScreen(),
              transitionsBuilder: (_, a, __, child) => SlideTransition(
                  position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                  child: child),
              transitionDuration: const Duration(milliseconds: 300))),
          onRename: () => _renameScan(_filtered[i]),
          onDelete: () => _deleteScan(_filtered[i])));

  Widget _buildEmpty() => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌿', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text('Aucune analyse', style: GoogleFonts.nunito(
            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.t1)),
        const SizedBox(height: 8),
        Text(_filter == 'Tous'
            ? 'Vos analyses apparaîtront ici\naprès votre premier scan'
            : 'Aucun résultat pour ce filtre',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t3)),
      ]));

  // ════════════════════════════════════════════════════
  //  TABLEAU DE BORD — Graphiques
  // ════════════════════════════════════════════════════
  Widget _buildDashboard() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.g600));
    }
    if (_scans.isEmpty) {
      return _buildEmpty();
    }

    final total   = _scans.length;
    final malades = _scans.where((s) => !_isHealthy(s)).length;
    final sains   = total - malades;
    final maize   = _scans.where((s) =>
    s.plantType.toLowerCase().contains('maïs') ||
        s.plantType.toLowerCase().contains('maize')).length;
    final tomate  = total - maize;

    // Top maladies
    final diseaseCounts = <String, int>{};
    for (final s in _scans) {
      if (!_isHealthy(s)) {
        diseaseCounts[s.diseaseName] = (diseaseCounts[s.diseaseName] ?? 0) + 1;
      }
    }
    final topDiseases = diseaseCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Tendance 7 derniers jours
    final now = DateTime.now();
    final weekCounts = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return _scans.where((s) =>
      s.createdAt.year == day.year &&
          s.createdAt.month == day.month &&
          s.createdAt.day == day.day).length;
    });

    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Stats principales
          Row(children: [
            Expanded(child: _KpiCard('📊', '$total', 'Total', AppColors.g700)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('🔴', '$malades', 'Malades', AppColors.red)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('🟢', '$sains', 'Saines', AppColors.green)),
          ]),
          const SizedBox(height: 20),

          // Camembert santé
          _DashCard(
              title: 'Répartition santé',
              emoji: '🩺',
              child: SizedBox(height: 180, child: Row(children: [
                Expanded(child: CustomPaint(
                    size: const Size(140, 140),
                    painter: _PieChartPainter(segments: [
                      _PieSegment(sains.toDouble(), AppColors.green, 'Saines'),
                      _PieSegment(malades.toDouble(), AppColors.red, 'Malades'),
                    ]))),
                const SizedBox(width: 16),
                Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendDot(AppColors.green, 'Saines',
                          total > 0 ? '${(sains/total*100).round()}%' : '0%'),
                      const SizedBox(height: 10),
                      _LegendDot(AppColors.red, 'Malades',
                          total > 0 ? '${(malades/total*100).round()}%' : '0%'),
                    ])),
              ]))),
          const SizedBox(height: 16),

          // Répartition par culture
          _DashCard(
              title: 'Répartition par culture',
              emoji: '🌱',
              child: Column(children: [
                _BarRow('🌽 Maïs', maize, total, AppColors.amber),
                const SizedBox(height: 10),
                _BarRow('🍅 Tomate', tomate, total, AppColors.red),
              ])),
          const SizedBox(height: 16),

          // Tendance 7 jours
          _DashCard(
              title: 'Activité — 7 derniers jours',
              emoji: '📈',
              child: SizedBox(height: 140, child: CustomPaint(
                  size: const Size(double.infinity, 140),
                  painter: _TrendChartPainter(values: weekCounts)))),
          const SizedBox(height: 16),

          // Top maladies
          if (topDiseases.isNotEmpty)
            _DashCard(
                title: 'Maladies les plus fréquentes',
                emoji: '🦠',
                child: Column(children: topDiseases.take(5).map((e) {
                  final pct = malades > 0 ? e.value / malades : 0.0;
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(diseaseDisplayName(e.key), style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.t1),
                              overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text('${e.value}', style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.red)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                                value: pct, minHeight: 6,
                                backgroundColor: AppColors.surface2,
                                valueColor: const AlwaysStoppedAnimation(AppColors.red))),
                      ]));
                }).toList())),
        ]));
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════════

class _SegmentBtn extends StatelessWidget {
  final String emoji, label;
  final bool active;
  final VoidCallback onTap;
  const _SegmentBtn({required this.emoji, required this.label,
    required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: active ? AppColors.g700 : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active ? AppShadows.sm : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.t2)),
          ])));
}

class _KpiCard extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _KpiCard(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.nunito(
            fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.nunitoSans(
            fontSize: 11, color: AppColors.t3)),
      ]));
}

class _DashCard extends StatelessWidget {
  final String title, emoji;
  final Widget child;
  const _DashCard({required this.title, required this.emoji, required this.child});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: AppShadows.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.g900)),
        ]),
        const SizedBox(height: 16),
        child,
      ]));
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label, value;
  const _LegendDot(this.color, this.label, this.value);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: GoogleFonts.nunitoSans(
        fontSize: 13, color: AppColors.t2))),
    Text(value, style: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t1)),
  ]);
}

class _BarRow extends StatelessWidget {
  final String label;
  final int value, total;
  final Color color;
  const _BarRow(this.label, this.value, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.t1))),
        Text('$value', style: GoogleFonts.nunito(
            fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 6),
        Text('(${(pct*100).round()}%)', style: GoogleFonts.nunitoSans(
            fontSize: 12, color: AppColors.t3)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
              value: pct, minHeight: 10,
              backgroundColor: AppColors.surface2,
              valueColor: AlwaysStoppedAnimation(color))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════
//  CARTE DE SCAN — avec menu "..." et volet dépliable
// ══════════════════════════════════════════════════════════

class _ScanCard extends StatefulWidget {
  final ScanRecord scan;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _ScanCard({
    required this.scan,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<_ScanCard> {
  bool _expanded = false;

  ScanRecord get scan => widget.scan;

  Color get _severityColor {
    switch (scan.severity.toLowerCase()) {
      case 'grave':  return AppColors.red;
      case 'modéré': return AppColors.amber;
      case 'faible': return AppColors.green;
      default:       return AppColors.t3;
    }
  }

  bool get _isHealthy =>
      scan.diseaseName.toLowerCase().contains('sain') ||
          scan.diseaseName.toLowerCase().contains('healthy');

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(100))),
              _MenuAction(emoji: '✏️', label: 'Renommer',
                  onTap: () { Navigator.pop(ctx); widget.onRename(); }),
              _MenuAction(emoji: '🗑️', label: 'Supprimer',
                  color: AppColors.red,
                  onTap: () { Navigator.pop(ctx); widget.onDelete(); }),
              const SizedBox(height: 8),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final meta = DiseaseMeta.of(scan.diseaseName);
    final date = '${scan.createdAt.day.toString().padLeft(2, '0')}/'
        '${scan.createdAt.month.toString().padLeft(2, '0')}/'
        '${scan.createdAt.year}';
    final time = '${scan.createdAt.hour.toString().padLeft(2, '0')}:'
        '${scan.createdAt.minute.toString().padLeft(2, '0')}';

    final hasLabel = scan.customLabel != null && scan.customLabel!.trim().isNotEmpty;
    final title = hasLabel ? scan.customLabel! : diseaseDisplayName(scan.diseaseName);

    return Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                    onTap: widget.onTap,
                    child: Container(width: 48, height: 48,
                        decoration: BoxDecoration(
                            color: meta.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(
                            plantDisplayName(scan.plantType) == 'Maïs' ? '🌽' : '🍅',
                            style: const TextStyle(fontSize: 24))))),
                const SizedBox(width: 14),
                Expanded(child: GestureDetector(
                    onTap: widget.onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: GoogleFonts.nunito(
                          fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.t1),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (hasLabel) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Text('🔬', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Expanded(child: Text(diseaseDisplayName(scan.diseaseName),
                              style: GoogleFonts.nunitoSans(fontSize: 11.5, color: AppColors.t3),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                      const SizedBox(height: 3),
                      Row(children: [
                        Text(plantDisplayName(scan.plantType), style: GoogleFonts.nunitoSans(
                            fontSize: 12, color: AppColors.t3)),
                        const SizedBox(width: 8),
                        Text('·', style: GoogleFonts.nunitoSans(color: AppColors.t4)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('$date à $time', style: GoogleFonts.nunitoSans(
                            fontSize: 12, color: AppColors.t3),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                    ]))),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: _severityColor.withOpacity(0.35))),
                      child: Text(_isHealthy ? 'Saine' : scan.severity,
                          style: GoogleFonts.nunito(fontSize: 11,
                              fontWeight: FontWeight.w700, color: _severityColor))),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('${(scan.confidence * 100).round()}%',
                        style: GoogleFonts.nunito(fontSize: 12,
                            fontWeight: FontWeight.w700, color: AppColors.t2)),
                    const SizedBox(width: 4),
                    Icon(scan.synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        size: 14, color: scan.synced ? AppColors.green : AppColors.t4),
                  ]),
                ]),
                const SizedBox(width: 4),
                GestureDetector(
                    onTap: () => _showMenu(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.t3))),
              ])),

          // ── Chevron : déplier / replier ──────────────────
          InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(border: Border(
                      top: BorderSide(color: AppColors.surface2, width: 1))),
                  child: Icon(_expanded
                      ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20, color: AppColors.t4))),

          // ── Contenu déplié ────────────────────────────────
          if (_expanded)
            Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _detailRow('📅', 'Date complète', '$date à $time'),
                  _detailRow('🧠', 'Modèle IA',
                      scan.modelUsed.isEmpty ? '—' : scan.modelUsed),
                  _detailRow('🌱', 'Culture', plantDisplayName(scan.plantType)),
                  _detailRow('☁️', 'Synchronisation',
                      scan.synced ? 'Synchronisé' : 'En attente'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.science_rounded, size: 16),
                        label: Text('Diagnostic', style: GoogleFonts.nunito(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.g700,
                            side: const BorderSide(color: AppColors.g300, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))))),
                    if (!_isHealthy) ...[
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => RecommendationsScreen(
                                diseaseName  : scan.diseaseName,
                                plantName    : plantDisplayName(scan.plantType),
                                severityLevel: scan.severity,
                                confidence   : scan.confidence,
                              ))),
                          icon: const Text('💊', style: TextStyle(fontSize: 14)),
                          label: Text('Recommandations', style: GoogleFonts.nunito(
                              fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: meta.color, elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))))),
                    ],
                  ]),
                ])),
        ]));
  }

  Widget _detailRow(String emoji, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: GoogleFonts.nunito(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.t2))),
        Text(value, style: GoogleFonts.nunito(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.t1)),
      ]));
}

class _MenuAction extends StatelessWidget {
  final String emoji, label;
  final Color? color;
  final VoidCallback onTap;
  const _MenuAction({required this.emoji, required this.label,
    this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    color: (color ?? AppColors.g700).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 17)))),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.nunito(fontSize: 14,
                fontWeight: FontWeight.w700, color: color ?? AppColors.t1)),
          ])));
}

// ══════════════════════════════════════════════════════════
//  GRAPHIQUES CUSTOM PAINTER
// ══════════════════════════════════════════════════════════

class _PieSegment {
  final double value;
  final Color color;
  final String label;
  _PieSegment(this.value, this.color, this.label);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSegment> segments;
  _PieChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold(0.0, (s, e) => s + e.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    if (total <= 0) {
      final p = Paint()
        ..color = AppColors.surface2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18;
      canvas.drawCircle(center, radius - 9, p);
      return;
    }

    double startAngle = -pi / 2;
    for (final seg in segments) {
      final sweep = (seg.value / total) * 2 * pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 9),
          startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    // Texte central
    final pct = segments.isNotEmpty
        ? (segments[0].value / total * 100).round()
        : 0;
    final textPainter = TextPainter(
        text: TextSpan(
            children: [
              TextSpan(text: '$pct%\n',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                      color: AppColors.g900, fontFamily: 'Nunito')),
              TextSpan(text: segments.isNotEmpty ? segments[0].label : '',
                  style: const TextStyle(fontSize: 10, color: AppColors.t3,
                      fontFamily: 'Nunito')),
            ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) =>
      old.segments != segments;
}

class _TrendChartPainter extends CustomPainter {
  final List<int> values;
  _TrendChartPainter({required this.values});

  static const _days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = values.fold(0, max);
    final chartHeight = size.height - 24;
    final stepX = size.width / (values.length - 1).clamp(1, 999);

    // Grille horizontale
    final gridPaint = Paint()
      ..color = AppColors.surface2
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (maxVal == 0) {
      _drawLabels(canvas, size, chartHeight);
      return;
    }

    // Points
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = chartHeight - (values[i] / maxVal) * chartHeight;
      points.add(Offset(x, y));
    }

    // Aire sous la courbe
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, chartHeight);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..color = AppColors.g700.withOpacity(0.08)
      ..style = PaintingStyle.fill);

    // Ligne
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i-1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx)/2, (prev.dy + curr.dy)/2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(linePath, Paint()
      ..color = AppColors.g700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Points + valeurs
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4, Paint()..color = AppColors.g700);
      canvas.drawCircle(points[i], 2, Paint()..color = Colors.white);

      if (values[i] > 0) {
        final tp = TextPainter(
            text: TextSpan(text: '${values[i]}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: AppColors.g700, fontFamily: 'Nunito')),
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(points[i].dx - tp.width/2, points[i].dy - 18));
      }
    }

    _drawLabels(canvas, size, chartHeight);
  }

  void _drawLabels(Canvas canvas, Size size, double chartHeight) {
    final stepX = size.width / (values.length - 1).clamp(1, 999);
    for (int i = 0; i < _days.length; i++) {
      final tp = TextPainter(
          text: TextSpan(text: _days[i],
              style: const TextStyle(fontSize: 11, color: AppColors.t4,
                  fontFamily: 'Nunito')),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(stepX * i - tp.width/2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) =>
      old.values != values;
}