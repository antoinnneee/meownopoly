#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script pour renommer les images dans le dossier courant
Format de sortie: [nom]-[numImg].png
"""

import os
import sys
import glob
from pathlib import Path

def renommer_images(nom_base):
    """
    Renomme toutes les images PNG du dossier courant
    
    Args:
        nom_base (str): Le nom de base à utiliser pour les images
    """
    # Obtenir le dossier courant
    dossier_courant = Path.cwd()
    
    # Trouver tous les fichiers PNG
    fichiers_png = list(dossier_courant.glob("*.png"))
    
    if not fichiers_png:
        print("Aucun fichier PNG trouvé dans le dossier courant.")
        return
    
    # Trier les fichiers par nom pour avoir un ordre cohérent
    fichiers_png.sort()
    
    print(f"Trouvé {len(fichiers_png)} fichier(s) PNG à renommer.")
    print(f"Nom de base: {nom_base}")
    print("-" * 50)
    
    # Renommer chaque fichier
    for i, fichier in enumerate(fichiers_png, 1):
        ancien_nom = fichier.name
        nouveau_nom = f"{nom_base}-{i:03d}.png"
        nouveau_chemin = fichier.parent / nouveau_nom
        
        try:
            # Vérifier si le nouveau nom existe déjà
            if nouveau_chemin.exists() and nouveau_chemin != fichier:
                print(f"⚠️  Le fichier {nouveau_nom} existe déjà. Ignoré.")
                continue
            
            # Renommer le fichier
            fichier.rename(nouveau_chemin)
            print(f"✅ {ancien_nom} → {nouveau_nom}")
            
        except Exception as e:
            print(f"❌ Erreur lors du renommage de {ancien_nom}: {e}")
    
    print("-" * 50)
    print("Renommage terminé !")

def main():
    """Fonction principale"""
    if len(sys.argv) != 2:
        print("Usage: python renommer_images.py <nom_base>")
        print("Exemple: python renommer_images.py grass")
        print("Cela renommera les images en: grass-001.png, grass-002.png, etc.")
        sys.exit(1)
    
    nom_base = sys.argv[1]
    
    # Vérifier que le nom de base ne contient que des caractères valides
    if not nom_base.replace("-", "").replace("_", "").isalnum():
        print("❌ Le nom de base ne peut contenir que des lettres, chiffres, tirets et underscores.")
        sys.exit(1)
    
    # Demander confirmation
    print(f"Vous êtes sur le point de renommer toutes les images PNG du dossier:")
    print(f"Dossier: {Path.cwd()}")
    print(f"Format: {nom_base}-XXX.png")
    
    reponse = input("\nVoulez-vous continuer ? (o/N): ").strip().lower()
    if reponse not in ['o', 'oui', 'y', 'yes']:
        print("Opération annulée.")
        sys.exit(0)
    
    renommer_images(nom_base)

if __name__ == "__main__":
    main()
