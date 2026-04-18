# 🐱 Meownopoly — Le changelog qui ronronne (par mois)

Bienvenue dans **l’histoire officielle (en mode fun)** du projet : on a croisé l’historique Git, les merges qui font *plouf* entre branches, et la réalité GitHub. Spoiler : **zéro PR fusionnée** sur le dépôt public, mais **1063 commits** et une équipe qui ne dort visiblement pas.

**Dépôt :** [github.com/antoinnneee/meownopoly](https://github.com/antoinnneee/meownopoly) — né le **2025-01-31**, branche par défaut **`main`**.

**Hall of fame Git (`git shortlog -sn --all`) :** antoinnneee, Valere21, Antoine bureau — merci à vous, les matous du code.

---

## 📡 GitHub, PR et la CLI `gh`

| Élément | La vérité (sans filtre) |
|--------|-------------------------|
| **Pull requests** | **Aucune** côté API GitHub. Ici on merge comme en 1999… enfin presque : **branches** (`V2`, `V2Antoine`, `V2_Valou`, `valouV2`, etc.) et pushes, pas le bouton vert « Squash and merge ». |
| **Issues** | Au moins une issue ouverte : [#1 « meow »](https://github.com/antoinnneee/meownopoly/issues/1) — priorité absolue, évidemment. |
| **Graphique contributeurs GitHub** | Souvent **sous-estimé** : `main` traîne parfois derrière les branches de dev. GitHub voit une partie du film ; Git local, le director’s cut. |

**Quand les PR débarqueront**, `gh` pourra enfin sortir des numéros traçables `(#42)` :

```bash
gh pr list --state merged --limit 200 --json number,title,mergedAt,author,labels,body
gh issue list --state all
gh repo view antoinnneee/meownopoly --json defaultBranchRef,url
```

*(Après `gh auth login`, sinon `gh` fait la tête.)*

---

## 📊 Activité par mois — le baromètre des commits

Période **très calme** : **février → juin 2025** (le plateau faisait probablement la sieste).

| Mois | Commits | Merges `Merge*` |
|------|--------:|----------------:|
| 2025-01 | 1 | 0 |
| 2025-03 | 6 | 0 |
| 2025-07 | 99 | 31 |
| 2025-08 | 193 | 33 |
| 2025-09 | 144 | 15 |
| 2025-10 | 160 | 23 |
| 2025-11 | 83 | 8 |
| 2025-12 | 114 | 4 |
| 2026-01 | 63 | 4 |
| 2026-02 | 146 | 20 |
| 2026-03 | 52 | 7 |
| 2026-04 | 2 | 0 |

\* Messages qui commencent par `Merge` — intégrations de branches, pas des tickets GitHub.

---

## 2025 — L’année où le plateau a appris à marcher

### Janvier 2025

- **Premier commit** (`first commit`, 31 janvier) : le big bang Meownopoly. Le capitalisme félin était encore un embryon.

### Février à juin 2025

- **Silence radio** dans Git — soit pause saine, soit labo secret. Le Monopoly des chats méditait.

### Mars 2025

- **Gameplay & IA** : l’ordinateur commence à jouer (et à nous juger).
- **Animations & UI** : plus joli, plus vivant ; un commit avoue qu’un truc a « cassé » au nettoyage — **tradition respectée**.

### Juillet 2025 — 99 commits, 31 merges (été productif)

- **Éditeur de plateau** : cases, tuiles, déplacements, infos — le sandbox prend forme.
- **Données & C++/QML** : liste chaînée / modèle Meownopoly, `CasePerks`, `RestArea`, `intToCaseType()`… le vocabulaire devient sérieux.
- **QoL** : `.gitignore`, tests JSON/QML, et une **symphonie de merges** entre `V2` / `V2Antoine` / `valou`.

### Août 2025 — 193 commits (record d’endorphines)

- **Éditeur pro** : panneaux modulaires, assets, filtres, `AssetManager`, JSON qui devient carte.
- **Effets visuels** : décorations qui tournent, se mirent, et se la pètent.
- **Carte & fond** : `MapInfo`, échelles, éditeur ↔ jeu — tout tient ensemble (enfin, souvent).

### Septembre 2025

- **Carte & fonds** : menus au démarrage, grilles, transparence, ScrollView qui arrête de faire des siennes.
- **Save / Load** : panneaux dédiés, musique et fond dans `MapInfo`.
- **Éditeur** : sélection plus propre, preview de cases, effets qui se propagent correctement.

### Octobre 2025 — Ctrl+Z devient un sport de haut niveau

- **Undo / redo** : `UndoRedoManager` entre en scène ; l’éditeur peut enfin dire « oups ».
- **Autosave** : intervalles, debounce sur `saveMap`, options UI — moins de larmes perdues.
- **Sélection** : rectangle magique, liens entre éléments, grille affinée.
- **Structure** : QML rangé (`component` / `ui_item`), effets de pions, connexions zigzag qui font le show.

### Novembre 2025

- **Panneau latéral** : `EditorSidePanel` redimensionnable et animé — le bureau du game designer.
- **3D & launcher** : modèles 3D, caméra / grille, souris un peu moins rebelle.
- **Zones d’exclusion** : polygones, `MouseLogic` qui passe un CAPTCHA.
- **Autosave 2.0** : rythme plus régulier, moins « à chaque frappe » ; undo/redo qui suit le tempo.

### Décembre 2025 — physique, templates, modules

- **Moteur physique 2D** : `PhysicsZone2D`, `ZoneParameter`, `PattounX`, collisions multi-segments, CCD pour les cercles — la gravité du fun.
- **Templates de carte** : briques réutilisables + doc — « copier-coller » niveau artisan.
- **Modules QML** : `meowComponent`, `UiStyle` ; Linux et la casse des chemins ont été **gentiment** recadrés.
- **Navigation carte** : barre, version / date, champs en lecture seule pour les autosaves — on sait *quoi* on ouvre.

---

## 2026 — Chat, Catway, et le réseau qui miaule en UDP

### Janvier 2026

- **Templates (PH1–PH4)** : édition, drag de groupe, persistance… puis **retrait** des templates de l’éditeur — l’expérience qui finit en « on recommence autrement » (ultra sain).
- **Chat multijoueur** : serveur, historique, images WebP, MP, messages éphémères, `PING`/`PONG`, kick hôte, mots de passe hashés.
- **HTTPS** + `ChatClient` sur thread worker — les WebSockets en tenue de soirée.
- **Compte local** : clés persistées côté client.
- **Physique & UI** : zones affinées, `MapInfoDrawer`, panneaux d’effets moins grincheux.

### Février 2026 — Catway : le tunnel sous l’Atlantique, mais en P2P

- **Catway / P2P** : UDP, STUN, hole punching, lib fiable, `CatwayWorker`, anti-spoofing, heartbeat.
- **Sessions** : lobby, création, listing DB, `sessionId`, qui est l’hôte, sync dessin UDP.
- **Chat + jeu** : intégration `ChatClient` / Catway, file de commandes, création de session en base revue de fond en comble.
- **Docs & outillage** : `PROJECT_STRUCTURE`, archi éditeur, protocole WebSocket, CMake, Android OpenSSL — la paperasse qui sauve des nuits blanches.

### Mars 2026

- **Réseau de jeu** : session multijoueur, sync minigame, tests réseau, rebroadcast UDP (chat UI parfois coupée pour les tests — *shh*).
- **Éditeur & Catway** : `/create`, `requestCreateItem`, éléments snapables depuis le chat — l’éditeur et Catway se font des câlins protocolaires.
- **Fiabilité** : paquets fiables, worker refactoré, erreurs mieux gérées, docs sur mots de passe invalides.
- **Qualité** : `==` sur items / maps, skip save si rien n’a bougé, singleton DB, ménage `ChatDatabase` / Catway.

### Avril 2026 (en cours)

- **Réseau** : hole punching, handlers chat, UTF-8 fiable, refactor STUN / `Catway`, commentaires QML un peu moins mystiques.
- **Ménage** : commit « clean project » — le équivalent d’aspirer avant d’inviter le monde.

---

## ⚠️ Ruptures & déploiement (sans étiquettes PR)

Pas de labels `breaking` GitHub à citer, mais après un gros `git pull`, **testez** surtout : **`Catway` / STUN / UDP fiable**, **physique 2D**, et tout ce qui touchait aux **templates** retirés. Migrations DB non centralisées ici ; chat / sessions suivent les scripts et URLs du repo.

---

## 🎲 Fun fact du projet

GitHub affiche **0 PR fusionnée**, alors que Git enregistre **des centaines de merges** — comme un restaurant avec zéro avis Google mais une file devant la porte. Le jour où les PR arriveront, `gh` pourra distribuer des `(#numéros)` comme des cartes Pokémon. Jusque-là, ce fichier reste la **source de vérité** — avec un peu plus de miaulements.
