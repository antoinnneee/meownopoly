#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour redimensionner des images PNG/WebP et réduire leur taille
Peut traiter des séquences entières ou des images individuelles
"""

import os
import sys
import argparse
from pathlib import Path
from PIL import Image
import time

def redimensionner_image(image_path, output_path, largeur=None, hauteur=None, scale=None, qualite=85):
    """
    Redimensionne une image
    
    Args:
        image_path (Path): Chemin de l'image source
        output_path (Path): Chemin de sortie
        largeur (int, optional): Largeur cible en pixels
        hauteur (int, optional): Hauteur cible en pixels
        scale (float, optional): Facteur d'échelle (ex: 0.5 = 50%)
        qualite (int): Qualité de compression (0-100)
    
    Returns:
        tuple: (succès, taille_originale, taille_finale, erreur)
    """
    try:
        # Ouvrir l'image
        with Image.open(image_path) as img:
            largeur_orig, hauteur_orig = img.size
            
            # Calculer les nouvelles dimensions
            if scale is not None:
                nouvelle_largeur = int(largeur_orig * scale)
                nouvelle_hauteur = int(hauteur_orig * scale)
            elif largeur and hauteur:
                nouvelle_largeur = largeur
                nouvelle_hauteur = hauteur
            elif largeur:
                ratio = largeur / largeur_orig
                nouvelle_largeur = largeur
                nouvelle_hauteur = int(hauteur_orig * ratio)
            elif hauteur:
                ratio = hauteur / hauteur_orig
                nouvelle_largeur = int(largeur_orig * ratio)
                nouvelle_hauteur = hauteur
            else:
                # Aucun redimensionnement, juste recompression
                nouvelle_largeur = largeur_orig
                nouvelle_hauteur = hauteur_orig
            
            # Redimensionner l'image (LANCZOS pour haute qualité)
            if (nouvelle_largeur, nouvelle_hauteur) != (largeur_orig, hauteur_orig):
                img_redim = img.resize((nouvelle_largeur, nouvelle_hauteur), Image.Resampling.LANCZOS)
            else:
                img_redim = img
            
            # Créer le dossier de sortie si nécessaire
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Sauvegarder avec compression
            if output_path.suffix.lower() == '.webp':
                save_params = {
                    "format": "WebP",
                    "quality": qualite
                }
                if qualite == 100:
                    save_params["lossless"] = True
            elif output_path.suffix.lower() in ['.png']:
                save_params = {
                    "format": "PNG",
                    "compress_level": 9 - int(qualite / 11)  # 0-9, inversé
                }
            elif output_path.suffix.lower() in ['.jpg', '.jpeg']:
                save_params = {
                    "format": "JPEG",
                    "quality": qualite
                }
            else:
                save_params = {}
            
            img_redim.save(output_path, **save_params)
            
            # Calculer les tailles
            taille_orig = image_path.stat().st_size
            taille_finale = output_path.stat().st_size
            
            return True, taille_orig, taille_finale, None
            
    except Exception as e:
        return False, 0, 0, str(e)

def traiter_dossier(dossier_source, dossier_output, largeur=None, hauteur=None, scale=None, qualite=85, ecraser=False):
    """
    Traite toutes les images d'un dossier (récursif pour les sous-dossiers)
    
    Args:
        dossier_source (Path): Dossier source
        dossier_output (Path): Dossier de sortie
        largeur (int, optional): Largeur cible
        hauteur (int, optional): Hauteur cible
        scale (float, optional): Facteur d'échelle
        qualite (int): Qualité de compression (0-100)
        ecraser (bool): Si True, écrase les fichiers existants
    """
    # Extensions supportées
    extensions = ['.png', '.webp', '.jpg', '.jpeg']
    
    # Trouver toutes les images
    images = []
    for ext in extensions:
        images.extend(list(dossier_source.rglob(f'*{ext}')))
    
    images.sort()
    
    if not images:
        print(f"[INFO] Aucune image trouvée dans {dossier_source}")
        return
    
    print(f"[REDIMENSIONNEMENT] Traitement de {len(images)} images")
    print(f"Dossier source: {dossier_source}")
    print(f"Dossier de sortie: {dossier_output}")
    
    if scale:
        print(f"Échelle: {scale*100:.0f}%")
    elif largeur and hauteur:
        print(f"Dimensions: {largeur}x{hauteur}")
    elif largeur:
        print(f"Largeur: {largeur}px (hauteur proportionnelle)")
    elif hauteur:
        print(f"Hauteur: {hauteur}px (largeur proportionnelle)")
    else:
        print(f"Dimensions: Originales (recompression uniquement)")
    
    print(f"Qualité: {qualite}%")
    print("-" * 60)
    
    # Traiter chaque image
    total_taille_orig = 0
    total_taille_finale = 0
    total_succes = 0
    total_erreurs = 0
    debut = time.time()
    
    for i, image_path in enumerate(images, 1):
        # Calculer le chemin de sortie (conserver la structure de dossiers)
        chemin_relatif = image_path.relative_to(dossier_source)
        output_path = dossier_output / chemin_relatif
        
        # Vérifier si le fichier existe déjà
        if output_path.exists() and not ecraser:
            print(f"[SKIP] {chemin_relatif} (existe déjà)")
            continue
        
        # Redimensionner l'image
        succes, taille_orig, taille_finale, erreur = redimensionner_image(
            image_path, output_path, largeur, hauteur, scale, qualite
        )
        
        if succes:
            total_succes += 1
            total_taille_orig += taille_orig
            total_taille_finale += taille_finale
            
            reduction = (1 - taille_finale / taille_orig) * 100 if taille_orig > 0 else 0
            print(f"[{i}/{len(images)}] {chemin_relatif.name}: {taille_orig/1024:.0f}KB → {taille_finale/1024:.0f}KB (-{reduction:.0f}%)")
        else:
            total_erreurs += 1
            print(f"[ERREUR] {chemin_relatif.name}: {erreur}")
    
    # Résumé final
    duree = time.time() - debut
    print("-" * 60)
    print("Redimensionnement terminé !")
    print(f"Images traitées: {total_succes}/{len(images)}")
    print(f"Erreurs: {total_erreurs}")
    print(f"Taille originale totale: {total_taille_orig/(1024*1024):.1f} MB")
    print(f"Taille finale totale: {total_taille_finale/(1024*1024):.1f} MB")
    if total_taille_orig > 0:
        reduction_totale = (1 - total_taille_finale / total_taille_orig) * 100
        print(f"Réduction totale: -{reduction_totale:.1f}%")
    print(f"Durée totale: {duree:.1f}s")
    if total_succes > 0:
        print(f"Vitesse moyenne: {total_succes/duree:.1f} images/s")

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Redimensionne des images PNG/WebP pour réduire leur taille",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:

  # Réduire à 50% de la taille
  python redimensionner_images.py data/mp4 output/mp4_reduit --scale 0.5

  # Redimensionner en Full HD (1920x1080)
  python redimensionner_images.py output/png_seq output/png_seq_hd --largeur 1920 --hauteur 1080

  # Redimensionner avec largeur fixe (hauteur proportionnelle)
  python redimensionner_images.py output/png_seq output/png_seq_1280 --largeur 1280

  # Recompresser sans changer les dimensions
  python redimensionner_images.py output/png_seq output/png_seq_compresse --qualite 70

  # Redimensionner les images WebP
  python redimensionner_images.py output/png_to_webp output/png_to_webp_reduit --scale 0.5 --qualite 80

Dimensions courantes:
  - 4K:       3840x2160 ou 4096x2304
  - Full HD:  1920x1080
  - HD:       1280x720
  - 480p:     854x480
  - 360p:     640x360
        """
    )
    
    parser.add_argument(
        "source",
        type=str,
        help="Dossier source contenant les images"
    )
    
    parser.add_argument(
        "output",
        type=str,
        help="Dossier de sortie pour les images redimensionnées"
    )
    
    parser.add_argument(
        "--largeur",
        type=int,
        metavar="PX",
        help="Largeur cible en pixels"
    )
    
    parser.add_argument(
        "--hauteur",
        type=int,
        metavar="PX",
        help="Hauteur cible en pixels"
    )
    
    parser.add_argument(
        "--scale",
        type=float,
        metavar="0.0-1.0",
        help="Facteur d'échelle (ex: 0.5 = 50%%, 0.25 = 25%%)"
    )
    
    parser.add_argument(
        "--qualite",
        type=int,
        default=85,
        choices=range(1, 101),
        metavar="1-100",
        help="Qualité de compression (1-100, défaut: 85)"
    )
    
    parser.add_argument(
        "--ecraser",
        action="store_true",
        help="Écraser les fichiers existants"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ne pas demander de confirmation"
    )
    
    args = parser.parse_args()
    
    # Vérifier les paramètres
    if not args.scale and not args.largeur and not args.hauteur:
        print("[INFO] Aucun redimensionnement spécifié, recompression uniquement")
    
    if args.scale and (args.largeur or args.hauteur):
        print("[ERREUR] Vous ne pouvez pas utiliser --scale avec --largeur/--hauteur")
        sys.exit(1)
    
    # Convertir en Path
    dossier_source = Path(args.source)
    dossier_output = Path(args.output)
    
    # Vérifier que le dossier source existe
    if not dossier_source.exists():
        print(f"[ERREUR] Le dossier source {dossier_source} n'existe pas")
        sys.exit(1)
    
    # Afficher les informations
    print("[REDIMENSIONNEUR] Réduction de taille d'images")
    print(f"Source: {dossier_source}")
    print(f"Sortie: {dossier_output}")
    
    if args.scale:
        print(f"Échelle: {args.scale*100:.0f}%")
    elif args.largeur and args.hauteur:
        print(f"Dimensions: {args.largeur}x{args.hauteur}")
    elif args.largeur:
        print(f"Largeur: {args.largeur}px (hauteur proportionnelle)")
    elif args.hauteur:
        print(f"Hauteur: {args.hauteur}px (largeur proportionnelle)")
    else:
        print(f"Dimensions: Originales (recompression uniquement)")
    
    print(f"Qualité: {args.qualite}%")
    print(f"Écraser: {'Oui' if args.ecraser else 'Non'}")
    
    # Demander confirmation sauf si --force
    if not args.force:
        print(f"\n[ATTENTION] Cette opération va redimensionner toutes les images du dossier.")
        
        reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
        if reponse not in ['o', 'oui', 'y', 'yes']:
            print("Opération annulée.")
            sys.exit(0)
    
    # Lancer le traitement
    traiter_dossier(
        dossier_source,
        dossier_output,
        args.largeur,
        args.hauteur,
        args.scale,
        args.qualite,
        args.ecraser
    )

if __name__ == "__main__":
    main()

