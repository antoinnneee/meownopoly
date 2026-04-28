# Plan d'implémentation — Panel de configuration des joueurs (éditeur de map)

> Statut : **Plan v3** — finalisé après arbitrage des 6 questions.
> Branche : `V2Antoine`.
> Changements clés vs v2 : `pickMode` est maintenant **par profil** (enum `Unique | Shared | Mandatory`) avec `minOccurrences` ; UI panel scindée en deux : **min/max dans `MapInfoDrawer` vue Cartes**, **roster dans bottom panel `AssetSelectionPanel` 5e onglet** ; prefix `PCP_`.
>
> ### Avancement (mise à jour 2026-04-29)
> - ✅ **Phase 0** — nettoyage `MapInfoDrawer` (double imports + qmldir mort).
> - ✅ **Phase 1** — `PlayerProfile` + extension `MapInfo` (roster, min/max, version, helpers, JSON, clamping).
> - ✅ **Phase 2a** — SpinBox min/max joueurs dans `MapInfoDrawer` (vue Cartes).
> - ✅ **Phase 3** — `AssetManager::availablePlayerModels()` (QRC + AppData + primitives).
> - ✅ **Phase 2b** — 5e onglet "Joueurs" + 11 composants `PCP_*`. Drag & drop horizontal **différé** : remplacé en v1 par boutons `←/→` dans l'overlay des cards.
> - ✅ **Phase 4** — collab editor : ops 12-16 (`AddPlayerProfile`/`RemovePlayerProfile`/`UpdatePlayerProfile`/`ReorderPlayerProfile`/`SetMapPlayerLimits`), helpers `EditorOpBus.make*Op`, apply remote dans `Editor.qml`, écritures `PCP_*` + `MapInfoDrawer` re-routées via `submitOp`. La borne `isEditorPacket` n'a **pas** été modifiée : elle filtre `EditorMessageType` (0x20+), pas `EditorOpType` — les ops 12-16 transitent via `EditorMessageType::Op` (0x23) déjà couvert. Test 2 instances (`dual_test_p2p`) restant.
> - ⏳ **Phase 5** — migration & persistance (fallback "Princess" sur roster vide à la création de partie).
> - ⏳ **Phase 6** — documentation (CLAUDE.md + ANALYSE_ARCHITECTURE_EDITEUR).

---

## 1. Objectif & sémantique

Ajouter dans l'éditeur la configuration des joueurs possibles sur une map :

1. **Limites globales — indicatives** (vue **Cartes** du `MapInfoDrawer`) : `minPlayers` et `maxPlayers` (placeholder `max=8`, augmentable techniquement). Affichées en lobby pour info, **pas de check bloquant** côté `GameSession`.
2. **Roster de profils choisissables** (5e onglet **"Joueurs"** du `AssetSelectionPanel`) : liste de `PlayerProfile`. Chaque joueur **choisit son profil** au lancement de la partie.

**Chaque profil porte** :
- **Visuel** : `modelName` (dossier 3D, picker des modèles `qrc:/asset/models/` **ET** `AppData/models/`).
- **Mode de sélection** (`pickMode` — enum à 3 valeurs **par profil**) :
  - **`Unique`** : un seul joueur peut prendre ce profil. Pas obligatoire.
  - **`Shared`** : plusieurs joueurs peuvent prendre ce profil. Pas obligatoire.
  - **`Mandatory`** : doit être pris par **au moins** `minOccurrences` joueurs pour démarrer la partie. **Au-delà** du quota, d'autres joueurs peuvent aussi le prendre (cardinality `Shared`-like).
- **`minOccurrences`** (int, défaut `1`) : utilisé uniquement si `pickMode == Mandatory`. Stocké pour tous les profils (zéro-cost), ignoré sinon.
- **Physiques (mode simple)** : taille (`radius`), poids (`mass`), vitesse (`maxSpeed`).
- **Physiques (mode expert)** : tous les paramètres + **presets** ("Standard", "Léger", "Lourd", "Glissant", "Adhérent").

> ### Hypothèses de design issues du Q&A (final)
> - Profils ≠ spawn tiles (pas de nouveau `TileType`).
> - Fallback : si `playerProfiles` vide au runtime, créer automatiquement un profil "Princess" par défaut.
> - Pas d'undo/redo sur les profils en v1.
> - Pas de différenciation visuelle (couleur/teinte) en v1.
> - Preview 3D miniature dans le picker : **design à demander à l'utilisateur** au moment de l'implémenter.
> - Pas de check bloquant `minPlayers`/`maxPlayers` au runtime (indicatif).
> - **Mandatory + autres possibilités** : un profil Mandatory peut être pris par plus de joueurs que `minOccurrences` ; le quota est un floor, pas un cap.

---

## 2. Décisions de design

### 2.1 Stockage : sur `MapInfo`
Cohérent avec `mapName`, `musicPath`. Pas de `TileType`.

### 2.2 Op bus collab : ops granulaires (5)
| ID | Nom | Champs |
|---|---|---|
| 12 | `AddPlayerProfile` | `profile: {...}` complet |
| 13 | `RemovePlayerProfile` | `id` |
| 14 | `UpdatePlayerProfile` | `id`, `fields: {...}` (partiel — couvre `pickMode`, `minOccurrences`, etc.) |
| 15 | `ReorderPlayerProfile` | `id`, `newIndex` |
| 16 | `SetMapPlayerLimits` | `minPlayers?`, `maxPlayers?` (pas de `pickMode` global ici) |

> **Gotcha critique** (cf. CLAUDE.md) : `EditorProtocol::isEditorPacket` filtre par plage `>= Hello && <= <dernier type>`. Mettre à jour la borne à 16.

### 2.3 Versioning de la config
Nouvelle propriété `int playerConfigVersion` sur `MapInfo`. Bumpée à chaque changement de schéma. Au load, `version > courant` → log warning + roster vidé + recréation profil "Princess" (cassure assumée — confirmé par le user).

### 2.4 Catalogue de modèles
Source double : built-in (`qrc:/asset/models/`) **et** téléchargés (`AppData/models/`). Nouveau `Q_INVOKABLE QStringList AssetManager::availablePlayerModels()`.

### 2.5 Pas de modification du moteur physique
Au runtime, `LocalPlayerSpawner.params` est peuplé depuis le `PlayerProfile` choisi.

---

## 3. Modèle de données (C++)

### 3.1 Nouvelle classe `PlayerProfile`
**Fichier** : `Meownopoly/cpp/game/map/playerprofile.{h,cpp}`

```cpp
class PlayerProfile : public QObject {
    Q_OBJECT
public:
    enum class PickMode : int {
        Unique    = 0,
        Shared    = 1,
        Mandatory = 2
    };
    Q_ENUM(PickMode)

private:
    Q_PROPERTY(QString  id              READ id              CONSTANT)             // UUID stable
    Q_PROPERTY(QString  name            READ name            WRITE setName            NOTIFY nameChanged)
    Q_PROPERTY(QString  modelName       READ modelName       WRITE setModelName       NOTIFY modelNameChanged)
    Q_PROPERTY(PickMode pickMode        READ pickMode        WRITE setPickMode        NOTIFY pickModeChanged)
    Q_PROPERTY(int      minOccurrences  READ minOccurrences  WRITE setMinOccurrences  NOTIFY minOccurrencesChanged)
    // Physics
    Q_PROPERTY(qreal radius          READ radius          WRITE setRadius          NOTIFY radiusChanged)
    Q_PROPERTY(qreal mass            READ mass            WRITE setMass            NOTIFY massChanged)
    Q_PROPERTY(qreal acceleration    READ acceleration    WRITE setAcceleration    NOTIFY accelerationChanged)
    Q_PROPERTY(qreal maxSpeed        READ maxSpeed        WRITE setMaxSpeed        NOTIFY maxSpeedChanged)
    Q_PROPERTY(qreal linearDamping   READ linearDamping   WRITE setLinearDamping   NOTIFY linearDampingChanged)
    Q_PROPERTY(qreal staticFriction  READ staticFriction  WRITE setStaticFriction  NOTIFY staticFrictionChanged)
    Q_PROPERTY(qreal dynamicFriction READ dynamicFriction WRITE setDynamicFriction NOTIFY dynamicFrictionChanged)
    Q_PROPERTY(qreal bounceFactor    READ bounceFactor    WRITE setBounceFactor    NOTIFY bounceFactorChanged)

public:
    explicit PlayerProfile(QObject *parent = nullptr);              // génère UUID + defaults
    explicit PlayerProfile(const QJsonObject &j, QObject *p=nullptr); // restore depuis JSON

    QJsonObject toJSON() const;
    void applyJson(const QJsonObject &j);

    Q_INVOKABLE void applyPreset(const QString &presetName);        // "Standard","Léger",...
    Q_INVOKABLE QStringList availablePresets() const;

    static void registerQml();
};
```

**Bornes & défauts** :

| Param | Min | Max | Default | Step | Mode UI |
|---|---|---|---|---|---|
| `radius` | 0.1 | 1.5 | 0.4 | 0.05 | simple ("taille") |
| `mass` | 0.1 | 10.0 | 1.0 | 0.1 | simple ("poids") |
| `maxSpeed` | 50 | 800 | 300 | 10 | simple ("vitesse") |
| `acceleration` | 5 | 100 | 30 | 1 | expert |
| `linearDamping` | 0.0 | 1.0 | 0.1 | 0.05 | expert |
| `staticFriction` | 0.0 | 2.0 | 0.4 | 0.05 | expert |
| `dynamicFriction` | 0.0 | 2.0 | 0.2 | 0.05 | expert |
| `bounceFactor` | 0.0 | 1.0 | 0.1 | 0.05 | expert |
| `minOccurrences` | 1 | 8 | 1 | 1 | conditionnel (visible si `Mandatory`) |

**Clamping** :
- `setMinOccurrences` clampe à `[1, MAX_PLAYERS_HARD_CAP]` (= 8 v1).
- `setPickMode(Mandatory)` : si `minOccurrences < 1`, le force à 1.

**Presets proposés** :
- **Standard** : tous défauts.
- **Léger / agile** : radius 0.3, mass 0.5, accel 50, maxSpeed 450, damping 0.05.
- **Lourd / inertiel** : radius 0.55, mass 3.0, accel 15, maxSpeed 200, damping 0.2.
- **Glissant** : friction 0.1 / 0.05, damping 0.0, bounce 0.5.
- **Adhérent** : friction 1.5 / 1.0, damping 0.5, bounce 0.0.

> Les presets ne touchent pas `pickMode`/`minOccurrences`/`name`/`modelName` — uniquement les paramètres physiques.

### 3.2 Extension de `MapInfo`
**Fichier** : `Meownopoly/cpp/game/map/mapinfo.{h,cpp}`

```cpp
Q_PROPERTY(int minPlayers READ minPlayers WRITE setMinPlayers NOTIFY minPlayersChanged)        // default 2
Q_PROPERTY(int maxPlayers READ maxPlayers WRITE setMaxPlayers NOTIFY maxPlayersChanged)        // default 8
Q_PROPERTY(int playerConfigVersion READ playerConfigVersion WRITE setPlayerConfigVersion NOTIFY playerConfigVersionChanged)  // default 1
Q_PROPERTY(QQmlListProperty<PlayerProfile> playerProfiles READ playerProfilesQml NOTIFY playerProfilesChanged)

Q_INVOKABLE PlayerProfile* addPlayerProfile();                       // crée + ajoute, retourne le profil
Q_INVOKABLE PlayerProfile* addPlayerProfileFromJson(const QString &json);
Q_INVOKABLE PlayerProfile* duplicatePlayerProfile(const QString &id);   // copie sauf id (nouveau UUID)
Q_INVOKABLE void           removePlayerProfile(const QString &id);
Q_INVOKABLE bool           updatePlayerProfile(const QString &id, const QString &fieldsJson);  // partial
Q_INVOKABLE bool           reorderPlayerProfile(const QString &id, int newIndex);
Q_INVOKABLE PlayerProfile* playerProfileById(const QString &id) const;
Q_INVOKABLE int            playerProfileCount() const;
Q_INVOKABLE PlayerProfile* playerProfileAt(int i) const;
Q_INVOKABLE void           clearPlayerProfiles();

static constexpr int MAX_PLAYERS_HARD_CAP = 8;   // placeholder, augmentable
```

**Clamping** :
- `setMinPlayers` clampe à `[1, maxPlayers]`.
- `setMaxPlayers` clampe à `[max(1, minPlayers), MAX_PLAYERS_HARD_CAP]`.

> **Gotcha** : `QQmlListProperty<PlayerProfile>` non itérable directement depuis JS — helpers `playerProfileAt/Count` obligatoires.

### 3.3 Sérialisation JSON
**`MapInfo::toJSON()`** ajoute :
```json
{
  "playerConfigVersion": 1,
  "minPlayers": 2,
  "maxPlayers": 8,
  "playerProfiles": [
    {
      "id": "uuid",
      "name": "Princess",
      "modelName": "Princess",
      "pickMode": "Unique",          // "Unique" | "Shared" | "Mandatory"
      "minOccurrences": 1,
      "radius": 0.4, "mass": 1.0,
      "acceleration": 30.0, "maxSpeed": 300.0,
      "linearDamping": 0.1,
      "staticFriction": 0.4, "dynamicFriction": 0.2,
      "bounceFactor": 0.1
    }
  ]
}
```

**Migration** :
- Clés absentes → defaults appliqués.
- `playerConfigVersion` absent → considéré 0, migré silencieusement.
- `playerConfigVersion > courant` → log warning + roster vidé + recréation profil "Princess".

---

## 4. UI (QML)

### 4.1 Pré-PR : nettoyage `MapInfoDrawer` (petit refactor isolé)
**Fichier** : `Meownopoly/qml/editor/panel/mapInfoPanel/MapInfoDrawer.qml` (1370 lignes).

À nettoyer :
1. **Double bloc d'imports** lignes 1-12 + 14-25 → garder un seul.
2. **`qmldir` ligne 4** référence un `MapSidePanel.qml` inexistant → supprimer.

> L'extraction des vues Cartes/Background dans `MIP_*` séparés (proposée v2) **n'est plus nécessaire** vu que la 3e vue n'est plus dans le drawer. Reportée à un éventuel refactor ultérieur indépendant.

### 4.2 Phase 2a : ajout min/max dans la vue "Cartes" du `MapInfoDrawer`
**Fichier modifié** : `Meownopoly/qml/editor/panel/mapInfoPanel/MapInfoDrawer.qml`

Dans le `GridLayout` ligne 417 (qui contient déjà nom/version/dates), ajouter en bas deux lignes éditables :

```
┌─ Map name (lecture seule) ───┐
├─ Version (lecture seule) ────┤
├─ Created (lecture seule) ────┤
├─ Modified (lecture seule) ───┤
├─ Min joueurs    [SpinBox] ──┤    ← NOUVEAU
└─ Max joueurs    [SpinBox] ──┘    ← NOUVEAU
```

Pattern : SpinBox styled comme les autres éléments. Édition via mutation directe + `Game.updateMapMetadata(before, after)` (pattern déjà utilisé pour `backgroundScaling` ligne 963-967, `isBackgroundOnGrill` ligne 884-889, etc.).

### 4.3 Phase 2b : 5e onglet "Joueurs" dans `AssetSelectionPanel`
**Fichier modifié** : `Meownopoly/qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/AssetSelectionPanel.qml`
- Ajouter `PCP_Content` au `StackLayout` (5e enfant, index 4).

**Fichier modifié** : `Meownopoly/qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/ASP_TitleBar.qml`
- Étendre `buttonModel: ["Decoration", "Case", "Zones", "Scène", "Joueurs"]`.

### 4.4 Layout du panel — design retenu

Le panel adopte un layout **rangée horizontale de cards** (à la "character select") + **panneau de détail en dessous** qui apparaît à la sélection d'une card. Inspiré du mockup user (rangée de classes type select screen).

> **Convention de tailles** : aucune taille en pixels fixes. On utilise `Screen.pixelDensity` (pixels/mm en Qt6, déjà utilisé ailleurs dans le repo, voir `MapInfoDrawer.qml:41`) pour exprimer les dimensions en mm/cm. Les sliders, paddings et fonts utilisent soit `Screen.pixelDensity * X`, soit des proportions de leur conteneur (`parent.width * 0.8`, etc.). La card a une **largeur min de 3 cm** = `Screen.pixelDensity * 30`.

```
┌─ PCP_Content ───────────────────────────────────────────────────────┐
│  ┌─ PCP_ProfileRow (Flickable horizontal, hauteur ~5 cm) ────────┐  │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────────┐         │  │
│  │  │      │  │      │  │      │  │      │  │    +     │         │  │
│  │  │ 3D   │  │ 3D   │  │ 3D   │  │ 3D   │  │          │         │  │
│  │  │      │  │      │  │      │  │      │  │ Ajouter  │         │  │
│  │  │ ===  │  │      │  │      │  │      │  │  une     │         │  │
│  │  ├──────┤  ├──────┤  ├──────┤  ├──────┤  │ classe   │         │  │
│  │  │Princ.│  │Voleur│  │Garde │  │Roi   │  └──────────┘         │  │
│  │  └──────┘  └──────┘  └──────┘  └──────┘                       │  │
│  │   ↑                                                            │  │
│  │   sélectionnée (highlight border)                              │  │
│  └────────────────────────────────────────────────────────────────┘  │
│  ┌─ PCP_ProfileDetail (visible seulement si une card sélectionnée)─┐ │
│  │  ┌─ Nom (TextField inline) ─┐ ┌─ ModelPicker (Combo) ──────────┐│ │
│  │  └──────────────────────────┘ └─────────────────────────────────┘│ │
│  │  ┌─ PickModeSelector ───────────────────────────────────────────┐│ │
│  │  │ ◉ Unique  ○ Shared  ○ Mandatory   minOccurrences: [1] ▲▼   ││ │
│  │  └──────────────────────────────────────────────────────────────┘│ │
│  │  ┌─ Tabs [Simple] [Expert] ────────────────────────────────────┐│ │
│  │  │ Simple : sliders Taille / Poids / Vitesse                   ││ │
│  │  │ Expert : Presets row + 8 sliders                            ││ │
│  │  └──────────────────────────────────────────────────────────────┘│ │
│  └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

#### Card de profil (`PCP_ProfileCard`)
- **Dimensions** : portrait, largeur **min 3 cm** (`Screen.pixelDensity * 30`), ratio largeur:hauteur ≈ 1 : 1.6 → hauteur ≈ 5 cm. À ajuster selon la hauteur disponible du bottom panel : la card peut grandir proportionnellement si plus de place, mais jamais en dessous de 3 cm de large.
- **Contenu** :
  - **Preview 3D** (View3D mini, fond transparent) — model chargé depuis `<AppData>/models/<modelName>/<modelName>.qml` ou QRC. Occupe ~75% de la hauteur de la card.
  - **Nom** en bas (~25% de la hauteur), **éditable inline** au double-clic (TextField) ; sinon Label. Font scalable (`Screen.pixelDensity * 3` ≈ 3 mm de haut).
  - **Badge `pickMode`** en coin haut-gauche : `U` (Unique), `S` (Shared), `M×N` (Mandatory ×N joueurs).
  - **Overlay au survol** (icônes coin haut-droit) : ⎘ Dupliquer, ✕ Supprimer.
- **Sélection** : clic simple sélectionne la card (border highlight bleu, comme `border.color: "#4A90E2"` du drawer). La sélection conditionne l'affichage du `PCP_ProfileDetail` en dessous.
- **Drag & drop** : drag latéral horizontal pour réordonner.

#### Card "Ajouter" (`PCP_AddProfileCard`)
- **Dimensions** : identiques aux cards profil (largeur min 3 cm, ratio 1 : 1.6).
- **Contenu** : un gros `+` jaune centré + label "Ajouter une classe" en dessous.
- **Comportement** : clic appelle `MapInfo.addPlayerProfile()`, sélectionne automatiquement le nouveau profil (qui ouvre le panneau de détail prêt à éditer).
- Toujours en dernière position de la rangée.

### 4.5 Composants `PCP_*` — fichiers
**Localisation** : `Meownopoly/qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/`

| Fichier | Rôle |
|---|---|
| `PCP_Content.qml` | Racine de l'onglet ; ColumnLayout = `ProfileRow` + `ProfileDetail`. Tient l'`id` du profil sélectionné. |
| `PCP_ProfileRow.qml` | Flickable horizontal contenant les `ProfileCard` + `AddProfileCard` final. Drag & drop horizontal. |
| `PCP_ProfileCard.qml` | Vignette d'une classe : preview 3D, nom éditable inline, badge pickMode, overlay actions. |
| `PCP_AddProfileCard.qml` | Card "+ Ajouter une classe" en queue de rangée. |
| `PCP_ProfileDetail.qml` | Panneau d'édition de la classe sélectionnée. Visible seulement si selection non-nulle. |
| `PCP_PickModeSelector.qml` | RadioButton group 3 choix (Unique/Shared/Mandatory) + SpinBox `minOccurrences` (visible si Mandatory). |
| `PCP_ModelPicker.qml` | ComboBox modèle (alimenté par `AssetManager.availablePlayerModels()`). |
| `PCP_PhysicsSimpleSection.qml` | 3 sliders : taille / poids / vitesse. |
| `PCP_PhysicsExpertSection.qml` | Boutons presets + 8 sliders complets. |
| `PCP_PresetButtons.qml` | Row de boutons de presets. |
| `PCP_Profile3DPreview.qml` | View3D miniature pour la card (réutilisé éventuellement par le détail). |

**Pattern de binding** : flag `_updatingValues` côté QML pour éviter les boucles ; mutation via `EditorOpBus.submitOp(...)` (Phase 4) ou mutation directe + `Game.updateMapMetadata` (Phase 2 transition).

**Drag & drop** : pattern QML standard (`Drag.active`, `DropArea`), drag latéral ; appelle `MapInfo.reorderPlayerProfile(id, newIndex)` à la fin.

**Bouton "Dupliquer"** : icône ⎘ dans l'overlay au survol → `MapInfo.duplicatePlayerProfile(id)`.

**Édition du nom inline** : double-clic sur le label de la card → swap Label↔TextField. Submit par Enter ou perte de focus → `EditorOpBus.submitOp(makeUpdatePlayerProfileOp(id, { name: newName }))` (Phase 4) ou mutation directe (Phase 2).

> **Décisions design issues du mockup** (à confirmer pendant l'implémentation) :
> - Preview 3D : View3D miniature avec un model statique non-animé (rotation lente optionnelle au survol). Le user a précédemment demandé "redemande moi le design" pour la preview — version proposée ici, à valider en revue visuelle.
> - Hauteur de la rangée : adaptative selon le bottom panel (qui dépend de `selectionPanel.isExpanded`). `PCP_ProfileRow.height` peut être bindé à `Math.max(Screen.pixelDensity * 50, parent.availableHeight * 0.5)` ; cards remplissent la hauteur disponible avec leur ratio 1:1.6 (ou minimum 3 cm).
> - Pas de panneau de détail si rien de sélectionné → message d'invitation ("Sélectionnez une classe ou ajoutez-en une") ou simplement un espace vide.
> - Au lancement de l'éditeur avec roster vide, la rangée n'affiche que la card "+ Ajouter".
> - Toutes les tailles (paddings, spacing, fonts, sliders width…) doivent être exprimées via `Screen.pixelDensity` ou en proportions du parent. **Aucun pixel fixe.**



### 4.5 Catalogue de modèles
**Modif** : `Meownopoly/cpp/asset/assetmanager.{h,cpp}`

```cpp
Q_INVOKABLE QStringList availablePlayerModels() const;
```

Implémentation :
1. Scanner `qrc:/asset/models/` (built-in via `QDirIterator` sur QRC).
2. Scanner `<AppData>/models/` (téléchargés).
3. Filtrer : ne retient que les dossiers contenant un `<name>.qml`.
4. Dédupliquer par nom (priorité QRC).

---

## 5. Op bus collaboratif

### 5.1 Nouveaux types d'op
**Fichier modifié** : `Meownopoly/cpp/editor/ops/editor_op_type.h`
```cpp
AddPlayerProfile      = 12,   // fields: { profile: { id, name, modelName, pickMode, minOccurrences, ... } }
RemovePlayerProfile   = 13,   // fields: { id }
UpdatePlayerProfile   = 14,   // fields: { id, fields: { mass: 1.5, pickMode: "Mandatory", minOccurrences: 2, ... } }
ReorderPlayerProfile  = 15,   // fields: { id, newIndex }
SetMapPlayerLimits    = 16,   // fields: { minPlayers?, maxPlayers? }
```

> **Gotcha critique** : étendre la borne `EditorProtocol::isEditorPacket` à 16 + commentaire `editor_protocol.cpp`.

### 5.2 Helpers `EditorOpBus`
**Fichier modifié** : `Meownopoly/cpp/editor/ops/editor_op_bus.{h,cpp}`
```cpp
Q_INVOKABLE QJsonObject makeAddPlayerProfileOp(const QJsonObject &profile) const;
Q_INVOKABLE QJsonObject makeRemovePlayerProfileOp(const QString &id) const;
Q_INVOKABLE QJsonObject makeUpdatePlayerProfileOp(const QString &id, const QJsonObject &fields) const;
Q_INVOKABLE QJsonObject makeReorderPlayerProfileOp(const QString &id, int newIndex) const;
Q_INVOKABLE QJsonObject makeSetMapPlayerLimitsOp(const QJsonObject &fields) const;
```

### 5.3 Apply remote
**Fichier modifié** : `Meownopoly/qml/editor/Editor.qml` (handler `Connections` sur `EditorOpBus.remoteOpReceived`).

```qml
case 12: { // AddPlayerProfile
    EditorOpBus.beginApplyRemote()
    MapFileManager.currentMap.mapInfo.addPlayerProfileFromJson(JSON.stringify(op.fields.profile))
    EditorOpBus.endApplyRemote()
    break
}
case 13: { // RemovePlayerProfile
    EditorOpBus.beginApplyRemote()
    MapFileManager.currentMap.mapInfo.removePlayerProfile(op.fields.id)
    EditorOpBus.endApplyRemote()
    break
}
case 14: { // UpdatePlayerProfile
    EditorOpBus.beginApplyRemote()
    MapFileManager.currentMap.mapInfo.updatePlayerProfile(
        op.fields.id, JSON.stringify(op.fields.fields || {}))
    EditorOpBus.endApplyRemote()
    break
}
case 15: { // ReorderPlayerProfile
    EditorOpBus.beginApplyRemote()
    MapFileManager.currentMap.mapInfo.reorderPlayerProfile(op.fields.id, op.fields.newIndex)
    EditorOpBus.endApplyRemote()
    break
}
case 16: { // SetMapPlayerLimits
    EditorOpBus.beginApplyRemote()
    const f = op.fields || {}
    const mi = MapFileManager.currentMap.mapInfo
    if ('minPlayers' in f) mi.minPlayers = f.minPlayers
    if ('maxPlayers' in f) mi.maxPlayers = f.maxPlayers
    EditorOpBus.endApplyRemote()
    break
}
```

### 5.4 Full sync (Phase 4 du collab editor)
La Phase 4 envoie déjà `Map.toJSON()`. `MapInfo` étendue suit naturellement, sous réserve de bumper `isEditorPacket`.

### 5.5 Undo/redo
**Pas d'undo en v1**. Les ops 12-16 utilisent `submitOp` (pas `submitOpWithUndo`).

---

## 6. Intégration runtime (hors panel — pour mémoire)

À traiter dans des PRs ultérieures :
1. **Lobby pré-partie** : UI de choix de profil par joueur, avec respect de :
   - `pickMode === Unique` → désactive le profil dès qu'un joueur l'a pris,
   - `pickMode === Shared` → toujours disponible,
   - `pickMode === Mandatory` → bouton "Lancer" grisé tant que `count(joueurs ayant ce profil) < minOccurrences`. Au-delà, profil reste sélectionnable (cardinality Shared-like).
2. **`World3D.modelName`** ← `profile.modelName`.
3. **`LocalPlayerSpawner.params`** ← `{ acceleration, maxSpeed, mass, linearDamping, staticFriction, dynamicFriction, bounceFactor }` du profil.
4. **`LocalPlayerSpawner.radius`** ← `profile.radius`.
5. **Validation `minPlayers`/`maxPlayers`** : indicatif uniquement, pas de check bloquant.
6. **Fallback "Princess"** : si `playerProfiles` vide à la création de partie, en injecter un par défaut sans modifier la map.

---

## 7. Phasage

### Phase 0 — Pré-PR refactor (petite, isolée)
- [ ] `MapInfoDrawer.qml` : supprimer le double bloc d'imports.
- [ ] `mapInfoPanel/qmldir` : supprimer la ligne morte `MapSidePanel`.

### Phase 1 — Modèle de données + sérialisation (1 PR)
- [ ] `PlayerProfile.{h,cpp}` (Q_PROPERTY, enum `PickMode`, presets, JSON, registerQml).
- [ ] Extension `MapInfo` (Q_PROPERTY min/max/playerConfigVersion + helpers `add/remove/update/reorder/duplicate` + JSON + clamping).
- [ ] Test manuel : éditer `mapInfo.minPlayers = 5` depuis QML console, save, reload → valeur persistée.

### Phase 2a — UI : min/max dans `MapInfoDrawer` (1 PR)
- [ ] 2 SpinBox (`minPlayers`, `maxPlayers`) dans le `GridLayout` de la vue Cartes.
- [ ] Pattern `Game.updateMapMetadata(before, after)` (collab via op 16 ajoutée Phase 4).

### Phase 3 — Catalogue modèles (1 PR, à faire **avant** Phase 2b)
- [ ] `AssetManager::availablePlayerModels()` (scan QRC + AppData).
- [ ] Test manuel : appel depuis QML console retourne la liste des dossiers `models/`.

> **Dépendance** : la Phase 2b consomme cette API à la fois dans le ComboBox `PCP_ModelPicker` et dans la preview 3D `PCP_Profile3DPreview` (chargement du `<modelName>.qml`).

### Phase 2b — UI : 5e onglet "Joueurs" + sous-composants (1 PR)
- [ ] 5e bouton dans `ASP_TitleBar.buttonModel`.
- [ ] `PCP_Content` + ~11 sous-composants `PCP_*` (cf. §4.5).
- [ ] **Layout rangée horizontale** : `PCP_ProfileRow` + `PCP_AddProfileCard` en queue.
- [ ] **Card vignette** : `PCP_Profile3DPreview` View3D mini + nom inline éditable + badge pickMode + overlay actions.
- [ ] **Panneau de détail** `PCP_ProfileDetail` conditionnel à la sélection.
- [ ] Drag & drop horizontal sur `PCP_ProfileRow`.
- [ ] Bouton "Dupliquer" en overlay sur `PCP_ProfileCard`.
- [ ] **Pas encore d'op bus** : édition locale via mutations directes + `Game.updateMapMetadata`.

### Phase 4 — Collab editor (1 PR)
- [ ] 5 ops `AddPlayerProfile`...`SetMapPlayerLimits` + helpers `EditorOpBus`.
- [ ] Borne `EditorProtocol::isEditorPacket` mise à jour.
- [ ] Apply remote dans `Editor.qml`.
- [ ] Re-router toutes les écritures du panel via `EditorOpBus.submitOp`.
- [ ] Test à 2 instances (`dual_test_p2p`).

### Phase 5 — Persistance & migration
- [ ] Maps existantes (sans `playerProfiles`) chargent avec defaults.
- [ ] Au save, si roster vide → injecter automatiquement profil "Princess".
- [ ] `playerConfigVersion` bumpé à 1.

### Phase 6 — Documentation
- [ ] CLAUDE.md : section "Editor Collaboratif" → ops 12-16 listées + "gap connu : pas d'undo profils".
- [ ] `doc/architecture/ANALYSE_ARCHITECTURE_EDITEUR.md` : section "Roster joueurs".

---

## 8. Risques & gotchas

| # | Risque | Mitigation |
|---|---|---|
| 1 | Plage `EditorProtocol::isEditorPacket` non étendue → ops 12-16 droppées | Bumper à 16 + commentaire `editor_protocol.cpp`. |
| 2 | `QQmlListProperty<PlayerProfile>` non itérable depuis JS | Helpers `playerProfileAt/Count` obligatoires. |
| 3 | Mutation in-place de `playerProfiles` ne réveille pas les bindings | Émettre `playerProfilesChanged` après chaque add/remove/reorder/duplicate. |
| 4 | Boucle signal-binding lors d'`apply remote` | Pattern `beginApplyRemote/endApplyRemote`. |
| 5 | Drag & drop ListView : `move` ne déclenche pas `playerProfilesChanged` automatiquement | `reorderPlayerProfile` C++ émet le signal explicitement. |
| 6 | Concurrence collab : 2 users updatent le même profil simultanément | LWW grossier (la dernière `UpdatePlayerProfile` gagne). Acceptable v1. |
| 7 | Modèle 3D introuvable au runtime (dossier supprimé) | `World3D.qml` a déjà fallback `#Cube` ; logger warning au load. |
| 8 | `PickMode` enum côté QML : `PlayerProfile.Unique` / `Shared` / `Mandatory` | Q_ENUM expose les valeurs. UI utilise ButtonGroup ou SegmentedButton. |
| 9 | `minOccurrences` édité alors que `pickMode != Mandatory` | UI cache la SpinBox sauf si Mandatory ; valeur persiste en JSON. |
| 10 | Sérialisation JSON casse map ancienne | `playerConfigVersion > courant` → wipe + Princess + warning. Acceptable. |
| 11 | `pickMode` enum sérialisé en string (lisibilité humaine) vs int | String préférée pour debug/diff JSON. Setter accepte les deux. |

---

## 9. Checklist de tests manuels

### Vue "Cartes" du `MapInfoDrawer`
- [ ] SpinBox `minPlayers` / `maxPlayers` éditables ; clamping `min ≤ max ≤ 8`.
- [ ] Save → reload → valeurs persistées.

### 5e onglet "Joueurs" (bottom panel)
- [ ] Onglet visible et cliquable.
- [ ] **Rangée horizontale** des cards visible, scroll horizontal si débordement.
- [ ] Card "+ Ajouter une classe" toujours en queue de rangée ; clic ajoute un profil et le sélectionne.
- [ ] **Card profil** : preview 3D s'affiche, nom en bas, badge `pickMode` en haut-gauche.
- [ ] **Édition inline du nom** au double-clic ; submit Enter / blur OK.
- [ ] **Overlay au survol** : icônes ⎘ Dupliquer / ✕ Supprimer fonctionnelles.
- [ ] **Sélection** : clic highlight la card, ouvre `PCP_ProfileDetail` en dessous.
- [ ] Si rien sélectionné, `PCP_ProfileDetail` masqué (ou message "Sélectionnez une classe").
- [ ] **Drag & drop horizontal** : réordonner les cards, persistance après reload.
- [ ] **Dupliquer** : crée un clone avec nouvel UUID, mêmes paramètres.
- [ ] **PickMode** : RadioButton Unique / Shared / Mandatory ; SpinBox `minOccurrences` visible seulement en Mandatory.
- [ ] ComboBox modèle alimentée par les dossiers réels (QRC + AppData) ; changement met à jour la preview 3D de la card.
- [ ] Mode **Simple** : 3 sliders (taille / poids / vitesse).
- [ ] Mode **Expert** : presets + 8 sliders ; clic preset met à jour les sliders en live, sans toucher pickMode/minOccurrences/name/modelName.
- [ ] Save → reload → état restauré identique.

### Migration / persistance
- [ ] Charger une map ancienne (sans `playerProfiles`) → ne crash pas, defaults appliqués.
- [ ] Charger une map avec `playerConfigVersion` futur → wipe + Princess + warning.

### Collab
- [ ] 2 instances (`dual_test_p2p`), modif côté A se voit côté B en < 1 s (toutes ops).
- [ ] Client rejoint en cours → reçoit roster via Phase 4 full sync.
- [ ] 2 users modifient simultanément 2 profils différents → pas d'écrasement mutuel.
- [ ] Modif min/max joueurs sur instance A reflétée sur B.
- [ ] **Migration hôte** (Phase 8 collab editor) : édition de profil par hôte sortant + élection nouvel hôte → état préservé.

---

## 10. Fichiers touchés (résumé)

### Nouveaux
- `cpp/game/map/playerprofile.h`
- `cpp/game/map/playerprofile.cpp`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_Content.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_ProfileRow.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_ProfileCard.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_AddProfileCard.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_ProfileDetail.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_PickModeSelector.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_ModelPicker.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_PhysicsSimpleSection.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_PhysicsExpertSection.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_PresetButtons.qml`
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/playerConfigPanel/PCP_Profile3DPreview.qml`

### Modifiés
- `cpp/game/map/mapinfo.h` / `mapinfo.cpp` — Q_PROPERTY min/max/playerConfigVersion/roster + JSON + helpers (incl. `duplicatePlayerProfile`).
- `cpp/asset/assetmanager.h` / `assetmanager.cpp` — `availablePlayerModels()`.
- `cpp/editor/ops/editor_op_type.h` — 5 nouveaux types (12-16).
- `cpp/editor/ops/editor_op_bus.h` / `editor_op_bus.cpp` — 5 helpers `make*Op`.
- `cpp/editor/network/editor_protocol.cpp` — borne plage `isEditorPacket` à 16.
- `qml/editor/panel/mapInfoPanel/MapInfoDrawer.qml` — nettoyage double imports + ajout 2 SpinBox min/max dans GridLayout vue Cartes.
- `qml/editor/panel/mapInfoPanel/qmldir` — supprimer ligne morte `MapSidePanel`.
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/AssetSelectionPanel.qml` — 5e enfant StackLayout.
- `qml/editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel/ASP_TitleBar.qml` — 5e bouton `buttonModel`.
- `qml/editor/Editor.qml` — cases 12-16 dans `Connections` apply remote.
- `qml.qrc` — référencer les nouveaux QML.
- `CLAUDE.md` — section "Editor Collab" : ops 12-16 + "gap connu : pas d'undo profils".

---

## 11. Arbitrages finaux (référence)

| # | Question | Choix retenu |
|---|---|---|
| 1 | `mandatory` bool ou compteur ? | `int minOccurrences` (compteur, défaut 1, utilisé seulement si `Mandatory`) |
| 2 | `pickMode` global ou par profil ? | **Par profil**, enum 3 valeurs `Unique` / `Shared` / `Mandatory`. Au-delà du quota Mandatory, le profil reste sélectionnable (cardinality Shared-like). |
| 3 | Refactor `MapInfoDrawer` | Mini-PR Phase 0 (juste nettoyage qmldir + double imports). Pas d'extraction de vues (plus nécessaire). |
| 4 | Prefix de nommage | **`PCP_`** (Player Config Panel) |
| 5 | Position 3e onglet | min/max dans `MapInfoDrawer` vue Cartes ; **roster en 5e onglet du bottom panel `AssetSelectionPanel`** |
| 6 | Bouton "Dupliquer" | **Oui** en v1, en overlay au survol de la card |
| 7 | Layout du panel | **Rangée horizontale** de cards (vignettes 3D portrait) + card "+ Ajouter" en queue + panneau de détail en dessous, conditionnel à la sélection. Inspiré du mockup user (character select). |
| 8 | Édition du nom | **Inline** dans la card (double-clic Label → TextField). |
| 9 | Preview 3D | View3D miniature dans chaque card (proposition à valider en revue visuelle). |
