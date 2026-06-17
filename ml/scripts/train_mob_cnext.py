import os
import gc
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch


print("🔥 Ma RTX 5060 est-elle réveillée ? ->", torch.cuda.is_available())
torch.cuda.empty_cache()
gc.collect()
torch.backends.cudnn.enabled = False
# → Ça désactive l'accélération GPU, ta RTX 5060 tournait au ralenti !
# → Ne l'active que si tu as un crash spécifique cuDNN

import keras
from keras import layers

import matplotlib.pyplot as plt

keras.config.set_image_data_format("channels_last")

IMG_SIZE = (224, 224)
BATCH_SIZE = 16 # Tu peux monter à 16 ou 32, la RTX 5060 peut encaisser
EPOCHS = 30
DATA_PATH = "dataset/dataset"
NUM_CLASSES = 6  # ✅ AJOUTÉ : variable explicite, plus facile à modifier

print("📂 Chargement des données...")
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




# Récupère les noms des classes pour plus tard
class_names = train_ds.class_names
print(f"Classes détectées : {class_names}")

# Data Augmentation
data_augmentation = keras.Sequential([
    layers.RandomFlip("horizontal_and_vertical"),
    layers.RandomRotation(0.2),
    layers.RandomZoom(0.2),
    layers.RandomBrightness(0.1),   # ✅ AJOUTÉ : utile pour images de terrain
    layers.RandomContrast(0.1),     # ✅ AJOUTÉ : variations d'éclairage
])

print("🧠 Téléchargement de ConvNeXt Tiny...")
base_model = keras.applications.ConvNeXtTiny(
    input_shape=(224, 224, 3),
    include_top=False,
    weights="imagenet"
)
base_model.trainable = False

inputs = keras.Input(shape=(224, 224, 3))
x = data_augmentation(inputs)
x = base_model(x, training=False)  # ✅ CORRIGÉ : training=False obligatoire
                                    # quand le modèle est gelé, sinon BatchNorm se dérègle
x = layers.GlobalAveragePooling2D()(x)
x = layers.Dropout(0.3)(x)
outputs = layers.Dense(NUM_CLASSES, activation='softmax')(x)

model = keras.Model(inputs, outputs)

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),  # ✅ LR explicite
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()

# ✅ AJOUTÉ : Callbacks essentiels
callbacks = [
    keras.callbacks.ModelCheckpoint(
        "agriscan_convnext_brut.keras",
        save_best_only=True,
        monitor='val_accuracy',
        verbose=1
    ),
    keras.callbacks.EarlyStopping(
        patience=5,
        restore_best_weights=True,
        monitor='val_accuracy'
    ),
    keras.callbacks.ReduceLROnPlateau(
        factor=0.3,
        patience=3,
        monitor='val_loss',
        verbose=1
    )
]

print("🔥 Démarrage ConvNeXt sur la RTX 5060 !")
history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS,
    callbacks=callbacks  # ✅ AJOUTÉ
)

# Courbes
def plot_history(history, filename='courbes_convnext.png', title_suffix='ConvNeXt'):
    acc     = history.history['accuracy']
    val_acc = history.history['val_accuracy']
    loss    = history.history['loss']
    val_loss= history.history['val_loss']
    epochs_range = range(len(acc))

    plt.figure(figsize=(12, 5))
    plt.subplot(1, 2, 1)
    plt.plot(epochs_range, acc,     label='Train', color='#2ecc71', lw=2)
    plt.plot(epochs_range, val_acc, label='Val',   color='#e67e22', lw=2)
    plt.title(f'Précision ({title_suffix})')
    plt.xlabel('Époques'); plt.ylabel('Score')
    plt.legend(loc='lower right'); plt.grid(alpha=0.3)

    plt.subplot(1, 2, 2)
    plt.plot(epochs_range, loss,     label='Train', color='#e74c3c', lw=2)
    plt.plot(epochs_range, val_loss, label='Val',   color='#3498db', lw=2)
    plt.title(f'Perte ({title_suffix})')
    plt.xlabel('Époques'); plt.ylabel('Erreur')
    plt.legend(loc='upper right'); plt.grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig(filename)
    print(f"📊 Courbes sauvegardées : {filename}")

plot_history(history)