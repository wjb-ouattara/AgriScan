import os
import numpy as np  # <--- À ajouter en haut
from rembg import remove
from PIL import Image


def nettoyer_dataset_securise(dossier_entree, dossier_sortie):
    if not os.path.exists(dossier_sortie):
        os.makedirs(dossier_sortie)

    categories = os.listdir(dossier_entree)

    for categorie in categories:
        chemin_cat_entree = os.path.join(dossier_entree, categorie)
        chemin_cat_sortie = os.path.join(dossier_sortie, categorie)

        if not os.path.isdir(chemin_cat_entree):
            continue
        if not os.path.exists(chemin_cat_sortie):
            os.makedirs(chemin_cat_sortie)

        print(f"🧹 Nettoyage de la catégorie : {categorie}...")

        for nom_image in os.listdir(chemin_cat_entree):
            chemin_img_entree = os.path.join(chemin_cat_entree, nom_image)
            chemin_img_sortie = os.path.join(chemin_cat_sortie, nom_image)

            try:
                input_image = Image.open(chemin_img_entree)
                output_image = remove(input_image)

                fond_noir = Image.new("RGB", output_image.size, (0, 0, 0))
                fond_noir.paste(output_image, mask=output_image.split()[3])

                # --- 🚨 LE FILET DE SÉCURITÉ 🚨 ---
                # On convertit l'image en tableau de nombres pour analyser les pixels
                img_array = np.array(fond_noir)

                # On compte combien de pixels NE SONT PAS noirs (càd > 0 sur au moins un canal RGB)
                pixels_non_noirs = np.sum(np.any(img_array > 0, axis=-1))
                pixels_totaux = img_array.shape[0] * img_array.shape[1]

                # Calcul du pourcentage de feuille restante
                ratio_feuille = pixels_non_noirs / pixels_totaux

                if ratio_feuille < 0.15:  # Si moins de 15% de l'image a survécu
                    print(
                        f"  ⚠️ rembg a paniqué sur {nom_image} ({ratio_feuille * 100:.1f}% restant). Conservation de l'originale.")
                    # On sauvegarde l'image de base, sans fond noir
                    input_image.convert("RGB").save(chemin_img_sortie)
                else:
                    # Le détourage s'est bien passé, on sauvegarde le fond noir
                    fond_noir.save(chemin_img_sortie)

            except Exception as e:
                print(f"❌ Erreur sur l'image {nom_image} : {e}")


# --- Utilisation ---
dossier_sale = "agriscan_final_v2/val"  # (N'oublie pas de faire le train ET le val !)
dossier_propre = "agriscan_sans_fond/val"

print("Démarrage de l'opération 'Mort aux ombres (Version Intelligente)'...")
nettoyer_dataset_securise(dossier_sale, dossier_propre)