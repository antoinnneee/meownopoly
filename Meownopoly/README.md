# 🐱 Meownopoly

**Un jeu de société inspiré du Monopoly avec un thème félin adorable !**

## 🎯 Aperçu du Jeu

Meownopoly est une version modernisée et thématisée du classique Monopoly, où les joueurs incarnent des chats qui se disputent le contrôle de différentes propriétés et territoires. Le jeu introduit des mécaniques innovantes comme les copropriétés, les enchères anonymes et des phases de jeu structurées.

## 🏠 Types de Cases et Propriétés

### 🏢 Copropriétés
- **Achetables en quantité de parts restreinte**
- Plusieurs joueurs peuvent posséder des parts d'une même propriété
- Les propriétaires doivent payer une location
- Les bénéfices sont distribués selon le pourcentage de parts possédées

### 🚧 Péages
- **Positionnés à mi-parcours**
- Achetables par un seul joueur
- Génèrent un loyer obligatoire même en cas de simple survol
- Les joueurs qui s'arrêtent dessus **passent 1 tour**

### 🎲 Cases Événements
- Événements aléatoires déclenchés lors du passage
- Effets variés sur le gameplay

## 🎮 Phases de Jeu

### 🚀 Phase de Début (Phase d'Initialisation)
**Durée :** `(nombre de joueurs - 1)` tours

1. **Enchères Anonymes :**
   - Chaque joueur mise secrètement sur sa somme de départ
   - À chaque tour, l'enchère la plus **basse** est révélée à tous
   - Ce processus se répète jusqu'à la fin de la phase

2. **Premier Lancement :**
   - Le premier joueur lance les dés
   - Le processus se répète pour tous les joueurs

### 🎯 Déroulement d'un Tour

Chaque tour se compose de **4 phases distinctes** :

#### 1️⃣ Phase d'Action (Pré-déplacement)
- Invitation possible aux autres joueurs pour échanges/enchères
- Utilisation d'objets et capacités spéciales
- Achat-vente entre joueurs (hypothèques)
- Construction ou vente de maisons/hôtels

#### 2️⃣ Phase de Déplacement
- **Lancer de dés** pour le déplacement principal
- **Option de relance :** À la fin, possibilité de relancer les dés à un prix **exponentiel**
- **Objets éphémères :** Utilisation d'objets de déplacement spéciaux

#### 3️⃣ Phase d'Action (Post-déplacement)
- Même mécaniques que la phase d'action pré-déplacement
- Actions basées sur la case d'arrivée

#### 4️⃣ Phase d'Attente
- **Réception des loyers** des propriétés possédées
- Possibilité de lancer des **objets éphémères**
- **Participation aux enchères** initiées par d'autres joueurs

## 🎭 Système de Personnages

### Modificateurs de Dés
- Chaque personnage possède des capacités uniques
- Influence sur les phases de jeu en cours
- Modificateurs spéciaux selon le personnage choisi

## 🏗️ Fonctionnalités Techniques

### Technologies Utilisées
- **Qt/QML** pour l'interface utilisateur
- **C++** pour la logique de jeu
- **JSON** pour la configuration des cases
- **CSV** pour les données de propriétés

### Structure du Projet
```
Meownopoly/
├── case/              # Classes des différents types de cases
├── qml/               # Interface utilisateur QML
├── config/            # Fichiers de configuration
├── asset/             # Ressources graphiques
└── tools/             # Outils de développement
```

## 🎨 Assets et Thème

Le jeu comprend des assets visuels sur le thème félin :
- **Avatars de chats** (6 différents)
- **Éléments de jeu :** dés, prison, aires de repos
- **Objets thématiques :** distributeur de croquettes, herbe à chat, porte à chat
- **Interface moderne** avec des éléments UI adaptés au thème

## 🚀 Installation et Lancement

### Prérequis
- Qt 5.x ou supérieur
- Compilateur C++ compatible
- Make

### Compilation
```bash
qmake Meownopoly.pro
make
```

### Lancement
```bash
./Meownopoly
```

## 🎲 Règles Spéciales

- **Système d'enchères innovant** avec révélation progressive
- **Mécaniques de copropriété** permettant la possession partagée
- **Phases structurées** offrant plus de stratégie
- **Objets éphémères** pour des actions temporaires
- **Prix exponentiel** pour les relances de dés

## 🏆 Objectif du Jeu

Comme dans le Monopoly traditionnel, l'objectif est de devenir le joueur le plus riche en achetant, développant et louant des propriétés, tout en évitant la faillite.

## 👥 Nombre de Joueurs

Le jeu supporte plusieurs joueurs (minimum 2), avec des mécaniques qui s'adaptent au nombre de participants.

---

**Amusez-vous bien dans Meownopoly ! 🐾** 