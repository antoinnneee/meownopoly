# Corpus de test R1 du banc d'essai (`test_artifacts/`)

Livrable de la tâche **A7** (plan v3 [doc 15](../doc/v3/15_PLAN_IMPLEMENTATION.md)).
Corpus d'artefacts QML/JS commité avec le banc pour valider/invalider le
prototype R1 (mesures de sortie, [doc 12](../doc/v3/12_BANC_ESSAI_R1.md) §8).

## Lancer

```powershell
# 1. bâtir la cible du banc (headless, EXCLUDE_FROM_ALL)
cmake --build build --config Release --target meow_testbench
# 2. jouer le corpus (3 runs / artefact, P0 puis P1->P5)
.\Meownopoly\test_artifacts\run_corpus.ps1
```

Sous **Linux** (mêmes verdicts attendus, portage L3 / doc v3 [15](../doc/v3/15_PLAN_IMPLEMENTATION.md)),
l'équivalent est `run_corpus.sh` (dépend de `jq` + `sha256sum`) :

```bash
cmake --build build --config Release --target meow_testbench
Meownopoly/test_artifacts/run_corpus.sh   # [chemin_du_banc] [runs] optionnels
```

Les deux runners sont joués automatiquement par la CI (`.github/workflows/ci.yml`,
job `tests`) sur Windows et Linux.

Le harnais assemble un job par artefact (source inline), respecte l'**ordre réel
du pipeline** — préfiltre statique **P0** (`meow_testbench --static-check`,
[StaticValidator](../cpp/ai/sandbox/static_validator.h)/A4) puis banc **P1→P5** —
et vérifie pour chacun le code de verdict attendu, la reproductibilité, le kill
et le coût. Sortie 0 si le corpus est vert.

## Les 9 artefacts ([doc 12](../doc/v3/12_BANC_ESSAI_R1.md) §8)

| Artefact | Étape | Verdict attendu | Ce qu'il prouve |
|----------|-------|-----------------|-----------------|
| `sain_plaque_piegee.qml` | banc | `pass` | Le fil rouge (doc 11) passe, métriques dans les budgets (critère R1 n°5) |
| `boucle_infinie_onload.qml` | banc P2 | `load_timeout` | `while(true)` au chargement tué par le watchdog, GUI jamais gelé |
| `boucle_infinie_handler.qml` | banc P4 | `event_budget` | Boucle dans un handler tuée par le watchdog de dispatch |
| `timer_spam.qml` | banc P4 | `event_flood` | Timer 1 ms + emit : débit mesuré > plafond dans la fenêtre temps réel |
| `alloc_massive.qml` | banc P4 | `runaway_alloc` | Ballast mémoire retenu > budget 8 Mo (pic RSS échantillonné) |
| `import_interdit.qml` | **P0** | `import_forbidden` | Import hors allow-list rejeté **avant** spawn du banc |
| `acces_singleton.qml` | banc P2 | `load_failed` | `Game.`/`Catway.` → TypeError : **masquage prouvé** (critère R1 n°4) |
| `writeset_hors_declaration.qml` | banc P4 | `writeset_violation` | Écriture d'une clé hors write-set déclaré (D11) |
| `fuite_teardown.qml` | banc P5 | `leak` | Activité de façade au teardown (objet/timer survivant) |

Note : plusieurs codes sont acceptés là où le doc laisse le choix (ex.
`object_quota`/`runaway_alloc`, `event_budget`/`bench_timeout`) — voir
`corpus.json`.

## Critères de réussite R1 ([doc 12](../doc/v3/12_BANC_ESSAI_R1.md) §8, reportés sur Q-J06)

1. **Kill 100 %** — tout cas pathologique est verdicté, jamais de gel du GUI.
2. **Reproductibilité** — 3 runs à seed fixe ⇒ mêmes verdicts.
3. **Coût** — validation saine < 8 s ; démarrage sain < 2 s (les cas
   pathologiques à timeout durent ~5 s : c'est le watchdog qui tue, pas un
   démarrage lent).
4. **Masquage prouvé** — `acces_singleton.qml` n'atteint aucun singleton du jeu.
5. **Pas de faux positif** — l'artefact sain passe ; toute instabilité du
   verdict sur le cas sain est bloquante.

## Notes de conception

- **`import_interdit.qml` est un cas P0**, pas un cas banc : dans le pipeline
  réel l'hôte le rejette avant de payer un process (doc 12 §3). Le harnais
  rejoue donc P0 en premier via `--static-check`. Passé directement au banc, il
  chargerait sans erreur dans l'environnement de dev (le module `QtWebSockets`
  est installé dans le Qt local) — d'où l'importance de tester au niveau P0.
- Les artefacts n'utilisent que l'allow-list D34 (`import QtQuick` + la façade
  `GameApi` injectée par contexte) : les 8 non-`import_interdit` franchissent P0.
- La façade `GameApi` est le seul vocabulaire autorisé
  ([meow_game_api.h](../cpp/ai/sandbox/meow_game_api.h), D34) : `memory`,
  `events`, `stats`, `session`, `player`, `zone`, présentation.
