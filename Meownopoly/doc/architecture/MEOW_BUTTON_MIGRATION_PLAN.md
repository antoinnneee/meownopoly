# Plan de migration — Unification des boutons sur `MeowButton`

> Statut : **✅ TERMINÉ** (Phases 0 à 3) — mergé dans V2Antoine
> (merge `3a98bfe`, 7 commits, ≈ −557 lignes nettes). Build Release vert +
> validation visuelle via le serveur d'automation MCP.
> Objectif : unifier au maximum les styles de boutons de l'application autour
> du composant générique `qml/ui_item/MeowButton.qml`, en réduisant la
> duplication de `background` / `contentItem` éparpillée dans le code.
>
> Cf. la section [Réalisation](#réalisation--bilan) en fin de document pour le
> bilan détaillé et l'API effective de `MeowButton`.

## Contexte

`MeowButton` a été créé dans `qml/ui_item/` (module `ui_item`) : bouton
générique reprenant le style de l'ancien `ParticleButton` **sans** les
particules — fond `baseColor` avec états down/hover/disabled, brillance,
feedback de scale au clic, léger zoom au survol. Personnalisation rapide via
`baseColor` / `textColor` ; `background` et `contentItem` restent
surchargeables. `ParticleButton` hérite désormais de `MeowButton` et n'ajoute
que l'émetteur de particules. Les 8 boutons de `TitleScreen.qml` ont déjà été
migrés (commit `d1c20f0`, branches V2 / V2Antoine).

S'inscrit dans la continuité du kit générique `Meow*` — cf.
`EDITOR_GENERIC_UI_KIT_PLAN.md`.

## Inventaire de l'existant

Recensement (hors `qml/test/` et hors `qml/ui_item/`) :

| Catégorie | Nombre | Migration |
|---|---|---|
| `Button` Qt bruts (background/contentItem redéfinis) | ~113 | Cible principale |
| Wrappers custom `Button` (StyledButton, PCP_StyledButton, ClearButtons, BackButton…) | ~9 | **Levier maximal** (1 fichier ⇒ N appels) |
| `ParticleButton` applicatifs | 4 | Simplifier (garder particules) |
| `ToolButton` icône-seule (Material) | 8 | Hors scope (→ futur `MeowIconButton`) |
| `PawSubButton` / `PawMainPad` (menu radial) | 2 | Exclus (forme/comportement propres) |

**Découverte clé** : migrer les **wrappers custom** propage le style à des
dizaines d'appels d'un coup. C'est le vrai point d'appui de la migration.

### Wrappers custom recensés

| Composant | Chemin | Parent | Remplacement |
|---|---|---|---|
| `StyledButton` | `qml/launcher/StyledButton.qml` | Button | `variant` / `baseColor` |
| `PCP_StyledButton` | `qml/editor/.../PCP_StyledButton.qml` | Button | `variant: "primary"` (accent) |
| `ASP_ClearButton` | `qml/editor/.../ASP_ClearButton.qml` | Button | `variant: "danger"` + `iconText: "✕"` |
| `CSP_ClearButton` | `qml/editor/.../CSP_ClearButton.qml` | Button | idem |
| `EBP_BackButton` | `qml/editor/.../EBP_BackButton.qml` | Button | `variant: "ghost"` + `iconText: "←"` |
| `MenuSelector_Button` | `qml/editor/.../MenuSelector_Button.qml` | Button | À évaluer (animation + couleurs hardcodées) |

### ParticleButton applicatifs

- `qml/multiplayer/SessionList.qml:156` — "➕ Créer une Session" (`#E67E22`)
- `qml/multiplayer/SessionCreation.qml:725` — "✨ Créer" (couleur dynamique)
- `qml/multiplayer/SessionDetails.qml:276` — "Rejoindre la Partie" (success)
- `qml/editor/panel/mapInfoPanel/MapInfoDrawer.qml:349` — sauvegarde carte (vert)

---

## Phase 0 — Enrichir `MeowButton` *(prérequis)* — ✅ FAIT (`6729943`)

Couvrir les besoins réels relevés avant toute migration de masse, pour ne pas
re-toucher ~100 appels deux fois.

**API cible (`qml/ui_item/MeowButton.qml`) :**

- `property string variant: "primary"` →
  `"primary" | "secondary" | "danger" | "warning" | "success" | "ghost"`.
  Mappe vers `baseColor` + couleur texte par défaut (via `Theme`).
  Un `baseColor` explicite reste prioritaire (override).
- `property int fontSize: Theme.fontSizeLarge` — beaucoup d'appels utilisent
  `fontSizeTitle` / `fontSizeBody`.
- `property string iconText: ""` — support icône emoji/unicode (cas très
  fréquent : "🔄", "← Back", "✕ Clear"). `contentItem` par défaut devient un
  `Row { [icône] [label] }` rendu conditionnel.
- `variant: "ghost"` — fond transparent au repos, coloré au hover/press
  (remplace les `flat: true` des boutons back/clear).
- *(optionnel)* `property bool loading: false` — `BusyIndicator` + `enabled:false`
  pendant une action async.

**Sortie :** `MeowButton` capable de remplacer 1:1 les boutons stylés standards.
Validation `qmllint -I qml` + validation visuelle MCP.

**Risque :** modifier le `contentItem` par défaut ne casse pas les appels qui le
surchargent (l'override reste possible) ; on ne touche que le défaut.

> **Réalisé** — toutes les props ci-dessus livrées, plus **deux ajouts** non
> prévus mais nécessaires :
> - `property bool hoverZoom: true` / `property bool glossy: true` — à passer
>   à `false` dans les grilles/formulaires denses (le zoom au survol chevauchait
>   les voisins, la brillance alourdissait les petits boutons plats).
> - **Dimensionnement basé sur le contenu** : l'ancien `width:150; height:50`
>   **en dur** empêchait les wrappers compacts (StyledButton h=30, ClearButtons
>   content-sized) d'hériter sans surcharger les deux dimensions. Remplacé par
>   du padding (`spacingXXL`/`spacingM`) + `implicitWidth`/`implicitHeight`
>   dérivés du contenu (surchargeables via `width`/`height`/Layout).
>
> Le harnais `TEST_MEOW_BUTTON.qml` n'a pas été créé : la validation s'est faite
> directement sur les écrans réels via le serveur d'automation MCP.

---

## Phase 1 — Simplifier les 4 `ParticleButton` applicatifs — ✅ FAIT (`3742a98`)

Fichiers : `SessionList.qml:156`, `SessionCreation.qml:725`,
`SessionDetails.qml:276`, `MapInfoDrawer.qml:349`.

- Ils restent des `ParticleButton` (particules conservées sur ces actions
  « marquantes »).
- Supprimer leur `background` Rectangle redéfini au profit de `baseColor:`
  (maintenant que `ParticleButton` hérite de `MeowButton`).
- Supprimer les `contentItem` redondants si la Phase 0 couvre la taille de
  police voulue (sinon garder `fontSize:`).

**Sortie :** ~4 boutons, ~−120 lignes, style unifié. Build + run + vérif
visuelle du lobby.

---

## Phase 2 — Statuer sur `ParticleButton` *(arbitrage)* — ✅ DÉCIDÉ : option A

Options envisagées :

- **A. (retenue)** Conserver `ParticleButton` pour 4-5 actions clés
  (créer/rejoindre partie, sauvegarder carte), `MeowButton` partout ailleurs.
  Les particules deviennent un signal d'« action principale ».
- B. Tout passer en `MeowButton`, réserver les particules à 1 seul CTA.
- C. Ajouter `property bool particles: false` directement sur `MeowButton` et
  supprimer `ParticleButton` (fusion). Plus simple à l'usage mais charge
  `QtQuick.Particles` partout.

**Décision actée — option A.** Motif : la fusion (C) chargerait
`QtQuick.Particles` dans tous les écrans utilisant un bouton, pour un effet
réservé à une poignée d'actions ; garder `ParticleButton` (qui hérite de
`MeowButton`) comme sous-classe spécialisée évite ce coût et fait des particules
un marqueur explicite d'« action principale ». Les 4 `ParticleButton` restants
(SessionList/Creation/Details, MapInfoDrawer) ne redéfinissent plus de
`background`/`contentItem` — ils ne portent que `baseColor`/`variant`/`fontSize`
+ les props de particules. Note reportée dans la mémoire `project-editor-ui-kit`.

---

## Phase 3 — Migrer les `Button` bruts vers `MeowButton` — ✅ FAIT (`f54c46c`→`df1d059`)

Stratégie « wrappers d'abord » (levier maximal), par lots, avec build + run
entre chaque lot. Lot A = `f54c46c`, Lot B = `88b32c3`, Lot C = `47a9465`,
Lot D = `925e657`, Lot E = `df1d059`.

1. **Lot A — Re-baser les wrappers custom** sur `MeowButton`
   (1 fichier migré ⇒ N appels stylés) :
   - `launcher/StyledButton.qml` (`primary`/`danger`/`accentColor` → `variant`/`baseColor`)
   - `editor/.../PCP_StyledButton.qml` (`accent`)
   - `ASP_ClearButton.qml`, `CSP_ClearButton.qml` (`variant:"danger"` + `iconText:"✕"`)
   - `EBP_BackButton.qml` (`variant:"ghost"` + `iconText:"←"`)
2. **Lot B — Account** (5 boutons) — écran isolé, faible risque.
3. **Lot C — Launcher** (boutons inline restants après StyledButton).
4. **Lot D — Editor** : EscMenu / MenuMapAtStart / MapInfoDrawer /
   MapNavigationBar (~30).
5. **Lot E — multiplayer** (3 boutons simples) + MeowComponent / game.

**Hors scope explicite (documenté, non migré) :**

- 8 `ToolButton` icône-seule → éventuel `MeowIconButton` séparé (phase
  ultérieure optionnelle), pas `MeowButton`.
- `PawSubButton` / `PawMainPad` (menu radial) → exclus.
- `MenuSelector_Button` (animation + couleurs hardcodées) → à évaluer au cas par
  cas (lot final ou exclu).

**Sortie :** ~80 boutons unifiés, wrappers réduits, plus aucune fuite de style
Qt par défaut dans les écrans applicatifs.

---

## Exécution & garde-fous

- **1 commit par lot/phase** sur une branche worktree dédiée.
- Build Release vert + run + vérification visuelle avant chaque commit
  (convention du repo).
- `qmllint -I qml` systématique (les warnings sur modules C++ `Game`/`Account`
  sont des faux positifs connus).
- Merge vers V2Antoine puis V2 + push à la fin, ou par phase pour une livraison
  incrémentale.
- Mise à jour de la mémoire `project-editor-ui-kit` à chaque jalon.

## Estimation (ordre de grandeur)

| Phase | Charge |
|---|---|
| Phase 0 (enrichir) | ~½ journée |
| Phase 1 (4 ParticleButton) | rapide |
| Phase 2 (arbitrage) | trivial |
| Phase 3 (migration de masse) | le gros, par lots |

---

## Réalisation — bilan

Migration livrée en **7 commits** sur `worktree-meow-button-migration`, mergée
dans V2Antoine (merge `3a98bfe`, `--no-ff`, sans conflit). **26 fichiers,
≈ +489 / −1046 lignes** (≈ −557 nettes). Build Release vert ; chaque lot validé
visuellement via le serveur d'automation MCP (titre, lobby, formulaire création,
launcher, menu Échap éditeur + « Charger carte », popup Paramètres du compte).

### API effective de `MeowButton`

| Propriété | Rôle |
|---|---|
| `variant` | `primary`\|`secondary`\|`danger`\|`warning`\|`success`\|`ghost` → `baseColor` + `textColor` par défaut |
| `baseColor` / `textColor` | override direct (prioritaire sur `variant`) |
| `fontSize` | défaut `Theme.fontSizeLarge` |
| `iconText` | icône emoji/unicode à gauche du libellé (Row centrée) |
| `loading` | `BusyIndicator` + `enabled:false` |
| `hoverZoom` | défaut `true` ; `false` dans les grilles/formulaires denses |
| `glossy` | défaut `true` ; `false` pour un rendu plat |

`ghost` = fond transparent au repos, bordure `borderLight`→`baseColor` au survol.
Dimensionnement basé sur le contenu (padding + `implicit*`), surchargeable.

### Patterns retenus (réutilisables pour la suite)

- **Libellé dynamique** → mettre la logique sur la propriété `text` (lue par le
  `contentItem` par défaut) plutôt que de redéfinir un `contentItem`.
- **Propager une taille via `font.pixelSize`** (API `Button` historique) dans un
  wrapper → `fontSize: control.font.pixelSize`, avec un défaut
  `font.pixelSize: Theme.fontSizeBody`.
- **Toggles** (segmented, vue caméra, onglets) → garder `checked` bindé et
  piloter `baseColor: cond ? accent : neutre`, `hoverZoom:false`/`glossy:false`.

### Wrappers re-basés (Lot A)

`launcher/StyledButton`, `PCP_StyledButton`, `ASP_ClearButton`,
`CSP_ClearButton`, `EBP_BackButton` héritent désormais de `MeowButton` et
conservent leur API historique (`primary`/`danger`/`accent`/`accentColor`).

### Hors-scope, conservés en `Button` brut (→ futur `MeowIconButton`)

Boutons **icône-seule** : reset axe `↺`, reload `↻`, fermetures `✕`/« x »,
suppression `🗑️`, refresh `🔄`, chevrons `◀▶`/`▼▲` ; `BackButton`
(`multiplayer/components`, Rectangle + « ← ») ; **segmented / filtres** :
`MenuSelector_Button`, delegate d'onglets de `ModelConfigurator`,
`EBP_FilterButton` ; `ToolButton` Material ; `PawSubButton`/`PawMainPad` (menu
radial) ; `TestCommandWindow` (fenêtre de debug réseau). Ces cas relèvent d'un
futur composant `MeowIconButton` dédié, hors de ce plan.

### Suite possible

- Créer `MeowIconButton` (carré, icône centrée, sans libellé) pour absorber les
  boutons icône-seule listés ci-dessus.
- Réévaluer les contrôles « segmented » (`MenuSelector_Button`, onglets) pour un
  éventuel `MeowSegmentedControl`.
