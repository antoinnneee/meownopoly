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
| 09 Questionnaire de cadrage | Questions ouvertes, chacune avec proposition | détaillé 2026-07-12 |
| 10 Audit stack existante | Audit V2 + chantiers M1→M13 | vérifié 2026-07-12 |
| 11 Vertical slice | Slice solo S1/S2/S3, fil rouge, critères | défini 2026-07-12 |
| 12 Banc d'essai R1 | Spec du banc hors-process (D26) : phases, corpus, sortie R1 | spécifié 2026-07-12 |

## 3. Décisions prises (D1→D34)

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
- **D24/D31 — Arbitre prouvé avant lancement, UX validée** : handshake de rôle
  + challenge de capacité avant d'ouvrir le mode IA ; lobby à 4 états
  (`Absent`/`Test en cours`/`Prêt`/`Erreur`), bouton d'hébergement grisé hors
  `Prêt`, re-test manuel/auto, bandeau + file de propositions si l'arbitre
  meurt en partie.
- **D25 — Grain d'arbitrage configurable par UI** : les joueurs choisissent
  quels types de requêtes passent par l'arbitre. Plancher proposé non
  désactivable sur le code/les règles ; défaut hybride (atténue R8).
- **D32 — Formes exécutables : sélection mécanique, arbitre confirme ou
  rétrograde ; un élément amendé par l'arbitre repasse par le banc D26** —
  aucun code ne contourne la validation, pas même celui de l'arbitre.
- **D33 — Événements en autorité par source** : tout événement passe par
  l'hôte avant de déclencher une règle ; ordre déterministe physique →
  mémoire → actions joueur → tick (file D12).

### Règles & exécution
- **D3 — Détails du moteur de règles différés** (autorité tranchée par D8).
- **D12 — Représentation hiérarchique des règles** : plan de capacités →
  config de modules → DSL/machine à états → QML/JS sandboxé, selon le besoin.
  Règlement autoritatif dans un document structuré versionné. Protections :
  profondeur max, file transactionnelle, détection de cycles/write-set.
- **D13/D26 — Sandbox à deux étages.** **Validation = banc d'essai
  hors-process** (D26) : moteur/process distincts, la carte est réinstanciée
  depuis un snapshot pour tester l'artefact candidat (non-chargement, boucle
  infinie → process tué, le jeu ne gèle jamais). **Spécifié dans le doc 12**
  (job/verdict JSON, phases P0→P5, corpus de test, pool, cache de verdicts,
  critères de sortie R1). **Exécution en partie = confinement in-process**
  (D13, conditionnel R1 recentré) : contexte restreint, façade API, budgets
  runtime pour le code déjà validé.
- **D34 — Contenu du sandbox arrêté** : allow-list d'imports (élargie à
  `QtQuick.Controls` + modules QML custom existants énumérés dans le
  manifeste, ex. `SnapableElement` surchargés), façade `Meow.GameApi`
  (mémoire, événements, gameplay, présentation) et budgets chiffrés
  (20 KB source, 2 ms/handler, 0,5 ms/tick, 8 Mo, 200 objets…), chacun
  derrière un `#define`.

### Canal, mémoire, artefacts
- **D14 — Un seul canal multiplexé et versionné** (rôles + namespaces),
  adaptateur d'événements unifié, lots tout-ou-rien visés. `automation.raw` en
  build dev uniquement. *(Transport révisé par D20 : MCP local.)*
- **D7 / D15 — Modèle mémoire.** Un objet `memory` avec namespaces `config`
  (durable : pipeline d'édition, undoable) et `state` (runtime : host-authoritative,
  LWW, non undoable), porté par tuiles, session et joueurs. Transport = bus d'état
  générique **à créer** (n'existe pas en V2).
- **D27 — Sauvegarde de partie distincte de la map** : l'état runtime
  (mémoires `state`, règlement, artefacts actifs) vit dans un fichier séparé
  qui référence la map (id + version/hash).
- **D28 — L'undo restaure malgré tout** : une valeur durable modifiée depuis
  est écrasée (LWW assumé, R10 accepté comme choix produit, trace au journal).
  Write-set ciblé requis, jamais de snapshot global.
- **D16 — Artefacts sous autorité hôte.** Source auteur → hôte (pas de broadcast
  systématique) ; exécution hôte seul ou chez chaque pair après revalidation,
  selon une propriété déclarée. Identité = QUuid d'instance + hash de contenu +
  version de manifeste (store par hash à créer).

### Produit & distribution
- **D9 — Périmètre V3.** Trois contextes (éditeur solo assisté, éditeur collab,
  partie runtime co-construite), tous avec les deux rôles IA. Application
  automatique sans revue humaine. Windows + Linux visés. Le mode classique
  survit à la transition mais n'est pas une cible à terme.
- **D23 — Ordre de livraison : solo → collaboratif → runtime.** Le solo
  dé-risque canal/skill/sandbox/arbitrage sans réseau ; le vertical slice
  (D30) est défini sur ce mode.
- **D30 — Vertical slice défini** (doc 11) : fil rouge « plaque piégée »
  (gameplay + physique + autres éléments + interaction joueur), trois
  scénarios — S1 création avec config + comportement, S2 proposition arbitrée
  + banc d'essai + application, S3 rejet actionnable et itération.
- **D17 — Skill générée au build** depuis le manifeste versionné du canal
  (source de vérité unique). Cibles : Codex + Claude Code. **Embarquée dans
  l'app et injectée en pré-prompt** à l'invocation ingame — pas d'installation
  dans la configuration de l'agent du joueur.
- **D4 / D18 / D29 — Bibliothèque.** Premier jalon : bibliothèque **locale
  officielle unifiée** d'assets 3D (format **GLB**), alimentée par les devs,
  réutilisant `asset_server/` + launcher après audit. Package au **format de
  l'asset manager existant, étendu** (version, hash, signature, types
  d'entrées — D29). Signature d'éditeur et adressage par hash à créer.

## 4. Principales questions encore ouvertes

**Chaque question du doc 09 porte désormais une proposition prête à valider.**
Les principales :

- **Confinement runtime (D13, recentré par D26)** : verrouillage réel d'un
  `QQmlContext` et masquage des singletons → **prototype R1 requis** — le
  contenu (allow-list, façade, budgets) est arrêté par **D34**, le protocole
  de mesure par le **doc 12** (corpus + critères de sortie) ; la préemption
  des boucles est couverte par le banc d'essai D26.
- **Canal** : manifeste des 10 tools MVP proposé (Q-E08), schéma du résumé
  d'événements + curseur proposé (Q-E06) ; garanties applicatives P2P
  au-dessus de `reliable.io` (Q-F06, modèle hybride à confirmer).
- **Mémoire/réseau** : delta 30 Hz + snapshot de réparation proposés (Q-F05),
  plafonds du bus (Q-F07), sérialisation string-manuelle de
  `ItemSnapable::toJSON` à assainir (bloquant pour le snapshot du banc,
  doc 12 §10).
- **Artefacts/migration** : cycle de vie multi-tuiles par refcount (Q-G06),
  checkpoint de migration en 4 volets (Q-G07).
- **Bibliothèque** : champs du manifeste étendu (Q-I04), modèle de confiance
  (Q-I05, reco « officiel signé + communautaire revalidé »), budgets assets
  (Q-I09).
- **Sortie de cadrage** : données privées (Q-J02), détection de divergence
  (Q-J03, reco hash + resync), indicateurs d'arbitrage (Q-J04), critères de
  repli D1 (Q-J06), prochain doc = **schéma de l'enveloppe de proposition**
  (Q-J07 — spec R1 ✓ doc 12, slice ✓ doc 11), responsables par famille (Q-J08).

## 5. Risques majeurs (top)

| Risque | Impact |
|--------|--------|
| R1 sandbox QML infaisable | Bloque D1 (repli « palette + mémoire ») — recentré par D26 sur le confinement runtime |
| R2 RCE inter-joueurs via QML répliqué | Critique — exécution hôte par défaut |
| R11 boucle JS bloquant le GUI | Réduit (D26) — les boucles franches meurent au banc d'essai hors-process |
| R13 `reliable.io` pris pour fiable | Critique — ACK/retry/dédup applicatifs |
| R7 arbitre pris pour un garde-fou dur | Élevé — sécurité dure = sandbox |
| R10 undo d'artefact écrasant du concurrent | Accepté (D28) — LWW assumé, trace au journal |
| R15 migration d'hôte sans contexte arbitre | Élevé — checkpoint transférable |
| R16 checksum SHA-256 pris pour signature | Élevé — signature asymétrique |

(Liste complète : doc 08 §3, R1→R16.)

## 6. Séquencement suggéré (non engageant, aligné D23/D30)

1. **Prototype sandbox** (R1 recentré D26) : banc d'essai hors-process +
   confinement runtime.
2. **Canal MCP minimal** (D20/D21) : passerelle streamable HTTP + tools MVP,
   rôles/tokens injectés, enveloppe de proposition.
3. **Adaptateur agents** : supervision `claude -p`/Codex, skill au build,
   handshake arbitre (D24), tchat ingame minimal.
4. **Vertical slice solo** (D30, doc 11) : S1/S2/S3 sur le fil rouge.
5. **Couche réseau V3** : ACK applicatif, retry/dédup, transaction
   prepare/commit/rollback (prérequis du collab).
6. **Espace mémoire** : bus runtime `state`, undo ciblé, sauvegarde de partie (D27).
7. **Bibliothèque officielle GLB** au format asset manager étendu (D29).

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
