# Système d'Effets Visuels - MultiEffect Integration

## Vue d'ensemble

Le système d'effets visuels de Meownopoly utilise le composant `MultiEffect` de Qt Quick Effects pour appliquer des effets post-processing aux éléments de décoration (`SnapableDecoration`). Le système est désormais modulaire, permettant de contrôler indépendamment les couleurs, les effets avancés (flou, ombre) et les transformations (rotation, miroir).

## Architecture

### Composants principaux

1.  **SnapableDecoration** : L'élément visuel de base qui intègre le `MultiEffect` et gère le rendu des assets avec leurs effets et transformations.
2.  **VisualEffectsPanel** : Le conteneur principal de l'interface utilisateur des effets, intégré dans le panneau latéral inférieur (`BottomSidePanel_Content`).
3.  **Sections Modulaires** :
    - **VEP_ColorEffectsSection** : Contrôle de la luminosité, contraste, saturation et colorisation.
    - **VEP_AdvancedEffectsSection** : Gestion du flou et de l'ombre portée (plus coûteux en performance).
    - **VEP_Rotation** : Contrôle des transformations géométriques (angle de rotation et symétries).

### Structure des fichiers

```
qml/
├── meowComponent/
│   └── snapable/
│       └── SnapableDecoration.qml          # Décoration avec support MultiEffect
└── editor/
    └── panel/
        └── bottomPanel/
            └── bottomSidePanel/
                └── visualEffectPanel/
                    ├── VisualEffectsPanel.qml       # Panneau conteneur
                    ├── VEP_ColorEffectsSection.qml   # Section Couleurs
                    ├── VEP_AdvancedEffectsSection.qml # Section Avancé (Blur/Shadow)
                    └── VEP_Rotation.qml              # Section Transformations
```

## Fonctionnalités

### Effets de couleur
- **Luminosité** (`effectBrightness`) : -1.0 à 1.0
- **Contraste** (`effectContrast`) : -1.0 à 1.0
- **Saturation** (`effectSaturation`) : -1.0 à 1.0
- **Colorisation** (`effectColorization`) : 0.0 à 1.0
- **Couleur de colorisation** (`effectColorizationColor`)

### Effets avancés (Activation optionnelle)
- **Flou** (`effectBlurEnabled`, `effectBlur`) : Effet de flou gaussien.
- **Ombre** (`effectShadowEnabled`, `effectShadowBlur`) : Ombre portée avec contrôle de l'opacité et de l'offset.

### Transformations (Nouveau)
- **Rotation** (`rotationAngle`) : Rotation libre sur l'axe Z (-180° à 180°).
- **Miroir Horizontal** (`mirrorHorizontal`) : Symétrie par rapport à l'axe vertical.
- **Miroir Vertical** (`mirrorVertical`) : Symétrie par rapport à l'axe horizontal.

## Optimisations de performance

### Activation conditionnelle
Le `MultiEffect` est toujours instancié mais reste masqué (`visible: shouldCreateEffect`) tant qu'aucun effet n'est actif ; l'image source (`AnimatedImage`) est alors affichée à sa place (`visible: !hasActiveEffects`).

```qml
// Propriété calculée dans SnapableDecoration.qml
readonly property bool hasActiveEffects: snapableParameters.displayParameter.effectBrightness !== 0.0 ||
                                         // ... autres propriétés d'effet ...
                                         snapableParameters.displayParameter.effectShadowEnabled

readonly property bool shouldCreateEffect: hasActiveEffects
```

### Gestion du pipeline de rendu
- L'image source (`AnimatedImage`) est masquée (`visible: !hasActiveEffects`) lorsque le `MultiEffect` prend le relais.
- Les transformations (rotation/scale) sont appliquées de manière cohérente sur la source et sur l'effet.

## Utilisation (Développeur)

### Application d'effets en QML
Les propriétés sont désormais centralisées dans l'objet `displayParameter` du `SnapableItem`.

```qml
SnapableDecoration {
    // Les paramètres sont généralement injectés via le modèle de données
    // mais peuvent être manipulés via displayParameter
    snapableParameters.displayParameter.effectBrightness: 0.2
    snapableParameters.displayParameter.rotationAngle: 45
    snapableParameters.displayParameter.mirrorHorizontal: true
}
```

## Tests et Validation

> [!IMPORTANT]
> La page `TEST_VISUAL_EFFECTS.qml` a été supprimée. La validation des effets doit désormais se faire directement dans l'éditeur de cartes en sélectionnant une décoration et en utilisant le panneau "Visual Effects".

### Points de vérification
1.  **Réactivité** : L'effet doit s'appliquer instantanément lors du mouvement des sliders.
2.  **Cumul** : Vérifier que la rotation fonctionne correctement même quand un flou ou une ombre est appliqué.
3.  **Performance** : Surveiller la fluidité de la grille lors de l'application massive d'ombres sur de grands objets.

## Dépannage

- **L'effet ne s'affiche pas** : Vérifiez que `shouldCreateEffect` est bien à `true` et que l'image source a fini de charger.
- **Rotation tronquée** : Le moteur gère l'auto-padding pour le flou, mais une rotation extrême sur un objet non-carré peut parfois nécessiter un ajustement de la boîte englobante du `SnapableElement`.

## Références
- [Qt MultiEffect Documentation](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html)
- [Meownopoly Architecture - Snapable System](./ANALYSE_ARCHITECTURE_EDITEUR.md)
