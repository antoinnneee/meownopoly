# Rapport du jalon R1 — Banc d'essai hors-process `meow_testbench`

> **Statut : rapport de mesure (2026-07-17).** Résultats factuels du protocole
> R1 ([doc 12](./12_BANC_ESSAI_R1.md) §8) exécuté sur la piste A complète
> (A1→A9, commits `29b6d835` → `faebcfd6`). Ce rapport **ne tranche pas** le
> go/no-go : la décision (Q-J06, [doc 09](./09_QUESTIONNAIRE_CADRAGE.md))
> appartient à **Antoine et Valou**. Il fournit les mesures et une
> recommandation argumentée, rien de plus.

## 1. Objet

Le jalon R1 ([doc 15](./15_PLAN_IMPLEMENTATION.md), encadré « JALON R1 »)
conditionne la suite de D1 (QML génératif) aux critères de sortie Q-J06 :

- **échec d'isolation** → repli « palette + mémoire » (briques + espace mémoire
  + règles en config/DSL, sans QML génératif) ;
- **tick > 0,5 ms systématique** → réduction « config modules + DSL »
  (pas de JS libre) ;
- sinon → **go** pour les phases 2+ dépendant du QML génératif.

Périmètre mesuré : la piste A entière — cible headless `meow_testbench` (A1),
protocole job/verdict `MEOWBENCH:` (A2), superviseur `QProcess` avec timeout dur
`MEOW_BENCH_TIMEOUT_MS` = 30 s (A3), préfiltre statique P0 (A4), pipeline
P1→P5 (A5), contexte restreint + façade `Meow.GameApi` (A6), corpus de 9
artefacts `test_artifacts/` (A7), pool + cache de verdicts (A8),
`artifact_dryrun` (A9).

## 2. Environnement et méthode

| | |
|---|---|
| Machine | Windows 10 Pro 10.0.19045 (machine de dev Antoine) |
| Kit | Qt 6.11.0 MinGW 13.1, build `Release` Ninja Multi-Config |
| Binaire | `build/Release/meow_testbench.exe` (cible `EXCLUDE_FROM_ALL`, bâtie le 2026-07-17) |
| Plateforme | `-platform offscreen`, `QT_PLUGIN_PATH=C:\Qt\6.11.0\mingw_64\plugins` |
| Corpus | `Meownopoly/test_artifacts/` (9 artefacts, `corpus.json`, seed 42, budgets D34 par défaut) |
| Protocole | 3 runs complets et séparés du corpus (27 exécutions du banc + 27 passes P0) |

Méthode : harnais de mesure reproduisant exactement l'assemblage de job et
l'**ordre réel du pipeline** de `test_artifacts/run_corpus.ps1` (P0 statique
via `--static-check` d'abord ; le banc P1→P5 n'est spawné que si P0 passe),
avec capture du JSON de verdict **complet** par artefact et par run, du temps
mur externe (spawn compris), et vérification des orphelins après chaque run.
Un timeout superviseur de 35 s (miroir de `MEOW_BENCH_TIMEOUT_MS` + marge)
armait le kill externe — il **n'a jamais été nécessaire**.

## 3. Résultats bruts

### 3.1 Verdicts par artefact et par run

Verdicts et codes d'échec **strictement identiques sur les 3 runs** pour les
9 artefacts. `durée` = temps mur externe du banc, spawn du process compris
(pour `import_interdit`, temps de la passe P0 seule).

| Artefact | Attendu (corpus) | Obtenu (runs 1/2/3) | Étape | Durée r1/r2/r3 (ms) |
|---|---|---|---|---|
| `sain_plaque_piegee.qml` | `pass` | `pass` / `pass` / `pass` | banc P1→P5 | 576 / 567 / 568 |
| `boucle_infinie_onload.qml` | `load_timeout` | `load_timeout` ×3 | banc P2 (watchdog) | 5185 / 5087 / 5079 |
| `boucle_infinie_handler.qml` | `event_budget`\|`bench_timeout` | `event_budget` ×3 | banc P4 (watchdog) | 5172 / 5163 / 5066 |
| `timer_spam.qml` | `event_flood` | `event_flood` ×3 | banc P4 | 578 / 567 / 568 |
| `alloc_massive.qml` | `object_quota`\|`runaway_alloc` | `runaway_alloc` ×3 | banc P4 | 1284 / 1276 / 1278 |
| `import_interdit.qml` | `import_forbidden`\|`load_failed` | `import_forbidden`+`forbidden_construct` ×3 | **P0** (banc jamais spawné) | 25 / 22 / 21 |
| `acces_singleton.qml` | `load_failed` | `load_failed` ×3 | banc P2 | 74 / 65 / 66 |
| `writeset_hors_declaration.qml` | `writeset_violation` | `writeset_violation` ×3 | banc P4 | 573 / 569 / 566 |
| `fuite_teardown.qml` | `leak` | `leak` ×3 | banc P5 | 573 / 568 / 566 |

La passe P0 statique coûte 20-26 ms par artefact (les 8 artefacts
non-`import_interdit` la franchissent, conformément au design du corpus).

### 3.2 Métriques du banc (run 1 ; runs 2-3 équivalents)

| Artefact | loadMs | tick p50 (µs) | tick p95 (µs) | tick max (µs) | mémoire retenue (Mo) | objets | émissions/s |
|---|---|---|---|---|---|---|---|
| `sain_plaque_piegee` | 0 | 1 | 1 | 10 | 0,8 | 2 | 0 |
| `timer_spam` | 4 | 1 | 1 | 1130 | 1,1 | 2 | 690,8 |
| `alloc_massive` | 703 | 1 | 1 | 16 | 128,8 | 2 | 0 |
| `writeset_hors_declaration` | 0 | 1 | 1 | 11 | 0,8 | 2 | 0 |
| `fuite_teardown` | 0 | 1 | 1 | 26 | 0,9 | 3 | 0 |

(Les cas tués en P2/P4 par watchdog n'ont pas de métriques de tick — attendu.)

Détails probants relevés dans les verdicts :

- `acces_singleton` : `TypeError: Cannot read property 'currentMap' of
  undefined` (P2) — `Game.` et `Catway.` sont bien `undefined` dans le contexte
  restreint : **masquage prouvé**, l'artefact n'atteint aucun singleton.
- `boucle_infinie_onload` : « chargement > 5000 ms […] process tué, le jeu n'a
  jamais gelé » — kill par le **watchdog interne** du banc (~5,1 s), pas par le
  timeout superviseur de 30 s.
- `timer_spam` : « 347 émissions en 0,50 s de temps réel (694,0/s) > plafond
  30/s » — mesure dans la fenêtre temps réel de 500 ms.
- `alloc_massive` : « pic mémoire 128,8 Mo > budget 8 Mo (delta RSS depuis
  P1) » — coupé par le budget artefact (8 Mo), très loin sous le plafond
  d'auto-préservation du banc (512 Mo).
- `writeset_hors_declaration` : « écriture observée hors write-set déclaré :
  tile-piege-02/state/secret ».
- `fuite_teardown` : « 2 appel(s) à la façade après teardown ».

### 3.3 Orphelins

`tasklist` après chacun des 3 runs et en fin de campagne : **aucun process
`meow_testbench` survivant**. Les kills des cas pathologiques (verdict flushé
puis `_exit` par le thread de surveillance) ne laissent pas d'orphelin.

## 4. Mesures vs critères de sortie R1 (doc 12 §8 / Q-J06)

| # | Critère | Seuil | Mesure | Résultat |
|---|---|---|---|---|
| 1 | Kill 100 % des cas pathologiques | tout cas verdicté, jamais de gel | 12/12 exécutions pathologiques à watchdog (2 boucles infinies × 3 runs + les cas P4/P5) verdictées en ≤ 5,2 s ; timeout superviseur 30 s jamais sollicité ; 0 orphelin | **OK** |
| 2 | Reproductibilité | 3 runs ⇒ mêmes verdicts (seed fixe) | 9/9 artefacts : verdicts **et** codes d'échec identiques sur les 3 runs | **OK** |
| 3a | Démarrage à froid | < 2 s | validation saine complète, spawn compris : 567-576 ms (in-process `durationMs` : 546-555 ms) ; rejet P2 : 65-74 ms | **OK** (marge ×3,5) |
| 3b | Validation complète | < 8 s par artefact | pire cas sain : 576 ms ; pire cas toutes catégories : 5185 ms (= watchdog 5 s qui tue, pas une lenteur) | **OK** |
| 4 | Masquage prouvé | `acces_singleton.qml` bloqué | `load_failed` en P2 sur les 3 runs, `Game`/`Catway` = `undefined` (TypeError) | **OK** |
| 5 | Pas de faux positif | artefact sain ⇒ `pass` stable | `pass` sur les 3 runs, toutes métriques dans les budgets | **OK** |
| — | Budget tick (Q-J06, réduction) | p50/p95 ≤ 0,5 ms | p50 = 1 µs, p95 = 1 µs sur tous les cas mesurables (pic ponctuel p95 = 22 µs sur un run de `timer_spam`) — **500× sous le budget** | **OK** |
| — | Comportement mémoire | RSS banc ≤ 512 Mo | jamais approché ; l'alloc massive est coupée dès 128,8 Mo par le budget artefact 8 Mo ; artefact sain : 0,8 Mo retenu | **OK** |

**Les 5 critères R1 sont tenus, ainsi que les deux conditions de repli Q-J06
(isolation et budget tick).** Le pool (A8) n'a même pas été nécessaire pour
tenir le coût : le spawn à froid par job reste sous les seuils.

## 5. Écarts, limites et constats mineurs

À verser au dossier — aucun n'invalide les mesures ci-dessus :

1. **Snapshot de map vide dans le corpus** (`snapshot.map = {}`, `tileCount` = 0) :
   le coût de P1 (reconstruction d'une vraie map + moteur physique chargé) et le
   coût de tick avec une carte réelle ne sont **pas couverts** par R1. Les tick
   p50/p95 à 1 µs mesurent des artefacts volontairement légers dans un monde
   vide. La marge (×500) est énorme, mais le budget 0,5 ms devra être
   re-vérifié au vertical slice (phase 2, scénarios S1/S2/S3) avec map réelle.
2. **Pool et cache (A8) non exercés** par ce protocole : chaque job spawn un
   banc à froid (c'est la mesure la plus défavorable — et elle passe). Le gain
   du pool/cache reste à mesurer en conditions réelles, mais il n'est plus une
   condition de viabilité (le doc 12 §8 le rendait « obligatoire » seulement si
   froid ≥ 2 s ou validation ≥ 8 s — non atteints).
3. **Doublon cosmétique** : `timer_spam` produit deux failures `event_flood`
   quasi identiques (deux fenêtres de mesure). Sans effet sur le verdict ;
   nettoyage possible, non bloquant.
4. **Mesures mono-plateforme** : Windows/MinGW uniquement. La qualification
   Linux (M13) reste à faire — les mécanismes de watchdog RSS/`_exit` sont à
   re-vérifier sur l'autre OS.
5. **Variation métrique ponctuelle** : un run de `timer_spam` a un tick p95 à
   22 µs (vs 1 µs) — bruit d'ordonnanceur sous flood. Les **verdicts** restent
   strictement identiques ; la reproductibilité exigée (verdicts, pas
   micro-métriques) est tenue.
6. **Constat d'outillage, hors banc** : `run_corpus.ps1` (la redirection via
   `cmd /c`) s'est bloqué dans l'environnement d'agent non interactif utilisé
   pour cette campagne ; les mesures ont été prises par un harnais équivalent
   (assemblage de job et ordre du pipeline identiques, capture des verdicts
   complets). À la main dans une console interactive, le script du repo reste
   l'outil de référence.

## 6. Recommandation (sans décision)

Au vu des mesures : **aucun des deux déclencheurs de repli Q-J06 n'est
observé**. L'isolation produit un verdict fiable et reproductible (27/27
exécutions conformes, masquage des singletons prouvé par TypeError, kill 100 %
sans orphelin ni gel), et le budget tick est tenu avec une marge de deux ordres
de grandeur. Les coûts (froid < 0,6 s, validation < 8 s même pour les cas tués)
sont très en deçà des seuils, sans même recourir au pool.

La recommandation argumentée de cette campagne est donc **go** pour la suite de
D1 (engagement des phases 2+ dépendant du QML génératif), avec deux réserves de
suivi : re-mesurer le tick au vertical slice avec une map réelle (§5.1) et
qualifier Linux (§5.4). Les replis « palette + mémoire » et « config modules +
DSL » ne sont, sur ces mesures, justifiés par aucun critère — ils restent les
sorties de secours documentées si le vertical slice infirme les marges.

**Ce rapport ne tranche pas.** Le go/no-go du jalon R1 est une décision
humaine ([doc 09](./09_QUESTIONNAIRE_CADRAGE.md) Q-J06/Q-J08) : elle revient à
**Antoine et Valou**, ce document n'étant que la base factuelle de leur
arbitrage.
