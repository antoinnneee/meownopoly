#!/bin/bash
echo "Déploiement du chat server..."
# Charger les variables depuis .deployEnv
if [ ! -f .deployEnv ]; then
    echo "⚠️  Fichier .deployEnv introuvable. Création d'un template..."
    cat <<EOF > .deployEnv
# Configuration de déploiement
REMOTE_USER="votre-utilisateur"
REMOTE_HOST="votre-ip-ou-domaine"
REMOTE_DIR="/chemin/vers/destination"
REMOTE_PASSWORD="mot-de-passe-distant"
SERVICE_NAME="nom-du-service"
EOF
    echo "❌ Un template .deployEnv a été créé. Veuillez le remplir avant de relancer le déploiement."
    exit 1
fi

set -a
. ./.deployEnv
set +a

# Nettoyage des variables (enlève les guillemets et les retours chariot Windows \r)
REMOTE_USER=$(echo "$REMOTE_USER" | sed 's/[\"\r]//g')
REMOTE_HOST=$(echo "$REMOTE_HOST" | sed 's/[\"\r]//g')
REMOTE_DIR=$(echo "$REMOTE_DIR" | sed 's/[\"\r]//g')
REMOTE_PASSWORD=$(echo "$REMOTE_PASSWORD" | sed 's/[\"\r]//g')
SERVICE_NAME=$(echo "$SERVICE_NAME" | sed 's/[\"\r]//g')

# Vérification des variables requises
if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_DIR" ] || [ -z "$SERVICE_NAME" ] || [ -z "$REMOTE_PASSWORD" ]; then
    echo "❌ Erreur : Variables de déploiement manquantes dans .deployEnv."
    exit 1
fi

# Configuration SSH Multiplexing (pour ne demander le mdp qu'une fois)
SSH_MUX_SOCKET="/tmp/ssh_mux_${REMOTE_HOST}_${REMOTE_USER}"
SSH_OPTS="-o ControlMaster=auto -o ControlPath=$SSH_MUX_SOCKET -o ControlPersist=600"

# Fonction de nettoyage pour fermer la connexion SSH
cleanup_ssh() {
    if [ -S "$SSH_MUX_SOCKET" ]; then
        echo "🔒 Fermeture de la connexion SSH..."
        ssh -O exit -o "ControlPath=$SSH_MUX_SOCKET" "$REMOTE_USER@$REMOTE_HOST" 2>/dev/null
    fi
}
trap cleanup_ssh EXIT

echo "🚀 Début du déploiement vers $REMOTE_HOST..."

# Établir la connexion maître
echo "🔑 Connexion au serveur..."
ssh $SSH_OPTS -fNM "$REMOTE_USER@$REMOTE_HOST"

# Fichiers à copier (exclut node_modules)
FILES=(
    "server.js"
    "database.js"
    "cleanup.js"
    "package.json"
    "package-lock.json"
    ".env"
    "README.md"
    "setup-domain.sh"
    "dashboard.html"
    "dashboard.css"
    "dashboard.js"
    "labo.html"
    "chat_crypto.js"
    "simple_stun.js"
)

# Copie des fichiers
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "📦 Copie de $file..."
        scp -o "ControlPath=$SSH_MUX_SOCKET" "$file" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
    else
        echo "⚠️  Fichier introuvable : $file"
    fi
done

# Installation des dépendances et redémarrage du service
echo "🔄 Mise à jour des dépendances et redémarrage du service..."
ssh -o "ControlPath=$SSH_MUX_SOCKET" "$REMOTE_USER@$REMOTE_HOST" "cd $REMOTE_DIR && npm install --production && echo '$REMOTE_PASSWORD' | sudo -S systemctl restart $SERVICE_NAME"

echo "✅ Déploiement terminé !"
