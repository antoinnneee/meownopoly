#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script d'automatisation du pipeline MP4 vers Animation WebP
Enchaîne automatiquement toutes les étapes de transformation :
1. Extraction des frames MP4 → output/png_seq/
2. Déplacement → data/png_seq/
3. Suppression de fond (BiRefNet GPU) → output/no_background/
4. Déplacement → data/png_to_webp/
5. Conversion WebP → output/png_to_webp/
6. Déplacement → data/webp_to_animation/
7. Création animation → output/animation/
"""

import os
import sys
import cv2
import shutil
import argparse
import time
from pathlib import Path
from datetime import datetime

# Imports des modules existants
from extraire_frames import traiter_videos, nettoyer_nom
from supprimer_fond import traiter_sequences, BackgroundRemovalProcessor
from convertir_webp import convertir_png_vers_webp
from creer_animation_webp import traiter_toutes_sequences

def extraire_fps_mp4(chemin_mp4):
    """
    Extrait le FPS d'un fichier MP4
    
    Args:
        chemin_mp4 (Path): Chemin vers le fichier MP4
        
    Returns:
        float: FPS de la vidéo
    """
    try:
        cap = cv2.VideoCapture(str(chemin_mp4))
        if not cap.isOpened():
            raise Exception(f"Impossible d'ouvrir la vidéo {chemin_mp4.name}")
        
        fps = cap.get(cv2.CAP_PROP_FPS)
        cap.release()
        
        if fps <= 0:
            raise Exception("FPS invalide détecté")
        
        return fps
        
    except Exception as e:
        print(f"[ERREUR] Impossible d'extraire le FPS de {chemin_mp4.name}: {e}")
        return 10.0  # FPS par défaut

def deplacer_dossier(source, destination, ecraser=True):
    """
    Déplace un dossier entier vers une nouvelle destination
    
    Args:
        source (Path): Dossier source
        destination (Path): Dossier de destination
        ecraser (bool): Si True, écrase le dossier de destination s'il existe
        
    Returns:
        bool: True si succès, False sinon
    """
    try:
        # Supprimer la destination si elle existe et qu'on veut écraser
        if destination.exists() and ecraser:
            shutil.rmtree(destination)
        
        # Créer le dossier parent de destination si nécessaire
        destination.parent.mkdir(parents=True, exist_ok=True)
        
        # Déplacer le dossier
        shutil.move(str(source), str(destination))
        return True
        
    except Exception as e:
        print(f"[ERREUR] Impossible de déplacer {source} vers {destination}: {e}")
        return False

def pipeline_complet(sequence_specifique=None, qualite=100, batch_size=4, nb_threads=None, loop=False, force=False, use_lite=False, double_pass=False, use_rmbg=False, no_normalize=False, use_opencv=False):
    """
    Exécute le pipeline complet de transformation MP4 vers Animation WebP
    
    Args:
        sequence_specifique (str, optional): Nom d'une séquence MP4 spécifique à traiter
        qualite (int): Qualité de compression WebP (0-100)
        batch_size (int): Taille du batch pour BiRefNet_lite
        nb_threads (int, optional): Nombre de threads à utiliser
        loop (bool): Si True, boucle infinie pour l'animation
        force (bool): Si True, ne pas demander de confirmation
        use_lite (bool): Si True, utilise BiRefNet_lite (plus rapide, moins précis)
        double_pass (bool): Si True, applique la suppression de fond deux fois pour améliorer la qualité
        use_rmbg (bool): Si True, utilise le modèle RMBG-2.0 au lieu de BiRefNet
        no_normalize (bool): Si True, désactive la normalisation des images
        use_opencv (bool): Si True, utilise OpenCV pour la suppression de fond (plus rapide, moins précis)
    """
    debut_total = time.time()
    
    # Définir les chemins
    dossier_mp4 = Path("data/mp4")
    dossier_png_seq_data = Path("data/png_seq")
    dossier_png_seq_output = Path("output/png_seq")
    dossier_no_bg_output = Path("output/no_background")
    dossier_png_to_webp_data = Path("data/png_to_webp")
    dossier_png_to_webp_output = Path("output/png_to_webp")
    dossier_webp_to_anim_data = Path("data/webp_to_animation")
    dossier_animation_output = Path("output/animation")
    
    # Vérifier que le dossier MP4 existe
    if not dossier_mp4.exists():
        print(f"[ERREUR] Le dossier {dossier_mp4} n'existe pas.")
        return False
    
    # Trouver les fichiers MP4 à traiter
    if sequence_specifique:
        fichiers_mp4 = [dossier_mp4 / f"{sequence_specifique}.mp4"]
        if not fichiers_mp4[0].exists():
            print(f"[ERREUR] Le fichier {sequence_specifique}.mp4 n'existe pas dans {dossier_mp4}")
            return False
    else:
        fichiers_mp4 = list(dossier_mp4.glob("*.mp4"))
        fichiers_mp4.sort()
    
    if not fichiers_mp4:
        print(f"Aucun fichier MP4 trouvé dans {dossier_mp4}.")
        return False
    
    print(f"[PIPELINE] Pipeline automatique MP4 → Animation WebP")
    print(f"Fichiers MP4 à traiter: {len(fichiers_mp4)}")
    if use_opencv:
        print(f"Modèle: OpenCV (rapide, moins précis)")
    elif use_rmbg:
        print(f"Modèle: RMBG-2.0")
    else:
        print(f"Modèle BiRefNet: {'Lite (rapide)' if use_lite else 'Normal (qualité maximale)'}")
    print(f"Double passage suppression fond: {'Oui' if double_pass else 'Non'}")
    print(f"Normalisation: {'Désactivée' if no_normalize else 'Activée'}")
    print(f"Qualité WebP: {qualite}%")
    print(f"Boucle animation: {'Oui' if loop else 'Non'}")
    print(f"Threads: {nb_threads if nb_threads else 'auto'}")
    print("-" * 80)
    
    # Traiter chaque fichier MP4
    total_succes = 0
    total_erreurs = 0
    
    for fichier_mp4 in fichiers_mp4:
        print(f"\n[FICHIER] Traitement de {fichier_mp4.name}")
        print("=" * 60)
        
        debut_fichier = time.time()
        nom_sequence = nettoyer_nom(fichier_mp4.name)
        
        try:
            # ÉTAPE 1: Extraire le FPS du MP4
            print(f"[ÉTAPE 1/7] Extraction du FPS...")
            fps_mp4 = extraire_fps_mp4(fichier_mp4)
            print(f"   FPS détecté: {fps_mp4:.2f}")
            
            # ÉTAPE 2: Extraire les frames
            print(f"[ÉTAPE 2/7] Extraction des frames...")
            # Créer temporairement un dossier avec juste ce fichier MP4
            dossier_temp = Path("temp_extraction")
            dossier_temp.mkdir(exist_ok=True)
            fichier_temp = dossier_temp / fichier_mp4.name
            shutil.copy2(fichier_mp4, fichier_temp)
            
            # Changer temporairement le dossier source pour l'extraction
            original_mp4_dir = Path("data/mp4")
            shutil.move(str(original_mp4_dir), str(Path("data/mp4_backup")))
            shutil.move(str(dossier_temp), str(original_mp4_dir))
            
            # Extraire les frames
            traiter_videos(fps_extraction=None, nb_threads=nb_threads)
            
            # Restaurer le dossier original
            shutil.move(str(original_mp4_dir), str(dossier_temp))
            shutil.move(str(Path("data/mp4_backup")), str(original_mp4_dir))
            shutil.rmtree(dossier_temp)
            
            # Vérifier que l'extraction a fonctionné
            sequence_output = dossier_png_seq_output / nom_sequence
            if not sequence_output.exists() or not list(sequence_output.glob("*.png")):
                raise Exception("Échec de l'extraction des frames")
            
            nb_frames = len(list(sequence_output.glob("*.png")))
            print(f"   {nb_frames} frames extraites")
            
            # ÉTAPE 3: Déplacer vers data/png_seq/
            print(f"[ÉTAPE 3/7] Déplacement vers data/png_seq/...")
            sequence_data = dossier_png_seq_data / nom_sequence
            if not deplacer_dossier(sequence_output, sequence_data):
                raise Exception("Échec du déplacement vers data/png_seq/")
            print(f"   Déplacé vers {sequence_data}")
            
            # ÉTAPE 4: Suppression de fond (simple ou double passage)
            if use_opencv:
                modele_desc = "OpenCV (rapide)"
            elif use_rmbg:
                modele_desc = "RMBG-2.0"
            else:
                modele_desc = "BiRefNet_lite (rapide)" if use_lite else "BiRefNet (qualité maximale)"
            if double_pass:
                print(f"[ÉTAPE 4/7] Suppression de fond - Premier passage ({modele_desc})...")
            else:
                print(f"[ÉTAPE 4/7] Suppression de fond ({modele_desc})...")
            
            # Temporairement déplacer la séquence vers output/png_seq pour la suppression de fond
            temp_sequence = dossier_png_seq_output / nom_sequence
            if not deplacer_dossier(sequence_data, temp_sequence):
                raise Exception("Échec du déplacement temporaire pour suppression de fond")
            
            # Premier passage de suppression de fond
            if use_opencv:
                # Forcer l'utilisation d'OpenCV
                traiter_sequences(sequence_specifique=nom_sequence, nb_threads=nb_threads, 
                                force_cpu=True, use_lite=use_lite, batch_size=batch_size,
                                use_rmbg=use_rmbg, no_normalize=no_normalize)
            else:
                # Utiliser les modèles IA
                traiter_sequences(sequence_specifique=nom_sequence, nb_threads=nb_threads, 
                                force_gpu=True, use_lite=use_lite, batch_size=batch_size,
                                use_rmbg=use_rmbg, no_normalize=no_normalize)
            
            # Vérifier que la suppression de fond a fonctionné
            no_bg_output = dossier_no_bg_output / nom_sequence
            if not no_bg_output.exists() or not list(no_bg_output.glob("*.png")):
                raise Exception("Échec de la suppression de fond")
            
            nb_frames_no_bg = len(list(no_bg_output.glob("*.png")))
            print(f"   Premier passage: {nb_frames_no_bg} frames traitées")
            
            # Deuxième passage si demandé
            if double_pass:
                print(f"[ÉTAPE 4.5/7] Suppression de fond - Deuxième passage ({modele_desc} GPU)...")
                
                # Déplacer le résultat du premier passage vers le dossier d'entrée pour le deuxième passage
                temp_sequence_2 = dossier_png_seq_output / nom_sequence
                if not deplacer_dossier(no_bg_output, temp_sequence_2):
                    raise Exception("Échec du déplacement pour deuxième passage")
                
                # Deuxième passage de suppression de fond
                if use_opencv:
                    # Forcer l'utilisation d'OpenCV
                    traiter_sequences(sequence_specifique=nom_sequence, nb_threads=nb_threads, 
                                    force_cpu=True, use_lite=use_lite, batch_size=batch_size,
                                    use_rmbg=use_rmbg, no_normalize=no_normalize)
                else:
                    # Utiliser les modèles IA
                    traiter_sequences(sequence_specifique=nom_sequence, nb_threads=nb_threads, 
                                    force_gpu=True, use_lite=use_lite, batch_size=batch_size,
                                    use_rmbg=use_rmbg, no_normalize=no_normalize)
                
                # Vérifier que le deuxième passage a fonctionné
                no_bg_output_2 = dossier_no_bg_output / nom_sequence
                if not no_bg_output_2.exists() or not list(no_bg_output_2.glob("*.png")):
                    raise Exception("Échec du deuxième passage de suppression de fond")
                
                nb_frames_no_bg_2 = len(list(no_bg_output_2.glob("*.png")))
                print(f"   Deuxième passage: {nb_frames_no_bg_2} frames traitées")
                print(f"   Double passage terminé: {nb_frames_no_bg_2} frames finales")
            
            # ÉTAPE 5: Déplacer vers data/png_to_webp/
            print(f"[ÉTAPE 5/7] Déplacement vers data/png_to_webp/...")
            png_to_webp_data = dossier_png_to_webp_data / nom_sequence
            # Utiliser le bon dossier de sortie selon le nombre de passages
            source_dossier = no_bg_output_2 if double_pass else no_bg_output
            if not deplacer_dossier(source_dossier, png_to_webp_data):
                raise Exception("Échec du déplacement vers data/png_to_webp/")
            print(f"   Déplacé vers {png_to_webp_data}")
            
            # ÉTAPE 6: Conversion WebP
            print(f"[ÉTAPE 6/7] Conversion vers WebP...")
            convertir_png_vers_webp(sequence_specifique=nom_sequence, qualite=qualite, 
                                  supprimer_originaux=False, nb_threads=nb_threads)
            
            # Vérifier que la conversion a fonctionné
            webp_output = dossier_png_to_webp_output / nom_sequence
            if not webp_output.exists() or not list(webp_output.glob("*.webp")):
                raise Exception("Échec de la conversion WebP")
            
            nb_webp = len(list(webp_output.glob("*.webp")))
            print(f"   {nb_webp} fichiers WebP créés")
            
            # ÉTAPE 7: Déplacer vers data/webp_to_animation/
            print(f"[ÉTAPE 7/7] Déplacement vers data/webp_to_animation/...")
            webp_to_anim_data = dossier_webp_to_anim_data / nom_sequence
            if not deplacer_dossier(webp_output, webp_to_anim_data):
                raise Exception("Échec du déplacement vers data/webp_to_animation/")
            print(f"   Déplacé vers {webp_to_anim_data}")
            
            # ÉTAPE 8: Création de l'animation
            print(f"[ÉTAPE 8/8] Création de l'animation WebP...")
            traiter_toutes_sequences(fps=fps_mp4, qualite=qualite, loop=loop, 
                                   sequence_specifique=nom_sequence)
            
            # Vérifier que l'animation a été créée
            animation_finale = dossier_animation_output / f"{nom_sequence}.webp"
            if not animation_finale.exists():
                raise Exception("Échec de la création de l'animation")
            
            taille_animation = animation_finale.stat().st_size / (1024 * 1024)
            duree_fichier = time.time() - debut_fichier
            
            print(f"   Animation créée: {animation_finale.name} ({taille_animation:.1f}MB)")
            print(f"   Durée du traitement: {duree_fichier:.1f}s")
            
            total_succes += 1
            
        except Exception as e:
            print(f"[ERREUR] Échec du traitement de {fichier_mp4.name}: {e}")
            total_erreurs += 1
            continue
    
    # Résumé final
    duree_totale = time.time() - debut_total
    print("\n" + "=" * 80)
    print("PIPELINE TERMINÉ !")
    print(f"Fichiers traités avec succès: {total_succes}")
    print(f"Erreurs: {total_erreurs}")
    print(f"Durée totale: {duree_totale:.1f}s")
    
    if total_succes > 0:
        print(f"Animations créées dans: {dossier_animation_output}")
        print("Fichiers d'animation:")
        for anim_file in dossier_animation_output.glob("*.webp"):
            taille = anim_file.stat().st_size / (1024 * 1024)
            print(f"  - {anim_file.name} ({taille:.1f}MB)")
    
    return total_erreurs == 0

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Pipeline automatique MP4 → Animation WebP",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python pipeline_mp4_vers_animation.py                    # Traite tous les MP4 avec BiRefNet normal
  python pipeline_mp4_vers_animation.py --sequence anim_tree_00038  # Traite un MP4 spécifique
  python pipeline_mp4_vers_animation.py --lite             # Utilise BiRefNet_lite (plus rapide)
  python pipeline_mp4_vers_animation.py --rmbg             # Utilise le modèle RMBG-2.0
  python pipeline_mp4_vers_animation.py --opencv           # Utilise OpenCV (rapide, moins précis)
  python pipeline_mp4_vers_animation.py --double-pass      # Double passage suppression fond
  python pipeline_mp4_vers_animation.py --no-normalize     # Désactive la normalisation
  python pipeline_mp4_vers_animation.py --quality 80       # Qualité WebP 80%
  python pipeline_mp4_vers_animation.py --loop             # Animation en boucle
  python pipeline_mp4_vers_animation.py --force            # Sans confirmation
        """
    )
    
    parser.add_argument(
        "--sequence",
        type=str,
        metavar="NOM",
        help="Nom d'une séquence MP4 spécifique à traiter (sans extension .mp4)"
    )
    
    parser.add_argument(
        "--quality",
        type=int,
        default=100,
        choices=range(0, 101),
        metavar="0-100",
        help="Qualité de compression WebP (0-100, défaut: 100)"
    )
    
    parser.add_argument(
        "--batch-size",
        type=int,
        default=4,
        help="Taille du batch pour BiRefNet (défaut: 4)"
    )
    
    parser.add_argument(
        "--threads",
        type=int,
        default=8,
        metavar="N",
        help="Nombre de threads à utiliser (par défaut: auto)"
    )
    
    parser.add_argument(
        "--loop",
        action="store_true",
        help="Créer des animations en boucle infinie"
    )
    
    parser.add_argument(
        "--lite",
        action="store_true",
        help="Utiliser BiRefNet_lite (plus rapide, moins précis)"
    )
    
    parser.add_argument(
        "--double-pass",
        action="store_true",
        help="Appliquer la suppression de fond deux fois pour améliorer la qualité"
    )
    
    parser.add_argument(
        "--rmbg",
        action="store_true",
        help="Utiliser le modèle RMBG-2.0 au lieu de BiRefNet"
    )
    
    parser.add_argument(
        "--no-normalize",
        action="store_true",
        help="Désactiver la normalisation des images"
    )
    
    parser.add_argument(
        "--opencv",
        action="store_true",
        help="Utiliser OpenCV pour la suppression de fond (plus rapide, moins précis)"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ne pas demander de confirmation"
    )
    
    args = parser.parse_args()
    
    # Afficher les informations
    print("[PIPELINE] Pipeline automatique MP4 → Animation WebP")
    print(f"Dossier source: data/mp4/")
    print(f"Dossier final: output/animation/")
    print(f"Séquence: {args.sequence if args.sequence else 'toutes'}")
    if args.opencv:
        print(f"Modèle: OpenCV (rapide, moins précis)")
    elif args.rmbg:
        print(f"Modèle: RMBG-2.0")
    else:
        print(f"Modèle BiRefNet: {'Lite (rapide)' if args.lite else 'Normal (qualité maximale)'}")
    print(f"Double passage suppression fond: {'Oui' if args.double_pass else 'Non'}")
    print(f"Normalisation: {'Désactivée' if args.no_normalize else 'Activée'}")
    print(f"Qualité WebP: {args.quality}%")
    print(f"Boucle: {'Oui' if args.loop else 'Non'}")
    print(f"Threads: {args.threads if args.threads else 'auto'}")
    
    # Demander confirmation sauf si --force
    if not args.force:
        print(f"\n[ATTENTION] Cette opération va traiter tous les fichiers MP4.")
        print("[ATTENTION] Le modèle BiRefNet sera téléchargé depuis Hugging Face si nécessaire.")
        print("[ATTENTION] Les fichiers intermédiaires seront déplacés entre les dossiers.")
        
        reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
        if reponse not in ['o', 'oui', 'y', 'yes']:
            print("Opération annulée.")
            sys.exit(0)
    
    # Lancer le pipeline
    succes = pipeline_complet(
        sequence_specifique=args.sequence,
        qualite=args.quality,
        batch_size=args.batch_size,
        nb_threads=args.threads,
        loop=args.loop,
        force=args.force,
        use_lite=args.lite,
        double_pass=args.double_pass,
        use_rmbg=args.rmbg,
        no_normalize=args.no_normalize,
        use_opencv=args.opencv
    )
    
    if not succes:
        sys.exit(1)

if __name__ == "__main__":
    main()
