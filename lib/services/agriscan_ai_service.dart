import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'gemma_service.dart'; // N'oublie pas d'importer ton IA locale !
import 'knowledge_base_service.dart';
import 'memory_service.dart';

// ══════════════════════════════════════════════════════════
//  AGRISCAN AI SERVICE
//  Moteur de recommandations intelligentes
//  Analyse agronomique propulsée par AgriScan IA
// ══════════════════════════════════════════════════════════

class AgriScanAIService {
  static final AgriScanAIService _instance = AgriScanAIService._internal();
  factory AgriScanAIService() => _instance;
  AgriScanAIService._internal();

  static const String _key = Secrets.groqApiKey;
  static const String _url  =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  // Cache en mémoire — évite les appels redondants
  final Map<String, AIRecommendation> _cache = {};

  Future<void> initServices() async {
    await KnowledgeBaseService().seedIfEmpty();
  }

  // ══════════════════════════════════════════════════════
  //  ANALYSE PRINCIPALE (HYBRIDE : GROQ + GEMMA LOCAL)
  // ══════════════════════════════════════════════════════

  Future<AIRecommendation> analyzeDisease({
    required String diseaseName,
    required String plantName,
    required String severityLevel,
    required double confidence,
    String region = 'Maroc',
  }) async {
    final key = '$diseaseName-$plantName-$severityLevel';
    if (_cache.containsKey(key)) return _cache[key]!;

    await initServices();

    // 1. Vérification de la connexion
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);

    AIRecommendation result;

    if (isOnline) {
      // ☁️ MODE CLOUD : API GROQ
      print("📶 Réseau détecté : Analyse via Groq (Cloud)");
      final prompt = await _buildPrompt(
        disease   : diseaseName,
        plant     : plantName,
        severity  : severityLevel,
        confidence: confidence,
        region    : region,
      );

      try {
        final response = await http.post(
          Uri.parse(_url),
          headers: {
            'Content-Type' : 'application/json',
            'Authorization': 'Bearer $_key',
          },
          body: jsonEncode({
            'model'          : _model,
            'messages'       : [
              {'role': 'user', 'content': prompt}
            ],
            'temperature'    : 0.3,
            'max_tokens'     : 2048,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data    = jsonDecode(response.body);
          final rawText = data['choices'][0]['message']['content'] as String;
          final parsed  = jsonDecode(rawText) as Map<String, dynamic>;
          result = AIRecommendation.fromJson(parsed);
        } else {
          throw AIServiceException('Erreur Groq ${response.statusCode}');
        }
      } catch (e) {
        print(" Échec du Cloud ($e). Bascule vers le mode local de secours...");
        result = await _runLocalAnalysis(diseaseName, plantName, key);
      }

    } else {
      // 📱 MODE HORS-LIGNE : GEMMA (Local GPU)
      print(" Pas de réseau : Analyse Edge AI via Gemma sur le GPU");
      result = await _runLocalAnalysis(diseaseName, plantName, key);
    }

    _cache[key] = result;

    // Enregistrer dans la mémoire utilisateur
    if (diseaseName.toLowerCase() != "sain") {
      await MemoryService().recordScan(
        plant: plantName,
        disease: diseaseName,
        confidence: confidence,
        severity: severityLevel,
      );
    }

    return result;
  }

  // ══════════════════════════════════════════════════════
  //  MÉTHODE INTERNE : EXÉCUTION LOCALE (GEMMA)
  //  Prompt allégé pour réponse rapide (~15-20s vs ~53s)
  // ══════════════════════════════════════════════════════

  Future<AIRecommendation> _runLocalAnalysis(
      String disease,
      String plant,
      String cacheKey
      ) async {
    try {
      final gemmaService = GemmaService();
      if (!gemmaService.isInitialized) {
        await gemmaService.initAI();
      }

      // Prompt ALLÉGÉ pour Gemma (moins de champs = plus rapide) + RAG
      final lightPrompt = await _buildLightPrompt(
        disease: disease,
        plant: plant,
      );

      String rawText = await gemmaService.sendMessage(lightPrompt);

      //  NETTOYAGE DU JSON
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      final parsed = jsonDecode(rawText) as Map<String, dynamic>;
      final reco   = AIRecommendation.fromJson(parsed);

      return reco;

    } catch (e) {
      print(" Erreur Gemma ou JSON invalide : $e");
      return AIRecommendation.offline(disease, plant);
    }
  }

  // ══════════════════════════════════════════════════════
  //  PROMPT AGRONOMIQUE COMPLET (GROQ CLOUD)
  // ══════════════════════════════════════════════════════

  Future<String> _buildPrompt({
    required String disease,
    required String plant,
    required String severity,
    required double confidence,
    required String region,
  }) async {
    //  Récupération du contexte RAG (Top 3 docs)
    final ragDocs = await KnowledgeBaseService().search('$disease $plant', topK: 3);
    final ragContext = ragDocs.map((d) => '--- ${d.title} ---\n${d.content}').join('\n\n');
    
    //  Récupération de la mémoire
    final memoryContext = await MemoryService().buildMemoryPromptBlock();

    return '''
Tu es un expert agronome spécialisé dans les maladies des cultures au $region.
Un système d'IA a détecté la maladie suivante :

- Culture   : $plant
- Maladie   : $disease
- Sévérité  : $severity
- Confiance : ${(confidence * 100).round()}%
- Région    : $region

 BASE DE CONNAISSANCES (RAG)
Utilise ces informations pour formuler tes conseils de traitement :
$ragContext

$memoryContext

Réponds UNIQUEMENT avec un objet JSON valide, sans texte avant ni après,
sans balises markdown, exactement dans ce format :

{
  "disease_name_fr": "Nom complet en français",
  "disease_name_scientific": "Nom scientifique latin",
  "description": "Description 2-3 phrases : causes et symptômes visibles",
  "severity_explanation": "Ce que ce niveau de sévérité implique concrètement",
  "urgency": "immediate",
  "urgency_label": "Libellé court ex: Dans les 48h",
  "treatment_steps": [
    {
      "step": 1,
      "title": "Titre action",
      "description": "Description détaillée",
      "timing": "Quand"
    }
  ],
  "products": [
    {
      "name": "Nom produit",
      "type": "fongicide",
      "active_ingredient": "Matière active",
      "dose_per_ha": "X L/ha",
      "water_volume": "X L/ha",
      "frequency": "Fréquence",
      "pre_harvest_delay": "X jours",
      "availability_morocco": true,
      "estimated_cost_dh": "X DH/ha"
    }
  ],
  "application_schedule": [
    {"day": "J0",  "action": "Description action J0"},
    {"day": "J14", "action": "Description action J14"}
  ],
  "prevention_tips": [
    "Conseil 1",
    "Conseil 2",
    "Conseil 3",
    "Conseil 4"
  ],
  "economic_impact": {
    "yield_loss_without_treatment": "X% de perte estimée",
    "treatment_cost": "X DH/ha",
    "roi": "X% retour sur investissement"
  },
  "weather_conditions": "Conditions météo favorisant cette maladie",
  "affected_parts": ["Feuilles", "Tiges"],
  "severity_score": 65
}
''';
  }

  // ══════════════════════════════════════════════════════
  //  PROMPT ALLÉGÉ POUR GEMMA (LOCAL / EDGE AI)
  //  → Moins de champs = réponse ~3x plus rapide
  // ══════════════════════════════════════════════════════

  Future<String> _buildLightPrompt({
    required String disease,
    required String plant,
  }) async {
    //  Récupération du contexte RAG (Top 2 docs en mode local pour gagner de la place)
    final ragDocs = await KnowledgeBaseService().search('$disease $plant', topK: 2);
    final ragContext = ragDocs.map((d) => '--- ${d.title} ---\n${d.content}').join('\n');
    
    //  Récupération de la mémoire
    final memoryContext = await MemoryService().buildMemoryPromptBlock();

    return '''
Maladie "$disease" détectée sur $plant.
Docs RAG:
$ragContext
Mémoire:
$memoryContext

Réponds UNIQUEMENT en JSON valide :
{
  "disease_name_fr": "nom français",
  "disease_name_scientific": "nom latin",
  "description": "2 phrases max",
  "severity_explanation": "1 phrase",
  "urgency": "immediate",
  "urgency_label": "Dans les 48h",
  "treatment_steps": [{"step":1,"title":"action","description":"détail","timing":"quand"}],
  "products": [{"name":"produit","type":"fongicide","active_ingredient":"matière","dose_per_ha":"dose","water_volume":"volume","frequency":"freq","pre_harvest_delay":"délai","availability_morocco":true,"estimated_cost_dh":"coût"}],
  "application_schedule": [{"day":"J0","action":"action"}],
  "prevention_tips": ["conseil1","conseil2"],
  "economic_impact": {"yield_loss_without_treatment":"perte","treatment_cost":"coût","roi":"roi"},
  "weather_conditions": "conditions",
  "affected_parts": ["Feuilles"],
  "severity_score": 65
}
''';
  }
}

// ══════════════════════════════════════════════════════════
//  MODÈLES DE DONNÉES
// ══════════════════════════════════════════════════════════

class AIRecommendation {
  final String diseaseNameFr;
  final String diseaseNameScientific;
  final String description;
  final String severityExplanation;
  final String urgency;
  final String urgencyLabel;
  final List<TreatmentStep> treatmentSteps;
  final List<ProductRecommendation> products;
  final List<ScheduleItem> applicationSchedule;
  final List<String> preventionTips;
  final EconomicImpact economicImpact;
  final String weatherConditions;
  final List<String> affectedParts;
  final int severityScore;

  const AIRecommendation({
    required this.diseaseNameFr,
    required this.diseaseNameScientific,
    required this.description,
    required this.severityExplanation,
    required this.urgency,
    required this.urgencyLabel,
    required this.treatmentSteps,
    required this.products,
    required this.applicationSchedule,
    required this.preventionTips,
    required this.economicImpact,
    required this.weatherConditions,
    required this.affectedParts,
    required this.severityScore,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      diseaseNameFr        : json['disease_name_fr']         ?? '',
      diseaseNameScientific: json['disease_name_scientific']  ?? '',
      description          : json['description']             ?? '',
      severityExplanation  : json['severity_explanation']    ?? '',
      urgency              : json['urgency']                 ?? '48h',
      urgencyLabel         : json['urgency_label']           ?? '',
      treatmentSteps       : (json['treatment_steps'] as List? ?? [])
          .map((s) => TreatmentStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      products             : (json['products'] as List? ?? [])
          .map((p) => ProductRecommendation.fromJson(p as Map<String, dynamic>))
          .toList(),
      applicationSchedule  : (json['application_schedule'] as List? ?? [])
          .map((s) => ScheduleItem.fromJson(s as Map<String, dynamic>))
          .toList(),
      preventionTips       : List<String>.from(json['prevention_tips'] ?? []),
      economicImpact       : EconomicImpact.fromJson(
          json['economic_impact'] as Map<String, dynamic>? ?? {}),
      weatherConditions    : json['weather_conditions'] ?? '',
      affectedParts        : List<String>.from(json['affected_parts'] ?? []),
      severityScore        : (json['severity_score'] as num?)?.toInt() ?? 50,
    );
  }

  factory AIRecommendation.offline(String disease, String plant) {
    return AIRecommendation(
      diseaseNameFr        : disease,
      diseaseNameScientific: '',
      description          : 'Maladie détectée sur votre culture de $plant. '
          'Connectez-vous pour une analyse complète.',
      severityExplanation  : 'Analyse en attente de connexion.',
      urgency              : '48h',
      urgencyLabel         : 'Dans les 48h',
      treatmentSteps       : [
        TreatmentStep(step: 1, title: 'Isolez les plants malades',
            description: 'Retirez les feuilles infectées immédiatement.',
            timing: 'Immédiatement'),
        TreatmentStep(step: 2, title: 'Consultez un agronome',
            description: 'Pour un traitement adapté à votre situation.',
            timing: 'Dans les 24h'),
      ],
      products             : [],
      applicationSchedule  : [],
      preventionTips       : [
        'Surveillez régulièrement vos cultures',
        'Maintenez une bonne aération entre les rangs',
        'Évitez l\'irrigation foliaire le soir',
      ],
      economicImpact: EconomicImpact(
        yieldLossWithoutTreatment: 'Non calculé',
        treatmentCost            : 'Non calculé',
        roi                      : 'Non calculé',
      ),
      weatherConditions: 'Humidité élevée favorise le développement.',
      affectedParts    : ['Feuilles'],
      severityScore    : 50,
    );
  }
}

class TreatmentStep {
  final int step;
  final String title, description, timing;
  const TreatmentStep({
    required this.step, required this.title,
    required this.description, required this.timing,
  });
  factory TreatmentStep.fromJson(Map<String, dynamic> j) => TreatmentStep(
    step       : (j['step'] as num?)?.toInt() ?? 0,
    title      : j['title']       ?? '',
    description: j['description'] ?? '',
    timing     : j['timing']      ?? '',
  );
}

class ProductRecommendation {
  final String name, type, activeIngredient, dosePerHa, waterVolume;
  final String frequency, preHarvestDelay, estimatedCostDh;
  final bool availabilityMorocco;
  const ProductRecommendation({
    required this.name,      required this.type,
    required this.activeIngredient, required this.dosePerHa,
    required this.waterVolume,      required this.frequency,
    required this.preHarvestDelay,  required this.estimatedCostDh,
    required this.availabilityMorocco,
  });
  factory ProductRecommendation.fromJson(Map<String, dynamic> j) =>
      ProductRecommendation(
        name                : j['name']                ?? '',
        type                : j['type']                ?? '',
        activeIngredient    : j['active_ingredient']   ?? '',
        dosePerHa           : j['dose_per_ha']         ?? '',
        waterVolume         : j['water_volume']        ?? '',
        frequency           : j['frequency']           ?? '',
        preHarvestDelay     : j['pre_harvest_delay']   ?? '',
        estimatedCostDh     : j['estimated_cost_dh']   ?? '',
        availabilityMorocco : j['availability_morocco'] as bool? ?? true,
      );
}

class ScheduleItem {
  final String day, action;
  const ScheduleItem({required this.day, required this.action});
  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
    day   : j['day']    ?? '',
    action: j['action'] ?? '',
  );
}

class EconomicImpact {
  final String yieldLossWithoutTreatment, treatmentCost, roi;
  const EconomicImpact({
    required this.yieldLossWithoutTreatment,
    required this.treatmentCost,
    required this.roi,
  });
  factory EconomicImpact.fromJson(Map<String, dynamic> j) => EconomicImpact(
    yieldLossWithoutTreatment: j['yield_loss_without_treatment'] ?? '',
    treatmentCost            : j['treatment_cost']              ?? '',
    roi                      : j['roi']                         ?? '',
  );
}

class AIServiceException implements Exception {
  final String message;
  const AIServiceException(this.message);
  @override String toString() => 'AIServiceException: $message';
}