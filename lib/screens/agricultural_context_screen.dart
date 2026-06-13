import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';

class AgriculturalContextScreen extends StatefulWidget {
  const AgriculturalContextScreen({super.key});
  @override
  State<AgriculturalContextScreen> createState() =>
      _AgriculturalContextScreenState();
}

class _AgriculturalContextScreenState
    extends State<AgriculturalContextScreen> {

  final _db = DatabaseService();

  String _region  = 'Maroc';
  String _culture = 'Maïs';
  String _soil    = 'Argileux';
  String _season  = 'Été';
  String _climate = 'Tropical humide';
  double _area    = 2.0;
  bool   _loading = true;
  bool   _saving  = false;

  static const _regions = [
    ('🇲🇦', 'Maroc'),       ('🇨🇮', "Côte d'Ivoire"), ('🇸🇳', 'Sénégal'),
    ('🇲🇱', 'Mali'),        ('🇧🇫', 'Burkina Faso'), ('🇳🇪', 'Niger'),
    ('🇨🇲', 'Cameroun'),    ('🇹🇬', 'Togo'),         ('🇧🇯', 'Bénin'),
    ('🇬🇭', 'Ghana'),       ('🇳🇬', 'Nigeria'),      ('🇰🇪', 'Kenya'),
    ('🌍', 'Autre'),
  ];
  static const _cultures = [
    ('🌽', 'Maïs'),     ('🍅', 'Tomate'),  ('🌾', 'Riz'),
    ('🥜', 'Arachide'), ('🫘', 'Soja'),    ('🍠', 'Manioc'),
    ('🧅', 'Oignon'),   ('🌿', 'Autre'),
  ];
  static const _soils = [
    ('🟤', 'Argileux'), ('🟡', 'Sableux'),
    ('⚫', 'Limoneux'), ('🔴', 'Latéritique'),
    ('🟢', 'Humifère'), ('⚪', 'Calcaire'),
  ];
  static const _seasons = [
    ('☀️',  'Été'),             ('🌧️', 'Saison des pluies'),
    ('💨', 'Harmattan'),       ('🌱', 'Début saison'),
    ('🌾', 'Fin saison'),      ('❄️',  'Hiver sec'),
  ];
  static const _climates = [
    ('🌴', 'Tropical humide'), ('☀️',  'Tropical sec'),
    ('🌵', 'Sahélien'),        ('⛰️', 'Montagnard'),
    ('🏜️', 'Aride'),           ('🌊', 'Côtier'),
    ('🌿', 'Tempéré'),
  ];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    setState(() => _loading = true);
    try {
      final userId = await _db.getCurrentUserId();
      if (userId != null) {
        final user = await _db.getUser(userId);
        if (user != null && user.region.isNotEmpty) {
          _region = user.region;
        }
      }
      final region  = await _db.getSetting('ctx_region');
      final culture = await _db.getSetting('ctx_culture');
      final soil    = await _db.getSetting('ctx_soil');
      final season  = await _db.getSetting('ctx_season');
      final climate = await _db.getSetting('ctx_climate');
      final area    = await _db.getSetting('ctx_area');
      setState(() {
        if (region  != null) _region  = region;
        if (culture != null) _culture = culture;
        if (soil    != null) _soil    = soil;
        if (season  != null) _season  = season;
        if (climate != null) _climate = climate;
        if (area    != null) _area = double.tryParse(area) ?? 2.0;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.setSetting('ctx_region',  _region);
      await _db.setSetting('ctx_culture', _culture);
      await _db.setSetting('ctx_soil',    _soil);
      await _db.setSetting('ctx_season',  _season);
      await _db.setSetting('ctx_climate', _climate);
      await _db.setSetting('ctx_area',    _area.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Contexte sauvegardé ✅',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2)));
        Navigator.pop(context, true);
      }
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  // ── Bottom sheet sélecteur (région) ──────────────────
  Future<void> _pickRegion() async {
    final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _PickerSheet(
          title: 'Choisir une région',
          options: _regions,
          selected: _region,
        ));
    if (result != null) setState(() => _region = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.g600)));
    }
    return Scaffold(
        backgroundColor: AppColors.bg,
        body: CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildSummaryCard(),
                        const SizedBox(height: 24),
                        _SectionTitle('📍', 'Région'),
                        const SizedBox(height: 10),
                        _buildRegionSelector(),
                        const SizedBox(height: 24),
                        _SectionTitle('🌱', 'Culture principale'),
                        const SizedBox(height: 10),
                        _buildCultureGrid(),
                        const SizedBox(height: 24),
                        _SectionTitle('🗓️', 'Saison actuelle'),
                        const SizedBox(height: 10),
                        _buildSeasonGrid(),
                        const SizedBox(height: 24),
                        _SectionTitle('🌤️', 'Type de climat'),
                        const SizedBox(height: 10),
                        _buildClimateGrid(),
                        const SizedBox(height: 24),
                        _SectionTitle('🪨', 'Type de sol'),
                        const SizedBox(height: 10),
                        _buildSoilGrid(),
                        const SizedBox(height: 24),
                        _SectionTitle('📐', 'Superficie du champ'),
                        const SizedBox(height: 10),
                        _buildAreaSlider(),
                        const SizedBox(height: 32),
                        _buildSaveBtn(),
                      ])))
            ]));
  }

  Widget _buildAppBar() {
    return SliverAppBar(
        pinned: true,
        expandedHeight: 120,
        backgroundColor: AppColors.g700,
        foregroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text('Sauvegarder', style: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w800,
                  color: Colors.white))),
        ],
        flexibleSpace: FlexibleSpaceBar(
            background: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1E3820), Color(0xFF2D6530)])),
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Contexte agricole', style: GoogleFonts.nunito(
                                  fontSize: 24, fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('Personnalisez vos recommandations IA',
                                  style: GoogleFonts.nunitoSans(fontSize: 13,
                                      color: Colors.white.withOpacity(0.75))),
                              const SizedBox(height: 16),
                            ]))))));
  }

  Widget _buildSummaryCard() {
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1E3820), Color(0xFF2D5A30)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.md),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _chip(_regionEmoji(_region), _region),
            _chip('🌱', _culture),
            _chip('🗓️', _season),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _chip('🌤️', _climate.split(' ').first),
            _chip('🪨', _soil),
            _chip('📐', '${_area.toStringAsFixed(1)} ha'),
          ]),
        ]));
  }

  String _regionEmoji(String region) {
    for (final r in _regions) {
      if (r.$2 == region) return r.$1;
    }
    return '📍';
  }

  Widget _chip(String emoji, String label) {
    return Expanded(child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 11,
          fontWeight: FontWeight.w700, color: Colors.white),
          overflow: TextOverflow.ellipsis, maxLines: 1),
    ]));
  }

  // ── Sélecteur région (style "select" professionnel) ──
  Widget _buildRegionSelector() {
    return GestureDetector(
        onTap: _pickRegion,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: AppShadows.sm),
            child: Row(children: [
              Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.g50,
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(_regionEmoji(_region),
                      style: const TextStyle(fontSize: 20)))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Région', style: GoogleFonts.nunitoSans(
                    fontSize: 11, color: AppColors.t3)),
                const SizedBox(height: 2),
                Text(_region, style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.t1)),
              ])),
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.g50, shape: BoxShape.circle),
                  child: const Icon(Icons.unfold_more_rounded,
                      size: 18, color: AppColors.g700)),
            ])));
  }

  Widget _buildCultureGrid() {
    return GridView.count(
        crossAxisCount: 4, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0,
        children: _cultures.map((c) => _IconCard(
            emoji: c.$1, label: c.$2,
            selected: _culture == c.$2,
            onTap: () => setState(() => _culture = c.$2))).toList());
  }

  Widget _buildSeasonGrid() {
    return GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45,
        children: _seasons.map((s) => _IconCard(
            emoji: s.$1, label: s.$2,
            selected: _season == s.$2,
            onTap: () => setState(() => _season = s.$2))).toList());
  }

  Widget _buildClimateGrid() {
    return GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.6,
        children: _climates.map((c) => _IconCard(
            emoji: c.$1, label: c.$2,
            selected: _climate == c.$2,
            onTap: () => setState(() => _climate = c.$2))).toList());
  }

  Widget _buildSoilGrid() {
    return GridView.count(
        crossAxisCount: 3, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45,
        children: _soils.map((s) => _IconCard(
            emoji: s.$1, label: s.$2,
            selected: _soil == s.$2,
            onTap: () => setState(() => _soil = s.$2))).toList());
  }

  Widget _buildAreaSlider() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Superficie', style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.t1)),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.g50,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.g300)),
                child: Text('${_area.toStringAsFixed(1)} ha',
                    style: GoogleFonts.nunito(fontSize: 14,
                        fontWeight: FontWeight.w800, color: AppColors.g700))),
          ]),
          SliderTheme(
              data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.g700,
                  thumbColor: AppColors.g700,
                  overlayColor: AppColors.g700.withOpacity(0.1),
                  inactiveTrackColor: AppColors.border),
              child: Slider(
                  value: _area, min: 0.5, max: 50,
                  divisions: 99,
                  onChanged: (v) => setState(() => _area = v))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('0.5 ha', style: GoogleFonts.nunitoSans(
                fontSize: 11, color: AppColors.t4)),
            Text('50 ha', style: GoogleFonts.nunitoSans(
                fontSize: 11, color: AppColors.t4)),
          ]),
        ]));
  }

  Widget _buildSaveBtn() {
    return SizedBox(
        width: double.infinity, height: 52,
        child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.g700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Enregistrer le contexte',
                  style: GoogleFonts.nunito(fontSize: 16,
                      fontWeight: FontWeight.w800, color: Colors.white)),
            ])));
  }
}

// ══════════════════════════════════════════════════════════
//  BOTTOM SHEET PICKER PROFESSIONNEL
// ══════════════════════════════════════════════════════════
class _PickerSheet extends StatefulWidget {
  final String title;
  final List<(String, String)> options;
  final String selected;
  const _PickerSheet({required this.title, required this.options,
    required this.selected});
  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((o) =>
        o.$2.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
              decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(100))),
                const SizedBox(height: 16),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(widget.title, style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: AppColors.g900))),
                const SizedBox(height: 14),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1.5)),
                        child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t1),
                            decoration: InputDecoration(
                                hintText: 'Rechercher...',
                                hintStyle: GoogleFonts.nunitoSans(
                                    fontSize: 14, color: AppColors.t4),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    size: 20, color: AppColors.t3),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12))))),
                const SizedBox(height: 8),
                Expanded(child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: AppColors.surface2),
                    itemBuilder: (_, i) {
                      final opt = filtered[i];
                      final isSelected = opt.$2 == widget.selected;
                      return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context, opt.$2),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(children: [
                                Text(opt.$1, style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 14),
                                Expanded(child: Text(opt.$2, style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppColors.g700 : AppColors.t1))),
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.g700, size: 22),
                              ])));
                    })),
              ]));
        });
  }
}

class _SectionTitle extends StatelessWidget {
  final String emoji, title;
  const _SectionTitle(this.emoji, this.title);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.nunito(fontSize: 16,
          fontWeight: FontWeight.w800, color: AppColors.g900)),
    ]);
  }
}

class _IconCard extends StatelessWidget {
  final String emoji, label;
  final bool selected;
  final VoidCallback onTap;
  const _IconCard({required this.emoji, required this.label,
    required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
                color: selected ? AppColors.g50 : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected ? AppColors.g700 : AppColors.border,
                    width: selected ? 2 : 1.5),
                boxShadow: AppShadows.sm),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(label, textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.g700 : AppColors.t2),
                      overflow: TextOverflow.ellipsis, maxLines: 2),
                ])));
  }
}