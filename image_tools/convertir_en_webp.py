#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour convertir une image en format WebP
Prend une image en paramètre et la convertit en WebP avec une qualité configurable
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image

def convertir_en_webp(image_path, qualite=90, output_path=None):
    """
    Convertit une image en format WebP

    Args:
        image_path (str): Chemin vers l'image source
        qualite (int): Qualité de compression WebP 0-100 (défaut: 90)
        output_path (str, optional): Chemin de sortie pour l'image WebP

    Returns:
        tuple: (succès, chemin_sortie, taille_fichier, erreur)
    """
    try:
        # Vérifier que l'image source existe
        source_path = Path(image_path)
        if not source_path.exists():
            return False, None, 0, f"Le fichier source n'existe pas: {image_path}"

        # Ouvrir l'image
        with Image.open(source_path) as img:
            # Déterminer le chemin de sortie
            if output_path is None:
                # Remplacer l'extension par .webp
                output_path = source_path.with_suffix('.webp')
            else:
                output_path = Path(output_path)

            # Créer le dossier de sortie si nécessaire
            output_path.parent.mkdir(parents=True, exist_ok=True)

            # Convertir en RGB si nécessaire (pour les images avec transparence)
            if img.mode in ('RGBA', 'LA', 'P'):
                # Créer un fond blanc
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background
            elif img.mode != 'RGB':
                img = img.convert('RGB')

            # Paramètres de sauvegarde
            save_params = {
                "format": "WebP",
                "quality": qualite
            }

            # Si qualité = 100, utiliser lossless
            if qualite == 100:
                save_params["lossless"] = True
                del save_params["quality"]  # lossless n'utilise pas quality

            # Sauvegarder l'image WebP
            img.save(output_path, **save_params)

            # Calculer la taille du fichier
            taille_fichier = output_path.stat().st_size

            return True, str(output_path), taille_fichier, None

    except Exception as e:
        return False, None, 0, str(e)

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Convertit une image en format WebP",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python convertir_en_webp.py image.png                           # Conversion avec qualité par défaut (90)
  python convertir_en_webp.py image.jpg --qualite 80              # Qualité 80%
  python convertir_en_webp.py image.png --output resultat.webp    # Spécifier le fichier de sortie
  python convertir_en_webp.py image.jpg --qualite 100             # Qualité maximale (lossless)
        """
    )

    parser.add_argument(
        "image",
        type=str,
        help="Chemin vers l'image à convertir"
    )

    parser.add_argument(
        "--qualite",
        type=int,
        default=90,
        choices=range(0, 101),
        metavar="0-100",
        help="Qualité de compression WebP (0-100, défaut: 90)"
    )

    parser.add_argument(
        "--output",
        "-o",
        type=str,
        metavar="FICHIER",
        help="Chemin du fichier WebP de sortie (par défaut: même nom avec extension .webp)"
    )

    args = parser.parse_args()

    # Afficher les informations
    print("[CONVERTISSEUR] Conversion d'image vers WebP")
    print(f"Image source: {args.image}")
    print(f"Qualité: {args.qualite}%")
    print(f"Fichier de sortie: {args.output if args.output else 'automatique'}")

    # Convertir l'image
    succès, chemin_sortie, taille_fichier, erreur = convertir_en_webp(
        args.image, args.qualite, args.output
    )

    if erreur:
        print(f"[ERREUR] {erreur}")
        sys.exit(1)
    else:
        taille_mb = taille_fichier / (1024 * 1024)
        print(f"[OK] Image convertie: {chemin_sortie}")
        print(f"Taille du fichier: {taille_mb:.2f} MB")
        print("Conversion terminée !")

if __name__ == "__main__":
    main()