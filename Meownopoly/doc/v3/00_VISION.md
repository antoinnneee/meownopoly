# 00 — Vision V3

> **Statut : cadrage (draft).**

## 1. Point de départ

Meownopoly V2 est un jeu de plateau en réseau (Qt6/QML + C++20) avec un éditeur
de map riche, un moteur physique maison (Pattounx v2), du P2P UDP et un éditeur
collaboratif host-authoritative. Le contenu d'une partie est produit par des
humains via l'UI de l'éditeur.

Le projet dispose déjà d'un fait technique décisif : **une couche d'automation**
(`AutomationServer` + hooks `editorAutomationHooks` + MCP `automation_mcp/`) qui
prouve qu'un agent externe peut piloter le jeu par WebSocket JSON — poser des
éléments, bouger la caméra, sauvegarder — **par le chemin UI exact**, donc
compatible collab/undo.

## 2. La bascule V3

V3 fait passer l'IA de **outil de développement** à **acteur de jeu de premier
plan**. Le contenu et une partie des règles ne sont plus seulement produits par
des humains dans une UI, mais **négociés en langage naturel entre un joueur et
son IA**, qui matérialise le résultat en direct dans le jeu.

Trois idées portent le pivot :

1. **« Son IA » — modèle fourni côté client.** Chaque joueur branche son propre
   modèle (Claude, un agent local, etc.). Le jeu ne fournit pas l'IA ; il fournit
   le **point d'entrée** (canal WebSocket local) et le **mode d'emploi** (fichier
   de skill livré à l'installation). L'intelligence vit côté client ; le jeu
   expose une surface d'interaction et des garde-fous.

2. **Le QML interprété comme substrat vivant.** Contrairement au C++ compilé, le
   QML est chargé et interprété au runtime. C'est ce qui rend crédible l'idée
   d'**ajouter des éléments et des comportements « à la volée »** pendant une
   session, sans recompiler ni redéployer. L'IA ne se limite pas à assembler des
   briques figées : elle **produit du QML** que le jeu charge en direct
   (décision **D1**, cf. doc 04).

3. **Liberté par joueur, partie sur-mesure.** L'objectif final est que chaque
   joueur, à travers son IA, puisse **construire une partie selon ses propres
   règles** : ajouter des éléments, leur donner des comportements, et à terme
   redéfinir des règles de jeu. Le jeu devient moins « un plateau figé » et plus
   « un bac à sable négociable ».

## 3. Boucle d'usage cible

```
Joueur ──(langage naturel)──▶ Son IA ──(WebSocket local dédié)──▶ Meownopoly
   ▲                                                                  │
   └──────────────── observe le résultat en jeu / itère ◀────────────┘
```

Exemple concret visé (éditeur) :
> « Mets une rivière qui traverse la carte du nord au sud, avec un pont au
> centre, et fais que les cases au bord de l'eau rapportent double loyer. »

L'IA traduit cette intention en une séquence d'actions sur le canal : poser des
zones/décorations, lier des cases, écrire l'espace mémoire des cases concernées
(« bonus loyer ×2 »), et — pour ce qui n'existe pas encore comme primitive —
générer du QML de comportement chargé à la volée.

## 4. Principes directeurs

- **Le jeu expose des capacités, pas des écrans.** L'IA agit via un contrat de
  capacités stable (canal WS + skill), pas en simulant des clics fragiles.
- **Le chemin UI reste la source de vérité.** Comme les hooks d'automation
  actuels, les actions IA passent par les mêmes pipelines que l'humain
  (`Game.updateMap`, `EditorOpBus`) → gratuitement compatibles undo, collab,
  persistance.
- **Liberté bornée par des garde-fous non-négociables.** « Grande liberté » ne
  veut pas dire « exécution arbitraire non contrôlée ». Le QML génératif impose
  un **sandbox** (doc 04) ; les règles custom imp, à terme, un **contrat**
  (doc 06). La liberté vit *au-dessus* d'invariants que l'IA ne peut pas violer.
- **Local d'abord.** Le canal d'interaction est **local à la machine** (loopback).
  Il n'est qu'un point de contact jeu↔IA-du-joueur, pas un service exposé.
- **Déterminisme réseau préservé.** L'ajout de contenu IA doit rester compatible
  avec le modèle host-authoritative (collab éditeur, `PhysicsSession`). Ce qui est
  généré chez un joueur doit pouvoir être répliqué/validé chez les autres, ou
  rester explicitement local.

## 5. Ce qui change / ce qui reste

| Domaine | V2 | V3 |
|---------|----|----|
| Producteur de contenu | Humain via UI éditeur | Humain **+ son IA** via canal WS |
| Extension d'un élément | Recompilation C++ (nouveau `TileType`, paramètre) | **Espace mémoire libre** + QML génératif à la volée (doc 04/05) |
| Point d'entrée IA | Automation (debug/dev) | **Canal WS dédié** IA-joueur (doc 02) |
| Règles de partie | Codées en dur (système de tour, loyers…) | Socle + couche custom pilotée par IA (doc 06, différé) |
| Partage de contenu | Fichiers map JSON | + **Bibliothèque** de primitives/créations (doc 07, différé) |
| Physique / rendu 3D | Pattounx v2 / World3D | Inchangé (piloté à terme par l'IA) |
| Réseau P2P / collab | Catway / EditorSession | Inchangé, socle réutilisé |

## 6. Non-buts (à ce stade du cadrage)

- Pas de suppression du jeu « classique » : le mode piloté par IA s'ajoute, il ne
  remplace pas immédiatement le gameplay existant.
- Pas d'IA hébergée par le jeu : le modèle est **fourni par le joueur**.
- Pas d'exposition réseau du canal hors de la machine locale à ce stade.
- Le cadrage du **moteur de règles** (doc 06) et de la **bibliothèque** (doc 07)
  est explicitement reporté.

## 7. Risque central assumé

Le choix **D1 (QML génératif complet)** offre la liberté maximale mais ouvre la
**plus grande surface de sécurité du projet** : du code non fait-maison est
chargé et exécuté dans le process du jeu. Tout le cadrage V3 est structuré pour
que cette liberté soit **encadrée par un sandbox** (doc 04) plutôt que subie.
C'est le sujet le plus important à traiter avant toute implémentation.
