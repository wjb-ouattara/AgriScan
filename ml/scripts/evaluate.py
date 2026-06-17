import os
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch
# Le fix anti-panique Nitro
torch.backends.cudnn.enabled = False

import keras
import numpy as np

# --- CONFIGURATION ---
IMG_SIZE = (224, 224)
BATCH_SIZE = 8
DATA_PATH = "agriscan_final_v2" # Ton dossier avec train/val/test
MODEL_PATH = "agriscan_mobilenet_final_finetuned.keras"

print("\n" + "="*50)
print("🎓 EXAMEN FINAL : ÉVALUATION SUR LE TEST SET 🎓")
print("="*50 + "\n")

# 1. Chargement du modèle expert
print("Chargement du modèle expert...")
try:
    model = keras.models.load_model(MODEL_PATH)
except Exception as e:
    print(f"❌ Impossible de charger le modèle : {e}")
    exit()

# 2. Chargement du Test Set (Le jeu de données inconnu)
print("Préparation de l'examen final...")
try:
    test_ds = keras.utils.image_dataset_from_directory(
        os.path.join(DATA_PATH, 'test'), # <-- On pointe sur le dossier TEST !
        image_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        label_mode='categorical',
        shuffle=False # Pas besoin de mélanger pour l'évaluation
    )
except Exception as e:
    print(f"❌ Erreur lors du chargement des données de test : {e}")
    exit()

# 3. L'Évaluation Officielle
print("\nLancement du test officiel... (Veuillez patienter)")
# La méthode 'evaluate' calcule la perte et les métriques sur tout le dataset
results = model.evaluate(test_ds, verbose=1)

# results[0] est la perte (Loss), results[1] est la précision (Accuracy)
test_loss = results[0]
test_accuracy = results[1] * 100

print("\n" + "="*50)
print("🏆 RÉSULTATS OFFICIELS DU MODÈLE AGRISCAN 🏆")
print(f"-> Précision Globale (Accuracy) : {test_accuracy:.2f} %")
print(f"-> Marge d'erreur (Loss)       : {test_loss:.4f}")
print("="*50 + "\n")

# Interprétation de "Tech Lead"
if test_accuracy >= 90:
    print("Commentaire : Excellent travail ! Ce modèle est prêt pour la production.")
elif test_accuracy >= 80:
    print("Commentaire : Très bon modèle. Quelques confusions possibles, mais solide.")
else:
    print("Commentaire : Le modèle a du mal sur les nouvelles données. Attention à l'overfitting (le modèle a peut-être trop appris le jeu d'entraînement par cœur).")