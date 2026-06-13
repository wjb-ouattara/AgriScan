import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'app_shell.dart';

// ═══════════════════════════════════════════════════════
// SPLASH SCREEN — V4 CORRIGÉ
// ═══════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _contentSlide;
  late Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut));
    _contentSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Navigation vers login ──────────────────────────────
  void _goToLogin() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, a, __) => const LoginScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  // ── Continuer sans compte ─────────────────────────────
  void _skipLogin() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, a, __) => const AppShell(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6ED),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Desktop ───────────────────────────────────────────
  Widget _buildDesktop() {
    return Row(children: [
      // Panneau gauche vert
      Expanded(
        flex: 5,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A3D1C), Color(0xFF2D6530)],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _DotPainter())),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(60),
                child: AnimatedBuilder(
                  animation: _contentCtrl,
                  builder: (_, child) =>
                      Opacity(opacity: _contentOpacity.value, child: child),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: const Center(
                            child: Text('🌿',
                                style: TextStyle(fontSize: 40))),
                      ),
                      const SizedBox(height: 32),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(fontSize: 52,
                              fontWeight: FontWeight.w900, letterSpacing: -2),
                          children: const [
                            TextSpan(text: 'Agri',
                                style: TextStyle(color: Colors.white)),
                            TextSpan(text: 'Scan',
                                style:
                                TextStyle(color: Color(0xFFA8D580))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Protégez vos cultures\npar l\'intelligence artificielle',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 20,
                          color: Colors.white.withOpacity(0.75),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 48),
                      ...[
                        ('📷', 'Détection par photo ou vidéo'),
                        ('🗺️', 'Carte du champ en temps réel'),
                        ('🚁', 'Simulation traitement drone'),
                        ('📶', 'Fonctionne hors ligne'),
                      ].map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: Text(e.$1,
                                style: const TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 14),
                          Text(e.$2, style: GoogleFonts.nunitoSans(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.85),
                          )),
                        ]),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
      // Panneau droit
      Expanded(
        flex: 4,
        child: Container(
          color: AppColors.bg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: _buildContent(isDesktop: true),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Mobile ────────────────────────────────────────────
  Widget _buildMobile() {
    return Stack(children: [
      Positioned(top: -80, right: -60,
          child: Container(width: 280, height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.g700.withOpacity(0.07)))),
      Positioned(bottom: 80, left: -50,
          child: Container(width: 180, height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.g700.withOpacity(0.06)))),
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _buildContent(isDesktop: false),
        ),
      ),
    ]);
  }

  Widget _buildContent({required bool isDesktop}) {
    return AnimatedBuilder(
      animation: _contentCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _contentSlide.value),
        child: Opacity(opacity: _contentOpacity.value, child: child),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo mobile uniquement
          if (!isDesktop) ...[
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, child) => Transform.scale(
                scale: _logoScale.value,
                child: Opacity(opacity: _logoOpacity.value, child: child),
              ),
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: AppColors.g700,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.green,
                ),
                child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 48))),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Titre
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.nunito(
                  fontSize: isDesktop ? 36 : 32,
                  fontWeight: FontWeight.w900, letterSpacing: -1),
              children: [
                const TextSpan(text: 'Agri',
                    style: TextStyle(color: Color(0xFF1A3D1C))),
                TextSpan(text: 'Scan',
                    style: TextStyle(color: AppColors.g600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Détectez les maladies de vos plantes\nen quelques secondes',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(
                fontSize: 15, color: AppColors.t2, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Badges
          Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: const [
              _Pill(icon: '📷', label: 'Photo & Vidéo'),
              _Pill(icon: '📶', label: 'Hors ligne'),
              _Pill(icon: '🌿', label: 'Traitement IA'),
            ],
          ),
          const SizedBox(height: 32),

          // Bouton principal — TAILLE ADAPTÉE AU CONTENU
          ElevatedButton(
            onPressed: _goToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.g700,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              shadowColor: AppColors.g700.withOpacity(0.4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Commencer', style: GoogleFonts.nunito(
                    fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lien sans compte
          GestureDetector(
            onTap: _skipLogin,
            child: Text(
              'Continuer sans compte →',
              style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.t3,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.t4,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // How it works
          _HowCard(),
          const SizedBox(height: 20),
          Text('AgriScan v4.0 · IA offline · WCAG AA',
              style: GoogleFonts.nunitoSans(
                  fontSize: 11, color: AppColors.t4, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────

class _Pill extends StatelessWidget {
  final String icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(100),
      border: Border.all(color: AppColors.border, width: 1.5),
      boxShadow: AppShadows.sm,
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: AppColors.g800)),
    ]),
  );
}

class _HowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comment ça marche ?', style: GoogleFonts.nunito(
            fontSize: 15, fontWeight: FontWeight.w800,
            color: AppColors.g900)),
        const SizedBox(height: 14),
        ...[
          ('📷', 'Prenez une photo ou une vidéo'),
          ('🧠', 'L\'IA analyse les symptômes'),
          ('💊', 'Recevez le traitement conseillé'),
        ].map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: AppColors.g50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border)),
              child: Center(child: Text(e.$1,
                  style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(e.$2, style: GoogleFonts.nunitoSans(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.t2))),
          ]),
        )),
      ],
    ),
  );
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, p);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}
