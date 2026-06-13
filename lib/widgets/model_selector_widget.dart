/// ══════════════════════════════════════════════════════════
/// FICHIER 1 : pubspec.yaml — VERSION CORRIGÉE
/// ══════════════════════════════════════════════════════════
///
/// name: agriscan
/// description: Détection intelligente des maladies des plantes
/// publish_to: 'none'
/// version: 1.0.0+1
///
/// environment:
///   sdk: '>=3.0.0 <4.0.0'
///
/// dependencies:
///   flutter:
///     sdk: flutter
///   tflite_flutter: ^0.10.4
///   image: ^4.1.7
///   image_picker: ^1.2.1
///   camera: ^0.10.6
///   shared_preferences: ^2.5.4
///   go_router: ^13.2.5
///   google_fonts: ^6.3.3
///   permission_handler: ^11.4.0
///   path_provider: ^2.1.4
///
/// dev_dependencies:
///   flutter_test:
///     sdk: flutter
///   flutter_lints: ^4.0.0
///
/// flutter:
///   uses-material-design: true
///
///   assets:
///     - assets/models/           ← dossier avec les .tflite
///     - assets/images/           ← dossier images UI
///
///   fonts:
///     - family: Nunito
///       fonts:
///         - asset: assets/fonts/Nunito-Regular.ttf
///         - asset: assets/fonts/Nunito-Bold.ttf
///           weight: 700
///         - asset: assets/fonts/Nunito-ExtraBold.ttf
///           weight: 800

// ══════════════════════════════════════════════════════════
// FICHIER 2 : lib/widgets/model_selector_widget.dart
// Widget de sélection du modèle (MobileViT / ConvNeXt)
// ══════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/ml_service.dart';

class ModelSelectorWidget extends StatefulWidget {
  final ModelVersion selectedVersion;
  final Function(ModelVersion) onVersionChanged;
  final bool isCompact;

  const ModelSelectorWidget({
    super.key,
    required this.selectedVersion,
    required this.onVersionChanged,
    this.isCompact = false,
  });

  @override
  State<ModelSelectorWidget> createState() => _ModelSelectorWidgetState();
}

class _ModelSelectorWidgetState extends State<ModelSelectorWidget> {
  bool _isLoading = false;

  Future<void> _selectVersion(ModelVersion version) async {
    if (version == widget.selectedVersion || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await AgriScanMLService().switchModel(version);
      widget.onVersionChanged(version);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: const Color(0xFFC0321A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCompact
        ? _buildCompact()
        : _buildFull();
  }

  // ── Version compacte (dans la barre du scanner) ───────────
  Widget _buildCompact() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ModelVersion.values.map((v) {
          final isSelected = v == widget.selectedVersion;
          return GestureDetector(
            onTap: () => _selectVersion(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _isLoading && !isSelected
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.white,
                      ),
                    )
                  : Text(
                      '${v.emoji} ${v.displayName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF2D6530)
                            : Colors.white.withOpacity(0.85),
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Version complète (dans les paramètres) ─────────────────
  Widget _buildFull() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Version du modèle IA',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2E1B),
            ),
          ),
        ),
        ...ModelVersion.values.map((v) => _buildVersionCard(v)),
        const SizedBox(height: 8),
        const Text(
          'Les deux versions analysent les mêmes maladies.\nMobileViT est plus précis, ConvNeXt est plus rapide.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B8E6F)),
        ),
      ],
    );
  }

  Widget _buildVersionCard(ModelVersion v) {
    final isSelected = v == widget.selectedVersion;
    final isLoading  = _isLoading && v != widget.selectedVersion;

    return GestureDetector(
      onTap: () => _selectVersion(v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEAF3DE)
              : const Color(0xFFF2F6ED),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2D6530)
                : const Color(0xFFC8DCC0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icône modèle
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2D6530)
                    : const Color(0xFFDDE8D3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(v.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? const Color(0xFF2D6530)
                          : const Color(0xFF1A2E1B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    v.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? const Color(0xFF3A7D3E)
                          : const Color(0xFF6B8E6F),
                    ),
                  ),
                ],
              ),
            ),

            // Indicateur
            if (isLoading)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF2D6530),
                ),
              )
            else if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF2D6530), size: 22)
            else
              const Icon(Icons.radio_button_unchecked,
                  color: Color(0xFFA0BCAA), size: 22),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════
// FICHIER 3 : lib/screens/scanner_screen.dart (extrait clé)
// ══════════════════════════════════════════════════════════

/*
class ScannerScreen extends StatefulWidget { ... }
class _ScannerScreenState extends State<ScannerScreen> {

  final _mlService = AgriScanMLService();
  ModelVersion _selectedVersion = ModelVersion.mobileViT;
  PlantType _selectedPlant = PlantType.maize;

  @override
  void initState() {
    super.initState();
    _mlService.initialize();
    _selectedVersion = _mlService.currentVersion;
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() => _isAnalyzing = true);

    try {
      final result = await _mlService.predict(
        imageFile : imageFile,
        plantType : _selectedPlant,
      );

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/result',
          arguments: result,
        );
      }
    } catch (e) {
      // Afficher erreur
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Viewfinder caméra
          CameraPreview(_cameraController),

          // Sélecteur de modèle en haut
          Positioned(
            top: 100,
            left: 0, right: 0,
            child: Center(
              child: ModelSelectorWidget(
                selectedVersion: _selectedVersion,
                onVersionChanged: (v) => setState(() => _selectedVersion = v),
                isCompact: true,
              ),
            ),
          ),

          // Sélecteur de plante
          Positioned(
            top: 148,
            left: 0, right: 0,
            child: Center(
              child: _PlantTypeSelector(
                selected: _selectedPlant,
                onChanged: (p) => setState(() => _selectedPlant = p),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/


// ══════════════════════════════════════════════════════════
// FICHIER 4 : lib/screens/result_screen.dart (extrait)
// Affichage du résultat avec indication du modèle utilisé
// ══════════════════════════════════════════════════════════

/*
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = ModalRoute.of(context)!.settings.arguments as DiseaseResult;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [

            // Badge modèle utilisé
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA8D5AC)),
              ),
              child: Text(
                '${result.modelUsed.emoji} ${result.modelUsed.displayName} '
                '· ${result.inferenceMs}ms',
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Color(0xFF2D6530),
                ),
              ),
            ),

            // Nom de la maladie
            Text(
              result.className,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),

            // Niveau de confiance
            _ConfidenceBar(confidence: result.confidence),

            // Scores de toutes les classes
            ...result.allScores.map((s) => _ClassScoreRow(score: s)),
          ],
        ),
      ),
    );
  }
}
*/
