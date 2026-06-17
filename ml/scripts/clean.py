import os
from pathlib import Path

def clean_empty_images(directory):
    path = Path(directory)
    count = 0
    # On cherche tous les fichiers dans train, val et test
    for img_path in path.rglob('*'):
        if img_path.is_file() and img_path.suffix.lower() in ['.jpg', '.jpeg', '.png']:
            # Si le fichier fait 0 octet
            if img_path.stat().st_size == 0:
                print(f"🗑️ Suppression du fichier vide : {img_path}")
                img_path.unlink()
                count += 1
    print(f"\nTerminé ! {count} fichiers corrompus ont été supprimés.")

clean_empty_images("dataste/dataset")
