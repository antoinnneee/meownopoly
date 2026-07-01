# 📚 Documentation Meownopoly

Bienvenue dans la documentation du projet Meownopoly ! Ce document sert d'index pour vous aider à naviguer facilement à travers toute la documentation disponible.

## 📖 Documentation Générale

- [README](./README.md) - Aperçu général du projet et du jeu
- [🚀 QUICK_START](./QUICK_START.md) - **Guide de démarrage rapide** (Nouveau !)
- [📁 STRUCTURE_DOCUMENTATION](./STRUCTURE_DOCUMENTATION.md) - Organisation complète de la documentation
- [🗂️ FILE_INDEX](./FILE_INDEX.md) - **Index fichier par fichier** de tout le dépôt (cpp/qml/serveurs/scripts) avec description, pour retrouver vite le bon fichier

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
- [🗺️ Cycle de vie de currentMap](./architecture/MAP_LIFECYCLE.md) - Variables centrales, interactions utilisateur, scénarios état/effets de bord, plan de tests
- [🌐 Éditeur Collaboratif](./architecture/COLLABORATIVE_EDITOR.md) - Stack réseau collab, op bus, host migration, stats transmission
- [🧩 Pattern Session Collab](./architecture/COLLAB_SESSION_PATTERN.md) - Pattern générique host-authoritative pour réimplémenter dans d'autres modes

### Réseau
- [🔭 Patterns réseau (synthèse)](./architecture/NETWORK_PATTERNS.md) - Vue d'ensemble + raisons des choix de techno (UDP/reliable.io, host-authoritative, host migration, chat E2E, triple buffer)
- [Architecture Catway](./architecture/CATWAY_ARCHITECTURE.md) - Threading, I/O, reliable.io
- [Réseau P2P](./architecture/P2P_NETWORK_ARCHITECTURE.md) - UDP hole-punching, signaling, reliable

### Performance & Rendu
- [⚡ Rendu & Performance](./architecture/RENDERING_PERF.md) - Récap des passes d'optim (grille, zones, hachures, drag/zoom, triple buffer physique) avec raisons techno

### Systèmes
- [Gestionnaire d'Assets](./architecture/ASSET_MANAGER.md) - Système de gestion des ressources
- [🎨 Color ID Map — Plan d'intégration](./architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md) - Re-skinning runtime par zone (teinte/texture + variantes + teinte d'équipe) — **implémentation démarrée (Phase A)**
- [Système d'Effets Visuels](./architecture/VISUAL_EFFECTS_SYSTEM.md) - Effets post-processing
- [Moteur Physique Pattounx v2](./architecture/PHYSICS_ENGINE_V2.md) - Doc fonctionnelle actuelle (post-refactor : thread dédié, multi-actors, body-body, sync live)
- [Plan refactor physique](./architecture/PHYSICS_REFACTOR_PLAN.md) - Décisions, phases, roadmap (référence historique)
- [Moteur Physique V1 (legacy)](./architecture/PHYSICS_ENGINE.md) - Doc V1, conservée pour archive — contient des erreurs (cf. §10.4 du plan refactor)

---

## 📘 Guides ([/guides](./guides/))

Guides pratiques pour les utilisateurs et développeurs.

### Pour les Utilisateurs
- [Guide de Gameplay](./guides/GAMEPLAY_GUIDE.md) - Règles et mécaniques de jeu
- [Guide de l'Éditeur de Maps](./guides/MAP_EDITOR_GUIDE.md) - Création de plateaux personnalisés


## 🎨 Design & UI ([/design](./design/))

Documentation sur le design et l'interface utilisateur.

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
- [🚀 QUICK_START](./QUICK_START.md)
- [Structure du Projet](./architecture/PROJECT_STRUCTURE.md)

### 🔬 Pour les Experts Techniques
- [Architecture de l'Éditeur - Analyse Complète](./architecture/ANALYSE_ARCHITECTURE_EDITEUR.md) ⭐
- [Architecture du Launcher](./architecture/LAUNCHER_ARCHITECTURE.md)
- [Système d'Effets Visuels](./architecture/VISUAL_EFFECTS_SYSTEM.md)
- [Serveur de Ressources](./features/SERVEUR_RESSOURCES.md)

### 🎨 Pour les Designers UI/UX
- [Héritage QML](./design/INHERITANCE_QML.md)

## 📅 Historique des Mises à Jour

| Date | Document | Modification |
|------|----------|--------------|
| 2026-06-05 | Architecture/Color ID Map | Nouveau : plan d'intégration du re-skinning runtime par zone (Color ID Map ArmorPaint) |
| 2026-04-18 | Architecture/Collab Editor | Nouveau : stack collaborative (EditorSession, EditorOpBus, host migration, stats reliable.io) |
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










