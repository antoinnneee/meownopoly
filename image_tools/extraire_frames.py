#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour extraire les frames des fichiers MP4 en séquences d'images PNG
Convertit les vidéos du dossier data/mp4 vers output/png_seq/[nom_animation]
"""

import os
import sys
import cv2
import argparse
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

# Verrou pour synchroniser l'affichage des messages
print_lock = threading.Lock()

def nettoyer_nom(nom):
    """
    Nettoie le nom en retirant les underscores et espaces finaux
    
    Args:
        nom (str): Le nom à nettoyer
        
    Returns:
        str: Le nom nettoyé
    """
    # Retirer l'extension si présente
    nom_sans_ext = Path(nom).stem
    
    # Retirer les underscores et espaces finaux
    nom_nettoye = nom_sans_ext.rstrip('_ ').rstrip()
    
    return nom_nettoye

def extraire_frames_video(chemin_mp4, dossier_sortie, fps_extraction=None):
    """
    Extrait les frames d'une vidéo MP4 et les sauvegarde en PNG
    
    Args:
        chemin_mp4 (Path): Chemin vers le fichier MP4
        dossier_sortie (Path): Dossier de destination pour les PNG
        fps_extraction (int, optional): Nombre de frames par seconde à extraire
        
    Returns:
        tuple: (nombre_frames_extraites, erreur)
    """
    try:
        # Ouvrir la vidéo
        cap = cv2.VideoCapture(str(chemin_mp4))
        
        if not cap.isOpened():
            return 0, f"Impossible d'ouvrir la vidéo {chemin_mp4.name}"
        
        # Obtenir les informations de la vidéo
        fps_video = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duree = total_frames / fps_video
        
        with print_lock:
            print(f"[VIDEO] {chemin_mp4.name}")
            print(f"   FPS vidéo: {fps_video:.2f}")
            print(f"   Durée: {duree:.2f}s")
            print(f"   Total frames: {total_frames}")
        
        # Calculer l'intervalle d'extraction
        if fps_extraction is None:
            # Extraire toutes les frames
            intervalle = 1
            frames_a_extraire = total_frames
        else:
            # Extraire selon le FPS spécifié
            intervalle = max(1, int(fps_video / fps_extraction))
            frames_a_extraire = int(total_frames / intervalle)
        
        with print_lock:
            print(f"   FPS extraction: {fps_extraction if fps_extraction else 'toutes'}")
            print(f"   Frames à extraire: {frames_a_extraire}")
        
        # Créer le dossier de sortie
        dossier_sortie.mkdir(parents=True, exist_ok=True)
        
        # Extraire les frames
        frame_count = 0
        frames_extraites = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Vérifier si on doit extraire cette frame
            if frame_count % intervalle == 0:
                # Créer le nom du fichier PNG
                nom_png = f"{dossier_sortie.name}-{frames_extraites + 1:03d}.png"
                chemin_png = dossier_sortie / nom_png
                
                # Sauvegarder la frame
                cv2.imwrite(str(chemin_png), frame)
                frames_extraites += 1
                
                # Afficher le progrès tous les 10 frames
                if frames_extraites % 10 == 0:
                    with print_lock:
                        print(f"   [FRAME] {frames_extraites}/{frames_a_extraire} - {chemin_mp4.name}")
            
            frame_count += 1
        
        cap.release()
        return frames_extraites, None
        
    except Exception as e:
        return 0, f"Erreur lors de l'extraction: {e}"

def traiter_video_unique(fichier_mp4, dossier_output, fps_extraction=None):
    """
    Traite un seul fichier MP4 (utilisé pour le multi-threading)
    
    Args:
        fichier_mp4 (Path): Chemin vers le fichier MP4
        dossier_output (Path): Dossier de sortie principal
        fps_extraction (int, optional): Nombre de frames par seconde à extraire
        
    Returns:
        tuple: (nom_fichier, frames_extraites, erreur)
    """
    try:
        # Nettoyer le nom pour créer le dossier de sortie
        nom_animation = nettoyer_nom(fichier_mp4.name)
        dossier_animation = dossier_output / nom_animation
        
        # Extraire les frames
        frames_extraites, erreur = extraire_frames_video(fichier_mp4, dossier_animation, fps_extraction)
        
        return fichier_mp4.name, frames_extraites, erreur
        
    except Exception as e:
        return fichier_mp4.name, 0, f"Erreur inattendue: {e}"

def traiter_videos(fps_extraction=None, nb_threads=None):
    """
    Traite tous les fichiers MP4 du dossier data/mp4 avec multi-threading
    
    Args:
        fps_extraction (int, optional): Nombre de frames par seconde à extraire
        nb_threads (int, optional): Nombre de threads à utiliser (par défaut: nombre de CPU)
    """
    # Définir les chemins
    dossier_mp4 = Path("data/mp4")
    dossier_output = Path("output/png_seq")
    
    # Vérifier que le dossier source existe
    if not dossier_mp4.exists():
        print(f"[ERREUR] Le dossier {dossier_mp4} n'existe pas.")
        return
    
    # Trouver tous les fichiers MP4
    fichiers_mp4 = list(dossier_mp4.glob("*.mp4"))
    
    if not fichiers_mp4:
        print(f"Aucun fichier MP4 trouvé dans {dossier_mp4}.")
        return
    
    # Trier les fichiers par nom
    fichiers_mp4.sort()
    
    # Déterminer le nombre de threads
    if nb_threads is None:
        nb_threads = min(len(fichiers_mp4), os.cpu_count() or 1)
    
    print(f"[EXTRACTION] Extraction des frames MP4")
    print(f"Dossier source: {dossier_mp4}")
    print(f"Dossier de sortie: {dossier_output}")
    print(f"FPS extraction: {fps_extraction if fps_extraction else 'toutes'}")
    print(f"Fichiers trouvés: {len(fichiers_mp4)}")
    print(f"Threads utilisés: {nb_threads}")
    print("-" * 60)
    
    videos_traitees = 0
    erreurs = 0
    total_frames = 0
    
    # Traiter les fichiers avec multi-threading
    with ThreadPoolExecutor(max_workers=nb_threads) as executor:
        # Soumettre toutes les tâches
        futures = {
            executor.submit(traiter_video_unique, fichier_mp4, dossier_output, fps_extraction): fichier_mp4
            for fichier_mp4 in fichiers_mp4
        }
        
        # Traiter les résultats au fur et à mesure
        for future in as_completed(futures):
            nom_fichier, frames_extraites, erreur = future.result()
            
            if erreur:
                with print_lock:
                    print(f"[ERREUR] {nom_fichier}: {erreur}")
                erreurs += 1
            else:
                with print_lock:
                    print(f"[OK] {nom_fichier} -> {nettoyer_nom(nom_fichier)}/ ({frames_extraites} frames)")
                videos_traitees += 1
                total_frames += frames_extraites
    
    # Résumé final
    print("-" * 60)
    print("Extraction terminée !")
    print(f"Vidéos traitées: {videos_traitees}")
    print(f"Total frames extraites: {total_frames}")
    if erreurs > 0:
        print(f"Erreurs: {erreurs}")

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Extrait les frames des fichiers MP4 en séquences d'images PNG",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python extraire_frames.py                    # Extrait toutes les frames
  python extraire_frames.py --fps 1            # 1 frame par seconde
  python extraire_frames.py --fps 10 --force   # 10 fps sans confirmation
  python extraire_frames.py --threads 4        # Utilise 4 threads
  python extraire_frames.py --fps 2 --threads 2 --force  # 2 fps, 2 threads, sans confirmation
        """
    )
    
    parser.add_argument(
        "--fps",
        type=int,
        metavar="N",
        help="Nombre de frames par seconde à extraire (par défaut: toutes les frames)"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ne pas demander de confirmation"
    )
    
    parser.add_argument(
        "--threads",
        type=int,
        metavar="N",
        help="Nombre de threads à utiliser (par défaut: nombre de CPU ou nombre de fichiers)"
    )
    
    args = parser.parse_args()
    
    # Afficher les informations
    print("[EXTRACTEUR] Extracteur de frames MP4 vers PNG")
    print(f"Dossier source: data/mp4/")
    print(f"Dossier de sortie: output/png_seq/")
    print(f"FPS extraction: {args.fps if args.fps else 'toutes'}")
    print(f"Threads: {args.threads if args.threads else 'auto'}")
    
    # Demander confirmation sauf si --force
    if not args.force:
        print("\n[ATTENTION] Cette opération va extraire les frames de tous les fichiers MP4.")
        
        reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
        if reponse not in ['o', 'oui', 'y', 'yes']:
            print("Opération annulée.")
            sys.exit(0)
    
    # Lancer l'extraction
    traiter_videos(args.fps, args.threads)

if __name__ == "__main__":
    main()

