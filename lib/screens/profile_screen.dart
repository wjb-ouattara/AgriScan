import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/database_service.dart';
import '../services/token_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'agricultural_context_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db       = DatabaseService();
  final _tokens   = TokenService();
  final _supabase = SupabaseService();

  AppUser? _user;
  bool     _isLoggedIn    = false;
  int      _scansCount    = 0;
  String   _statusMessage = '';
  bool     _loading       = true;
  bool     _syncing       = false;

  String _ctxRegion  = '';
  String _ctxCulture = '';
  String _ctxSeason  = '';
  String _ctxClimate = '';
  String _ctxSoil    = '';
  String _ctxArea    = '';

  bool _notificationsOn = true;
  bool _offlineModeOn   = true;
  bool _autoSyncOn      = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final isLogin   = await _db.isLoggedIn();
      final scansN    = await _db.getScansCount();
      final statusMsg = await _tokens.getStatusMessage();
      final userId    = await _db.getCurrentUserId();
      AppUser? user;
      if (userId != null) user = await _db.getUser(userId);

      final region  = await _db.getSetting('ctx_region');
      final culture = await _db.getSetting('ctx_culture');
      final season  = await _db.getSetting('ctx_season');
      final climate = await _db.getSetting('ctx_climate');
      final soil    = await _db.getSetting('ctx_soil');
      final area    = await _db.getSetting('ctx_area');

      if (mounted) {
        setState(() {
          _isLoggedIn    = isLogin;
          _scansCount    = scansN;
          _statusMessage = statusMsg;
          _user          = user;
          _ctxRegion     = region  ?? (user?.region ?? 'Non défini');
          _ctxCulture    = culture ?? 'Non défini';
          _ctxSeason     = season  ?? 'Non défini';
          _ctxClimate    = climate ?? 'Non défini';
          _ctxSoil       = soil    ?? 'Non défini';
          _ctxArea       = area != null ? '$area ha' : 'Non défini';
          _loading       = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final result = await _supabase.syncToCloud();
    if (mounted) {
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? AppColors.green : AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))));
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('Déconnexion', style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800)),
              content: Text('Vos données locales seront conservées.',
                  style: GoogleFonts.nunitoSans(fontSize: 14)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Annuler')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red, elevation: 0),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Déconnexion',
                        style: TextStyle(color: Colors.white))),
              ]);
        });
    if (confirm == true) {
      await _supabase.signOut();
      await _loadData();
    }
  }

  void _goToContext() {
    Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => const AgriculturalContextScreen()))
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(
              color: AppColors.g600)));
    }
    return Scaffold(
        backgroundColor: AppColors.bg,
        body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        if (!_isLoggedIn) _buildLoginBanner(),
                        if (_isLoggedIn) ...[
                          _buildSyncCard(),
                          const SizedBox(height: 20),
                        ],
                        _buildContextCard(),
                        const SizedBox(height: 20),
                        _buildSettingsCard(),
                        const SizedBox(height: 20),
                        _buildAppInfoCard(),
                        const SizedBox(height: 20),
                        if (_isLoggedIn) _buildLogoutBtn(),
                      ]))
              )
            ]
        )
    );
  }

  Widget _buildHero() {
    final name = _isLoggedIn
        ? (_user?.name ?? 'Agriculteur')
        : 'Agriculteur';
    final email = _isLoggedIn
        ? (_user?.email ?? '')
        : 'Connectez-vous pour sauvegarder';
    final region = (_ctxRegion.isNotEmpty && _ctxRegion != 'Non défini')
        ? _ctxRegion
        : (_user?.region ?? 'Maroc');
    final culture = _ctxCulture != 'Non défini' ? _ctxCulture : '';
    final initials = name.trim().split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A3D1C), Color(0xFF2D6530)])),
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(children: [
                        Text('Mon Profil', style: GoogleFonts.nunito(
                            fontSize: 18, fontWeight: FontWeight.w900,
                            color: Colors.white)),
                        const Spacer(),
                        GestureDetector(
                            onTap: _loadData,
                            child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.refresh_rounded,
                                    size: 18, color: Colors.white))),
                      ]),
                      const SizedBox(height: 20),
                      // Avatar + infos
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(children: [
                              Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.4), width: 2)),
                                  child: Center(child: Text(
                                      initials.isEmpty ? 'AG' : initials,
                                      style: GoogleFonts.nunito(fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white)))),
                              if (_isLoggedIn)
                                Positioned(bottom: 0, right: 0,
                                    child: Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                            color: AppColors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2)),
                                        child: const Icon(Icons.check,
                                            size: 10, color: Colors.white))),
                            ]),
                            const SizedBox(width: 16),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: GoogleFonts.nunito(
                                      fontSize: 22, fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                                  if (email.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(email, style: GoogleFonts.nunitoSans(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7)),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    _heroTag('📍 $region'),
                                    if (culture.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      _heroTag('🌱 $culture'),
                                    ],
                                  ]),
                                ])),
                          ]),
                    ]))));
  }

  Widget _heroTag(String text) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withOpacity(0.2))),
        child: Text(text, style: GoogleFonts.nunito(fontSize: 11,
            fontWeight: FontWeight.w700, color: Colors.white)));
  }

  Widget _buildStatsRow() {
    final scansLeft = _isLoggedIn
        ? '∞'
        : '${(15 - _scansCount) < 0 ? 0 : 15 - _scansCount}';
    return Row(children: [
      Expanded(child: _StatCard(value: '$_scansCount',
          label: 'Analyses', emoji: '🔬', color: AppColors.g700)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
          value: _isLoggedIn ? '☁️' : '📱',
          label: _isLoggedIn ? 'Synchronisé' : 'Local',
          emoji: _isLoggedIn ? '✅' : '📶',
          color: AppColors.green)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(value: scansLeft,
          label: 'Restantes', emoji: '⚡', color: AppColors.amber)),
    ]);
  }

  Widget _buildLoginBanner() {
    return GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LoginScreen()))
            .then((_) => _loadData()),
        child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.g700.withOpacity(0.08),
                  AppColors.g700.withOpacity(0.04)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.g300, width: 1.5)),
            child: Row(children: [
              Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                      color: AppColors.g700, shape: BoxShape.circle),
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Créez un compte gratuit',
                        style: GoogleFonts.nunito(fontSize: 14,
                            fontWeight: FontWeight.w800, color: AppColors.g700)),
                    Text('Analyses illimitées · Sync cloud',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 12, color: AppColors.t2)),
                  ])),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.g600),
            ])));
  }

  Widget _buildSyncCard() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.g50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.g300, width: 1.5)),
        child: Row(children: [
          const Text('☁️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Synchronisation cloud',
                    style: GoogleFonts.nunito(fontSize: 14,
                        fontWeight: FontWeight.w800, color: AppColors.g900)),
                Text('Analyses sauvegardées',
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12, color: AppColors.t2)),
              ])),
          const SizedBox(width: 12),
          SizedBox(
              width: 80, height: 38,
              child: ElevatedButton(
                  onPressed: _syncing ? null : _sync,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g700,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 0),
                  child: _syncing
                      ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Text('Sync', style: GoogleFonts.nunito(
                      fontSize: 13, fontWeight: FontWeight.w800,
                      color: Colors.white)))),
        ]));
  }

  Widget _buildContextCard() {
    return Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(children: [
                const Text('🌾', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text('Contexte agricole',
                    style: GoogleFonts.nunito(fontSize: 15,
                        fontWeight: FontWeight.w800, color: AppColors.g900))),
                GestureDetector(
                    onTap: _goToContext,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: AppColors.g50,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: AppColors.g300)),
                        child: Text('Modifier', style: GoogleFonts.nunito(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.g700)))),
              ])),
          const Divider(color: AppColors.surface2, height: 1),
          _ctxRow('📍', 'Région',      _ctxRegion),
          _ctxRow('🌤️', 'Climat',     _ctxClimate),
          _ctxRow('🌱', 'Culture',     _ctxCulture),
          _ctxRow('🗓️', 'Saison',     _ctxSeason),
          _ctxRow('🪨', 'Sol',         _ctxSoil),
          _ctxRow('📐', 'Superficie',  _ctxArea, isLast: true),
        ]));
  }

  Widget _ctxRow(String emoji, String label, String value,
      {bool isLast = false}) {
    return Container(
        decoration: BoxDecoration(border: Border(bottom: isLast
            ? BorderSide.none
            : const BorderSide(color: AppColors.surface2, width: 1))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.nunito(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.t2))),
          Text(value == 'Non défini' ? '—' : value,
              style: GoogleFonts.nunito(fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: value == 'Non défini' ? AppColors.t4 : AppColors.t1)),
        ]));
  }

  Widget _buildSettingsCard() {
    return Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                const Text('⚙️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text('Paramètres', style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.g900)),
              ])),
          const Divider(color: AppColors.surface2, height: 1),
          _settingRow('🔔', 'Notifications',
              'Alertes maladies saisonnières',
              _notificationsOn,
                  (v) => setState(() => _notificationsOn = v)),
          const Divider(color: AppColors.surface2, height: 1),
          _settingRow('📶', 'Mode hors ligne',
              'IA locale en priorité',
              _offlineModeOn,
                  (v) => setState(() => _offlineModeOn = v)),
          const Divider(color: AppColors.surface2, height: 1),
          _settingRow('☁️', 'Sync automatique',
              'Quand Wi-Fi disponible',
              _autoSyncOn,
                  (v) => setState(() => _autoSyncOn = v)),
        ]));
  }

  Widget _settingRow(String emoji, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.nunito(fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.t1)),
                Text(subtitle, style: GoogleFonts.nunitoSans(
                    fontSize: 11, color: AppColors.t3)),
              ])),
          AppToggle(value: value, onChanged: onChanged),
        ]));
  }

  Widget _buildAppInfoCard() {
    return Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(children: [
                const Text('📱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text('Application', style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: AppColors.g900)),
              ])),
          const Divider(color: AppColors.surface2, height: 1),
          _infoRow('🔖', 'Version',   'AgriScan v4.0'),
          const Divider(color: AppColors.surface2, height: 1),
          _infoRow('🧠', 'Modèle IA', 'CropNet · ConvNeXt'),
          const Divider(color: AppColors.surface2, height: 1),
          _infoRow('🌿', 'Cultures',  'Maïs · Tomate'),
          const Divider(color: AppColors.surface2, height: 1),
          _infoRow('📶', 'Connexion',
              _isLoggedIn ? '✅ En ligne' : '📵 Hors ligne'),
        ]));
  }

  Widget _infoRow(String emoji, String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.nunito(fontSize: 13,
              fontWeight: FontWeight.w600, color: AppColors.t2)),
          const Spacer(),
          Text(value, style: GoogleFonts.nunito(fontSize: 13,
              fontWeight: FontWeight.w700, color: AppColors.t1)),
        ]));
  }

  Widget _buildLogoutBtn() {
    return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text('Se déconnecter', style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)))));
  }
}

class _StatCard extends StatelessWidget {
  final String value, label, emoji;
  final Color color;
  const _StatCard({required this.value, required this.label,
    required this.emoji, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Column(children: [
          Text(value, style: GoogleFonts.nunito(fontSize: 22,
              fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.nunitoSans(
              fontSize: 11, color: AppColors.t3)),
        ]));
  }
}