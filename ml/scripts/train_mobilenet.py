import os
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"# La magie est ici
import torch

torch.backends.cudnn.enabled = False
import keras
from keras import layers, models
import matplotlib.pyplot as plt
keras.config.set_image_data_format("channels_last")
# 1. Configuration des paramètres (Les "Hyperparamètres")
IMG_SIZE = (224, 224)
BATCH_SIZE = 8
EPOCHS = 20
DATA_PATH = "agriscan_sans_fond"

# 2. Chargement des données (Le moment de vérité)
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

# 3. Data Augmentation "On-the-fly" (Pour ignorer tes bords noirs !)
data_augmentation = keras.Sequential([
    layers.RandomRotation(0.2), # On augmente un peu la rotation
    layers.RandomZoom(0.2),
    layers.RandomBrightness(factor=0.3), # SIMULE LE SOLEIL ET LES NUAGES
    layers.RandomContrast(factor=0.3),   # SIMULE LES ZONES D'OMBRE
])

# 4. Construction du modèle MobileNetV3
# On prend le modèle pré-entraîné sur ImageNet (le "cerveau" de base)
base_model = keras.applications.MobileNetV3Large(
    input_shape=(224, 224, 3),
    include_top=False, # On vire la couche finale (elle classait des chiens, pas du maïs)
    weights="imagenet"
)
base_model.trainable = False # On gèle les poids au début (Transfer Learning)

model = models.Sequential([
    layers.Input(shape=(224, 224, 3)),
    data_augmentation,
    layers.Rescaling(1./255), # Normalisation des pixels [0, 1]
    base_model,
    layers.GlobalAveragePooling2D(),
    layers.Dropout(0.2), # Pour éviter que le modèle n'apprenne par cœur
    layers.Dense(len(train_ds.class_names), activation='softmax') # La couche "Diagnostic"
])

# 5. Compilation
model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()

# 6. Entraînement (Prépare le ventilo de ta carte graphique)
history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS
)
def plot_history(history):
    acc = history.history['accuracy']
    val_acc = history.history['val_accuracy']
    loss = history.history['loss']
    val_loss = history.history['val_loss']
    epochs_range = range(len(acc))

    plt.figure(figsize=(12, 5))

    # Graphique de la Précision
    plt.subplot(1, 2, 1)
    plt.plot(epochs_range, acc, label='Training Accuracy', color='#2ecc71', lw=2)
    plt.plot(epochs_range, val_acc, label='Validation Accuracy', color='#e67e22', lw=2)
    plt.title('Précision (Accuracy)')
    plt.xlabel('Époques')
    plt.ylabel('Score')
    plt.legend(loc='lower right')
    plt.grid(alpha=0.3)

    # Graphique de la Perte
    plt.subplot(1, 2, 2)
    plt.plot(epochs_range, loss, label='Training Loss', color='#e74c3c', lw=2)
    plt.plot(epochs_range, val_loss, label='Validation Loss', color='#3498db', lw=2)
    plt.title('Perte (Loss)')
    plt.xlabel('Époques')
    plt.ylabel('Erreur')
    plt.legend(loc='upper right')
    plt.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig('resultats_agriscan.png')


# Appels de la fonction après l'entraînement
plot_history(history)
# Sauvegarde pour ton futur smartphone
model.save("agriscan_mobilenet_v1.keras")