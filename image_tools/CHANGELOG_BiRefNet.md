# Changelog - Intégration BiRefNet

## ✅ Implémentation complète

### Modèles disponibles

#### 1. BiRefNet (standard)
- **Modèle** : `ZhengPeng7/BiRefNet`
- **Qualité** : Maximale (SOTA)
- **Vitesse** : ~1.0 images/s
- **VRAM** : ~4-5 GB
- **Précision** : FP32
- **Usage** : `python supprimer_fond.py`

#### 2. BiRefNet_lite (nouveau) ⭐
- **Modèle** : `ZhengPeng7/BiRefNet_lite`
- **Qualité** : Excellente
- **Vitesse** : ~4.4 images/s avec batch de 4 (4x plus rapide)
- **VRAM** : ~2-3 GB (économie mémoire)
- **Précision** : FP16 (half precision)
- **Batch processing** : Oui (4 images par défaut)
- **Usage** : `python supprimer_fond.py --lite`
- **Usage avancé** : `python supprimer_fond.py --lite --batch-size 4`

#### 3. OpenCV (fallback)
- **Algorithme** : GrabCut
- **Qualité** : Bonne
- **Vitesse** : ~3-4 images/s
- **Usage** : `python supprimer_fond.py --cpu`

## 📝 Fichiers modifiés

### `supprimer_fond.py`
- ✅ Ajout du paramètre `use_lite` dans `BackgroundRemovalProcessor`
- ✅ Chargement automatique de BiRefNet ou BiRefNet_lite selon l'option
- ✅ Support FP16 (half precision) pour BiRefNet_lite
- ✅ Conversion automatique FP16 ↔ FP32 pendant l'inférence
- ✅ Nouvelle option CLI `--lite`
- ✅ **Batch processing** pour BiRefNet_lite (nouveau)
- ✅ Nouvelle option CLI `--batch-size` (défaut: 4)
- ✅ Traitement optimisé par lots de 4 images simultanément
- ✅ Messages informatifs sur le modèle et le batch chargé

### `README_suppression_fond.md`
- ✅ Documentation BiRefNet_lite
- ✅ Comparaison des performances
- ✅ Exemples d'utilisation
- ✅ Information sur la consommation mémoire

### Nouveaux fichiers
- ✅ `test_birefnet_lite.py` - Script de benchmark comparatif

## 🚀 Exemples d'utilisation

### Mode standard (qualité maximale)
```bash
python supprimer_fond.py
```

### Mode lite (rapide, recommandé)
```bash
python supprimer_fond.py --lite
```

### Avec séquence spécifique
```bash
python supprimer_fond.py --sequence anim_tree_00037 --lite --force
```

### Forcer GPU avec lite
```bash
python supprimer_fond.py --gpu --lite
```

## 📊 Performance mesurée

### Configuration de test
- **GPU** : NVIDIA GeForce RTX 3050 (8GB)
- **Résolution** : 1024x1024
- **Images** : Séquence anim_tree_00037 (121 images)

### Résultats
- **BiRefNet standard** : 115.4s pour 121 images = 1.0 images/s
- **BiRefNet_lite (séquentiel)** : 30.3s pour 121 images = 4.0 images/s
- **BiRefNet_lite (batch de 4)** : 27.7s pour 121 images = 4.4 images/s ⭐
- **BiRefNet_lite (batch de 8)** : 51.6s pour 121 images = 2.3 images/s (surcharge mémoire)
- **Gain vs standard** : 4.4x plus rapide avec batch de 4
- **Gain batch vs séquentiel** : +10% de vitesse avec batch de 4

### Recommandations
1. **Qualité maximale** : Utiliser BiRefNet standard (défaut)
2. **Production/Volume** : Utiliser BiRefNet_lite avec batch (`--lite --batch-size 4`) ⭐ Recommandé
3. **GPU limité** : Réduire la taille du batch (`--lite --batch-size 2`)
4. **Sans GPU** : Utiliser OpenCV (`--cpu`)

## 🔧 Améliorations techniques

### Optimisations BiRefNet_lite
- ✅ Modèle chargé en FP16 automatiquement
- ✅ Tenseurs d'entrée convertis en FP16
- ✅ Sortie reconvertie en FP32 pour compatibilité
- ✅ Réduction de ~50% de la mémoire GPU
- ✅ Accélération 4x de l'inférence vs standard
- ✅ **Batch processing** : traitement par lots de 4 images
- ✅ Gain supplémentaire de 10% avec batch vs séquentiel
- ✅ Gestion automatique des batches incomplets

### Traitement des séquences
- ✅ GPU BiRefNet standard : Traitement séquentiel pour éviter OOM
- ✅ GPU BiRefNet_lite : Traitement par batch pour meilleure performance
- ✅ CPU OpenCV : Multi-threading préservé
- ✅ Gestion intelligente de la mémoire selon le mode

## ✨ Points clés

1. **Compatibilité totale** : Tous les scripts existants fonctionnent sans changement
2. **Option opt-in** : `--lite` est une option, pas un remplacement
3. **Fallback automatique** : OpenCV si échec du chargement GPU
4. **Performance mesurable** : Gain réel de 4.4x avec BiRefNet_lite + batch
5. **Qualité préservée** : Excellente qualité même en mode lite
6. **Batch processing** : Traitement optimisé pour BiRefNet_lite
7. **Configurable** : Taille du batch ajustable selon la VRAM disponible

## 🎯 Résumé

L'intégration de BiRefNet_lite avec batch processing offre un excellent compromis entre qualité et vitesse :
- **4.4x plus rapide** que BiRefNet standard
- **10% plus rapide** que le traitement séquentiel
- Traitement par lots de 4 images simultanément
- Recommandé pour la production avec des volumes importants d'images

Le mode standard reste disponible pour les cas nécessitant la qualité maximale.
