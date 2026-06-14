import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'ml_service.dart';
import '../utils/disease_meta.dart';

// ══════════════════════════════════════════════════════════
//  VIDEO ANALYSIS SERVICE
//  Pipeline : extraction de frames → classification CropNet
//  → lissage temporel → regroupement en segments
// ══════════════════════════════════════════════════════════

// ── Résultat brut d'une frame ─────────────────────────────
class VideoFrameResult {
  final Duration timestamp;
  final String   diseaseName;
  final double   confidence;
  final String?  thumbnailPath;
  const VideoFrameResult({
    required this.timestamp,
    required this.diseaseName,
    required this.confidence,
    this.thumbnailPath,
  });
}

// ── Segment temporel (frames consécutives, même classe) ───
class VideoSegment {
  final String   diseaseName;
  final Duration start;
  final Duration end;
  final double   avgConfidence;
  final int      frameCount;
  final String?  thumbnailPath;
  const VideoSegment({
    required this.diseaseName,
    required this.start,
    required this.end,
    required this.avgConfidence,
    required this.frameCount,
    this.thumbnailPath,
  });

  Duration get duration => end - start;
}

// ── Progression pendant le traitement ─────────────────────
class VideoProgress {
  final int      current;
  final int      total;
  final Duration timestamp;
  final String?  lastDisease;
  final double?  lastConfidence;
  const VideoProgress({
    required this.current,
    required this.total,
    required this.timestamp,
    this.lastDisease,
    this.lastConfidence,
  });

  double get fraction => total == 0 ? 0 : current / total;
}

// ── Résultat final complet ────────────────────────────────
class VideoAnalysisResult {
  final String   videoPath;
  final Duration videoDuration;
  final Duration interval;
  final int      totalFrames;
  final List<VideoSegment> segments;    // après lissage + regroupement
  final Map<String, int>   distribution; // code maladie → nb frames
  final PlantType plantType;
  final DateTime  analyzedAt;

  const VideoAnalysisResult({
    required this.videoPath,
    required this.videoDuration,
    required this.interval,
    required this.totalFrames,
    required this.segments,
    required this.distribution,
    required this.plantType,
    required this.analyzedAt,
  });

  String get videoName => p.basename(videoPath);

  double get healthyPercent {
    final healthy = distribution['Healthy'] ?? 0;
    return totalFrames == 0 ? 0 : healthy / totalFrames * 100;
  }

  /// Score de santé global 0-100, pondéré par la sévérité
  /// de chaque maladie détectée (plus une maladie est grave
  /// et fréquente, plus le score baisse).
  double get healthScore {
    if (totalFrames == 0) return 100;
    double penalty = 0;
    distribution.forEach((code, count) {
      final meta = DiseaseMeta.of(code);
      penalty += meta.severity * (count / totalFrames);
    });
    return ((1 - penalty) * 100).clamp(0, 100);
  }

  /// Détections anormales (hors "Healthy") triées par
  /// priorité de traitement = sévérité × prévalence.
  List<VideoSegment> get priorityDetections {
    final issues = segments.where((s) => s.diseaseName != 'Healthy').toList();
    issues.sort((a, b) {
      final pa = DiseaseMeta.of(a.diseaseName).severity * a.frameCount;
      final pb = DiseaseMeta.of(b.diseaseName).severity * b.frameCount;
      return pb.compareTo(pa);
    });
    return issues;
  }

  bool get isHealthy => priorityDetections.isEmpty;
}

// ══════════════════════════════════════════════════════════
//  SERVICE
// ══════════════════════════════════════════════════════════

class VideoAnalysisService {
  final _ml = AgriScanMLService();

  // ── Durée totale de la vidéo ─────────────────────────────
  Future<Duration> getVideoDuration(File video) async {
    final controller = VideoPlayerController.file(video);
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  // ── Extraire une frame à un instant donné → fichier JPEG ─
  Future<File?> _extractFrameFile(
      String videoPath, Duration time, int index) async {
    final bytes = await vt.VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: vt.ImageFormat.JPEG,
      timeMs: time.inMilliseconds,
      quality: 80,
      maxWidth: 512,
    );
    if (bytes == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/agriscan_frame_$index.jpg');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ── Pipeline complet ─────────────────────────────────────
  Future<VideoAnalysisResult> analyzeVideo({
    required File videoFile,
    required Duration interval,
    PlantType plantType = PlantType.maize,
    void Function(VideoProgress progress)? onProgress,
  }) async {
    final duration = await getVideoDuration(videoFile);

    // Construire la liste des instants à analyser
    final timestamps = <Duration>[];
    for (var t = Duration.zero; t < duration; t += interval) {
      timestamps.add(t);
    }
    if (timestamps.isEmpty) timestamps.add(Duration.zero);

    final frames = <VideoFrameResult>[];

    for (var i = 0; i < timestamps.length; i++) {
      final ts = timestamps[i];
      final frameFile = await _extractFrameFile(videoFile.path, ts, i);
      if (frameFile == null) continue;

      try {
        final result = await _ml.predict(
          imageFile: frameFile,
          forcePlantType: plantType,
        );

        frames.add(VideoFrameResult(
          timestamp     : ts,
          diseaseName   : result.diseaseName,
          confidence    : result.confidence,
          thumbnailPath : frameFile.path,
        ));

        onProgress?.call(VideoProgress(
          current       : i + 1,
          total         : timestamps.length,
          timestamp     : ts,
          lastDisease   : result.diseaseName,
          lastConfidence: result.confidence,
        ));
      } catch (e) {
        print('⚠️ Frame $i ignorée : $e');
      }
    }

    final smoothed = _smooth(frames, windowSize: 3);
    final segments = _groupSegments(smoothed);
    final distribution = _distribution(smoothed);

    return VideoAnalysisResult(
      videoPath    : videoFile.path,
      videoDuration: duration,
      interval     : interval,
      totalFrames  : smoothed.length,
      segments     : segments,
      distribution : distribution,
      plantType    : plantType,
      analyzedAt   : DateTime.now(),
    );
  }

  // ════════════════════════════════════════════════════════
  //  LISSAGE TEMPOREL — vote majoritaire (fenêtre glissante)
  //  Évite qu'une frame floue/isolée fausse le diagnostic
  //  d'un segment globalement stable.
  // ════════════════════════════════════════════════════════
  List<VideoFrameResult> _smooth(
      List<VideoFrameResult> frames, {int windowSize = 3}) {
    if (frames.length <= windowSize) return frames;
    final half = windowSize ~/ 2;
    final result = <VideoFrameResult>[];

    for (var i = 0; i < frames.length; i++) {
      final start = (i - half).clamp(0, frames.length - 1);
      final end   = (i + half).clamp(0, frames.length - 1);
      final window = frames.sublist(start, end + 1);

      final counts = <String, int>{};
      for (final f in window) {
        counts[f.diseaseName] = (counts[f.diseaseName] ?? 0) + 1;
      }
      final majority = counts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;

      result.add(VideoFrameResult(
        timestamp    : frames[i].timestamp,
        diseaseName  : majority,
        confidence   : frames[i].confidence,
        thumbnailPath: frames[i].thumbnailPath,
      ));
    }
    return result;
  }

  // ════════════════════════════════════════════════════════
  //  REGROUPEMENT — frames consécutives de même classe
  //  (après lissage) → segments temporels
  // ════════════════════════════════════════════════════════
  List<VideoSegment> _groupSegments(List<VideoFrameResult> frames) {
    if (frames.isEmpty) return [];
    final segments = <VideoSegment>[];

    String   currentDisease = frames.first.diseaseName;
    Duration segStart = frames.first.timestamp;
    Duration segEnd   = frames.first.timestamp;
    double   confSum  = frames.first.confidence;
    int      count    = 1;
    String?  thumb    = frames.first.thumbnailPath;

    for (var i = 1; i < frames.length; i++) {
      final f = frames[i];
      if (f.diseaseName == currentDisease) {
        segEnd = f.timestamp;
        confSum += f.confidence;
        count++;
      } else {
        segments.add(VideoSegment(
          diseaseName  : currentDisease,
          start        : segStart,
          end          : segEnd,
          avgConfidence: confSum / count,
          frameCount   : count,
          thumbnailPath: thumb,
        ));
        currentDisease = f.diseaseName;
        segStart = f.timestamp;
        segEnd   = f.timestamp;
        confSum  = f.confidence;
        count    = 1;
        thumb    = f.thumbnailPath;
      }
    }
    segments.add(VideoSegment(
      diseaseName  : currentDisease,
      start        : segStart,
      end          : segEnd,
      avgConfidence: confSum / count,
      frameCount   : count,
      thumbnailPath: thumb,
    ));
    return segments;
  }

  Map<String, int> _distribution(List<VideoFrameResult> frames) {
    final dist = <String, int>{};
    for (final f in frames) {
      dist[f.diseaseName] = (dist[f.diseaseName] ?? 0) + 1;
    }
    return dist;
  }
}