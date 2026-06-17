import os

# On reste fidèle à ton backend Torch pour charger le fichier original
os.environ["KERAS_BACKEND"] = "torch"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"  # Pour éviter que TensorFlow hurle des warnings

import keras
import torch
import subprocess

print("🔄 1. Chargement du modèle Keras (Backend: Torch)...")
model = keras.models.load_model("agriscan_convnext_FINALconda clean --all.keras")
torch_model = model.pytorch_model
torch_model.eval()

# Dummy input au format PyTorch : (Batch, Canaux, Hauteur, Largeur)
# Attention : ConvNeXt s'attend à 3 canaux (RGB)
dummy_input = torch.randn(1, 3, 224, 224)

onnx_path = "agriscan_convnext.onnx"

print("🚀 2. Exportation intermédiaire vers ONNX...")
torch.onnx.export(
    torch_model,
    dummy_input,
    onnx_path,
    export_params=True,
    opset_version=14,
    do_constant_folding=True,
    input_names=['input_1'],  # Nom de l'entrée tflite
    output_names=['output_1']  # Nom de la sortie tflite
)
print("✅ ONNX généré avec succès.")

print("📦 3. Conversion ONNX vers TFLite (Float32)...")
# On utilise la commande onnx2tf via un appel système pour générer le dossier SavedModel et le TFLite
# L'option -oiqt permet d'ignorer la quantification et de rester en Float32 pur.
try:
    subprocess.run(["onnx2tf", "-i", onnx_path, "-o", "tflite_output"], check=True)

    # Par défaut, onnx2tf crée un fichier nommé 'model_float32.tflite' dans le dossier de sortie
    src_tflite = os.path.join("tflite_output", "model_float32.tflite")
    dest_tflite = "agriscan_convnext.tflite"

    if os.path.exists(src_tflite):
        os.rename(src_tflite, dest_tflite)
        print(f"🎉 VICTOIRE ! Ton modèle est prêt : '{dest_tflite}'")
    else:
        print(
            "⚠️ Conversion terminée, mais le fichier n'est pas à l'emplacement attendu. Regarde dans le dossier 'tflite_output'.")
except Exception as e:
    print(f"❌ Erreur lors de la conversion TFLite : {e}")
    print("Vérifie que 'onnx2tf' et 'tensorflow' sont bien installés.")