#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de comparaison BiRefNet vs BiRefNet_lite
"""

import torch
import time
from transformers import AutoModelForImageSegmentation
from PIL import Image
from torchvision import transforms
import glob

def test_model(model_name, use_half=False):
    """
    Teste un modèle BiRefNet
    """
    print(f"\n{'='*60}")
    print(f"Test de {model_name}")
    print(f"{'='*60}")
    
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    print(f"Device: {device}")
    
    # Charger le modèle
    print(f"Chargement du modèle...")
    start = time.time()
    model = AutoModelForImageSegmentation.from_pretrained(
        model_name,
        trust_remote_code=True
    )
    model.to(device)
    model.eval()
    
    if use_half:
        model.half()
        print("Mode FP16 activé")
    
    load_time = time.time() - start
    print(f"Modèle chargé en {load_time:.2f}s")
    
    # Charger une image de test
    test_images = glob.glob("output/png_seq/anim_tree_00037/*.png")
    if not test_images:
        print("Aucune image de test!")
        return
    
    image = Image.open(test_images[0]).convert('RGB')
    print(f"Image de test: {test_images[0]}")
    print(f"Taille: {image.size}")
    
    # Préparer les transformations
    transform = transforms.Compose([
        transforms.Resize((1024, 1024)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    ])
    
    input_tensor = transform(image).unsqueeze(0).to(device)
    if use_half:
        input_tensor = input_tensor.half()
    
    # Warmup
    print("Warmup...")
    with torch.no_grad():
        _ = model(input_tensor)
    
    # Benchmark
    print("Benchmark (10 itérations)...")
    times = []
    for i in range(10):
        start = time.time()
        with torch.no_grad():
            output = model(input_tensor)[-1].sigmoid()
            if use_half:
                output = output.float()
        torch.cuda.synchronize() if device == 'cuda' else None
        elapsed = time.time() - start
        times.append(elapsed)
        print(f"  Itération {i+1}: {elapsed:.3f}s ({1/elapsed:.2f} images/s)")
    
    avg_time = sum(times) / len(times)
    print(f"\nTemps moyen: {avg_time:.3f}s")
    print(f"Vitesse moyenne: {1/avg_time:.2f} images/s")
    
    # Mémoire GPU
    if device == 'cuda':
        memory_allocated = torch.cuda.memory_allocated(0) / 1024**3
        memory_reserved = torch.cuda.memory_reserved(0) / 1024**3
        print(f"\nMémoire GPU:")
        print(f"  Allouée: {memory_allocated:.2f} GB")
        print(f"  Réservée: {memory_reserved:.2f} GB")
    
    return avg_time

if __name__ == "__main__":
    print("Comparaison BiRefNet vs BiRefNet_lite")
    print("="*60)
    
    if not torch.cuda.is_available():
        print("ATTENTION: GPU non disponible!")
    
    # Test BiRefNet standard
    time_standard = test_model('ZhengPeng7/BiRefNet', use_half=False)
    
    # Nettoyer la mémoire
    torch.cuda.empty_cache()
    
    # Test BiRefNet_lite
    time_lite = test_model('ZhengPeng7/BiRefNet_lite', use_half=True)
    
    # Comparaison
    print(f"\n{'='*60}")
    print("COMPARAISON")
    print(f"{'='*60}")
    print(f"BiRefNet standard: {1/time_standard:.2f} images/s")
    print(f"BiRefNet_lite: {1/time_lite:.2f} images/s")
    print(f"Gain de vitesse: {time_standard/time_lite:.2f}x")
    print(f"{'='*60}")
