import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/scan_result.dart';
import '../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════
// WEEDS RESULT SCREEN
// ═══════════════════════════════════════════════════════

class WeedsResultScreen extends StatefulWidget {
  final WeedResult? result;
  const WeedsResultScreen({super.key, this.result});

  @override
  State<WeedsResultScreen> createState() => _WeedsResultScreenState();
}

class _WeedsResultScreenState extends State<WeedsResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late WeedResult _result;

  @override
  void initState() {
    super.initState();
    _result = widget.result ?? WeedResult.demo;
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Widget _animated(Widget child, double delay) {
    final end = (delay + 0.4).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (_, __) {
        final t = ((_animCtrl.value - delay) / (end - delay)).clamp(0.0, 1.0);
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
          SliverToBoxAdapter(child: _buildMapHero(context)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _animated(_buildRiskBlock(), 0.0),
                const SizedBox(height: 14),
                _animated(const SectionLabel('Herbes identifiées'), 0.1),
                ..._result.species.asMap().entries.map(
                  (e) => _animated(
                    _WeedSpeciesCard(species: e.value),
                    0.1 + e.key * 0.06,
                  ),
                ),
                const SizedBox(height: 14),
                _animated(
                  PrimaryButton(
                    label: '🗓️ Planifier le désherbage',
                    onTap: () {},
                  ),
                  0.35,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapHero(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F1E10), Color(0xFF18291A)],
              ),
            ),
          ),
          // Foliage bg
          const Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.07,
                child: Text('🌾', style: TextStyle(fontSize: 220)),
              ),
            ),
          ),
          // Grid overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: GridPaper(
                color: const Color(0xFFA8D580),
                interval: 22,
                divisions: 1,
                subdivisions: 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Simulated bounding boxes
          const Positioned(
            top: 84, left: 28,
            child: _WeedBBox(
              label: 'Chiendent', confidence: '91%',
              width: 82, height: 68, borderColor: AppColors.red,
              bgColor: Color(0xD9C0321A),
            ),
          ),
          const Positioned(
            top: 96, left: 148,
            child: _WeedBBox(
              label: 'Chardon', confidence: '87%',
              width: 74, height: 62, borderColor: AppColors.amber,
              bgColor: Color(0xD9E8920A),
            ),
          ),
          const Positioned(
            top: 86, left: 246,
            child: _WeedBBox(
              label: 'Liseron', confidence: '79%',
              width: 70, height: 72, borderColor: AppColors.g600,
              bgColor: Color(0xD92A5C2D),
            ),
          ),
          // Top bar
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
                children: [
                  AppBackButton(
                    onTap: () => Navigator.of(context).pop(),
                    color: Colors.white.withOpacity(0.18),
                    iconColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mauvaises herbes',
                    style: GoogleFonts.nunito(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  AppChip(
                    label: '${_result.totalCount} trouvées',
                    variant: ChipVariant.red,
                    fontSize: 11,
                  ),
                ],
              ),
            ),
          ),
          // Bottom fade
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 60,
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

  Widget _buildRiskBlock() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.red3, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withOpacity(0.1),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚨 Risque de perte de récolte',
                    style: GoogleFonts.nunito(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.t1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Densité critique sur ${_result.affectedArea}',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 13, color: AppColors.t3,
                    ),
                  ),
                ],
              ),
              Text(
                '${_result.riskPercent.toStringAsFixed(0)}%',
                style: GoogleFonts.nunito(
                  fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.red,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppProgressBar(
            value: _result.riskPercent / 100,
            color: AppColors.red,
          ),
          const SizedBox(height: 10),
          Text(
            'Agissez dans les 72 heures pour protéger votre récolte et réduire les pertes.',
            style: GoogleFonts.nunitoSans(
              fontSize: 14, color: AppColors.t2, height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weed bounding box simulation ──────────────────────────
class _WeedBBox extends StatelessWidget {
  final String label;
  final String confidence;
  final double width;
  final double height;
  final Color borderColor;
  final Color bgColor;

  const _WeedBBox({
    required this.label,
    required this.confidence,
    required this.width,
    required this.height,
    required this.borderColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width, height: height,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          Positioned(
            top: -20, left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                confidence,
                style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Species card ──────────────────────────────────────────
class _WeedSpeciesCard extends StatelessWidget {
  final WeedSpecies species;
  const _WeedSpeciesCard({required this.species});

  Color get _barColor {
    switch (species.dangerLevel.toLowerCase()) {
      case 'élevé': return AppColors.red;
      case 'modéré': return AppColors.amber;
      default: return AppColors.g500;
    }
  }

  ChipVariant get _chipVariant {
    switch (species.dangerLevel.toLowerCase()) {
      case 'élevé': return ChipVariant.red;
      case 'modéré': return ChipVariant.amber;
      default: return ChipVariant.sage;
    }
  }

  String get _dangerEmoji {
    switch (species.dangerLevel.toLowerCase()) {
      case 'élevé': return '🚨';
      case 'modéré': return '⚠️';
      default: return '🟡';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          // Color indicator bar
          Container(
            width: 5,
            height: 70,
            decoration: BoxDecoration(
              color: _barColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  species.name,
                  style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.t1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  species.latin,
                  style: GoogleFonts.nunitoSans(
                    fontSize: 12, color: AppColors.t3, fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
                AppChip(
                  label: '$_dangerEmoji Danger ${species.dangerLevel}',
                  variant: _chipVariant,
                  fontSize: 11,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Count & confidence
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '×${species.count}',
                style: GoogleFonts.nunito(
                  fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.t1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${species.confidence.toStringAsFixed(0)}%',
                style: GoogleFonts.nunito(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _barColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
