import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';
import 'knowledge_base_screen.dart';

// ══════════════════════════════════════════════════════════
//  CHAT HISTORY DRAWER
//  Panneau latéral (façon ChatGPT) listant les conversations
//  groupées par date, avec menu "..." Renommer/Supprimer.
// ══════════════════════════════════════════════════════════

class ChatHistoryDrawer extends StatelessWidget {
  final List<ChatConversation> conversations;
  final String? activeId;
  final VoidCallback onNewConversation;
  final void Function(String id) onOpenConversation;
  final void Function(ChatConversation conv) onRename;
  final void Function(ChatConversation conv) onDelete;

  const ChatHistoryDrawer({
    super.key,
    required this.conversations,
    required this.activeId,
    required this.onNewConversation,
    required this.onOpenConversation,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sections = _groupByDate(conversations);

    return Drawer(
      backgroundColor: AppColors.surface,
      width: MediaQuery.of(context).size.width * 0.84,
      child: SafeArea(child: Column(children: [
        // ── En-tête ───────────────────────────────────
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(children: [
              Text('Conversations', style: GoogleFonts.nunito(
                  fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.g900)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.t3)),
            ])),

        // ── Nouvelle conversation ─────────────────────
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: GestureDetector(
                onTap: () {
                  onNewConversation();
                  Navigator.pop(context);
                },
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: AppColors.g50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.g300, width: 1.5)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_rounded, size: 18, color: AppColors.g700),
                      const SizedBox(width: 8),
                      Text('Nouvelle conversation', style: GoogleFonts.nunito(
                          fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.g700)),
                    ])))),

        const Divider(height: 1, color: AppColors.border),

        // ── Liste groupée par date ─────────────────────
        Expanded(child: conversations.isEmpty
            ? _buildEmpty()
            : ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: sections.entries.expand((entry) => [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(entry.key, style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.t3, letterSpacing: 1))),
              ...entry.value.map((c) => _ConversationTile(
                  conversation: c,
                  active: c.id == activeId,
                  onTap: () {
                    onOpenConversation(c.id);
                    Navigator.pop(context);
                  },
                  onRename: () => onRename(c),
                  onDelete: () => onDelete(c))),
            ]).toList())),

        const Divider(height: 1, color: AppColors.border),

        // ── Base de connaissances ──────────────────────
        InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const KnowledgeBaseScreen()));
            },
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Text('📚', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Text('Base de connaissances', style: GoogleFonts.nunito(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.t1)),
                ]))),
      ])),
    );
  }

  Widget _buildEmpty() => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('💬', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 12),
        Text('Aucune conversation', style: GoogleFonts.nunito(
            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.t2)),
        const SizedBox(height: 4),
        Text('Posez votre première question\nà l\'assistant agronome.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(fontSize: 12.5, color: AppColors.t3, height: 1.4)),
      ]));

  // ── Regroupement par date (Aujourd'hui / Hier / dd/mm/yyyy) ──
  Map<String, List<ChatConversation>> _groupByDate(List<ChatConversation> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<ChatConversation>>{};
    for (final c in list) {
      final d = c.updatedAt;
      final day = DateTime(d.year, d.month, d.day);
      String key;
      if (day == today) {
        key = 'Aujourd\'hui';
      } else if (day == yesterday) {
        key = 'Hier';
      } else {
        key = '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }
}

// ══════════════════════════════════════════════════════════
//  CARTE CONVERSATION — avec menu "..." Renommer/Supprimer
// ══════════════════════════════════════════════════════════

class _ConversationTile extends StatelessWidget {
  final ChatConversation conversation;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.active,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.md),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(100))),
              _MenuAction(emoji: '✏️', label: 'Renommer',
                  onTap: () { Navigator.pop(ctx); onRename(); }),
              _MenuAction(emoji: '🗑️', label: 'Supprimer',
                  color: AppColors.red,
                  onTap: () { Navigator.pop(ctx); onDelete(); }),
              const SizedBox(height: 8),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final time = '${conversation.updatedAt.hour.toString().padLeft(2, '0')}:'
        '${conversation.updatedAt.minute.toString().padLeft(2, '0')}';
    final preview = (conversation.preview ?? '').replaceAll('\n', ' ');

    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: active ? AppColors.g50 : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: AppColors.g300, width: 1.5) : null),
        child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: active ? AppColors.g700 : AppColors.surface2,
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.chat_bubble_outline_rounded, size: 16,
                          color: active ? Colors.white : AppColors.t3)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(conversation.displayTitle, style: GoogleFonts.nunito(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: active ? AppColors.g700 : AppColors.t1),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(preview, style: GoogleFonts.nunitoSans(
                          fontSize: 11.5, color: AppColors.t3),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ])),
                  const SizedBox(width: 6),
                  Text(time, style: GoogleFonts.nunitoSans(
                      fontSize: 11, color: AppColors.t4)),
                  const SizedBox(width: 4),
                  GestureDetector(
                      onTap: () => _showMenu(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.more_vert_rounded, size: 16, color: AppColors.t4))),
                ]))));
  }
}

class _MenuAction extends StatelessWidget {
  final String emoji, label;
  final Color? color;
  final VoidCallback onTap;
  const _MenuAction({required this.emoji, required this.label,
    this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    color: (color ?? AppColors.g700).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 17)))),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.nunito(fontSize: 14,
                fontWeight: FontWeight.w700, color: color ?? AppColors.t1)),
          ])));
}