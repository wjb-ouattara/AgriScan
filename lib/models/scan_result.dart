// ═══════════════════════════════════════════════════════
// AGRISCAN — DATA MODELS
// ═══════════════════════════════════════════════════════

enum ScanType { disease, weeds, both }
enum SeverityLevel { faible, moderate, elevee, critique }
enum ScanStatus { sain, maladie, herbes }

// ── Disease Model ────────────────────────────────────────
class DiseaseResult {
  final String name;
  final String scientificName;
  final String plantName;
  final double confidence;
  final SeverityLevel severity;
  final String type;       // Fongique, Bactérien, Viral…
  final String urgency;    // 48h, 72h…
  final String cause;
  final List<TreatmentStep> treatments;
  final DateTime scannedAt;

  const DiseaseResult({
    required this.name,
    required this.scientificName,
    required this.plantName,
    required this.confidence,
    required this.severity,
    required this.type,
    required this.urgency,
    required this.cause,
    required this.treatments,
    required this.scannedAt,
  });

  String get severityLabel {
    switch (severity) {
      case SeverityLevel.faible:   return 'Faible';
      case SeverityLevel.moderate: return 'Modérée';
      case SeverityLevel.elevee:   return 'Élevée';
      case SeverityLevel.critique: return 'Critique';
    }
  }

  double get severityRatio {
    switch (severity) {
      case SeverityLevel.faible:   return 0.25;
      case SeverityLevel.moderate: return 0.62;
      case SeverityLevel.elevee:   return 0.80;
      case SeverityLevel.critique: return 1.0;
    }
  }

  // Demo data
  static DiseaseResult get demo => DiseaseResult(
    name: 'Rouille de la tige',
    scientificName: 'Puccinia graminis',
    plantName: 'Blé (Triticum aestivum)',
    confidence: 94.3,
    severity: SeverityLevel.moderate,
    type: 'Fongique',
    urgency: '48h',
    cause: 'Humidité élevée',
    scannedAt: DateTime.now(),
    treatments: [
      TreatmentStep(
        number: 1,
        title: 'Séparez les plants malades',
        description: 'Retirez et brûlez les feuilles abîmées. Évitez tout contact entre plants sains et infectés.',
      ),
      TreatmentStep(
        number: 2,
        title: 'Appliquez un fongicide',
        description: 'Tebuconazole 250 EC — 1 litre par hectare, le matin, par temps calme.',
      ),
      TreatmentStep(
        number: 3,
        title: 'Prochaine saison',
        description: 'Changez de culture sur cette parcelle. Choisissez des variétés résistantes.',
      ),
    ],
  );
}

class TreatmentStep {
  final int number;
  final String title;
  final String description;

  const TreatmentStep({
    required this.number,
    required this.title,
    required this.description,
  });
}

// ── Weed Model ───────────────────────────────────────────
class WeedResult {
  final int totalCount;
  final double riskPercent;
  final String affectedArea;
  final List<WeedSpecies> species;
  final DateTime scannedAt;

  const WeedResult({
    required this.totalCount,
    required this.riskPercent,
    required this.affectedArea,
    required this.species,
    required this.scannedAt,
  });

  static WeedResult get demo => WeedResult(
    totalCount: 5,
    riskPercent: 72,
    affectedArea: '0.4 ha',
    scannedAt: DateTime.now(),
    species: [
      WeedSpecies(name: 'Chiendent commun',    latin: 'Elymus repens',      count: 2, confidence: 91, dangerLevel: 'Élevé'),
      WeedSpecies(name: 'Chardon des champs',  latin: 'Cirsium arvense',    count: 2, confidence: 87, dangerLevel: 'Modéré'),
      WeedSpecies(name: 'Liseron des haies',   latin: 'Calystegia sepium',  count: 1, confidence: 79, dangerLevel: 'Faible'),
    ],
  );
}

class WeedSpecies {
  final String name;
  final String latin;
  final int count;
  final double confidence;
  final String dangerLevel;

  const WeedSpecies({
    required this.name,
    required this.latin,
    required this.count,
    required this.confidence,
    required this.dangerLevel,
  });
}

// ── History Model ────────────────────────────────────────
class ScanHistory {
  final String id;
  final String cropName;
  final String fieldName;
  final ScanStatus status;
  final String result;
  final double confidence;
  final DateTime date;
  final ScanType type;

  const ScanHistory({
    required this.id,
    required this.cropName,
    required this.fieldName,
    required this.status,
    required this.result,
    required this.confidence,
    required this.date,
    required this.type,
  });

  String get statusLabel {
    switch (status) {
      case ScanStatus.sain:    return 'Saine';
      case ScanStatus.maladie: return 'Maladie';
      case ScanStatus.herbes:  return 'Herbes';
    }
  }

  String get emoji {
    switch (type) {
      case ScanType.disease: return '🌿';
      case ScanType.weeds:   return '🍃';
      case ScanType.both:    return '🌾';
    }
  }

  static List<ScanHistory> get demoList => [
    ScanHistory(id: '1', cropName: 'Tomate — Mildiou',    fieldName: 'Champ A', status: ScanStatus.maladie, result: 'Mildiou', confidence: 94, date: DateTime.now(), type: ScanType.disease),
    ScanHistory(id: '2', cropName: 'Blé — Résultat normal', fieldName: 'Champ B', status: ScanStatus.sain,    result: 'Saine',   confidence: 99, date: DateTime.now(), type: ScanType.disease),
    ScanHistory(id: '3', cropName: 'Champ Nord — 5 herbes', fieldName: 'Champ C', status: ScanStatus.herbes,  result: '5 herbes', confidence: 87, date: DateTime.now().subtract(const Duration(days: 1)), type: ScanType.weeds),
    ScanHistory(id: '4', cropName: 'Maïs — Rouille commune', fieldName: 'Champ D', status: ScanStatus.maladie, result: 'Rouille', confidence: 88, date: DateTime.now().subtract(const Duration(days: 1)), type: ScanType.disease),
    ScanHistory(id: '5', cropName: 'Tomate — Résultat normal', fieldName: 'Champ A', status: ScanStatus.sain, result: 'Saine', confidence: 97, date: DateTime.now().subtract(const Duration(days: 2)), type: ScanType.disease),
  ];
}
