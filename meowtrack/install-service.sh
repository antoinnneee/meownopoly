#!/bin/bash
# install-service.sh — installe meowtrack comme service systemd (à lancer UNE FOIS
# sur le serveur de dev). Pas de nginx, pas de port 80 : le dashboard écoute
# directement sur un port dédié (MEOWTRACK_PORT du .env), joignable sur l'IP du
# serveur. Ensuite, les mises à jour passent par deploy.sh (qui fait restart).
#
# Usage (sur le serveur, depuis le dossier meowtrack déployé) :
#   ./install-service.sh
#
# Pré-requis : un fichier .env rempli à côté (cf. .env.example), Node.js installé.
set -e

SERVICE_NAME="${SERVICE_NAME:-meownopoly-meowtrack}"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_USER="${RUN_USER:-$(whoami)}"
NODE_BIN="$(command -v node || echo /usr/bin/node)"

echo "🔧 Installation du service systemd '$SERVICE_NAME'"
echo "   Dossier   : $APP_DIR"
echo "   Utilisateur: $RUN_USER"
echo "   Node      : $NODE_BIN"

if [ ! -f "$APP_DIR/.env" ]; then
    echo "⚠️  Aucun .env trouvé dans $APP_DIR."
    echo "   Copie de .env.example → .env (à éditer ensuite : port, token, MEOWTRACK_REPO)."
    cp "$APP_DIR/.env.example" "$APP_DIR/.env"
fi

echo "📦 Installation des dépendances de production..."
( cd "$APP_DIR" && npm install --production )

echo "📝 Écriture de l'unité systemd..."
sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null <<EOF
[Unit]
Description=Meownopoly Meowtrack (suivi bugs/tâches + dashboard)
After=network.target

[Service]
Type=simple
User=$RUN_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$APP_DIR/.env
ExecStart=$NODE_BIN server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Activation et démarrage..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

sleep 2
PORT=$(grep -E '^MEOWTRACK_PORT=' "$APP_DIR/.env" | cut -d= -f2 | tr -d ' \r"')
PORT="${PORT:-7702}"
echo ""
if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "✅ Service '$SERVICE_NAME' actif → dashboard sur le port $PORT."
else
    echo "❌ Le service n'a pas démarré. Logs : sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi
echo ""
echo "Commandes utiles :"
echo "  • Statut  : sudo systemctl status $SERVICE_NAME"
echo "  • Logs    : sudo journalctl -u $SERVICE_NAME -f"
echo "  • Restart : sudo systemctl restart $SERVICE_NAME"
echo ""
echo "⚠️  Pense à ouvrir le port $PORT sur le firewall si l'accès est distant,"
echo "    et à définir MEOWTRACK_TOKEN dans .env (API ouverte sinon)."
