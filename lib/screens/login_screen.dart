import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';
import '../services/token_service.dart';
import 'app_shell.dart';

// ══════════════════════════════════════════════════════════
//  LOGIN SCREEN
//  Connexion + Inscription connectées à Supabase
//  Après login : sync données cloud → SQLite local
// ══════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;

  // Connexion
  final _loginEmail    = TextEditingController();
  final _loginPassword = TextEditingController();

  // Inscription
  final _regName     = TextEditingController();
  final _regEmail    = TextEditingController();
  final _regPassword = TextEditingController();
  final _regConfirm  = TextEditingController();
  String _regRegion  = 'Maroc';

  bool   _loading      = false;
  bool   _showLoginPwd = false;
  bool   _showRegPwd   = false;
  String _error        = '';

  static const _regions = [
    'Maroc', 'Côte d\'Ivoire', 'Sénégal', 'Mali',
    'Burkina Faso', 'Niger', 'Cameroun', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _error = ''));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _loginEmail.dispose(); _loginPassword.dispose();
    _regName.dispose(); _regEmail.dispose();
    _regPassword.dispose(); _regConfirm.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════
  //  CONNEXION
  // ════════════════════════════════════════════════════
  Future<void> _login() async {
    final email    = _loginEmail.text.trim();
    final password = _loginPassword.text;

    if (email.isEmpty || password.isEmpty) {
      _setError('Remplissez tous les champs.');
      return;
    }

    _setLoading(true);
    try {
      final result = await SupabaseService().signIn(
        email   : email,
        password: password,
      );

      if (!mounted) return;

      if (result.success) {
        // Sync données cloud → SQLite
        await _syncAfterLogin();
        _navigateHome();
      } else {
        _setError(result.message);
      }
    } catch (e) {
      _setError('Erreur : $e');
    } finally {
      _setLoading(false);
    }
  }

  // ════════════════════════════════════════════════════
  //  INSCRIPTION
  // ════════════════════════════════════════════════════
  Future<void> _register() async {
    final name     = _regName.text.trim();
    final email    = _regEmail.text.trim();
    final password = _regPassword.text;
    final confirm  = _regConfirm.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _setError('Remplissez tous les champs obligatoires.');
      return;
    }
    if (password != confirm) {
      _setError('Les mots de passe ne correspondent pas.');
      return;
    }
    if (password.length < 6) {
      _setError('Mot de passe minimum 6 caractères.');
      return;
    }

    _setLoading(true);
    try {
      final result = await SupabaseService().signUp(
        email   : email,
        password: password,
        name    : name,
        region  : _regRegion,
      );

      if (!mounted) return;

      if (result.success) {
        await _syncAfterLogin();
        _navigateHome();
      } else {
        _setError(result.message);
      }
    } catch (e) {
      _setError('Erreur : $e');
    } finally {
      _setLoading(false);
    }
  }

  // ════════════════════════════════════════════════════
  //  SYNC APRÈS LOGIN
  //  Cloud Supabase → SQLite local
  // ════════════════════════════════════════════════════
  Future<void> _syncAfterLogin() async {
    try {
      final db      = DatabaseService();
      final supabase = SupabaseService();

      // 1. Récupérer les scans depuis Supabase
      final cloudScans = await supabase.getCloudScans(limit: 100);

      // 2. Récupérer l'ID utilisateur connecté
      final userId = supabase.currentUser?.id;
      if (userId == null) return;

      // 3. Sauvegarder chaque scan cloud dans SQLite local
      for (final scan in cloudScans) {
        try {
          await db.saveScan(
            plantType  : scan['plant_type']   ?? '',
            diseaseName: scan['disease_name'] ?? '',
            severity   : scan['severity']     ?? '',
            confidence : (scan['confidence']  as num?)?.toDouble() ?? 0.0,
            modelUsed  : scan['model_used']   ?? '',
            userId     : userId,
          );
        } catch (_) {
          // Scan déjà existant — ignorer
        }
      }

      // 4. Synchroniser les scans locaux non envoyés vers Supabase
      await supabase.syncToCloud();

      // 5. Réinitialiser le compteur tokens
      await TokenService().onLogin();

      print('✅ Sync terminée : ${cloudScans.length} scans récupérés');
    } catch (e) {
      print('⚠️ Sync partielle : $e');
      // Ne pas bloquer la connexion si sync échoue
    }
  }

  // ── Navigue vers l'app principale en vidant toute la pile
  //    de navigation (Splash/Login ne doivent plus être
  //    accessibles via le bouton retour) ──────────────────
  void _navigateHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
    );
  }

  void _setLoading(bool v) {
    if (mounted) setState(() { _loading = v; if (v) _error = ''; });
  }

  void _setError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: w >= 900 ? _buildDesktop() : _buildMobile(),
    );
  }

  // ── Desktop ────────────────────────────────────────
  Widget _buildDesktop() {
    return Row(children: [
      // Panneau gauche — illustration
      Expanded(flex: 5, child: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1E3820), Color(0xFF2D5A30)])),
          child: Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
            const Text('🌿', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text('AgriScan', style: GoogleFonts.nunito(
                fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Détection intelligente\ndes maladies des plantes',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(
                    fontSize: 16, color: Colors.white.withOpacity(0.7),
                    height: 1.5)),
            const SizedBox(height: 40),
            // Stats
            Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatBadge('🌽', 'Maïs', 'Détection'),
                  const SizedBox(width: 24),
                  _StatBadge('🤖', 'IA', 'ConvNeXt'),
                  const SizedBox(width: 24),
                  _StatBadge('⚡', '< 1s', 'Analyse'),
                ]),
          ])))),
      // Panneau droit — formulaire
      Expanded(flex: 5, child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
              child: _buildForm())))),
    ]);
  }

  // ── Mobile ─────────────────────────────────────────
  Widget _buildMobile() => SingleChildScrollView(
      child: Column(children: [
        // Header
        Container(
            width: double.infinity,
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 32,
                bottom: 32, left: 24, right: 24),
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3820), Color(0xFF2D5A30)])),
            child: Column(children: [
              const Text('🌿', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text('AgriScan', style: GoogleFonts.nunito(
                  fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Détection des maladies des plantes',
                  style: GoogleFonts.nunitoSans(
                      fontSize: 13, color: Colors.white.withOpacity(0.7))),
            ])),
        // Formulaire
        Padding(padding: const EdgeInsets.all(24), child: _buildForm()),
      ]));

  // ── Formulaire commun ──────────────────────────────
  Widget _buildForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      // Tabs
      Container(
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5)),
          padding: const EdgeInsets.all(4),
          child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                  color: AppColors.g700,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppShadows.sm),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.t2,
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.nunito(
                  fontSize: 14, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(text: 'Connexion'),
                Tab(text: 'Inscription'),
              ])),
      const SizedBox(height: 24),

      // Contenu des tabs
      AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _tabs.index == 0
              ? _buildLoginForm()
              : _buildRegisterForm()),

      // Erreur
      if (_error.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.red.withOpacity(0.3))),
            child: Row(children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(child: Text(_error,
                  style: GoogleFonts.nunitoSans(
                      fontSize: 13, color: AppColors.red))),
            ])),
      ],

      const SizedBox(height: 16),

      // Mode hors ligne
      Center(child: TextButton(
          onPressed: _navigateHome,
          child: Text('Continuer sans compte (mode hors ligne)',
              style: GoogleFonts.nunito(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.t3)))),
    ]);
  }

  // ════════════════════════════════════════════════════
  //  FORMULAIRE CONNEXION
  // ════════════════════════════════════════════════════
  Widget _buildLoginForm() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
            controller  : _loginEmail,
            label       : 'Email',
            hint        : 'votre@email.com',
            icon        : Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _Field(
            controller  : _loginPassword,
            label       : 'Mot de passe',
            hint        : '••••••••',
            icon        : Icons.lock_outline_rounded,
            obscure     : !_showLoginPwd,
            suffix      : IconButton(
                icon: Icon(_showLoginPwd
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                    color: AppColors.t3, size: 20),
                onPressed: () =>
                    setState(() => _showLoginPwd = !_showLoginPwd))),
        const SizedBox(height: 24),
        _PrimaryBtn(
            label  : 'Se connecter',
            loading: _loading,
            onTap  : _login),
      ]);

  // ════════════════════════════════════════════════════
  //  FORMULAIRE INSCRIPTION
  // ════════════════════════════════════════════════════
  Widget _buildRegisterForm() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
            controller: _regName,
            label     : 'Prénom et nom *',
            hint      : 'Ahmed Benali',
            icon      : Icons.person_outline_rounded),
        const SizedBox(height: 14),
        _Field(
            controller  : _regEmail,
            label       : 'Email *',
            hint        : 'votre@email.com',
            icon        : Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        // Région
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5)),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _regRegion,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.t3),
                style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t1),
                items: _regions.map((r) => DropdownMenuItem(
                    value: r,
                    child: Row(children: [
                      const Text('📍', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(r),
                    ]))).toList(),
                onChanged: (v) => setState(() => _regRegion = v!)))),
        const SizedBox(height: 14),
        _Field(
            controller: _regPassword,
            label     : 'Mot de passe *',
            hint      : 'Minimum 6 caractères',
            icon      : Icons.lock_outline_rounded,
            obscure   : !_showRegPwd,
            suffix    : IconButton(
                icon: Icon(_showRegPwd
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                    color: AppColors.t3, size: 20),
                onPressed: () =>
                    setState(() => _showRegPwd = !_showRegPwd))),
        const SizedBox(height: 14),
        _Field(
            controller: _regConfirm,
            label     : 'Confirmer le mot de passe *',
            hint      : 'Répétez votre mot de passe',
            icon      : Icons.lock_outline_rounded,
            obscure   : !_showRegPwd),
        const SizedBox(height: 24),
        _PrimaryBtn(
            label  : 'Créer mon compte',
            loading: _loading,
            onTap  : _register),
        const SizedBox(height: 8),
        Center(child: Text('En créant un compte, vos analyses\nseront sauvegardées et illimitées.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t3))),
      ]);
}

// ══════════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════════

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.nunito(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.t1)),
    const SizedBox(height: 6),
    TextField(
        controller  : controller,
        obscureText : obscure,
        keyboardType: keyboardType,
        style       : GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t1),
        decoration  : InputDecoration(
            hintText       : hint,
            hintStyle      : GoogleFonts.nunitoSans(
                fontSize: 14, color: AppColors.t4),
            prefixIcon     : Icon(icon, size: 20, color: AppColors.t3),
            suffixIcon     : suffix,
            filled         : true,
            fillColor      : AppColors.surface,
            border         : OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide  : const BorderSide(color: AppColors.border, width: 1.5)),
            enabledBorder  : OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide  : const BorderSide(color: AppColors.border, width: 1.5)),
            focusedBorder  : OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide  : const BorderSide(color: AppColors.g600, width: 2)),
            contentPadding : const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14))),
  ]);
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.g700,
              foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              shadowColor: AppColors.g700.withOpacity(0.3)),
          child: loading
              ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: GoogleFonts.nunito(
              fontSize: 16, fontWeight: FontWeight.w800))));
}

class _StatBadge extends StatelessWidget {
  final String emoji, value, label;
  const _StatBadge(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 24)),
    const SizedBox(height: 4),
    Text(value, style: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
    Text(label, style: GoogleFonts.nunitoSans(
        fontSize: 11, color: Colors.white.withOpacity(0.6))),
  ]);
}