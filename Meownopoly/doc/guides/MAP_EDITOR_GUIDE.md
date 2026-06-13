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
3. L'éditeur s'ouvre directement sur une carte vierge, prête à être éditée
4. Sélectionnez les éléments à placer depuis le panneau de sélection latéral et construisez votre plateau directement dans la zone de travail

> L'éditeur ne possède pas de barre de menus. Toutes les actions liées au fichier (charger une carte, régler la sauvegarde) passent par le **menu d'échappement**, ouvert avec la touche **Esc**.

### Navigation dans l'éditeur

- **Zoom** : Ctrl + molette de la souris
- **Déplacement** : Clic-droit maintenu + déplacement
- **Rotation de la vue** : Touche Alt + déplacement de la souris

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

### Configuration du roster de joueurs

Le panneau de sélection comporte un onglet "Joueurs" qui permet de configurer le roster embarqué dans la carte :

- **Nombre de joueurs** : bornes min/max supportées (indicatives, sans contrôle bloquant)
- **Profils de joueurs** : liste de profils configurables (nom, modèle, mode de sélection, paramètres physiques)

Ces réglages sont enregistrés directement dans le fichier de la carte. Il n'existe pas de fenêtre "Propriétés de la carte" séparée.

## Sauvegarde et Chargement

### Sauvegarde de la carte

La sauvegarde n'est pas déclenchée par une action de menu mais pilotée par une **politique** réglable dans le menu d'échappement (Esc) > **Paramètres**, via la liste déroulante du mode de sauvegarde :

- **Manuelle**
- **Intervalle de temps** (sauvegarde périodique)
- **Sur modification** (sauvegarde après chaque changement)

Les cartes sont stockées au format JSON dans le dossier `map/`. Le fichier cible est `<nom>_map.json` pour une carte personnalisée (ou `autosave_tmp.json` pour la carte d'autosave).

### Chargement d'une carte

1. Ouvrez le menu d'échappement avec **Esc**
2. Cliquez sur **"Charger carte"**
3. Sélectionnez une carte ; l'éditeur charge tous ses éléments et propriétés

## Test de la Carte

> Les outils de test automatisé (prévisualisation en mode jeu, simulation de parcours, analyse de validité, partie simulée avec joueurs IA) ne sont **pas encore implémentés**.

Le seul moyen de tester une carte est le **pilotage de l'acteur physique 3D** : déplacez l'acteur sur le plateau au clavier (WASD) et basculez en caméra libre pour explorer la carte (cf. `InputController` / `CameraRig` de la présentation 3D).

## Partage de Cartes

### Format de fichier

Les cartes sont enregistrées et chargées sous forme de fichiers **JSON** (`<nom>_map.json`) dans le dossier `map/`. Il n'existe pas de format `.meowmap` ni d'action de menu d'export/import distincte : le fichier JSON de la carte est lui-même le format portable.

### Publication

Utilisez le launcher pour :
1. Téléverser votre carte sur le serveur de ressources
2. Renseigner les métadonnées (description, captures d'écran)
3. Publier la carte pour qu'elle soit disponible aux autres joueurs

## Raccourcis Clavier

| Touche | Action |
|--------|--------|
| Ctrl+Z | Aperçu / élément précédent (`Game.askPreview`) |
| Ctrl+Y | Élément suivant (`Game.askNext`) |
| Delete | Supprimer la sélection |
| Esc | Annuler l'action en cours / ouvrir le menu d'échappement |

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
- Consultez la sortie console / les logs de l'application (l'éditeur n'embarque pas de visionneuse de logs intégrée)
- Vérifiez la documentation à jour sur le site officiel
- Posez vos questions sur le forum ou le Discord de la communauté

---

Amusez-vous à créer des cartes uniques pour Meownopoly ! 🐾

