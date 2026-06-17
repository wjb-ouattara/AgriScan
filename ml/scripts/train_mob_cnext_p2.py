import os
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch
torch.backends.cudnn.enabled = False
import keras
import matplotlib.pyplot as plt

keras.config.set_image_data_format("channels_last")
EPOCHS_PHASE_2 = 20
IMG_SIZE = (224, 224)
BATCH_SIZE = 8
DATA_PATH = "dataset/dataset"

print("📂 Chargement des données Phase 2...")
train_ds = keras.utils.image_dataset_from_directory(
    os.path.join(DATA_PATH, 'train'),
    image_size=IMG_SIZE, batch_size=BATCH_SIZE, label_mode='categorical'
)

val_ds = keras.utils.image_dataset_from_directory(
    os.path.join(DATA_PATH, 'val'),
    image_size=IMG_SIZE, batch_size=BATCH_SIZE, label_mode='categorical'
)

print("🧠 Chargement du modèle Phase 1...")
model = keras.models.load_model("agriscan_convnext_brut.keras")

print("🔓 Dégel des 20 dernières couches ConvNeXt...")
for layer in model.layers:
    if layer.name.startswith("convnext"):
        layer.trainable = True
        sub_layers = layer.layers
        n = len(sub_layers)
        for i, inner_layer in enumerate(sub_layers):
            inner_layer.trainable = (i >= n - 20)
        print(f"   → {sum(l.trainable for l in sub_layers)}/{n} couches dégelées")

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-5),
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

model.summary()

callbacks = [
    keras.callbacks.ModelCheckpoint(
        "agriscan_convnext_FINAL.keras",
        save_best_only=True,
        monitor='val_accuracy',
        verbose=1
    ),
    keras.callbacks.EarlyStopping(
        patience=6,
        restore_best_weights=True,
        monitor='val_accuracy'
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
     factor=0.3,
        patience=3,
        verbose=1
    )
]

def plot_history(history, filename='courbes.png', title_suffix=''):
    acc      = history.history['accuracy']
    val_acc  = history.history['val_accuracy']
    loss     = history.history['loss']
    val_loss = history.history['val_loss']
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

print("🔥 Fine-Tuning en cours...")
history_finetune = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=20,
    callbacks=callbacks
)

print("✅ Modèle final sauvegardé !")
plot_history(history_finetune, 'courbes_convnext_phase2.png', 'Phase 2 - Fine Tuning')