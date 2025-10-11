#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de test standalone pour BiRefNet
Teste le modèle sur une seule image pour vérifier le fonctionnement
"""

import torch
import numpy as np
from PIL import Image
from transformers import AutoModelForImageSegmentation
import time

def test_birefnet():
    """
    Teste BiRefNet sur une image de test
    """
    print("=" * 60)
    print("Test de BiRefNet")
    print("=" * 60)
    
    # Vérifier la disponibilité du GPU
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"Device: {device}")
    
    if device == 'cuda':
        print(f"GPU: {torch.cuda.get_device_name(0)}")
        print(f"CUDA Version: {torch.version.cuda}")
    
    # Charger le modèle depuis Hugging Face
    print("\nChargement du modèle BiRefNet depuis Hugging Face...")
    start_time = time.time()
    
    try:
        model = AutoModelForImageSegmentation.from_pretrained(
            'ZhengPeng7/BiRefNet',
            trust_remote_code=True
        )
        model.to(device)
        model.eval()
        
        load_time = time.time() - start_time
        print(f"Modèle chargé en {load_time:.2f}s")
        
    except Exception as e:
        print(f"Erreur lors du chargement: {e}")
        return False
    
    # Trouver une image de test
    import glob
    test_images = glob.glob("output/png_seq/anim_tree_00037/*.png")
    
    if not test_images:
        print("Aucune image de test trouvée!")
        return False
    
    test_image_path = test_images[0]
    print(f"\nTest sur: {test_image_path}")
    
    # Charger l'image
    try:
        image = Image.open(test_image_path).convert('RGB')
        print(f"Taille image: {image.size}")
        
        # Préparer l'image pour le modèle
        from torchvision import transforms
        
        transform = transforms.Compose([
            transforms.Resize((1024, 1024)),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])
        
        input_tensor = transform(image).unsqueeze(0).to(device)
        print(f"Tensor shape: {input_tensor.shape}")
        
        # Inférence
        print("\nInférence...")
        start_time = time.time()
        
        with torch.no_grad():
            output = model(input_tensor)[-1].sigmoid()
        
        inference_time = time.time() - start_time
        print(f"Inférence terminée en {inference_time:.3f}s")
        print(f"Output shape: {output.shape}")
        
        # Post-traitement
        mask = output[0, 0].cpu().numpy()
        mask = (mask * 255).astype(np.uint8)
        
        # Redimensionner à la taille originale
        from PIL import Image as PILImage
        mask_image = PILImage.fromarray(mask).resize(image.size, PILImage.BILINEAR)
        
        # Créer l'image RGBA
        image_array = np.array(image)
        mask_array = np.array(mask_image)
        
        rgba_image = np.zeros((image_array.shape[0], image_array.shape[1], 4), dtype=np.uint8)
        rgba_image[:, :, :3] = image_array
        rgba_image[:, :, 3] = mask_array
        
        # Sauvegarder l'image de test
        result_image = PILImage.fromarray(rgba_image, 'RGBA')
        output_path = "test_birefnet_output.png"
        result_image.save(output_path)
        
        print(f"\nImage de test sauvegardée: {output_path}")
        print(f"Vitesse: {1/inference_time:.2f} images/s")
        
        # Statistiques mémoire GPU
        if device == 'cuda':
            memory_allocated = torch.cuda.memory_allocated(0) / 1024**3
            memory_reserved = torch.cuda.memory_reserved(0) / 1024**3
            print(f"\nMémoire GPU:")
            print(f"  Allouée: {memory_allocated:.2f} GB")
            print(f"  Réservée: {memory_reserved:.2f} GB")
        
        print("\n" + "=" * 60)
        print("Test réussi!")
        print("=" * 60)
        return True
        
    except Exception as e:
        print(f"Erreur lors du traitement: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_birefnet()
    exit(0 if success else 1)
