# 01 — Architecture cible

> **Statut : cadrage (draft).** Vue d'ensemble des briques V3 et de leurs flux.
> Détail par brique dans les docs 02→05.

## 1. Schéma d'ensemble

```
MACHINE DU JOUEUR — process Qt « Meownopoly »

  Son IA (modèle client)  ◀── skill installée (doc 03) ──▶  Fichier de skill
        │
        │  WebSocket LOCAL dédié IA↔jeu (loopback) ── doc 02
        ▼
  ┌──────────────┐
  │  Canal IA    │  reçoit les propositions (fichiers QML + script, data ops)
  │ (serveur WS) │
  └──────┬───────┘
         ▼
  ┌─────────────────────────┐  ◀── HÔTE uniquement, OBLIGATOIRE (D6, doc 00 §4)
  │  IA ARBITRE / MJ        │      juge la viabilité AVANT le sandbox
  │  accepte/amende/rejette │      rejet → erreur actionnable au proposant
  └──────┬──────────────────┘
         ▼  proposition validée   (data ops : sautent le sandbox → pipeline)
  ┌───────────────────┐
  │  Bac à sable QML  │  valide + instancie l'artefact QML en
  │  (sandbox, doc 04)│  contexte restreint (allow-list, budget)
  └─────────┬─────────┘
            ▼
  ┌───────────────────────┐
  │  Scène QML / Éditeur  │  (Editor.qml, World3D)
  └─────────┬─────────────┘
            ▼
  Pipeline de mutation existant :
    Game.updateMap → EditDelta → EditorOpBus/EditorSession
    → ItemSnapable (+ espace mémoire, doc 05) → persistance JSON
            │
            ▼  collab / réseau
  Catway (P2P UDP) → autres joueurs
```

**Ordre clé : Canal → Arbitre → Bac à sable → Scène.** L'arbitre est **en amont**
du bac à sable : il juge la proposition (données **et** source QML) *avant* toute
instanciation — inutile de sandboxer un artefact que le MJ rejettera. Le sandbox
reste la **dernière** barrière (sécurité dure) juste avant la scène. Les
propositions **sans** QML (pose, écriture mémoire) sautent le sandbox et vont de
l'arbitre directement au pipeline.

L'`AutomationServer` V2 (port 7700) **subsiste en parallèle**, réservé au
test/debug interne (décision D2). Il sert de **modèle de référence** au canal IA
mais n'est pas ce canal.

## 2. Briques

### 2.1 Le canal d'interaction IA↔jeu (doc 02)
Nouveau serveur WebSocket local, dédié. Protocole requête/réponse corrélé (calqué
sur l'automation : `{id, cmd, params}` / `{id, ok, result|error}`) mais avec un
**catalogue de commandes de haut niveau orienté gameplay** et une boucle
**perception → action** (l'IA lit l'état, agit, observe). Distinct de
l'automation pour isoler les responsabilités et pouvoir durcir la sécurité
indépendamment.

### 2.2 Le fichier de skill client (doc 03)
Livré à l'installation, généré à partir du MCP `automation_mcp/`. Il décrit à
l'IA du joueur **les capacités disponibles** (catalogue de commandes, schémas
d'I/O, exemples, garde-fous). C'est le contrat qui rend l'IA opérationnelle sans
que le joueur ait à documenter le protocole.

### 2.3 Le bac à sable QML (doc 04) — pièce critique
Reçoit le QML généré par l'IA (D1), le **valide** et le **charge dans un contexte
restreint** (pas d'accès disque/réseau/process, API allow-list, budget de
ressources). Point de passage obligatoire de tout code génératif avant qu'il
touche la scène.

### 2.4 L'espace mémoire par `snapableElement` (doc 05)
Chaque `ItemSnapable` gagne un **set de variables typées** (`int`/`string`/`bool`/
`real`, sans schéma de clés imposé) que l'IA lit/écrit pour personnaliser un
élément (« loyer ×2 », état, compteur, réf. d'un comportement généré). Sync **live
host-authoritative façon physique** (`PhysicsSession`, snapshot ~30 Hz), **pas** via
l'op d'édition undoable : le stream est **lossy et non-undoable** au grain de
l'écriture. L'undo est préservé par un **snapshot de toute la mémoire avant chaque
ajout d'item QML** (doc 05 §3). Persistance dans le JSON de map via `toJSON`.
**Réactif** : une écriture (locale ou reçue par snapshot) émet un signal QML
(`userMemoryChanged`) auquel les règles custom / comportements générés s'abonnent —
c'est le **bus de variables** entre la donnée synchronisée et le JS embarqué.
Support privilégié : les **zones**.

### 2.5 L'IA arbitre / MJ (hôte uniquement, **obligatoire**) — cf. doc 00 §4, D6
Second rôle d'IA, **présent seulement chez l'hôte** et **requis** : comme du code
JS entre dans la partie, héberger le mode IA **exige** un arbitre branché (pas de
« host sans arbitre » ; à défaut, repli jeu classique). Il se place **en amont du
bac à sable** (doc 04) : il s'interpose entre les propositions (locales à l'hôte
**et** venues des clients par le réseau) et leur traitement, **juge la viabilité**
(cohérence de règles, équilibre, faisabilité, abus) sur les données **et** la
source QML, et **accepte / amende / rejette** — *avant* toute instanciation. Le
sandbox reste la barrière suivante (sécurité dure) pour les artefacts QML acceptés.
C'est la couche de jugement *contextuel* au-dessus des garde-fous *mécaniques* du
sandbox (doc 04) et du contrat de règles (doc 06). C'est aussi **lui qui gère les
règles** (D8) : le règlement est ce que l'arbitre connaît (prompt) et fait
respecter, pas un moteur séparé ; il évolue via des propositions acceptées.
Point d'ancrage réseau : le même que l'autorité d'édition — `EditorSession`
host-authoritative (l'hôte valide déjà les ops clientes avant rebroadcast ;
l'arbitre s'y greffe). **À cadrer (D6)** : sa nature (LLM / déterministe / hybride),
son grain et le format de son verdict.

### 2.6 Règles (doc 06, gérées par l'arbitre) & Bibliothèque (doc 07)
Les **règles sont gérées par l'arbitre** (D8, §2.5) — pas de moteur séparé ; il n'y
a **pas de tour imposé** (il s'introduit par prompt ou proposition acceptée). Les
**détails** (format d'une règle, mémorisation, réplication) sont différés. La
**bibliothèque** (doc 07, différée) capitalisera les créations et/ou fournira des
primitives réutilisables.

## 3. Réutilisation du socle V2 (points d'ancrage réels)

| Brique V3 | S'appuie sur (V2) | Fichiers |
|-----------|-------------------|----------|
| Canal IA | `AutomationServer` (protocole, loopback, dispatch) | `cpp/automation/automation_server.{h,cpp}` |
| Actions éditeur | hooks `editorAutomationHooks` (pose, caméra, save) | `qml/editor/Editor.qml` (bloc ~l.2633+) |
| Skill client | MCP + tools + `AUTOMATION_API.md` | `automation_mcp/`, `doc/architecture/AUTOMATION_API.md` |
| Espace mémoire | `ItemSnapable` + `toJSON`/`applyJson` | `cpp/game/item_snapable/ItemSnapable.{h,cpp}` |
| Sync du blob | `EditDelta` + op `ApplyState` + `Game.updateMap` | `cpp/game/map/editdelta.h`, `cpp/game/game_loader.cpp`, `cpp/editor/ops/editor_op_bus.{h,cpp}` |
| Briques graphiques (vocabulaire IA) | Éléments posables, composants UI | `cpp/game/item_snapable/`, `qml/ui_item/`, `qml/meowComponent/` |
| Briques gameplay (vocabulaire IA) | Modules activables (vie, inventaire, monnaie, stats/XP) | `GameplayModuleManager` |
| Partage des actions | Collab host-authoritative (traitement + broadcast) | `EditorOpBus`/`EditorSession` |
| Runtime piloté | `PhysicsSession`, `World3D`, `InputController` | `cpp/game/physics/`, `qml/world3d/` |
| Réseau/collab | Catway, `EditorSession` host-authoritative | `cpp/communication/`, `cpp/editor/network/` |
| Point d'arbitrage (D6) | `EditorSession` (l'hôte valide déjà les ops avant rebroadcast) | `cpp/editor/network/` |

## 4. Flux type — « l'IA crée un élément de gameplay »

1. Le joueur décrit l'intention à son **IA cliente**.
2. L'IA cliente **génère un fichier QML** — l'élément et/ou son comportement — qui
   peut embarquer du **script QML/JS**. Ce script est écrit pour **lire et écrire
   l'espace mémoire** (doc 05) des tuiles : c'est par là qu'il crée le gameplay
   (variables, état, effets). L'IA émet ce fichier sur le **canal WS** (doc 02),
   éventuellement avec des commandes de pose (`place*`).
3. **D'abord l'arbitre.** Toute proposition (client ou hôte) passe par l'**IA
   arbitre** de l'hôte (§2.5, **obligatoire**, en amont du sandbox) : jugement de
   viabilité sur les données **et** la source QML/JS → accepte / amende / rejette.
   Un rejet remonte au proposant comme **erreur actionnable** (doc 02 §5) pour
   itérer.
4. **Ensuite le sandbox.** Le fichier QML accepté passe par le **sandbox**
   (doc 04) qui le valide et l'instancie dans un contexte restreint, rattaché à la
   tuile ; son script n'accède qu'à la façade autorisée (dont l'espace mémoire).
   Une proposition sans QML (pose, écriture mémoire directe) saute cette étape.
5. **Le script fait le gameplay via l'espace mémoire.** À l'exécution, il lit/écrit
   les variables ; **elles sont streamées host-authoritative comme les états de
   physique** (`PhysicsSession` : l'hôte applique puis rebroadcaste un snapshot
   ~30 Hz) → répliquées aux autres joueurs, qui réagissent via `userMemoryChanged`
   (doc 05). Ce stream est **lossy et non-undoable** ; l'undo d'une session est
   préservé par un **snapshot de toute la mémoire pris avant chaque ajout d'item
   QML** (doc 05 §3). La réplication de la *source* QML, elle, reste à trancher
   (doc 04 §sécurité, doc 08).
6. L'IA cliente **observe** le résultat (état / screenshot via le canal) et itère.

## 5. Frontières & responsabilités

- **Le jeu ne raisonne pas** : il expose des capacités et applique des garde-fous.
  Le raisonnement (traduire l'intention → séquence d'actions) est côté IA client.
- **Le canal ne fait pas de gameplay** : il traduit des commandes vers les
  pipelines existants. Pas de règle métier dans le transport.
- **Le canal IA n'est pas l'automation.** L'IA cliente n'a **aucun accès** au
  harnais d'automation (`AutomationServer`, `automation_mcp/`), réservé au
  test/debug. Le canal ré-expose un **sous-ensemble curé** (certaines features
  portées + durcies) orienté création de briques de gameplay. Le tableau §3
  documente une réutilisation **de code** (patrons du serveur d'automation pour
  bâtir le canal), **pas** un accès de l'IA à l'automation (doc 02 §1, doc 03).
- **Le sandbox ne fait pas confiance** : tout artefact QML est hostile par défaut.
- **L'espace mémoire n'a pas de schéma imposé côté cœur** : c'est un blob libre ;
  le sens des clés est une convention IA/règles (doc 05/06), pas du C++.
- **L'arbitre juge, il n'exécute pas.** Il rend un verdict (accepte/amende/rejette)
  sur une proposition ; l'application reste le pipeline de mutation existant. Et il
  ne porte **aucune** garantie de sécurité dure : celles-ci restent au sandbox
  (doc 04) et au contrat de règles (doc 06). Voir doc 00 §8.

## 6. Chantiers dérivés (aperçu, non planifiés ici)

- Combler la **divergence hooks ↔ tools MCP** (des hooks existent sans tool MCP).
- Ajouter des capacités **runtime** (piloter le joueur/NPC en jeu, pas seulement
  poser dans l'éditeur) — absentes en V2.
- Ajouter **l'introspection d'état** (lister les tuiles par uuid/type/position,
  énumérer les enums valides) requise par une boucle perception→action.

Ces manques sont documentés en détail dans le doc 02 (§capacités manquantes).
