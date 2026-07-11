# 01 — Architecture cible

> **Statut : cadrage (draft).** Vue d'ensemble des briques V3 et de leurs flux.
> Détail par brique dans les docs 02→05.

## 1. Schéma d'ensemble

```
┌───────────────────────────────────────────────────────────────────────────┐
│  MACHINE DU JOUEUR                                                          │
│                                                                             │
│   ┌───────────────┐        skill (installée)        ┌───────────────────┐  │
│   │   Son IA      │◀───────────────────────────────▶│  Fichier de skill │  │
│   │ (modèle       │   décrit les capacités du jeu    │  (doc 03)         │  │
│   │  client)      │                                  └───────────────────┘  │
│   └──────┬────────┘                                                         │
│          │  WebSocket LOCAL dédié IA↔jeu (loopback)  ── doc 02              │
│          ▼                                                                   │
│   ┌──────────────────────────────────────────────────────────────────────┐ │
│   │  MEOWNOPOLY (process Qt)                                              │ │
│   │                                                                       │ │
│   │   ┌──────────────┐   ┌───────────────────┐   ┌────────────────────┐  │ │
│   │   │ Canal IA     │──▶│ Bac à sable QML   │──▶│ Scène QML / Éditeur │  │ │
│   │   │ (serveur WS) │   │ (sandbox, doc 04) │   │ (Editor.qml, World3D)│ │ │
│   │   └──────┬───────┘   └───────────────────┘   └─────────┬──────────┘  │ │
│   │          │  actions de haut niveau                     │             │ │
│   │          ▼                                              ▼             │ │
│   │   ┌────────────────────────────────────────────────────────────────┐ │ │
│   │   │ Pipeline de mutation existant :                                │ │ │
│   │   │  Game.updateMap → EditDelta → EditorOpBus/EditorSession        │ │ │
│   │   │  ItemSnapable (+ espace mémoire, doc 05) → persistance JSON     │ │ │
│   │   └────────────────────────────────────────────────────────────────┘ │ │
│   │                              │ collab / réseau                        │ │
│   └──────────────────────────────┼───────────────────────────────────────┘ │
└──────────────────────────────────┼─────────────────────────────────────────┘
                                    ▼  Catway (P2P UDP) vers les autres joueurs
```

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
Chaque `ItemSnapable` gagne un **blob JSON libre** que l'IA écrit pour
personnaliser un élément (données custom : « loyer ×2 », état, paramètres d'un
comportement généré). Transporté **gratuitement** par le pipeline `EditDelta`/
`ApplyState` existant → persistance, undo/redo et sync collab sans nouveau canal.

### 2.5 Moteur de règles (doc 06) & Bibliothèque (doc 07)
Différés. Placés dans l'architecture pour réserver leur emplacement : le moteur de
règles consommera l'espace mémoire + le QML génératif ; la bibliothèque
capitalisera les créations et/ou fournira des primitives réutilisables.

## 3. Réutilisation du socle V2 (points d'ancrage réels)

| Brique V3 | S'appuie sur (V2) | Fichiers |
|-----------|-------------------|----------|
| Canal IA | `AutomationServer` (protocole, loopback, dispatch) | `cpp/automation/automation_server.{h,cpp}` |
| Actions éditeur | hooks `editorAutomationHooks` (pose, caméra, save) | `qml/editor/Editor.qml` (bloc ~l.2633+) |
| Skill client | MCP + tools + `AUTOMATION_API.md` | `automation_mcp/`, `doc/architecture/AUTOMATION_API.md` |
| Espace mémoire | `ItemSnapable` + `toJSON`/`applyJson` | `cpp/game/item_snapable/ItemSnapable.{h,cpp}` |
| Sync du blob | `EditDelta` + op `ApplyState` + `Game.updateMap` | `cpp/game/map/editdelta.h`, `cpp/game/game_loader.cpp`, `cpp/editor/ops/editor_op_bus.{h,cpp}` |
| Runtime piloté | `PhysicsSession`, `World3D`, `InputController` | `cpp/game/physics/`, `qml/world3d/` |
| Réseau/collab | Catway, `EditorSession` host-authoritative | `cpp/communication/`, `cpp/editor/network/` |

## 4. Flux type — « l'IA ajoute un élément avec comportement custom »

1. Le joueur décrit l'intention à son IA.
2. L'IA appelle des commandes de haut niveau sur le **canal WS** (doc 02) :
   `place*`, puis écrit l'**espace mémoire** de la tuile (doc 05).
3. Pour un comportement non couvert par une primitive, l'IA envoie un **artefact
   QML** ; le **sandbox** (doc 04) le valide et l'instancie, rattaché à la tuile.
4. Les mutations passent par `Game.updateMap` → `EditDelta` → `EditorOpBus` :
   persistées, undoables, **broadcastées aux autres joueurs** (avec la réserve
   « réplication du QML génératif » à trancher, cf. doc 04 §sécurité et doc 08).
5. L'IA **observe** le résultat (lecture d'état / screenshot via le canal) et
   itère.

## 5. Frontières & responsabilités

- **Le jeu ne raisonne pas** : il expose des capacités et applique des garde-fous.
  Le raisonnement (traduire l'intention → séquence d'actions) est côté IA client.
- **Le canal ne fait pas de gameplay** : il traduit des commandes vers les
  pipelines existants. Pas de règle métier dans le transport.
- **Le sandbox ne fait pas confiance** : tout artefact QML est hostile par défaut.
- **L'espace mémoire n'a pas de schéma imposé côté cœur** : c'est un blob libre ;
  le sens des clés est une convention IA/règles (doc 05/06), pas du C++.

## 6. Chantiers dérivés (aperçu, non planifiés ici)

- Combler la **divergence hooks ↔ tools MCP** (des hooks existent sans tool MCP).
- Ajouter des capacités **runtime** (piloter le joueur/NPC en jeu, pas seulement
  poser dans l'éditeur) — absentes en V2.
- Ajouter **l'introspection d'état** (lister les tuiles par uuid/type/position,
  énumérer les enums valides) requise par une boucle perception→action.

Ces manques sont documentés en détail dans le doc 02 (§capacités manquantes).
