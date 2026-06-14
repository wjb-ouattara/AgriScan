import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/chat_service.dart';
import '../services/knowledge_base_service.dart';
import '../utils/disease_meta.dart';
import 'knowledge_base_screen.dart';

// ══════════════════════════════════════════════════════════
//  CHAT SCREEN
//  Assistant agronome conversationnel — texte uniquement
//  pour cette version. Contextualisé (profil agricole +
//  dernier diagnostic) et appuyé sur la base RAG.
// ══════════════════════════════════════════════════════════

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db   = DatabaseService();
  final _chat = ChatService();
  final _kb   = KnowledgeBaseService();
  static const _uuid = Uuid();

  final _controller       = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  List<KnowledgeDocument> _allDocs = [];
  bool _loading = true;
  bool _sending = false;

  String _userName = 'Agriculteur';
  String _region   = 'Maroc';
  String _culture  = 'Maïs';
  String _climate  = 'Tempéré';
  String _soil     = 'Argileux';
  String _season   = 'Été';
  ScanRecord? _lastScan;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _kb.seedIfEmpty();
    await _loadContext();
    await _loadLastScan();
    _allDocs = await _kb.getAllDocuments();
    final history = await _chat.loadHistory();
    if (mounted) setState(() {
      _messages = history;
      _loading  = false;
    });
    _scrollToBottom(animated: false);
  }

  Future<void> _loadContext() async {
    final region  = await _db.getSetting('ctx_region');
    final culture = await _db.getSetting('ctx_culture');
    final climate = await _db.getSetting('ctx_climate');
    final soil    = await _db.getSetting('ctx_soil');
    final season  = await _db.getSetting('ctx_season');

    String name = 'Agriculteur';
    final userId = await _db.getCurrentUserId();
    if (userId != null) {
      final user = await _db.getUser(userId);
      if (user?.name != null && user!.name!.trim().isNotEmpty) {
        name = user.name!.trim().split(' ').first;
      }
    }

    if (mounted) setState(() {
      _region  = region  ?? 'Maroc';
      _culture = culture ?? 'Maïs';
      _climate = climate ?? 'Tempéré';
      _soil    = soil    ?? 'Argileux';
      _season  = season  ?? 'Été';
      _userName = name;
    });
  }

  Future<void> _loadLastScan() async {
    final scans = await _db.getScans(limit: 1);
    if (mounted && scans.isNotEmpty) setState(() => _lastScan = scans.first);
  }

  ChatContext _buildContext() {
    String? diseaseLabel, dateLabel;
    if (_lastScan != null) {
      diseaseLabel = DiseaseMeta.of(_lastScan!.diseaseName).labelFr;
      dateLabel = '${_lastScan!.createdAt.day.toString().padLeft(2, '0')}/'
          '${_lastScan!.createdAt.month.toString().padLeft(2, '0')}';
    }
    return ChatContext(
      region: _region, culture: _culture, climate: _climate,
      soil: _soil, season: _season,
      lastScanDisease   : diseaseLabel,
      lastScanPlant     : _lastScan?.plantType,
      lastScanDate      : dateLabel,
      lastScanConfidence: _lastScan?.confidence,
    );
  }

  // ── Suggestions affichées quand la conversation est vide ──
  List<String> get _suggestions {
    final list = <String>[];
    if (_lastScan != null) {
      final meta = DiseaseMeta.of(_lastScan!.diseaseName);
      if (!meta.isHealthy) {
        list.add('Comment traiter ${meta.labelFr.toLowerCase()} '
            'sur mon ${_culture.toLowerCase()} ?');
      }
    }
    list.addAll([
      'Quand semer le maïs cette saison ?',
      'Comment fertiliser mon champ ?',
      'Quels sont les signes d\'un maïs sain ?',
    ]);
    return list;
  }

  // ── Envoi ──────────────────────────────────────────────
  Future<void> _send([String? quick]) async {
    final text = (quick ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    final history = List<ChatMessage>.from(_messages);
    final userMsg = ChatMessage(
        id: _uuid.v4(), role: 'user', content: text, createdAt: DateTime.now());

    setState(() {
      _messages.add(userMsg);
      _sending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final reply = await _chat.sendMessage(
        text: text, history: history, context: _buildContext());

    if (mounted) setState(() {
      _messages.add(reply);
      _sending = false;
    });
    _scrollToBottom();
  }

  Future<void> _newConversation() async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Nouvelle conversation', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800)),
            content: Text('L\'historique actuel sera effacé. Continuer ?',
                style: GoogleFonts.nunitoSans(fontSize: 14)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g700, elevation: 0),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Effacer',
                      style: TextStyle(color: Colors.white))),
            ]));
    if (confirm == true) {
      await _chat.clearHistory();
      if (mounted) setState(() => _messages = []);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(pos,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(pos);
      }
    });
  }

  // ── Affiche le contenu d'une source RAG ────────────────
  void _showSource(String title) {
    final doc = _allDocs.where((d) =>
    title.startsWith(d.title) || d.title == title).toList();
    final found = doc.isEmpty ? null : doc.first;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
            expand: false,
            builder: (_, scrollCtrl) => Container(
                decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: ListView(controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(child: Container(width: 40, height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: AppColors.border,
                              borderRadius: BorderRadius.circular(100)))),
                      Row(children: [
                        const Text('📚', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(title, style: GoogleFonts.nunito(
                            fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.g900))),
                      ]),
                      const SizedBox(height: 12),
                      Text(found?.content ?? 'Contenu indisponible.',
                          style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t2,
                              height: 1.6)),
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.g600))
            : _messages.isEmpty
            ? _buildEmptyState()
            : _buildMessageList()),
        if (_sending) _buildTypingIndicator(),
        _buildInputBar(),
      ])),
    );
  }

  // ── En-tête ─────────────────────────────────────────────
  Widget _buildHeader() => Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1E3820), Color(0xFF2D5A30)])),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Assistant Agronome IA', style: GoogleFonts.nunito(
                    fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
                Text('Propulsé par AgriScan · ${_culture}',
                    style: GoogleFonts.nunitoSans(fontSize: 12,
                        color: Colors.white.withOpacity(0.7))),
              ])),
              IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const KnowledgeBaseScreen())),
                  icon: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 22)),
              IconButton(
                  onPressed: _messages.isEmpty ? null : _newConversation,
                  icon: Icon(Icons.add_comment_rounded,
                      color: _messages.isEmpty
                          ? Colors.white.withOpacity(0.3) : Colors.white, size: 22)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _headerChip('📍', _region),
              const SizedBox(width: 8),
              _headerChip('🌤️', _climate),
              const SizedBox(width: 8),
              _headerChip('🌱', _culture),
            ]),
          ])));

  Widget _headerChip(String emoji, String text) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withOpacity(0.18))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 5),
        Flexible(child: Text(text, style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            overflow: TextOverflow.ellipsis)),
      ])));

  // ── État vide ────────────────────────────────────────────
  Widget _buildEmptyState() => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(children: [
        Container(width: 88, height: 88,
            decoration: BoxDecoration(
                color: AppColors.g50, shape: BoxShape.circle,
                border: Border.all(color: AppColors.g300, width: 1.5)),
            child: const Center(child: Text('🌾', style: TextStyle(fontSize: 40)))),
        const SizedBox(height: 20),
        Text('Bonjour, $_userName 👋', style: GoogleFonts.nunito(
            fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.g900)),
        const SizedBox(height: 8),
        Text('Posez votre question agronomique. Je connais votre contexte '
            'agricole et vos derniers diagnostics AgriScan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(fontSize: 13.5, color: AppColors.t3, height: 1.5)),
        const SizedBox(height: 24),
        if (_lastScan != null) _buildLastScanBanner(),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: _suggestions.map((s) => _SuggestionChip(
                text: s, onTap: () => _send(s))).toList()),
      ]));

  Widget _buildLastScanBanner() {
    final meta = DiseaseMeta.of(_lastScan!.diseaseName);
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: meta.color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: meta.color.withOpacity(0.25))),
        child: Row(children: [
          Text(meta.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dernier diagnostic', style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.t3,
                letterSpacing: 0.5)),
            Text(meta.labelFr, style: GoogleFonts.nunito(
                fontSize: 14, fontWeight: FontWeight.w800, color: meta.color)),
          ])),
          Text('${(_lastScan!.confidence * 100).round()}%', style: GoogleFonts.nunito(
              fontSize: 14, fontWeight: FontWeight.w800, color: meta.color)),
        ]));
  }

  // ── Liste de messages ────────────────────────────────────
  Widget _buildMessageList() => ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(
          message: _messages[i],
          onSourceTap: _showSource));

  // ── Indicateur de saisie ─────────────────────────────────
  Widget _buildTypingIndicator() => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1.5)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                      color: AppColors.g600, strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('L\'assistant réfléchit...', style: GoogleFonts.nunitoSans(
                  fontSize: 12.5, color: AppColors.t3, fontStyle: FontStyle.italic)),
            ])),
      ]));

  // ── Barre de saisie ───────────────────────────────────────
  Widget _buildInputBar() => Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5))),
      child: Row(children: [
        Expanded(child: TextField(
            controller: _controller,
            minLines: 1, maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t1),
            decoration: InputDecoration(
                hintText: 'Posez votre question agronomique...',
                hintStyle: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t4),
                filled: true, fillColor: AppColors.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none)))),
        const SizedBox(width: 8),
        GestureDetector(
            onTap: _sending ? null : () => _send(),
            child: Container(width: 46, height: 46,
                decoration: BoxDecoration(
                    color: _sending ? AppColors.surface2 : AppColors.g700,
                    shape: BoxShape.circle),
                child: Icon(Icons.send_rounded,
                    color: _sending ? AppColors.t4 : Colors.white, size: 20))),
      ]));
}

// ══════════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════════

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: AppShadows.sm),
          child: Text(text, style: GoogleFonts.nunito(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.g700))));
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String title) onSourceTap;
  const _MessageBubble({required this.message, required this.onSourceTap});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: isUser
                  ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: isUser ? AppColors.g700 : AppColors.surface,
                                borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                                    bottomRight: Radius.circular(isUser ? 4 : 16)),
                                border: isUser ? null : Border.all(
                                    color: AppColors.border, width: 1.5),
                                boxShadow: isUser ? null : AppShadows.sm),
                            child: Text(message.content, style: GoogleFonts.nunitoSans(
                                fontSize: 14, height: 1.5,
                                color: isUser ? Colors.white : AppColors.t1)))),
                  ]),
              if (!isUser && message.sources.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6,
                    children: message.sources.map((s) => GestureDetector(
                        onTap: () => onSourceTap(s),
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppColors.g50,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.g300)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('📚', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 4),
                              Text(s, style: GoogleFonts.nunito(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: AppColors.g700)),
                            ])))).toList()),
              ],
            ]));
  }
}