# Meownopoly V3 — Dossier de cadrage

> **Statut : cadrage (draft).** Ce dossier contient les documents de cadrage du
> pivot V3. Il ne contient **aucun code** : c'est le lieu où l'on affine la
> vision, on tranche les décisions d'architecture et on liste les questions
> ouvertes **avant** d'ouvrir des chantiers d'implémentation.
>
> Branche cible : **V3** (partie du même point que V2, cf. `git log V2..V3` vide
> au moment de la création).

## Le pivot en une phrase

Meownopoly V3 transforme le jeu en un **substrat de gameplay créé par des IA
clientes** : chaque joueur dispose de « son IA » (un modèle fourni côté client) à
qui il décrit en langage naturel les éléments **et le gameplay** qu'il veut voir
apparaître ; cette **IA cliente** les matérialise en direct — en priorité dans
l'**éditeur** — via un canal WebSocket local dédié, en **composant les briques
graphiques et gameplay préexistantes** de l'éditeur **et en y embarquant du code
JS** pour le comportement nouveau (le QML/JS étant interprété au runtime). Le jeu
n'est pas figé : il **se construit au fur et à mesure grâce aux utilisateurs**.
Comme du code entre dans la partie, l'hôte fait **obligatoirement** tourner une
seconde IA — l'**arbitre / MJ** — qui vérifie la viabilité de chaque proposition
avant qu'elle n'entre dans la partie partagée (2 modèles côté hôte, 1 côté client ;
cf. doc 00 §4).

## Ordre de lecture

| # | Document | Rôle | Statut |
|---|----------|------|--------|
| — | [`README.md`](./README.md) | Index (ce fichier) | draft |
| 00 | [`00_VISION.md`](./00_VISION.md) | Vision, principes directeurs, ce qui change / ce qui reste | draft |
| 01 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | Vue d'ensemble des briques + flux, réutilisation du socle V2 | draft |
| 02 | [`02_CANAL_IA_WEBSOCKET.md`](./02_CANAL_IA_WEBSOCKET.md) | Le canal WS dédié IA↔jeu (distinct de l'automation) | draft |
| 03 | [`03_SKILL_CLIENT_IA.md`](./03_SKILL_CLIENT_IA.md) | Le fichier de skill livré au joueur à l'installation | draft |
| 04 | [`04_QML_GENERATIF_SANDBOX.md`](./04_QML_GENERATIF_SANDBOX.md) | Modèle d'exécution « QML à la volée » + sandbox de sécurité | draft |
| 05 | [`05_ESPACE_MEMOIRE_SNAPABLE.md`](./05_ESPACE_MEMOIRE_SNAPABLE.md) | Espace mémoire par `snapableElement` + intégration delta | draft |
| 06 | [`06_MOTEUR_REGLES.md`](./06_MOTEUR_REGLES.md) | Moteur de règles de partie | **stub — à cadrer** |
| 07 | [`07_BIBLIOTHEQUE.md`](./07_BIBLIOTHEQUE.md) | Bibliothèque (primitives — dont assets 3D — et/ou créations partagées) | **stub — à cadrer** |
| 08 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | Registre des décisions (ADR léger) + questions ouvertes + risques | vivant |

## Décisions structurantes déjà prises

Détail et justification dans [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md).

- **D1 — Modèle d'exécution : QML génératif complet.** L'IA produit du vrai code
  QML chargé au runtime (`Qt.createQmlObject` / `Loader`). Conséquence directe :
  le **sandbox d'exécution** (doc 04) devient la pièce d'architecture la plus
  critique du pivot.
- **D2 — Canal d'interaction : nouveau WebSocket dédié.** On ne surcharge pas
  l'`AutomationServer` existant (`cpp/automation/`, port 7700) : il reste réservé
  au test/debug interne. Un canal séparé « IA-joueur » est créé (doc 02).
- **D3 — Moteur de règles : cadrage différé** (doc 06, stub).
- **D4 — Bibliothèque : cadrage différé** (doc 07, stub). Première intention de
  contenu actée : une **bibliothèque d'assets 3D** (versant primitives graphiques,
  doc 07 §1).
- **D6 — Deux rôles d'IA : cliente (proposante) partout + arbitre (MJ) chez
  l'hôte, obligatoire.** L'hôte fait tourner 2 modèles (proposant + arbitre de
  viabilité), le client 1 (proposant). Comme du code JS entre dans la partie,
  l'arbitre est **requis** (pas de host sans arbitre). Il se place **en amont du
  sandbox** (Canal → Arbitre → Sandbox → Scène). Nature/grain/verdict à cadrer
  (doc 00 §4, doc 08).
- **D7 — Espace mémoire : stream façon physique, non-undoable, + snapshot d'undo.**
  Le sync live de la mémoire passe par un **stream host-authoritative type
  `PhysicsSession`** (snapshot ~30 Hz), pas par l'op d'édition undoable → lossy et
  non-undoable au grain de l'écriture. L'undo de session est préservé par un
  **snapshot de toute la mémoire avant chaque ajout d'item QML** (doc 05, doc 08).
- **D8 — Les règles sont gérées par l'arbitre** (pas de moteur séparé). L'arbitre
  valide/refuse les actions des IA clientes. **Aucun tour imposé** : il s'introduit
  par le **prompt à l'arbitre** ou par une **proposition d'IA cliente acceptée**
  (règlement négociable/évolutif). Invariants durs = sandbox (doc 06, doc 08).

## Ce que le pivot réutilise du socle V2 (ne pas réinventer)

- **Serveur d'automation + hooks éditeur** (`cpp/automation/automation_server.*`,
  `editorAutomationHooks` dans `qml/editor/Editor.qml`) : réutilisés **comme
  patron de code** (protocole, loopback, dispatch) et comme **implémentation** des
  capacités portées dans le canal. ⚠️ **L'automation reste test-only : l'IA
  cliente n'y a aucun accès** — le canal ré-expose un sous-ensemble curé (D2, doc 02).
- **MCP `automation_mcp/`** : **patron d'outillage** pour générer le manifeste du
  canal et la skill (doc 03) — pas exposé à l'IA.
- **`ItemSnapable` + `EditDelta` + `EditorOpBus`/`EditorSession`** : le pipeline
  de mutation/sérialisation/sync collaboratif dans lequel s'insère l'espace
  mémoire (doc 05).
- **`PhysicsSession` / Pattounx v2 / World3D** : présentation et simulation
  runtime que l'IA pilotera à terme.

## Convention

Documents en **français** (convention projet). Chaque doc porte un bandeau de
statut. Les affirmations sur le code citent fichier + point d'ancrage ; comme
les plans dérivent, **vérifier contre le code réel avant d'implémenter**.
