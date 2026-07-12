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
l'**éditeur** — via un canal MCP local dédié (D20), en **composant les briques
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
| — | [`RECAP_CADRAGE.md`](./RECAP_CADRAGE.md) | Récapitulatif synthétique du cadrage (photo à date) | 2026-07-12 |
| 00 | [`00_VISION.md`](./00_VISION.md) | Vision, principes directeurs, ce qui change / ce qui reste | draft |
| 01 | [`01_ARCHITECTURE_CIBLE.md`](./01_ARCHITECTURE_CIBLE.md) | Vue d'ensemble des briques + flux, réutilisation du socle V2 | draft |
| 02 | [`02_CANAL_IA.md`](./02_CANAL_IA.md) | Le canal MCP local IA↔jeu (distinct de l'automation ; ex-WS, D20) | draft |
| 03 | [`03_SKILL_CLIENT_IA.md`](./03_SKILL_CLIENT_IA.md) | Le fichier de skill livré au joueur à l'installation | draft |
| 04 | [`04_QML_GENERATIF_SANDBOX.md`](./04_QML_GENERATIF_SANDBOX.md) | Modèle d'exécution « QML à la volée » + sandbox de sécurité | draft |
| 05 | [`05_ESPACE_MEMOIRE_SNAPABLE.md`](./05_ESPACE_MEMOIRE_SNAPABLE.md) | Mémoire `config/state`, persistance, bus runtime et undo | partiellement cadré |
| 06 | [`06_MOTEUR_REGLES.md`](./06_MOTEUR_REGLES.md) | Autorité, représentation et exécution des règles | **partiellement cadré** |
| 07 | [`07_BIBLIOTHEQUE.md`](./07_BIBLIOTHEQUE.md) | Bibliothèque (primitives — dont assets 3D — et/ou créations partagées) | **intention actée, architecture ouverte** |
| 08 | [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md) | Registre des décisions (ADR léger) + questions ouvertes + risques | vivant |
| 09 | [`09_QUESTIONNAIRE_CADRAGE.md`](./09_QUESTIONNAIRE_CADRAGE.md) | Questions **encore ouvertes** (arbitrages D9→D22 reportés au doc 08) | **épuré 2026-07-12** |
| 10 | [`10_AUDIT_STACK_EXISTANTE.md`](./10_AUDIT_STACK_EXISTANTE.md) | Audit V2 + plan M1→M13 des modifications de stack | **vérifié 2026-07-12** |

## Décisions structurantes déjà prises

Détail et justification dans [`08_DECISIONS_ET_QUESTIONS.md`](./08_DECISIONS_ET_QUESTIONS.md).

- **D1 — Modèle d'exécution : QML génératif complet.** L'IA produit du vrai code
  QML chargé au runtime (`Qt.createQmlObject` / `Loader`). Conséquence directe :
  le **sandbox d'exécution** (doc 04) devient la pièce d'architecture la plus
  critique du pivot.
- **D2/D20 — Canal d'interaction : serveur MCP local dédié.** On ne surcharge
  pas l'`AutomationServer` existant (`cpp/automation/`, port 7700) : il reste
  réservé au test/debug interne. Un canal séparé « IA-joueur » est créé (doc 02),
  exposé comme **serveur MCP local** (D20 — remplace le WS custom initial) :
  l'app spawne l'agent et injecte config + token, catalogue de tools groupé
  économe en tokens, événements injectés par invocation + `events_poll`.
  Forme d'intégration tranchée (**D21**) : endpoint **streamable HTTP loopback
  intégré au process du jeu** (`QtHttpServer` à installer ; repli pont stdio).
- **D3 — Règles : détails de représentation/exécution différés** (doc 06).
  L'autorité de politique est tranchée par D8, mais son exécution runtime ne
  repose pas implicitement sur le LLM : elle doit être matérialisée par les
  primitives/modules/QML acceptés.
- **D4 — Bibliothèque : architecture différée** (doc 07). Première intention de
  contenu actée : une **bibliothèque d'assets 3D** (versant primitives graphiques,
  doc 07 §1).
- **D6 — Deux rôles d'IA : cliente (proposante) partout + arbitre (MJ) chez
  l'hôte, obligatoire.** L'hôte fait tourner 2 modèles (proposant + arbitre de
  viabilité), le client 1 (proposant). L'arbitre est **requis** pour gouverner la
  partie partagée (pas de host sans arbitre), mais ne remplace aucune barrière de
  sécurité. Il se place dans le flux d'acceptation **avant l'application** et
  avant l'exécution finale (préfiltre mécanique possible avant le LLM).
  Nature/grain/verdict à cadrer
  (doc 00 §4, doc 08).
- **D7 — Espace mémoire : deux sémantiques, deux chemins.** La configuration
  durable suit le pipeline d'édition/persistance et peut être undoable ; l'état
  runtime suit un flux host-authoritative à sémantique « dernier état » et n'est
  pas undoable au grain de l'écriture. La cadence, le transport et la stratégie
  d'undo structurel restent à trancher (doc 05, doc 08).
- **D8 — L'arbitre gouverne les règles ; le jeu exécute leur forme acceptée.**
  Aucun moteur générique séparé n'est acté. **Aucun tour imposé** : il s'introduit
  par le prompt ou une proposition acceptée, puis doit être matérialisé dans des
  capacités/modules/QML validés. Invariants durs = contrôles mécaniques (doc 06/08).
- **D9→D22 — Arbitrages issus du questionnaire et de ses suites.** Périmètre des
  trois modes V3, agents Codex/Claude supervisés **invoqués in-app via tchat
  ingame**, proposition auditable avec amendement immédiat, règles hiérarchiques,
  sandbox in-process conditionnel à R1, canal **MCP local** multiplexé (D20) en
  **streamable HTTP intégré au jeu** (D21), screenshots plafonnés/éphémères (D22),
  mémoire `config/state`, artefacts sous autorité hôte, skill générée au build
  **injectée en pré-prompt** et bibliothèque locale officielle GLB. Détail et
  réserves techniques dans les docs 08→10.

## Ce que le pivot réutilise du socle V2 (ne pas réinventer)

- **Serveur d'automation + hooks éditeur** (`cpp/automation/automation_server.*`,
  `editorAutomationHooks` dans `qml/editor/Editor.qml`) : réutilisés **comme
  patron de code** (protocole, loopback, dispatch) et comme **implémentation** des
  capacités portées dans le canal. ⚠️ **L'automation reste test-only : l'IA
  cliente n'y a aucun accès** — le canal ré-expose un sous-ensemble curé (D2, doc 02).
- **MCP `automation_mcp/`** : **patron d'outillage** et source de schémas à porter.
  La source de vérité livrée est le **manifeste du canal IA**, jamais le MCP
  d'automation lui-même (doc 03).
- **`ItemSnapable` + `EditDelta` + `EditorOpBus`/`EditorSession`** : le pipeline
  de mutation/sérialisation/sync collaboratif dans lequel s'insère l'espace
  mémoire (doc 05).
- **`PhysicsSession` / Pattounx v2 / World3D** : présentation et simulation
  runtime que l'IA pilotera à terme.

## Convention

Documents en **français** (convention projet). Chaque doc porte un bandeau de
statut. Les affirmations sur le code citent fichier + point d'ancrage ; comme
les plans dérivent, **vérifier contre le code réel avant d'implémenter**.
