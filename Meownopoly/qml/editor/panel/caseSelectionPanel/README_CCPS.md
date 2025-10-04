# Configuration des Cases - Nouveau Style

## Vue d'ensemble

La configuration des cases a été réimplémentée dans un nouveau style modulaire, inspiré du `VisualEffectsPanel`. Cette nouvelle implémentation offre une interface sombre et moderne pour configurer les propriétés des cases.

## Architecture

### Composant Principal

**`CaseConfigurationPanelSection.qml`**
- Point d'entrée principal pour la configuration des cases
- Gère le `targetCase` et `targetSnapableCase`
- Coordonne les différentes sections de configuration
- Style : fond sombre (#2a2a2a) avec bordure (#444444)

### Sections Modulaires

Chaque section est un composant autonome qui peut être affiché/masqué selon le type de case :

#### 1. **CCPS_TypeSection.qml**
- Sélection du type de case avec navigation par flèches
- Indicateur visuel de couleur par type
- Styles : sombre avec animations fluides

#### 2. **CCPS_GeneralSection.qml**
- Configuration générale (nom de la case)
- S'applique à tous les types de cases

#### 3. **CCPS_RestAreaSection.qml**
- Configuration spécifique aux zones de repos (terrains)
- Réutilise les composants :
  - `CCP_RestAreaFamilyConfig` : Configuration de la famille
  - `CCP_CatPerksConfig` : Prix d'achat et de rachat
  - `CCP_HouseHotelPriceConfig` : Prix des améliorations
  - `CCP_RentConfig` : Prix de location

#### 4. **CCPS_KibbleDispenserSection.qml**
- Configuration du distributeur de croquettes
- Récompense donnée au joueur
- Informations sur le fonctionnement

#### 5. **CCPS_CardBoardBoxSection.qml**
- Configuration des boîtes en carton (Caisse de Communauté)
- Informations visuelles sur le fonctionnement
- Conseils de placement

#### 6. **CCPS_CatDeviceSection.qml**
- Configuration des appareils pour chats
- Prix d'achat (via `CCP_CatPerksConfig`)
- Taxe d'utilisation
- Informations économiques

## Utilisation

### Définir une case cible

```qml
caseConfigurationPanelSection.setTargetCase(snapableCaseElement)
```

### Effacer la sélection

```qml
caseConfigurationPanelSection.clearTarget()
```

### Mettre à jour les contrôles

```qml
caseConfigurationPanelSection.updateControls()
```

## Signaux

- **`requestChangeType(var newType)`** : Émis quand l'utilisateur change le type de case
- **`configurationChanged()`** : Émis quand une configuration est modifiée

## Style Visuel

### Palette de couleurs

- **Fond principal** : #2a2a2a
- **Bordure** : #444444
- **GroupBox fond** : #333333
- **GroupBox bordure** : #555555
- **Texte titre** : #ffffff
- **Texte normal** : #cccccc
- **Texte secondaire** : #888888
- **Champs de saisie** : #2a2a2a avec bordure #555555
- **Accent (focus)** : #569c58

### Sections d'information

Les sections colorées utilisent des variantes sombres :
- **Jaune** (fonctionnement) : #3a3a1a / #4a4a2a
- **Bleu** (informations) : #1a2e3a / #2a3e4a
- **Vert** (conseils) : #1a3a2a / #2a4a3a
- **Cyan** (économie) : #1a3a3a / #2a4a4a

## Modularité

Chaque section :
- Est autonome et réutilisable
- Gère ses propres propriétés et mises à jour
- Émet des signaux pour communiquer avec le parent
- Suit le même style visuel cohérent
- Peut être facilement étendue

## Avantages

1. **Cohérence visuelle** : Style uniforme inspiré de `VisualEffectsPanel`
2. **Modularité** : Sections indépendantes faciles à maintenir
3. **Réutilisabilité** : Composants CCP existants intégrés
4. **Extensibilité** : Facile d'ajouter de nouveaux types de cases
5. **UX améliorée** : Interface moderne et intuitive

## Fichiers créés

1. `CaseConfigurationPanelSection.qml` - Composant principal
2. `CCPS_TypeSection.qml` - Sélection du type
3. `CCPS_GeneralSection.qml` - Configuration générale
4. `CCPS_RestAreaSection.qml` - Configuration RestArea
5. `CCPS_KibbleDispenserSection.qml` - Configuration KibbleDispenser
6. `CCPS_CardBoardBoxSection.qml` - Configuration CardBoardBox
7. `CCPS_CatDeviceSection.qml` - Configuration CatDevice

Tous les fichiers sont enregistrés dans `qml.qrc` pour être accessibles dans l'application.

