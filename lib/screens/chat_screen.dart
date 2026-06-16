import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/chat_service.dart';
import '../services/knowledge_base_service.dart';
import '../utils/disease_meta.dart';
import 'chat_history_drawer.dart';

// ══════════════════════════════════════════════════════════
//  CHAT SCREEN
//  Assistant agronome conversationnel — multi-conversations
//  (panneau latéral façon ChatGPT) + saisie vocale (FR).
//  Contextualisé (profil agricole + dernier diagnostic) et
//  appuyé sur la base RAG.
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

  final _scaffoldKey       = GlobalKey<ScaffoldState>();
  final _controller        = TextEditingController();
  final _scrollController  = ScrollController();
  final _speech            = SpeechToText();

  List<ChatMessage> _messages = [];
  List<ChatConversation> _conversations = [];
  List<KnowledgeDocument> _allDocs = [];
  String? _conversationId;

  bool _loading = true;
  bool _sending = false;
  bool _speechAvailable = false;
  bool _listening = false;
  String? _pendingImagePath;  // Image en attente d'envoi

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
    _speech.stop();
    super.dispose();
  }

  Future<void> _init() async {
    await _kb.seedIfEmpty();
    await _loadContext();
    await _loadLastScan();
    _allDocs = await _kb.getAllDocuments();
    await _loadConversations();
    await _initSpeech();
    if (mounted) setState(() => _loading = false);
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

  String get _cultureEmoji {
    final c = _culture.toLowerCase();
    if (c.contains('maïs') || c.contains('maize')) return '🌽';
    if (c.contains('tomate') || c.contains('tomato')) return '🍅';
    return '🌱';
  }

  // ── Suggestions : toujours 4, en grille 2x2.
  //    Si un diagnostic récent est malade, il prend la 1ère place. ──
  List<_Suggestion> get _suggestions {
    final list = <_Suggestion>[];
    if (_lastScan != null) {
      final meta = DiseaseMeta.of(_lastScan!.diseaseName);
      if (!meta.isHealthy) {
        list.add(_Suggestion(
          emoji : meta.emoji,
          label : 'Traiter ma\n${meta.labelFr}',
          prompt: 'Comment traiter ${meta.labelFr.toLowerCase()} '
              'sur mon ${_culture.toLowerCase()} ?',
          accent: meta.color,
        ));
      }
    }
    const generic = [
      _Suggestion(emoji: '📅', label: 'Calendrier\nde semis',
          prompt: 'Quand semer le maïs cette saison ?'),
      _Suggestion(emoji: '💧', label: 'Irrigation\noptimale',
          prompt: 'Comment bien irriguer mon champ ce mois-ci ?'),
      _Suggestion(emoji: '🌡️', label: 'Risque de\ngel',
          prompt: 'Y a-t-il un risque de gel cette nuit pour mes cultures ?'),
      _Suggestion(emoji: '🌿', label: 'Maïs sain :\nles signes',
          prompt: 'Quels sont les signes d\'un maïs en bonne santé ?'),
    ];
    for (final g in generic) {
      if (list.length >= 4) break;
      list.add(g);
    }
    return list.take(4).toList();
  }

  // ════════════════════════════════════════════════════
  //  CONVERSATIONS
  // ════════════════════════════════════════════════════
  Future<void> _loadConversations() async {
    final list = await _chat.listConversations();
    if (mounted) setState(() => _conversations = list);
  }

  Future<void> _openConversation(String id) async {
    final messages = await _chat.loadMessages(id);
    if (mounted) {
      setState(() {
        _conversationId = id;
        _messages = messages;
      });
    }
    _scrollToBottom(animated: false);
  }

  void _startNewConversation() {
    if (_listening) _toggleListening();
    setState(() {
      _conversationId = null;
      _messages = [];
    });
  }

  Future<void> _renameConversation(ChatConversation conv) async {
    final ctrl = TextEditingController(text: conv.title);
    final result = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Renommer la conversation', style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
            content: TextField(
                controller: ctrl, autofocus: true,
                style: GoogleFonts.nunitoSans(fontSize: 14),
                decoration: InputDecoration(
                    hintText: 'Ex : Traitement maïs - Champ Nord',
                    hintStyle: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g700, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white))),
            ]));
    if (result == null || result.isEmpty) return;
    await _chat.renameConversation(conv.id, result);
    await _loadConversations();
  }

  Future<void> _deleteConversation(ChatConversation conv) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Supprimer cette conversation ?', style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
            content: Text('Cette action est irréversible.',
                style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t2)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Supprimer', style: TextStyle(color: Colors.white))),
            ]));
    if (confirm != true) return;
    await _chat.deleteConversation(conv.id);
    if (_conversationId == conv.id) {
      setState(() { _conversationId = null; _messages = []; });
    }
    await _loadConversations();
  }

  // ── Envoi ──────────────────────────────────────────────────────
  Future<void> _send([String? quick]) async {
    final text = (quick ?? _controller.text).trim();
    if ((text.isEmpty && _pendingImagePath == null) || _sending) return;
    if (_listening) await _toggleListening();

    final convId = _conversationId ?? await _chat.createConversation();
    final history = List<ChatMessage>.from(_messages);
    final imagePath = _pendingImagePath;

    final userMsg = ChatMessage(
        id: _uuid.v4(), role: 'user', content: text,
        imagePath: imagePath, createdAt: DateTime.now());

    setState(() {
      _conversationId = convId;
      _messages.add(userMsg);
      _sending = true;
      _pendingImagePath = null;
    });
    _controller.clear();
    _scrollToBottom();

    ChatMessage reply;
    if (imagePath != null) {
      reply = await _chat.sendMessageWithImage(
          conversationId: convId, text: text, imagePath: imagePath,
          history: history, context: _buildContext());
    } else {
      reply = await _chat.sendMessage(
          conversationId: convId, text: text,
          history: history, context: _buildContext());
    }

    if (mounted) setState(() {
      _messages.add(reply);
      _sending = false;
    });
    _scrollToBottom();
    await _loadConversations();
  }

  // ── Picker d'image (caméra ou galerie) ──────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_sending) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _pendingImagePath = picked.path);
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(100))),
              Text('Envoyer une image', style: GoogleFonts.nunito(
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _ImagePickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Caméra',
                    onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); })),
                const SizedBox(width: 12),
                Expanded(child: _ImagePickerOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie',
                    onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); })),
              ]),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ])));
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

  // ════════════════════════════════════════════════════
  //  SAISIE VOCALE (speech-to-text, FR)
  // ════════════════════════════════════════════════════
  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      _speechAvailable = available;
    } catch (_) {
      _speechAvailable = false;
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable || _sending) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    } else {
      setState(() => _listening = true);
      await _speech.listen(
          localeId: 'fr_FR',
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.collapsed(
                  offset: _controller.text.length);
            });
          });
    }
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
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: ChatHistoryDrawer(
        conversations: _conversations,
        activeId: _conversationId,
        onNewConversation: _startNewConversation,
        onOpenConversation: _openConversation,
        onRename: _renameConversation,
        onDelete: _deleteConversation,
      ),
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        if (_listening) _buildListeningBanner(),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Colors.white))),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.menu_rounded,
                          size: 19, color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Assistant Agronome IA', style: GoogleFonts.nunito(
                    fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Propulsé par AgriScan · $_culture',
                    style: GoogleFonts.nunitoSans(fontSize: 12,
                        color: Colors.white.withOpacity(0.7)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              GestureDetector(
                  onTap: _startNewConversation,
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.add_comment_rounded,
                          size: 18, color: Colors.white))),
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

  // ── Bandeau "écoute en cours" ────────────────────────────
  Widget _buildListeningBanner() => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.red.withOpacity(0.08),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _PulsingDot(),
        const SizedBox(width: 8),
        Text('Je vous écoute… parlez maintenant', style: GoogleFonts.nunito(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.red)),
      ]));

  // ── État vide — refonte "WOW" ────────────────────────────
  Widget _buildEmptyState() => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(children: [
        _GlowOrb(emoji: _cultureEmoji),
        const SizedBox(height: 18),
        Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.g900, AppColors.g600],
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                  ).createShader(bounds),
                  child: Text('Bonjour, $_userName', style: GoogleFonts.nunito(
                      fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white))),
              const SizedBox(width: 8),
              const Text('👋', style: TextStyle(fontSize: 24)),
            ]),
        const SizedBox(height: 6),
        Text('Par texte ou à l\'oral — je connais votre contexte agricole.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: _SuggestionCard(
              s: _suggestions[0], onTap: () => _send(_suggestions[0].prompt))),
          const SizedBox(width: 10),
          Expanded(child: _SuggestionCard(
              s: _suggestions[1], onTap: () => _send(_suggestions[1].prompt))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SuggestionCard(
              s: _suggestions[2], onTap: () => _send(_suggestions[2].prompt))),
          const SizedBox(width: 10),
          Expanded(child: _SuggestionCard(
              s: _suggestions[3], onTap: () => _send(_suggestions[3].prompt))),
        ]),
      ]));

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

  // ── Barre de saisie ─ bouton qui morph micro ↔ envoi ─────
  Widget _buildInputBar() => Container(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Preview image en attente
        if (_pendingImagePath != null)
          Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_pendingImagePath!),
                        width: 56, height: 56, fit: BoxFit.cover)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Image prête à envoyer', style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.g700)),
                  Text('Ajoutez un message ou envoyez directement',
                      style: GoogleFonts.nunitoSans(fontSize: 10, color: AppColors.t3)),
                ])),
                GestureDetector(
                    onTap: () => setState(() => _pendingImagePath = null),
                    child: Container(width: 28, height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            size: 14, color: AppColors.red))),
              ])),
        const SizedBox(height: 10),
        AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final hasText = _controller.text.trim().isNotEmpty;
              final hasContent = hasText || _pendingImagePath != null;
              final showMic = !hasContent && _speechAvailable;

              return Row(children: [
                // Bouton caméra/galerie
                GestureDetector(
                    onTap: _sending ? null : _showImagePickerSheet,
                    child: Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                            color: AppColors.surface2,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border)),
                        child: Icon(Icons.camera_alt_rounded,
                            size: 18, color: _sending ? AppColors.t4 : AppColors.g700))),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                    controller: _controller,
                    minLines: 1, maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: GoogleFonts.nunitoSans(fontSize: 14, color: AppColors.t1),
                    decoration: InputDecoration(
                        hintText: _pendingImagePath != null
                            ? 'Décrivez l\'image (optionnel)...'
                            : _listening
                                ? 'Parlez maintenant...'
                                : 'Posez votre question agronomique...',
                        hintStyle: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t4),
                        filled: true, fillColor: AppColors.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(100), borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: showMic
                      ? GestureDetector(
                      key: const ValueKey('mic'),
                      onTap: _sending ? null : _toggleListening,
                      child: Container(width: 46, height: 46,
                          decoration: BoxDecoration(
                              color: _listening
                                  ? AppColors.red.withOpacity(0.1) : AppColors.g700,
                              shape: BoxShape.circle,
                              border: _listening
                                  ? Border.all(color: AppColors.red, width: 1.5) : null),
                          child: Icon(_listening
                              ? Icons.mic_rounded : Icons.mic_none_rounded,
                              color: _listening ? AppColors.red : Colors.white, size: 20)))
                      : GestureDetector(
                      key: const ValueKey('send'),
                      onTap: (hasContent && !_sending) ? () => _send() : null,
                      child: Container(width: 46, height: 46,
                          decoration: BoxDecoration(
                              color: (hasContent && !_sending)
                                  ? AppColors.g700 : AppColors.surface2,
                              shape: BoxShape.circle),
                          child: Icon(Icons.send_rounded,
                              color: (hasContent && !_sending)
                                  ? Colors.white : AppColors.t4, size: 20))),
                ),
              ]);
            }),
      ]));
}

// ══════════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════════

// ── Données d'une carte de suggestion ───────────────────────
class _Suggestion {
  final String emoji, label, prompt;
  final Color? accent;
  const _Suggestion({
    required this.emoji, required this.label, required this.prompt, this.accent,
  });
}

// ── Carte de suggestion (grille 2x2) ────────────────────────
class _SuggestionCard extends StatelessWidget {
  final _Suggestion s;
  final VoidCallback onTap;
  const _SuggestionCard({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          height: 100, // Augmenté pour éviter le overflow de 1 pixel
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: s.accent != null
                      ? s.accent!.withOpacity(0.35) : AppColors.border,
                  width: 1.5),
              boxShadow: AppShadows.sm),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 32, height: 32,
                    decoration: BoxDecoration(
                        color: (s.accent ?? AppColors.g700).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(s.emoji, style: const TextStyle(fontSize: 16)))),
                Text(s.label, style: GoogleFonts.nunito(
                    fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.2,
                    color: s.accent ?? AppColors.g700),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ])));
}

// ── Orbe animée pulsante (icône culture) ────────────────────
class _GlowOrb extends StatefulWidget {
  final String emoji;
  const _GlowOrb({required this.emoji});
  @override
  State<_GlowOrb> createState() => _GlowOrbState();
}

class _GlowOrbState extends State<_GlowOrb> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return SizedBox(width: 136, height: 136,
            child: Stack(alignment: Alignment.center, children: [
              Container(width: 120 + 16 * t, height: 120 + 16 * t,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.g300.withOpacity(0.35 - 0.15 * t),
                        Colors.transparent,
                      ]))),
              Container(width: 100, height: 100,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.g50,
                      border: Border.all(color: AppColors.g300, width: 1.5),
                      boxShadow: AppShadows.md),
                  child: Center(child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 44)))),
            ]));
      });
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
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image attachée
                                  if (message.hasImage) ...[
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                            File(message.imagePath!),
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                                height: 120,
                                                decoration: BoxDecoration(
                                                    color: AppColors.surface2,
                                                    borderRadius: BorderRadius.circular(10)),
                                                child: const Center(
                                                    child: Icon(Icons.broken_image_rounded,
                                                        color: AppColors.t3, size: 32))))),
                                    if (message.content.isNotEmpty)
                                      const SizedBox(height: 8),
                                  ],
                                  // Texte du message
                                  if (message.content.isNotEmpty)
                                    MarkdownBody(
                                      data: message.content,
                                      styleSheet: MarkdownStyleSheet(
                                        p: GoogleFonts.nunitoSans(
                                          fontSize: 14, height: 1.5,
                                          color: isUser ? Colors.white : AppColors.t1),
                                        strong: GoogleFonts.nunitoSans(
                                          fontSize: 14, height: 1.5,
                                          fontWeight: FontWeight.bold,
                                          color: isUser ? Colors.white : AppColors.t1),
                                        listBullet: TextStyle(
                                          color: isUser ? Colors.white : AppColors.t1),
                                      ),
                                    ),
                                ]))),
                  ]),
              if (!isUser && message.sources.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6,
                    children: message.sources.map((s) => GestureDetector(
                        onTap: () => onSourceTap(s),
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: AppColors.g50,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: AppColors.g300)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('📚', style: TextStyle(fontSize: 10)),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(s,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                          fontSize: 10, fontWeight: FontWeight.w700,
                                          color: AppColors.g700))),
                                ]))))).toList()),
              ],
            ]));
  }
}

// ── Option du picker image ─────────────────────────────────────
class _ImagePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ImagePickerOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
              color: AppColors.g50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.g300)),
          child: Column(children: [
            Container(width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppColors.g700.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.g700, size: 24)),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.g900)),
          ])));
}

// ── Petit point rouge pulsant (indicateur d'écoute) ─────────
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(width: 8, height: 8,
          decoration: const BoxDecoration(
              color: AppColors.red, shape: BoxShape.circle)));
}