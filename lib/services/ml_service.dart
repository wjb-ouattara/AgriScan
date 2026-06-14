import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

// ══════════════════════════════════════════════════════════
//  ML SERVICE — Pipeline AgriScan
//  YOLO → crop → MobileViT/ConvNeXt → résultat
// ══════════════════════════════════════════════════════════

enum PlantType { maize, tomato }

enum ModelVersion {
  mobileViT('MobileViT', 'agriscan_mobilevit.tflite',
      'Précision max · Transformer', '🧠'),
  convNext ('ConvNeXt',  'agriscan_convnext.tflite',
      'Rapide · CNN moderne',        '⚡'),
  cropNet('CropNet', 'agriscan_cropnet.tflite',
  'Fine-tune Google terrain', '🌿');

  final String displayName, assetFile, description, emoji;
  const ModelVersion(this.displayName, this.assetFile,
      this.description, this.emoji);
}

class DiseaseDetectionResult {
  final String           diseaseName;
  final double           confidence;
  final PlantType        plantType;
  final ModelVersion     modelUsed;
  final List<ClassScore> allScores;
  final BoundingBox?     detectedZone;
  final int              inferenceMs;

  const DiseaseDetectionResult({
    required this.diseaseName,
    required this.confidence,
    required this.plantType,
    required this.modelUsed,
    required this.allScores,
    required this.inferenceMs,
    this.detectedZone,
  });

  bool get isHealthy =>
      diseaseName.toLowerCase().contains('sain') ||
          diseaseName.toLowerCase().contains('health');

  String get severityLabel {
    if (isHealthy) return 'Saine';
    if (confidence >= 0.85) return 'Grave';
    if (confidence >= 0.60) return 'Modéré';
    return 'Faible';
  }
}

class ClassScore {
  final String label;
  final double score;
  const ClassScore(this.label, this.score);
}

class BoundingBox {
  final double x, y, width, height, confidence;
  final int classId;
  const BoundingBox({
    required this.x, required this.y,
    required this.width, required this.height,
    required this.confidence, required this.classId,
  });
}

class PlantNotFoundException implements Exception {
  final String message;
  const PlantNotFoundException([
    this.message = 'Aucune plante reconnue dans l\'image.']);
  @override String toString() => message;
}

class ModelNotLoadedException implements Exception {
  final String message;
  const ModelNotLoadedException(this.message);
  @override String toString() => message;
}

// ══════════════════════════════════════════════════════════
//  SERVICE PRINCIPAL
// ══════════════════════════════════════════════════════════

class AgriScanMLService {
  static final AgriScanMLService _i = AgriScanMLService._();
  factory AgriScanMLService() => _i;
  AgriScanMLService._();

  Interpreter? _yoloInterpreter;
  Interpreter? _maizeInterpreter;
  Interpreter? _tomatoInterpreter;

  ModelVersion _currentVersion = ModelVersion.convNext;
  bool         _initialized    = false;
  bool         _maizeAvailable = false;
  bool         _yoloAvailable  = false;

  static const int    _yoloSize       = 640;
  static const int    _classifierSize = 224;
  static const List<String> _yoloClasses    = ['maize', 'tomato', 'weed'];
  static const List<String> _maizeClasses   =
  ['Healthy', 'f_GLS', 'f_NLB', 'f_RUST', 'v_MLN', 'v_MSV'];
  static const List<String> _tomatoClasses  = [
    'Acariens', 'Alternariose', 'Enroulement_Jaune',
    'Mildiou', 'Moisissure', 'Mosaique', 'Oidium',
    'Saine', 'Septoriose', 'Tache_Bact', 'Tache_Cible',
  ];
  static const double _yoloConfThreshold = 0.45;

  ModelVersion get currentVersion => _currentVersion;
  bool         get isInitialized  => _initialized;
  bool         get maizeAvailable => _maizeAvailable;

  // ════════════════════════════════════════════════════
  //  INITIALISATION
  // ════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    // Reset SharedPreferences → forcer le modèle
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('model_version');
    _currentVersion = ModelVersion.cropNet;
    await _loadYolo();
    await _loadMaizeModel();
    _initialized = true;
  }

  Future<void> _loadYolo() async {
    try {
      _yoloInterpreter?.close();
      final opts = InterpreterOptions()..threads = 2;
      _yoloInterpreter = await Interpreter.fromAsset(
          'assets/models/yolov8n_plants.tflite', options: opts);
      _yoloAvailable = true; // YOLO activé
      // Debug shapes
      final inShape  = _yoloInterpreter!.getInputTensor(0).shape;
      final outShape = _yoloInterpreter!.getOutputTensor(0).shape;
      print('✅ YOLO chargé — input: $inShape  output: $outShape');
    } catch (e) {
      _yoloAvailable = false;
      print('⚠️  YOLO non disponible : $e');
    }
  }

  Future<void> _loadMaizeModel() async {
    try {
      _maizeInterpreter?.close();
      final opts = InterpreterOptions()..threads = 2;
      _maizeInterpreter = await Interpreter.fromAsset(
          'assets/models/${_currentVersion.assetFile}', options: opts);
      _maizeAvailable = true;
      final inShape  = _maizeInterpreter!.getInputTensor(0).shape;
      final outShape = _maizeInterpreter!.getOutputTensor(0).shape;
      print('✅ Maïs chargé : ${_currentVersion.displayName}'
          ' — input: $inShape  output: $outShape');
    } catch (e) {
      _maizeAvailable = false;
      print('⚠️  Modèle maïs non disponible : $e');
    }
  }

  Future<void> switchModel(ModelVersion version) async {
    if (_currentVersion == version) return;
    _currentVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_version', version.name);
    await _loadMaizeModel();
  }

  // ════════════════════════════════════════════════════
  //  PIPELINE PRINCIPAL
  // ════════════════════════════════════════════════════

  Future<DiseaseDetectionResult> predict({
    required File imageFile,
    PlantType?    forcePlantType,
  }) async {
    if (!_initialized) await initialize();

    final sw = Stopwatch()..start();

    // Charger l'image
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) throw Exception('Image illisible');
    img.Image image = decoded;

    // Déterminer la plante
    PlantType plantType = forcePlantType ?? PlantType.maize;
    BoundingBox? bbox;

    // ── YOLO ─────────────────────────────────────────
    if (_yoloAvailable && _yoloInterpreter != null) {
      try {
        final yoloResult = await _runYolo(image);
        if (yoloResult != null) {
          bbox      = yoloResult;
          if (forcePlantType == null) {
            plantType = yoloResult.classId == 0
                ? PlantType.maize : PlantType.tomato;
          }
          image = _cropBoundingBox(image, bbox);
          print('✅ YOLO crop: ${image.width}x${image.height}');
        } else {
          print('⚠️  YOLO: rien détecté → image entière');
        }
      } catch (e) {
        print('⚠️ YOLO erreur : $e');
      }
    }

    // ── Classifieur ───────────────────────────────────
    final interpreter = plantType == PlantType.maize
        ? _maizeInterpreter : _tomatoInterpreter;

    if (interpreter == null) {
      sw.stop();
      print('⚠️ Classifieur absent → mode démo');
      return _demoResult(plantType, sw.elapsedMilliseconds);
    }

    final result = await _classifyDisease(
      image    : image,
      plantType: plantType,
      bbox     : bbox,
      elapsedMs: sw.elapsedMilliseconds,
    );
    sw.stop();
    return result;
  }

  // ── Résultat démo ─────────────────────────────────────
  DiseaseDetectionResult _demoResult(PlantType plantType, int ms) {
    final classes = plantType == PlantType.maize
        ? _maizeClasses : _tomatoClasses;
    return DiseaseDetectionResult(
      diseaseName: classes[0],
      confidence : 0.87,
      plantType  : plantType,
      modelUsed  : _currentVersion,
      allScores  : [
        ClassScore(classes[0], 0.87),
        ClassScore(classes[1], 0.08),
        ClassScore(classes[2], 0.03),
        ClassScore(classes[3], 0.02),
      ],
      inferenceMs: ms,
    );
  }

  // ════════════════════════════════════════════════════
  //  YOLO — avec debug complet
  // ════════════════════════════════════════════════════

  Future<BoundingBox?> _runYolo(img.Image image) async {
    final resized = img.copyResize(image,
        width: _yoloSize, height: _yoloSize);
    final input = _imageToFloat32(resized, _yoloSize);

    final outputShape = _yoloInterpreter!.getOutputTensor(0).shape;
    final output = List.generate(
        outputShape[0], (_) => List.generate(
        outputShape[1], (_) => List<double>.filled(outputShape[2], 0)));

    _yoloInterpreter!.run(input, output);

    // ── DEBUG — top détections ────────────────────────
    final numDet = outputShape[2];
    final numClasses = _yoloClasses.length;

    // Collecter toutes les détections > 10%
    final List<Map<String, dynamic>> detections = [];
    for (int i = 0; i < numDet; i++) {
      double bestConf = 0.0;
      int    bestClass = -1;
      for (int c = 0; c < numClasses; c++) {
        final conf = output[0][4 + c][i];
        if (conf > bestConf) { bestConf = conf; bestClass = c; }
      }
      if (bestConf > 0.10 && bestClass != 2) { // ignorer weed
        detections.add({
          'cls' : bestClass,
          'name': _yoloClasses[bestClass],
          'conf': bestConf,
          'cx'  : output[0][0][i],
          'cy'  : output[0][1][i],
          'w'   : output[0][2][i],
          'h'   : output[0][3][i],
        });
      }
    }
    detections.sort((a, b) =>
        (b['conf'] as double).compareTo(a['conf'] as double));

    print('🔍 YOLO top 5 détections :');
    if (detections.isEmpty) {
      print('   ⚠️  Aucune détection > 10% (seuil actuel: '
          '${(_yoloConfThreshold * 100).round()}%)');
    }
    for (final d in detections.take(5)) {
      final pct  = ((d['conf'] as double) * 100).round();
      final cx   = (d['cx'] as double).round();
      final cy   = (d['cy'] as double).round();
      print('   ${d['name']}  conf=${pct}%  cx=$cx  cy=$cy');
    }

    // Résultat final
    final result = _parseYoloOutput(
      output[0],
      imageWidth : image.width.toDouble(),
      imageHeight: image.height.toDouble(),
    );

    if (result != null) {
      final pct = (result.confidence * 100).round();
      print('🔍 YOLO → ${_yoloClasses[result.classId]} conf=$pct%  '
          'crop: ${result.width.round()}x${result.height.round()}');
    } else {
      print('🔍 YOLO → rien au-dessus du seuil ${_yoloConfThreshold}');
    }
    return result;
  }

  // ════════════════════════════════════════════════════
  //  PARSE YOLO OUTPUT
  // ════════════════════════════════════════════════════

  BoundingBox? _parseYoloOutput(
      List<List<double>> output, {
        required double imageWidth,
        required double imageHeight,
      }) {
    final numDet = output[0].length;
    BoundingBox? best;
    double bestConf = _yoloConfThreshold;

    for (int i = 0; i < numDet; i++) {
      final cx = output[0][i];
      final cy = output[1][i];
      final w  = output[2][i];
      final h  = output[3][i];

      int    bestClass = -1;
      double classConf = 0.0;
      for (int c = 0; c < _yoloClasses.length; c++) {
        final conf = output[4 + c][i];
        if (conf > classConf) { classConf = conf; bestClass = c; }
      }

      if (bestClass == 2 || bestClass == -1) continue;
      if (classConf < _yoloConfThreshold)    continue;

      if (classConf > bestConf) {
        bestConf = classConf;
        best = BoundingBox(
          x         : (cx - w / 2) * imageWidth  / _yoloSize,
          y         : (cy - h / 2) * imageHeight / _yoloSize,
          width     : w * imageWidth  / _yoloSize,
          height    : h * imageHeight / _yoloSize,
          confidence: classConf,
          classId   : bestClass,
        );
      }
    }
    return best;
  }

  // ════════════════════════════════════════════════════
  //  CROP BOUNDING BOX
  // ════════════════════════════════════════════════════

  img.Image _cropBoundingBox(img.Image image, BoundingBox bbox) {
    const margin = 0.10;
    final mw = bbox.width  * margin;
    final mh = bbox.height * margin;
    final x = max(0, (bbox.x - mw).round());
    final y = max(0, (bbox.y - mh).round());
    final w = min(image.width  - x, (bbox.width  + 2 * mw).round());
    final h = min(image.height - y, (bbox.height + 2 * mh).round());
    // Garde-fou : ignorer les crops absurdes
    const minSize = 50; // pixels
    if (w <= minSize || h <= minSize) {
      print('⚠️ YOLO crop trop petit (${w}x$h) → image entière utilisée');
      return image;
    }
    final ratio = w / h;
    if (ratio < 0.2 || ratio > 5.0) {
      print('⚠️ YOLO crop ratio absurde (${ratio.toStringAsFixed(2)}) → image entière utilisée');
      return image;
    }

    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  // ════════════════════════════════════════════════════
  //  CLASSIFICATION
  // ════════════════════════════════════════════════════

  Future<DiseaseDetectionResult> _classifyDisease({
    required img.Image image,
    required PlantType plantType,
    required int       elapsedMs,
    BoundingBox?       bbox,
  }) async {
    final interpreter = plantType == PlantType.maize
        ? _maizeInterpreter! : _tomatoInterpreter!;
    final classes = plantType == PlantType.maize
        ? _maizeClasses : _tomatoClasses;

    final resized = img.copyResize(image,
        width: _classifierSize, height: _classifierSize);
    final input   = _imageToFloat32(resized, _classifierSize);

    final outputShape = interpreter.getOutputTensor(0).shape;
    final numClasses  = outputShape[1];
    final output      = List.generate(
        1, (_) => List<double>.filled(numClasses, 0));

    final sw = Stopwatch()..start();
    interpreter.run(input, output);
    sw.stop();

    // CropNet a déjà softmax intégré — vérifier avant d'appliquer
    final rawSum = output[0].fold(0.0, (a, b) => a + b);
    final scores = (rawSum > 0.99 && rawSum < 1.01)
        ? output[0]
        : _softmax(output[0]);
    final allScores = List.generate(
        scores.length,
            (i) => ClassScore(
            i < classes.length ? classes[i] : 'Classe_$i',
            scores[i]))
      ..sort((a, b) => b.score.compareTo(a.score));

    print('🧠 Classifieur résultat : ${allScores[0].label} '
        '${(allScores[0].score * 100).round()}%');

    return DiseaseDetectionResult(
      diseaseName : allScores[0].label,
      confidence  : allScores[0].score,
      plantType   : plantType,
      modelUsed   : _currentVersion,
      allScores   : allScores,
      detectedZone: bbox,
      inferenceMs : elapsedMs + sw.elapsedMilliseconds,
    );
  }

  // ════════════════════════════════════════════════════
  //  UTILITAIRES
  // ════════════════════════════════════════════════════

  List<List<List<List<double>>>> _imageToFloat32(img.Image image, int size) {
    return List.generate(1, (_) =>
        List.generate(size, (y) =>
            List.generate(size, (x) {
              final pixel = image.getPixel(x, y);
              return [
                pixel.r.toDouble() / 255.0,
                pixel.g.toDouble() / 255.0,
                pixel.b.toDouble() / 255.0,
              ];
            })));
  }

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final exps   = logits.map((x) => exp(x - maxVal)).toList();
    final sum    = exps.fold(0.0, (a, b) => a + b) + 1e-9;
    return exps.map((e) => e / sum).toList();
  }

  void dispose() {
    _yoloInterpreter?.close();
    _maizeInterpreter?.close();
    _tomatoInterpreter?.close();
    _initialized    = false;
    _maizeAvailable = false;
    _yoloAvailable  = false;
  }
}