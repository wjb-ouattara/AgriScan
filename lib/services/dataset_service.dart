import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DatasetService {
  static final DatasetService _instance = DatasetService._internal();
  factory DatasetService() => _instance;
  DatasetService._internal();

  final _uuid = const Uuid();

  /// Compresse et sauvegarde l'image pour le futur dataset
  Future<void> cacheImageForDataset({
    required File originalImage,
    required String plantType,
    required String diseaseName,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      
      // Assainir les noms de dossiers
      final safePlant = plantType.replaceAll(' ', '_').replaceAll('/', '_');
      final safeDisease = diseaseName.replaceAll(' ', '_').replaceAll('/', '_');
      final folderName = '${safePlant}_$safeDisease';
      
      final datasetDir = Directory('${appDir.path}/ml_dataset/$folderName');
      if (!await datasetDir.exists()) {
        await datasetDir.create(recursive: true);
      }

      final fileName = '${_uuid.v4()}.jpg';
      final targetPath = '${datasetDir.path}/$fileName';

      // Compression de l'image (environ 600x600, qualité 70%)
      await FlutterImageCompress.compressAndGetFile(
        originalImage.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 600,
        minHeight: 600,
        format: CompressFormat.jpeg,
      );

      print(" Image compressée et cachée pour le dataset : $targetPath");
      
      // Tenter d'uploader si le quota est atteint
      uploadBatches().catchError((e) {
        print("Erreur background upload dataset: $e");
        return false;
      });
    } catch (e) {
      print("Erreur lors du cache de l'image dataset : $e");
    }
  }

  /// Compte le nombre d'images en attente
  Future<int> getPendingImagesCount() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final datasetDir = Directory('${appDir.path}/ml_dataset');
      if (!await datasetDir.exists()) return 0;

      int count = 0;
      await for (final entity in datasetDir.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Zippe les images et les envoie sur Supabase
  Future<bool> uploadBatches({int minImagesToUpload = 2, int maxPerBatch = 20}) async {
    try {
      // 1. Vérifier la connexion Internet (Mode Hors-Ligne)
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print("📴 Pas de connexion Internet. Les images sont conservées localement pour un envoi ultérieur.");
        return false;
      }

      final pendingCount = await getPendingImagesCount();
      if (pendingCount < minImagesToUpload) {
        print("Pas assez d'images pour un batch ($pendingCount/$minImagesToUpload).");
        return false;
      }

      print("Création d'un batch ZIP (jusqu'à $maxPerBatch images)...");
      
      final appDir = await getApplicationDocumentsDirectory();
      final datasetDir = Directory('${appDir.path}/ml_dataset');
      final batchDir = Directory('${appDir.path}/ml_dataset_batches');
      
      if (!await batchDir.exists()) {
        await batchDir.create(recursive: true);
      }

      final zipFileName = 'batch_${_uuid.v4()}.zip';

      // Zippage en mémoire avec limite de fichiers (pour économiser la RAM)
      final archive = Archive();
      final filesToUpload = <File>[];
      int count = 0;

      await for (final entity in datasetDir.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          // Extraire le chemin relatif et forcer les slashs (important pour les zips)
          final relativePath = entity.path.substring(datasetDir.path.length + 1).replaceAll('\\', '/');
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
          filesToUpload.add(entity);
          
          count++;
          if (count >= maxPerBatch) break; // Limite de fichiers par batch
        }
      }
      
      if (filesToUpload.isEmpty) return false;

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null || zipBytes.isEmpty) {
        print("Erreur: ZIP vide ou impossible à créer.");
        return false;
      }

      print("🚀 Upload du batch vers Supabase ($zipFileName)...");
      
      await Supabase.instance.client.storage
          .from('ml_dataset_batches')
          .uploadBinary(
            zipFileName, 
            Uint8List.fromList(zipBytes),
            fileOptions: const FileOptions(contentType: 'application/zip'),
          );

      print("✅ Upload réussi ! Nettoyage de ${filesToUpload.length} images locales...");
      
      // Nettoyage UNIQUEMENT des images qui ont été envoyées avec succès
      for (final file in filesToUpload) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Si d'autres images sont encore en attente (backlog hors-ligne accumulé), on relance
      final remainingCount = await getPendingImagesCount();
      if (remainingCount >= minImagesToUpload) {
        print("🔄 Il reste $remainingCount images en attente, lancement du batch suivant...");
        uploadBatches(minImagesToUpload: minImagesToUpload, maxPerBatch: maxPerBatch);
      }

      return true;
    } catch (e) {
      print("❌ Erreur lors de l'upload du batch dataset (réessai automatique plus tard) : $e");
      return false;
    }
  }
}
