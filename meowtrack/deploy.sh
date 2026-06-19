#!/bin/bash
# Déploiement de meowtrack (dashboard + service) sur le serveur de dev.
# Même pattern que chatServer/deploy.sh : SCP via SSH multiplexing + npm install
# + systemctl restart. node_modules/, meowtrack.db et .env ne sont PAS copiés.
echo "Déploiement de meowtrack..."

# Charger les variables depuis .deployEnv
if [ ! -f .deployEnv ]; then
    echo "⚠️  Fichier .deployEnv introuvable. Création d'un template..."
    cat <<EOF > .deployEnv
# Configuration de déploiement meowtrack
REMOTE_USER="votre-utilisateur"
REMOTE_HOST="votre-ip-ou-domaine"
REMOTE_DIR="/chemin/vers/destination/meowtrack"
REMOTE_PASSWORD="mot-de-passe-distant"
SERVICE_NAME="meownopoly-meowtrack"
EOF
    echo "❌ Un template .deployEnv a été créé. Veuillez le remplir avant de relancer le déploiement."
    exit 1
fi

set -a
. ./.deployEnv
set +a

# Nettoyage des variables (enlève les guillemets et les \r Windows)
REMOTE_USER=$(echo "$REMOTE_USER" | sed 's/[\"\r]//g')
REMOTE_HOST=$(echo "$REMOTE_HOST" | sed 's/[\"\r]//g')
REMOTE_DIR=$(echo "$REMOTE_DIR" | sed 's/[\"\r]//g')
REMOTE_PASSWORD=$(echo "$REMOTE_PASSWORD" | sed 's/[\"\r]//g')
SERVICE_NAME=$(echo "$SERVICE_NAME" | sed 's/[\"\r]//g')

if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_DIR" ] || [ -z "$SERVICE_NAME" ] || [ -z "$REMOTE_PASSWORD" ]; then
    echo "❌ Erreur : Variables de déploiement manquantes dans .deployEnv."
    exit 1
fi

# SSH multiplexing (ne demande le mot de passe qu'une fois)
SSH_MUX_SOCKET="/tmp/ssh_mux_meowtrack_${REMOTE_HOST}_${REMOTE_USER}"
SSH_OPTS="-o ControlMaster=auto -o ControlPath=$SSH_MUX_SOCKET -o ControlPersist=600"

cleanup_ssh() {
    if [ -S "$SSH_MUX_SOCKET" ]; then
        echo "🔒 Fermeture de la connexion SSH..."
        ssh -O exit -o "ControlPath=$SSH_MUX_SOCKET" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null
    fi
}
trap cleanup_ssh EXIT

echo "🚀 Début du déploiement vers $REMOTE_HOST..."
echo "🔑 Connexion au serveur..."
if ! ssh $SSH_OPTS -fNM "$REMOTE_USER@$REMOTE_HOST"; then
    echo "❌ Erreur : impossible d'établir la connexion SSH vers $REMOTE_USER@$REMOTE_HOST."
    exit 1
fi

# S'assurer que le dossier distant existe.
ssh -o "ControlPath=$SSH_MUX_SOCKET" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p '$REMOTE_DIR/dashboard'"

# Fichiers à copier (exclut node_modules, meowtrack.db*, .env, .deployEnv).
FILES=(
    "server.js"
    "mcp.js"
    "db.js"
    "repo.js"
    "repos.js"
    "package.json"
    "package-lock.json"
    "README.md"
    "install-service.sh"
    ".env.example"
)
DASHBOARD_FILES=(
    "dashboard/index.html"
    "dashboard/dashboard.css"
    "dashboard/dashboard.js"
)

COPY_ERRORS=0
copy_one() {
    local file="$1" dest="$2"
    if [ -f "$file" ]; then
        echo "📦 Copie de $file..."
        if ! scp -o "ControlPath=$SSH_MUX_SOCKET" "$file" "$REMOTE_USER@$REMOTE_HOST:$dest"; then
            echo "❌ Échec de copie : $file"; COPY_ERRORS=$((COPY_ERRORS + 1))
        fi
    else
        echo "⚠️  Fichier introuvable : $file"; COPY_ERRORS=$((COPY_ERRORS + 1))
    fi
}

for file in "${FILES[@]}"; do copy_one "$file" "$REMOTE_DIR/"; done
for file in "${DASHBOARD_FILES[@]}"; do copy_one "$file" "$REMOTE_DIR/dashboard/"; done

if [ "$COPY_ERRORS" -gt 0 ]; then
    echo "❌ $COPY_ERRORS fichier(s) non copié(s). Abandon avant le redémarrage du service."
    exit 1
fi

# Installation des dépendances + redémarrage du service.
echo "🔄 Mise à jour des dépendances et redémarrage du service..."
if ! ssh -o "ControlPath=$SSH_MUX_SOCKET" "$REMOTE_USER@$REMOTE_HOST" \
    "cd '$REMOTE_DIR' && npm install --production && echo '$REMOTE_PASSWORD' | sudo -S systemctl restart $SERVICE_NAME"; then
    echo "❌ Erreur lors de l'installation des dépendances ou du redémarrage de $SERVICE_NAME."
    echo "   (Première installation ? Lancer d'abord install-service.sh sur le serveur — voir README.)"
    exit 1
fi

sleep 2
if ssh -o "ControlPath=$SSH_MUX_SOCKET" "$REMOTE_USER@$REMOTE_HOST" \
    "echo '$REMOTE_PASSWORD' | sudo -S systemctl is-active --quiet $SERVICE_NAME"; then
    echo "✅ Déploiement terminé ! Service $SERVICE_NAME actif."
else
    echo "⚠️  Déploiement copié mais $SERVICE_NAME ne semble pas actif. Vérifier : journalctl -u $SERVICE_NAME"
    exit 1
fi
