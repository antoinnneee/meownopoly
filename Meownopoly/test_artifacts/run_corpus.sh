#!/usr/bin/env bash
# ============================================================================
# Harnais de validation R1 du banc d'essai — équivalent Linux de run_corpus.ps1
# (doc v3 12 §8, tâche A7 ; portage L3 « CI Windows + Linux »).
# ============================================================================
#
# Pour chaque artefact de corpus.json, dans l'ORDRE réel du pipeline (doc 12 §3) :
#   1. P0 — préfiltre statique (`meow_testbench --static-check`, StaticValidator).
#      Un rejet P0 (ex. import hors allow-list) est le verdict : le banc n'est
#      PAS spawné.
#   2. P1→P5 — sinon on assemble un job (source inline) et on lance le banc.
# Chaque artefact est joué $RUNS fois (défaut 3) pour vérifier :
#   - le code de verdict attendu (`expect`) ;
#   - la REPRODUCTIBILITÉ (mêmes verdicts sur les 3 runs, à seed fixe) ;
#   - le KILL 100 % (tout cas pathologique rend un verdict, jamais de gel) ;
#   - le COÛT (validation saine < 8 s ; démarrage froid < 2 s).
#
# Dépendances : bash, jq, sha256sum (coreutils). Qt doit être découvrable par le
# linker (LD_LIBRARY_PATH) — sur CI, install-qt-action le fait ; en local, la
# variable est en général déjà positionnée par le kit Qt.
#
# Exécuter APRÈS avoir bâti la cible :
#   cmake --build build --config Release --target meow_testbench
#
# Usage : run_corpus.sh [chemin_du_banc] [runs]
# Sortie : 0 si le corpus est vert, 1 sinon, 2 si environnement invalide.
# ============================================================================

set -u

BENCH_EXE="${1:-}"
RUNS="${2:-3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Dépendances outillage -------------------------------------------------
for tool in jq sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERREUR : outil manquant : $tool (installer jq / coreutils)" >&2
        exit 2
    fi
done

# --- Résolution du binaire du banc -----------------------------------------
if [ -z "$BENCH_EXE" ]; then
    for candidate in \
        "$SCRIPT_DIR/../../build/Release/meow_testbench" \
        "$SCRIPT_DIR/../../build/meow_testbench" \
        "$SCRIPT_DIR/../../build/Debug/meow_testbench"; do
        if [ -x "$candidate" ]; then BENCH_EXE="$candidate"; break; fi
    done
fi
if [ -z "$BENCH_EXE" ] || [ ! -x "$BENCH_EXE" ]; then
    echo "ERREUR : banc introuvable : ${BENCH_EXE:-<non résolu>}" >&2
    echo "Bâtir d'abord : cmake --build build --config Release --target meow_testbench" >&2
    exit 2
fi
BENCH_EXE="$(cd "$(dirname "$BENCH_EXE")" && pwd)/$(basename "$BENCH_EXE")"

# Le banc tourne offscreen (aucun rendu évalué).
export QT_QPA_PLATFORM=offscreen

CORPUS="$SCRIPT_DIR/corpus.json"
if [ ! -f "$CORPUS" ]; then
    echo "ERREUR : corpus.json introuvable : $CORPUS" >&2
    exit 2
fi

BENCH_VERSION="$(jq -r '.benchVersion' "$CORPUS")"
SEED="$(jq -r '.seed' "$CORPUS")"
BUDGETS="$(jq -c '.defaultBudgets' "$CORPUS")"

# Lance le banc et retourne la dernière ligne de verdict JSON (préfixe retiré),
# ou une chaîne vide. stderr est jeté (les plugins Qt bavardent en offscreen).
run_bench() {
    local out
    out="$("$BENCH_EXE" "$@" 2>/dev/null)"
    printf '%s\n' "$out" | grep '^MEOWBENCH:' | tail -n1 | sed 's/^MEOWBENCH://'
}

# Signature d'un verdict : "<verdict>|<codes triés>". Sert au test de repro.
verdict_signature() {
    local v="$1"
    if [ -z "$v" ]; then echo "<aucun-verdict>"; return; fi
    echo "$v" | jq -r '(.verdict // "<none>") + "|" +
        ([.failures[]?.code] | sort | join(","))' 2>/dev/null || echo "<parse-error>"
}

now_ms() { echo $(( $(date +%s%N) / 1000000 )); }

# --- Accumulateurs ----------------------------------------------------------
declare -a ROWS=()
ALL_KILL_OK=1
ALL_REPRO_OK=1
ALL_VERDICT_OK=1
MAX_HEALTHY_MS=0
MAX_COLD_MS=0
SINGLETON_OK=0
HEALTHY_OK=0

# --- Boucle sur le corpus (process substitution : garde les accumulateurs) --
while read -r art; do
    file="$(echo "$art" | jq -r '.file')"
    uuid="$(echo "$art" | jq -r '.targetUuid')"
    qml="$SCRIPT_DIR/$file"
    expect_json="$(echo "$art" | jq -c '(.expect | if type=="array" then . else [.] end)')"
    write_set="$(echo "$art" | jq -c 'if has("writeSet") then .writeSet else null end')"
    stimuli="$(echo "$art" | jq -c 'if has("stimuli") then .stimuli else [] end')"

    if [ ! -f "$qml" ]; then
        echo "ERREUR : artefact manquant : $qml" >&2
        exit 2
    fi
    source_qml="$(cat "$qml")"
    hash="$(printf '%s' "$source_qml" | sha256sum | cut -d' ' -f1)"

    # Job JSON (miroir de run_corpus.ps1 / doc 12 §2.3).
    job_id="corpus_${file%.qml}"
    job_file="$(mktemp)"
    jq -n \
        --arg jobId "$job_id" \
        --argjson bv "$BENCH_VERSION" \
        --arg src "$source_qml" \
        --arg uuid "$uuid" \
        --arg hash "$hash" \
        --argjson writeSet "$write_set" \
        --argjson budgets "$BUDGETS" \
        --argjson stimuli "$stimuli" \
        --argjson seed "$SEED" \
        '{
            jobId: $jobId,
            benchVersion: $bv,
            snapshot: { map: {}, memory: {}, modules: [] },
            artifact: ( { source: $src, targetUuid: $uuid, contentHash: $hash }
                        + (if $writeSet == null then {} else { writeSet: $writeSet } end) ),
            budgets: $budgets,
            stimuli: $stimuli,
            seed: $seed
        }' > "$job_file"

    declare -a signatures=()
    last_verdict=""
    stage=""
    max_ms=0
    for ((i = 0; i < RUNS; i++)); do
        t0="$(now_ms)"
        # 1) P0 statique (ordre réel du pipeline) — le banc n'est spawné qu'après.
        verdict="$(run_bench -platform offscreen --static-check "$qml")"
        v_kind="$(echo "$verdict" | jq -r '.verdict // ""' 2>/dev/null)"
        if [ "$v_kind" = "fail" ]; then
            stage="P0"
        else
            # 2) P1→P5.
            verdict="$(run_bench -platform offscreen "$job_file")"
            stage="bench"
        fi
        t1="$(now_ms)"
        dur=$(( t1 - t0 ))
        [ "$dur" -gt "$max_ms" ] && max_ms="$dur"
        last_verdict="$verdict"
        signatures+=("$(verdict_signature "$verdict")")
    done
    rm -f "$job_file"

    # Analyse du dernier verdict.
    got_verdict="<aucun>"
    got_codes=""
    if [ -n "$last_verdict" ]; then
        got_verdict="$(echo "$last_verdict" | jq -r '.verdict // "<aucun>"')"
        got_codes="$(echo "$last_verdict" | jq -r '[.failures[]?.code] | join(",")')"
    fi

    expects_pass="$(echo "$expect_json" | jq -r 'index("pass") != null')"
    if [ "$expects_pass" = "true" ]; then
        [ "$got_verdict" = "pass" ] && expect_ok=1 || expect_ok=0
    else
        expect_ok=0
        if [ "$got_verdict" = "fail" ]; then
            match="$(echo "$last_verdict" | jq --argjson exp "$expect_json" -r \
                '[.failures[]?.code] as $got | ($got | map(. as $c | $exp | index($c)) | any)')"
            [ "$match" = "true" ] && expect_ok=1
        fi
    fi

    # Reproductibilité : signatures toutes identiques.
    repro_ok=1
    first_sig="${signatures[0]}"
    for s in "${signatures[@]}"; do
        [ "$s" != "$first_sig" ] && repro_ok=0
    done

    # Kill : un verdict a été rendu.
    kill_ok=0
    [ -n "$last_verdict" ] && kill_ok=1

    [ "$max_ms" -gt "$MAX_COLD_MS" ] && MAX_COLD_MS="$max_ms"
    if [ "$expects_pass" = "true" ] && [ "$max_ms" -gt "$MAX_HEALTHY_MS" ]; then
        MAX_HEALTHY_MS="$max_ms"
    fi

    [ "$kill_ok" -eq 0 ] && ALL_KILL_OK=0
    [ "$repro_ok" -eq 0 ] && ALL_REPRO_OK=0
    [ "$expect_ok" -eq 0 ] && ALL_VERDICT_OK=0

    if [ "$file" = "acces_singleton.qml" ] && [ "$expect_ok" -eq 1 ]; then SINGLETON_OK=1; fi
    if [ "$file" = "sain_plaque_piegee.qml" ] && [ "$expect_ok" -eq 1 ]; then HEALTHY_OK=1; fi

    obtenu="$got_codes"
    [ "$got_verdict" = "pass" ] && obtenu="pass"
    v_mark=$([ "$expect_ok" -eq 1 ] && echo OK || echo X)
    r_mark=$([ "$repro_ok" -eq 1 ] && echo OK || echo X)
    k_mark=$([ "$kill_ok" -eq 1 ] && echo OK || echo X)
    printf -v row '%-32s %-24s %-24s %-6s %-8s %-6s %-5s %6sms' \
        "$file" "$(echo "$expect_json" | jq -r 'join("|")')" "$obtenu" \
        "$stage" "$v_mark" "$r_mark" "$k_mark" "$max_ms"
    ROWS+=("$row")
done < <(jq -c '.artifacts[]' "$CORPUS")

# --- Rapport ----------------------------------------------------------------
echo ""
printf '%-32s %-24s %-24s %-6s %-8s %-6s %-5s %8s\n' \
    "Artefact" "Attendu" "Obtenu" "Stage" "Verdict" "Repro" "Kill" "MaxMs"
printf '%.0s-' {1..118}; echo ""
for r in "${ROWS[@]}"; do echo "$r"; done
echo ""

echo "=== Critères R1 (doc 12 §8) ==="
mark() { [ "$1" -eq 1 ] && echo "OK " || echo "X  "; }
c3valid=$([ "$MAX_HEALTHY_MS" -lt 8000 ] && echo 1 || echo 0)
c3cold=$([ "$MAX_HEALTHY_MS" -lt 2000 ] && echo 1 || echo 0)
echo "[$(mark "$ALL_KILL_OK")] 1. Kill 100 % : tout cas verdicté, jamais de gel"
echo "[$(mark "$ALL_REPRO_OK")] 2. Reproductibilité : $RUNS runs => mêmes verdicts"
echo "[$(mark "$c3cold")] 3a. Démarrage sain < 2 s (max sain observé : ${MAX_HEALTHY_MS} ms)"
echo "[$(mark "$c3valid")] 3b. Validation saine < 8 s (max sain : ${MAX_HEALTHY_MS} ms)"
echo "[$(mark "$SINGLETON_OK")] 4. Masquage prouvé (acces_singleton bloqué en P2)"
echo "[$(mark "$HEALTHY_OK")] 5. Pas de faux positif (artefact sain => pass)"
echo "    note: les cas pathologiques à timeout durent ~5 s (watchdog qui tue,"
echo "    pas un démarrage lent) ; max toutes catégories : ${MAX_COLD_MS} ms"
echo ""

if [ "$ALL_VERDICT_OK" -eq 1 ] && [ "$ALL_KILL_OK" -eq 1 ] && \
   [ "$ALL_REPRO_OK" -eq 1 ] && [ "$SINGLETON_OK" -eq 1 ] && [ "$HEALTHY_OK" -eq 1 ]; then
    echo "CORPUS R1 : VERT"
    if [ "$c3valid" -eq 0 ]; then
        echo "NOTE coût : cible non tenue en spawn froid => pool recommandé (A8, doc 12 §6)."
    fi
    exit 0
else
    echo "CORPUS R1 : ROUGE (voir X ci-dessus)"
    exit 1
fi
