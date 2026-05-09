# Rendu & Performance — récap des optimisations

Cette doc consolide les passes d'optimisation rendu de l'éditeur Meownopoly (grille, zones d'exclusion, hachures, drag/zoom) et le triple buffer du moteur physique. Pour chaque solution, on précise **la raison du choix de techno**, pas seulement le quoi.

Sources : `cpp/editor/painter/{grid,zone,zones_overlay,zone_hatch}_*`, `cpp/game/physics/physics_world.cpp`. Commits : `40289d2` (grille), `bc7711b` (zones GPU), `7f65fbe` / `734c162` / `5009195` (hachures), `a983d90` (overlay global), `6a06d2b` (overlay suit drag), `c0205b3` (zoom multiplicatif).

---

## 1. Rendu de la grille — `GridCanvasPainter` global viewport-cullé

### Avant
`Repeater { model: 1202 }` (601 lignes verticales + 601 horizontales pour `croisillons=600`). Steady-state OK (le scene graph batche), mais création/destruction au `croisillonsChanged` = 75–101 ms/itération.

### Après
Un seul `QCanvasPainterItem` C++ couvrant le viewport visible (≈ 1280×720, **pas** la grille entière 7200×7200), positionné en `x: -gridManager.x` pour rester aligné en coords écran. Calcule `[firstX, lastX] × [firstY, lastY]` visibles puis émet ~167 `lineTo` par frame.

### Pourquoi `QCanvasPainterItem` (Qt 6.11)
- **Rendu GPU** via QRhi. Le `Canvas` QML 2D utilise QPainter CPU sur le main thread → freeze garanti dès quelques centaines d'items.
- API impérative façon Canvas 2D (`beginPath / moveTo / lineTo / stroke`) → portage direct depuis `Canvas` QML existants.
- `Shape` + `ShapePath` aurait marché mais 1 item GPU + vertex buffers par item → pas de gain pour des lignes simples.

### Pourquoi viewport culling au lieu d'un canvas grande grille
Le backing texture d'un `QQuickRhiItem` suit `width × height × dpr`. À 7200×7200 → ≈ 200 MB de VRAM, **réalloué à chaque cran de zoom**. Le canvas viewport-cullé est dimensionné comme l'écran (constant) ; seuls les indices visibles changent à chaque frame.

### Toggle
`MEOW_GRID_RENDERER=canvas` (défaut) | `repeater` (fallback Qt < 6.11 ou debug visuel).

### Gain mesuré
`resizeCroisillons` 75.66 → 6.96 ms mean (**−91 %**), max 101.69 → 7.21 ms (× 14).

---

## 2. Rendu des zones d'exclusion — 3 passes successives

### Passe 1 : `Canvas` QML 2D → `ZoneCanvasPainter` C++ (commit `bc7711b`)
`Canvas` QML 2D = QPainter CPU sur main thread. Avec 50+ zones polygonales repeintes au tick wheel : freeze GUI. Migration vers `QCanvasPainterItem` (1 item C++ par zone). **~100×** sur le zoom.

### Passe 2 : optims internes du scanline des hachures (`7f65fbe`, `734c162`, `5009195`)

Le calcul des hachures est un **scanline classique** : intersection ligne diagonale ↔ arêtes du polygone, paires d'abscisses, règle even-odd.

#### 2.a Pré-calcul des arêtes
Struct compacte `EdgeCoef` (4 `float` post-G6) calculée une fois par changement de polygone, puis re-balayée à chaque scanline. ~2× sur le coût scanline.

#### 2.b Fast-path convexe (sz==2)
La majorité des polygones d'usage réel sont convexes → pas de `std::sort`, juste `min/max`. Évite le tri sur 99 % des cas.

#### 2.c `QVarLengthArray<float, 4096>` pour les segments
Stack-allocated jusqu'à 1024 segments. Remplace `QVector<QVector<QLineF>>` qui allouait N petits vecteurs heap par hachure.

#### 2.d Cache `m_pointsGrid` côté item
Conversion `QVariant → QPointF` (≈ 60 ns/point avec `canConvert` + lookup map) faite **une fois** dans `setPolygonPoints`. Le sync ne fait plus qu'une multiplication par `gridSize`. **Sync −87 %**.

#### 2.e `float` au lieu de `qreal`
Mantisse 24 bits = 0.06 px à 100 k px — précision suffisante pour des coords pixel. **4 arêtes par cache line** vs 2 en double. −5 à −10 % sur les cas hatch-heavy.

#### 2.f Early-out `bbox.diagonal < spacing`
Économise tout le scanline pour zones zoomées-out sans hachures visibles utiles.

#### 2.g `PrecomputeAsync` — scanline en background

`QtConcurrent::run` + `QFutureWatcher::finished` → `update()`. Le `paint()` ne fait QUE du draw. Cache `m_cachedSegments` invalidé à chaque setter géo. **Frame mean −30 % à −47 %** sur les cas hatch-heavy.

**Pourquoi `QtConcurrent::run` + watcher (et pas `blockingMapped` à l'intérieur du `paint`)** : confirmé par benchmark — paralléliser DANS un paint séquentiel quand N items submittent simultanément sature le pool global (× 3 à × 20 sur le frame). On parallélise **AVANT** le rendu, pas dedans. Voir `MEOW_ZONE_PARALLEL_MODE=qtc-hatches/qtc-edges` pour reproduire (catastrophique : `renderScaling/1000` 6.5 → 119 ms).

#### 2.h Anti-pattern `painter->stroke(QCanvasPath, pathGroup=0)`
Testé : −30 à −38 % CPU. **MAIS** bug visuel — les hachures restaient figées entre frames. Hypothèse : `pathGroup=0` introduit un cache GPU qui ne s'invalide pas. **Ne pas réutiliser** sans avoir compris la sémantique de `removePathGroup(int)`. Le bench Qt Test ne détecte PAS ce genre de régression visuelle.

### Passe 3 : `ZonesOverlayPainter` global viewport-cullé (commit `a983d90`)

#### Problème détecté à `mmSize=200+`
Un `ZoneCanvasPainter` par tile avec `width = polygonGridWidth * gridSize`. Une zone 10×10 cellules → 2000×2000 px ≈ 16 MB ; 100 zones → 1.6 GB de VRAM. Qt réalloue le backing à chaque cran de zoom → **freezes > 1 s/cran**.

#### Solution
Un **seul** `QCanvasPainterItem` global (`anchors.fill: parent` du `Base_Board`), reçoit la liste des zones via `Q_PROPERTY zones` (QVariantList de descripteurs `{posGridX, posGridY, points, color, strokeColor, strokeWidth, opacity, hatchSpacing}`). Itère, calcule bbox écran, **viewport-cull**, dessine fill + stroke + hachures via `zone_painter::computeHatchSegments` (sync, plus de cache async — la liste change peu et `gridSize` change à chaque cran de zoom donc invalide tout).

#### Pourquoi pas `setFixedColorBufferWidth/Height` à 2048
Testé : réduisait les freezes mais le scene graph étirait la texture sur tout l'item → **flou inacceptable** au zoom extrême. Ce n'est pas un cap dur sain.

#### Pourquoi pas un overlay unique sur tout le `workArea` (sans culling)
`QQuickRhiItem` cale le FBO sur la taille à l'écran (`effectiveColorBufferSize`), pas la taille logique. À 7000+ pixels logiques, **décalage géométrique au zoom**. Échoué dans `bc7711b`, code supprimé.

#### Suivi du drag (commit `6a06d2b`)
Le binding `zones` lit `t.x / gridSize` (pixels courants), **pas** `dp.gridRelativePositionX` qui n'est mis à jour qu'au snap (release). Sans ça l'overlay restait figé pendant tout le drag puis snappait au release.

#### Toggle
`MEOW_ZONES_RENDERER=overlay` (défaut) | `per-tile` (legacy fallback). Le `ZoneCanvasPainter` legacy reste utilisé pour les preview cursors (cf. `forceLocalRenderer: true`).

#### `Loader.active` plutôt que `visible: false`
Un `QCanvasPainterItem` invisible mais instancié continue de réagir aux changes `width/height` et de **réallouer son backing GPU**. Pour vraiment l'éliminer, passer par `Loader { active: ... }` côté QML — l'item n'est même pas créé.

---

## 3. Zoom multiplicatif (commit `c0205b3`)

`mmSize` passé de `int` à `real` + multiplication ×1.1 au lieu d'addition dans `ScrollLogic.scrollGrid`. Sans ça `mmSize * 1.1` se ré-arrondissait à chaque cran et le zoom progressait par ±1 mmSize. Pas une optim de rendu directe mais **dépendance** des viewports cullés (qui ont besoin d'un zoom continu pour avoir un sens).

`gridSize` aussi en `real` pour préserver la précision ; downstream `* gridSize` / `Math.round(... / gridSize)` déjà compatibles.

---

## 4. Triple buffer physique (Fraser-Harris) — `physics_world.cpp`

### Problème
Jitter visuel sur `PhysicsActor` à 144 Hz écran / 60 Hz physique. `tryAdvanceGuiBuffer` faisait un `atomic_exchange` inconditionnel entre `m_guiInUse` et `m_pending`. Quand le rendu tirait plus vite que la publication worker, deux exchanges GUI consécutifs récupéraient le buffer **que la GUI venait de déposer** (= tick antérieur). Symptôme : tick observé côté GUI oscille (`2663 → 2662 → 2664 → 2662 …`).

### Fix : peek (load) avant swap
```cpp
auto *peek = m_pending.load(std::memory_order_acquire);
if (!peek || peek->tick <= m_guiInUse->tick) return;
auto *fresh = m_pending.exchange(m_guiInUse, std::memory_order_acq_rel);
if (fresh) m_guiInUse = fresh;
```
Le worker dépose toujours strictement croissant → post-peek positif, l'exchange ne peut que ramener un tick ≥ peek.

### Pourquoi triple buffer Fraser-Harris
- Producteur = worker physique (60 Hz, ≈ 16 ms tick).
- Consommateur = GUI (variable selon vsync, 60-144 Hz).
- **Lock-free**, pas de blocage : le consommateur lit toujours le dernier snapshot publié.
- Le piège était la sémantique d'`exchange` quand le consommateur lit plus vite que le producteur publie → fix peek.

### Outils de diag
- `PhysicsTestTab` bouton "Trace 3s" → 180 frames CSV `[PHYS-TRACE]` (frame, tick, dTick, frameMs, px, py, vx, vy, dx, dy, dist).
- `PhysicsActor.startJitterTrace(N)` (touche J dans Editor) — log mappingDx/Dz et position node3D pre/post lissage.
- `Timer interval=16` remplacé par `FrameAnimation` (synchro vsync, plus de battement 62.5/60 Hz).

---

## 5. Patterns transverses

### Bindings cachés via closure
```qml
// MAUVAIS : Shape ré-évalue à chaque change de gs même si points inchangé
path: { var trigger = updateTrigger; var gs = gridManager.gridSize; return points }
// BON : capturer SEULEMENT updateTrigger
path: { void updateTrigger; return points }
```

### `Qt.point()` vs `{x, y}` JS literal
`Qt.point()` est ≈ 5× plus lent. Acceptable seulement quand le consommateur attend un type Qt natif (ex: `PathPolyline.path` qui demande `list<point>`).

### `var` map mutée en place ne déclenche pas la ré-évaluation
```qml
// MAUVAIS : binding ne se ré-évalue pas
map[key] = value
// BON
map = Object.assign({}, map, { [key]: value })
```

### Débounce du `snapToGridFromGridPos`
`Editor_WheelHandler` rebindait toutes les tuiles à chaque tick wheel → cascade. Timer 80 ms qui boucle une seule fois en fin de geste.

### `WheelHandler` n'a pas de default property pour les enfants visuels
Un `Timer` enfant d'un `WheelHandler` provoque "Cannot assign to non-existent default property". Le déclarer en `property Timer foo: Timer { ... }` à la place.

### `Loader.source = "qrc:/..."` peut fail silencieusement
Status=Error sans message clair. Si le module C++ utilisé par le QML chargé est déjà importé ailleurs dans la scène, préférer instancier directement le composant via `import` + Component inline plutôt qu'un `Loader { source: "qrc:/..." }`. Voir `ZonesOverlayPainter` instancié directement dans `Editor.qml` après échec du Loader/qrc.

### Preview cursors hors `snapableTilesList`
Les overlays globaux viewport-cullés (`ZonesOverlayPainter`, `GridCanvasPainter`) itèrent uniquement `snapableTilesList`. Tout `SnapableExclusionZone` instancié hors de cette liste (preview cursors) n'est rendu nulle part avec l'overlay actif. Pattern : property `forceLocalRenderer: true` qui force le `ZoneCanvasPainter` legacy local sous `Loader`.

---

## 6. Récap "quoi sert à quoi"

| Techno | Pourquoi choisie |
|---|---|
| `QCanvasPainterItem` (Qt 6.11) | Rendu GPU 2D impératif, API proche Canvas. Pas de QPainter CPU main thread. Seule alternative GPU pour scanline complexe (Shape ne fait pas ça). |
| Viewport culling (1 item global) | `QQuickRhiItem` backing = `w×h×dpr` → exploser la VRAM au zoom évité. Un seul item de la taille de l'écran. |
| `QtConcurrent::run` + `QFutureWatcher` | Calcul scanline en background, sans bloquer ni le main ni le render thread. Marche parce qu'on parallélise AVANT le rendu, pas dedans. |
| `QtConcurrent::blockingMapped` (rejeté) | Confirmé contre-productif quand N items submittent en // → saturation pool global. |
| Triple buffer atomic peek+swap | Lock-free ; consommateur peut tirer > producteur sans rejouer son propre dépôt. |
| Cache pré-calculé en setter | Setter sur main thread, sync sur render thread. Faire le travail UNE fois, pas N. |
| `float` au lieu de `qreal` (hot path) | Cache-line density × 2, précision suffisante pour des coords pixel. |
| `Loader.active` | Vrai démantèlement de l'item, libère le backing GPU. |
| `mmSize` real + ×1.1 | Zoom continu, sinon arrondi à chaque cran. |

---

## 7. Métriques de référence (Qt 6.11.0 Release, 144 Hz vsync DWM, 2026-05-07/08)

### Frame mean (ms) — gain async vs baseline (négatif = mieux)
| Cas | Baseline | Async | Δ |
|---|---:|---:|---:|
| `renderScaling/500` | 22.41 | 14.71 | −34 % |
| `renderScaling/1000` | 34.91 | 30.34 | −13 % |
| `renderScaling/2000` | 82.80 | 73.09 | −12 % |
| `hatchComplexity/100z 80v` | 13.89 | 8.80 | −37 % |
| `hatchComplexity/200z 40v` | 13.89 | 9.78 | −30 % |
| `hatchComplexity/100 grandes r10 30v` | 13.88 | 7.40 | −47 % |
| `extremeCombo/100huge60` | 14.00 | 7.72 | −45 % |
| `extremeCombo/1000tiny` | 41.65 | 36.01 | −14 % |
| `zoomBurst/1000` | 42.69 | 40.62 | −5 % (bench limité, chaque tick relance N tasks) |

### Grille — `resizeCroisillons` 5it
| Mode | Mean | Max |
|---|---:|---:|
| Repeater (legacy) | 75.66 ms | 101.69 ms |
| Canvas | 6.96 ms | 7.21 ms |
| **Δ** | **−91 %** | **× 14** |

---

## 8. Pistes restantes (non implémentées)

- **Subdivision spatiale + N overlays** (chunks 1024×1024) — combine batching + FBO de taille saine.
- **Pre-tessellation côté C++** : convertir le polygone en triangles une fois, retransformer au zoom (matrix scale).
- **Cache des hachures en coords grille** (Strat F) : sur zoomBurst le polygone est fixe, seul `gridSize` change.
- **Réduction dynamique des hachures** selon `scaleLevel`.
- **`QCanvasGridPattern` ou `QCanvasImagePattern`** (Qt 6.11) pour le pattern de hachures au lieu d'un scanline manuel.
- **Interpolation tick-aware** côté `PhysicsActor` (lerp prev/curr) si on veut zéro stutter à 144 Hz. Lissage exponentiel `smoothing=0.3` actuel suffit en pratique.

## 9. Benchmarks

### `tst_zone_render_perf` (Qt Test)
Mesure `mean/p50/p95/p99/max` du frame time + CPU pur `paint()` / `sync()` (atomics `s_totalPaintNs / s_paintCalls / s_totalSyncNs / s_syncCalls`). Datasets : `renderScaling`, `hatchComplexity`, `zoomBurst`, `hugeZoneZoom`, `concaveStar`, `extremeCombo`. Build dédié dans `build_perf/`, run via PowerShell pour le PATH des DLLs.

### `tst_grid_render_perf`
Comparaison Repeater vs Canvas (`croisillons=600`) : `staticIdle`, `zoomBurst`, `panBurst`, `resizeCroisillons`. Le différentiel idle est masqué par le palier vsync 144 Hz.

### Bench combiné
Reproduit le centrage de zoom de l'éditeur sur `test_map.json` (commits `08affec`, `df87c50`). Inclut `zoomBurst` exact (`gridSize=200 px`) et `zoomBurstWide` (mmSize 5→1000, 100 étapes).
