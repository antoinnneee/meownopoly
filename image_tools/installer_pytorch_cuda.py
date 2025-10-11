#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour installer PyTorch avec support CUDA
"""

import subprocess
import sys
import os

def desinstaller_pytorch_cpu():
    """
    Désinstalle PyTorch CPU pour le remplacer par la version CUDA
    """
    print("Desinstallation de PyTorch CPU...")
    
    try:
        result = subprocess.run([
            sys.executable, "-m", "pip", "uninstall", 
            "torch", "torchvision", "torchaudio", "-y"
        ], capture_output=True, text=True, check=True)
        
        print("PyTorch CPU desinstalle avec succes")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Erreur lors de la desinstallation: {e}")
        return False

def installer_pytorch_cuda():
    """
    Installe PyTorch avec support CUDA
    """
    print("Installation de PyTorch avec support CUDA...")
    print("Cela peut prendre plusieurs minutes...")
    
    try:
        # Commande pour installer PyTorch avec CUDA 12.1 (compatible avec CUDA 12.6)
        result = subprocess.run([
            sys.executable, "-m", "pip", "install", 
            "torch", "torchvision", "torchaudio", 
            "--index-url", "https://download.pytorch.org/whl/cu121"
        ], capture_output=True, text=True, check=True)
        
        print("PyTorch CUDA installe avec succes !")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Erreur lors de l'installation: {e}")
        print(f"Sortie d'erreur: {e.stderr}")
        return False

def verifier_installation():
    """
    Vérifie que PyTorch CUDA est correctement installé
    """
    print("\nVerification de l'installation...")
    
    try:
        import torch
        print(f"Version PyTorch: {torch.__version__}")
        print(f"CUDA disponible: {torch.cuda.is_available()}")
        
        if torch.cuda.is_available():
            print(f"Nombre de GPUs: {torch.cuda.device_count()}")
            print(f"GPU actuel: {torch.cuda.get_device_name(0)}")
            print(f"Version CUDA: {torch.version.cuda}")
            return True
        else:
            print("ERREUR: CUDA non disponible")
            return False
            
    except ImportError as e:
        print(f"ERREUR: Impossible d'importer PyTorch: {e}")
        return False

def main():
    """Fonction principale"""
    print("Installation de PyTorch avec support CUDA")
    print("=" * 50)
    
    # Vérifier la version CUDA du système
    print("Verification de votre configuration GPU...")
    try:
        result = subprocess.run(["nvidia-smi"], capture_output=True, text=True)
        if result.returncode == 0:
            print("GPU NVIDIA detecte")
        else:
            print("ATTENTION: nvidia-smi non disponible")
    except:
        print("ATTENTION: Impossible de verifier nvidia-smi")
    
    # Demander confirmation
    print("\nCette operation va:")
    print("1. Desinstaller PyTorch CPU actuel")
    print("2. Installer PyTorch avec support CUDA")
    print("3. Verifier l'installation")
    
    reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
    if reponse not in ['o', 'oui', 'y', 'yes']:
        print("Operation annulee.")
        return
    
    # Étape 1: Désinstaller PyTorch CPU
    if not desinstaller_pytorch_cpu():
        print("Echec de la desinstallation. Arret.")
        return
    
    # Étape 2: Installer PyTorch CUDA
    if not installer_pytorch_cuda():
        print("Echec de l'installation. Arret.")
        return
    
    # Étape 3: Vérifier l'installation
    if verifier_installation():
        print("\nInstallation terminee avec succes !")
        print("\nVous pouvez maintenant utiliser le GPU avec supprimer_fond.py:")
        print("  python supprimer_fond.py --gpu")
    else:
        print("\nInstallation terminee mais verification echouee.")
        print("Redemarrez votre terminal et essayez de nouveau.")

if __name__ == "__main__":
    main()
