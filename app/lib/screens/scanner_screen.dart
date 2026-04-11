import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'analyzing_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

// ═══════════════════════════════════════════════════════
// MAIN SHELL — Bottom Navigation
// ═══════════════════════════════════════════════════════

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // Scanner is center/default

  final List<Widget> _pages = const [
    HistoryScreen(),
    ScannerScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E461E).withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: '📊', label: 'Historique',
              isActive: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            // Center scanner button
            GestureDetector(
              onTap: () => onTap(1),
              child: Container(
                width: 68, height: 68,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.g700,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.g700.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.g700.withOpacity(0.1),
                      blurRadius: 0,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('📷', style: TextStyle(fontSize: 28)),
                ),
              ),
            ),
            _NavItem(
              icon: '👤', label: 'Profil',
              isActive: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.g700 : AppColors.t2,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 5 : 0,
                height: isActive ? 5 : 0,
                decoration: const BoxDecoration(
                  color: AppColors.g600,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SCANNER SCREEN
// ═══════════════════════════════════════════════════════

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  int _selectedMode = 0; // 0=Maladie, 1=Herbes, 2=Tout
  final List<String> _modes = ['🦠 Maladie', '🌱 Herbes', '⚡ Tout'];

  late AnimationController _scanLineCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _scanLineAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // Scan line animation
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut),
    );

    // Pulse animation for reticle ring
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Set status bar transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onShutterPressed() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const AnalyzingScreen(),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2A1C),
      body: Stack(
        children: [
          // ── Background: simulated camera viewfinder ──
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.2,
                colors: [Color(0xFF1E3820), Color(0xFF0F1F10)],
              ),
            ),
          ),

          // Foliage hint at bottom
          Positioned(
            bottom: 0, left: -20, right: -20,
            child: Opacity(
              opacity: 0.12,
              child: Text(
                '🌿🌾🍃🌱🌿🍃',
                style: const TextStyle(fontSize: 80, height: 1),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Light flare top-right
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFF0B4).withOpacity(0.06),
              ),
            ),
          ),

          // ── Top bar ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 20, right: 20, bottom: 14,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Agri',
                          style: GoogleFonts.nunito(
                            fontSize: 20, fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(
                          text: 'Scan',
                          style: GoogleFonts.nunito(
                            fontSize: 20, fontWeight: FontWeight.w900,
                            color: const Color(0xFFA8D580),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                    ),
                    child: const Center(child: Text('⚡', style: TextStyle(fontSize: 20))),
                  ),
                ],
              ),
            ),
          ),

          // ── Mode selector ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 0, right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _modes.asMap().entries.map((e) {
                    final isActive = _selectedMode == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMode = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: isActive
                              ? [BoxShadow(color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8, offset: const Offset(0, 2))]
                              : [],
                        ),
                        child: Text(
                          e.value,
                          style: GoogleFonts.nunito(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: isActive ? AppColors.g800 : Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // ── Reticle frame (center) ──
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.18),
              child: SizedBox(
                width: 230, height: 230,
                child: Stack(
                  children: [
                    // Corner brackets
                    ..._buildCorners(),
                    // Pulse ring
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Center(
                        child: Transform.scale(
                          scale: _pulseAnim.value,
                          child: Container(
                            width: 180, height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Center dot
                    const Center(
                      child: _CenterDot(),
                    ),
                    // Scan line
                    AnimatedBuilder(
                      animation: _scanLineCtrl,
                      builder: (_, __) {
                        final t = _scanLineAnim.value;
                        final opacity = t < 0.08
                            ? t / 0.08
                            : t > 0.92
                                ? (1 - t) / 0.08
                                : 1.0;
                        return Positioned(
                          top: 3 + (224 * t),
                          left: 3, right: 3,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Colors.transparent,
                                  Color(0xFFA8D580),
                                  Colors.transparent,
                                ]),
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFA8D580).withOpacity(0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Hint text ──
          Positioned(
            bottom: 170,
            left: 0, right: 0,
            child: Text(
              'Centrez la plante dans le cadre',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ),

          // ── Bottom controls panel ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.97),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: AppColors.g700.withOpacity(0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                28, 20, 28,
                20 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ScanAuxButton(
                        emoji: '🕘', label: 'Historique',
                        onTap: () {
                          // Navigate to history tab in parent
                        },
                      ),
                      _ShutterButton(onTap: _onShutterPressed),
                      _ScanAuxButton(
                        emoji: '🖼️', label: 'Galerie',
                        onTap: () {
                          // Open image picker
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Appuyez sur le bouton vert pour analyser',
                    style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.t3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    return [
      // TL
      Positioned(top: 0, left: 0, child: _Corner(isTop: true, isLeft: true)),
      // TR
      Positioned(top: 0, right: 0, child: _Corner(isTop: true, isLeft: false)),
      // BL
      Positioned(bottom: 0, left: 0, child: _Corner(isTop: false, isLeft: true)),
      // BR
      Positioned(bottom: 0, right: 0, child: _Corner(isTop: false, isLeft: false)),
    ];
  }
}

class _Corner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;
  const _Corner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          left: isLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: (isTop && isLeft) ? const Radius.circular(6) : Radius.zero,
          topRight: (isTop && !isLeft) ? const Radius.circular(6) : Radius.zero,
          bottomLeft: (!isTop && isLeft) ? const Radius.circular(6) : Radius.zero,
          bottomRight: (!isTop && !isLeft) ? const Radius.circular(6) : Radius.zero,
        ),
      ),
    );
  }
}

class _CenterDot extends StatelessWidget {
  const _CenterDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 0,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _ScanAuxButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _ScanAuxButton({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.t2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring animation
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.g300, width: 2),
            ),
          ),
          // Main shutter button
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.g700,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.g700.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text('📷', style: TextStyle(fontSize: 30)),
            ),
          ),
        ],
      ),
    );
  }
}
