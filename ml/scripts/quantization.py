import torch
from ai_edge_torch.generative.quantize import quantize
from ai_edge_torch.generative.layers import kv_cache
from mediapipe.tasks.python.genai import converter

# Configuration des chemins
input_dir = "./gemma-raw"
output_path = "./gemma-3-1b-android.bin"

print("🚀 Starting conversion to LiteRT format...")

# Configuration de la quantization en INT4 (4-bit) pour le mobile
config = converter.ConversionConfig(
    input_ckpt=input_dir,
    ckpt_format="safetensors",
    model_type="GEMMA_1B", # Définit l'architecture de base
    backend="cpu",         # On cible une compatibilité hybride CPU/GPU stable
    output_dir=output_path,
    quantization_bits=4    # Crucial pour la RAM du téléphone
)

converter.convert_checkpoint(config)
print(f"✅ Model successfully quantized and saved to {output_path}")