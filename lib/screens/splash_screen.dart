import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'scanner_screen.dart';

// ═══════════════════════════════════════════════════════
// SPLASH / ACCUEIL SCREEN
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
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _contentSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut),
    );

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

  void _goToScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6ED),
      body: Stack(
        children: [
          // Background circles
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.g700.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 100, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.g700.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 220, left: 20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.amber.withOpacity(0.05),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  AnimatedBuilder(
                    animation: _logoCtrl,
                    builder: (_, child) => Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: child,
                      ),
                    ),
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: AppColors.g700,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.g700.withOpacity(0.3),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: AppColors.g700.withOpacity(0.1),
                            blurRadius: 0,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🌿', style: TextStyle(fontSize: 52)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // App name & tagline
                  AnimatedBuilder(
                    animation: _contentCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _contentSlide.value),
                      child: Opacity(opacity: _contentOpacity.value, child: child),
                    ),
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Agri',
                                style: GoogleFonts.nunito(
                                  fontSize: 38, fontWeight: FontWeight.w900,
                                  color: AppColors.g900,
                                  letterSpacing: -1,
                                ),
                              ),
                              TextSpan(
                                text: 'Scan',
                                style: GoogleFonts.nunito(
                                  fontSize: 38, fontWeight: FontWeight.w900,
                                  color: AppColors.g600,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Détectez les maladies\nde vos plantes en quelques secondes',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunitoSans(
                            fontSize: 16,
                            color: AppColors.t2,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Feature pills
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            _FeaturePill(icon: '📷', label: 'Scanner rapide'),
                            _FeaturePill(icon: '📶', label: 'Sans connexion'),
                            _FeaturePill(icon: '🌿', label: 'Traitement conseillé'),
                          ],
                        ),
                        const SizedBox(height: 36),
                        // CTA
                        SizedBox(
                          width: double.infinity,
                          height: 62,
                          child: ElevatedButton(
                            onPressed: _goToScanner,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.g700,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                              shadowColor: AppColors.g700.withOpacity(0.4),
                            ),
                            child: Text(
                              'Commencer à scanner →',
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Gratuit · Sans inscription · Fonctionne hors ligne',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 13, color: AppColors.t3,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // How it works
                        _HowItWorksCard(),
                        const SizedBox(height: 20),
                        Text(
                          'AgriScan v3.0 · Offline IA · WCAG AAA',
                          style: GoogleFonts.nunitoSans(
                            fontSize: 11, color: AppColors.t4,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
}

class _FeaturePill extends StatelessWidget {
  final String icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.g800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment ça marche ?',
            style: GoogleFonts.nunito(
              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.g900,
            ),
          ),
          const SizedBox(height: 14),
          const _HowStep(icon: '📷', text: 'Prenez une photo de la plante'),
          const SizedBox(height: 10),
          const _HowStep(icon: '🧠', text: "L'IA analyse automatiquement"),
          const SizedBox(height: 10),
          const _HowStep(icon: '💊', text: 'Recevez le traitement conseillé'),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final String icon;
  final String text;
  const _HowStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.g50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunitoSans(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.t2,
            ),
          ),
        ),
      ],
    );
  }
}
