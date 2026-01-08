#!/bin/bash

# Script de configuration du domaine pour Meownopoly Secure Chat Server
# Usage: ./setup-domain.sh votre-domaine.com

if [ -z "$1" ]; then
    echo "Usage: $0 <votre-domaine.com>"
    echo "Exemple: $0 chat.meownopoly.example.com"
    exit 1
fi

DOMAIN=$1
echo "🚀 Configuration du domaine Chat: $DOMAIN"

# Vérifier si nginx est installé
if ! command -v nginx &> /dev/null; then
    echo "📦 Installation de nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

# Vérifier si certbot est installé
if ! command -v certbot &> /dev/null; then
    echo "📦 Installation de certbot pour SSL..."
    sudo apt install -y certbot python3-certbot-nginx
fi

# Créer la configuration nginx
echo "⚙️  Création de la configuration nginx..."
sudo tee /etc/nginx/sites-available/meownopoly-chat << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Proxy vers l'application Node.js (Chat Server sur port 3000)
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # WebSocket support
        proxy_read_timeout 86400; # Garder la connexion ouverte (24h)
    }
    
    # Logs
    access_log /var/log/nginx/meownopoly_chat_access.log;
    error_log /var/log/nginx/meownopoly_chat_error.log;
}
EOF

# Activer le site
echo "🔗 Activation du site nginx..."
sudo ln -sf /etc/nginx/sites-available/meownopoly-chat /etc/nginx/sites-enabled/
sudo nginx -t

if [ $? -eq 0 ]; then
    sudo systemctl reload nginx
    echo "✅ Configuration nginx activée"
else
    echo "❌ Erreur dans la configuration nginx"
    exit 1
fi

# Configuration SSL avec Let's Encrypt
echo "🔒 Configuration du certificat SSL..."
echo "Assurez-vous que votre domaine pointe déjà vers ce serveur avant de continuer."
read -p "Voulez-vous configurer SSL maintenant pour $DOMAIN ? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo certbot --nginx -d $DOMAIN
    
    if [ $? -eq 0 ]; then
        echo "✅ Certificat SSL configuré avec succès"
        
        # Configurer le renouvellement automatique
        sudo crontab -l | grep -q certbot || {
            (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -
            echo "✅ Renouvellement automatique configuré"
        }
    else
        echo "❌ Erreur lors de la configuration SSL"
    fi
fi

# Créer un service systemd pour l'application
echo "🔧 Création du service systemd..."
sudo tee /etc/systemd/system/meownopoly-chat-server.service << EOF
[Unit]
Description=Meownopoly Secure Chat Server
After=network.target

[Service]
Type=simple
User=meow-server
WorkingDirectory=/home/meow-server/meownopoly/chatServer
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

# Activer et démarrer le service
sudo systemctl daemon-reload
sudo systemctl enable meownopoly-chat-server
sudo systemctl start meownopoly-chat-server

echo ""
echo "🎉 Configuration terminée !"
echo "📡 Votre serveur de chat est maintenant accessible sur: wss://$DOMAIN"
echo ""
echo "Commandes utiles :"
echo "  • Statut du service: sudo systemctl status meownopoly-chat-server"
echo "  • Logs du service: sudo journalctl -u meownopoly-chat-server -f"
echo "  • Redémarrer: sudo systemctl restart meownopoly-chat-server"
echo ""
echo "⚠️  N'oubliez pas d'ouvrir le port 3000 (ou laisser nginx gérer le 80/443) sur votre firewall."
