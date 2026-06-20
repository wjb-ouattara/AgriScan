import os
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch
torch.backends.cudnn.enabled = False

import keras
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.cm as cm
from PIL import Image
from rembg import remove

# --- 1. CONFIGURATION ---
IMAGE_PATH = "test-i/img.png"
MODEL_PATH = "agriscan_convnext_FINAL.keras"  # ✅ Adapté ConvNeXt
# ✅ LA VRAIE LISTE (Alignée avec le modèle Keras)
CLASS_NAMES = [
    "Healthy",  # Index 0
    "f_GLS",  # Index 1
    "f_NLB",  # Index 2
    "f_RUST",  # Index 3
    "v_MLN",  # Index 4
    "v_MSV"  # Index 5
]


print("\n🔬 GRAD-CAM CONVNEXT - AGRISCAN 🔬")

print("📦 Chargement du modèle ConvNeXt...")
model = keras.models.load_model(MODEL_PATH)

# --- 1.5 PRÉPARATION DE L'IMAGE (sans détourage) ---
print("📸 Chargement et redimensionnement de l'image...")
pil_img = Image.open(IMAGE_PATH).convert("RGB")
img_resized = pil_img.resize((224, 224))
img_array = keras.utils.img_to_array(img_resized)
img_array_batch = np.expand_dims(img_array, axis=0)
# --- 2. DÉCOUPAGE DU CERVEAU ---
# ✅ FIX : On accède directement au backbone sans recréer un Model depuis model.inputs

base_model = None
base_idx = -1
for i, layer in enumerate(model.layers):
    if isinstance(layer, keras.Model) and "convnext" in layer.name.lower():
        base_model = layer
        base_idx = i
        break

if base_idx == -1:
    for i, layer in enumerate(model.layers):
        if isinstance(layer, keras.Model):
            base_idx = i
            base_model = layer
            break

if base_model is None:
    print("❌ Backbone introuvable. Couches disponibles :")
    for i, l in enumerate(model.layers):
        print(f"  [{i}] {l.name} — {type(l).__name__}")
    exit()

print(f"✅ Backbone : {base_model.name} (couche {base_idx})")

# ✅ FIX PRINCIPAL : On crée un Input frais, indépendant du modèle original
fresh_input = keras.Input(shape=(224, 224, 3))

# Feature extractor : Input frais → backbone ConvNeXt
feature_extractor = keras.Model(
    inputs=fresh_input,
    outputs=base_model(fresh_input)
)

# Classifier : sortie du backbone → reste des couches
classifier_input = keras.Input(shape=base_model.output_shape[1:])
x = classifier_input
for layer in model.layers[base_idx + 1:]:
    x = layer(x)
classifier = keras.Model(inputs=classifier_input, outputs=x)
# --- 3. GRAD-CAM PYTORCH ---
print("🔥 Calcul Grad-CAM...")

img_tensor = torch.tensor(img_array_batch, dtype=torch.float32)
features = feature_extractor(img_tensor)
features = features.detach().clone()
features.requires_grad_(True)

preds = classifier(features)
pred_index = torch.argmax(preds[0])
pred_score = preds[0, pred_index]
pred_name = CLASS_NAMES[pred_index.item()] if pred_index.item() < len(CLASS_NAMES) else f"Classe {pred_index.item()}"

print(f"\n🌽 Diagnostic : {pred_name}")
print(f"   Confiance : {pred_score.item() * 100:.1f}%")
print("\n📊 Toutes les probabilités :")
for i, score in enumerate(preds[0]):
    name = CLASS_NAMES[i] if i < len(CLASS_NAMES) else f"Classe {i}"
    bar = "█" * int(score.item() * 20)
    print(f"   {name:<25} {score.item()*100:5.1f}% {bar}")

pred_score.backward()
grads = features.grad

# --- 4. CONSTRUCTION DE LA HEATMAP ---
# ✅ ADAPTÉ : ConvNeXt sort (B, H, W, C) en channels_last
# On moyenne sur le batch et les dimensions spatiales
pooled_grads = torch.mean(grads, dim=(0, 1, 2))

features_np = features.detach().cpu().numpy()[0]
pooled_grads_np = pooled_grads.detach().cpu().numpy()

heatmap = features_np @ pooled_grads_np
heatmap = np.maximum(heatmap, 0)
if np.max(heatmap) > 0:
    heatmap /= np.max(heatmap)

# --- 5. AFFICHAGE ---
print("\n🖼️ Génération du rapport visuel...")
heatmap_uint8 = np.uint8(255 * heatmap)
jet = cm.get_cmap("jet")
jet_colors = jet(np.arange(256))[:, :3]
jet_heatmap = jet_colors[heatmap_uint8]

jet_heatmap_img = keras.utils.array_to_img(jet_heatmap)
jet_heatmap_img = jet_heatmap_img.resize((224, 224))
jet_heatmap_np = keras.utils.img_to_array(jet_heatmap_img)

superimposed = jet_heatmap_np * 0.4 + img_array
superimposed_img = keras.utils.array_to_img(superimposed)

plt.figure(figsize=(14, 5))

plt.subplot(1, 3, 1)
plt.title("Image originale")
plt.imshow(Image.open(IMAGE_PATH).convert("RGB").resize((224, 224)))
plt.axis('off')

plt.subplot(1, 3, 2)
plt.title("Vue modèle (fond noir)")
plt.imshow(keras.utils.array_to_img(img_array))
plt.axis('off')

plt.subplot(1, 3, 3)
plt.title(f"Grad-CAM → {pred_name} ({pred_score.item()*100:.1f}%)")
plt.imshow(superimposed_img)
plt.axis('off')

plt.tight_layout()
output_name = f"gradcam_{pred_name.lower()}.png"
plt.savefig(output_name, dpi=150)
plt.show()
print(f"\n✅ Rapport sauvegardé : {output_name}")