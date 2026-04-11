import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';
import '../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════
// DISEASE RESULT SCREEN
// ═══════════════════════════════════════════════════════

class DiseaseResultScreen extends StatefulWidget {
  final DiseaseResult? result;
  const DiseaseResultScreen({super.key, this.result});

  @override
  State<DiseaseResultScreen> createState() => _DiseaseResultScreenState();
}

class _DiseaseResultScreenState extends State<DiseaseResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late DiseaseResult _result;

  @override
  void initState() {
    super.initState();
    _result = widget.result ?? DiseaseResult.demo;
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _animated(Widget child, double delayFraction) {
    final begin = delayFraction;
    final end = (delayFraction + 0.4).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, __) {
        final t = (((_animCtrl.value - begin) / (end - begin)).clamp(0.0, 1.0));
        final curve = Curves.easeOut.transform(t);
        return Opacity(
          opacity: curve,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - curve)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero ──
          SliverToBoxAdapter(child: _buildHero(context)),
          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Disease name
                _animated(
                  Text(
                    _result.name,
                    style: GoogleFonts.nunito(
                      fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.g900,
                    ),
                  ), 0.0,
                ),
                const SizedBox(height: 4),
                _animated(
                  Text(
                    '${_result.scientificName} · ${_result.plantName}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13, color: AppColors.t3, fontStyle: FontStyle.italic,
                    ),
                  ), 0.05,
                ),
                const SizedBox(height: 16),
                // Metrics
                _animated(_buildMetrics(), 0.1),
                const SizedBox(height: 14),
                // Info chips
                _animated(_buildInfoChips(), 0.15),
                const SizedBox(height: 18),
                // Treatment
                _animated(_buildTreatment(), 0.2),
                const SizedBox(height: 14),
                // Actions
                _animated(_buildActions(context), 0.3),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3820), Color(0xFF152815)],
              ),
            ),
          ),
          // Foliage background
          const Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.1,
                child: Text('🌿', style: TextStyle(fontSize: 200)),
              ),
            ),
          ),
          // Heat map overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, 0),
                  radius: 0.7,
                  colors: [Color(0x4DFF5A1E), Colors.transparent],
                ),
              ),
            ),
          ),
          // Grid overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: GridPaper(
                color: Colors.white,
                divisions: 1,
                subdivisions: 1,
                interval: 24,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Bounding box
          Positioned(
            top: 72, left: 100,
            child: Container(
              width: 160, height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xDCFFB428), width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xCCE8920A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚠ Zone infectée',
                      style: GoogleFonts.nunito(
                        fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top controls
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
                  colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppBackButton(
                    onTap: () => Navigator.of(context).pop(),
                    color: Colors.white.withOpacity(0.18),
                    iconColor: Colors.white,
                  ),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Center(child: Text('📤', style: TextStyle(fontSize: 18))),
                  ),
                ],
              ),
            ),
          ),
          // Bottom chips
          Positioned(
            bottom: 14, left: 20,
            child: Row(
              children: [
                _HeroChip(label: '⚠️ Maladie détectée', isWarning: true),
                const SizedBox(width: 8),
                _HeroChip(
                  label: 'Confiance ${_result.confidence.toStringAsFixed(0)}%',
                  isWarning: false,
                ),
              ],
            ),
          ),
          // Bottom fade
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.bg],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        Expanded(
          child: SurfaceCard(
            padding: const EdgeInsets.all(14),
            radius: AppRadius.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CERTITUDE IA',
                  style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.t3, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_result.confidence.toStringAsFixed(0)}%',
                  style: GoogleFonts.nunito(
                    fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Très fiable',
                  style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SurfaceCard(
            padding: const EdgeInsets.all(14),
            radius: AppRadius.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GRAVITÉ',
                  style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.t3, letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _result.severityLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.amber,
                  ),
                ),
                const SizedBox(height: 8),
                AppProgressBar(
                  value: _result.severityRatio,
                  color: AppColors.amber,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChips() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        AppChip(label: '🦠 ${_result.type}', variant: ChipVariant.amber),
        AppChip(label: '⏰ Urgent: ${_result.urgency}', variant: ChipVariant.red),
        AppChip(label: '💧 ${_result.cause}', variant: ChipVariant.sage),
      ],
    );
  }

  Widget _buildTreatment() {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'Que faire maintenant ?',
                style: GoogleFonts.nunito(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.g900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._result.treatments.asMap().entries.map(
            (e) => _TreatStepWidget(step: e.value, isLast: e.key == _result.treatments.length - 1),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        PrimaryButton(
          label: '✅ Sauvegarder le résultat',
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: '🗺️ Carte',
                onTap: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                label: '👨‍🌾 Expert',
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final bool isWarning;
  const _HeroChip({required this.label, required this.isWarning});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: BackdropFilter(
        filter: const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isWarning
                ? const Color(0xD9E8920A)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _TreatStepWidget extends StatelessWidget {
  final TreatmentStep step;
  final bool isLast;
  const _TreatStepWidget({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.g700,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step.number.toString(),
                    style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(
                      step.title,
                      style: GoogleFonts.nunito(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 14, color: AppColors.t2, height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.surface2, thickness: 1.5),
          ],
        ],
      ),
    );
  }
}
