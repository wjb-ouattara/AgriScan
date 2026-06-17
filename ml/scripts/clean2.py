import os
from PIL import Image
import warnings

warnings.filterwarnings("ignore")

# 🚨 Vérifie bien que c'est le bon dossier
DOSSIER = "dataset"

fantomes_tues = 0
images_corrompues_tuees = 0

print("🕵️‍♂️ Démarrage de la grande purge...")

for racine, _, fichiers in os.walk(DOSSIER):
    for fichier in fichiers:
        chemin_complet = os.path.join(racine, fichier)

        # 1. ÉLIMINATION DES FANTÔMES (Windows & Mac)
        if "Zone.Identifier" in fichier or fichier.startswith("._"):
            try:
                os.remove(chemin_complet)
                fantomes_tues += 1
            except Exception as e:
                pass
            continue  # On passe au fichier suivant

        # 2. VÉRIFICATION DES VRAIES IMAGES
        if fichier.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp')):
            try:
                img = Image.open(chemin_complet)
                img.verify()  # Vérifie l'intégrité de la structure

                # Test de lecture forcée (Le même test que Keras)
                img = Image.open(chemin_complet)
                img.load()
            except Exception as e:
                print(f"🗑️ Image corrompue détruite : {fichier} ({e})")
                os.remove(chemin_complet)
                images_corrompues_tuees += 1

print("-" * 40)
print("✅ PURGE TERMINÉE AVEC SUCCÈS !")
print(f"👻 Fantômes systèmes éliminés : {fantomes_tues}")
print(f"💀 Images corrompues éliminées : {images_corrompues_tuees}")