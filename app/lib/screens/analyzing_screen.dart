import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'disease_result_screen.dart';

// ═══════════════════════════════════════════════════════
// ANALYZING SCREEN — AI Processing Animation
// ═══════════════════════════════════════════════════════

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with TickerProviderStateMixin {

  // Spinner controllers
  late AnimationController _spin1, _spin2, _spin3;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  late AnimationController _innerPulse;

  // Steps state
  final List<_StepState> _steps = [
    _StepState(label: "Préparation de l'image", emoji: '📸'),
    _StepState(label: 'Analyse intelligente',   emoji: '🧠'),
    _StepState(label: 'Identification de la maladie', emoji: '🔍'),
  ];
  String _statusMsg = 'Patientez quelques secondes…\nNe bougez pas votre téléphone';
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Spinners
    _spin1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
    _spin2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..repeat(reverse: false);
    _spin3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat();

    // Inner icon pulse
    _innerPulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Progress bar
    _progressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200),
    )..forward();
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut),
    );

    // Schedule step animations
    _scheduleSteps();
  }

  void _scheduleSteps() {
    // Step 1 — start
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _steps[0].status = _StepStatus.active;
        _statusMsg = 'Analyse de la texture des feuilles…';
      });
    });
    // Step 1 — done
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _steps[0].status = _StepStatus.done;
      });
    });
    // Step 2 — start
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _steps[1].status = _StepStatus.active;
        _statusMsg = "L'IA compare avec 50 000 images…";
      });
    });
    // Step 2 — done
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() {
        _steps[1].status = _StepStatus.done;
      });
    });
    // Step 3 — start
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      setState(() {
        _steps[2].status = _StepStatus.active;
        _statusMsg = 'Maladie identifiée ! Préparation du résultat…';
      });
    });
    // Step 3 — done
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() {
        _steps[2].status = _StepStatus.done;
        _statusMsg = 'Analyse terminée avec succès ✓';
      });
    });
    // Navigate to result
    _navTimer = Timer(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: const DiseaseResultScreen(),
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    });
  }

  @override
  void dispose() {
    _spin1.dispose(); _spin2.dispose(); _spin3.dispose();
    _innerPulse.dispose(); _progressCtrl.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  AppBackButton(onTap: () => Navigator.of(context).pop()),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Analyse en cours…',
                        style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: AppColors.g900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 46),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  children: [
                    // Spinner
                    SizedBox(
                      width: 168, height: 168,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring
                          AnimatedBuilder(
                            animation: _spin1,
                            builder: (_, __) => Transform.rotate(
                              angle: _spin1.value * 6.28,
                              child: Container(
                                width: 168, height: 168,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: CustomPaint(painter: _ArcPainter(AppColors.g700)),
                              ),
                            ),
                          ),
                          // Middle ring
                          AnimatedBuilder(
                            animation: _spin2,
                            builder: (_, __) => Transform.rotate(
                              angle: -_spin2.value * 6.28,
                              child: SizedBox(
                                width: 140, height: 140,
                                child: CustomPaint(
                                  painter: _ArcPainter(AppColors.g600.withOpacity(0.6)),
                                ),
                              ),
                            ),
                          ),
                          // Inner dashed ring
                          AnimatedBuilder(
                            animation: _spin3,
                            builder: (_, __) => Transform.rotate(
                              angle: _spin3.value * 6.28,
                              child: SizedBox(
                                width: 116, height: 116,
                                child: CustomPaint(
                                  painter: _DashedCirclePainter(
                                    AppColors.amber.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Inner icon
                          AnimatedBuilder(
                            animation: _innerPulse,
                            builder: (_, __) => Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.g700.withOpacity(
                                      0.1 + 0.12 * _innerPulse.value,
                                    ),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🔬', style: TextStyle(fontSize: 38)),
                              ),
                            ),
                          ),
                          // Detection dots
                          const Positioned(
                            top: 14, left: 60,
                            child: _DetectionDot(delay: Duration(milliseconds: 300)),
                          ),
                          const Positioned(
                            bottom: 26, right: 18,
                            child: _DetectionDot(delay: Duration(milliseconds: 800)),
                          ),
                          const Positioned(
                            bottom: 44, left: 20,
                            child: _DetectionDot(delay: Duration(milliseconds: 1200)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      "L'IA examine votre plante",
                      style: GoogleFonts.nunito(
                        fontSize: 24, fontWeight: FontWeight.w900,
                        color: AppColors.g900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusMsg,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 15, color: AppColors.t2, height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress bar
                    AnimatedBuilder(
                      animation: _progressCtrl,
                      builder: (_, __) => Column(
                        children: [
                          AppProgressBar(value: _progressAnim.value),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progression',
                                style: GoogleFonts.nunitoSans(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: AppColors.t3,
                                ),
                              ),
                              Text(
                                '${(_progressAnim.value * 100).round()}%',
                                style: GoogleFonts.nunito(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: AppColors.g700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Analysis steps
                    ..._steps.asMap().entries.map(
                      (e) => _AnalysisStep(step: e.value),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step state model ──────────────────────────────────────
enum _StepStatus { waiting, active, done }

class _StepState {
  final String label;
  final String emoji;
  _StepStatus status;

  _StepState({required this.label, required this.emoji, this.status = _StepStatus.waiting});
}

// ── Single analysis step widget ───────────────────────────
class _AnalysisStep extends StatelessWidget {
  final _StepState step;
  const _AnalysisStep({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final String displayEmoji;

    switch (step.status) {
      case _StepStatus.waiting:
        bgColor = AppColors.surface2;
        borderColor = AppColors.border;
        displayEmoji = step.emoji;
      case _StepStatus.active:
        bgColor = const Color(0xFFEAF5EB);
        borderColor = AppColors.g300;
        displayEmoji = '⚡';
      case _StepStatus.done:
        bgColor = AppColors.green2;
        borderColor = const Color(0xFFA8D9B0);
        displayEmoji = '✅';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Center(
              child: Text(displayEmoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: GoogleFonts.nunito(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.t1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.status == _StepStatus.waiting
                      ? 'En attente…'
                      : step.status == _StepStatus.active
                          ? 'En cours…'
                          : 'Terminé',
                  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3),
                ),
              ],
            ),
          ),
          if (step.status == _StepStatus.done)
            Text(
              '✓',
              style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.green,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Detection dot ─────────────────────────────────────────
class _DetectionDot extends StatefulWidget {
  final Duration delay;
  const _DetectionDot({required this.delay});

  @override
  State<_DetectionDot> createState() => _DetectionDotState();
}

class _DetectionDotState extends State<_DetectionDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(_ctrl);

    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward().then((_) {
        if (mounted) {
          _ctrl.repeat(reverse: true,
              period: const Duration(milliseconds: 900));
        }
      });
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(
              color: AppColors.g600,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.g600.withOpacity(0.4),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────
class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -1.57, 4.5, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  _DashedCirclePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashCount = 12;
    const gapAngle = 0.2;
    final dashAngle = (6.28 / dashCount) - gapAngle;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (6.28 / dashCount);
      canvas.drawArc(
        Rect.fromLTWH(0, 0, size.width, size.height),
        startAngle, dashAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
