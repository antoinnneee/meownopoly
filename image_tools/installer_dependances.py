#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour installer les dépendances nécessaires pour supprimer_fond.py
"""

import subprocess
import sys
import os

def installer_dependances():
    """
    Installe les dépendances depuis requirements.txt
    """
    print("Installation des dependances pour BiRefNet...")
    print("Cela peut prendre plusieurs minutes...")
    
    try:
        # Installer les dépendances
        result = subprocess.run([
            sys.executable, "-m", "pip", "install", "-r", "requirements.txt"
        ], capture_output=True, text=True, check=True)
        
        print("Dependances installees avec succes !")
        print("\nDependances installees :")
        print("- torch et torchvision (PyTorch)")
        print("- opencv-python (OpenCV)")
        print("- Pillow (PIL)")
        print("- huggingface-hub")
        print("- transformers")
        print("- numpy")
        
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"Erreur lors de l'installation : {e}")
        print(f"Sortie d'erreur : {e.stderr}")
        return False
    except Exception as e:
        print(f"Erreur inattendue : {e}")
        return False

def verifier_installation():
    """
    Vérifie que les dépendances sont correctement installées
    """
    print("\nVerification de l'installation...")
    
    modules_a_verifier = [
        "torch",
        "torchvision", 
        "cv2",
        "PIL",
        "huggingface_hub",
        "transformers",
        "numpy"
    ]
    
    modules_ok = []
    modules_erreur = []
    
    for module in modules_a_verifier:
        try:
            __import__(module)
            modules_ok.append(module)
            print(f"OK {module}")
        except ImportError:
            modules_erreur.append(module)
            print(f"ERREUR {module}")
    
    if modules_erreur:
        print(f"\n{len(modules_erreur)} module(s) manquant(s) : {', '.join(modules_erreur)}")
        return False
    else:
        print(f"\nTous les modules sont installes ({len(modules_ok)} modules)")
        return True

def main():
    """Fonction principale"""
    print("Installation des dependances pour supprimer_fond.py")
    print("=" * 60)
    
    # Vérifier si requirements.txt existe
    if not os.path.exists("requirements.txt"):
        print("Le fichier requirements.txt n'existe pas.")
        return
    
    # Installer les dépendances
    if installer_dependances():
        # Vérifier l'installation
        if verifier_installation():
            print("\nInstallation terminee avec succes !")
            print("\nVous pouvez maintenant utiliser supprimer_fond.py :")
            print("  python supprimer_fond.py --help")
            print("  python supprimer_fond.py --sequence anim_tree_00037 --force")
        else:
            print("\nInstallation terminee mais certains modules ne sont pas disponibles.")
            print("Essayez de redemarrer votre terminal et relancer le script.")
    else:
        print("\nEchec de l'installation.")
        print("Verifiez votre connexion internet et votre environnement Python.")

if __name__ == "__main__":
    main()
