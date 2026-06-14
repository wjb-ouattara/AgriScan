// ══════════════════════════════════════════════════════════
//  KNOWLEDGE SEED
//  Base de connaissances agronomiques initiale (RAG).
//  Fiches enrichies : 5 maladies du maïs + plante saine
//  + calendrier cultural + fertilisation/irrigation (Maroc).
// ══════════════════════════════════════════════════════════

class KnowledgeSeedDoc {
  final String title;
  final String content;
  final List<String> tags;
  const KnowledgeSeedDoc({
    required this.title,
    required this.content,
    required this.tags,
  });
}

const List<KnowledgeSeedDoc> kKnowledgeSeed = [
  KnowledgeSeedDoc(
    title: 'Cercosporiose grise du maïs (GLS)',
    tags: ['f_GLS', 'maladie', 'fongique', 'maïs', 'feuilles', 'cercosporiose'],
    content:
    'La cercosporiose grise du maïs (Gray Leaf Spot, GLS) est une '
        'maladie FONGIQUE causée par le champignon Cercospora zeae-maydis. '
        'Elle se manifeste par des lésions rectangulaires gris-brun à brun '
        'clair, allongées entre les nervures des feuilles, qui peuvent '
        'fusionner et provoquer un dessèchement important du feuillage. '
        'Les conditions favorables sont une humidité élevée, des '
        'températures chaudes (24-30°C) et un temps nuageux prolongé, '
        'surtout en monoculture de maïs.\n\n'
        'Traitement : application de fongicides à base de strobilurines ou '
        'de triazoles (azoxystrobine, propiconazole) dès l\'apparition des '
        'premiers symptômes, en particulier sur les feuilles supérieures '
        'proches de l\'épi.\n\n'
        'Prévention : rotation des cultures avec une plante non hôte, '
        'choix de variétés tolérantes, gestion des résidus de récolte '
        '(enfouissement), et aération du couvert végétal par un espacement '
        'adapté.',
  ),
  KnowledgeSeedDoc(
    title: 'Helminthosporiose du maïs (NLB)',
    tags: ['f_NLB', 'maladie', 'fongique', 'maïs', 'feuilles', 'helminthosporiose'],
    content:
    'L\'helminthosporiose du maïs (Northern Corn Leaf Blight, NLB) est '
        'une maladie FONGIQUE causée par le champignon Exserohilum '
        'turcicum. Elle provoque de grandes lésions elliptiques ou en '
        'forme de cigare, de couleur gris-vert à brun, pouvant atteindre '
        '15 cm de long, orientées le long des nervures. En cas '
        'd\'infection sévère, le feuillage peut sembler brûlé par le gel. '
        'La maladie se développe par temps humide et températures '
        'modérées (18-27°C), avec des rosées matinales fréquentes.\n\n'
        'Traitement : fongicides à base de strobilurines, triazoles ou '
        'mélanges (pyraclostrobine + metconazole), appliqués '
        'préventivement ou dès les premiers symptômes sur les feuilles du '
        'tiers supérieur.\n\n'
        'Prévention : rotation culturale, destruction des débris végétaux '
        'infectés par labour, et utilisation de semences de variétés '
        'résistantes ou tolérantes au NLB.',
  ),
  KnowledgeSeedDoc(
    title: 'Rouille commune du maïs',
    tags: ['f_RUST', 'maladie', 'fongique', 'maïs', 'feuilles', 'rouille'],
    content:
    'La rouille commune du maïs est une maladie FONGIQUE causée par le '
        'champignon Puccinia sorghi. Elle se caractérise par de petites '
        'pustules ovales ou allongées, de couleur rouille à brun-orangé, '
        'dispersées sur les deux faces des feuilles, qui libèrent une '
        'poudre de spores orangée au toucher. Elle se développe surtout '
        'par temps frais et humide (16-25°C), avec une forte humidité '
        'relative. Bien que généralement moins destructrice que le GLS ou '
        'le NLB, une infection sévère et précoce peut réduire le '
        'rendement.\n\n'
        'Traitement : fongicides à base de triazoles (propiconazole, '
        'tébuconazole) si l\'infection touche plus de 5% de la surface '
        'foliaire avant la floraison.\n\n'
        'Prévention : semis de variétés résistantes, surveillance '
        'régulière en début de saison, et éviter les excès d\'irrigation '
        'par aspersion qui prolongent l\'humidité foliaire.',
  ),
  KnowledgeSeedDoc(
    title: 'Nécrose Létale du Maïs (MLN)',
    tags: ['v_MLN', 'maladie', 'virale', 'maïs', 'necrose', 'mln'],
    content:
    'La nécrose létale du maïs (Maize Lethal Necrosis, MLN) est une '
        'maladie VIRALE grave résultant d\'une co-infection entre le Maize '
        'Chlorotic Mottle Virus (MCMV) et un potyvirus comme le Sugarcane '
        'Mosaic Virus (SCMV). CE N\'EST PAS UNE MALADIE FONGIQUE : aucun '
        'fongicide n\'est efficace. Les symptômes incluent une mosaïque '
        'chlorotique sévère, un jaunissement prononcé, un rabougrissement '
        'des plants, et une nécrose progressive qui peut tuer la plante '
        'avant la formation des épis. La transmission se fait par insectes '
        'vecteurs (pucerons pour le SCMV, chrysomèles et thrips pour le '
        'MCMV) et par les semences contaminées.\n\n'
        'Traitement : il n\'existe pas de traitement curatif ; il faut '
        'arracher et détruire les plants fortement atteints pour limiter '
        'la propagation.\n\n'
        'Prévention : utiliser des semences certifiées indemnes, planter '
        'des variétés tolérantes au MLN, contrôler les populations '
        'd\'insectes vecteurs avec des insecticides ciblés, et pratiquer '
        'la rotation des cultures pour casser le cycle des virus.',
  ),
  KnowledgeSeedDoc(
    title: 'Striure du maïs (MSV)',
    tags: ['v_MSV', 'maladie', 'virale', 'maïs', 'striure', 'msv'],
    content:
    'La striure du maïs (Maize Streak Virus, MSV) est une maladie '
        'VIRALE transmise exclusivement par des cicadelles du genre '
        'Cicadulina. CE N\'EST PAS UNE MALADIE FONGIQUE. Les symptômes '
        'typiques sont de fines stries jaunes parallèles aux nervures, qui '
        'débutent sur les jeunes feuilles et peuvent s\'étendre à toute la '
        'plante, accompagnées d\'un retard de croissance et d\'une '
        'réduction importante du rendement, surtout en cas d\'infection '
        'précoce. Le virus persiste dans des graminées sauvages qui '
        'servent de réservoir pour les cicadelles.\n\n'
        'Traitement : aucun traitement curatif n\'existe ; la lutte repose '
        'sur le contrôle des cicadelles vectrices avec des insecticides '
        'systémiques appliqués tôt en saison.\n\n'
        'Prévention : semis précoce pour éviter les pics de population de '
        'cicadelles, élimination des graminées sauvages autour des champs, '
        'et utilisation de variétés résistantes au MSV.',
  ),
  KnowledgeSeedDoc(
    title: 'Maïs sain — surveillance et bonnes pratiques',
    tags: ['Healthy', 'sain', 'prevention', 'surveillance', 'maïs'],
    content:
    'Un maïs sain présente des feuilles d\'un vert uniforme, sans '
        'taches, lésions ou décolorations, une croissance régulière et une '
        'bonne vigueur. Pour maintenir cet état, il est recommandé '
        'd\'inspecter le champ au moins une fois par semaine, en '
        'particulier les feuilles du tiers inférieur où les maladies '
        'fongiques apparaissent souvent d\'abord. Surveiller aussi la '
        'présence de ravageurs (pucerons, cicadelles, chenilles) qui '
        'peuvent transmettre des virus ou affaiblir la plante.\n\n'
        'Une bonne gestion comprend : rotation des cultures (éviter le '
        'maïs après maïs plusieurs années consécutives), espacement '
        'adéquat des plants pour favoriser l\'aération et réduire '
        'l\'humidité foliaire, fertilisation équilibrée (azote, phosphore, '
        'potassium) selon les analyses de sol, et irrigation adaptée '
        'évitant les excès d\'humidité prolongée qui favorisent les '
        'maladies fongiques. La détection précoce via une application '
        'comme AgriScan permet d\'intervenir avant que les maladies ne se '
        'propagent.',
  ),
  KnowledgeSeedDoc(
    title: 'Calendrier cultural du maïs au Maroc',
    tags: ['calendrier', 'semis', 'recolte', 'maroc', 'maïs', 'saison'],
    content:
    'Au Maroc, le maïs est principalement cultivé en cycle de '
        'printemps-été dans les zones irriguées (Gharb, Saïs, Tadla, '
        'Souss) et en cycle d\'été pluvial dans certaines zones. Le semis '
        'a généralement lieu entre mars et mai selon la région et la '
        'disponibilité en eau, avec une levée 7 à 10 jours après semis '
        'dans de bonnes conditions de température (sol > 12°C).\n\n'
        'La phase végétative dure environ 50-60 jours, suivie de la '
        'floraison (apparition des soies) vers 60-75 jours après semis, '
        'période critique nécessitant un apport hydrique suffisant.\n\n'
        'La récolte intervient généralement 110 à 140 jours après semis '
        'selon la variété (précoce, demi-précoce ou tardive), lorsque les '
        'grains atteignent leur maturité physiologique (point noir à la '
        'base du grain) et un taux d\'humidité d\'environ 20-25% pour le '
        'grain humide ou 14-15% pour le stockage. Le choix de la date de '
        'semis doit tenir compte des risques de gel tardif au printemps et '
        'de stress thermique pendant la floraison en été.',
  ),
  KnowledgeSeedDoc(
    title: 'Fertilisation et irrigation du maïs',
    tags: ['fertilisation', 'irrigation', 'azote', 'engrais', 'maïs', 'sol'],
    content:
    'Le maïs est une culture exigeante en azote (N), avec des besoins '
        'totaux d\'environ 200-250 kg N/ha selon le rendement visé, '
        'fractionnés en plusieurs apports : un tiers au semis ou en '
        'starter, et le reste en couverture lors des stades 6-8 feuilles '
        'et avant la floraison. Les besoins en phosphore (P2O5) sont '
        'd\'environ 80-100 kg/ha, apportés majoritairement au semis pour '
        'favoriser l\'enracinement, et en potassium (K2O) d\'environ '
        '150-200 kg/ha selon la richesse du sol.\n\n'
        'Sur sols argileux comme ceux fréquents au Maroc, attention au '
        'drainage : un excès d\'eau stagnante favorise l\'asphyxie '
        'racinaire et les maladies fongiques.\n\n'
        'L\'irrigation doit être régulière mais sans excès, avec un pic de '
        'besoins en eau pendant la floraison et le remplissage des grains '
        '(évapotranspiration élevée). L\'irrigation goutte-à-goutte ou par '
        'aspersion contrôlée limite l\'humidité foliaire prolongée par '
        'rapport à l\'irrigation gravitaire, réduisant ainsi les risques de '
        'maladies fongiques foliaires comme le GLS ou le NLB.',
  ),
];