import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/marketplace_service.dart';
import '../services/database_service.dart';
import 'marketplace_product_detail_screen.dart';
import 'marketplace_cart_screen.dart';

// ══════════════════════════════════════════════════════════
//  MARKETPLACE SCREEN — liste des produits
//  Accessible depuis l'onglet "Boutique" de AppShell
//  ou depuis DiseaseResultScreen (lien diagnostic → achat)
// ══════════════════════════════════════════════════════════

class MarketplaceScreen extends StatefulWidget {
  /// Si fourni, présélectionne les produits pour cette maladie
  final String? diseaseCode;
  final String? diseaseName;

  const MarketplaceScreen({super.key, this.diseaseCode, this.diseaseName});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _svc  = MarketplaceService();
  final _db   = DatabaseService();

  List<Product> _products = [];
  List<Product> _filtered = [];
  bool          _loading  = true;
  String?       _error;
  String        _selectedCat = 'all';
  String        _searchQuery = '';
  bool          _isLoggedIn  = false;

  static const _categories = [
    ('all',        'Tout'),
    ('fungicide',  'Fongicides'),
    ('pesticide',  'Pesticides'),
    ('fertilizer', 'Engrais'),
    ('bio',        'Bio'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logged = await _db.isLoggedIn();
      final products = await _svc.fetchProducts(
          diseaseCode: widget.diseaseCode);
      if (!mounted) return;
      setState(() {
        _isLoggedIn = logged;
        _products   = products;
        _loading    = false;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilters() {
    var list = _products;
    if (_selectedCat != 'all') {
      list = list.where((p) => p.category == _selectedCat).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
      p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.categoryLabel.toLowerCase().contains(q)).toList();
    }
    _filtered = list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        _Header(
          cartCount: _svc.cartCount,
          onCartTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MarketplaceCartScreen())),
        ),

        // Bannière "Recommandé pour [maladie]"
        if (widget.diseaseCode != null && widget.diseaseName != null)
          _DiseaseBanner(diseaseName: widget.diseaseName!),

        // Barre de recherche
        _SearchBar(
          onChanged: (q) => setState(() {
            _searchQuery = q; _applyFilters();
          }),
        ),

        // Filtres par catégorie
        _CategoryFilter(
          selected: _selectedCat,
          categories: _categories,
          onSelect: (cat) => setState(() {
            _selectedCat = cat; _applyFilters();
          }),
        ),

        // Corps
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(
            color: AppColors.g700))
            : _error != null
            ? _ErrorView(error: _error!, onRetry: _load)
            : _filtered.isEmpty
            ? const _EmptyView()
            : _ProductGrid(
          products: _filtered,
          cartService: _svc,
          isLoggedIn: _isLoggedIn,
          onTap: (p) => Navigator.push(context,
              MaterialPageRoute(builder: (_) =>
                  MarketplaceProductDetailScreen(product: p))),
          onAddToCart: (p) {
            _svc.addToCart(p);
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('${p.name} ajouté au panier'),
              backgroundColor: AppColors.g700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ));
          },
        ),
        ),
      ])),
    );
  }
}

// ── Sous-widgets ──────────────────────────────────────────

class _Header extends StatelessWidget {
  final int cartCount;
  final VoidCallback onCartTap;
  const _Header({required this.cartCount, required this.onCartTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5))),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Boutique AgriScan',
              style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900,
                  color: AppColors.g900)),
          Text('Produits phytosanitaires & engrais',
              style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
        ]),
        const Spacer(),
        Stack(children: [
          GestureDetector(
              onTap: onCartTap,
              child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.g50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.g300)),
                  child: const Icon(Icons.shopping_cart_outlined,
                      color: AppColors.g700, size: 22))),
          if (cartCount > 0)
            Positioned(right: 0, top: 0,
                child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE8920A), shape: BoxShape.circle),
                    child: Center(child: Text('$cartCount',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.w800))))),
        ]),
      ]),
    );
  }
}

class _DiseaseBanner extends StatelessWidget {
  final String diseaseName;
  const _DiseaseBanner({required this.diseaseName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF0D6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8920A), width: 1.5)),
      child: Row(children: [
        const Icon(Icons.local_pharmacy_outlined,
            color: Color(0xFFE8920A), size: 22),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(
            style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t1),
            children: [
              const TextSpan(text: 'Produits recommandés contre '),
              TextSpan(text: diseaseName,
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      color: Color(0xFFB36B00))),
              const TextSpan(text: ' détecté par l\'IA'),
            ]))),
      ]),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t1),
        decoration: InputDecoration(
          hintText: 'Rechercher un produit…',
          hintStyle: GoogleFonts.nunitoSans(color: AppColors.t4),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.t3, size: 20),
          filled: true, fillColor: AppColors.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.g700, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ));
}

class _CategoryFilter extends StatelessWidget {
  final String selected;
  final List<(String, String)> categories;
  final ValueChanged<String> onSelect;
  const _CategoryFilter({required this.selected,
    required this.categories, required this.onSelect});

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (id, label) = categories[i];
          final active = selected == id;
          return GestureDetector(
              onTap: () => onSelect(id),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: active ? AppColors.g700 : AppColors.surface,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                          color: active ? AppColors.g700 : AppColors.border, width: 1.5)),
                  child: Text(label,
                      style: GoogleFonts.nunito(fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.t2))));
        },
      ));
}

class _ProductGrid extends StatelessWidget {
  final List<Product>       products;
  final MarketplaceService  cartService;
  final bool                isLoggedIn;
  final ValueChanged<Product> onTap;
  final ValueChanged<Product> onAddToCart;
  const _ProductGrid({required this.products, required this.cartService,
    required this.isLoggedIn, required this.onTap, required this.onAddToCart});

  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72,
        crossAxisSpacing: 12, mainAxisSpacing: 12),
    itemCount: products.length,
    itemBuilder: (_, i) => _ProductCard(
      product: products[i],
      onTap: () => onTap(products[i]),
      onAddToCart: isLoggedIn
          ? () => onAddToCart(products[i])
          : null,
    ),
  );
}

class _ProductCard extends StatelessWidget {
  final Product      product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  const _ProductCard({required this.product, required this.onTap,
    this.onAddToCart});

  static const _catColors = {
    'fungicide' : (Color(0xFFF0F9F1), Color(0xFF2D6530)),
    'pesticide' : (Color(0xFFFFF3F0), Color(0xFFD63A1A)),
    'fertilizer': (Color(0xFFFFF8E6), Color(0xFFAA7A00)),
    'bio'       : (Color(0xFFEDF7F0), Color(0xFF0F7A42)),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _catColors[product.category]
        ?? (AppColors.g50, AppColors.g700);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [BoxShadow(
                color: AppColors.g700.withOpacity(0.06),
                blurRadius: 12, offset: const Offset(0, 3))]),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image produit
              ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15)),
                  child: Stack(children: [
                    SizedBox(
                        height: 120, width: double.infinity,
                        child: product.imageUrl.isNotEmpty
                            ? Image.network(product.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ImagePlaceholder(
                                category: product.category, bg: bg, fg: fg))
                            : _ImagePlaceholder(
                            category: product.category, bg: bg, fg: fg)),
                    // Badge catégorie
                    Positioned(top: 8, left: 8,
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: fg.withOpacity(0.4))),
                            child: Text(product.categoryLabel,
                                style: GoogleFonts.nunito(fontSize: 10,
                                    fontWeight: FontWeight.w700, color: fg)))),
                    // Badge rupture
                    if (!product.isAvailable)
                      Positioned.fill(child: Container(
                          color: Colors.black.withOpacity(0.45),
                          child: Center(child: Text('Indisponible',
                              style: GoogleFonts.nunito(fontSize: 12,
                                  fontWeight: FontWeight.w700, color: Colors.white))))),
                  ])),

              // Infos
              Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Text(product.name, maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(fontSize: 13,
                          fontWeight: FontWeight.w800, color: AppColors.t1))),
              const SizedBox(height: 4),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('${product.price.toStringAsFixed(0)} MAD',
                      style: GoogleFonts.nunito(fontSize: 15,
                          fontWeight: FontWeight.w900, color: AppColors.g700))),
              const Spacer(),

              // Bouton panier
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: GestureDetector(
                    onTap: product.isAvailable ? onAddToCart : null,
                    child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                            color: (product.isAvailable && onAddToCart != null)
                                ? AppColors.g700 : AppColors.surface2,
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Row(
                            mainAxisSize: MainAxisSize.min, children: [
                          Icon(onAddToCart != null
                              ? Icons.add_shopping_cart_rounded
                              : Icons.lock_outline_rounded,
                              size: 15,
                              color: (product.isAvailable && onAddToCart != null)
                                  ? Colors.white : AppColors.t4),
                          const SizedBox(width: 5),
                          Text(onAddToCart != null
                              ? 'Ajouter' : 'Connexion requise',
                              style: GoogleFonts.nunito(fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: (product.isAvailable && onAddToCart != null)
                                      ? Colors.white : AppColors.t4)),
                        ])))),
              ),
            ]),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String category;
  final Color bg, fg;
  const _ImagePlaceholder({required this.category,
    required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
      color: bg,
      child: Center(child: Icon(
          category == 'fertilizer' ? Icons.grass_rounded
              : category == 'bio'      ? Icons.eco_rounded
              : Icons.science_outlined,
          size: 40, color: fg.withOpacity(0.5))));
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.t4),
    const SizedBox(height: 16),
    Text('Aucun produit trouvé', style: GoogleFonts.nunito(
        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.t3)),
  ]));
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.t4),
    const SizedBox(height: 12),
    Text('Impossible de charger les produits',
        style: GoogleFonts.nunito(fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.t3)),
    const SizedBox(height: 8),
    TextButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, color: AppColors.g700),
        label: Text('Réessayer', style: GoogleFonts.nunito(
            color: AppColors.g700, fontWeight: FontWeight.w700))),
  ]));
}