#!/usr/bin/env bash
# sync_from_remote.sh — Recupere un dossier distant via SSH en ne transferant que les mises a jour (delta)
#
# Usage:
#   ./sync_from_remote.sh user@host:/chemin/distant /chemin/local
#   ./sync_from_remote.sh user@host:/chemin/distant              # sync dans le repertoire courant
#
# Options (variables d'environnement) :
#   SSH_PORT=2222        port SSH alternatif (defaut: 22)
#   DRY_RUN=1            simuler sans rien copier
#   EXCLUDE="*.log"      pattern a exclure (separateur : virgule)

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <user@host:/chemin/distant> [/chemin/local]"
    echo ""
    echo "Exemples:"
    echo "  $0 pi@192.168.1.10:/home/pi/projet ./projet_local"
    echo "  SSH_PORT=2222 $0 user@server:/data/assets ."
    echo "  DRY_RUN=1 $0 user@server:/data/assets ./assets"
    exit 1
fi

REMOTE="$1"
LOCAL="${2:-.}"
SSH_PORT="${SSH_PORT:-22}"
DRY_RUN="${DRY_RUN:-0}"
EXCLUDE="${EXCLUDE:-}"

# Construction des options rsync
RSYNC_OPTS=(
    -avz                # archive + verbose + compression
    --update            # ne remplace que si le fichier source est plus recent
    --progress          # affiche la progression
    --partial           # garde les transferts partiels (reprise possible)
    --delete            # supprime les fichiers locaux absents du distant
    -e "ssh -p ${SSH_PORT}"
)

# Mode simulation
if [[ "$DRY_RUN" == "1" ]]; then
    RSYNC_OPTS+=(--dry-run)
    echo "[DRY RUN] Simulation — aucun fichier ne sera modifie"
fi

# Exclusions
if [[ -n "$EXCLUDE" ]]; then
    IFS=',' read -ra PATTERNS <<< "$EXCLUDE"
    for pattern in "${PATTERNS[@]}"; do
        RSYNC_OPTS+=(--exclude "$pattern")
    done
fi

echo "=== Synchronisation ==="
echo "  Source  : $REMOTE"
echo "  Dest    : $LOCAL"
echo "  Port SSH: $SSH_PORT"
echo ""

rsync "${RSYNC_OPTS[@]}" "$REMOTE" "$LOCAL"

echo ""
echo "Synchronisation terminee."
