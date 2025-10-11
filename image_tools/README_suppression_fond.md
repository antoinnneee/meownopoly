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

### Traiter toutes les séquences (mode auto)
```bash
python supprimer_fond.py
```

### Utiliser BiRefNet_lite (plus rapide)
```bash
python supprimer_fond.py --lite
```

### Utiliser BiRefNet_lite avec batch processing personnalisé
```bash
python supprimer_fond.py --lite --batch-size 4  # Défaut : 4 (recommandé)
python supprimer_fond.py --lite --batch-size 8  # Batch plus grand (plus de VRAM nécessaire)
```

### Forcer l'utilisation du GPU
```bash
python supprimer_fond.py --gpu
```

### Forcer l'utilisation d'OpenCV (CPU)
```bash
python supprimer_fond.py --cpu
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

### 1. BiRefNet (GPU uniquement)
- Utilise le modèle BiRefNet de pointe pour la segmentation d'images
- Performance SOTA (State-of-the-Art) sur la suppression de fond
- Plus précis pour les objets complexes avec détails fins
- Nécessite une connexion internet pour le premier téléchargement
- **Utilise uniquement le GPU** - ne fonctionne pas sur CPU
- Modèle chargé depuis Hugging Face : `ZhengPeng7/BiRefNet`

**Variante BiRefNet_lite** (option `--lite`) :
- Version allégée et plus rapide
- Utilise FP16 (half precision) pour économiser la mémoire
- 2-3x plus rapide que BiRefNet standard
- Légèrement moins précis mais excellent compromis vitesse/qualité
- Modèle : `ZhengPeng7/BiRefNet_lite`
- **Supporte le batch processing** : traite plusieurs images simultanément
- Batch de 4 images par défaut (configurable avec `--batch-size`)
- Batch optimal : 4 pour RTX 3050 (4.4 images/s vs 4.0 en séquentiel)

### 2. Méthode OpenCV (CPU)
- Utilise l'algorithme GrabCut d'OpenCV
- Fonctionne hors ligne
- Bon pour les objets centrés dans l'image
- **Utilise uniquement le CPU**

### 3. Mode automatique
- **GPU disponible** : Utilise BiRefNet sur GPU
- **GPU non disponible** : Utilise automatiquement OpenCV sur CPU

## Exemples de résultats

Les images de sortie sont au format PNG avec transparence (canal alpha), permettant de les utiliser directement dans des logiciels d'animation ou de montage.

## Performance

- **BiRefNet standard** : ~1.0 images/s (qualité maximale, traitement séquentiel)
- **BiRefNet_lite (batch de 4)** : ~4.4 images/s (excellent compromis vitesse/qualité)
- **BiRefNet_lite (séquentiel)** : ~4.0 images/s 
- **OpenCV (CPU)** : ~3-4 images/s (qualité correcte)
- **Qualité** : Excellente avec BiRefNet, très bonne avec BiRefNet_lite, bonne avec OpenCV
- **Mémoire GPU** : 
  - BiRefNet : ~4-5 GB VRAM (traitement séquentiel uniquement)
  - BiRefNet_lite : ~2-3 GB VRAM (FP16, supporte batch processing)
- **Batch optimal** : 4 images pour BiRefNet_lite (meilleur compromis)
- **Compatibilité** : Fonctionne sur Windows, Linux et macOS

## Dépannage

### GPU non disponible
- Utilisez `--cpu` pour forcer l'utilisation d'OpenCV
- Le mode automatique basculera sur OpenCV si le GPU n'est pas disponible

### Erreur de modèle BiRefNet
- Le script utilisera automatiquement la méthode OpenCV en fallback
- Vérifiez votre connexion internet pour le téléchargement du modèle
- Le modèle (~444 MB) sera téléchargé depuis Hugging Face au premier lancement

### Problèmes de performance
- Utilisez l'option `--threads` pour ajuster le nombre de threads
- Sur GPU, les performances peuvent être améliorées
- Utilisez `--gpu` pour forcer l'utilisation du GPU

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
