import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/marketplace_service.dart';
import '../services/database_service.dart';

// ══════════════════════════════════════════════════════════
//  ORDERS HISTORY SCREEN — historique des commandes
// ══════════════════════════════════════════════════════════

class MarketplaceOrdersScreen extends StatefulWidget {
  const MarketplaceOrdersScreen({super.key});

  @override
  State<MarketplaceOrdersScreen> createState() =>
      _MarketplaceOrdersScreenState();
}

class _MarketplaceOrdersScreenState extends State<MarketplaceOrdersScreen> {
  final _svc  = MarketplaceService();
  final _db   = DatabaseService();

  List<Order> _orders = [];
  bool        _loading = true;
  String?     _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = await _db.getCurrentUserId();
      if (userId == null) {
        setState(() { _orders = []; _loading = false; });
        return;
      }
      final orders = await _svc.fetchOrders(userId);
      if (!mounted) return;
      setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.g900,
        elevation: 0,
        title: Text('Mes commandes', style: GoogleFonts.nunito(
            fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.g900)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: const Divider(color: AppColors.border, height: 1)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.g700))
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _orders.isEmpty
          ? const _EmptyView()
          : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (_, i) => _OrderCard(order: _orders[i])),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  static const _statusConfig = {
    'pending'  : (Color(0xFFFEF0D6), Color(0xFFB36B00), Icons.schedule_rounded),
    'confirmed': (Color(0xFFEDF7F0), Color(0xFF0F7A42), Icons.check_circle_outline_rounded),
    'shipped'  : (Color(0xFFE8F0FE), Color(0xFF1A56CC), Icons.local_shipping_outlined),
    'delivered': (Color(0xFFF0F9F1), Color(0xFF2D6530), Icons.done_all_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic) = _statusConfig[order.status]
        ?? (_statusConfig['pending']!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
              color: AppColors.g700.withOpacity(0.05),
              blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        // En-tête de la commande
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.nunito(fontSize: 15,
                        fontWeight: FontWeight.w900, color: AppColors.g900)),
                Text(_formatDate(order.createdAt),
                    style: GoogleFonts.nunitoSans(
                        fontSize: 12, color: AppColors.t3)),
              ]),
              const Spacer(),
              Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(100)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ic, size: 14, color: fg),
                    const SizedBox(width: 5),
                    Text(order.statusLabel, style: GoogleFonts.nunito(
                        fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
                  ])),
            ])),

        const Divider(color: AppColors.border, height: 1),

        // Lignes de commande
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(children: order.lines.map((line) =>
              Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(children: [
                    const Icon(Icons.circle, size: 5, color: AppColors.t4),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        '${line.productName} × ${line.quantity}',
                        style: GoogleFonts.nunitoSans(
                            fontSize: 13, color: AppColors.t2))),
                    Text('${line.subtotal.toStringAsFixed(0)} MAD',
                        style: GoogleFonts.nunito(fontSize: 13,
                            fontWeight: FontWeight.w700, color: AppColors.t1)),
                  ]))).toList()),
        ),

        const Divider(color: AppColors.border, height: 1),

        // Total + livraison
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.t4),
              const SizedBox(width: 4),
              Expanded(child: Text(
                  '${order.deliveryAddress}, ${order.deliveryCity}',
                  style: GoogleFonts.nunitoSans(fontSize: 12,
                      color: AppColors.t4), maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Text('Total : ${order.total.toStringAsFixed(2)} MAD',
                  style: GoogleFonts.nunito(fontSize: 14,
                      fontWeight: FontWeight.w900, color: AppColors.g700)),
            ])),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${dt.day} ${months[dt.month - 1]}. ${dt.year}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.t4),
    const SizedBox(height: 16),
    Text('Aucune commande', style: GoogleFonts.nunito(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.t3)),
    const SizedBox(height: 8),
    Text('Vos commandes apparaîtront ici.',
        style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t4)),
  ]));
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.t4),
    const SizedBox(height: 12),
    Text('Impossible de charger les commandes',
        style: GoogleFonts.nunito(fontSize: 15,
            fontWeight: FontWeight.w700, color: AppColors.t3)),
    const SizedBox(height: 8),
    TextButton.icon(onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, color: AppColors.g700),
        label: Text('Réessayer', style: GoogleFonts.nunito(
            color: AppColors.g700, fontWeight: FontWeight.w700))),
  ]));
}