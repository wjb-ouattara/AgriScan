import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ml_service.dart';
import '../services/database_service.dart';
import '../services/token_service.dart';
import 'login_screen.dart';
import 'analyzing_screen.dart';

enum ScanMode    { photo, video, importFile, realtime }

// ══════════════════════════════════════════════════════════
//  AGRISCAN — "BOTANIST'S LENS"
//  Thème clair · Fond sage-crème · Cadre circulaire premium
//  Panneau flottant blanc · Zéro élément criard
// ══════════════════════════════════════════════════════════

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {

  ScanMode    _mode      = ScanMode.photo;
  PlantType _plant     = PlantType.maize;
  bool        _panelOpen = true;

  late AnimationController _scanCtrl;
  late AnimationController _breathCtrl;
  late AnimationController _rotCtrl;
  late AnimationController _panelCtrl;
  late Animation<double>   _panelAnim;

  @override
  void initState() {
    super.initState();
    _scanCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2800))..repeat();
    _breathCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _rotCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 12000))..repeat();
    _panelCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 360), value: 1.0);
    _panelAnim = CurvedAnimation(parent: _panelCtrl,
        curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _scanCtrl.dispose(); _breathCtrl.dispose();
    _rotCtrl.dispose(); _panelCtrl.dispose();
    super.dispose();
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    _panelOpen ? _panelCtrl.forward() : _panelCtrl.reverse();
  }

  // ── Couleurs thème clair ──────────────────────────────
  static const _bgTop    = Color(0xFFEDF5E8);  // sage clair
  static const _bgBottom = Color(0xFFF8F3EC);  // crème chaud
  static const _green    = Color(0xFF2D6530);
  static const _greenSoft = Color(0xFF5E9E62);
  static const _frame    = Color(0xFF2D6530);
  static const _textDark = Color(0xFF1A2E1B);
  static const _textSoft = Color(0xFF6B8A6D);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: w >= 900 ? _buildDesktop() : _buildMobile(),
    );
  }

  // ════════════════════════════════════════════════════
  //  DESKTOP
  // ════════════════════════════════════════════════════
  Widget _buildDesktop() => Row(children: [
    Expanded(flex: 6, child: _buildCanvas(isDesktop: true)),
    Container(width: 320,
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Color(0xFFE0EDD9), width: 1.5))),
        child: _buildDesktopPanel()),
  ]);

  // ════════════════════════════════════════════════════
  //  MOBILE
  // ════════════════════════════════════════════════════
  Widget _buildMobile() => Stack(children: [
    Positioned.fill(child: _buildCanvas(isDesktop: false)),
    // Top bar
    Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
    // Panneau bas + toggle toujours visibles
    Positioned(bottom: 0, left: 0, right: 0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Toggle — TOUJOURS visible
          Center(child: GestureDetector(
              onTap: _togglePanel,
              child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [BoxShadow(
                          color: _green.withOpacity(0.12),
                          blurRadius: 16, offset: const Offset(0, 4))],
                      border: Border.all(color: const Color(0xFFD8EDD4), width: 1.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_panelOpen
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                        color: _textSoft, size: 18),
                    const SizedBox(width: 5),
                    Text(_panelOpen ? 'Réduire' : 'Ouvrir',
                        style: GoogleFonts.nunito(fontSize: 12,
                            fontWeight: FontWeight.w700, color: _textSoft)),
                  ])))),
          // Panneau rétractable
          SizeTransition(
              sizeFactor: _panelAnim,
              axisAlignment: -1,
              child: _buildBottomPanel()),
        ])),
  ]);

  // ════════════════════════════════════════════════════
  //  CANVAS — Fond dégradé sage-crème
  // ════════════════════════════════════════════════════
  Widget _buildCanvas({required bool isDesktop}) {
    return Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bgTop, Color(0xFFF0EBE3)],
                stops: [0.0, 1.0])),
        child: Stack(children: [
          // Motif botanique très subtil
          Positioned.fill(child: CustomPaint(painter: _BotanicPainter())),

          // Cadre circulaire de scan
          Center(child: Transform.translate(
              offset: Offset(0, isDesktop ? -30 : -50),
              child: _buildLens(isDesktop))),

          // Contrôles desktop
          if (isDesktop)
            Positioned(bottom: 20, left: 0, right: 0,
                child: Center(child: _buildDesktopShutter())),
        ]));
  }

  // ════════════════════════════════════════════════════
  //  LENS — Cadre circulaire style loupe de précision
  // ════════════════════════════════════════════════════
  Widget _buildLens(bool isDesktop) {
    final d = isDesktop ? 290.0 : 268.0; // diamètre
    final r = d / 2;

    return SizedBox(width: d + 80, height: d + 80,
        child: Stack(alignment: Alignment.center, children: [

          // ── Cercle externe rotatif pointillé ─────────
          AnimatedBuilder(animation: _rotCtrl, builder: (_, __) =>
              Transform.rotate(
                  angle: _rotCtrl.value * 2 * math.pi,
                  child: SizedBox(width: d + 60, height: d + 60,
                      child: CustomPaint(painter: _DottedRing(
                          radius: r + 28,
                          color: _greenSoft.withOpacity(0.18),
                          dotCount: 48, dotSize: 2.5))))),

          // ── Cercle respirant ─────────────────────────
          AnimatedBuilder(animation: _breathCtrl, builder: (_, __) =>
              Container(
                  width: d + 20 + 6 * _breathCtrl.value,
                  height: d + 20 + 6 * _breathCtrl.value,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _greenSoft.withOpacity(
                              0.15 + 0.1 * _breathCtrl.value),
                          width: 1)))),

          // ── Cercle principal (le "verre" de la loupe) ─
          Container(width: d, height: d,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Simule un verre légèrement teinté
                  gradient: RadialGradient(
                      center: Alignment.center, radius: 1.0,
                      colors: [
                        const Color(0xFF1C3A1E).withOpacity(0.82),
                        const Color(0xFF0F2210).withOpacity(0.92)]),
                  border: Border.all(color: _frame.withOpacity(0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: _green.withOpacity(0.15),
                        blurRadius: 40, spreadRadius: 8),
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20, offset: const Offset(0, 8))])),

          // ── Lignes de grille légères à l'intérieur ───
          SizedBox(width: d, height: d,
              child: ClipOval(child: CustomPaint(
                  painter: _LensGridPainter()))),

          // ── 4 marqueurs de coin (style réticule) ────
          ..._cornerOffsets(r * 0.62).map((off) =>
              Transform.translate(
                  offset: off,
                  child: _Tick(angle: _tickAngle(off)))),

          // ── Ligne de scan ────────────────────────────
          AnimatedBuilder(animation: _scanCtrl, builder: (_, __) {
            final t = Curves.easeInOut.transform(_scanCtrl.value);
            // Mouvement vertical dans le cercle
            final innerR = r * 0.88;
            final yOffset = -innerR + 2 * innerR * t;
            // Largeur de la ligne à ce y (corde du cercle)
            final halfW = math.sqrt(
                math.max(0, innerR * innerR - yOffset * yOffset));
            return Transform.translate(
                offset: Offset(0, yOffset),
                child: Container(
                    width: halfW * 1.9,
                    height: 1.5,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.75),
                          Colors.white.withOpacity(0.4),
                          Colors.transparent]),
                        boxShadow: [BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 8, spreadRadius: 1)])));
          }),

          // ── Croix centrale ────────────────────────────
          // Horizontale
          Container(width: d * 0.25, height: 0.5,
              color: Colors.white.withOpacity(0.25)),
          // Verticale
          Container(width: 0.5, height: d * 0.25,
              color: Colors.white.withOpacity(0.25)),
          // Point central
          AnimatedBuilder(animation: _breathCtrl, builder: (_, __) =>
              Container(
                  width: 5 + 2 * _breathCtrl.value,
                  height: 5 + 2 * _breathCtrl.value,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.7 + 0.3 * _breathCtrl.value),
                      boxShadow: [BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8)]))),

          // ── Label au-dessus de la loupe ────────────────
          Positioned(top: 0,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(animation: _breathCtrl, builder: (_, __) =>
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _greenSoft.withOpacity(
                                0.5 + 0.5 * _breathCtrl.value)))),
                const SizedBox(width: 7),
                Text('ANALYSE EN COURS', style: GoogleFonts.nunito(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 2.5, color: _textSoft)),
              ])),

          // ── Hint sous la loupe ────────────────────────
          Positioned(bottom: 4,
              child: Text(_getHint(), style: GoogleFonts.nunitoSans(
                  fontSize: 11, color: _textSoft))),
        ]));
  }

  List<Offset> _cornerOffsets(double r) => [
    Offset(-r, -r), Offset(r, -r),
    Offset(-r, r),  Offset(r, r)];

  double _tickAngle(Offset o) {
    if (o.dx < 0 && o.dy < 0) return -math.pi * 0.75;
    if (o.dx > 0 && o.dy < 0) return -math.pi * 0.25;
    if (o.dx < 0 && o.dy > 0) return  math.pi * 0.75;
    return  math.pi * 0.25;
  }

  String _getHint() {
    switch (_mode) {
      case ScanMode.photo:      return 'Centrez la feuille · IA prête';
      case ScanMode.video:      return 'Filmez lentement le champ';
      case ScanMode.importFile: return 'Appuyez pour importer';
      case ScanMode.realtime:   return 'Analyse automatique continue';
    }
  }

  // ════════════════════════════════════════════════════
  //  TOP BAR — Fond transparent sur sage
  // ════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Padding(
        padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20, right: 20),
        child: Row(children: [
          // Logo
          RichText(text: TextSpan(
              style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w900),
              children: const [
                TextSpan(text: 'Agri',
                    style: TextStyle(color: _textDark)),
                TextSpan(text: 'Scan',
                    style: TextStyle(color: _greenSoft)),
              ])),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFD0E8CC))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(animation: _breathCtrl, builder: (_, __) =>
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                                _greenSoft,
                                const Color(0xFF4ADE80),
                                _breathCtrl.value)))),
                const SizedBox(width: 6),
                Text('IA Prête', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _green)),
              ])),
        ]));
  }

  // ════════════════════════════════════════════════════
  //  MODE BAR
  // ════════════════════════════════════════════════════
  Widget _buildModeBar() {
    final modes = [
      (ScanMode.photo,      Icons.camera_alt_rounded,  'Photo'),
      (ScanMode.video,      Icons.videocam_rounded,    'Vidéo'),
      (ScanMode.importFile, Icons.upload_file_rounded, 'Import'),
      (ScanMode.realtime,   Icons.bolt_rounded,        'Live'),
    ];
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0xFFD8EDD4), width: 1.5),
            boxShadow: [BoxShadow(
                color: _green.withOpacity(0.08),
                blurRadius: 16, offset: const Offset(0, 4))]),
        child: Row(mainAxisSize: MainAxisSize.min,
            children: modes.map((m) {
              final a = _mode == m.$1;
              return GestureDetector(
                  onTap: () => setState(() => _mode = m.$1),
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: a ? _green : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: a ? [BoxShadow(
                              color: _green.withOpacity(0.3),
                              blurRadius: 8)] : null),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(m.$2, size: 14,
                            color: a ? Colors.white : _textSoft),
                        const SizedBox(width: 5),
                        Text(m.$3, style: GoogleFonts.nunito(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: a ? Colors.white : _textSoft)),
                      ])));
            }).toList()));
  }

  // ════════════════════════════════════════════════════
  //  BOTTOM PANEL — Carte blanche flottante
  // ════════════════════════════════════════════════════
  Widget _buildBottomPanel() {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFFE0EDD9), width: 1.5),
            boxShadow: [BoxShadow(
                color: _green.withOpacity(0.08),
                blurRadius: 30, offset: const Offset(0, -8))]),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Mode bar
          _buildModeBar(),
          const SizedBox(height: 16),
          // Culture
          Row(children: [
            Text('Culture', style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: _textSoft)),
            const SizedBox(width: 12),
            _PlantChip(emoji: '🌽', label: 'Maïs',
                active: _plant == PlantType.maize,
                onTap: () => setState(() => _plant = PlantType.maize)),
            const SizedBox(width: 8),
            _PlantChip(emoji: '🍅', label: 'Tomate',
                active: _plant == PlantType.tomato,
                onTap: () => setState(() => _plant = PlantType.tomato)),
          ]),
          const SizedBox(height: 20),
          // Contrôles
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _LightAux(icon: Icons.history_rounded, label: 'Historique',
                onTap: () {}),
            _buildShutter(),
            _LightAux(
                icon: _mode == ScanMode.importFile
                    ? Icons.upload_file_rounded
                    : Icons.photo_library_rounded,
                label: _mode == ScanMode.importFile ? 'Importer' : 'Galerie',
                onTap: _handleAction),
          ]),
        ]));
  }

  // ════════════════════════════════════════════════════
  //  SHUTTER — Blanc sur fond blanc, effet 3D
  // ════════════════════════════════════════════════════
  Widget _buildShutter() {
    return GestureDetector(
        onTap: _handleAction,
        child: AnimatedBuilder(animation: _breathCtrl, builder: (_, __) =>
            Stack(alignment: Alignment.center, children: [
              // Halo vert pulsant
              Container(
                  width: 82 + 4 * _breathCtrl.value,
                  height: 82 + 4 * _breathCtrl.value,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _green.withOpacity(
                              0.12 + 0.08 * _breathCtrl.value), width: 1.5))),
              // Anneau intermédiaire
              Container(width: 70, height: 70,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _green.withOpacity(0.2), width: 1))),
              // Bouton principal
              Container(width: 60, height: 60,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green,
                      boxShadow: [
                        BoxShadow(
                            color: _green.withOpacity(
                                0.35 + 0.15 * _breathCtrl.value),
                            blurRadius: 20, spreadRadius: 2),
                        const BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 8, offset: Offset(0, 4))]),
                  child: Center(child: Icon(
                      _mode == ScanMode.photo ? Icons.camera_alt_rounded
                          : _mode == ScanMode.video ? Icons.videocam_rounded
                          : _mode == ScanMode.importFile ? Icons.upload_file_rounded
                          : Icons.bolt_rounded,
                      color: Colors.white, size: 26))),
            ])));
  }

  Widget _buildDesktopShutter() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _LightAux(icon: Icons.history_rounded, label: '', onTap: () {}),
      const SizedBox(width: 28),
      _buildShutter(),
      const SizedBox(width: 28),
      _LightAux(icon: Icons.photo_library_rounded, label: '',
          onTap: _handleAction),
    ]);
  }

  // ════════════════════════════════════════════════════
  //  DESKTOP PANEL
  // ════════════════════════════════════════════════════
  Widget _buildDesktopPanel() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Configuration', style: GoogleFonts.nunito(
              fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
          const SizedBox(height: 3),
          Text('Paramètres d\'analyse', style: GoogleFonts.nunitoSans(
              fontSize: 13, color: _textSoft)),
          const SizedBox(height: 24),

          _SectionLbl('MODE D\'ENTRÉE'),
          _buildDesktopModeGrid(),
          const SizedBox(height: 20),

          _SectionLbl('CULTURE À ANALYSER'),
          Row(children: [
            Expanded(child: _DPlantCard(emoji: '🌽', label: 'Maïs',
                sub: 'Zea mays',
                active: _plant == PlantType.maize,
                onTap: () => setState(() => _plant = PlantType.maize))),
            const SizedBox(width: 8),
            Expanded(child: _DPlantCard(emoji: '🍅', label: 'Tomate',
                sub: 'S. lycopersicum',
                active: _plant == PlantType.tomato,
                onTap: () => setState(() => _plant = PlantType.tomato))),
          ]),
          const SizedBox(height: 20),

          _SectionLbl('MODÈLE IA'),
          _buildModels(),
          const SizedBox(height: 28),

          SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
                onPressed: _handleAction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    shadowColor: _green.withOpacity(0.3)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_mode == ScanMode.photo ? Icons.camera_alt_rounded
                          : _mode == ScanMode.video ? Icons.videocam_rounded
                          : _mode == ScanMode.importFile ? Icons.upload_file_rounded
                          : Icons.bolt_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(_getLabel(), style: GoogleFonts.nunito(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                    ])),
          ),
        ]));
  }

  Widget _buildDesktopModeGrid() {
    final modes = [
      (ScanMode.photo,      Icons.camera_alt_rounded,  'Photo',  'Capture unique'),
      (ScanMode.video,      Icons.videocam_rounded,    'Vidéo',  'Enregistrement'),
      (ScanMode.importFile, Icons.upload_file_rounded, 'Import', 'Fichier local'),
      (ScanMode.realtime,   Icons.bolt_rounded,        'Live',   'Temps réel'),
    ];
    return Column(children: [
      Row(children: [
        Expanded(child: _DMCard(modes[0], _mode,
                (m) => setState(() => _mode = m))),
        const SizedBox(width: 8),
        Expanded(child: _DMCard(modes[1], _mode,
                (m) => setState(() => _mode = m))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _DMCard(modes[2], _mode,
                (m) => setState(() => _mode = m))),
        const SizedBox(width: 8),
        Expanded(child: _DMCard(modes[3], _mode,
                (m) => setState(() => _mode = m))),
      ]),
    ]);
  }

  Widget _buildModels() => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5)),
      child: Column(children: [
        _ModelRow('🧠', 'MobileViT', 'Précision max · Transformer', true),
        Divider(color: AppColors.border, height: 16),
        _ModelRow('⚡', 'ConvNeXt', 'Rapide · CNN moderne', false),
      ]));

  String _getLabel() {
    switch (_mode) {
      case ScanMode.photo:      return 'Capturer & Analyser';
      case ScanMode.video:      return 'Démarrer la vidéo';
      case ScanMode.importFile: return 'Importer';
      case ScanMode.realtime:   return 'Analyse Live';
    }
  }

  void _handleAction() async {
    // Vérifier les tokens
    final permission = await TokenService().checkPermission();
    if (!permission.allowed) { _showLimitDialog(); return; }

    // Récupérer l'image selon le mode
    File? imageFile;
    final picker = ImagePicker();

    try {
      XFile? picked;
      if (_mode == ScanMode.photo) {
        picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          preferredCameraDevice: CameraDevice.rear,
        );
      } else if (_mode == ScanMode.importFile) {
        picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
      } else {
        // Video / Realtime → on ouvre la caméra aussi pour l'instant
        picked = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
      }

      if (picked == null) return; // Annulé
      imageFile = File(picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur caméra : \$e'),
            backgroundColor: AppColors.red));
      }
      return;
    }

    // Sauvegarder le scan en BD
    final userId = await DatabaseService().getCurrentUserId();
    final scanId = await DatabaseService().saveScan(
      plantType  : _plant == PlantType.maize ? 'Maïs' : 'Tomate',
      diseaseName: 'En cours...',
      severity   : 'Inconnu',
      confidence : 0.0,
      modelUsed  : 'MobileViT',
      userId     : userId,
      imagePath  : imageFile.path,
    );

    // Naviguer vers l'analyse
    if (mounted) {
      Navigator.push(context, PageRouteBuilder(
          pageBuilder: (_, a, __) => AnalyzingScreen(
            imageFile : imageFile!,
            plantType : _plant,
            scanId    : scanId,
            isVideo   : _mode == ScanMode.video,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: CurvedAnimation(
                  parent: a, curve: Curves.easeOut), child: child),
          transitionDuration: const Duration(milliseconds: 350)));
    }
  }

  void _showLimitDialog() {
    showDialog(context: context, builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: AppColors.g50, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.g300, width: 1.5)),
                  child: const Center(
                      child: Text('🌿', style: TextStyle(fontSize: 30)))),
              const SizedBox(height: 16),
              Text('Limite atteinte', style: GoogleFonts.nunito(
                  fontSize: 20, fontWeight: FontWeight.w900, color: _textDark)),
              const SizedBox(height: 8),
              Text('Créez un compte gratuit\npour des analyses illimitées.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 14, color: _textSoft, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 48,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => LoginScreen()));
                      },
                      child: Text('Créer un compte', style: GoogleFonts.nunito(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: Colors.white)))),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Plus tard', style: GoogleFonts.nunito(
                      fontSize: 14, color: _textSoft))),
            ]))));
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS
// ══════════════════════════════════════════════════════════

// Marqueur de coin (tick)
class _Tick extends StatelessWidget {
  final double angle;
  const _Tick({required this.angle});
  @override
  Widget build(BuildContext context) => Transform.rotate(
      angle: angle,
      child: SizedBox(width: 16, height: 16,
          child: Stack(children: [
            // Trait horizontal
            Positioned(left: 0, right: 6, top: 0, height: 1.5,
                child: Container(color: Colors.white.withOpacity(0.7))),
            // Trait vertical
            Positioned(left: 0, top: 0, bottom: 6, width: 1.5,
                child: Container(color: Colors.white.withOpacity(0.7))),
            // Dot
            Container(width: 3, height: 3,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9))),
          ])));
}

// Grille intérieure de la loupe
class _LensGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
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

// Motif botanique de fond
class _BotanicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5E9E62).withOpacity(0.05)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    // Petits hexagones très discrets
    const step = 52.0;
    const r = 14.0;
    for (double x = 0; x < size.width + step; x += step * 1.5) {
      for (double y = 0; y < size.height + step; y += step) {
        final offset = (y / step % 2 == 0) ? 0.0 : step * 0.75;
        final cx = x + offset;
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = math.pi / 3 * i - math.pi / 6;
          final px = cx + r * math.cos(angle);
          final py = y + r * math.sin(angle);
          i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}

// Anneau de points
class _DottedRing extends CustomPainter {
  final double radius;
  final Color color;
  final int dotCount;
  final double dotSize;
  const _DottedRing({required this.radius, required this.color,
    required this.dotCount, required this.dotSize});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    for (int i = 0; i < dotCount; i++) {
      final angle = 2 * math.pi / dotCount * i;
      canvas.drawCircle(
          Offset(cx + radius * math.cos(angle),
              cy + radius * math.sin(angle)),
          dotSize, p);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _PlantChip extends StatelessWidget {
  final String emoji, label;
  final bool active;
  final VoidCallback onTap;
  const _PlantChip({required this.emoji, required this.label,
    required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: active ? AppColors.g50 : AppColors.surface2,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: active ? AppColors.g700 : AppColors.border, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? AppColors.g700 : AppColors.t2)),
          ])));
}

class _LightAux extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LightAux({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 50, height: 50,
            decoration: BoxDecoration(
                color: AppColors.surface2, shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5)),
            child: Icon(icon, color: AppColors.t2, size: 22)),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.nunito(fontSize: 10,
              fontWeight: FontWeight.w600, color: AppColors.t3)),
        ],
      ]));
}

class _DPlantCard extends StatelessWidget {
  final String emoji, label, sub;
  final bool active;
  final VoidCallback onTap;
  const _DPlantCard({required this.emoji, required this.label,
    required this.sub, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: active ? AppColors.g50 : AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: active ? AppColors.g700 : AppColors.border, width: 1.5)),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 5),
            Text(label, style: GoogleFonts.nunito(fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.g700 : AppColors.t1)),
            Text(sub, style: GoogleFonts.nunitoSans(fontSize: 9,
                color: AppColors.t4, fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis),
          ])));
}

class _DMCard extends StatelessWidget {
  final (ScanMode, IconData, String, String) data;
  final ScanMode current;
  final ValueChanged<ScanMode> onTap;
  const _DMCard(this.data, this.current, this.onTap);
  @override
  Widget build(BuildContext context) {
    final a = data.$1 == current;
    return GestureDetector(
        onTap: () => onTap(data.$1),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
                color: a ? AppColors.g50 : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: a ? AppColors.g700 : AppColors.border, width: 1.5)),
            child: Row(children: [
              Icon(data.$2, size: 17,
                  color: a ? AppColors.g700 : AppColors.t3),
              const SizedBox(width: 8),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, children: [
                Text(data.$3, style: GoogleFonts.nunito(fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: a ? AppColors.g700 : AppColors.t1),
                    overflow: TextOverflow.ellipsis),
                Text(data.$4, style: GoogleFonts.nunitoSans(fontSize: 10,
                    color: AppColors.t4), overflow: TextOverflow.ellipsis),
              ])),
            ])));
  }
}

class _ModelRow extends StatelessWidget {
  final String emoji, name, desc;
  final bool active;
  const _ModelRow(this.emoji, this.name, this.desc, this.active);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 10),
    Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: GoogleFonts.nunito(fontSize: 13,
          fontWeight: FontWeight.w700, color: AppColors.t1)),
      Text(desc, style: GoogleFonts.nunitoSans(fontSize: 11,
          color: AppColors.t3)),
    ])),
    if (active) Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.g50, borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.g300)),
        child: Text('Actif', style: GoogleFonts.nunito(fontSize: 11,
            fontWeight: FontWeight.w700, color: AppColors.g700))),
  ]);
}

class _SectionLbl extends StatelessWidget {
  final String text;
  const _SectionLbl(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5,
          color: AppColors.t4)));
}