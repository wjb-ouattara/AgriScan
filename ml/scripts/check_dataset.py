# =============================================================
#  AgriScan — check_dataset.py
#  Script de vérification et nettoyage du dataset Maïs
#  Catégories : healthy, Blight, Spot, Infected, Rust
#  Usage : python check_dataset.py --dataset ./dataset
# =============================================================

import os
import hashlib
import shutil
import argparse
from datetime import datetime
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

# ── Configuration ────────────────────────────────────────────
CLASSES   = ["Healthy", "Blight", "Spot", "Infected", "Rust"]
SPLITS    = ["train", "val", "test"]
IMG_EXTS  = {".jpg", ".jpeg", ".png", ".bmp", ".tiff", ".webp"}
TARGET_SIZE = (224, 224)
QUARANTINE_DIR = "quarantine"

# ── Couleurs terminal ─────────────────────────────────────────
GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
BLUE   = "\033[94m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def _is_image(path: str) -> bool:
    return Path(path).suffix.lower() in IMG_EXTS

def _get_images(folder: str) -> list:
    """Retourne tous les chemins d'images dans un dossier."""
    images = []
    for f in os.listdir(folder):
        fpath = os.path.join(folder, f)
        if os.path.isfile(fpath) and _is_image(fpath):
            images.append(fpath)
    return sorted(images)


# =============================================================
#  FONCTION 1 — Compter les images
# =============================================================

def count_images(dataset_path: str) -> dict:
    """
    Affiche et retourne le nombre d'images par classe et par split.

    Args:
        dataset_path : chemin vers le dossier racine du dataset
                       (ex: './dataset')

    Returns:
        dict : {split: {classe: nb_images}}

    Exemple:
        counts = count_images('./dataset')
    """
    results = {}
    total_global = 0

    print(f"\n{BOLD}{'='*55}{RESET}")
    print(f"{BOLD}  DISTRIBUTION DU DATASET{RESET}")
    print(f"  Chemin : {dataset_path}")
    print(f"{BOLD}{'='*55}{RESET}")

    header = f"{'Classe':<15}" + "".join(f"{s:>10}" for s in SPLITS) + f"{'TOTAL':>10}"
    print(f"\n{BOLD}{header}{RESET}")
    print("-" * 55)

    class_totals = {cls: 0 for cls in CLASSES}

    for split in SPLITS:
        results[split] = {}
        for cls in CLASSES:
            folder = os.path.join(dataset_path, split, cls)
            if os.path.isdir(folder):
                count = len(_get_images(folder))
            else:
                count = 0
            results[split][cls] = count
            class_totals[cls] += count

    # Affichage par classe
    for cls in CLASSES:
        row = f"{cls:<15}"
        cls_total = 0
        for split in SPLITS:
            n = results[split].get(cls, 0)
            cls_total += n
            color = GREEN if n >= 400 else (YELLOW if n >= 100 else RED)
            row += f"{color}{n:>10}{RESET}"
        row += f"{BOLD}{cls_total:>10}{RESET}"
        print(row)
        total_global += class_totals[cls]

    print("-" * 55)
    total_row = f"{'TOTAL':<15}"
    for split in SPLITS:
        s_total = sum(results[split].values())
        total_row += f"{BOLD}{s_total:>10}{RESET}"
    total_row += f"{BOLD}{total_global:>10}{RESET}"
    print(total_row)

    # Vérification des proportions
    print(f"\n{BOLD}  Vérification des proportions :{RESET}")
    for split in SPLITS:
        if total_global > 0:
            pct = sum(results[split].values()) / total_global * 100
            expected = {"train": (65, 80), "val": (10, 20), "test": (10, 20)}
            lo, hi = expected[split]
            status = GREEN + "OK" if lo <= pct <= hi else RED + "ATTENTION"
            print(f"    {split:>5} : {pct:5.1f}%  [{status}{RESET}]  (attendu {lo}–{hi}%)")

    # Équilibre des classes dans train
    print(f"\n{BOLD}  Équilibre des classes (train) :{RESET}")
    train_counts = [results["train"].get(c, 0) for c in CLASSES if results["train"].get(c, 0) > 0]
    if train_counts:
        ratio = max(train_counts) / min(train_counts)
        color = GREEN if ratio <= 1.5 else (YELLOW if ratio <= 3 else RED)
        print(f"    Ratio max/min : {color}{ratio:.2f}{RESET}  (idéal < 1.5, acceptable < 3)")

    return results


# =============================================================
#  FONCTION 2 — Trouver les fichiers corrompus
# =============================================================

def find_corrupted(folder_path: str) -> list:
    """
    Retourne la liste des fichiers images corrompus (illisibles).

    Args:
        folder_path : dossier à analyser

    Returns:
        list : chemins des fichiers corrompus

    Exemple:
        bad = find_corrupted('./dataset/train/Rust')
    """
    corrupted = []
    images = _get_images(folder_path)

    if not images:
        print(f"{YELLOW}  Aucune image trouvée dans {folder_path}{RESET}")
        return []

    print(f"\n{BOLD}  Recherche de fichiers corrompus...{RESET}")
    print(f"  Dossier : {folder_path}  ({len(images)} images)")

    for i, fpath in enumerate(images, 1):
        print(f"  Vérification {i}/{len(images)}...", end="\r")
        try:
            img = Image.open(fpath)
            img.verify()          # vérifie l'intégrité du fichier
        except Exception as e:
            corrupted.append(fpath)

        # Double vérification avec OpenCV
        try:
            img_cv = cv2.imread(fpath)
            if img_cv is None:
                if fpath not in corrupted:
                    corrupted.append(fpath)
        except Exception:
            if fpath not in corrupted:
                corrupted.append(fpath)

    print(f"  Résultat : ", end="")
    if corrupted:
        print(f"{RED}{len(corrupted)} fichier(s) corrompu(s) trouvé(s){RESET}")
        for f in corrupted:
            print(f"    {RED}✗{RESET} {os.path.basename(f)}")
    else:
        print(f"{GREEN}Aucun fichier corrompu{RESET}")

    return corrupted


# =============================================================
#  FONCTION 3 — Trouver les images non-RGB
# =============================================================

def find_non_rgb(folder_path: str) -> list:
    """
    Retourne les images qui ne sont pas en mode RGB.
    MobileNetV3 attend du RGB — les images RGBA, grayscale, etc.
    doivent être converties.

    Args:
        folder_path : dossier à analyser

    Returns:
        list : liste de tuples (chemin, mode_actuel)

    Exemple:
        non_rgb = find_non_rgb('./dataset/train/healthy')
    """
    non_rgb = []
    images = _get_images(folder_path)

    print(f"\n{BOLD}  Recherche des images non-RGB...{RESET}")
    print(f"  Dossier : {folder_path}  ({len(images)} images)")

    mode_counts = {}

    for fpath in images:
        try:
            img = Image.open(fpath)
            mode = img.mode
            mode_counts[mode] = mode_counts.get(mode, 0) + 1
            if mode != "RGB":
                non_rgb.append((fpath, mode))
        except Exception:
            pass  # les fichiers corrompus sont gérés ailleurs

    # Résumé des modes trouvés
    print(f"  Modes trouvés :")
    for mode, count in sorted(mode_counts.items()):
        color = GREEN if mode == "RGB" else YELLOW
        print(f"    {color}{mode:>8} : {count} image(s){RESET}")

    if non_rgb:
        print(f"\n  {YELLOW}{len(non_rgb)} image(s) non-RGB à convertir{RESET}")
    else:
        print(f"  {GREEN}Toutes les images sont en RGB{RESET}")

    return non_rgb


# =============================================================
#  FONCTION 4 — Trouver les doublons (hash MD5)
# =============================================================

def find_duplicates(folder_path: str) -> dict:
    """
    Retourne les groupes de doublons (même contenu binaire).
    Utilise le hash MD5 de chaque image.

    Args:
        folder_path : dossier à analyser

    Returns:
        dict : {hash_md5: [liste de fichiers identiques]}
              (uniquement les hash avec > 1 fichier)

    Exemple:
        dupes = find_duplicates('./dataset/train/Blight')
    """
    images = _get_images(folder_path)
    hash_map = {}

    print(f"\n{BOLD}  Recherche de doublons (MD5)...{RESET}")
    print(f"  Dossier : {folder_path}  ({len(images)} images)")

    for i, fpath in enumerate(images, 1):
        print(f"  Calcul du hash {i}/{len(images)}...", end="\r")
        try:
            with open(fpath, "rb") as f:
                file_hash = hashlib.md5(f.read()).hexdigest()
            if file_hash not in hash_map:
                hash_map[file_hash] = []
            hash_map[file_hash].append(fpath)
        except Exception:
            pass

    duplicates = {h: files for h, files in hash_map.items() if len(files) > 1}

    print(f"\n  Résultat : ", end="")
    if duplicates:
        total_dupes = sum(len(v) - 1 for v in duplicates.values())
        print(f"{YELLOW}{len(duplicates)} groupe(s) de doublons — {total_dupes} fichier(s) à supprimer{RESET}")
        for h, files in duplicates.items():
            print(f"\n    Groupe (hash: {h[:12]}...):")
            for i, f in enumerate(files):
                mark = f"{GREEN}  GARDER{RESET}" if i == 0 else f"{RED}SUPPRIMER{RESET}"
                print(f"      [{mark}] {os.path.basename(f)}")
    else:
        print(f"{GREEN}Aucun doublon trouvé{RESET}")

    return duplicates


# =============================================================
#  FONCTION 5 — Trouver les images floues
# =============================================================

def find_blurry(folder_path: str, threshold: float = 60.0) -> list:
    """
    Retourne les images trop floues en calculant la variance du
    Laplacien. Une valeur basse = image floue.

    Args:
        folder_path : dossier à analyser
        threshold   : score en dessous duquel l'image est floue
                      (défaut: 60 — adapter selon vos images)

    Returns:
        list : liste de tuples (chemin, score_laplacien)
               triée du plus flou au moins flou

    Exemple:
        blurry = find_blurry('./dataset/train/Spot', threshold=80)
    """
    images = _get_images(folder_path)
    blurry = []
    scores = []

    print(f"\n{BOLD}  Détection des images floues (seuil = {threshold})...{RESET}")
    print(f"  Dossier : {folder_path}  ({len(images)} images)")

    for i, fpath in enumerate(images, 1):
        print(f"  Analyse {i}/{len(images)}...", end="\r")
        try:
            img = cv2.imread(fpath)
            if img is None:
                continue
            gray  = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            score = cv2.Laplacian(gray, cv2.CV_64F).var()
            scores.append(score)
            if score < threshold:
                blurry.append((fpath, round(score, 2)))
        except Exception:
            pass

    # Tri du plus flou au moins flou
    blurry.sort(key=lambda x: x[1])

    print(f"\n  Statistiques des scores :")
    if scores:
        print(f"    Min : {min(scores):.1f}  |  Max : {max(scores):.1f}  |  Moyenne : {np.mean(scores):.1f}")

    print(f"\n  Résultat : ", end="")
    if blurry:
        print(f"{YELLOW}{len(blurry)} image(s) floue(s) détectée(s){RESET}")
        for fpath, score in blurry[:10]:   # affiche les 10 pires
            print(f"    {YELLOW}score {score:6.1f}{RESET}  {os.path.basename(fpath)}")
        if len(blurry) > 10:
            print(f"    ... et {len(blurry) - 10} autres")
    else:
        print(f"{GREEN}Aucune image floue détectée{RESET}")

    return blurry


# =============================================================
#  FONCTION 6 — Redimensionner toutes les images
# =============================================================

def resize_all(folder_path: str, size: tuple = TARGET_SIZE,
               output_folder: str = None, dry_run: bool = False) -> int:
    """
    Redimensionne toutes les images à la taille cible (224×224 par défaut).
    Préserve le ratio avec du padding blanc si nécessaire.

    Args:
        folder_path   : dossier source
        size          : taille cible (largeur, hauteur) — défaut (224, 224)
        output_folder : dossier de sortie. Si None, modifie sur place (backup auto)
        dry_run       : si True, simule sans modifier les fichiers

    Returns:
        int : nombre d'images redimensionnées

    Exemple:
        n = resize_all('./dataset/train/Rust', size=(224,224), dry_run=True)
    """
    images = _get_images(folder_path)
    count  = 0
    skipped = 0

    if output_folder is None:
        output_folder = folder_path
    else:
        os.makedirs(output_folder, exist_ok=True)

    action = "SIMULATION" if dry_run else "REDIMENSIONNEMENT"
    print(f"\n{BOLD}  {action} — {size[0]}×{size[1]} px{RESET}")
    print(f"  Source : {folder_path}")
    print(f"  Sortie : {output_folder}  ({len(images)} images)")

    for i, fpath in enumerate(images, 1):
        print(f"  Traitement {i}/{len(images)}...", end="\r")
        try:
            img = Image.open(fpath).convert("RGB")
            w, h = img.size

            if w == size[0] and h == size[1]:
                skipped += 1
                continue

            # Redimensionnement avec LANCZOS (meilleure qualité)
            img_resized = img.resize(size, Image.LANCZOS)

            if not dry_run:
                out_path = os.path.join(output_folder, os.path.basename(fpath))
                # Sauvegarde en JPG qualité 95
                img_resized.save(out_path, "JPEG", quality=95)

            count += 1

        except Exception as e:
            print(f"\n  {RED}Erreur sur {os.path.basename(fpath)} : {e}{RESET}")

    print(f"\n  {GREEN}Terminé :{RESET}")
    print(f"    Redimensionnées : {count}")
    print(f"    Déjà correctes  : {skipped}")
    print(f"    Total traité    : {count + skipped} / {len(images)}")

    return count


# =============================================================
#  FONCTION 7 — Générer le rapport Markdown
# =============================================================

def generate_report(class_name: str, results: dict,
                    output_path: str = None) -> str:
    """
    Génère un rapport de nettoyage en format Markdown.

    Args:
        class_name  : nom de la classe analysée (ex: 'Rust')
        results     : dictionnaire avec les résultats des autres fonctions
                      Format attendu :
                      {
                        'total_avant': int,
                        'corrupted':   list,
                        'non_rgb':     list,
                        'duplicates':  dict,
                        'blurry':      list,
                        'total_apres': int,
                        'etudiant':    str,
                      }
        output_path : chemin du fichier .md à créer
                      (défaut: reports/cleaning_report_{class_name}.md)

    Returns:
        str : chemin du fichier généré

    Exemple:
        generate_report('Rust', results, 'reports/cleaning_report_A.md')
    """
    if output_path is None:
        os.makedirs("reports", exist_ok=True)
        output_path = f"reports/cleaning_report_{class_name}.md"

    now = datetime.now().strftime("%d/%m/%Y à %H:%M")

    corrupted  = results.get("corrupted",  [])
    non_rgb    = results.get("non_rgb",    [])
    duplicates = results.get("duplicates", {})
    blurry     = results.get("blurry",     [])
    total_avant = results.get("total_avant", "?")
    total_apres = results.get("total_apres", "?")
    etudiant    = results.get("etudiant",    "—")

    total_supprimes = (len(corrupted) +
                       len(non_rgb)   +
                       sum(len(v) - 1 for v in duplicates.values()) +
                       len(blurry))

    lines = [
        f"# Rapport de nettoyage — Classe `{class_name}`",
        f"",
        f"> Généré le {now}  |  Étudiant : **{etudiant}**",
        f"",
        f"---",
        f"",
        f"## Résumé",
        f"",
        f"| Indicateur | Valeur |",
        f"|---|---|",
        f"| Images avant nettoyage | **{total_avant}** |",
        f"| Images après nettoyage | **{total_apres}** |",
        f"| Images supprimées / corrigées | **{total_supprimes}** |",
        f"| Fichiers corrompus | {len(corrupted)} |",
        f"| Images non-RGB | {len(non_rgb)} |",
        f"| Doublons supprimés | {sum(len(v)-1 for v in duplicates.values())} |",
        f"| Images floues | {len(blurry)} |",
        f"| Taille cible appliquée | 224 × 224 px |",
        f"",
        f"---",
        f"",
        f"## 1. Fichiers corrompus ({len(corrupted)})",
        f"",
    ]

    if corrupted:
        lines.append("| Fichier | Action |")
        lines.append("|---|---|")
        for f in corrupted:
            lines.append(f"| `{os.path.basename(f)}` | Supprimé |")
    else:
        lines.append("Aucun fichier corrompu trouvé.")

    lines += [
        f"",
        f"---",
        f"",
        f"## 2. Images non-RGB ({len(non_rgb)})",
        f"",
    ]

    if non_rgb:
        lines.append("| Fichier | Mode original | Action |")
        lines.append("|---|---|---|")
        for f, mode in non_rgb:
            lines.append(f"| `{os.path.basename(f)}` | {mode} | Converti en RGB |")
    else:
        lines.append("Toutes les images étaient déjà en RGB.")

    lines += [
        f"",
        f"---",
        f"",
        f"## 3. Doublons ({sum(len(v)-1 for v in duplicates.values())} supprimés)",
        f"",
    ]

    if duplicates:
        for h, files in duplicates.items():
            lines.append(f"**Groupe** `{h[:12]}...` — {len(files)} fichiers identiques")
            lines.append("")
            for i, f in enumerate(files):
                action = "Conservé" if i == 0 else "Supprimé"
                lines.append(f"- `{os.path.basename(f)}` — {action}")
            lines.append("")
    else:
        lines.append("Aucun doublon détecté.")

    lines += [
        f"",
        f"---",
        f"",
        f"## 4. Images floues ({len(blurry)})",
        f"",
    ]

    if blurry:
        lines.append("| Fichier | Score Laplacien | Action |")
        lines.append("|---|---|---|")
        for f, score in blurry:
            lines.append(f"| `{os.path.basename(f)}` | {score} | Supprimé |")
    else:
        lines.append("Aucune image floue détectée (seuil = 100).")

    lines += [
        f"",
        f"---",
        f"",
        f"## 5. Conclusion",
        f"",
        f"Le nettoyage de la classe `{class_name}` est terminé.",
        f"",
        f"- Toutes les images restantes sont en **224×224 px, format RGB**.",
        f"- Le dataset est prêt pour la Phase 2 (entraînement MobileNetV3).",
        f"",
        f"---",
        f"",
        f"*Rapport généré automatiquement par `check_dataset.py`*",
    ]

    content = "\n".join(lines)

    with open(output_path, "w", encoding="utf-8") as fp:
        fp.write(content)

    print(f"\n  {GREEN}Rapport généré :{RESET} {output_path}")
    return output_path


# =============================================================
#  PIPELINE COMPLET — analyse une classe en une commande
# =============================================================

def run_full_check(dataset_path: str, split: str, class_name: str,
                   etudiant: str = "?", fix: bool = False) -> dict:
    """
    Lance toutes les vérifications sur une classe et génère le rapport.

    Args:
        dataset_path : chemin racine du dataset
        split        : 'train', 'val', ou 'test'
        class_name   : nom de la classe (ex: 'Rust')
        etudiant     : prénom ou lettre de l'étudiant (pour le rapport)
        fix          : si True, applique les corrections (supprime, convertit, redimensionne)

    Exemple :
        run_full_check('./dataset', 'train', 'Rust', etudiant='A', fix=False)
    """
    folder = os.path.join(dataset_path, split, class_name)

    if not os.path.isdir(folder):
        print(f"{RED}Dossier introuvable : {folder}{RESET}")
        return {}

    images_avant = _get_images(folder)
    total_avant  = len(images_avant)

    print(f"\n{BOLD}{'='*55}{RESET}")
    print(f"{BOLD}  ANALYSE COMPLÈTE : {split}/{class_name}{RESET}")
    print(f"  Étudiant : {etudiant}  |  Mode : {'CORRECTION' if fix else 'LECTURE SEULE'}")
    print(f"{BOLD}{'='*55}{RESET}")

    corrupted  = find_corrupted(folder)
    non_rgb    = find_non_rgb(folder)
    duplicates = find_duplicates(folder)
    blurry     = find_blurry(folder)

    if fix:
        print(f"\n{BOLD}  Application des corrections...{RESET}")
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        quarantine_folder = os.path.join(QUARANTINE_DIR, f"{split}_{class_name}_{timestamp}")
        
        # Supprimer les corrompus
        for f in corrupted:
            dest_folder = os.path.join(quarantine_folder, "corrupted")
            os.makedirs(dest_folder, exist_ok=True)
            dest = os.path.join(dest_folder, os.path.basename(f))
            shutil.move(f, dest)
            print(f"  {YELLOW}Déplacé (corrompu) vers quarantaine :{RESET} {os.path.basename(f)}")

        # Convertir non-RGB
        for f, mode in non_rgb:
            try:
                img = Image.open(f).convert("RGB")
                img.save(f, "JPEG", quality=95)
                print(f"  {YELLOW}Converti {mode}→RGB :{RESET} {os.path.basename(f)}")
            except Exception as e:
                print(f"  {RED}Erreur conversion : {e}{RESET}")

        # Déplacer les doublons (garder le premier, déplacer les autres)
        for h, files in duplicates.items():
            for i, f in enumerate(files):
                if i > 0:  # Tous sauf le premier
                    dest_folder = os.path.join(quarantine_folder, "duplicates")
                    os.makedirs(dest_folder, exist_ok=True)
                    dest = os.path.join(dest_folder, f"dup_{i}_{os.path.basename(f)}")
                    shutil.move(f, dest)
                    print(f"  {YELLOW}Doublon déplacé vers quarantaine :{RESET} {os.path.basename(f)}")

        # Déplacer les flous
        for f, score in blurry:
            if os.path.exists(f):
                dest_folder = os.path.join(quarantine_folder, f"blurry_score_{score}")
                os.makedirs(dest_folder, exist_ok=True)
                dest = os.path.join(dest_folder, os.path.basename(f))
                shutil.move(f, dest)
                print(f"  {YELLOW}Flou (score={score}) déplacé vers quarantaine :{RESET} {os.path.basename(f)}")

        # Redimensionner
        resize_all(folder, size=TARGET_SIZE)
        
        print(f"\n  {GREEN}Fichiers déplacés dans : {quarantine_folder}{RESET}")

        # Redimensionner
        resize_all(folder, size=TARGET_SIZE)

    total_apres = len(_get_images(folder))

    results = {
        "etudiant":    etudiant,
        "total_avant": total_avant,
        "total_apres": total_apres,
        "corrupted":   corrupted,
        "non_rgb":     non_rgb,
        "duplicates":  duplicates,
        "blurry":      blurry,
    }

    report_path = f"reports/cleaning_report_{etudiant}_{class_name}.md"
    generate_report(class_name, results, output_path=report_path)

    print(f"\n{BOLD}  BILAN FINAL :{RESET}")
    print(f"    Avant  : {total_avant} images")
    print(f"    Après  : {total_apres} images")
    delta = total_avant - total_apres
    print(f"    Retirées : {RED if delta > 0 else GREEN}{delta}{RESET}")

    return results


# =============================================================
#  POINT D'ENTRÉE LIGNE DE COMMANDE
# =============================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="AgriScan — Vérification et nettoyage du dataset Maïs"
    )
    parser.add_argument("--dataset",  default="./dataset",
                        help="Chemin racine du dataset (défaut: ./dataset)")
    parser.add_argument("--split",    default="train",
                        choices=SPLITS,
                        help="Split à analyser : train, val ou test")
    parser.add_argument("--class_name", default=None,
                        help="Classe à analyser (ex: Rust). Si absent = toutes les classes")
    parser.add_argument("--etudiant", default="?",
                        help="Votre lettre : A, B ou C")
    parser.add_argument("--fix",      action="store_true",
                        help="Appliquer les corrections (sans ce flag = lecture seule)")
    parser.add_argument("--count",    action="store_true",
                        help="Afficher uniquement la distribution du dataset")

    args = parser.parse_args()

    # Mode comptage rapide
    if args.count:
        count_images(args.dataset)

    # Mode analyse d'une seule classe
    elif args.class_name:
        run_full_check(
            dataset_path=args.dataset,
            split=args.split,
            class_name=args.class_name,
            etudiant=args.etudiant,
            fix=args.fix,
        )

    # Mode analyse de toutes les classes d'un split
    else:
        count_images(args.dataset)
        for cls in CLASSES:
            run_full_check(
                dataset_path=args.dataset,
                split=args.split,
                class_name=cls,
                etudiant=args.etudiant,
                fix=args.fix,
            )