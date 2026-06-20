import os
from PIL import Image
import torchvision.transforms as T

print("Démarrage de l'usine à clones avec le moteur PyTorch...\n")

# 1. On configure notre machine à torturer les images
# C'est l'équivalent moderne (et plus rapide) de ton ImageDataGenerator
augmenter = T.Compose([
    T.RandomRotation(degrees=40),
    T.RandomAffine(degrees=0, translate=(0.2, 0.2), shear=20),  # Décalage et déformation
    T.RandomHorizontalFlip(p=0.5),  # Effet miroir 1 fois sur 2
    T.ColorJitter(brightness=0.2, contrast=0.2)  # Bonus : modifie un peu la lumière, parfait pour le soleil marocain !
])

# 2. Les chemins
dossier_source = './dataset/train/Spot'
dossier_destination = './dataset/train/Spot'

# On récupère les images (uniquement les originales, on ignore les clones s'ils existent déjà)
images = [f for f in os.listdir(dossier_source) if f.endswith(('.png', '.jpg', '.jpeg')) and not f.startswith('aug_')]

print(f"🌽 {len(images)} images originales trouvées dans la classe Spot.")
print("Début de l'augmentation. Ton drone va être content...")

# 3. La boucle de création
images_generees_par_image = 2  # Combien de faux clones on veut par image originale
compteur_total = 0

for image_name in images:
    img_path = os.path.join(dossier_source, image_name)

    # Charger l'image avec la librairie classique PIL
    try:
        img = Image.open(img_path).convert('RGB')
    except Exception as e:
        print(f"Image corrompue ignorée : {image_name}")
        continue

    # On génère les clones
    for i in range(images_generees_par_image):
        # On applique la torture PyTorch
        img_clone = augmenter(img)

        # On donne un petit nom unique au clone et on sauvegarde
        nouveau_nom = f"aug_{i}_{image_name}"
        chemin_sauvegarde = os.path.join(dossier_destination, nouveau_nom)

        img_clone.save(chemin_sauvegarde, 'JPEG', quality=95)
        compteur_total += 1

print(f"\n✅ Terminé ! {compteur_total} nouvelles images générées.")
print("Ton dataset n'est plus ridicule, la classe Spot est prête au combat.")