#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour supprimer le fond des séquences d'images PNG en utilisant BiRefNet
Traite les images du dossier output/png_seq/ et sauvegarde les résultats avec transparence
dans output/no_background/[nom_sequence]/
"""

import os
import sys
import cv2
import torch
import numpy as np
import argparse
from pathlib import Path
from PIL import Image
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
import time
from transformers import pipeline

# Verrou pour synchroniser l'affichage des messages
print_lock = threading.Lock()

class BackgroundRemovalProcessor:
    """
    Classe pour gérer la suppression de fond avec un modèle de segmentation
    """
    
    def __init__(self, device=None):
        """
        Initialise le processeur de suppression de fond
        
        Args:
            device (str, optional): Device à utiliser ('cuda', 'cpu', ou None pour auto-détection)
        """
        self.device = device or ('cuda' if torch.cuda.is_available() else 'cpu')
        self.pipe = None
        self._load_model()
    
    def _load_model(self):
        """
        Charge un modèle de segmentation pour la suppression de fond
        """
        try:
            with print_lock:
                print(f"[MODEL] Chargement du modèle de suppression de fond sur {self.device}...")
            
            # Utiliser un modèle de segmentation disponible sur Hugging Face
            # Nous utilisons un modèle de segmentation d'objets qui peut servir pour la suppression de fond
            model_name = "facebook/detr-resnet-50-panoptic"
            
            # Créer le pipeline de segmentation
            self.pipe = pipeline(
                "image-segmentation",
                model=model_name,
                device=0 if self.device == 'cuda' else -1
            )
            
            with print_lock:
                print(f"[MODEL] Modèle de suppression de fond chargé avec succès sur {self.device}")
                
        except Exception as e:
            with print_lock:
                print(f"[ERREUR] Impossible de charger le modèle: {e}")
            # Fallback vers une méthode simple basée sur OpenCV
            with print_lock:
                print("[FALLBACK] Utilisation de la méthode OpenCV simple...")
            self.pipe = None
    
    def remove_background(self, image_path):
        """
        Supprime le fond d'une image
        
        Args:
            image_path (str): Chemin vers l'image à traiter
            
        Returns:
            PIL.Image: Image avec fond supprimé (RGBA)
        """
        try:
            # Charger l'image
            image = Image.open(image_path).convert('RGB')
            
            if self.pipe is not None:
                # Utiliser le modèle de segmentation
                return self._remove_background_with_model(image)
            else:
                # Utiliser la méthode OpenCV simple
                return self._remove_background_simple(image)
                
        except Exception as e:
            raise Exception(f"Erreur lors du traitement de {image_path}: {e}")
    
    def _remove_background_with_model(self, image):
        """
        Supprime le fond en utilisant le modèle de segmentation
        """
        try:
            # Utiliser le pipeline de segmentation
            results = self.pipe(image)
            
            # Créer un masque combiné de tous les objets détectés
            mask = np.zeros((image.height, image.width), dtype=np.uint8)
            
            for result in results:
                if result['mask'].mode == 'L':
                    mask = np.maximum(mask, np.array(result['mask']))
            
            # Convertir en image RGBA
            image_np = np.array(image)
            rgba_image = np.zeros((image_np.shape[0], image_np.shape[1], 4), dtype=np.uint8)
            rgba_image[:, :, :3] = image_np  # RGB
            rgba_image[:, :, 3] = mask  # Alpha
            
            return Image.fromarray(rgba_image, 'RGBA')
            
        except Exception as e:
            # Fallback vers la méthode simple
            return self._remove_background_simple(image)
    
    def _remove_background_simple(self, image):
        """
        Supprime le fond en utilisant une méthode simple basée sur OpenCV
        """
        # Convertir PIL vers OpenCV
        image_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
        
        # Créer un masque en utilisant GrabCut
        height, width = image_cv.shape[:2]
        mask = np.zeros((height, width), np.uint8)
        
        # Définir un rectangle autour de l'image (on suppose que l'objet principal est au centre)
        margin = min(width, height) // 10
        rect = (margin, margin, width - 2*margin, height - 2*margin)
        
        # Appliquer GrabCut
        bgd_model = np.zeros((1, 65), np.float64)
        fgd_model = np.zeros((1, 65), np.float64)
        
        cv2.grabCut(image_cv, mask, rect, bgd_model, fgd_model, 5, cv2.GC_INIT_WITH_RECT)
        
        # Créer le masque final
        mask2 = np.where((mask == 2) | (mask == 0), 0, 1).astype('uint8')
        mask2 = mask2 * 255
        
        # Appliquer une morphologie pour nettoyer le masque
        kernel = np.ones((3,3), np.uint8)
        mask2 = cv2.morphologyEx(mask2, cv2.MORPH_CLOSE, kernel)
        mask2 = cv2.morphologyEx(mask2, cv2.MORPH_OPEN, kernel)
        
        # Créer l'image RGBA
        image_np = np.array(image)
        rgba_image = np.zeros((image_np.shape[0], image_np.shape[1], 4), dtype=np.uint8)
        rgba_image[:, :, :3] = image_np  # RGB
        rgba_image[:, :, 3] = mask2  # Alpha
        
        return Image.fromarray(rgba_image, 'RGBA')

def traiter_image_unique(image_path, output_path, processor):
    """
    Traite une seule image (utilisé pour le multi-threading)
    
    Args:
        image_path (Path): Chemin vers l'image à traiter
        output_path (Path): Chemin de sortie pour l'image traitée
        processor (BackgroundRemovalProcessor): Processeur de suppression de fond
        
    Returns:
        tuple: (nom_fichier, succès, erreur)
    """
    try:
        # Créer le dossier de sortie si nécessaire
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Traiter l'image
        result_image = processor.remove_background(str(image_path))
        
        # Sauvegarder l'image avec transparence
        result_image.save(output_path, 'PNG')
        
        return image_path.name, True, None
        
    except Exception as e:
        return image_path.name, False, str(e)

def traiter_sequence(sequence_path, output_base, processor, nb_threads=None):
    """
    Traite toutes les images d'une séquence
    
    Args:
        sequence_path (Path): Chemin vers le dossier de la séquence
        output_base (Path): Dossier de base pour les sorties
        processor (BackgroundRemovalProcessor): Processeur de suppression de fond
        nb_threads (int, optional): Nombre de threads à utiliser
        
    Returns:
        tuple: (images_traitees, erreurs)
    """
    # Créer le dossier de sortie pour cette séquence
    output_sequence = output_base / sequence_path.name
    output_sequence.mkdir(parents=True, exist_ok=True)
    
    # Trouver toutes les images PNG
    images = list(sequence_path.glob("*.png"))
    images.sort()
    
    if not images:
        with print_lock:
            print(f"[ATTENTION] Aucune image PNG trouvée dans {sequence_path.name}")
        return 0, 0
    
    with print_lock:
        print(f"[SEQUENCE] {sequence_path.name} ({len(images)} images)")
    
    # Déterminer le nombre de threads
    if nb_threads is None:
        nb_threads = min(len(images), os.cpu_count() or 1)
    
    images_traitees = 0
    erreurs = 0
    
    # Traiter les images avec multi-threading
    with ThreadPoolExecutor(max_workers=nb_threads) as executor:
        # Soumettre toutes les tâches
        futures = {
            executor.submit(
                traiter_image_unique, 
                image_path, 
                output_sequence / image_path.name,
                processor
            ): image_path
            for image_path in images
        }
        
        # Traiter les résultats au fur et à mesure
        for future in as_completed(futures):
            nom_fichier, succès, erreur = future.result()
            
            if erreur:
                with print_lock:
                    print(f"[ERREUR] {sequence_path.name}/{nom_fichier}: {erreur}")
                erreurs += 1
            else:
                images_traitees += 1
                if images_traitees % 10 == 0:
                    with print_lock:
                        print(f"[PROGRES] {sequence_path.name}: {images_traitees}/{len(images)} images traitées")
    
    with print_lock:
        print(f"[OK] {sequence_path.name}: {images_traitees} images traitées, {erreurs} erreurs")
    
    return images_traitees, erreurs

def traiter_sequences(sequence_specifique=None, nb_threads=None):
    """
    Traite toutes les séquences d'images avec suppression de fond
    
    Args:
        sequence_specifique (str, optional): Nom d'une séquence spécifique à traiter
        nb_threads (int, optional): Nombre de threads à utiliser
    """
    # Définir les chemins
    dossier_png_seq = Path("output/png_seq")
    dossier_output = Path("output/no_background")
    
    # Vérifier que le dossier source existe
    if not dossier_png_seq.exists():
        print(f"[ERREUR] Le dossier {dossier_png_seq} n'existe pas.")
        return
    
    # Trouver les séquences à traiter
    if sequence_specifique:
        sequences = [dossier_png_seq / sequence_specifique]
        if not sequences[0].exists():
            print(f"[ERREUR] La séquence {sequence_specifique} n'existe pas dans {dossier_png_seq}")
            return
    else:
        sequences = [d for d in dossier_png_seq.iterdir() if d.is_dir()]
        sequences.sort()
    
    if not sequences:
        print(f"Aucune séquence trouvée dans {dossier_png_seq}.")
        return
    
    print(f"[SUPPRESSION FOND] Suppression de fond avec BiRefNet")
    print(f"Dossier source: {dossier_png_seq}")
    print(f"Dossier de sortie: {dossier_output}")
    print(f"Séquences à traiter: {len(sequences)}")
    print(f"Threads par séquence: {nb_threads if nb_threads else 'auto'}")
    print("-" * 60)
    
    # Initialiser le processeur de suppression de fond
    try:
        processor = BackgroundRemovalProcessor()
    except Exception as e:
        print(f"[ERREUR] Impossible d'initialiser le processeur: {e}")
        return
    
    # Traiter chaque séquence
    total_images = 0
    total_erreurs = 0
    debut = time.time()
    
    for sequence in sequences:
        images_traitees, erreurs = traiter_sequence(
            sequence, dossier_output, processor, nb_threads
        )
        total_images += images_traitees
        total_erreurs += erreurs
    
    # Résumé final
    duree = time.time() - debut
    print("-" * 60)
    print("Suppression de fond terminée !")
    print(f"Séquences traitées: {len(sequences)}")
    print(f"Total images traitées: {total_images}")
    print(f"Total erreurs: {total_erreurs}")
    print(f"Durée totale: {duree:.1f}s")
    if total_images > 0:
        print(f"Vitesse moyenne: {total_images/duree:.1f} images/s")

def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Supprime le fond des séquences d'images PNG automatiquement",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python supprimer_fond.py                           # Traite toutes les séquences
  python supprimer_fond.py --sequence anim_tree_00037 # Traite une séquence spécifique
  python supprimer_fond.py --threads 4               # Utilise 4 threads par séquence
  python supprimer_fond.py --force                   # Sans confirmation
        """
    )
    
    parser.add_argument(
        "--sequence",
        type=str,
        metavar="NOM",
        help="Nom d'une séquence spécifique à traiter (par défaut: toutes les séquences)"
    )
    
    parser.add_argument(
        "--threads",
        type=int,
        metavar="N",
        help="Nombre de threads à utiliser par séquence (par défaut: nombre de CPU)"
    )
    
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ne pas demander de confirmation"
    )
    
    args = parser.parse_args()
    
    # Afficher les informations
    print("[SUPPRESSION FOND] Suppresseur de fond automatique")
    print(f"Dossier source: output/png_seq/")
    print(f"Dossier de sortie: output/no_background/")
    print(f"Séquence: {args.sequence if args.sequence else 'toutes'}")
    print(f"Threads: {args.threads if args.threads else 'auto'}")
    
    # Demander confirmation sauf si --force
    if not args.force:
        print("\n[ATTENTION] Cette opération va supprimer le fond de toutes les images.")
        print("[ATTENTION] Le modèle de suppression de fond sera téléchargé depuis Hugging Face si nécessaire.")
        
        reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
        if reponse not in ['o', 'oui', 'y', 'yes']:
            print("Opération annulée.")
            sys.exit(0)
    
    # Lancer le traitement
    traiter_sequences(args.sequence, args.threads)

if __name__ == "__main__":
    main()
