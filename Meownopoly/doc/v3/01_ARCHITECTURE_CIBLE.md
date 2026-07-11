# 01 — Architecture cible

> **Statut : cadrage (draft).** Vue d'ensemble des briques V3 et de leurs flux.
> Détail par brique dans les docs 02→05.

## 1. Schéma d'ensemble

```
CLIENT                                      HÔTE (autorité)

IA cliente                                 IA cliente de l'hôte
    │ WS local                                  │ WS local
    ▼                                           ▼
Passerelle IA locale                       Passerelle IA locale
    │ proposition                                │ proposition locale
    └──────────── Catway / enveloppe ────────────┤
                                                 ▼
                                      Préfiltre mécanique
                                                 ▼
                                      IA arbitre / MJ
                                      accepte / refuse / demande révision
                                                 ▼
                                      Validation mécanique complète
                                      (sandbox QML si code)
                                                 ▼
                                      Application autoritative
                                      Game / EditorOpBus / runtime
                                                 │
                          état/op/événement validé ─┴─► pairs
```

**Ordre logique côté autorité : Passerelle locale → transport de proposition →
Arbitre de l'hôte → validation mécanique → application autoritative.** Pour une
proposition cliente, une **enveloppe** (auteur, intention, opérations, source ou
hash d'artefact, version) doit donc atteindre l'hôte avant toute acceptation. Le
mot « local-only » du doc 04 qualifie l'**exécution/réplication aux pairs**, pas
le fait de cacher la proposition à l'arbitre : sinon D6 serait impossible.

Le sandbox reste une barrière de sécurité indépendante de l'arbitre. L'ordre
exact entre analyse statique peu coûteuse et arbitrage LLM reste à mesurer : un
préfiltre mécanique peut rejeter immédiatement une source manifestement interdite,
puis l'arbitre juge la viabilité, puis l'artefact accepté subit la validation
complète avant exécution. Les propositions sans code ne passent pas par le
sandbox QML, mais restent soumises aux validateurs de schéma, d'autorisation et
de quotas du canal.

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
Livré à l'installation, généré à partir du **manifeste versionné du canal IA**.
Le MCP `automation_mcp/` sert de patron et de source de schémas à porter. Il décrit à
l'IA du joueur **les capacités disponibles** (catalogue de commandes, schémas
d'I/O, exemples, garde-fous). C'est le contrat qui rend l'IA opérationnelle sans
que le joueur ait à documenter le protocole.

### 2.3 Le bac à sable QML (doc 04) — pièce critique
Reçoit le QML généré par l'IA (D1), le **valide** et tente de le charger dans une
frontière restreinte (pas d'accès disque/réseau/process, API allow-list, budget).
La robustesse de cette frontière in-process n'est pas acquise : R1 doit décider
si un moteur/processus séparé ou un repli déclaratif est nécessaire (doc 04).

### 2.4 L'espace mémoire par `snapableElement` (doc 05)
Chaque `ItemSnapable` gagne un **set de variables sérialisables**. Le cadrage
distingue désormais deux sémantiques : **configuration durable** (édition,
persistance, undo) et **état runtime** (autorité hôte, dernier état, non undoable
au grain de l'écriture). Cette séparation évite de sauvegarder accidentellement
un état éphémère dans la map ou de restaurer toute la partie lors d'un undo.
La cadence et le transport du flux runtime restent à mesurer ; « 30 Hz reliable »
n'est pas une décision V3.
**Réactif** : une écriture (locale ou reçue par snapshot) émet un signal QML
(`userMemoryChanged`) auquel les règles custom / comportements générés s'abonnent —
c'est le **bus de variables** entre la donnée synchronisée et le JS embarqué.
Support privilégié : les **zones**.

### 2.5 L'IA arbitre / MJ (hôte uniquement, **obligatoire**) — cf. doc 00 §4, D6
Second rôle d'IA, **présent seulement chez l'hôte** et **requis** pour gouverner
une partie partagée co-construite : héberger le mode IA **exige** un arbitre (pas de
« host sans arbitre » ; à défaut, repli jeu classique). Il se place **en amont du
bac à sable** (doc 04) : il s'interpose entre les propositions (locales à l'hôte
**et** venues des clients par le réseau) et leur traitement, **juge la viabilité**
(cohérence de règles, équilibre, faisabilité, abus) sur les données **et** la
source QML, et **accepte / amende / rejette** — *avant* toute instanciation. Le
sandbox reste la barrière suivante (sécurité dure) pour les artefacts QML acceptés.
C'est la couche de jugement *contextuel* au-dessus des garde-fous *mécaniques* du
sandbox (doc 04). C'est aussi **lui qui gouverne les règles** (D8) : il accepte
leur évolution, tandis que leur forme matérialisée est exécutée par les capacités
du jeu. Le prompt seul n'est ni un état persistant ni un moteur runtime.
Point d'ancrage réseau pressenti : le même domaine d'autorité que
`EditorSession`. Le code V2 fournit déjà rate-limit, séquencement et rebroadcast,
mais **pas une validation sémantique générique** des ops : la passerelle
d'arbitrage et ses validateurs sont donc une nouvelle responsabilité, pas un
simple branchement sur un validateur existant. **À cadrer (D6)** : sa nature,
son grain et le format de son verdict.

### 2.6 Règles (doc 06, gouvernées par l'arbitre) & Bibliothèque (doc 07)
Les **règles sont gouvernées par l'arbitre** (D8, §2.5) — pas de moteur générique
séparé acté ; leur forme acceptée doit être exécutable par le jeu. Il n'y
a **pas de tour imposé** (il s'introduit par prompt ou proposition acceptée). Les
**détails** (format d'une règle, mémorisation, réplication) sont différés. La
**bibliothèque** (doc 07, différée) capitalisera les créations et/ou fournira des
primitives réutilisables — dont une **bibliothèque d'assets 3D** (prévue au
développement) qui **élargit le vocabulaire graphique** composable par l'IA,
adossée au rendu World3D existant (doc 00 §2, doc 07 §1).

## 3. Réutilisation du socle V2 (points d'ancrage réels)

| Brique V3 | S'appuie sur (V2) | Fichiers |
|-----------|-------------------|----------|
| Canal IA | `AutomationServer` (protocole, loopback, dispatch) | `cpp/automation/automation_server.{h,cpp}` |
| Actions éditeur | hooks `editorAutomationHooks` (pose, caméra, save) | `qml/editor/Editor.qml` (bloc ~l.2633+) |
| Skill client | MCP + tools + `AUTOMATION_API.md` | `automation_mcp/`, `doc/architecture/AUTOMATION_API.md` |
| Espace mémoire | `ItemSnapable` + `toJSON`/`applyJson` | `cpp/game/item_snapable/ItemSnapable.{h,cpp}` |
| Configuration mémoire durable | `EditDelta` + op `ApplyState` + `Game.updateMap` | `cpp/game/map/editdelta.h`, `cpp/game/game_loader.cpp`, `cpp/editor/ops/editor_op_bus.{h,cpp}` |
| État mémoire runtime | modèle host-authoritative à concevoir, inspiré de `PhysicsSession` | `cpp/game/physics/physics_session.{h,cpp}` |
| Briques graphiques (vocabulaire IA) | Éléments posables, composants UI | `cpp/game/item_snapable/`, `qml/ui_item/`, `qml/meowComponent/` |
| Briques gameplay (vocabulaire IA) | Modules activables (vie, inventaire, monnaie, stats/XP) | `GameplayModuleManager` |
| Partage des actions | Collab host-authoritative (traitement + broadcast) | `EditorOpBus`/`EditorSession` |
| Runtime piloté | `PhysicsSession`, `World3D`, `InputController` | `cpp/game/physics/`, `qml/world3d/` |
| Réseau/collab | Catway, `EditorSession` host-authoritative | `cpp/communication/`, `cpp/editor/network/` |
| Domaine réseau d'arbitrage (D6) | `EditorSession` (rate-limit, séquencement, rebroadcast ; validation sémantique à créer) | `cpp/editor/network/` |

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
5. **Le script fait le gameplay via les capacités autorisées.** Les écritures de
   configuration durable suivent une transaction d'édition. Les mutations d'état
   runtime deviennent des intentions adressées à l'hôte, puis des mises à jour à
   sémantique « dernier état » vers les pairs. Elles ne sont pas undoables au
   grain de l'écriture. La cadence, la fiabilité et le format sont à trancher.
   En posture « exécution locale », la source cliente transite tout de même vers
   l'hôte pour arbitrage, mais elle n'est ni broadcastée ni exécutée chez les
   autres pairs (doc 04).
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
  (doc 04) et aux validateurs de capacités. Voir doc 00 §8.

## 6. Chantiers dérivés (aperçu, non planifiés ici)

- Combler la **divergence hooks ↔ tools MCP** (des hooks existent sans tool MCP).
- Ajouter des capacités **runtime** (piloter le joueur/NPC en jeu, pas seulement
  poser dans l'éditeur) — absentes en V2.
- Ajouter **l'introspection d'état** (lister les tuiles par uuid/type/position,
  énumérer les enums valides) requise par une boucle perception→action.

Ces manques sont documentés en détail dans le doc 02 (§capacités manquantes).
