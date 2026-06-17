from ultralytics import YOLO
import torch

# Le fix anti-panique pour ta carte graphique très récente
torch.backends.cudnn.enabled = False

# Ton nouveau dataset tout beau tout propre
path_to_yaml = '/home/arold/miniconda3/AgriScan/dataset/dataset_yolo/data.yaml'

model = YOLO('yolov8n.pt')

results = model.train(
    data=path_to_yaml,
    epochs=300,
    patience=50,
    imgsz=640,
    device=0,
    plots=True,
    amp=False,
    workers=0,
    batch=16
)