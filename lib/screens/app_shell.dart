import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'scanner_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'disease_result_screen.dart';
import 'field_map_screen.dart';
import 'drone_simulation_screen.dart';
import 'recommendations_screen.dart';
import 'marketplace_screen.dart';
import 'marketplace_orders_screen.dart';
import 'video_analysis_screen.dart';
import 'chat_screen.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late int _index;
  bool _drawerOpen = false;
  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;

  final _screens = const [
    ScannerScreen(),
    HistoryScreen(),
    MarketplaceScreen(),   // index 2 — Boutique
    ProfileScreen(),       // index 3
  ];

  static const _navItems = [
    _NavDef('📷', 'Scanner',    'Analyser une plante',  0),
    _NavDef('📊', 'Historique', 'Mes analyses',         1),
    _NavDef('🛒', 'Boutique',   'Produits & commandes', 2),
    _NavDef('👤', 'Profil',     'Mon compte',           3),
  ];

  static const _extraItems = [
    _NavDef('🔬', 'Résultat',        'Dernier diagnostic',   -1),
    _NavDef('🗺️', 'Carte champ',     'Zones infectées',      -2),
    _NavDef('🚁', 'Simulation',      'Traitement drone',     -3),
    _NavDef('💊', 'Recommandations', 'Dosage & traitement',  -4),
    _NavDef('📦', 'Mes commandes',   'Historique boutique',  -5),
    _NavDef('🎥', 'Analyse vidéo',   'Simulation drone IA',  -6),
    _NavDef('💬', 'Assistant chat',  'Agronome IA (RAG)',    -7),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _drawerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _drawerAnim = CurvedAnimation(
        parent: _drawerCtrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _toggleDrawer() {
    if (_drawerOpen) {
      _drawerCtrl.reverse().then((_) {
        if (mounted) setState(() => _drawerOpen = false);
      });
    } else {
      setState(() => _drawerOpen = true);
      _drawerCtrl.forward();
    }
  }

  void _selectIndex(int i) {
    _toggleDrawer();
    if (i >= 0) {
      setState(() => _index = i);
      return;
    }
    // Écrans spéciaux — TOUS connectés
    Widget target;
    switch (i) {
      case -1: target = const DiseaseResultScreen();    break;
      case -2: target = const FieldMapScreen();         break;
      case -3: target = const DroneSimulationScreen();  break;
      case -4: target = const RecommendationsScreen();  break;
      case -5: target = const MarketplaceOrdersScreen(); break;
      case -6: target = const VideoAnalysisScreen();    break;
      case -7: target = const ChatScreen();             break;
      default: return;
    }
    Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, a, __) => target,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: child),
        transitionDuration: const Duration(milliseconds: 300)));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 900;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Column(children: [
          _TopBar(
              index: _index, onMenuTap: _toggleDrawer,
              navItems: _navItems, isDesktop: isDesktop,
              onTabSelect: (i) => setState(() => _index = i)),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
          if (!isDesktop)
            _BottomBar(
                index: _index, navItems: _navItems,
                onSelect: (i) => setState(() => _index = i)),
        ]),
        if (_drawerOpen)
          Positioned.fill(child: GestureDetector(
              onTap: _toggleDrawer,
              child: FadeTransition(opacity: _drawerAnim,
                  child: Container(color: Colors.black.withOpacity(0.35))))),
        if (_drawerOpen)
          Positioned(top: 0, bottom: 0, left: 0,
              child: SlideTransition(
                  position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
                      .animate(_drawerAnim),
                  child: _SideDrawer(
                      index: _index, navItems: _navItems,
                      extraItems: _extraItems,
                      onSelect: _selectIndex, onClose: _toggleDrawer))),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int index;
  final VoidCallback onMenuTap;
  final List<_NavDef> navItems;
  final bool isDesktop;
  final ValueChanged<int> onTabSelect;
  const _TopBar({required this.index, required this.onMenuTap,
    required this.navItems, required this.isDesktop, required this.onTabSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5))),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: SizedBox(height: 60, child: Row(children: [
        const SizedBox(width: 8),
        _MenuBtn(onTap: onMenuTap),
        const SizedBox(width: 16),
        RichText(text: TextSpan(
            style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900),
            children: [
              const TextSpan(text: 'Agri',
                  style: TextStyle(color: Color(0xFF1A3D1C))),
              TextSpan(text: 'Scan',
                  style: TextStyle(color: AppColors.g600)),
            ])),
        const SizedBox(width: 10),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.g50,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.g300)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: AppColors.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('IA prête', style: GoogleFonts.nunito(fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppColors.green)),
            ])),
        const Spacer(),
        if (isDesktop)
          ...navItems.map((item) {
            final active = item.index == index;
            return GestureDetector(
                onTap: () => onTabSelect(item.index),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: active ? AppColors.g50 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: active ? AppColors.g300 : Colors.transparent, width: 1.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(item.label, style: GoogleFonts.nunito(fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.g700 : AppColors.t2)),
                    ])));
          }).toList(),
        if (isDesktop) const SizedBox(width: 12),
        Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: GestureDetector(
                onTap: () => onTabSelect(3),
                child: Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.g700,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('IB', style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: Colors.white)))))),
      ])),
    );
  }
}

class _MenuBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.5)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Bar(14), const SizedBox(height: 4),
            _Bar(10), const SizedBox(height: 4),
            _Bar(14),
          ])));
}

class _Bar extends StatelessWidget {
  final double width;
  const _Bar(this.width);
  @override
  Widget build(BuildContext context) => Container(width: width, height: 2,
      decoration: BoxDecoration(color: AppColors.t2,
          borderRadius: BorderRadius.circular(2)));
}

class _SideDrawer extends StatelessWidget {
  final int index;
  final List<_NavDef> navItems;
  final List<_NavDef> extraItems;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  const _SideDrawer({required this.index, required this.navItems,
    required this.extraItems, required this.onSelect, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 280, height: double.infinity,
        decoration: const BoxDecoration(color: AppColors.surface,
            boxShadow: [BoxShadow(color: Color(0x201E461E),
                blurRadius: 32, offset: Offset(8, 0))]),
        child: SafeArea(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête fixe ────────────────────────────
              Padding(padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.g700,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppShadows.green),
                        child: const Center(child: Text('🌿',
                            style: TextStyle(fontSize: 22)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RichText(text: TextSpan(
                          style: GoogleFonts.nunito(fontSize: 18,
                              fontWeight: FontWeight.w900),
                          children: [
                            const TextSpan(text: 'Agri',
                                style: TextStyle(color: Color(0xFF1A3D1C))),
                            TextSpan(text: 'Scan',
                                style: TextStyle(color: AppColors.g600)),
                          ])),
                      Text('Ibrahim Benali', style: GoogleFonts.nunitoSans(
                          fontSize: 12, color: AppColors.t3)),
                    ])),
                    GestureDetector(onTap: onClose,
                        child: Container(width: 32, height: 32,
                            decoration: BoxDecoration(color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border)),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppColors.t3))),
                  ])),
              const Divider(color: AppColors.border, height: 1),

              // ── Liste scrollable ─────────────────────────
              Expanded(child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _DrawerSection('NAVIGATION'),
                        ...navItems.map((item) => _DrawerItem(
                            item: item, active: item.index == index,
                            onTap: () => onSelect(item.index))),
                        const SizedBox(height: 8),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 8),
                        _DrawerSection('ANALYSES & OUTILS'),
                        ...extraItems.map((item) => _DrawerItem(
                            item: item, active: false,
                            onTap: () => onSelect(item.index))),
                        const SizedBox(height: 16),
                      ]))),

              // ── Pied fixe ────────────────────────────────
              const Divider(color: AppColors.border, height: 1),
              Padding(padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('IA offline · v4.0', style: GoogleFonts.nunitoSans(
                        fontSize: 12, color: AppColors.t3)),
                  ])),
            ])));
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  const _DrawerSection(this.title);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Text(title, style: GoogleFonts.nunito(fontSize: 10,
          fontWeight: FontWeight.w700, color: AppColors.t4, letterSpacing: 1.5)));
}

class _DrawerItem extends StatelessWidget {
  final _NavDef item; final bool active; final VoidCallback onTap;
  const _DrawerItem({required this.item, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: active ? AppColors.g50 : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: active ? AppColors.g300 : Colors.transparent)),
          child: Row(children: [
            Container(width: 34, height: 34,
                decoration: BoxDecoration(
                    color: active ? AppColors.g700 : AppColors.surface2,
                    borderRadius: BorderRadius.circular(9)),
                child: Center(child: Text(item.emoji,
                    style: const TextStyle(fontSize: 16)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
              Text(item.label, style: GoogleFonts.nunito(fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.g700 : AppColors.t1)),
              Text(item.subtitle, style: GoogleFonts.nunitoSans(
                  fontSize: 11, color: AppColors.t3)),
            ])),
            if (active) Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: AppColors.g600, shape: BoxShape.circle)),
          ])));
}

class _BottomBar extends StatelessWidget {
  final int index;
  final List<_NavDef> navItems;
  final ValueChanged<int> onSelect;
  const _BottomBar({
    required this.index,
    required this.navItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
              top: BorderSide(color: Color(0xFFEAF0E7), width: 1.5)),
          boxShadow: [BoxShadow(
              color: const Color(0xFF2D6530).withOpacity(0.07),
              blurRadius: 20, offset: const Offset(0, -4))]),
      child: Row(children: [
        // Scanner
        Expanded(child: _BotItem(
            icon: Icons.document_scanner_rounded,
            label: 'Scanner',
            active: 0 == index,
            onTap: () => onSelect(0))),
        // Boutique
        Expanded(child: _BotItem(
            icon: Icons.storefront_rounded,
            label: 'Boutique',
            active: 2 == index,
            onTap: () => onSelect(2))),
        // Bouton central surélevé
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
                onTap: () => onSelect(0),
                child: Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                        color: AppColors.g700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(
                            color: AppColors.g700.withOpacity(0.35),
                            blurRadius: 16, spreadRadius: 2,
                            offset: const Offset(0, 4))]),
                    child: const Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.white, size: 24)))),
        // Historique
        Expanded(child: _BotItem(
            icon: Icons.timeline_rounded,
            label: 'Historique',
            active: 1 == index,
            onTap: () => onSelect(1))),
        // Profil
        Expanded(child: _BotItem(
            icon: Icons.person_outline_rounded,
            label: 'Profil',
            active: 3 == index,
            onTap: () => onSelect(3))),
      ]),
    );
  }
}

class _BotItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _BotItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 36,
              decoration: BoxDecoration(
                  color: active ? AppColors.g50 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22,
                  color: active ? AppColors.g700 : AppColors.t3)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: active ? AppColors.g700 : AppColors.t3)),
          const SizedBox(height: 3),
          AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 18 : 0, height: 3,
              decoration: BoxDecoration(
                  color: AppColors.g700,
                  borderRadius: BorderRadius.circular(100))),
        ]));
  }
}


class _NavDef {
  final String emoji, label, subtitle; final int index;
  const _NavDef(this.emoji, this.label, this.subtitle, this.index);
}