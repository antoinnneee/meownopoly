# Color ID Map — Plan d'intégration (re-skinning runtime par zone)

> Statut : **plan validé, implémentation démarrée (Phase A)** (2026-06-05).
> Décisions structurantes tranchées avec l'utilisateur (cf. §3).
> Source externe portée : `kura_qt_viewer` (repo ArmorPaint, **hors de ce repo**) —
> doc de référence : `COLOR_ID_MAP.md`, `NOTES_SYSTEME_TEXTURE.md`,
> `kura_qt_viewer/README.md` côté armorpaint.
>
> **⚠️ RÉVISION 2026-06-05b — On adopte le format kuraViewer tel quel et on
> ABANDONNE balsam.** Les modèles sont distribués en `.glb` et chargés au
> runtime via `RuntimeLoader` + `overrideMaterials` (exactement comme kura),
> et non plus via balsam → `.qml` + `Loader3D`. Conséquences : plus d'injection
> de matériau par regex dans un `.qml`, plus de marker transform dans le `.qml`
> (transform → manifest), et **un seul `KuraMaterial.qml` + `tint.frag`
> partagés** dans l'app (qrc) au lieu d'un codegen par modèle. Cf. D1/D7/D8
> révisés et §4-§7.

## 1. Objectif

Intégrer le système **Color ID Map** d'ArmorPaint (re-teinte + re-texture d'un
personnage **par zone**, à chaud, sans bake offline) dans :

1. le **configurateur de modèle 3D** du launcher (`ModelConfigurator.qml`) — pour
   que l'auteur définisse les zones, la bibliothèque de textures et des
   **variantes** (presets) ;
2. le **rendu in-game** (`World3D`) — pour que **chaque joueur** affiche le skin
   et la variante qu'il a choisis ;
3. le **format de paquet `.meow`** — pour que skins + variantes voyagent avec le
   modèle (distribution via l'asset_server, et à terme upload par les joueurs).

Cas d'usage moteur : **équipes** matérialisées par une **teinte de zone** (les
zones marquées « équipe » par l'auteur prennent la couleur d'équipe au runtime).

**On casse volontairement les formats précédents** (pas de compat ascendante).

## 2. Rappel du système source (Color ID Map)

- Une **color ID map** est une texture qui partage les UV du mesh ; chaque **zone
  logique** y est peinte d'une **couleur plate unique** issue d'une palette de 20
  IDs (Van der Corput, contrastes maximaux). Ce n'est **pas** un index dans le
  canal R : le décodage compare la couleur lue à la palette par **distance
  euclidienne** : `m = step(distance(idSample, RAW_IDS[i]), 0.15)`.
- **Pièges absolus** : la map est en **linéaire brut (PAS sRGB)** et samplée en
  **Nearest + sans mipmaps + ClampToEdge** (sinon couleurs fantômes aux
  frontières et décalage de comparaison).
- **Modèle de composition empilé** (cf. `tint.frag`) :
  ```
  base color (la peau)
    → teinte globale du skin (baseTint / mode / strength)   [visible hors zones]
    → pour chaque zone qui matche (m=1), on REPART de la base color et on remplace :
         couche texture : tex = (inv ? 1-pat : pat) * texTint ; zone = mix(base, tex, texOpacity)
         couche teinte  : zone = mix(zone, apply_tint(zone, tint, mode), tintStrength)
       result = mix(result, zone, m)
  → BASE_COLOR (PBR : ROUGHNESS/METALNESS fixes pour la démo)
  ```
- **3 modes de teinte** `apply_tint(c, color, mode)` : `0` Aplat (`color`), `1`
  Multiply (`c*color`, garde le détail), `2` Overlay (recolore en gardant le relief).
- **Architecture d'assets source** : `base/`(glb + skin_base.png) +
  `skins/<skin>/`(colorMap.png + skin.json + textures/ + variants/). Une texture
  appartient à la **bibliothèque du skin**, pas à un slot : chaque zone choisit
  `["Aucune", …bibliothèque…]`.
- **Limite samplers (D3D11)** : 16 samplers/étage, Qt Quick3D en réserve ~3 →
  **~11 textures max**. Les zones restent toutes *teintables* (0 sampler).

## 3. Décisions d'architecture (verrouillées)

| # | Sujet | Décision (révisée 2026-06-05b) |
|---|-------|----------|
| D1 | Où s'applique le CustomMaterial | **`RuntimeLoader` (.glb) + `overrideMaterials`** comme kura : on parcourt l'arbre chargé et on assigne un `KuraMaterial` à chaque `Model`. ~~Injection dans le `.qml`~~ abandonnée (plus de `.qml` de modèle). Les 3 sites de rendu partagent ce pattern via un composant `KuraModel.qml` réutilisable. |
| D2 | Zones (statique) vs teinte (joueur) | **base + skins + variantes packagés dans le `.meow`** (auteur, format kura). **Choix joueur** (skin + variante + override équipe) dans `PlayerProfile`. |
| D3 | Forme du choix joueur | `PlayerProfile.colorVariant` = **string JSON** (`{ skin, variant, teamColor? }`), défaut `""` = neutre. |
| D4 | Teinte d'équipe | **Zones marquées par l'auteur** (`team:true` dans `skin.json`). Au runtime, la couleur d'équipe surcharge ces zones (couche teinte, **0 sampler**). |
| D5 | Budget zones/textures | **20 zones teintables + ~8 zones texturées max** (marge sûre sous D3D11). |
| D6 | Portée multijoueur v1 | **Tous les joueurs** rendus avec leur skin/teinte en jeu → chantier **rendu multi-acteurs** inclus (un `KuraModel` par acteur). |
| D7 | Shader/matériau | **Un seul `KuraMaterial.qml` + `shaders/tint.frag` partagés**, versionnés dans l'app (`qml/world3d/`, qrc, N=20 fixe, MAX_TEX=8). Portés une fois depuis kura (équiv. `generate_zones.py` à N=20). **Pas** de codegen par modèle, **pas** de `generate_zones.py` dans le build, **pas** de shader chargé en file:// (donc pas de risque de compilation runtime). |
| D8 | balsam | **Abandonné.** Les modèles sont des `.glb` chargés via `RuntimeLoader`. Plus de conversion `.obj/.glb → .qml + .mesh`, plus de `runBalsamImport`/options/`balsamPath`. Le transform (scale/rot/pos) vit dans `model_manifest.json` (plus de marker `.qml`). |

## 4. Nouveau format de modèle (`.meow` v2)

Le dossier d'un modèle (avant compression `.meow`, et après décompression dans
`AppData/models/<name>/`) adopte l'archi **Base → Skin → Variante de kura, à
l'identique** :

```
<ModelName>/
├── model_manifest.json          # étendu (cf. ci-dessous) — porte aussi le transform
├── base/
│   ├── <ModelName>.glb          # mesh + UV0 (chargé via RuntimeLoader)
│   └── skin_base.png            # couleur de peau de base (le "skin")
└── skins/                       # MULTI-SKINS (plusieurs tenues possibles)
    └── <skin>/
        ├── colorMap.png         # color ID map (linéaire, Nearest)
        ├── skin.json            # zones (+ flag team) + bibliothèque
        ├── textures/*.png       # bibliothèque de textures du skin
        └── variants/*.json      # VARIANTES d'auteur (presets choisissables)
```

- **Plus de `.qml` de modèle, plus de `meshes/*.mesh`, plus de `maps/`** : le
  `.glb` se suffit (RuntimeLoader). Le `KuraMaterial.qml`/`tint.frag` ne sont
  **pas** dans le paquet — ils sont partagés dans l'app (D7).
- **Multi-skins** : un modèle peut avoir N skins (sous-dossiers de `skins/`),
  chacun avec son colorMap, sa bibliothèque et ses variantes.

### `model_manifest.json` (étendu)
```json
{
  "name": "Princess",
  "version": "2.0.0",
  "type": "model",
  "timestamp": "2026-06-05T…",
  "glb": "base/Princess.glb",
  "skinBase": "base/skin_base.png",
  "transform": {
    "scale": [1, 1, 1],
    "eulerRotation": [0, 0, 0],
    "position": [0, 0, 0]
  },
  "colorId": {
    "version": 1,
    "defaultSkin": "default",
    "defaultVariant": ""
  }
}
```
> Le **transform** doit migrer du marker `.qml` (supprimé avec balsam) vers le
> manifest. ⚠️ **Pas encore fait** : `readModelTransform`/`writeModelTransform`
> sont **toujours** basés sur le marker `.qml` (`<modelName>.qml`,
> `__MODEL_TRANSFORM_BEGIN__`) — la réécriture vers le manifest reste à faire.

### `skin.json` (par skin, dans `skins/<skin>/`)
```json
{
  "name": "Default",
  "baseColor": "",
  "textures": [ { "file": "foulard.png", "name": "Foulard" } ],
  "zones": {
    "0": { "name": "foulard", "team": true },
    "1": { "name": "jacket" }
  }
}
```
- `zones` : nombre de zones = entrées consécutives depuis `"0"` (≤ 20).
- `team: true` → zone surchargée par la couleur d'équipe au runtime (D4).
- `textures[]` : renomme/ordonne le scan auto de `textures/` (fichiers non
  listés ajoutés automatiquement).

### `variants/<nom>.json` (preset d'auteur, par skin)
Reprend le format Kura v2 (texture stockée **par nom**, remappée à l'index au
chargement) :
```json
{
  "version": 2, "skin": "default",
  "baseTint": "#ffffff", "baseTintMode": 0, "baseTintStrength": 0.0,
  "slots": [
    { "tint": "#ffaa00", "tintMode": 2, "tintStrength": 0.4,
      "texture": "Foulard", "texOpacity": 1.0, "texTint": "#ffffff", "texInvert": false }
  ]
}
```

### `PlayerProfile.colorVariant` (choix joueur, hors `.meow`)
String JSON, défaut `""` (= skin/variante par défaut du modèle, aucune teinte
équipe) :
```json
{ "skin": "default", "variant": "rouge_vif", "teamColor": "#e03b3b" }
```
- `variant` = nom d'une variante packagée dans le modèle (résolue au runtime).
- `teamColor` (optionnel) = couleur appliquée aux zones `team:true` par-dessus la
  variante. Peut être **fourni par la partie** (équipe) plutôt que par le profil
  — voir §8.

## 5. Matériau & shader (partagés, dans l'app)

**Un seul** `KuraMaterial.qml` + `shaders/tint.frag`, portés une fois depuis kura
(N=20, **MAX_TEX=8**), versionnés dans `qml/world3d/` et inclus dans le module QML
(`qml.qrc` / `qt_add_qml_module`) → **shader pré-bundlé en qrc, pas de file://**.

- `tint.frag` : palette `RAW_IDS[20]`, `apply_tint` (Aplat/Multiply/Overlay),
  `compose_slot`, boucle 20 zones. Slots ≥ 8 = teinte-seule (pattern = base).
- `KuraMaterial.qml` : `CustomMaterial` exposant `baseColorSource`,
  `colorIDSource`, `slot{0..7}PatternSource`, `tint{0..19}`, `tintMode{0..19}`,
  `tintStrength{0..19}`, `slot{0..7}TexOpacity/TexTint/texInvert`, `baseTint*`,
  `debugMode`. ColorID : Nearest/no-mip/ClampToEdge + `colorSpace: Texture.Linear`.

`generate_zones.py` n'est **pas** porté dans le build : si un jour N doit changer,
on régénère ces 2 fichiers à la main (ou via un script dev hors-CMake) et on les
recommite. Le risque « shader file:// runtime » de l'ancien plan **disparaît**.

## 6. Application du matériau au runtime (D1) — `KuraModel.qml`

Composant réutilisable `qml/world3d/KuraModel.qml` (port du pattern kura
`RuntimeLoader` + `overrideMaterials` + Timer fallback) :

```qml
// pseudo
Node {
    property url glbUrl
    property url baseColorUrl
    property url colorMapUrl
    property var config        // variante parsée : tints/modes/strengths/tex…
    KuraMaterial { id: mat; baseColorSource: baseColorUrl; colorIDSource: colorMapUrl; /* binds config */ }
    RuntimeLoader { id: loader; source: glbUrl
        function overrideMaterials(n){ /* récurse, c.materials=[mat] */ } }
    Timer { interval: 100; repeat: true; running: true
        onTriggered: if (loader.overrideMaterials(loader) > 0) stop() }
}
```

- Les **2 sites de rendu runtime** (`World3D`, `PCP_Profile3DPreview`) passent par
  un wrapper `SkinnedModel.qml` (résout `modelName` + `colorVariant` →
  glb/skin/variante/équipe via `AssetManager`) qui enveloppe lui-même `KuraModel`.
  Seul l'aperçu du configurateur (`Model3DPreview`) pilote `KuraModel` directement
  → un seul endroit à maintenir pour la logique matériau.
- Le **transform** (du manifest) s'applique sur le `Node` racine de `KuraModel`.
- La config **par joueur** (skin + variante + équipe) = bindings de `config` sur
  l'instance `KuraMaterial` — réactif, sans réécriture de fichier.

## 7. Plan par phases (révisé : format kura, sans balsam)

### Phase A — Fondation : matériau partagé + composant `KuraModel`
1. Porter `KuraMaterial.qml` + `shaders/tint.frag` dans `qml/world3d/` (N=20,
   MAX_TEX=8) + entrée `qml.qrc`/`qt_add_qml_module`.
2. `KuraModel.qml` (RuntimeLoader + overrideMaterials + Timer + binds config).
3. Banc d'essai : afficher un `.glb` + colorMap dans `Model3DPreview`, valider
   rendu D3D11 + **compte samplers** (`QT_FORCE_STDERR_LOGGING=1`) + debugMode 0..5.
4. C++ : helpers Catalog (`createModelSkin`, `listModelSkins`, `listSkinTextures`,
   `importSkinTexture`, `readSkinJson`/`writeSkinJson`, `listSkinVariants`,
   `saveSkinVariant`/`loadSkinVariant`/`deleteSkinVariant`). **(fait dans le header)**

### Phase B — Créateur de skin (configurateur)
5. C++ : `model_manifest.json` étendu (glb/skinBase/transform/colorId) + réécrire
   `readModelTransform`/`writeModelTransform` pour les **baser manifest** (plus de
   `.qml`). ⚠️ **Pas encore fait** : les deux fonctions lisent/écrivent toujours
   le marker `.qml` (`<modelName>.qml`, `__MODEL_TRANSFORM_BEGIN__`) — migration
   restante. Supprimer le code balsam (`runBalsamImport`, options, `balsamPath`).
6. QML : refondre `ModelConfigurator` en **créateur de skin** : importer un `.glb`,
   importer une colorMap → `createModelSkin`, éditer zones (nom/team), importer
   textures, configurer teinte/texture/opacité par zone, gérer variantes
   (sauver/charger/suppr). Aperçu via `KuraModel`. Réutilise l'UI de
   `kura_qt_viewer/Main.qml`.
7. QML : transform (scale/rot/pos) → manifest ; packaging via `createModelPackage`.

### Phase C — Runtime joueur (mono-acteur d'abord)
8. C++ : `PlayerProfile.colorVariant` (`Q_PROPERTY QString` + toJSON/applyJson,
   défaut `""`). ⚠️ « preset » déjà pris (physique) → on dit **variante**.
9. QML : `World3D` — remplacer `Loader3D` par `KuraModel`, distribuer le
   `colorVariant` du profil (skin + variante + équipe). Binding dans `Editor.qml`.
10. QML : `PCP_Profile3DPreview` — `KuraModel` + variante.
11. QML : UI de choix skin/variante dans le `playerConfigPanel`.

### Phase D — Runtime multi-acteurs (D6)
12. `World3D` : un `KuraModel` **par acteur** (Repeater sur le registry), chacun
    lisant le `colorVariant` de son `PlayerProfile`. Remplace `entityNode`/`entity2Node`.
13. Coût : N matériaux + N colorMap ; mutualiser les textures de skin partagées.

### Phase E — Packaging + réseau
14. C++ : `createModelPackage` embarque `base/` + `skins/` + manifest
    (FolderCompressor récursif → aucune modif du compresseur).
15. C++ : AssetManager — résoudre le `.glb`, exposer skins/variantes d'un modèle
    pour le runtime/UI (port runtime du Catalog).
16. Réseau : vérifier qu'`UpdatePlayerProfile` (ops 12-16) sérialise `colorVariant`.
    Teinte d'équipe pilotée par la partie → via l'état de session (mode équipe).

## 8. Teinte d'équipe (D4) — détail

- L'auteur marque des zones `team:true` dans `skin.json`.
- Au runtime, si une couleur d'équipe est active pour le joueur, **les zones
  `team:true` reçoivent une couche teinte** `apply_tint(zone, teamColor, mode)`
  par-dessus la variante (mode/intensité par défaut Aplat à 1.0, ajustable).
- **Source de la couleur d'équipe** : deux options non exclusives —
  (a) `PlayerProfile.colorVariant.teamColor` (figé dans le profil), ou
  (b) attribué par la **partie/session** (équipe 1 = rouge, etc.) et injecté
  dans le binding du matériau au runtime. La (b) est préférable pour le gameplay
  équipe (à câbler quand le mode équipe existera) ; la structure `colorVariant`
  laisse la place aux deux.

## 9. Pièges & risques connus

- **sRGB / Nearest** sur la colorMap : non négociable (cf. §2). `colorSpace:
  Texture.Linear`, `minFilter/magFilter: Nearest`, `mipFilter: None`, ClampToEdge.
- **Limite samplers D3D11** : l'erreur n'apparaît qu'au **runtime** et seulement
  avec `QT_FORCE_STDERR_LOGGING=1` (Windows → `qDebug` part en OutputDebugString).
  Respecter D5 (≤ 8 patterns).
- **`Loader3D.status`** : `node3D` n'existe qu'après Ready ; l'enum de succès est
  instable selon la version Qt (cf. gotcha repo). Brancher la distribution de
  teinte sur `onStatusChanged`/poll, jamais à la construction.
- **Pas d'arbre `.qml` à parcourir** : avec le `.glb` + `RuntimeLoader`, il n'y a
  plus de fichier `.qml` de modèle ni d'arbre `node2 → … → Model.materials[0]` à
  traverser. Pour la distribution par binding, viser l'instance `KuraMaterial`
  (id stable injecté), pas un index `children[]`.
- **Primitives Cube/Sphere** (`World3D:273-278`) shuntent le `Loader3D` →
  pas de Color ID Map ; teinte = `baseColor` simple ou exclues.
- **`generate_zones.py`** : abandonné côté Meownopoly (gotcha CMake GLOB +
  reproductibilité). Le codegen vit en C++.
- **Multi-acteurs (D6)** : `World3D` ne rend qu'un acteur aujourd'hui — Phase D
  est un vrai refactor, pas un ajout trivial.

## 10. Fichiers load-bearing

| Fichier | Rôle dans l'intégration |
|---------|--------------------------|
| `cpp/launcher/launcher_manager.{h,cpp}` | marker pattern (919-1031), packaging (434-486), **+** helpers Catalog skin/variante (`createModelSkin`, `listModelSkins`, `listSkinTextures`, `importSkinTexture`, `readSkinJson`/`writeSkinJson`, `listSkinVariants`, `saveSkinVariant`/`loadSkinVariant`/`deleteSkinVariant`, `detectColorMapZones`, `deleteSkinTexture`) |
| `cpp/game/map/playerprofile.{h,cpp}` | **+** `colorVariant` (Q_PROPERTY + toJSON/applyJson) |
| `cpp/assetManager/asset_manager.{h,cpp}` | **+** accès runtime aux skins/variantes d'un modèle |
| `qml/launcher/ModelConfigurator.qml` | UI zones/biblio/variantes (~1054) ; save flow (147-164) |
| `qml/launcher/Model3DPreview.qml` | preview teinté (subjectLoader 167-176) |
| `qml/world3d/World3D.qml` | runtime mono via `SkinnedModel` (280-292) → multi-acteurs (D6) |
| `qml/world3d/SkinnedModel.qml` | wrapper runtime : résout `modelName` + `colorVariant` (glb/skin/variante/équipe) via `AssetManager`, enveloppe `KuraModel` |
| `qml/world3d/PhysicsActor.qml`, `PCP_Profile3DPreview.qml` | sites de rendu secondaires (`PCP_Profile3DPreview` passe par `SkinnedModel`) |
| **Créés** (partagés, dans l'app) | `qml/world3d/KuraMaterial.qml`, `qml/world3d/shaders/tint.frag` |

---
*Source externe à porter (PAS dans ce repo) : `kura_qt_viewer/` (tint.frag,
KuraMaterial.qml, Main.qml, catalog.h, generate_zones.py). Référence palette/
encodage : `COLOR_ID_MAP.md`. Notes pédagogiques : `NOTES_SYSTEME_TEXTURE.md`.*
