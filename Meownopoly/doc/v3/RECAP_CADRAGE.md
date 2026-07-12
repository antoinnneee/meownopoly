# Récapitulatif du cadrage V3

> **Statut : synthèse ponctuelle (2026-07-12).** Photo de l'état du cadrage à date,
> dérivée du README et du registre `08_DECISIONS_ET_QUESTIONS.md`. En cas de
> divergence, les docs 00→10 font foi.

## 1. Le pivot en bref

Meownopoly V3 devient un **substrat de gameplay créé par des IA clientes** :
chaque joueur décrit en langage naturel ce qu'il veut voir apparaître, et « son
IA » (modèle côté client) le matérialise en direct — en priorité dans l'éditeur —
via un canal MCP local dédié (D20). La création se fait en **composant les
briques graphiques/gameplay existantes** de l'éditeur et en **embarquant du code
JS** pour le comportement nouveau (QML interprété au runtime). Comme du code
entre dans la partie, l'hôte fait tourner **obligatoirement** une seconde IA —
l'**arbitre / MJ** — qui valide chaque proposition avant application (2 modèles
chez l'hôte, 1 chez le client).

## 2. État des documents

| Doc | Sujet | Statut |
|-----|-------|--------|
| 00 Vision | Principes, ce qui change / reste | draft |
| 01 Architecture cible | Briques + flux, réutilisation V2 | draft |
| 02 Canal IA | Canal MCP local dédié (≠ automation ; ex-WS, D20) | draft |
| 03 Skill client IA | Skill livrée au joueur | draft |
| 04 QML génératif & sandbox | Exécution à la volée + sécurité | draft |
| 05 Espace mémoire snapable | `config`/`state`, bus runtime, undo | partiellement cadré |
| 06 Moteur de règles | Autorité/représentation/exécution | partiellement cadré |
| 07 Bibliothèque | Primitives (dont assets 3D) | intention actée, archi ouverte |
| 08 Décisions & questions | Registre ADR + risques | vivant |
| 09 Questionnaire de cadrage | Questions encore ouvertes uniquement | épuré 2026-07-12 |
| 10 Audit stack existante | Audit V2 + chantiers M1→M13 | vérifié 2026-07-12 |

## 3. Décisions prises (D1→D22)

### Fondations
- **D1 — QML génératif complet.** L'IA produit du vrai QML chargé au runtime.
  Précision 2026-07-11 : le but courant est de **composer les briques validées**
  + JS embarqué, pas de générer des scènes de zéro — ce qui réduit la surface du
  sandbox. Le sandbox (doc 04) reste la pièce la plus critique (risque R1).
- **D2/D20/D21 — Canal MCP local dédié, streamable HTTP intégré au jeu.**
  Nouveau canal local IA↔jeu, exposé comme **serveur MCP** (D20, remplace le WS
  custom initial) : l'app spawne l'agent et lui injecte config + token +
  pré-prompt skill. Forme d'intégration (D21) : **endpoint streamable HTTP
  loopback embarqué dans le process du jeu** — les deux CLIs le supportent
  nativement (vérifié 2026-07-12) ; sous-ensemble JSON-RPC à implémenter
  (`initialize`, `tools/list`, `tools/call`), add-on `QtHttpServer` à installer,
  repli pont stdio documenté. Catalogue de tools **réduit et groupé** pour
  économiser les tokens ; événements **injectés par invocation** + tool
  `events_poll`. Screenshots (D22) : écran de jeu à la demande de l'IA, plafond
  par requête via `#define` (défaut 5), rétention éphémère, aucun masquage,
  information une fois au lancement. L'`AutomationServer` (7700) reste
  strictement test/debug, **jamais accessible à l'IA cliente**.
- **D5 — Dossier de cadrage** dans `Meownopoly/doc/v3/`, en français, branche V3.

### Rôles IA & gouvernance
- **D6 — Deux rôles IA.** Cliente (proposante) chez chaque joueur ; arbitre/MJ
  **uniquement chez l'hôte et obligatoire** (pas de host sans arbitre ; à défaut,
  repli sur le jeu classique). L'arbitre n'est **pas** une barrière de sécurité.
- **D8 — L'arbitre gouverne les règles.** Pas de moteur de règles générique ;
  une règle acceptée est matérialisée en forme exécutable (config, module,
  primitive, QML/JS validé). **Aucun tour imposé** : il s'introduit par le prompt
  ou une proposition acceptée. Invariants durs = sandbox, pas arbitre.
- **D10 — Agents externes supervisés, invoqués in-app.** Cibles : `claude -p` +
  équivalent Codex non interactif, sessions isolées, lancés/supervisés par le
  launcher/jeu via un adaptateur. **Le joueur interagit via un tchat ingame** :
  les features ne s'exécutent jamais depuis un CLI à part — le CLI n'est que le
  mécanisme sous-jacent, invisible. L'app **pré-prompte** chaque modèle à
  l'invocation pour qu'il suive les workflows des skills internes. Budget côté
  hôte, prompt/personnalité de l'arbitre configuré par les joueurs. Migration
  d'arbitre avec transfert d'état requise.
- **D11 — Proposition auditable.** Enveloppe {auteur, intention, opérations,
  artefacts, write-set, version}. Flux : préfiltre mécanique → arbitre →
  validation complète → exécution. L'arbitre peut **amender et appliquer
  immédiatement**, avec journal de l'original et des raisons.
- **D19 — Journal configurable** avec noyau d'audit obligatoire (proposition,
  auteur, verdict, raisons, amendement, version) tant que l'action est rejouable.

### Règles & exécution
- **D3 — Détails du moteur de règles différés** (autorité tranchée par D8).
- **D12 — Représentation hiérarchique des règles** : plan de capacités →
  config de modules → DSL/machine à états → QML/JS sandboxé, selon le besoin.
  Règlement autoritatif dans un document structuré versionné. Protections :
  profondeur max, file transactionnelle, détection de cycles/write-set.
- **D13 — Sandbox in-process visé** (même moteur QML, contexte restreint, JS
  borné, pas de disque/réseau/process), **conditionnel à R1** (arrêt préemptif
  d'une boucle infinie). Échec ⇒ processus séparé.

### Canal, mémoire, artefacts
- **D14 — Un seul canal multiplexé et versionné** (rôles + namespaces),
  adaptateur d'événements unifié, lots tout-ou-rien visés. `automation.raw` en
  build dev uniquement. *(Transport révisé par D20 : MCP local.)*
- **D7 / D15 — Modèle mémoire.** Un objet `memory` avec namespaces `config`
  (durable : pipeline d'édition, undoable) et `state` (runtime : host-authoritative,
  LWW, non undoable), porté par tuiles, session et joueurs. Transport = bus d'état
  générique **à créer** (n'existe pas en V2).
- **D16 — Artefacts sous autorité hôte.** Source auteur → hôte (pas de broadcast
  systématique) ; exécution hôte seul ou chez chaque pair après revalidation,
  selon une propriété déclarée. Identité = QUuid d'instance + hash de contenu +
  version de manifeste (store par hash à créer).

### Produit & distribution
- **D9 — Périmètre V3.** Trois contextes (éditeur solo assisté, éditeur collab,
  partie runtime co-construite), tous avec les deux rôles IA. Application
  automatique sans revue humaine. Windows + Linux visés. Le mode classique
  survit à la transition mais n'est pas une cible à terme.
- **D17 — Skill générée au build** depuis le manifeste versionné du canal
  (source de vérité unique). Cibles : Codex + Claude Code. **Embarquée dans
  l'app et injectée en pré-prompt** à l'invocation ingame — pas d'installation
  dans la configuration de l'agent du joueur.
- **D4 / D18 — Bibliothèque.** Premier jalon : bibliothèque **locale officielle
  unifiée** d'assets 3D (format **GLB**), alimentée par les devs, réutilisant
  `asset_server/` + launcher après audit. Signature d'éditeur et adressage par
  hash à créer.

## 4. Principales questions encore ouvertes

- **Sandbox QML (bloquant D1/D13)** : verrouillage réel d'un `QQmlContext`,
  allow-list d'imports, arrêt préemptif d'un JS bloquant → **prototype R1 requis**.
- **Grain d'arbitrage** (Q-C01) : par action, par lot, ou seulement les artefacts
  QML ? Coût/latence d'un appel LLM par action.
- **Ordre de livraison des trois modes** V3 (tous cochés « premier mode »).
- **Canal** : sous-ensemble exact de tools à porter et leur groupement (économie
  de tokens), sémantique du résumé d'événements injecté et du curseur
  `events_poll` ; garanties applicatives P2P au-dessus de `reliable.io`.
  *(Auth/découverte : résolues par D20 ; forme d'intégration : tranchée D21,
  HTTP loopback intégré au jeu.)*
- **Mémoire** : schéma/noms `config`/`state`, delta vs snapshot, cadence,
  plafond, undo ciblé par write-set (conflits, redo), sérialisation
  string-manuelle de `ItemSnapable::toJSON` à assainir.
- **Capacités manquantes V2** : réconciliation hooks↔MCP, introspection d'état,
  édition ciblée par uuid, capacités runtime (piloter joueur/NPC).
- **UX du prérequis arbitre** : comment le jeu détecte/exige un arbitre branché.
- ~~Skill : comment l'agent atteint le canal~~ **tranché D20** : connecteur MCP
  natif des CLIs, config injectée au spawn. *(L'emplacement d'installation
  était déjà caduc : skill embarquée, injectée en pré-prompt.)*

## 5. Risques majeurs (top)

| Risque | Impact |
|--------|--------|
| R1 sandbox QML infaisable | Bloque D1 (repli « palette + mémoire ») |
| R2 RCE inter-joueurs via QML répliqué | Critique — exécution hôte par défaut |
| R11 boucle JS bloquant le GUI | Critique — isolation préemptive à prototyper |
| R13 `reliable.io` pris pour fiable | Critique — ACK/retry/dédup applicatifs |
| R7 arbitre pris pour un garde-fou dur | Élevé — sécurité dure = sandbox |
| R10 undo d'artefact écrasant du concurrent | Élevé — inverse ciblé par write-set |
| R15 migration d'hôte sans contexte arbitre | Élevé — checkpoint transférable |
| R16 checksum SHA-256 pris pour signature | Élevé — signature asymétrique |

(Liste complète : doc 08 §3, R1→R16.)

## 6. Séquencement suggéré (non engageant)

1. **Prototype sandbox QML** (R1) — dé-risque tout le reste.
2. **Couche réseau V3** : ACK applicatif, retry/dédup, transaction prepare/commit/rollback.
3. **Canal MCP minimal** (D20) : passerelle + tools d'introspection/pose, rôles/tokens injectés, version, enveloppe de proposition.
4. **Espace mémoire** : modèle `config/state`, bus runtime, undo ciblé.
5. **Adaptateur agents** : supervision `claude -p`/Codex + skill générée au build.
6. **Vertical slice règles/runtime** : modules + artefact + arbitrage.
7. **Bibliothèque officielle GLB** sur launcher/asset_server audité.

Détail technique : doc 10, chantiers **M1→M13**.

## 7. Socle V2 réutilisé

- **Automation + hooks éditeur** : patron de code (protocole, loopback, dispatch)
  et implémentation des capacités portées — jamais exposés à l'IA.
- **MCP `automation_mcp/`** : patron d'outillage et source de schémas ; la source
  de vérité livrée est le manifeste du canal.
- **`ItemSnapable` + `EditDelta` + `EditorOpBus`/`EditorSession`** : pipeline de
  mutation/sync dans lequel s'insère la mémoire `config`.
- **`PhysicsSession` / Pattounx v2 / World3D** : simulation et présentation
  runtime, modèle d'autorité pour la mémoire `state`.
- **`asset_server/` + launcher** : distribution de la bibliothèque (D18).
