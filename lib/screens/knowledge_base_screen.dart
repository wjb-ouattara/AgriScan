import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/knowledge_base_service.dart';

// ══════════════════════════════════════════════════════════
//  KNOWLEDGE BASE SCREEN
//  Gestion de la base de connaissances RAG : fiches intégrées
//  + documents importés (.txt ou texte collé manuellement).
// ══════════════════════════════════════════════════════════

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});
  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  final _kb = KnowledgeBaseService();
  List<KnowledgeDocument> _docs = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await _kb.getAllDocuments();
    if (mounted) setState(() { _docs = docs; _loading = false; });
  }

  // ── Import depuis un fichier .txt ─────────────────────
  Future<void> _importFile() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['txt']);
      if (result == null || result.files.single.path == null) {
        setState(() => _busy = false);
        return;
      }
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final filename = result.files.single.name;
      final title = filename.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');

      final chunks = await _kb.importTextDocument(
          title: title, content: content, source: 'import:$filename');

      await _load();
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$chunks section(s) ajoutée(s) depuis "$filename"'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur import : $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    }
  }

  // ── Ajout manuel (texte collé) ────────────────────────
  Future<void> _addManual() async {
    final titleCtrl   = TextEditingController();
    final contentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Ajouter un document', style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.g900)),
            content: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl,
                  style: GoogleFonts.nunitoSans(fontSize: 14),
                  decoration: InputDecoration(
                      labelText: 'Titre',
                      labelStyle: GoogleFonts.nunitoSans(fontSize: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 14),
              TextField(controller: contentCtrl, maxLines: 8,
                  style: GoogleFonts.nunitoSans(fontSize: 13),
                  decoration: InputDecoration(
                      labelText: 'Contenu (collez votre texte ici)',
                      labelStyle: GoogleFonts.nunitoSans(fontSize: 13),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.g700, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ajouter', style: TextStyle(color: Colors.white))),
            ]));

    if (ok == true &&
        titleCtrl.text.trim().isNotEmpty &&
        contentCtrl.text.trim().isNotEmpty) {
      await _kb.importTextDocument(
          title: titleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
          source: 'manual');
      await _load();
    }
  }

  Future<void> _delete(KnowledgeDocument doc) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Supprimer ce document ?', style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800)),
            content: Text(doc.title, style: GoogleFonts.nunitoSans(fontSize: 13)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red, elevation: 0),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Supprimer', style: TextStyle(color: Colors.white))),
            ]));
    if (confirm == true) {
      await _kb.deleteDocument(doc.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final seedDocs     = _docs.where((d) => d.isSeed).toList();
    final importedDocs = _docs.where((d) => !d.isSeed).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
          backgroundColor: AppColors.bg, elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.t1),
              onPressed: () => Navigator.pop(context)),
          title: Text('Base de connaissances', style: GoogleFonts.nunito(
              fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.g900))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.g600))
          : ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            _InfoBanner(
                emoji: '🧠',
                text: 'Cette base alimente les réponses de l\'assistant IA '
                    '(recherche par pertinence sur vos documents). Ajoutez '
                    'vos propres fiches techniques pour enrichir ses '
                    'connaissances.'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _ActionBtn(
                  emoji: '📄', label: 'Importer .txt',
                  busy: _busy, onTap: _busy ? null : _importFile)),
              const SizedBox(width: 10),
              Expanded(child: _ActionBtn(
                  emoji: '✏️', label: 'Coller un texte',
                  busy: false, onTap: _busy ? null : _addManual)),
            ]),
            const SizedBox(height: 24),
            _SectionLabel('FICHES INTÉGRÉES (${seedDocs.length})'),
            ...seedDocs.map((d) => _DocCard(doc: d, onDelete: null)),
            const SizedBox(height: 24),
            _SectionLabel('DOCUMENTS IMPORTÉS (${importedDocs.length})'),
            if (importedDocs.isEmpty)
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.5)),
                  child: Text('Aucun document importé pour le moment.',
                      style: GoogleFonts.nunitoSans(fontSize: 13, color: AppColors.t3)))
            else
              ...importedDocs.map((d) => _DocCard(
                  doc: d, onDelete: () => _delete(d))),
          ]),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  WIDGETS HELPERS
// ══════════════════════════════════════════════════════════

class _InfoBanner extends StatelessWidget {
  final String emoji, text;
  const _InfoBanner({required this.emoji, required this.text});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.g50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.g300, width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.nunitoSans(
            fontSize: 12.5, color: AppColors.t2, height: 1.5))),
      ]));
}

class _ActionBtn extends StatelessWidget {
  final String emoji, label;
  final bool busy;
  final VoidCallback? onTap;
  const _ActionBtn({required this.emoji, required this.label,
    required this.busy, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: AppShadows.sm),
          child: Column(children: [
            busy
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.g600, strokeWidth: 2))
                : Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(label, style: GoogleFonts.nunito(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.g700)),
          ])));
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 11,
          fontWeight: FontWeight.w700, color: AppColors.t3, letterSpacing: 1.5)));
}

class _DocCard extends StatelessWidget {
  final KnowledgeDocument doc;
  final VoidCallback? onDelete;
  const _DocCard({required this.doc, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final preview = doc.content.replaceAll('\n', ' ');
    final sourceLabel = doc.isSeed
        ? '🔖 Intégré'
        : doc.source.startsWith('import:')
        ? '📄 ${doc.source.substring(7)}'
        : '✏️ Manuel';

    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: AppShadows.sm),
        child: Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.title, style: GoogleFonts.nunito(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.t1),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(preview, style: GoogleFonts.nunitoSans(
                fontSize: 12, color: AppColors.t3, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(100)),
                child: Text(sourceLabel, style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.t3))),
          ])),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
                onTap: onDelete,
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.red))),
          ],
        ]));
  }
}