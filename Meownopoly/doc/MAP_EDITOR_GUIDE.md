# 🗺️ Guide de l'Éditeur de Maps Meownopoly

Ce guide explique comment utiliser l'éditeur de maps intégré à Meownopoly pour créer et modifier des plateaux de jeu personnalisés.

## Aperçu

L'éditeur de maps de Meownopoly vous permet de :
- Créer des plateaux de jeu personnalisés
- Placer différents types de cases (propriétés, chances, etc.)
- Ajouter des décorations (arbres, herbe, etc.)
- Sauvegarder et charger des cartes
- Tester vos créations

## Interface de l'Éditeur

![Interface de l'Éditeur](../build/asset_extracted/ui/editor_interface.png)

L'interface de l'éditeur est divisée en plusieurs zones :

1. **Zone de travail** - Espace central où vous construisez votre plateau de jeu
2. **Panneau de sélection** - Panneau latéral pour choisir les éléments à placer
3. **Barre d'outils** - Outils de manipulation (sélection, rotation, etc.)
4. **Menu d'information** - Affiche les détails de l'élément sélectionné
5. **Barre de statut** - Informations générales et messages système

## Commencer avec l'Éditeur

### Création d'une nouvelle carte

1. Lancez l'application Meownopoly
2. Sélectionnez "Éditeur" dans le menu principal
3. Dans l'éditeur, cliquez sur "Fichier" > "Nouvelle carte"
4. Définissez les paramètres de base :
   - Nom de la carte
   - Dimensions (largeur x hauteur)
   - Type de fond

### Navigation dans l'éditeur

- **Zoom** : Molette de la souris ou pincement sur trackpad
- **Déplacement** : Clic-droit maintenu + déplacement
- **Rotation de la vue** : Touche Alt + déplacement de la souris
- **Grille** : Activez/désactivez avec G ou via le menu "Affichage"

## Placement des Cases

### Types de cases disponibles

| Type | Description |
|------|-------------|
| Départ | Case de départ (Distributeur de Croquettes) |
| Propriété | Cases achetables (Aires de repos) |
| Chance | Cases Herbe à Chat (événements aléatoires) |
| Caisse de Comm. | Cases Carton (événements communautaires) |
| Prison | Case Prison |
| Allez en Prison | Envoie le joueur en prison |
| Porte à Chat | Équivalent des gares |
| Free Nap | Parking gratuit |
| Appareil | Services publics |
| Taxe | Cases de taxe |

### Placement d'une case

1. Sélectionnez le type de case dans le panneau latéral
2. Un aperçu apparaît sous votre curseur
3. Cliquez sur la grille pour placer la case
4. Utilisez le panneau d'information pour configurer la case :
   - Nom
   - Prix (pour les propriétés)
   - Groupe de couleur
   - Loyers

### Création d'un chemin

Les cases doivent former un chemin continu pour le plateau de jeu :

1. Placez la case de départ
2. Placez les cases adjacentes pour former le chemin
3. L'éditeur indiquera visuellement les connexions entre les cases
4. Vous pouvez visualiser l'ordre du parcours avec le bouton "Afficher chemin"

## Ajout de Décorations

### Types de décorations

Les décorations sont organisées en catégories :
- **Arbres** : Différentes variétés d'arbres
- **Herbe** : Textures d'herbe et de pelouse
- **Eau** : Lacs, rivières, étangs
- **Mobilier** : Bancs, lampadaires, etc.
- **Objets thématiques** : Éléments félins

### Placement des décorations

1. Sélectionnez la catégorie dans le panneau "Décorations"
2. Choisissez un élément spécifique
3. Placez-le sur la carte en cliquant
4. Utilisez les contrôles pour :
   - Rotation (R ou bouton de rotation)
   - Redimensionnement (Shift + molette)
   - Ajustement de la hauteur (Alt + molette)

### Personnalisation des décorations

Le panneau d'effets visuels vous permet de modifier l'apparence des décorations :
- **Luminosité** : Éclaircir ou assombrir
- **Contraste** : Augmenter ou diminuer le contraste
- **Saturation** : Modifier l'intensité des couleurs
- **Colorisation** : Appliquer une teinte colorée
- **Effets avancés** : Flou, ombre, etc.

## Édition et Organisation

### Sélection et manipulation

- **Sélection simple** : Clic sur un élément
- **Sélection multiple** : Shift + clic ou rectangle de sélection
- **Déplacement** : Glisser-déposer les éléments sélectionnés
- **Copier/Coller** : Ctrl+C / Ctrl+V
- **Suppression** : Touche Delete ou backspace

### Organisation des éléments

- **Calques** : Utilisez le gestionnaire de calques pour organiser les éléments
- **Ordre Z** : Modifiez l'ordre d'empilement avec les boutons "Avant-plan" et "Arrière-plan"
- **Groupement** : Sélectionnez plusieurs éléments et utilisez Ctrl+G pour les grouper

## Propriétés de la Carte

### Configuration générale

Accédez aux propriétés via "Fichier" > "Propriétés de la carte" :
- **Nom de la carte**
- **Auteur**
- **Description**
- **Image de miniature**
- **Tags et catégories**

### Configuration du jeu

- **Nombre de joueurs** : Min/Max supportés
- **Règles spéciales** : Activez/désactivez des mécaniques spécifiques
- **Difficulté** : Définissez le niveau de difficulté

## Sauvegarde et Chargement

### Sauvegarde de la carte

1. "Fichier" > "Sauvegarder" ou Ctrl+S
2. Choisissez un emplacement (par défaut : dossier `map/`)
3. La carte est sauvegardée au format JSON avec extension `.json`

### Chargement d'une carte

1. "Fichier" > "Ouvrir" ou Ctrl+O
2. Sélectionnez un fichier de carte `.json`
3. L'éditeur charge tous les éléments et propriétés

## Test de la Carte

### Prévisualisation

- Utilisez le bouton "Prévisualiser" pour voir la carte en mode jeu
- Testez le parcours avec le bouton "Simuler Parcours"
- Vérifiez la validité avec "Analyser Carte"

### Mode Test Rapide

1. Cliquez sur "Tester la carte"
2. Définissez le nombre de joueurs IA
3. Observez le déroulement d'une partie simulée
4. Utilisez les contrôles pour accélérer/ralentir la simulation

## Partage de Cartes

### Export et Import

- **Export** : "Fichier" > "Exporter" pour créer un fichier `.meowmap` portable
- **Import** : "Fichier" > "Importer" pour charger un fichier `.meowmap`

### Publication

Utilisez le launcher pour :
1. Téléverser votre carte sur le serveur de ressources
2. Renseigner les métadonnées (description, captures d'écran)
3. Publier la carte pour qu'elle soit disponible aux autres joueurs

## Raccourcis Clavier

| Touche | Action |
|--------|--------|
| Ctrl+N | Nouvelle carte |
| Ctrl+O | Ouvrir une carte |
| Ctrl+S | Sauvegarder |
| Ctrl+Shift+S | Sauvegarder sous |
| Ctrl+Z | Annuler |
| Ctrl+Y | Refaire |
| Ctrl+C | Copier |
| Ctrl+V | Coller |
| Delete | Supprimer la sélection |
| F | Centrer sur la sélection |
| G | Afficher/masquer la grille |
| R | Rotation de l'élément |
| Alt+R | Réinitialiser la rotation |
| Esc | Annuler l'action en cours |

## Astuces et Bonnes Pratiques

### Optimisation des performances

- Limitez le nombre de décorations avec effets avancés
- Utilisez les groupes pour manipuler des ensembles d'éléments
- Évitez de superposer trop d'éléments transparents

### Design équilibré

- Créez un parcours bien proportionné
- Distribuez équitablement les types de cases
- Équilibrez les groupes de propriétés
- Utilisez les décorations pour guider visuellement les joueurs

### Accessibilité

- Utilisez des contrastes suffisants
- Évitez les combinaisons de couleurs difficiles à distinguer
- Prévoyez suffisamment d'espace entre les éléments
- Testez la lisibilité à différents niveaux de zoom

## Dépannage

### Problèmes courants

- **Cases non connectées** : Vérifiez l'alignement sur la grille
- **Sauvegarde échouée** : Vérifiez les permissions du dossier
- **Lenteur de l'éditeur** : Réduisez le nombre d'effets visuels
- **Éléments invisibles** : Vérifiez l'ordre des calques

### Support et aide

Si vous rencontrez des problèmes :
- Consultez le log de l'application (accessible via "Aide" > "Afficher les logs")
- Vérifiez la documentation à jour sur le site officiel
- Posez vos questions sur le forum ou le Discord de la communauté

---

Amusez-vous à créer des cartes uniques pour Meownopoly ! 🐾

