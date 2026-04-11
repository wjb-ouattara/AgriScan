# AgriScan V3 — Flutter App
## Application mobile de détection des maladies des plantes

---

## 📱 Stack technique
- **Flutter** 3.19+
- **Dart** 3.2+
- **Theme** : Light Mode, WCAG AAA, outdoor-optimized
- **Typographie** : Google Fonts — Nunito + Nunito Sans

---

## 📂 Structure du projet

```
agriscan/
├── lib/
│   ├── main.dart                    # Point d'entrée
│   ├── theme/
│   │   └── app_theme.dart           # Tokens design (couleurs, ombres, radius)
│   ├── models/
│   │   └── scan_result.dart         # Modèles : DiseaseResult, WeedResult, ScanHistory
│   ├── screens/
│   │   ├── splash_screen.dart       # Écran d'accueil + onboarding
│   │   ├── scanner_screen.dart      # Scanner caméra + MainShell (bottom nav)
│   │   ├── analyzing_screen.dart    # Animation d'analyse IA
│   │   ├── disease_result_screen.dart # Résultat maladie
│   │   ├── weeds_result_screen.dart  # Résultat mauvaises herbes
│   │   ├── history_screen.dart      # Historique + graphiques
│   │   └── profile_screen.dart      # Profil utilisateur & paramètres
│   └── widgets/
│       └── common_widgets.dart      # Composants réutilisables
├── assets/
│   └── images/                      # Placez vos images ici
├── pubspec.yaml
└── README.md
```

---

## 🚀 Installation

### 1. Prérequis
```bash
flutter --version   # Flutter 3.19+ requis
dart --version      # Dart 3.2+ requis
```

### 2. Installer les dépendances
```bash
cd agriscan
flutter pub get
```

### 3. Lancer l'application
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios
```

### 4. Build production
```bash
# APK Android
flutter build apk --release

# App Bundle Android
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 🎨 Système de design

### Couleurs principales
```dart
AppColors.g700  // Vert primaire   #2D6530  (ratio 8.2:1 — WCAG AAA)
AppColors.t1    // Texte primaire  #1A2E1B  (ratio 12.3:1 — WCAG AAA)
AppColors.amber // Alerte ambre   #E8920A
AppColors.red   // Danger rouge   #C0321A
AppColors.bg    // Fond clair     #F2F6ED
```

### Composants disponibles
| Widget | Usage |
|--------|-------|
| `AppChip` | Badge statut (green/amber/red/sage) |
| `SurfaceCard` | Carte surface blanche |
| `PrimaryButton` | Bouton principal vert |
| `SecondaryButton` | Bouton secondaire outline |
| `AppBackButton` | Bouton retour |
| `AppProgressBar` | Barre de progression |
| `AppToggle` | Toggle switch animé |
| `StatMiniCard` | Carte statistique |
| `ProfileMenuItem` | Item menu profil |
| `HistoryItem` | Item liste historique |

---

## 📷 Intégration Caméra (production)

La version actuelle simule la caméra. Pour l'activer :

### 1. Ajouter les permissions

**Android** (`android/app/src/main/AndroidManifest.xml`) :
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**iOS** (`ios/Runner/Info.plist`) :
```xml
<key>NSCameraUsageDescription</key>
<string>AgriScan utilise la caméra pour analyser vos plantes</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>AgriScan accède à votre galerie pour analyser des images</string>
```

### 2. Remplacer le viewfinder simulé dans `scanner_screen.dart`
```dart
// Remplacez le Container décoratif par :
CameraPreview(_cameraController)
```

---

## 🧠 Intégration TFLite (modèle IA)

### 1. Activer dans pubspec.yaml
```yaml
tflite_flutter: ^0.10.4
```

### 2. Ajouter votre modèle
```
assets/
  models/
    disease_model.tflite
    weeds_model.tflite
    labels_disease.txt
    labels_weeds.txt
```

### 3. Modifier `analyzing_screen.dart`
Remplacez l'animation temporisée par l'appel réel :
```dart
final interpreter = await Interpreter.fromAsset('assets/models/disease_model.tflite');
// ... inference code
```

---

## 📱 Configuration Android Studio

1. Ouvrir Android Studio
2. **File → Open** → sélectionner le dossier `agriscan/`
3. Attendre l'indexation Gradle
4. **pub get** dans le terminal intégré
5. Sélectionner un émulateur ou un appareil physique
6. Appuyer sur **Run ▶**

### Min SDK requis
```gradle
minSdkVersion 21    // Android 5.0+
targetSdkVersion 34
```

---

## 🏗️ Prochaines étapes recommandées

1. **Intégration caméra** → package `camera`
2. **Modèle TFLite** → `tflite_flutter`
3. **Base de données locale** → `sqflite` ou `hive`
4. **Géolocalisation parcelles** → `geolocator`
5. **Export PDF rapports** → `pdf` package
6. **Multi-langue** → `flutter_localizations` (FR/AR)
7. **Push notifications** → `firebase_messaging`

---

## 👨‍💻 Développé avec
- Flutter & Dart
- Design WCAG AA/AAA
- Google Fonts (Nunito)
- Architecture screens + widgets séparés

**AgriScan V3 · Outdoor-First · Farmer-Friendly**
