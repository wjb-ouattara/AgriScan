import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

// ══════════════════════════════════════════════════════════
//  MARKETPLACE SERVICE
//  Gère : produits, panier, commandes
//  Images : Supabase Storage (URL publique uniquement)
//  Commandes offline : SQLite local + sync Supabase
// ══════════════════════════════════════════════════════════

// ── Modèles ───────────────────────────────────────────────

class Product {
  final String   id;
  final String   name;
  final String   description;
  final double   price;
  final String   category;       // 'fungicide' | 'pesticide' | 'fertilizer' | 'bio'
  final int      stockQty;
  final String   imageUrl;       // URL publique Supabase Storage
  final String   vendorId;
  final String   vendorName;
  final String   usage;          // Mode d'utilisation
  final List<String> targetDiseases; // Codes maladies ciblées (f_NLB, f_RUST…)
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockQty,
    required this.imageUrl,
    required this.vendorId,
    required this.vendorName,
    required this.usage,
    required this.targetDiseases,
    required this.createdAt,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id             : m['id'] as String,
    name           : m['name'] as String? ?? '',
    description    : m['description'] as String? ?? '',
    price          : (m['price'] as num?)?.toDouble() ?? 0.0,
    category       : m['category'] as String? ?? '',
    stockQty       : m['stock_qty'] as int? ?? 0,
    imageUrl       : m['image_url'] as String? ?? '',
    vendorId       : m['vendor_id'] as String? ?? '',
    vendorName     : m['vendor_name'] as String? ?? '',
    usage          : m['usage'] as String? ?? '',
    targetDiseases : (m['target_diseases'] as String? ?? '')
        .split(',').where((s) => s.isNotEmpty).toList(),
    createdAt      : DateTime.tryParse(m['created_at'] as String? ?? '')
        ?? DateTime.now(),
  );

  bool get isAvailable => stockQty > 0;

  String get categoryLabel => switch (category) {
    'fungicide'  => 'Fongicide',
    'pesticide'  => 'Pesticide',
    'fertilizer' => 'Engrais',
    'bio'        => 'Bio',
    _            => category,
  };
}

// ─────────────────────────────────────────────────────────

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

// ─────────────────────────────────────────────────────────

class Order {
  final String   id;
  final String   userId;
  final List<OrderLine> lines;
  final double   total;
  final String   status;       // 'pending' | 'confirmed' | 'shipped' | 'delivered'
  final String   deliveryName;
  final String   deliveryPhone;
  final String   deliveryAddress;
  final String   deliveryCity;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.userId,
    required this.lines,
    required this.total,
    required this.status,
    required this.deliveryName,
    required this.deliveryPhone,
    required this.deliveryAddress,
    required this.deliveryCity,
    required this.createdAt,
  });

  factory Order.fromMap(Map<String, dynamic> m) => Order(
    id              : m['id'] as String,
    userId          : m['user_id'] as String? ?? '',
    lines           : (jsonDecode(m['lines'] as String? ?? '[]') as List)
        .map((l) => OrderLine.fromMap(l as Map<String, dynamic>))
        .toList(),
    total           : (m['total'] as num?)?.toDouble() ?? 0.0,
    status          : m['status'] as String? ?? 'pending',
    deliveryName    : m['delivery_name'] as String? ?? '',
    deliveryPhone   : m['delivery_phone'] as String? ?? '',
    deliveryAddress : m['delivery_address'] as String? ?? '',
    deliveryCity    : m['delivery_city'] as String? ?? '',
    createdAt       : DateTime.tryParse(m['created_at'] as String? ?? '')
        ?? DateTime.now(),
  );

  String get statusLabel => switch (status) {
    'pending'   => 'En attente',
    'confirmed' => 'Confirmée',
    'shipped'   => 'Expédiée',
    'delivered' => 'Livrée',
    _           => status,
  };

  Map<String, dynamic> toMap() => {
    'id'              : id,
    'user_id'         : userId,
    'lines'           : jsonEncode(lines.map((l) => l.toMap()).toList()),
    'total'           : total,
    'status'          : status,
    'delivery_name'   : deliveryName,
    'delivery_phone'  : deliveryPhone,
    'delivery_address': deliveryAddress,
    'delivery_city'   : deliveryCity,
    'created_at'      : createdAt.toIso8601String(),
    'synced'          : 0,
  };
}

class OrderLine {
  final String productId;
  final String productName;
  final int    quantity;
  final double unitPrice;

  const OrderLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => unitPrice * quantity;

  factory OrderLine.fromMap(Map<String, dynamic> m) => OrderLine(
    productId   : m['product_id'] as String,
    productName : m['product_name'] as String,
    quantity    : m['quantity'] as int,
    unitPrice   : (m['unit_price'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'product_id'  : productId,
    'product_name': productName,
    'quantity'    : quantity,
    'unit_price'  : unitPrice,
  };
}

// ══════════════════════════════════════════════════════════
//  MarketplaceService — singleton
// ══════════════════════════════════════════════════════════

class MarketplaceService {
  static final MarketplaceService _i = MarketplaceService._();
  factory MarketplaceService() => _i;
  MarketplaceService._();

  static const _uuid = Uuid();

  // ── Panier en mémoire (état de session) ───────────────
  final List<CartItem> _cart = [];
  List<CartItem> get cart => List.unmodifiable(_cart);

  int get cartCount => _cart.fold(0, (s, i) => s + i.quantity);
  double get cartTotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

  // ── Produits : catalogue Supabase ─────────────────────

  /// Récupère tous les produits depuis Supabase.
  /// Fallback : catalogue de démonstration embarqué si hors-ligne.
  Future<List<Product>> fetchProducts({String? diseaseCode}) async {
    try {
      final client = Supabase.instance.client;
      var query = client
          .from('products')
          .select('*')
          .order('created_at', ascending: false);

      final data = await query.limit(50);
      final products = (data as List)
          .map((m) => Product.fromMap(m as Map<String, dynamic>))
          .toList();

      // Filtre optionnel : produits recommandés pour une maladie
      if (diseaseCode != null && diseaseCode.isNotEmpty) {
        return products
            .where((p) => p.targetDiseases.contains(diseaseCode))
            .toList();
      }
      return products;
    } catch (_) {
      // Hors-ligne ou table absente → catalogue de démo
      return _demoProducts(diseaseCode);
    }
  }

  /// Récupère un produit par ID.
  Future<Product?> fetchProductById(String id) async {
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('products')
          .select('*')
          .eq('id', id)
          .single();
      return Product.fromMap(data as Map<String, dynamic>);
    } catch (_) {
      return _demoProducts(null).where((p) => p.id == id).firstOrNull;
    }
  }

  // ── Panier ────────────────────────────────────────────

  void addToCart(Product product, {int qty = 1}) {
    final existing = _cart.where((i) => i.product.id == product.id).firstOrNull;
    if (existing != null) {
      existing.quantity += qty;
    } else {
      _cart.add(CartItem(product: product, quantity: qty));
    }
  }

  void updateQuantity(String productId, int qty) {
    if (qty <= 0) {
      _cart.removeWhere((i) => i.product.id == productId);
    } else {
      final item = _cart.where((i) => i.product.id == productId).firstOrNull;
      if (item != null) item.quantity = qty;
    }
  }

  void removeFromCart(String productId) =>
      _cart.removeWhere((i) => i.product.id == productId);

  void clearCart() => _cart.clear();

  // ── Commandes ─────────────────────────────────────────

  /// Crée une commande à partir du panier actuel.
  /// Persiste localement (SQLite) et tente une sync Supabase.
  Future<Order> placeOrder({
    required String userId,
    required String deliveryName,
    required String deliveryPhone,
    required String deliveryAddress,
    required String deliveryCity,
  }) async {
    if (_cart.isEmpty) throw Exception('Le panier est vide.');

    final order = Order(
      id              : _uuid.v4(),
      userId          : userId,
      lines           : _cart.map((i) => OrderLine(
        productId   : i.product.id,
        productName : i.product.name,
        quantity    : i.quantity,
        unitPrice   : i.product.price,
      )).toList(),
      total           : cartTotal,
      status          : 'pending',
      deliveryName    : deliveryName,
      deliveryPhone   : deliveryPhone,
      deliveryAddress : deliveryAddress,
      deliveryCity    : deliveryCity,
      createdAt       : DateTime.now(),
    );

    // 1. Persister localement
    await DatabaseService().saveOrder(order.toMap());

    // 2. Tenter sync Supabase
    try {
      final client = Supabase.instance.client;
      await client.from('orders').insert(order.toMap());
      await DatabaseService().markOrderSynced(order.id);
    } catch (_) {
      // Hors-ligne : sera re-synchronisé lors de la prochaine connexion
    }

    clearCart();
    return order;
  }

  /// Récupère l'historique des commandes d'un utilisateur (SQLite local).
  Future<List<Order>> fetchOrders(String userId) async {
    final rows = await DatabaseService().getOrders(userId);
    return rows.map((m) => Order.fromMap(m)).toList();
  }

  // ── Catalogue de démonstration (offline/dev) ──────────

  List<Product> _demoProducts(String? diseaseCode) {
    final all = [
      Product(
        id: 'demo-1', name: 'Amistar Xtra 280 SC',
        description: 'Fongicide systémique à double mode d\'action contre les '
            'principales maladies foliaires du maïs. Formulation liquide concentrée.',
        price: 320.0, category: 'fungicide', stockQty: 48,
        imageUrl: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400',
        vendorId: 'v1', vendorName: 'AgroMaroc Distribution',
        usage: 'Diluer 0,8 L/ha dans 200 L d\'eau. Appliquer en début de '
            'symptômes. Max 2 applications par saison.',
        targetDiseases: ['f_NLB', 'f_GLS', 'f_RUST'],
        createdAt: DateTime(2024, 1, 10),
      ),
      Product(
        id: 'demo-2', name: 'Comet 200 EC',
        description: 'Fongicide trifloxystrobine contre la rouille commune '
            'et l\'helminthosporiose. Action préventive et curative.',
        price: 285.0, category: 'fungicide', stockQty: 32,
        imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400',
        vendorId: 'v1', vendorName: 'AgroMaroc Distribution',
        usage: 'Appliquer 0,75 L/ha. Traiter dès l\'apparition des premiers '
            'symptômes ou en préventif.',
        targetDiseases: ['f_RUST', 'f_GLS'],
        createdAt: DateTime(2024, 1, 12),
      ),
      Product(
        id: 'demo-3', name: 'Cuivrol Flowable',
        description: 'Fongicide à base de cuivre pour traitement biologique '
            'contre les maladies fongiques. Certifié agriculture biologique.',
        price: 195.0, category: 'bio', stockQty: 60,
        imageUrl: 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400',
        vendorId: 'v2', vendorName: 'BioAgri Maroc',
        usage: 'Appliquer 3–5 L/ha dilués dans 400 L d\'eau. Renouvelable '
            'tous les 10–14 jours selon pression.',
        targetDiseases: ['f_NLB', 'f_GLS'],
        createdAt: DateTime(2024, 1, 15),
      ),
      Product(
        id: 'demo-4', name: 'Engrais NPK 20-10-10',
        description: 'Engrais granulé équilibré pour maïs. Formulation '
            'enrichie en oligo-éléments (Zn, Mn, B) pour soutenir '
            'la résistance aux maladies.',
        price: 450.0, category: 'fertilizer', stockQty: 120,
        imageUrl: 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=400',
        vendorId: 'v3', vendorName: 'FertiSol Agri',
        usage: 'Épandre 300–400 kg/ha à la préparation du sol. '
            'Complément azote en végétation selon analyse foliaire.',
        targetDiseases: [],
        createdAt: DateTime(2024, 2, 1),
      ),
      Product(
        id: 'demo-5', name: 'Movento 150 OD',
        description: 'Insecticide systémique biphase contre les pucerons '
            'vecteurs du MLN (Maize Lethal Necrosis). Absorption foliaire '
            'et racinaire.',
        price: 380.0, category: 'pesticide', stockQty: 25,
        imageUrl: 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400',
        vendorId: 'v1', vendorName: 'AgroMaroc Distribution',
        usage: 'Diluer 0,75 L/ha. Traiter dès détection des vecteurs '
            '(pucerons), de préférence en soirée.',
        targetDiseases: ['v_MLN', 'v_MSV'],
        createdAt: DateTime(2024, 2, 5),
      ),
      Product(
        id: 'demo-6', name: 'Trichoderma BIO-T',
        description: 'Biofongicide à base de Trichoderma harzianum. '
            'Protège les racines et stimule les défenses naturelles de la plante.',
        price: 145.0, category: 'bio', stockQty: 80,
        imageUrl: 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=400',
        vendorId: 'v2', vendorName: 'BioAgri Maroc',
        usage: 'Traitement semences : 5 g/kg. Traitement sol : 2 kg/ha '
            'dilués dans 400 L d\'eau à l\'irrigation.',
        targetDiseases: ['f_GLS', 'f_NLB'],
        createdAt: DateTime(2024, 2, 8),
      ),
    ];

    if (diseaseCode != null && diseaseCode.isNotEmpty) {
      final filtered = all.where(
              (p) => p.targetDiseases.contains(diseaseCode)).toList();
      return filtered.isEmpty ? all : filtered;
    }
    return all;
  }
}