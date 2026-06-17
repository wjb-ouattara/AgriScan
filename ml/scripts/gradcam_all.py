import os
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
import cv2
import numpy as np
import matplotlib.pyplot as plt
from rembg import remove
from PIL import Image

# ==============================================================================
# --- 0. CONFIGURATION SYSTÈME ET ENVIRONNEMENT ---
# ==============================================================================
# Cohabitation pacifique Keras/PyTorch
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import torch
import torch.nn as nn
import timm
import keras

# Accélération maximale pour la RTX 5060 (Vitesse x10)
torch.backends.cudnn.benchmark = False
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --- PARAMÈTRES DU PROJET ---
CLASS_NAMES = ["Healthy", "f_GLS", "f_NLB", "f_RUST", "v_MLN", "v_MSV"]
IMG_SIZE = (224, 224)
IMAGE_PATH = "test-i/img_5.png"


# ==============================================================================
# --- 1. LE SCALPEL (Détourage IA) ---
# ==============================================================================
def detourer_image_unique(chemin_entree):
    chemin_sortie = "temp_sans_fond.png"
    print(f"\n✂️ [ÉTAPE 1] Détourage magique de l'image : {chemin_entree}...")

    try:
        input_image = Image.open(chemin_entree)
        output_image = remove(input_image)

        fond_noir = Image.new("RGB", output_image.size, (0, 0, 0))
        fond_noir.paste(output_image, mask=output_image.split()[3])

        img_array = np.array(fond_noir)
        pixels_non_noirs = np.sum(np.any(img_array > 0, axis=-1))
        ratio_feuille = pixels_non_noirs / (img_array.shape[0] * img_array.shape[1])

        if ratio_feuille < 0.15:
            print(f"  ⚠️ rembg a eu un AVC ({ratio_feuille * 100:.1f}% restant). On garde l'originale.")
            return chemin_entree

        fond_noir.save(chemin_sortie)
        print("  ✅ Arrière-plan éliminé avec succès !")
        return chemin_sortie

    except Exception as e:
        print(f"  ❌ Erreur lors du détourage : {e}")
        return chemin_entree

    # ==============================================================================


# --- 2. LES SCANNERS GRAD-CAM ---
# ==============================================================================
def compute_grad_cam_keras(model, img, last_conv_layer_name):
    img_array = np.expand_dims(img, axis=0)
    img_tensor = torch.from_numpy(img_array).float().to(device)

    target_layer = None
    for layer in model.layers:
        if layer.name == last_conv_layer_name:
            target_layer = layer
            break
    if target_layer is None:
        raise ValueError(f"Couche conv '{last_conv_layer_name}' introuvable.")

    gradients, activations = [], []

    def save_gradient(module, grad_input, grad_output):
        gradients.append(grad_output[0])

    def save_activation(module, input, output):
        activations.append(output)

    layer_handle_torch = target_layer.backend_layer if hasattr(target_layer, 'backend_layer') else target_layer

    handle_grad = layer_handle_torch.register_backward_hook(save_gradient)
    handle_act = layer_handle_torch.register_forward_hook(save_activation)

    model.zero_grad()
    with torch.enable_grad():
        preds = model(img_tensor)
        top_pred_index = preds.argmax()
        top_pred_score = preds[0, top_pred_index]
        top_pred_score.backward()

    gradient = gradients[0].cpu().data.numpy()[0]
    activation = activations[0].cpu().data.numpy()[0]

    handle_grad.remove()
    handle_act.remove()

    weights = np.mean(gradient, axis=(0, 1))
    heatmap = np.dot(activation, weights)
    heatmap = np.maximum(heatmap, 0)
    if np.max(heatmap) > 0:
        heatmap /= np.max(heatmap)

    return heatmap, CLASS_NAMES[top_pred_index], preds[0].detach().cpu().numpy()


def compute_grad_cam_pytorch(model, img, target_layer_name="backbone.stages.4"):
    img_array = np.expand_dims(img, axis=0)
    img_tensor = torch.tensor(img_array, dtype=torch.float32).to(device)

    target_layer = dict([*model.named_modules()])[target_layer_name]
    gradients, activations = [], []

    def save_grad(module, grad_in, grad_out):
        gradients.append(grad_out[0])

    def save_act(module, inp, out):
        activations.append(out)

    handle_g = target_layer.register_backward_hook(save_grad)
    handle_a = target_layer.register_forward_hook(save_act)

    model.eval()
    model.zero_grad()
    img_tensor.requires_grad_(True)
    preds = model(img_tensor)

    top_index = preds.argmax().item()
    preds[0, top_index].backward()

    grad = gradients[0].cpu().data.numpy()[0]
    act = activations[0].cpu().data.numpy()[0]
    handle_g.remove()
    handle_a.remove()

    weights = np.mean(grad, axis=(1, 2))
    heatmap = weights @ act.reshape(act.shape[0], -1)
    heatmap = heatmap.reshape(act.shape[1], act.shape[2])
    heatmap = np.maximum(heatmap, 0)
    if np.max(heatmap) > 0:
        heatmap /= np.max(heatmap)

    return heatmap, CLASS_NAMES[top_index], torch.nn.functional.softmax(preds, dim=1)[0].detach().cpu().numpy()


# ==============================================================================
# --- 3. PRÉPARATION DE L'IMAGE ET CHARGEMENT DES MODÈLES ---
# ==============================================================================
IMAGE_PROPRE = detourer_image_unique(IMAGE_PATH)

print("\n📸 [ÉTAPE 2] Lecture de l'image nettoyée...")
img = cv2.imread(IMAGE_PROPRE)
if img is None:
    raise ValueError(f"Impossible de trouver l'image à : {IMAGE_PROPRE}")
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
img = cv2.resize(img, IMG_SIZE)

print("\n🧠 [ÉTAPE 3] Chargement des cerveaux IA...")
model_mobilenet = keras.models.load_model("agriscan_mobilenet_final_finetuned.keras")
model_convnext = keras.models.load_model("agriscan_convnext_FINAL.keras")

backbone = timm.create_model('mobilevit_s', pretrained=False, num_classes=0)


class AgriScanMobileViT(nn.Module):
    def __init__(self, backbone, num_classes, feature_dim):
        super().__init__()
        self.backbone = backbone
        self.drop = nn.Dropout(0.4)
        self.head = nn.Linear(feature_dim, num_classes)

    def forward(self, x):
        x = x.permute(0, 3, 1, 2) / 255.0
        mean = torch.tensor([0.485, 0.456, 0.406], device=x.device).view(1, 3, 1, 1)
        std = torch.tensor([0.229, 0.224, 0.225], device=x.device).view(1, 3, 1, 1)
        x = (x - mean) / std
        return self.head(self.drop(self.backbone(x)))


model_mobilevit = AgriScanMobileViT(backbone, len(CLASS_NAMES), backbone.num_features).to(device)
model_mobilevit.load_state_dict(torch.load('agriscan_mobilevit_FINAL.pt', map_location=device)['model_state_dict'],
                                strict=False)

# ==============================================================================
# --- 4. L'ARÈNE (Calculs Grad-CAM) ---
# ==============================================================================
print("\n🔥 [ÉTAPE 4] Lancement du tournoi Grad-CAM ! 🔥")

heatmap_mob, pred_mob, scores_mob = compute_grad_cam_keras(
    model_mobilenet, img, last_conv_layer_name='MobileNetV3Large'
)
heatmap_cn, pred_cn, scores_cn = compute_grad_cam_keras(
    model_convnext, img, last_conv_layer_name='convnext_tiny'
)
heatmap_mv, pred_mv, scores_mv = compute_grad_cam_pytorch(
    model_mobilevit, img, target_layer_name='backbone.stages.4'
)


# ==============================================================================
# --- 5. AFFICHAGE DES RÉSULTATS ---
# ==============================================================================
def render_cam_masked(heatmap, image, title):
    """ Superpose la heatmap uniquement sur les zones visibles (non noires) """
    heatmap_res = cv2.resize(heatmap, (image.shape[1], image.shape[0]))
    heatmap_res = np.uint8(255 * heatmap_res)
    heatmap_colored = cv2.applyColorMap(heatmap_res, cv2.COLORMAP_JET)

    # On évite que le fond noir de l'image devienne rouge/bleu foncé
    masque_feuille = np.any(image > 0, axis=-1).astype(np.uint8)
    masque_3d = np.stack([masque_feuille] * 3, axis=-1)

    superimposed_img = (heatmap_colored * 0.4 + image) * masque_3d

    plt.imshow(np.uint8(superimposed_img))
    plt.title(title)
    plt.axis('off')


plt.figure(figsize=(15, 10))

plt.subplot(2, 2, 1)
plt.imshow(img)
plt.title("Image Originale (Détourée)")
plt.axis('off')

plt.subplot(2, 2, 2)
render_cam_masked(heatmap_mob, img, f"MobileNet\nPrédiction: {pred_mob}")

plt.subplot(2, 2, 3)
render_cam_masked(heatmap_cn, img, f"ConvNeXt\nPrédiction: {pred_cn}")

plt.subplot(2, 2, 4)
render_cam_masked(heatmap_mv, img, f"MobileViT\nPrédiction: {pred_mv}")

plt.tight_layout()
plt.savefig('comparatif_modeles_propre.png')
print("\n📊 Graphique sauvegardé sous 'comparatif_modeles_propre.png'")
plt.show()

# --- AFFICHAGE TEXTE ---
print("\n" + "=" * 55)
print("🎯 RÉSULTATS DÉTAILLÉS DES PROBABILITÉS 🎯")
print("=" * 55)
print(f"{'Classe':<10} | {'MobileNet':<10} | {'ConvNeXt':<10} | {'MobileViT':<10}")
print("-" * 55)
for i, (name, s_mob, s_cn, s_mv) in enumerate(zip(CLASS_NAMES, scores_mob, scores_cn, scores_mv)):
    print(f"{name:<10} | {s_mob:>10.2%} | {s_cn:>10.2%} | {s_mv:>10.2%}")