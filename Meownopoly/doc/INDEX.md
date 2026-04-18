# 📚 Documentation Meownopoly

Bienvenue dans la documentation du projet Meownopoly ! Ce document sert d'index pour vous aider à naviguer facilement à travers toute la documentation disponible.

## 📖 Documentation Générale

- [README](./README.md) - Aperçu général du projet et du jeu
- [🚀 QUICK_START](./QUICK_START.md) - **Guide de démarrage rapide** (Nouveau !)
- [📁 STRUCTURE_DOCUMENTATION](./STRUCTURE_DOCUMENTATION.md) - Organisation complète de la documentation

---

## 🏗️ Architecture ([/architecture](./architecture/))

Documentation technique sur l'architecture du système et les composants.

### Architecture Générale
- [Structure du Projet](./architecture/PROJECT_STRUCTURE.md) - Organisation des fichiers et architecture globale
- [Architecture du Launcher](./architecture/LAUNCHER_ARCHITECTURE.md) - Pattern singleton et structure

### Architecture de l'Éditeur ⭐ **NOUVEAU**
- [📖 Analyse Complète](./architecture/ANALYSE_ARCHITECTURE_EDITEUR.md) - Analyse détaillée de l'éditeur (12 sections)
- [📋 Résumé](./architecture/RESUME_ARCHITECTURE_EDITEUR.md) - Vue d'ensemble rapide avec points clés
- [📊 Diagrammes](./architecture/DIAGRAMMES_ARCHITECTURE_EDITEUR.md) - Diagrammes visuels ASCII

### Systèmes
- [Gestionnaire d'Assets](./architecture/ASSET_MANAGER.md) - Système de gestion des ressources
- [Système d'Effets Visuels](./architecture/VISUAL_EFFECTS_SYSTEM.md) - Effets post-processing
- [Moteur Physique PattounX](./architecture/PHYSICS_ENGINE.md) - Documentation du moteur de collisions 2D PattounX

---

## 📘 Guides ([/guides](./guides/))

Guides pratiques pour les utilisateurs et développeurs.

### Pour les Utilisateurs
- [Guide de Gameplay](./guides/GAMEPLAY_GUIDE.md) - Règles et mécaniques de jeu
- [Guide de l'Éditeur de Maps](./guides/MAP_EDITOR_GUIDE.md) - Création de plateaux personnalisés


## 🎨 Design & UI ([/design](./design/))

Documentation sur le design et l'interface utilisateur.

- [Guide de Style UI](./design/UI_STYLE_GUIDE.md) - Standards d'interface utilisateur
- [Héritage QML](./design/INHERITANCE_QML.md) - Utilisation de l'héritage en QML

---

## ✨ Fonctionnalités ([/features](./features/))

Documentation sur les fonctionnalités spécifiques.

- [Support du Curseur Asset Preview](./features/ASSET_PREVIEW_CURSOR_CASE_SUPPORT.md) - Prévisualisation des cases
- [Serveur de Ressources](./features/SERVEUR_RESSOURCES.md) - Implémentation du serveur

## 📁 Documentation Externe

- [Documentation Qt](https://doc.qt.io/) - Documentation officielle Qt
- [Documentation QML](https://doc.qt.io/qt-6/qmlapplications.html) - Guide QML
- [Documentation C++](https://en.cppreference.com/) - Référence C++

## 🔍 Recherche par Sujet

### 🆕 Pour Comprendre l'Éditeur de Maps
> Documentation complète sur l'architecture de l'éditeur
- [📖 Analyse Complète de l'Éditeur](./architecture/ANALYSE_ARCHITECTURE_EDITEUR.md) - **Commencez ici pour tout comprendre**
- [📋 Résumé Rapide](./architecture/RESUME_ARCHITECTURE_EDITEUR.md) - Vue d'ensemble condensée
- [📊 Diagrammes Visuels](./architecture/DIAGRAMMES_ARCHITECTURE_EDITEUR.md) - Flux et schémas

### 👤 Pour les Nouveaux Utilisateurs
- [README](./README.md)
- [Guide de Gameplay](./guides/GAMEPLAY_GUIDE.md)

### 🎨 Pour les Créateurs de Contenu
- [Guide de l'Éditeur de Maps](./guides/MAP_EDITOR_GUIDE.md)
- [Gestionnaire d'Assets](./architecture/ASSET_MANAGER.md)
- [Support du Curseur Asset Preview](./features/ASSET_PREVIEW_CURSOR_CASE_SUPPORT.md)

### 👨‍💻 Pour les Nouveaux Développeurs
- [Structure du Projet](./architecture/PROJECT_STRUCTURE.md)
- [Guide du Développeur](./guides/DEVELOPER_GUIDE.md)
- [Directives de Contribution](./guides/CONTRIBUTION_GUIDELINES.md)

### 🔬 Pour les Experts Techniques
- [Architecture de l'Éditeur - Analyse Complète](./architecture/ANALYSE_ARCHITECTURE_EDITEUR.md) ⭐
- [Architecture du Launcher](./architecture/LAUNCHER_ARCHITECTURE.md)
- [Système d'Effets Visuels](./architecture/VISUAL_EFFECTS_SYSTEM.md)
- [Serveur de Ressources](./features/SERVEUR_RESSOURCES.md)

### 🎨 Pour les Designers UI/UX
- [Guide de Style UI](./design/UI_STYLE_GUIDE.md)
- [Héritage QML](./design/INHERITANCE_QML.md)

## 📅 Historique des Mises à Jour

| Date | Document | Modification |
|------|----------|--------------|
| 2026-04-10 | Architecture/Launcher | Ajout queue, retry, checksum, timeout, modèles 3D, auth |
| 2026-04-10 | Architecture/Asset Manager | Ajout section modèles 3D |
| 2026-04-10 | Features/Serveur Ressources | Routes modèles 3D, sécurité, Range, async I/O |
| 2025-10-12 | INDEX | Réorganisation avec sous-dossiers (architecture/, guides/, design/, features/) |
| 2025-10-12 | Architecture/Éditeur | Création de 3 documents sur l'architecture de l'éditeur |
| 2025-10-12 | Tous | Déplacement des fichiers dans la nouvelle structure |
| 2025-09-30 | Tous | Création initiale de la documentation complète |
| 2025-09-30 | README | Mise à jour et amélioration de la structure |
| 2025-09-30 | UI_STYLE_GUIDE | Création du guide de style UI |

---

Si vous ne trouvez pas l'information que vous cherchez, n'hésitez pas à :
- Consulter les commentaires dans le code source
- Vérifier les fichiers de test dans `qml/test/`
- Poser vos questions dans la section Issues du dépôt GitHub
- Contacter l'équipe de développement via Discord

Bonne exploration de Meownopoly ! 🐾










