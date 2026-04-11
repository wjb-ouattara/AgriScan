import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════
// PROFILE SCREEN
// ═══════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _offlineMode = true;
  bool _alertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──
          SliverToBoxAdapter(
            child: _buildHero(context),
          ),
          // ── Body ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // My farm
                const SectionLabel('Mon exploitation'),
                ProfileMenuItem(
                  emoji: '🌾',
                  title: 'Mes cultures',
                  subtitle: 'Blé, Tomate, Maïs',
                  onTap: () {},
                ),
                ProfileMenuItem(
                  emoji: '🗺️',
                  title: 'Mes parcelles',
                  subtitle: '4 champs enregistrés',
                  onTap: () {},
                ),
                ProfileMenuItem(
                  emoji: '📋',
                  title: 'Mes rapports',
                  subtitle: '14 diagnostics ce mois',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppChip(label: 'Nouveau', variant: ChipVariant.green, fontSize: 10),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.t4, size: 22),
                    ],
                  ),
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                // AI settings
                const SectionLabel('Paramètres IA'),
                ProfileMenuItem(
                  emoji: '🧠',
                  title: 'Modèle IA installé',
                  subtitle: 'MobileNetV3 · v3.2.1 · À jour ✓',
                  trailing: AppChip(label: 'À jour', variant: ChipVariant.green, fontSize: 10),
                ),
                ProfileMenuItem(
                  emoji: '📱',
                  title: 'Fonctionner sans internet',
                  subtitle: 'Mode hors ligne activé',
                  trailing: AppToggle(
                    value: _offlineMode,
                    onChanged: (v) => setState(() => _offlineMode = v),
                  ),
                ),
                ProfileMenuItem(
                  emoji: '🔔',
                  title: 'Alertes maladies',
                  subtitle: 'Notification push activée',
                  trailing: AppToggle(
                    value: _alertsEnabled,
                    onChanged: (v) => setState(() => _alertsEnabled = v),
                  ),
                ),
                const SizedBox(height: 8),
                // General
                const SectionLabel('Général'),
                ProfileMenuItem(
                  emoji: '🔤',
                  title: 'Langue de l\'application',
                  subtitle: 'Français · العربية · Darija',
                  onTap: () {},
                ),
                ProfileMenuItem(
                  emoji: '☁️',
                  title: 'Synchronisation cloud',
                  subtitle: 'Dernière sync: il y a 2h',
                  onTap: () {},
                ),
                ProfileMenuItem(
                  emoji: '❓',
                  title: 'Aide & Support',
                  subtitle: 'Guide d\'utilisation, FAQ',
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                // Logout
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.red2,
                      foregroundColor: AppColors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        side: const BorderSide(color: AppColors.red3, width: 2),
                      ),
                    ),
                    child: Text(
                      'Se déconnecter',
                      style: GoogleFonts.nunito(
                        fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'AgriScan v3.0 · Certifié WCAG AA · Offline IA',
                    style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.t4, letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 20, bottom: 0,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(
        children: [
          // Top row
          Row(
            children: [
              // Avatar
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.g700,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.g700.withOpacity(0.3),
                      blurRadius: 16, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'IB',
                    style: GoogleFonts.nunito(
                      fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ibrahim Benali',
                      style: GoogleFonts.nunito(
                        fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.g900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Agriculteur · 8.5 ha cultivés',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 14, color: AppColors.t2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          'Meknès, Maroc',
                          style: GoogleFonts.nunito(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.g600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Crop chips
          Wrap(
            spacing: 8, runSpacing: 6,
            children: const [
              AppChip(label: '🌾 Blé',      variant: ChipVariant.green),
              AppChip(label: '🍅 Tomate',   variant: ChipVariant.green),
              AppChip(label: '🌽 Maïs',     variant: ChipVariant.green),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
            ),
            child: Row(
              children: [
                _StatCell(value: '127', label: 'Analyses', color: AppColors.g700),
                _StatCell(value: '14',  label: 'Maladies', color: AppColors.amber),
                _StatCell(value: '4',   label: 'Parcelles', color: AppColors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: AppColors.border,
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 24, fontWeight: FontWeight.w900, color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunitoSans(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.t3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
