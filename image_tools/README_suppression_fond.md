# Script de Suppression de Fond

Ce script permet de supprimer automatiquement le fond des séquences d'images PNG en utilisant des techniques d'intelligence artificielle.

## Fonctionnalités

- **Suppression de fond automatique** : Utilise des modèles de segmentation d'objets ou des algorithmes OpenCV
- **Traitement par séquences** : Traite toutes les images d'une séquence d'animation
- **Multi-threading** : Traitement parallèle pour améliorer les performances
- **Sortie avec transparence** : Génère des images PNG avec canal alpha
- **Fallback automatique** : Si le modèle IA n'est pas disponible, utilise OpenCV

## Installation

1. **Installer les dépendances** :
   ```bash
   python installer_dependances.py
   ```

2. **Ou installer manuellement** :
   ```bash
   pip install -r requirements.txt
   ```

## Utilisation

### Traiter toutes les séquences
```bash
python supprimer_fond.py
```

### Traiter une séquence spécifique
```bash
python supprimer_fond.py --sequence anim_tree_00037
```

### Utiliser plusieurs threads
```bash
python supprimer_fond.py --threads 4
```

### Traitement sans confirmation
```bash
python supprimer_fond.py --force
```

## Structure des dossiers

```
output/
├── png_seq/                    # Dossier source (séquences d'images)
│   ├── anim_tree_00037/
│   ├── anim_tree_00038/
│   └── anim_tree_00039/
└── no_background/              # Dossier de sortie (images sans fond)
    ├── anim_tree_00037/
    ├── anim_tree_00038/
    └── anim_tree_00039/
```

## Méthodes de suppression de fond

### 1. Modèle de segmentation (par défaut)
- Utilise un modèle de segmentation d'objets de Facebook
- Plus précis pour les objets complexes
- Nécessite une connexion internet pour le premier téléchargement

### 2. Méthode OpenCV (fallback)
- Utilise l'algorithme GrabCut d'OpenCV
- Fonctionne hors ligne
- Bon pour les objets centrés dans l'image

## Exemples de résultats

Les images de sortie sont au format PNG avec transparence (canal alpha), permettant de les utiliser directement dans des logiciels d'animation ou de montage.

## Performance

- **Vitesse** : Environ 2-4 images par seconde (selon la méthode utilisée)
- **Qualité** : Bonne qualité de suppression de fond
- **Compatibilité** : Fonctionne sur Windows, Linux et macOS

## Dépannage

### Erreur de modèle
Si le modèle de segmentation ne se charge pas, le script utilisera automatiquement la méthode OpenCV.

### Problèmes de performance
- Utilisez l'option `--threads` pour ajuster le nombre de threads
- Sur GPU, les performances peuvent être améliorées

### Images non traitées
Vérifiez que les images source sont au format PNG et dans le bon dossier.

## Dépendances

- `torch` et `torchvision` : PyTorch pour l'IA
- `opencv-python` : Traitement d'images
- `Pillow` : Manipulation d'images PNG
- `transformers` : Modèles Hugging Face
- `huggingface-hub` : Téléchargement de modèles
- `timm` : Modèles de vision par ordinateur
- `numpy` : Calculs numériques
