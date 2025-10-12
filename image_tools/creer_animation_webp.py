#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour créer des animations WebP à partir de séquences d'images WebP
Traite les séquences du dossier data/webp_to_animation/ et génère des animations dans output/animation/
"""

import os
import sys
import time
from pathlib import Path
from PIL import Image
import argparse

def creer_animation_unique(sequence_path, output_path, fps=10, qualite=100, loop=False):
    """
    Crée une animation WebP à partir d'une séquence d'images WebP
    
    Args:
        sequence_path (Path): Chemin vers le dossier de la séquence
        output_path (Path): Chemin de sortie pour l'animation WebP
        fps (int): Nombre d'images par seconde (défaut: 10)
        qualite (int): Qualité de compression WebP 0-100 (défaut: 100)
        loop (bool): Si True, boucle infinie, sinon lecture unique (défaut: False)
        
    Returns:
        tuple: (succès, nb_frames, taille_fichier, erreur)
    """
    try:
        # Créer le dossier de sortie si nécessaire
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Trouver toutes les images WebP et les trier
        images_webp = list(sequence_path.glob("*.webp"))
        images_webp.sort()
        
        if len(images_webp) < 2:
            return False, 0, 0, f"Au moins 2 images WebP requises, trouvé: {len(images_webp)}"
        
        print(f"[ANIMATION] {sequence_path.name} ({len(images_webp)} frames)")
        
        # Charger la première image
        with Image.open(images_webp[0]) as first_frame:
            # Charger toutes les autres frames
            frames = [first_frame.copy()]
            for img_path in images_webp[1:]:
                with Image.open(img_path) as frame:
                    frames.append(frame.copy())
        
        # Calculer la durée par frame en millisecondes
        duration_ms = int(1000 / fps)
        
        # Paramètres de sauvegarde
        save_params = {
            "format": "WebP",
            "save_all": True,
            "append_images": frames[1:],
            "duration": duration_ms,
            "loop": 0 if loop else 1,
            "quality": qualite
        }
        
        # Si qualité = 100, utiliser lossless
        if qualite == 100:
            save_params["lossless"] = True
        
        # Sauvegarder l'animation
        first_frame.save(output_path, **save_params)
        
        # Calculer la taille du fichier
        taille_fichier = output_path.stat().st_size
        
        return True, len(images_webp), taille_fichier, None
        
    except Exception as e:
        return False, 0, 0, str(e)

def traiter_toutes_sequences(fps=10, qualite=100, loop=False, sequence_specifique=None):
    """
    Traite toutes les séquences d'images WebP et crée les animations
    
    Args:
        fps (int): Nombre d'images par seconde
        qualite (int): Qualité de compression WebP 0-100
        loop (bool): Si True, boucle infinie
        sequence_specifique (str, optional): Nom d'une séquence spécifique à traiter
    """
    # Définir les chemins
    dossier_source = Path("data/webp_to_animation")
    dossier_output = Path("output/animation")
    
    # Vérifier que le dossier source existe
    if not dossier_source.exists():
        print(f"[ERREUR] Le dossier {dossier_source} n'existe pas.")
        return
    
    # Trouver les séquences à traiter
    if sequence_specifique:
        sequences = [dossier_source / sequence_specifique]
        if not sequences[0].exists():
            print(f"[ERREUR] La séquence {sequence_specifique} n'existe pas dans {dossier_source}")
            return
    else:
        sequences = [d for d in dossier_source.iterdir() if d.is_dir() and d.name != "put_webp_folder_here"]
        sequences.sort()
    
    if not sequences:
        print(f"Aucune séquence trouvée dans {dossier_source}.")
        return
    
    print(f"[ANIMATION] Création d'animations WebP")
    print(f"Dossier source: {dossier_source}")
    print(f"Dossier de sortie: {dossier_output}")
    print(f"Séquences à traiter: {len(sequences)}")
    print(f"FPS: {fps}")
    print(f"Qualité: {qualite}%")
    print(f"Boucle: {'Infinie' if loop else 'Lecture unique'}")
    print("-" * 60)
    
    # Traiter chaque séquence
    total_sequences = 0
    total_frames = 0
    total_erreurs = 0
    debut = time.time()
    
    for sequence in sequences:
        output_file = dossier_output / f"{sequence.name}.webp"
        
        # Écraser l'animation si elle existe déjà
        if output_file.exists():
            output_file.unlink()
            print(f"[INFO] {sequence.name}.webp écrasé")
        
        succès, nb_frames, taille_fichier, erreur = creer_animation_unique(
            sequence, output_file, fps, qualite, loop
        )
        
        if erreur:
            print(f"[ERREUR] {sequence.name}: {erreur}")
            total_erreurs += 1
        else:
            total_sequences += 1
            total_frames += nb_frames
            duree_animation = nb_frames / fps
            taille_mb = taille_fichier / (1024 * 1024)
            print(f"[OK] {sequence.name}: {nb_frames} frames, {duree_animation:.1f}s, {taille_mb:.1f}MB")
    
    # Résumé final
    duree = time.time() - debut
    print("-" * 60)
    print("Création d'animations terminée !")
    print(f"Séquences traitées: {total_sequences}")
    print(f"Total frames: {total_frames}")
    print(f"Total erreurs: {total_erreurs}")
    print(f"Durée totale: {duree:.1f}s")
    if total_sequences > 0:
        print(f"Vitesse moyenne: {total_sequences/duree:.1f} animations/s")

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Crée des animations WebP à partir de séquences d'images WebP",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python creer_animation_webp.py                           # Création avec paramètres par défaut
  python creer_animation_webp.py --fps 24                  # Animation à 24 FPS
  python creer_animation_webp.py --qualite 80              # Qualité 80%
  python creer_animation_webp.py --loop                    # Boucle infinie
  python creer_animation_webp.py --sequence anim_tree_00037 # Créer une séquence spécifique
  python creer_animation_webp.py --force                   # Sans confirmation
        """
    )
    
    parser.add_argument(
        "--sequence",
        type=str,
        metavar="NOM",
        help="Nom d'une séquence spécifique à traiter (par défaut: toutes les séquences)"
    )
    
    parser.add_argument(
        "--fps",
        type=int,
        default=10,
        metavar="N",
        help="Nombre d'images par seconde (défaut: 10)"
    )
    
    parser.add_argument(
        "--qualite",
        type=int,
        default=100,
        choices=range(0, 101),
        metavar="0-100",
        help="Qualité de compression WebP (0-100, défaut: 100)"
    )
    
    parser.add_argument(
        "--loop",
        action="store_true",
        help="Activer la boucle infinie (par défaut: lecture unique)"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ne pas demander de confirmation"
    )
    
    args = parser.parse_args()
    
    # Afficher les informations
    print("[ANIMATEUR] Créateur d'animations WebP")
    print(f"Dossier source: data/webp_to_animation/")
    print(f"Dossier de sortie: output/animation/")
    print(f"Séquence: {args.sequence if args.sequence else 'toutes'}")
    print(f"FPS: {args.fps}")
    print(f"Qualité: {args.qualite}%")
    print(f"Boucle: {'Infinie' if args.loop else 'Lecture unique'}")
    
    # Demander confirmation sauf si --force
    if not args.force:
        print(f"\n[ATTENTION] Cette opération va créer des animations WebP.")
        
        reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
        if reponse not in ['o', 'oui', 'y', 'yes']:
            print("Opération annulée.")
            sys.exit(0)
    
    # Lancer la création d'animations
    traiter_toutes_sequences(args.fps, args.qualite, args.loop, args.sequence)

if __name__ == "__main__":
    main()
