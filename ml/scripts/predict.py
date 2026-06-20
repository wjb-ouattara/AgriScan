import os

os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch

# Le fix anti-panique, toujours utile
torch.backends.cudnn.enabled = False

import keras
import numpy as np
from keras import utils

# --- CONFIGURATION ---
# Remplace ceci par le chemin vers l'image que tu veux tester
IMAGE_TEST_PATH = "test-i/img_4.png"
MODEL_PATH = "agriscan_mobilenet_final_finetuned.keras"

# Les classes exactes de ton dataset (attention à l'ordre alphabétique !)
# Vérifie cet ordre en regardant les noms de dossiers dans agriscan_final_v2/train
CLASS_NAMES = [ 'f_GLS', 'f_NLB', 'f_RUST','Healthy', 'v_MLN', 'v_MSV']

print("\n🔍 DÉMARRAGE DE L'AGRISCAN-EXPERT 🔍")
print("=" * 40)

# 1. Chargement du Modèle
print("Chargement du cerveau expert...")
try:
    model = keras.models.load_model(MODEL_PATH)
except Exception as e:
    print(f"❌ Impossible de charger le modèle : {e}")
    exit()

# 2. Préparation de l'Image
print(f"Analyse de l'image : {IMAGE_TEST_PATH}")
try:
    # On charge l'image et on la force en 224x224
    img = utils.load_img(IMAGE_TEST_PATH, target_size=(224, 224))

    # On convertit l'image en tableau de nombres
    img_array = utils.img_to_array(img)

    # Le modèle attend un Batch. On passe de (224, 224, 3) à (1, 224, 224, 3)
    img_array = np.expand_dims(img_array, axis=0)

except Exception as e:
    print(f"❌ Erreur lors de l'ouverture de l'image : {e}")
    exit()

# 3. La Prédiction
print("\nCalcul du diagnostic en cours...\n")
predictions = model.predict(img_array, verbose=0)  # verbose=0 pour cacher la barre de chargement

# 'predictions' ressemble à ça : [[0.01, 0.05, 0.80, ...]] (La somme fait 1.0)
# On récupère le tableau des pourcentages pour notre seule image
score = predictions[0]

# On trouve l'indice du pourcentage le plus élevé
best_index = np.argmax(score)
best_class = CLASS_NAMES[best_index]
best_confidence = score[best_index] * 100

# 4. Affichage du Résultat
print("=" * 40)
print(f"🩺 VERDICT AGRISCAN :")
print(f"Maladie détectée : ** {best_class} **")
print(f"Niveau de confiance : {best_confidence:.2f} %")
print("=" * 40)

# Optionnel : Afficher le détail de toutes les probabilités
print("\n--- Détail du scan ---")
for i, class_name in enumerate(CLASS_NAMES):
    print(f"{class_name:<10}: {score[i] * 100:.2f}%")