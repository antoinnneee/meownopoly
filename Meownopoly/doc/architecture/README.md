# 🏗️ Documentation Architecture

Ce dossier contient toute la documentation technique sur l'architecture du projet Meownopoly.

## 📚 Contenu

### Architecture Générale
- **[PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)** - Organisation complète des fichiers et dossiers du projet
- **[LAUNCHER_ARCHITECTURE.md](./LAUNCHER_ARCHITECTURE.md)** - Architecture du système de lancement (pattern singleton)

### 🆕 Architecture de l'Éditeur de Maps ⭐
Documentation complète sur l'architecture de l'éditeur de cartes :

1. **[ANALYSE_ARCHITECTURE_EDITEUR.md](./ANALYSE_ARCHITECTURE_EDITEUR.md)** - **Document principal**
   - Analyse détaillée en 13 sections (~870 lignes)
   - Explications approfondies de chaque mécanisme
   - Parfait pour comprendre en profondeur le fonctionnement

2. **[RESUME_ARCHITECTURE_EDITEUR.md](./RESUME_ARCHITECTURE_EDITEUR.md)** - **Résumé concis**
   - Vue d'ensemble rapide avec points clés
   - Idéal pour une référence rapide
   - Contient les concepts essentiels

3. **[DIAGRAMMES_ARCHITECTURE_EDITEUR.md](./DIAGRAMMES_ARCHITECTURE_EDITEUR.md)** - **Diagrammes visuels**
   - Diagrammes ASCII détaillés
   - Flux de données et cycles de vie
   - Parfait pour la compréhension visuelle

**Sujets couverts** :
- ✅ Génération et fonctionnement de la grille
- ✅ Système "snapable" (accrochage à la grille)
- ✅ Mécanisme de zoom (sans perte de qualité)
- ✅ Gestion des liens entre cases (connexions)
- ✅ Sélection par rectangle (AABB)
- ✅ Modes de souris (State Machine)
- ✅ Architecture des panneaux (SelectionPanel)
- ✅ Z-Order et gestion des calques
- ✅ Optimisations et performances

### Systèmes Spécialisés
- **[ASSET_MANAGER.md](./ASSET_MANAGER.md)** - Système de gestion des ressources (images, sons, assets)
- **[VISUAL_EFFECTS_SYSTEM.md](./VISUAL_EFFECTS_SYSTEM.md)** - Système d'effets visuels et post-processing
- **[PHYSICS_ENGINE_V2.md](./PHYSICS_ENGINE_V2.md)** - Moteur physique 2D Pattounx v2 (référence actuelle)
- [PHYSICS_ENGINE.md](./PHYSICS_ENGINE.md) - ⚠️ Archive V1 legacy (obsolète, contient des erreurs)

## 🎯 Par Où Commencer ?

### Je veux comprendre l'éditeur de maps
→ Lisez dans cet ordre :
1. [RESUME_ARCHITECTURE_EDITEUR.md](./RESUME_ARCHITECTURE_EDITEUR.md) - Vue d'ensemble (15 min)
2. [DIAGRAMMES_ARCHITECTURE_EDITEUR.md](./DIAGRAMMES_ARCHITECTURE_EDITEUR.md) - Visualisation (10 min)
3. [ANALYSE_ARCHITECTURE_EDITEUR.md](./ANALYSE_ARCHITECTURE_EDITEUR.md) - Approfondissement (45 min)

### Je veux comprendre l'architecture globale
→ [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)

### Je développe une nouvelle fonctionnalité
→ Consultez les documents spécifiques au système concerné

## 🔗 Liens Utiles

- [Retour à l'index principal](../INDEX.md)
- [Guides développeur](../guides/)
- [Documentation design](../design/)

---

**Dernière mise à jour** : 12 octobre 2025



