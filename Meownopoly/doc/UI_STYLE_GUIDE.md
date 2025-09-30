# 🎨 Guide de Style UI Meownopoly

Ce document définit les standards de design et les principes d'interface utilisateur à suivre pour maintenir une expérience cohérente dans l'application Meownopoly.

## 🎯 Principes Généraux

### Philosophie de Design

- **Félin et ludique** : Interface amusante et thématique
- **Intuitive** : Facile à comprendre sans instructions
- **Réactive** : Feedback immédiat aux actions de l'utilisateur
- **Cohérente** : Styles et comportements uniformes
- **Accessible** : Utilisable par tous les joueurs

### Objectifs de l'Interface

- Communiquer clairement les mécaniques de jeu
- Maintenir l'immersion dans l'univers félin
- Faciliter la navigation et la compréhension
- S'adapter à différentes tailles d'écran
- Minimiser la charge cognitive

## 🎭 Thème Félin

### Éléments Caractéristiques

- **Pattes de chat** : Utilisées pour les boutons, menus et points focaux
- **Oreilles de chat** : Pour les en-têtes et titres
- **Textures poilues** : Subtiles, pour les arrière-plans et séparateurs
- **Griffures** : Pour les éléments d'accent et décoratifs
- **Pelotes** : Pour les indicateurs et petits éléments interactifs

### Métaphores Visuelles

- **Carton** : Conteneurs et panneaux (boîtes de chat)
- **Pelage** : Textures de fond et séparateurs
- **Jouets** : Indicateurs interactifs
- **Griffoirs** : Barres de progression et sliders

## 🎨 Palette de Couleurs

### Couleurs Principales

| Nom | HEX | RGB | Utilisation |
|-----|-----|-----|------------|
| **Chat Noir** | `#2D2A32` | `45, 42, 50` | Texte principal, icônes |
| **Chat Gris** | `#4A4A4A` | `74, 74, 74` | Texte secondaire, contours |
| **Crème** | `#F2E8DC` | `242, 232, 220` | Arrière-plans, zones de contenu |
| **Brun Chaton** | `#BE8E63` | `190, 142, 99` | Accents, séparateurs |
| **Orangé** | `#E67E22` | `230, 126, 34` | Boutons, actions principales |
| **Patte Rose** | `#FF90B3` | `255, 144, 179` | Accents secondaires, surbrillances |

### Couleurs Secondaires

| Nom | HEX | RGB | Utilisation |
|-----|-----|-----|------------|
| **Vert Herbe à Chat** | `#7CB518` | `124, 181, 24` | Positif, succès |
| **Bleu Yeux** | `#3498DB` | `52, 152, 219` | Information, sélection |
| **Rouge Jouet** | `#E74C3C` | `231, 76, 60` | Négatif, erreur |
| **Violet Nuit** | `#8E44AD` | `142, 68, 173` | Premium, spécial |

### Groupes de Propriétés

Palette pour les groupes de propriétés sur le plateau :

| Groupe | HEX | RGB | Nom |
|--------|-----|-----|-----|
| 1 | `#964B00` | `150, 75, 0` | Marron |
| 2 | `#87CEEB` | `135, 206, 235` | Bleu Ciel |
| 3 | `#FF69B4` | `255, 105, 180` | Rose |
| 4 | `#FFA500` | `255, 165, 0` | Orange |
| 5 | `#FF0000` | `255, 0, 0` | Rouge |
| 6 | `#FFFF00` | `255, 255, 0` | Jaune |
| 7 | `#008000` | `0, 128, 0` | Vert |
| 8 | `#000080` | `0, 0, 128` | Bleu Foncé |

## 📐 Typographie

### Familles de Polices

- **Titre** : "Catpaw" (police personnalisée avec des oreilles de chat) ou "Comic Neue Bold"
- **Corps** : "Nunito" ou "Quicksand"
- **Interface** : "Roboto" ou "Open Sans"
- **Monospace** : "Fira Code" ou "Roboto Mono"

### Hiérarchie Typographique

| Élément | Taille | Graisse | Utilisation |
|---------|--------|---------|------------|
| H1 | 36px | Bold | Titres d'écran |
| H2 | 28px | Bold | Sections principales |
| H3 | 22px | SemiBold | Sous-sections |
| H4 | 18px | SemiBold | Entêtes de groupe |
| Body | 16px | Regular | Texte général |
| Small | 14px | Regular | Texte secondaire |
| Caption | 12px | Light | Légendes, notes |

### Règles Typographiques

- Texte sombre sur fond clair pour une lisibilité maximale
- Éviter les paragraphes de plus de 3-4 lignes
- Utiliser des listes à puces pour les informations séquentielles
- Aligner le texte à gauche (pas de justification)
- Interligne de 1.4 à 1.5 pour le texte de corps

## 🧩 Composants UI

### Boutons

#### Types de Boutons

- **Principal** : Actions importantes, forme de patte de chat
- **Secondaire** : Actions alternatives, rectangle arrondi
- **Tertiaire** : Actions mineures, texte souligné
- **Iconique** : Actions courantes, icône uniquement

#### États des Boutons

- **Normal** : Couleur de base
- **Hover** : Légèrement plus clair (+10% luminosité)
- **Pressed** : Légèrement plus foncé (-10% luminosité)
- **Disabled** : Opacité réduite (60%)
- **Focus** : Contour lumineux

```qml
// Exemple de bouton principal
PawButton {
    text: "Jouer"
    type: PawButton.Primary
    onClicked: startGame()
}

// Exemple de bouton secondaire
PawButton {
    text: "Options"
    type: PawButton.Secondary
    onClicked: openOptions()
}
```

### Cartes et Panneaux

- **Fond** : Crème (`#F2E8DC`)
- **Bordure** : Brun clair, arrondie (8px)
- **Ombre** : Subtile, offset-y positif
- **Espacement interne** : 16-24px
- **Contenu** : Aligné à gauche, espacement vertical cohérent

```qml
// Exemple de carte
Rectangle {
    color: "#F2E8DC"
    border.color: "#BE8E63"
    border.width: 2
    radius: 8
    
    // Ombre
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 0
        verticalOffset: 3
        radius: 8.0
        samples: 17
        color: "#20000000"
    }
    
    // Contenu
    padding: 16
    // ...
}
```

### Champs de Saisie

- **Hauteur** : 40-44px
- **Fond** : Blanc ou très léger gris
- **Bordure** : Fine, s'accentue au focus
- **Coins** : Légèrement arrondis (4-6px)
- **Placeholder** : Gris clair, italique
- **Texte** : Aligné à gauche, padding horizontal

```qml
// Exemple de champ de texte
TextField {
    placeholderText: "Nom du joueur"
    height: 42
    background: Rectangle {
        color: "#FFFFFF"
        border.color: parent.activeFocus ? "#E67E22" : "#BEBEBE"
        border.width: parent.activeFocus ? 2 : 1
        radius: 6
    }
}
```

### Dialogues et Popups

- **Overlay** : Noir semi-transparent (60-70%)
- **Animation** : Légère échelle + fondu à l'entrée/sortie
- **Position** : Centrée ou contextuelle
- **Disposition** : Titre, contenu, actions (alignées à droite)

```qml
// Exemple de popup
Popup {
    id: confirmDialog
    modal: true
    dim: true
    
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
        NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 200 }
    }
    
    background: Rectangle {
        color: "#F2E8DC"
        radius: 10
        border.color: "#BE8E63"
        border.width: 2
    }
    
    // Contenu...
}
```

### Icônes

- **Style** : Cohérent, légèrement arrondi, épuré
- **Taille** : Multiple de 8px (16px, 24px, 32px)
- **Couleur** : Adaptative au contexte
- **État** : Variation de couleur/opacité selon l'état

### Listes et Grilles

- **Séparateurs** : Fins, légère transparence
- **Alternance** : Légère variation de couleur (facultatif)
- **Sélection** : Surbrillance claire avec accent coloré
- **Espacement** : 8-12px entre les éléments

## 📏 Système de Grille et Espacement

### Grille de Base

- **Unité de base** : 8px
- **Colonnes** : 12 colonnes flexibles
- **Gouttières** : 16px ou 24px
- **Marges** : 16px (mobile), 24px (tablet), 32px+ (desktop)

### Espacement

- **Extra-petit** : 4px (demi-unité)
- **Petit** : 8px (une unité)
- **Moyen** : 16px (deux unités)
- **Grand** : 24px (trois unités)
- **Extra-grand** : 32px+ (quatre unités et plus)

## 🖼️ Iconographie et Illustrations

### Style d'Icônes

- **Style** : Simple, contours doux, thématique féline
- **Épaisseur de trait** : 2px cohérent
- **Coins** : Légèrement arrondis
- **Remplissage** : Minimal, accent par couleur

### Illustrations

- **Style** : Cartoon moderne, proportions légèrement exagérées
- **Palette** : Cohérente avec la palette UI principale
- **Détail** : Moyen, lisible à petite taille
- **Contexte** : Pertinentes au contexte, aidant à la compréhension

## 📱 Responsive Design

### Breakpoints

- **Mobile** : < 768px
- **Tablet** : 768px - 1023px
- **Desktop** : 1024px - 1439px
- **Large Desktop** : ≥ 1440px

### Adaptations Mobiles

- Boutons plus grands (min. 44px tactile)
- Navigation simplifiée (menu hamburger)
- Dispositions empilées au lieu de côte à côte
- Réduction des éléments décoratifs
- Focus sur le contenu principal

```qml
// Exemple d'adaptation responsive
RowLayout {
    // Desktop layout
    spacing: 16
    
    // Adaptation mobile
    orientation: window.width < 768 ? Qt.Vertical : Qt.Horizontal
    
    // Éléments...
}
```

## 🎬 Animations et Transitions

### Principes d'Animation

- **Subtil** : Les animations ne doivent pas distraire
- **Rapide** : 200-300ms pour les transitions UI standards
- **Cohérent** : Types d'animations similaires pour actions similaires
- **Significatif** : Renforce la compréhension de l'action

### Types d'Animations

- **Transition de page** : Fondu enchaîné ou slide horizontal
- **Apparition** : Scale + opacity (0.8 → 1.0, 0 → 1)
- **Sélection** : Léger rebond ou pulse
- **Erreur** : Secousse horizontale courte
- **Chargement** : Rotation d'une pelote de laine

```qml
// Exemple de transition
Behavior on opacity {
    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
}

// Exemple d'animation de chargement
RotationAnimation {
    target: loadingIcon
    from: 0
    to: 360
    duration: 1500
    loops: Animation.Infinite
    running: isLoading
}
```

## 🔄 État et Feedback

### Indicateurs d'État

- **Chargement** : Spinner en forme de pelote
- **Succès** : Vert + icône de patte
- **Erreur** : Rouge + icône d'alerte
- **Information** : Bleu + icône d'info
- **En attente** : Orange + icône d'horloge

### Feedback Utilisateur

- **Toast** : Messages temporaires non bloquants
- **Tooltip** : Information contextuelle au survol
- **Son** : Feedback audio subtil pour les actions importantes
- **Haptique** : Sur plateformes mobiles pour actions critiques

```qml
// Exemple de toast
MeowToast {
    message: "Sauvegarde réussie !"
    type: MeowToast.Success
    duration: 3000 // ms
}

// Exemple de tooltip
MeowTooltip {
    text: "Double-cliquez pour éditer"
    delay: 500 // ms
}
```

## 🧰 Composants QML Personnalisés

### Liste des Composants Partagés

- **PawButton** : Bouton stylisé en forme de patte
- **MeowInput** : Champ de saisie customisé
- **FurSlider** : Slider stylisé
- **CatDialog** : Popup avec animations félines
- **StarRating** : Système d'évaluation en pattes
- **ToggleSwitch** : Interrupteur à bascule chat/souris

### Utilisation et Personnalisation

```qml
// Import des composants
import "qrc:/qml/components"

// Utilisation
Column {
    spacing: 16
    
    PawButton {
        text: "Jouer"
        pawColor: "#E67E22"
        size: PawButton.Large
    }
    
    MeowInput {
        placeholderText: "Nom du chat"
        validator: RegExpValidator { regExp: /[a-zA-Z0-9 ]{3,15}/ }
    }
    
    FurSlider {
        from: 0
        to: 100
        stepSize: 1
        value: 50
        furColor: "#8E44AD"
    }
}
```

## 📋 Listes de Vérification

### Vérification de Design

- [ ] Palette de couleurs respectée
- [ ] Typographie conforme à la hiérarchie
- [ ] Espacement cohérent (multiples de 8px)
- [ ] Feedback visuel pour toutes les interactions
- [ ] Éléments d'interface suffisamment grands (cible min 44px)
- [ ] Contraste suffisant pour la lisibilité (WCAG AA)

### Vérification d'Implémentation QML

- [ ] Composants UI réutilisables
- [ ] Animations fluides (60fps)
- [ ] Responsive sur différentes tailles d'écran
- [ ] Comportement cohérent sur différents appareils
- [ ] Code bien structuré et commenté
- [ ] Performances optimisées (pas de binding loops)

## 🔗 Ressources et Outils

### Design

- Fichier Sketch/Figma des composants UI
- Bibliothèque d'icônes Meownopoly
- Palette de couleurs au format .aco/.ase

### Développement

- Documentation complète des composants personnalisés
- Exemples de code pour chaque pattern UI
- Style guides automatisés (si applicable)

---

Ce guide est en constante évolution. Consultez régulièrement la dernière version pour rester à jour avec les standards de design de Meownopoly. 🐾

