import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/marketplace_service.dart';
import '../services/database_service.dart';
import 'marketplace_cart_screen.dart';
import 'login_screen.dart';

// ══════════════════════════════════════════════════════════
//  PRODUCT DETAIL SCREEN
// ══════════════════════════════════════════════════════════

class MarketplaceProductDetailScreen extends StatefulWidget {
  final Product product;
  const MarketplaceProductDetailScreen({super.key, required this.product});

  @override
  State<MarketplaceProductDetailScreen> createState() =>
      _MarketplaceProductDetailScreenState();
}

class _MarketplaceProductDetailScreenState
    extends State<MarketplaceProductDetailScreen> {
  final _svc = MarketplaceService();
  bool _isLoggedIn = false;
  int  _qty = 1;

  @override
  void initState() {
    super.initState();
    DatabaseService().isLoggedIn().then((v) {
      if (mounted) setState(() => _isLoggedIn = v);
    });
  }

  void _addToCart() {
    if (!_isLoggedIn) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => LoginScreen()));
      return;
    }
    _svc.addToCart(widget.product, qty: _qty);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.product.name} ajouté au panier ($_qty)'),
      backgroundColor: AppColors.g700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(
          label: 'Voir le panier',
          textColor: Colors.white,
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MarketplaceCartScreen()))),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(slivers: [

        // ── Image en-tête ──
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.surface,
          leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.g900)))),
          actions: [
            Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                        const MarketplaceCartScreen())),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.shopping_cart_outlined,
                              color: AppColors.g700, size: 18),
                          const SizedBox(width: 6),
                          Text('${_svc.cartCount}', style: GoogleFonts.nunito(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: AppColors.g700)),
                        ])))),
          ],
          flexibleSpace: FlexibleSpaceBar(
              background: p.imageUrl.isNotEmpty
                  ? Image.network(p.imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(p.category))
                  : _placeholder(p.category)),
        ),

        // ── Contenu ──
        SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Catégorie + disponibilité
              Row(children: [
                _Badge(label: p.categoryLabel),
                const SizedBox(width: 8),
                _Badge(
                    label: p.isAvailable
                        ? '${p.stockQty} en stock'
                        : 'Indisponible',
                    color: p.isAvailable
                        ? AppColors.g700 : const Color(0xFFD63A1A)),
              ]),
              const SizedBox(height: 12),

              // Nom + prix
              Text(p.name, style: GoogleFonts.nunito(
                  fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.g900)),
              const SizedBox(height: 6),
              Text('${p.price.toStringAsFixed(2)} MAD',
                  style: GoogleFonts.nunito(fontSize: 22,
                      fontWeight: FontWeight.w800, color: AppColors.g700)),
              const SizedBox(height: 6),
              Text('Vendu par ${p.vendorName}',
                  style: GoogleFonts.nunitoSans(fontSize: 13,
                      color: AppColors.t3)),
              const SizedBox(height: 20),

              // Description
              _SectionTitle('Description'),
              Text(p.description, style: GoogleFonts.nunitoSans(
                  fontSize: 15, color: AppColors.t2, height: 1.6)),
              const SizedBox(height: 20),

              // Mode d'utilisation
              _SectionTitle('Mode d\'utilisation'),
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.g50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.g300)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.science_outlined,
                            color: AppColors.g700, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(p.usage, style: GoogleFonts.nunitoSans(
                            fontSize: 14, color: AppColors.t2, height: 1.6))),
                      ])),
              const SizedBox(height: 20),

              // Maladies ciblées
              if (p.targetDiseases.isNotEmpty) ...[
                _SectionTitle('Maladies ciblées'),
                Wrap(spacing: 8, runSpacing: 8,
                    children: p.targetDiseases.map((d) =>
                        _DiseasePill(code: d)).toList()),
                const SizedBox(height: 20),
              ],

              // Sélecteur de quantité
              _SectionTitle('Quantité'),
              Row(children: [
                _QtyBtn(Icons.remove_rounded,
                    onTap: () { if (_qty > 1) setState(() => _qty--); }),
                const SizedBox(width: 16),
                Text('$_qty', style: GoogleFonts.nunito(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.t1)),
                const SizedBox(width: 16),
                _QtyBtn(Icons.add_rounded,
                    onTap: () => setState(() => _qty++)),
                const Spacer(),
                Text('Total : ${(p.price * _qty).toStringAsFixed(2)} MAD',
                    style: GoogleFonts.nunito(fontSize: 14,
                        fontWeight: FontWeight.w700, color: AppColors.t2)),
              ]),
              const SizedBox(height: 28),

              // Bouton commander
              if (!_isLoggedIn) ...[
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF0D6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE8920A))),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFFE8920A)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                          'Connectez-vous pour ajouter au panier et commander.',
                          style: GoogleFonts.nunitoSans(fontSize: 13,
                              color: const Color(0xFFB36B00)))),
                    ])),
                const SizedBox(height: 12),
              ],

              SizedBox(width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: p.isAvailable ? _addToCart : null,
                    icon: Icon(_isLoggedIn
                        ? Icons.add_shopping_cart_rounded
                        : Icons.login_rounded),
                    label: Text(_isLoggedIn
                        ? 'Ajouter au panier'
                        : 'Se connecter pour commander',
                        style: GoogleFonts.nunito(fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  )),
              const SizedBox(height: 32),
            ])))
      ]),
    );
  }

  Widget _placeholder(String category) => Container(
      color: AppColors.g50,
      child: Center(child: Icon(
          category == 'fertilizer' ? Icons.grass_rounded
              : category == 'bio'      ? Icons.eco_rounded
              : Icons.science_outlined,
          size: 80, color: AppColors.g300)));
}

// ── Sub-widgets ───────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: GoogleFonts.nunito(
          fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)));
}

class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge({required String label, Color? color})
      : text = label, color = color ?? AppColors.g700;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(text, style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700, color: color)));
}

class _DiseasePill extends StatelessWidget {
  final String code;
  const _DiseasePill({required this.code});

  static const _names = {
    'f_NLB' : 'Helminthosporiose (NLB)',
    'f_GLS'  : 'Cercosporiose (GLS)',
    'f_RUST' : 'Rouille commune',
    'v_MLN'  : 'Nécrose létale (MLN)',
    'v_MSV'  : 'Striure du maïs (MSV)',
    'Healthy': 'Maïs sain',
  };

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.g50,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.g300)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_pharmacy_outlined,
            size: 13, color: AppColors.g700),
        const SizedBox(width: 5),
        Text(_names[code] ?? code, style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.g700)),
      ]));
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn(this.icon, {required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border)),
          child: Icon(icon, size: 18, color: AppColors.t2)));
}