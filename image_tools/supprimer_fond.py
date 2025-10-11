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
from transformers import AutoModelForImageSegmentation
from torchvision import transforms

# Verrou pour synchroniser l'affichage des messages
print_lock = threading.Lock()

class BackgroundRemovalProcessor:
    """
    Classe pour gérer la suppression de fond avec BiRefNet
    """
    
    def __init__(self, device=None, use_lite=False, batch_size=4):
        """
        Initialise le processeur de suppression de fond
        
        Args:
            device (str, optional): Device à utiliser ('cuda', 'cpu', ou None pour auto-détection)
            use_lite (bool): Utiliser BiRefNet_lite (plus rapide, moins précis)
            batch_size (int): Taille du batch pour traitement par lots (si lite)
        """
        # Forcer l'utilisation du GPU si disponible, sinon utiliser OpenCV
        if device is None:
            if torch.cuda.is_available():
                self.device = 'cuda'
                self.use_gpu = True
            else:
                self.device = 'cpu'
                self.use_gpu = False
        else:
            self.device = device
            self.use_gpu = (device == 'cuda' and torch.cuda.is_available())
        
        self.use_lite = use_lite
        self.batch_size = batch_size if use_lite else 1  # Batch uniquement pour lite
        self.model = None
        self.transform = None
        self._load_model()
    
    def _load_model(self):
        """
        Charge BiRefNet pour la suppression de fond
        """
        # Ne charger le modèle IA que si GPU est disponible
        if not self.use_gpu:
            with print_lock:
                print("[INFO] GPU non disponible - utilisation directe d'OpenCV")
            self.model = None
            return
        
        try:
            # Choisir le modèle selon le mode lite
            if self.use_lite:
                model_name = 'ZhengPeng7/BiRefNet_lite'
                model_desc = 'BiRefNet_lite (rapide)'
            else:
                model_name = 'ZhengPeng7/BiRefNet'
                model_desc = 'BiRefNet (qualité maximale)'
            
            with print_lock:
                print(f"[MODEL] Chargement de {model_desc} sur GPU...")
            
            # Charger BiRefNet depuis Hugging Face
            self.model = AutoModelForImageSegmentation.from_pretrained(
                model_name,
                trust_remote_code=True
            )
            self.model.to(self.device)
            self.model.eval()
            
            # Activer half precision pour plus de vitesse
            if self.use_lite:
                self.model.half()
            
            # Définir les transformations pour BiRefNet
            self.transform = transforms.Compose([
                transforms.Resize((1024, 1024)),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
            ])
            
            with print_lock:
                print(f"[MODEL] {model_desc} chargé avec succès sur GPU")
                if self.use_lite:
                    print(f"[MODEL] Mode FP16 activé pour plus de vitesse")
                    print(f"[MODEL] Traitement par batch de {self.batch_size} images")
                
        except Exception as e:
            with print_lock:
                print(f"[ERREUR] Impossible de charger BiRefNet sur GPU: {e}")
            # Fallback vers une méthode simple basée sur OpenCV
            with print_lock:
                print("[FALLBACK] Utilisation de la méthode OpenCV...")
            self.model = None
    
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
            
            # Utiliser BiRefNet si GPU disponible et modèle chargé
            if self.use_gpu and self.model is not None:
                # Utiliser BiRefNet sur GPU
                return self._remove_background_with_birefnet(image)
            else:
                # Utiliser la méthode OpenCV
                return self._remove_background_simple(image)
                
        except Exception as e:
            raise Exception(f"Erreur lors du traitement de {image_path}: {e}")
    
    def _remove_background_with_birefnet(self, image):
        """
        Supprime le fond en utilisant BiRefNet (image unique)
        """
        try:
            # Sauvegarder la taille originale
            original_size = image.size
            
            # Préparer l'image pour le modèle
            input_tensor = self.transform(image).unsqueeze(0).to(self.device)
            
            # Convertir en FP16 si mode lite
            if self.use_lite:
                input_tensor = input_tensor.half()
            
            # Inférence avec BiRefNet
            with torch.no_grad():
                output = self.model(input_tensor)[-1].sigmoid()
                
                # Convertir en FP32 si nécessaire
                if self.use_lite:
                    output = output.float()
            
            # Extraire le masque alpha
            mask = output[0, 0].cpu().numpy()
            mask = (mask * 255).astype(np.uint8)
            
            # Redimensionner le masque à la taille originale
            mask_image = Image.fromarray(mask).resize(original_size, Image.BILINEAR)
            mask_array = np.array(mask_image)
            
            # Convertir l'image en array
            image_array = np.array(image)
            
            # Créer l'image RGBA
            rgba_image = np.zeros((image_array.shape[0], image_array.shape[1], 4), dtype=np.uint8)
            rgba_image[:, :, :3] = image_array  # RGB
            rgba_image[:, :, 3] = mask_array  # Alpha
            
            return Image.fromarray(rgba_image, 'RGBA')
            
        except Exception as e:
            # Fallback vers la méthode simple
            print(f"Erreur BiRefNet: {e}")
            return self._remove_background_simple(image)
    
    def _remove_background_batch_birefnet(self, images_data):
        """
        Supprime le fond en utilisant BiRefNet par batch
        
        Args:
            images_data: Liste de tuples (image, original_size, image_path)
            
        Returns:
            Liste d'images RGBA
        """
        try:
            # Préparer le batch de tenseurs
            batch_tensors = []
            for image, _, _ in images_data:
                tensor = self.transform(image)
                batch_tensors.append(tensor)
            
            # Créer le batch
            batch = torch.stack(batch_tensors).to(self.device)
            
            # Convertir en FP16 si mode lite
            if self.use_lite:
                batch = batch.half()
            
            # Inférence avec BiRefNet sur le batch
            with torch.no_grad():
                outputs = self.model(batch)[-1].sigmoid()
                
                # Convertir en FP32 si nécessaire
                if self.use_lite:
                    outputs = outputs.float()
            
            # Traiter chaque image du batch
            results = []
            for idx, (image, original_size, _) in enumerate(images_data):
                # Extraire le masque alpha pour cette image
                mask = outputs[idx, 0].cpu().numpy()
                mask = (mask * 255).astype(np.uint8)
                
                # Redimensionner le masque à la taille originale
                mask_image = Image.fromarray(mask).resize(original_size, Image.BILINEAR)
                mask_array = np.array(mask_image)
                
                # Convertir l'image en array
                image_array = np.array(image)
                
                # Créer l'image RGBA
                rgba_image = np.zeros((image_array.shape[0], image_array.shape[1], 4), dtype=np.uint8)
                rgba_image[:, :, :3] = image_array  # RGB
                rgba_image[:, :, 3] = mask_array  # Alpha
                
                results.append(Image.fromarray(rgba_image, 'RGBA'))
            
            return results
            
        except Exception as e:
            # Fallback: traiter individuellement
            print(f"Erreur batch BiRefNet: {e}, fallback vers traitement individuel")
            return [self._remove_background_simple(img) for img, _, _ in images_data]
    
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
    
    images_traitees = 0
    erreurs = 0
    
    # Si GPU est utilisé avec BiRefNet
    if processor.use_gpu and processor.model is not None:
        # Traitement par batch si lite, sinon séquentiel
        if processor.use_lite and processor.batch_size > 1:
            with print_lock:
                print(f"[INFO] Traitement par batch de {processor.batch_size} avec BiRefNet_lite (GPU)")
            
            # Traiter les images par batch
            for batch_start in range(0, len(images), processor.batch_size):
                batch_end = min(batch_start + processor.batch_size, len(images))
                batch_paths = images[batch_start:batch_end]
                
                try:
                    # Charger et préparer le batch d'images
                    images_data = []
                    for img_path in batch_paths:
                        image = Image.open(img_path).convert('RGB')
                        original_size = image.size
                        images_data.append((image, original_size, img_path))
                    
                    # Traiter le batch
                    results = processor._remove_background_batch_birefnet(images_data)
                    
                    # Sauvegarder les résultats
                    for idx, (result, img_path) in enumerate(zip(results, batch_paths)):
                        output_path = output_sequence / img_path.name
                        output_path.parent.mkdir(parents=True, exist_ok=True)
                        result.save(output_path, 'PNG')
                        images_traitees += 1
                    
                    if images_traitees % 10 == 0 or images_traitees == len(images):
                        with print_lock:
                            print(f"[PROGRES] {sequence_path.name}: {images_traitees}/{len(images)} images traitées")
                
                except Exception as e:
                    with print_lock:
                        print(f"[ERREUR] Batch {batch_start}-{batch_end}: {e}")
                    erreurs += len(batch_paths)
        else:
            with print_lock:
                print(f"[INFO] Traitement séquentiel avec BiRefNet (GPU)")
            
            # Traiter les images une par une
            for idx, image_path in enumerate(images, 1):
                output_path = output_sequence / image_path.name
                nom_fichier, succès, erreur = traiter_image_unique(image_path, output_path, processor)
                
                if erreur:
                    with print_lock:
                        print(f"[ERREUR] {sequence_path.name}/{nom_fichier}: {erreur}")
                    erreurs += 1
                else:
                    images_traitees += 1
                    if images_traitees % 10 == 0:
                        with print_lock:
                            print(f"[PROGRES] {sequence_path.name}: {images_traitees}/{len(images)} images traitées")
    else:
        # Utiliser multi-threading pour OpenCV (CPU)
        # Déterminer le nombre de threads
        if nb_threads is None:
            nb_threads = min(len(images), os.cpu_count() or 1)
        
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

def traiter_sequences(sequence_specifique=None, nb_threads=None, force_gpu=False, force_cpu=False, use_lite=False, batch_size=4):
    """
    Traite toutes les séquences d'images avec suppression de fond
    
    Args:
        sequence_specifique (str, optional): Nom d'une séquence spécifique à traiter
        nb_threads (int, optional): Nombre de threads à utiliser
        force_gpu (bool): Forcer l'utilisation du GPU (arrêter si non disponible)
        force_cpu (bool): Forcer l'utilisation du CPU (utiliser OpenCV)
        use_lite (bool): Utiliser BiRefNet_lite (plus rapide, moins précis)
        batch_size (int): Taille du batch pour BiRefNet_lite
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
    
    print(f"[SUPPRESSION FOND] Suppression de fond automatique")
    print(f"Dossier source: {dossier_png_seq}")
    print(f"Dossier de sortie: {dossier_output}")
    print(f"Séquences à traiter: {len(sequences)}")
    print(f"Threads par séquence: {nb_threads if nb_threads else 'auto'}")
    
    # Vérifier la disponibilité du GPU
    gpu_available = torch.cuda.is_available()
    print(f"GPU disponible: {'Oui' if gpu_available else 'Non'}")
    if gpu_available:
        print(f"GPU: {torch.cuda.get_device_name(0)}")
    
    if force_gpu and not gpu_available:
        print("[ERREUR] GPU requis mais non disponible. Utilisez --cpu pour forcer l'utilisation du CPU.")
        return
    
    print("-" * 60)
    
    # Initialiser le processeur de suppression de fond
    try:
        if force_gpu:
            device = 'cuda'
        elif force_cpu:
            device = 'cpu'
        else:
            device = 'cuda' if gpu_available else 'cpu'
        
        processor = BackgroundRemovalProcessor(device=device, use_lite=use_lite, batch_size=batch_size)
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
  python supprimer_fond.py                           # Traite toutes les séquences (GPU si disponible)
  python supprimer_fond.py --lite                    # Utilise BiRefNet_lite (plus rapide)
  python supprimer_fond.py --sequence anim_tree_00037 # Traite une séquence spécifique
  python supprimer_fond.py --gpu                     # Force l'utilisation du GPU
  python supprimer_fond.py --cpu                     # Force l'utilisation d'OpenCV
  python supprimer_fond.py --threads 4               # Utilise 4 threads par séquence
  python supprimer_fond.py --lite --force            # BiRefNet_lite sans confirmation
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
    
    parser.add_argument(
        "--gpu",
        action="store_true",
        help="Forcer l'utilisation du GPU (arrêter si non disponible)"
    )
    
    parser.add_argument(
        "--cpu",
        action="store_true",
        help="Forcer l'utilisation du CPU (utiliser OpenCV)"
    )
    
    parser.add_argument(
        "--lite",
        action="store_true",
        help="Utiliser BiRefNet_lite (plus rapide, moins précis)"
    )
    
    parser.add_argument(
        "--batch-size",
        type=int,
        default=4,
        help="Taille du batch pour BiRefNet_lite (défaut: 4)"
    )
    
    args = parser.parse_args()
    
    # Vérifier les arguments contradictoires
    if args.gpu and args.cpu:
        print("[ERREUR] Les options --gpu et --cpu sont mutuellement exclusives.")
        sys.exit(1)
    
    # Afficher les informations
    print("[SUPPRESSION FOND] Suppresseur de fond automatique")
    print(f"Dossier source: output/png_seq/")
    print(f"Dossier de sortie: output/no_background/")
    print(f"Séquence: {args.sequence if args.sequence else 'toutes'}")
    print(f"Threads: {args.threads if args.threads else 'auto'}")
    
    # Afficher le mode de traitement
    if args.gpu:
        mode_str = "GPU forcé"
    elif args.cpu:
        mode_str = "CPU forcé (OpenCV)"
    else:
        mode_str = "Auto (GPU si disponible, sinon OpenCV)"
    
    if args.lite and not args.cpu:
        mode_str += " + BiRefNet_lite (rapide)"
    
    print(f"Mode: {mode_str}")
    
    # Demander confirmation sauf si --force
    if not args.force:
        print("\n[ATTENTION] Cette opération va supprimer le fond de toutes les images.")
        if not args.cpu:
            print("[ATTENTION] Le modèle de suppression de fond sera téléchargé depuis Hugging Face si nécessaire.")
        
        reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
        if reponse not in ['o', 'oui', 'y', 'yes']:
            print("Opération annulée.")
            sys.exit(0)
    
    # Lancer le traitement
    traiter_sequences(args.sequence, args.threads, args.gpu, args.cpu, args.lite, args.batch_size)

if __name__ == "__main__":
    main()
