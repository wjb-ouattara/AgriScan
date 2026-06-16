import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/marketplace_service.dart';
import '../services/database_service.dart';

// ══════════════════════════════════════════════════════════
//  CART SCREEN — panier
// ══════════════════════════════════════════════════════════

class MarketplaceCartScreen extends StatefulWidget {
  const MarketplaceCartScreen({super.key});

  @override
  State<MarketplaceCartScreen> createState() => _MarketplaceCartScreenState();
}

class _MarketplaceCartScreenState extends State<MarketplaceCartScreen> {
  final _svc = MarketplaceService();

  @override
  Widget build(BuildContext context) {
    final cart = _svc.cart;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.g900,
        elevation: 0,
        title: Text('Mon panier', style: GoogleFonts.nunito(
            fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.g900)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: const Divider(color: AppColors.border, height: 1)),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
                onPressed: () {
                  _svc.clearCart();
                  setState(() {});
                },
                child: Text('Vider', style: GoogleFonts.nunito(
                    color: const Color(0xFFD63A1A),
                    fontWeight: FontWeight.w700))),
        ],
      ),
      body: cart.isEmpty
          ? const _EmptyCart()
          : Column(children: [
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cart.length,
          itemBuilder: (_, i) => _CartTile(
            item: cart[i],
            onRemove: () { _svc.removeFromCart(cart[i].product.id); setState(() {}); },
            onQtyChange: (q) {
              _svc.updateQuantity(cart[i].product.id, q);
              setState(() {});
            },
          ),
        )),
        _CartSummary(
          total: _svc.cartTotal,
          itemCount: _svc.cartCount,
          onCheckout: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MarketplaceOrderScreen())),
        ),
      ]),
    );
  }
}

class _CartTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChange;
  const _CartTile({required this.item,
    required this.onRemove, required this.onQtyChange});

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        // Image
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 70, height: 70,
                child: p.imageUrl.isNotEmpty
                    ? Image.network(p.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: AppColors.g50,
                        child: const Icon(Icons.science_outlined,
                            color: AppColors.g300, size: 28)))
                    : Container(color: AppColors.g50,
                    child: const Icon(Icons.science_outlined,
                        color: AppColors.g300, size: 28)))),
        const SizedBox(width: 12),
        // Info
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(fontSize: 14,
                  fontWeight: FontWeight.w800, color: AppColors.t1)),
          const SizedBox(height: 2),
          Text('${p.price.toStringAsFixed(0)} MAD',
              style: GoogleFonts.nunito(fontSize: 13,
                  fontWeight: FontWeight.w700, color: AppColors.g700)),
          const SizedBox(height: 8),
          // Sélecteur quantité compact
          Row(mainAxisSize: MainAxisSize.min, children: [
            _SmallBtn(Icons.remove_rounded,
                onTap: () => onQtyChange(item.quantity - 1)),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('${item.quantity}', style: GoogleFonts.nunito(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.t1))),
            _SmallBtn(Icons.add_rounded,
                onTap: () => onQtyChange(item.quantity + 1)),
          ]),
        ])),
        // Sous-total + suppression
        Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.t4)),
          const SizedBox(height: 24),
          Text('${item.subtotal.toStringAsFixed(0)} MAD',
              style: GoogleFonts.nunito(fontSize: 15,
                  fontWeight: FontWeight.w900, color: AppColors.g900)),
        ]),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallBtn(this.icon, {required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border)),
          child: Icon(icon, size: 14, color: AppColors.t2)));
}

class _CartSummary extends StatelessWidget {
  final double      total;
  final int         itemCount;
  final VoidCallback onCheckout;
  const _CartSummary({required this.total,
    required this.itemCount, required this.onCheckout});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1.5)),
          boxShadow: [BoxShadow(color: AppColors.g700.withOpacity(0.08),
              blurRadius: 20, offset: const Offset(0, -4))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('$itemCount article${itemCount > 1 ? 's' : ''}',
              style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t3)),
          const Spacer(),
          Text('${total.toStringAsFixed(2)} MAD',
              style: GoogleFonts.nunito(fontSize: 20,
                  fontWeight: FontWeight.w900, color: AppColors.g900)),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: onCheckout,
              icon: const Icon(Icons.payment_rounded),
              label: Text('Passer la commande', style: GoogleFonts.nunito(
                  fontSize: 16, fontWeight: FontWeight.w800)),
            )),
      ]));
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.shopping_cart_outlined, size: 72, color: AppColors.t4),
    const SizedBox(height: 16),
    Text('Votre panier est vide', style: GoogleFonts.nunito(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.t3)),
    const SizedBox(height: 8),
    Text('Ajoutez des produits depuis la boutique.',
        style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t4)),
    const SizedBox(height: 20),
    TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.store_outlined, color: AppColors.g700),
        label: Text('Voir la boutique', style: GoogleFonts.nunito(
            color: AppColors.g700, fontWeight: FontWeight.w700))),
  ]));
}

// ══════════════════════════════════════════════════════════
//  ORDER SCREEN — formulaire de commande + confirmation
// ══════════════════════════════════════════════════════════

class MarketplaceOrderScreen extends StatefulWidget {
  const MarketplaceOrderScreen({super.key});
  @override
  State<MarketplaceOrderScreen> createState() => _MarketplaceOrderScreenState();
}

class _MarketplaceOrderScreenState extends State<MarketplaceOrderScreen> {
  final _svc = MarketplaceService();
  final _db  = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();

  bool   _loading         = false;
  Order? _confirmedOrder;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    try {
      final userId = await _db.getCurrentUserId();
      if (userId == null || !mounted) return;
      final user = await _db.getUser(userId);
      if (!mounted || user == null) return;
      setState(() {
        _nameCtrl.text = user.name ?? '';
        _cityCtrl.text = user.region;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Fermer le clavier pour que les erreurs de validation soient visibles
    FocusScope.of(context).unfocus();

    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_svc.cart.isEmpty) {
      setState(() => _errorMessage = 'Votre panier est vide. Retournez à la boutique.');
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = await _db.getCurrentUserId() ?? '';
      final order = await _svc.placeOrder(
        userId          : userId,
        deliveryName    : _nameCtrl.text.trim(),
        deliveryPhone   : _phoneCtrl.text.trim(),
        deliveryAddress : _addressCtrl.text.trim(),
        deliveryCity    : _cityCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _confirmedOrder = order;
        _loading        = false;
        _errorMessage   = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading      = false;
        _errorMessage = 'Erreur lors de la commande : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmedOrder != null) {
      return _ConfirmationView(order: _confirmedOrder!);
    }

    final cartItems = _svc.cart;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.g900,
        elevation: 0,
        title: Text('Finaliser la commande', style: GoogleFonts.nunito(
            fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.g900)),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(color: AppColors.border, height: 1)),
      ),
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Récapitulatif panier ─────────────────────
            if (cartItems.isEmpty)
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF0D6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8920A))),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFE8920A)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                        'Votre panier est vide. Retournez à la boutique pour ajouter des produits.',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 13, color: const Color(0xFFB36B00)))),
                  ]))
            else
              _OrderRecap(cart: cartItems, total: _svc.cartTotal),

            const SizedBox(height: 20),

            // ── Formulaire de livraison ───────────────────
            Text('Informations de livraison',
                style: GoogleFonts.nunito(
                    fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.g900)),
            const SizedBox(height: 14),

            Form(
                key: _formKey,
                child: Column(children: [
                  _Field(
                      ctrl: _nameCtrl, label: 'Nom complet',
                      icon: Icons.person_outline_rounded,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                  const SizedBox(height: 12),
                  _Field(
                      ctrl: _phoneCtrl, label: 'Téléphone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                      (v == null || v.trim().length < 8)
                          ? 'Numéro invalide (min. 8 chiffres)' : null),
                  const SizedBox(height: 12),
                  _Field(
                      ctrl: _addressCtrl, label: 'Adresse complète',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                  const SizedBox(height: 12),
                  _Field(
                      ctrl: _cityCtrl, label: 'Ville',
                      icon: Icons.location_city_outlined,
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
                ])),

            const SizedBox(height: 20),

            // ── Message d'erreur global ───────────────────
            if (_errorMessage != null)
              Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEE8E4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD63A1A))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFD63A1A), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!,
                        style: GoogleFonts.nunitoSans(
                            fontSize: 13, color: const Color(0xFFD63A1A)))),
                  ])),

            // ── Bouton confirmer ──────────────────────────
            SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  onPressed: (_loading || cartItems.isEmpty) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.t4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: _loading
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                      _loading ? 'Traitement en cours…' : 'Confirmer la commande',
                      style: GoogleFonts.nunito(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                )),
            const SizedBox(height: 8),
            Center(child: Text(
                'Vous recevrez une confirmation par téléphone',
                style: GoogleFonts.nunitoSans(fontSize: 12, color: AppColors.t4))),
          ])),
    );
  }
}

class _OrderRecap extends StatelessWidget {
  final List<CartItem> cart;
  final double total;
  const _OrderRecap({required this.cart, required this.total});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Récapitulatif', style: GoogleFonts.nunito(
            fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
        const SizedBox(height: 12),
        ...cart.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text('${i.product.name} × ${i.quantity}',
                  style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t2))),
              Text('${i.subtotal.toStringAsFixed(0)} MAD',
                  style: GoogleFonts.nunito(fontSize: 13,
                      fontWeight: FontWeight.w700, color: AppColors.t1)),
            ]))),
        const Divider(color: AppColors.border),
        Row(children: [
          Text('Total', style: GoogleFonts.nunito(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
          const Spacer(),
          Text('${total.toStringAsFixed(2)} MAD',
              style: GoogleFonts.nunito(fontSize: 18,
                  fontWeight: FontWeight.w900, color: AppColors.g700)),
        ]),
      ]));
}

// _FieldTitle remplacé par Text inline dans _MarketplaceOrderScreenState

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String   label;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  const _Field({required this.ctrl, required this.label,
    required this.icon, this.keyboardType = TextInputType.text,
    this.maxLines = 1, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.nunitoSans(fontSize: 15, color: AppColors.t1),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunitoSans(color: AppColors.t3),
        prefixIcon: Icon(icon, color: AppColors.t3, size: 20),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.g700, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD63A1A))),
      ));
}

// ── Écran de confirmation ─────────────────────────────────

class _ConfirmationView extends StatelessWidget {
  final Order order;
  const _ConfirmationView({required this.order});

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: AppColors.g700, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.g700.withOpacity(0.35),
                        blurRadius: 24, offset: const Offset(0, 6))]),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 40)),
            const SizedBox(height: 24),
            Text('Commande confirmée !', style: GoogleFonts.nunito(
                fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.g900)),
            const SizedBox(height: 10),
            Text('Votre commande #${order.id.substring(0, 8).toUpperCase()} '
                'a été enregistrée.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunitoSans(fontSize: 15, color: AppColors.t2,
                    height: 1.6)),
            const SizedBox(height: 28),
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.g50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.g300)),
                child: Column(children: [
                  _ConfRow('Livraison à', order.deliveryName),
                  _ConfRow('Adresse', '${order.deliveryAddress}, ${order.deliveryCity}'),
                  _ConfRow('Contact', order.deliveryPhone),
                  _ConfRow('Total', '${order.total.toStringAsFixed(2)} MAD'),
                  _ConfRow('Statut', order.statusLabel),
                ])),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context)
                    ..pop()..pop()..pop(),
                  icon: const Icon(Icons.storefront_rounded),
                  label: Text('Retour à la boutique', style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800)),
                )),
          ]))));
}

class _ConfRow extends StatelessWidget {
  final String label, value;
  const _ConfRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text('$label :', style: GoogleFonts.nunitoSans(
            fontSize: 13, color: AppColors.t3)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, textAlign: TextAlign.end,
            style: GoogleFonts.nunito(fontSize: 13,
                fontWeight: FontWeight.w700, color: AppColors.t1))),
      ]));
}