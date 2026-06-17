import os
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch
torch.backends.cudnn.enabled = False

import keras
from keras import layers, models
import matplotlib.pyplot as plt

keras.config.set_image_data_format("channels_last")

# 1. Configuration des Hyperparamètres (identiques)
IMG_SIZE = (224, 224)
BATCH_SIZE = 8
EPOCHS_PHASE_2 = 20
DATA_PATH = "agriscan_final_v2" # Ton dossier propre

# 2. Chargement des données (Le DataLoader)
train_ds = keras.utils.image_dataset_from_directory(
    os.path.join(DATA_PATH, 'train'),
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

val_ds = keras.utils.image_dataset_from_directory(
    os.path.join(DATA_PATH, 'val'),
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    label_mode='categorical'
)

print("\n" + "="*50)
print("🔥 DÉMARRAGE DE LA PHASE 2 : FINE-TUNING")
print("="*50 + "\n")
# 3. CHARGEMENT DU MODÈLE DE LA PHASE 1
print("Chargement du modèle échauffé...")
# C'EST CETTE LIGNE QUI MANQUE OU QUI A DISPARU :
model = keras.models.load_model("agriscan_mobilenet_v1.keras")

# 4. LE DÉGEL (On réveille MobileNet)
print("Dégel du Feature Extractor...")
# Maintenant que 'model' a été défini juste au-dessus, cette ligne va marcher :
model.trainable = True

# On cible le MobileNet (Index 2)
base_model = model.layers[2]


# 5. RE-COMPILATION (Crucial : Learning Rate minuscule)
print("Re-compilation avec Learning Rate à 1e-5...")
model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-5), # Le secret est ici
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

# 6. ENTRAÎNEMENT PHASE 2
print("Que le Fine-Tuning commence !")
history_fine = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS_PHASE_2
)

# 7. SAUVEGARDE ET GRAPHIQUE
model.save("agriscan_mobilenet_final_finetuned.keras")

def plot_history_phase2(history):
    acc = history.history['accuracy']
    val_acc = history.history['val_accuracy']
    loss = history.history['loss']
    val_loss = history.history['val_loss']
    epochs_range = range(len(acc))

    plt.figure(figsize=(12, 5))
    plt.subplot(1, 2, 1)
    plt.plot(epochs_range, acc, label='Training Accuracy', color='#2ecc71', lw=2)
    plt.plot(epochs_range, val_acc, label='Validation Accuracy', color='#e67e22', lw=2)
    plt.title('Précision (Phase 2 - Fine Tuning)')
    plt.xlabel('Époques Phase 2')
    plt.ylabel('Score')
    plt.legend(loc='lower right')
    plt.grid(alpha=0.3)

    plt.subplot(1, 2, 2)
    plt.plot(epochs_range, loss, label='Training Loss', color='#e74c3c', lw=2)
    plt.plot(epochs_range, val_loss, label='Validation Loss', color='#3498db', lw=2)
    plt.title('Perte (Phase 2 - Fine Tuning)')
    plt.xlabel('Époques Phase 2')
    plt.ylabel('Erreur')
    plt.legend(loc='upper right')
    plt.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig('resultats_agriscan_phase2.png')
    plt.show()

plot_history_phase2(history_fine)