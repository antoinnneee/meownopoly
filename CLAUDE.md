# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Meownopoly is a networked board game (Monopoly-inspired, cat-themed) built with Qt6/QML and C++20. It includes a map editor, P2P multiplayer via UDP hole punching, a WebSocket chat system, and a custom 2D physics engine. The project language (code comments, docs, conventions) is primarily French.

## Branching

- **V2** : branche principale de développement (équivalent de main pour le travail actif)
- **V2Antoine** : branche de travail d'Antoine
- **V2_Valou** : branche de travail de Valère
- Les deux développeurs mergent dans V2 une fois leur travail stabilisé

## Build Commands

```bash
# Configure (from repo root)
cd Meownopoly && cmake -B ../build -G Ninja -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build ../build

# Run
../build/Meownopoly.exe
```

Requires: CMake 3.21+, Ninja, Qt6 (Core, Quick, Qml, Widgets, QuickControls2, Network, WebSockets, Sql, Quick3D, Concurrent).

No automated test runner is configured. Manual testing via the executable.

## Architecture

### Threading Model
- **GUI thread**: QML UI + `Catway` singleton (network orchestrator)
- **Network thread**: `CatwayWorker` handles UDP I/O, STUN, heartbeats
- Cross-thread communication uses `Qt::BlockingQueuedConnection` for socket setup and `Qt::QueuedConnection` for async events

### Networking (Catway)
- P2P via UDP hole punching with STUN server discovery
- `reliable.io` library provides ACK-based reliability over UDP (magic byte `0x01` prefix)
- Heartbeats (`HP:PING`) every 10s to maintain NAT holes
- C callbacks bridge `reliable.io` into Qt's signal/slot system
- Key classes: `Catway`, `CatwayWorker`, `PlayerNetwork`, `StunManager`

### Chat System
- Client: C++ WebSocket (`ChatClient`) in `cpp/chat/`
- Server: Node.js + SQLite in `chatServer/`
- Protocol: JSON commands (JOIN_SESSION, SEND_MSG, GET_HISTORY)
- End-to-end encrypted blind relay (server never sees plaintext)

### Map Editor
- `GridManager` renders configurable grids; `ItemSnapable` is the base class for placeable elements
- Modular panel system with prefix naming: `CCP_` (case config), `ASP_` (asset), `VEP_` (visual effects)
- Selection uses AABB rectangles with multi-select support
- Undo/redo with full state management, autosave with debouncing

### Game Logic
- `Case` hierarchy: `CasePerks`, `CaseRestArea`, `CaseCatDoor`, `CaseJail`, `CaseCardBoardBox`
- `CaseFactory` creates instances by type
- 4-phase turn system: action pre-move, move, action post-move, wait
- Coproperty system (shared ownership), anonymous auctions (blind bidding)
- Maps stored as JSON

### Physics
- Custom 2D engine ("PattounX") in `cpp/game/physics/`
- `PhysicsZone2D` + `ZoneParameter` define interaction volumes
- Circle collision with continuous collision detection (CCD)

## Key Patterns

- **Singletons**: `Catway`, `AssetManager`, `MapFileManager`, `Launcher` — registered as QML singletons
- **C++/QML bridge**: `Q_PROPERTY` for data binding, `Q_INVOKABLE` for method calls
- **Resource files**: `qml.qrc`, `asset.qrc`, `base_comp.qrc`, `chat.qrc`, `launcher.qrc`, `other.qrc`

## QML Conventions

- Root `id`: `root` by default, or a semantic role name
- Files: `PascalCase.qml`; editor panels prefixed (`CCP_`, `ASP_`, `VEP_`)
- Internal properties prefixed with `_`
- Signals: `camelCase`, often suffixed `Requested` or `Changed`
- Use `root.` prefix in children to avoid binding ambiguity
- Use `const`/`let` (not `var`) in JS functions
- Reusable components in `ui_item/`, board elements in `meowComponent/`, logic in `board/logic/` or `editor/logic/`
- Base types prefixed `Base_` (e.g., `Base_Board`, `Base_logic`)

## Directory Layout

- `Meownopoly/cpp/` — C++ source (game logic, networking, chat, assets, physics, editor)
- `Meownopoly/qml/` — QML UI (editor, board, chat, menu, launcher, account, components)
- `Meownopoly/doc/` — Comprehensive project documentation (40+ files)
- `Meownopoly/config/` — Configuration files
- `chatServer/` — Node.js WebSocket chat server with SQLite
- `asset_server/` — Node.js HTTP asset distribution server
- `image_tools/` — Image processing utilities

## External Documentation

Extensive docs exist in `Meownopoly/doc/` — check `doc/INDEX.md` for the full index and `doc/QUICK_START.md` for navigation. Key architecture docs:
- `doc/architecture/P2P_NETWORK_ARCHITECTURE.md` — Catway/networking details
- `doc/architecture/ANALYSE_ARCHITECTURE_EDITEUR.md` — Editor architecture (detailed)
- `doc/architecture/CATWAY_ARCHITECTURE.md` — P2P/UDP communication
- `doc/architecture/PROJECT_STRUCTURE.md` — Code organization
