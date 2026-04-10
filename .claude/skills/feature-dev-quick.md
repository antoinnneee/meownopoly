---
name: feature-dev-quick
description: Develop a feature with automatic model selection based on complexity. Triggers when the user asks to implement, add, create, or develop a new feature or modification in the codebase.
user-invocable: true
argument-hint: [description de la feature]
---

# Feature Dev Quick

Tu dois developper la feature suivante : $ARGUMENTS

## Etape 1 : Evaluation de la complexite

Avant de coder, analyse la demande et classe-la dans un de ces 3 niveaux :

### Niveau 1 - SIMPLE (haiku)
Changement de valeur, renommage, modification d'une constante, ajustement de style QML, changement de texte/label, modification d'un parametre numerique.
- Critere : moins de ~10 lignes modifiees, aucune logique nouvelle, aucun nouveau fichier.

### Niveau 2 - MOYEN (sonnet)
Feature simple avec logique claire : ajout d'un bouton avec handler, nouvelle propriete QML avec binding, nouveau signal/slot simple, modification d'une fonction existante, ajout d'un champ dans un modele existant.
- Critere : logique straightforward, 1-3 fichiers touches, pattern deja existant dans le code.

### Niveau 3 - COMPLEXE (opus)
Feature impliquant de la conception : nouveau systeme, interactions multi-composants, modification d'architecture, networking, nouveau type de Case, integration physique, logique de jeu complexe.
- Critere : necessite de comprendre l'architecture, 4+ fichiers, nouveaux patterns.

## Etape 2 : Delegation au bon modele

Annonce le niveau choisi et la justification en une ligne, puis delegue IMMEDIATEMENT le travail avec l'outil Agent en utilisant le parametre `model` :

- Niveau 1 : `model: "haiku"`
- Niveau 2 : `model: "sonnet"`
- Niveau 3 : `model: "opus"`

Dans le prompt de l'Agent, inclus :
1. La description complete de la feature a implementer
2. Les fichiers pertinents identifies
3. Les conventions du projet (voir CLAUDE.md)
4. L'instruction de respecter les conventions QML et C++ du projet

## Etape 3 : Validation

Une fois l'agent termine, verifie le resultat :
- Le code compile-t-il ? (utilise /build si disponible)
- Les conventions sont-elles respectees ?
- Signale tout probleme a l'utilisateur
