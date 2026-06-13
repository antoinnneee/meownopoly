# Kit de composants UI génériques pour l'éditeur — Plan

> **Statut** : document de conception (plan). Aucun code écrit.
> **Date** : 2026-06-12
> **Périmètre** : form-controls réutilisables (`qml/ui_item/`) pour les panneaux de l'éditeur (`qml/editor/`).
> **Objectif** : factoriser les blocs UI dupliqués des panneaux de configuration (CCP/CCPS, ZCP, VEP, SEP, PCP) en composants canoniques branchés sur `Theme`.

---

## 1. Contexte et constat

L'éditeur compte ~106 fichiers QML. Les panneaux de configuration (`bottomSidePanel/`, `bottomMainPanel/`) répètent les mêmes blocs de form-controls, chacun re-stylé à la main sur `Theme`. Trois symptômes :

1. **Duplication pure** : un même bloc Label+TextField (background + border focus animée + `onEditingFinished`) recopié ~8-10 fois.
2. **Variantes divergentes du même composant** : il existe déjà 2-3 implémentations du même contrôle, isolées par préfixe de panneau, sans version canonique partagée :
   - SpinBox : `CCP_StyledSpinBox` (int, auto-repeat, formatage milliers) **vs** `PCP_StyledSpinBox`.
   - Slider : `VEP_Slider` **vs** `SEP_Slider` (cf. §4.2 — interactions différentes).
   - ComboBox : `PCP_StyledComboBox` **vs** delegates inline (`CCP_RestAreaFamilyConfig`).
3. **Style implicite** : malgré la convention « tout style passe par `Theme` », des couleurs en dur subsistent (`#222222`, `#3a3a1a`, `#ffeb99`…) dans les blocs copiés.

Le gain principal n'est pas seulement « moins de lignes » : c'est **une seule source de vérité de style** par contrôle, donc une UI cohérente et un `uiScale` qui s'applique partout.

---

## 2. Composants déjà factorisés (à conserver / promouvoir)

### `qml/ui_item/` (module `ui_item`, cf. `qmldir`)
| Composant | Rôle |
|---|---|
| `CollapsableGroupBox` | Groupe repliable (titre cliquable). **Déjà la brique de section** — réutiliser, ne pas refaire. |
| `InteractiveUiElement` | Élément éditable avec overlay/drag/resize. |
| `SizeSelector` | Sélecteur de largeur + spinbox. |
| `BtSideMenu`, `ParticleButton`, `Player_Profil_Icon`, `LayerVisualizer` | Boutons/icônes spécialisés. |

### Composants « stylés » enfermés dans un sous-dossier de panneau (candidats à la promotion vers `ui_item/`)
| Fichier actuel | Devient (proposé) | Note |
|---|---|---|
| `playerConfigPanel/PCP_StyledSpinBox.qml` | — | Version simple ; superseded par `CCP_StyledSpinBox`. |
| `caseConfigPanel/CCP_StyledSpinBox.qml` | **`MeowSpinBox`** | Le plus abouti (auto-repeat, milliers, validator). Base canonique. |
| `playerConfigPanel/PCP_StyledComboBox.qml` | **`MeowComboBox`** | Base canonique combobox. |
| `playerConfigPanel/PCP_StyledTabButton.qml` | `MeowTabButton` (optionnel) | |
| `playerConfigPanel/PCP_StyledRadioButton.qml` | `MeowRadioButton` (optionnel) | |
| `visualEffectPanel/VEP_Slider.qml` + `screenEffectPanel/SEP_Slider.qml` | **`MeowSlider`** | Fusion, cf. §4.2 (réconcilier 2 API). |

---

## 3. Patterns dupliqués non factorisés (inventaire)

| # | Pattern | ~Occ. | Fichiers témoins | Priorité |
|---|---|---|---|---|
| P1 | Label + TextField stylé | 8-10 | `zoneConfigPanel/ZCP_GeneralSection.qml:87`, `caseConfigPanel/CCPS_GeneralSection.qml:42` | 🔴 |
| P2 | Slider + label + valeur (+reset) | 7-9 | `VEP_Slider.qml`, `SEP_Slider.qml`, `ZCP_GeneralSection.qml:161/236/311` | 🔴 |
| P3 | Property Row (Label + contrôle aligné) | 20+ | `ZCP_GeneralSection.qml:80-418`, `CCPS_GeneralSection.qml:35-80` | 🔴 |
| P4 | Switch stylé (indicator + pastille animée) | ~6 | `ZCP_GeneralSection.qml:121-159` | 🟠 |
| P5 | Multi-SpinBox en colonnes | 5-6 | `CCP_RentConfig.qml:54`, `CCP_HouseHotelPriceConfig.qml:50`, `CCP_CatPerksConfig.qml:49` | 🟠 |
| P6 | Info Box (note `💡` / encadré coloré) | 15+ | `CCP_RentConfig.qml:43`, `CCPS_CardBoardBoxSection.qml:40` | 🟡 |
| P7 | CheckBox stylée (indicator + check) | 3-4 | `VEP_AdvancedEffectsSection.qml:40/88`, `ConnectionsConfigurationSection.qml:46` | 🟡 |
| P8 | Swatch / color button | 1-2 | `VEP_ColorEffectsSection.qml:119` (`component SwatchButton`) | 🟡 |

Foyers les plus denses : `zoneConfigPanel/ZCP_GeneralSection.qml` et les `caseConfigPanel/CCP_*Config.qml`.

---

## 4. API proposée des composants génériques

> Convention : préfixe **`Meow`**, placés dans `qml/ui_item/`, enregistrés dans `qmldir`. Tout style dérive de `Theme`. Signaux suffixés `…ed`/`…Requested` (jamais `…Changed` custom — collision avec l'auto-signal QML). Propriétés internes préfixées `_`.

### 4.1 `MeowTextField` — Label + champ texte (P1)
```qml
MeowTextField {
    label: "Nom"
    placeholder: "Nom de la zone"
    text: targetZone.name
    // signaux :
    onEdited: ...          // émis sur editingFinished (valeur committée)
    onReturnReleased: ...  // Entrée pressée (libère le focus)
}
```
- Props : `label:string`, `placeholder:string`, `text:string` (binding bidirectionnel via alias), `labelWidth:real` (défaut auto), `orientation` (`Row`/`Column`).
- Style : background `Theme.background`, border `Theme.border`→`Theme.accentAlt` au focus, `Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }`.
- Signaux : `edited()`, `returnReleased()`.

### 4.2 `MeowSlider` — slider labellisé (P2) ⚠️ réconciliation de 2 API
Les deux sources ont des contrats **différents** :
- `VEP_Slider` : `signal effectChanged(var value)` émis en continu (live, simple).
- `SEP_Slider` : `begin()` / `movedValue(real)` / `commit()` — modèle **transactionnel** pensé pour l'undo/save (snapshot au début du geste, un seul delta committé à la fin).

Le composant générique doit **exposer les deux modèles** sans forcer l'un :
```qml
MeowSlider {
    label: "Vitesse"
    from: 0; to: 5; value: zone.speed; decimals: 1
    unitText: "×"            // suffixe affiché à côté de la valeur
    resettable: true         // bouton Reset (off par défaut)
    resetValue: 0
    // modèle live (compat VEP) :
    onMoved: ...             // (real v) pendant le drag
    // modèle transactionnel (compat SEP, pour undo/save) :
    onGestureBegan: ...
    onGestureCommitted: ...
}
```
- Props : `label`, `from`, `to`, `value` (alias), `stepSize` (ou dérivé de `decimals`), `decimals:int`, `unitText:string`, `labelWidth`, `valueWidth`, `accentColor:color` (défaut `Theme.accentAlt`), `resettable:bool`, `resetValue:real`.
- Signaux : `moved(real v)`, `gestureBegan()`, `gestureCommitted()`.
- **Migration** : les call-sites VEP branchent `onMoved` ; les call-sites SEP branchent `onGestureBegan/onMoved/onGestureCommitted`. Garder les deux noms de slot, pas de rupture.

### 4.3 `MeowPropertyRow` — ligne label + contrôle (P3)
Conteneur d'alignement (le plus rentable : 20+ occurrences).
```qml
MeowPropertyRow {
    label: "Mode Exclusion"
    // contenu = default property → le contrôle arbitraire (Switch, ComboBox…)
    MeowSwitch { checked: zone.exclusion; onToggled: ... }
}
```
- `default property alias content` → un seul contrôle à droite.
- Props : `label:string`, `labelWidth:real` (défaut cohérent global), `labelBold:bool`, `enabled`/`opacity` propagés (utile pour les blocs grisés quand `exclusionSwitch.checked`).
- Implémentation : `RowLayout` (ou `GridLayout` 2 colonnes piloté par un parent `MeowPropertyGroup` optionnel pour aligner plusieurs rows — voir §6 extension).

### 4.4 `MeowSwitch` (P4) / `MeowCheckBox` (P7)
- `MeowSwitch` : `Switch` avec indicator custom (track + pastille blanche animée `Behavior on x`). Couleurs `Theme.accentAlt`/`Theme.surfaceAlt`. Signal `toggled()`.
- `MeowCheckBox` : `CheckBox` avec indicator carré + check. `Theme.success` au check. Props `text`, `checked`, `tooltip`.

### 4.5 `MeowSpinBox` (promotion de `CCP_StyledSpinBox`)
- Garder l'API actuelle : `from`, `to`, `value`, `stepSize`, `suffix`, `editable` + `valueChanged()` (déjà émis à la main).
- ⚠️ Actuellement **int-only** (`property int value`, `IntValidator`). Décider : (a) rester int et ajouter un `MeowSpinBoxReal` séparé, ou (b) généraliser en `real` avec `decimals`. **Reco : (a)** — l'int couvre prix/loyers/perks ; le real est rare (physique → déjà couvert par `MeowSlider`).

### 4.6 `MeowComboBox` (promotion de `PCP_StyledComboBox`)
- API `ComboBox` standard + style canonique. Ajouter un hook delegate optionnel pour le cas « swatch couleur + texte » (`CCP_RestAreaFamilyConfig`) via une property `swatchRole` ou un `delegate` surchargé.

### 4.7 `MeowInfoBox` (P6)
```qml
MeowInfoBox {
    icon: "💡"
    text: "Définissez les prix selon le niveau d'amélioration."
    variant: "info"   // info | warning | tip → mappe sur des couleurs Theme
}
```
- Remplace à la fois la note `Text` italique muted **et** l'encadré `Rectangle` coloré (titre + bullets) → 2 modes : `text` simple ou `default property` (contenu riche).
- ⚠️ Les couleurs en dur actuelles (`#3a3a1a`, `#ffeb99`, `#d4c894`) doivent devenir des **tokens `Theme`** (candidats : `infoBg`, `warningBg`, `tipText`…). Cf. memory `project_theme_singleton` (tokens manquants).

### 4.8 `MeowSwatchButton` (P8)
- Extraire le `component SwatchButton` de `VEP_ColorEffectsSection.qml:119` tel quel : `baseColor`, `pressedColor`, `text`, `clicked()`, alias `hovered`.

---

## 5. Plan de migration (par vagues, à valider call-site par call-site)

> Stratégie : créer le composant → migrer **1 panneau pilote** → vérifier visuellement (automation/screenshot) → étendre. Ne jamais migrer en masse sans vérif visuelle (les blocs ont des variantes subtiles : largeurs de label, opacité conditionnelle, `Screen.pixelDensity`).

| Vague | Composant(s) | Panneau pilote | Puis étendre à |
|---|---|---|---|
| V1 | `MeowTextField` | `ZCP_GeneralSection` (nom de zone) | `CCPS_GeneralSection`, autres champs nom |
| V2 | `MeowSlider` | `SEP_*` (modèle transactionnel) puis `VEP_*` | sliders inline de `ZCP_GeneralSection` (speed/friction/accel) |
| V3 | `MeowPropertyRow` + `MeowSwitch` | `ZCP_GeneralSection` | `CCPS_*` |
| V4 | `MeowSpinBox` (promotion) | `CCP_RentConfig` | `CCP_HouseHotelPriceConfig`, `CCP_CatPerksConfig` |
| V5 | `MeowComboBox` (promotion) | `playerConfigPanel` | `CCP_RestAreaFamilyConfig` (delegate swatch) |
| V6 | `MeowInfoBox`, `MeowCheckBox`, `MeowSwatchButton` | au fil de l'eau | partout |

### Points d'attention transverses
- **`Screen.pixelDensity` vs `Theme`** : certains composants (VEP/PCP) dimensionnent via `Screen.pixelDensity * N` au lieu de `Theme.px(...)`. Harmoniser sur `Theme`/`uiScale` pour que l'échelle UI globale s'applique (cf. memory `project_theme_singleton`).
- **Bindings vs imperatif** : conserver les bindings déclaratifs ; ne pas réintroduire de `prop = value` dans les slots (warning `qt.qml.binding.removal`).
- **Largeur de label** : aujourd'hui hétérogène (`96`, `Screen.pixelDensity*17/25`). Définir une constante par défaut dans `MeowPropertyRow`/`MeowTextField`, surchargeable.
- **Couleurs en dur → tokens Theme** : lister les couleurs hex restantes (`#222222`, `#3a3a1a`, `#ffeb99`, `#e3f2fd`…) et les promouvoir en tokens avant/pendant la migration des InfoBox/ComboBox.
- **`qmldir`** : chaque nouveau composant doit être ajouté au module `ui_item` (`qml/ui_item/qmldir`).
- **Collab/undo** : les contrôles ne changent rien au flux d'ops (`EditorOpBus`) — ils restent de purs widgets ; les call-sites continuent d'appeler `configurationChanged()`/submitOp comme avant.

---

## 6. Extensions possibles (hors périmètre form-controls)

- `MeowPropertyGroup` : `GridLayout` 2 colonnes qui aligne plusieurs `MeowPropertyRow` (largeur de label partagée) — utile pour les longues sections (`ZCP_GeneralSection`).
- `MeowSectionHeader` : standardiser les en-têtes (icône/emoji + titre) au-dessus de `CollapsableGroupBox`.
- `MeowMultiSpinRow` (P5) : RowLayout multi-colonnes de `Label + MeowSpinBox` piloté par un modèle `[{label, from, to, value}]` — réduit `CCP_RentConfig`/`CatPerks`.
- `MeowArrowSelector` : le sélecteur `◀ … ▶` de `CCPS_TypeSection`.

---

## 7. Estimation d'impact

- **Blocs dupliqués retirés** : ~60-80.
- **Fichiers touchés en migration complète** : ~20-25 (CCP/CCPS, ZCP, VEP, SEP, PCP).
- **Nouveaux fichiers** : 7 prioritaires + 4 extensions (+ entrées `qmldir`).
- **Risque** : faible côté logique (widgets purs), modéré côté visuel (variantes subtiles) → d'où la migration par vagues avec vérif visuelle.

---

## 8. Décisions à trancher avant implémentation

1. **`MeowSpinBox`** : int-only + `MeowSpinBoxReal` séparé, ou un seul `real` paramétré ? (reco : int-only canonique).
2. **`MeowSlider`** : garder les deux API (live `moved` + transactionnel `gesture*`) dans un seul composant, ou deux composants ? (reco : un seul, les deux jeux de signaux coexistent).
3. **Tokens `Theme` manquants** : créer `infoBg/warningBg/tipText/...` maintenant (bloque `MeowInfoBox`/`MeowComboBox` propres) ou tolérer du hex transitoire ?
4. **`Screen.pixelDensity`** : migrer vers `Theme.px`/`uiScale` dans la foulée, ou laisser tel quel pour limiter le diff ?
