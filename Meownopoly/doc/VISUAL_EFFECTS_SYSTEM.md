# Système d'Effets Visuels - MultiEffect Integration

## Vue d'ensemble

Le système d'effets visuels de Meownopoly utilise le composant `MultiEffect` de Qt Quick Effects pour appliquer des effets post-processing aux éléments de décoration. Cette implémentation offre une interface utilisateur intuitive et des optimisations de performance.

## Architecture

### Composants principaux

1. **SnapableDecoration** - Élément de décoration avec support des effets
2. **VisualEffectsPanel** - Interface utilisateur pour contrôler les effets
3. **AssetSelectionPanel** - Panneau intégrant les contrôles d'effets
4. **MultiEffect** - Composant Qt pour l'application des effets

### Structure des fichiers

```
qml/
├── editor/
│   ├── tools/
│   │   └── SnapableDecoration.qml          # Décoration avec effets
│   └── panel/
│       └── assetSelectionPanel/
│           ├── AssetSelectionPanel.qml      # Panneau principal
│           └── VisualEffectsPanel.qml       # Interface des effets
└── test/
    └── TEST_VISUAL_EFFECTS.qml             # Tests et démonstration
```

## Fonctionnalités

### Effets de couleur (toujours activés)
- **Luminosité** (`effectBrightness`) : -1.0 à 1.0
- **Contraste** (`effectContrast`) : -1.0 à 2.0
- **Saturation** (`effectSaturation`) : -1.0 à 2.0
- **Colorisation** (`effectColorization`) : 0.0 à 1.0
- **Couleur de colorisation** (`effectColorizationColor`) : couleur personnalisable

### Effets avancés (activation optionnelle)
- **Flou** (`effectBlurEnabled`, `effectBlur`) : effet de flou gaussien
- **Ombre** (`effectShadowEnabled`, `effectShadowBlur`) : ombre portée

## Interface utilisateur

### Panneau d'effets visuels

Le panneau d'effets visuels s'affiche automatiquement dans le panneau de sélection d'assets lorsqu'une décoration est sélectionnée.

#### Sections du panneau :

1. **Effets de couleur**
   - Sliders pour luminosité, contraste, saturation
   - Contrôle de colorisation avec sélecteur de couleur
   - Boutons de réinitialisation individuels

2. **Effets avancés**
   - Cases à cocher pour activer/désactiver les effets
   - Sliders pour ajuster l'intensité
   - Indicateurs visuels d'état

3. **Indicateur de performance**
   - Affichage en temps réel de l'impact sur les performances
   - Code couleur : Vert (aucun), Jaune (faible), Rouge (élevé)

### Contrôles interactifs

- **Sliders** : ajustement précis des valeurs numériques
- **Color picker** : sélection de couleur pour la colorisation
- **Checkboxes** : activation/désactivation des effets coûteux
- **Boutons de réinitialisation** : remise à zéro rapide

## Optimisations de performance

### Activation conditionnelle

```qml
// Propriété calculée pour déterminer si des effets sont actifs
readonly property bool hasActiveEffects: effectBrightness !== 0.0 || 
                                       effectContrast !== 0.0 || 
                                       effectSaturation !== 0.0 || 
                                       effectColorization !== 0.0 ||
                                       effectBlurEnabled || 
                                       effectShadowEnabled || 
                                       effectMaskEnabled

// Optimisation : ne créer MultiEffect que si nécessaire
readonly property bool shouldCreateEffect: hasActiveEffects
```

### Gestion de la visibilité

```qml
// Image source cachée quand les effets sont appliqués
Image {
    visible: !hasActiveEffects
}

// MultiEffect visible seulement quand nécessaire
MultiEffect {
    visible: shouldCreateEffect
    source: tileImage
}
```

### Recommandations de performance

1. **Éviter les effets coûteux** : Flou et ombre ont un impact significatif
2. **Optimiser la taille** : Plus l'élément est petit, meilleure est la performance
3. **Utilisation conditionnelle** : Désactiver les effets non utilisés
4. **Auto-padding** : Géré automatiquement pour le flou et l'ombre

## Utilisation

### Dans l'éditeur

1. Sélectionner une décoration dans l'éditeur
2. Le panneau d'effets visuels apparaît automatiquement
3. Ajuster les effets en temps réel
4. Les modifications sont appliquées instantanément

### Programmation

```qml
SnapableDecoration {
    // Effets de couleur
    effectBrightness: 0.3
    effectSaturation: -0.5
    effectColorization: 0.7
    effectColorizationColor: "#ff6600"
    
    // Effets avancés
    effectBlurEnabled: true
    effectBlur: 0.3
    effectShadowEnabled: true
    effectShadowColor: "#ff0000"
}
```

### Fonctions utilitaires

```qml
// Réinitialisation des effets
decoration.resetColorEffects()      // Effets de couleur uniquement
decoration.resetBlurEffect()        // Effet de flou
decoration.resetShadowEffect()      // Effet d'ombre
decoration.resetMaskEffect()        // Effet de masque
decoration.resetAllEffects()        // Tous les effets
```

## Tests et validation

### Fichier de test

`qml/test/TEST_VISUAL_EFFECTS.qml` fournit :
- Exemples de toutes les combinaisons d'effets
- Contrôles interactifs pour tester en temps réel
- Indicateurs de performance
- Démonstration des bonnes pratiques

### Lancement des tests

```bash
# Dans l'IDE, ouvrir TEST_VISUAL_EFFECTS.qml
# Ou dans l'application, naviguer vers le mode test
```

## Bonnes pratiques

### Performance
- Utiliser les effets de couleur de préférence (toujours optimisés)
- Éviter d'animer les propriétés qui changent le shader
- Désactiver les effets non utilisés
- Optimiser la taille des éléments

### Interface utilisateur
- Fournir un feedback visuel immédiat
- Utiliser des valeurs par défaut sensées
- Offrir des options de réinitialisation faciles
- Afficher l'impact sur les performances

### Développement
- Tester sur différentes configurations matérielles
- Valider la compatibilité avec les assets existants
- Documenter les nouvelles propriétés d'effet
- Maintenir la cohérence avec l'interface existante

## Dépannage

### Problèmes courants

1. **Effets non visibles** : Vérifier que `hasActiveEffects` est true
2. **Performance dégradée** : Réduire `blurMax` ou désactiver le flou/ombre
3. **Interface non responsive** : Vérifier la sélection de décoration
4. **Erreurs de shader** : Vérifier la compatibilité Qt Quick Effects

### Debugging

```qml
// Propriétés de debug utiles
console.log("Effects active:", hasActiveEffects)
console.log("Should create effect:", shouldCreateEffect)
console.log("MultiEffect visible:", multiEffect.visible)
```

## Évolutions futures

### Fonctionnalités prévues
- Presets d'effets prédéfinis
- Animation des transitions d'effets
- Sauvegarde/chargement des configurations
- Effets personnalisés via shaders

### Améliorations potentielles
- Optimisations shader supplémentaires
- Support des effets en lot
- Interface de création d'effets personnalisés
- Intégration avec le système de thèmes

## Références

- [Qt MultiEffect Documentation](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html)
- [Qt Quick Effects Module](https://doc.qt.io/qt-6/qtquickeffects-index.html)
- [Performance Guidelines](https://doc.qt.io/qt-6/qtquick-performance.html)
