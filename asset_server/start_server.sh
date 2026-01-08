#!/bin/

echo "==================================="
echo "  Serveur Meownopoly Resources"
echo "==================================="
echo

# Vérifier si Node.js est installé
if ! command -v node &> /dev/null; then
    echo "ERREUR: Node.js n'est pas installé ou pas dans le PATH"
    echo "Téléchargez Node.js depuis https://nodejs.org/"
    read -p "Appuyez sur Entrée pour continuer..."
    exit 1
fi

# Vérifier si les dépendances sont installées
if [ ! -d "node_modules" ]; then
    echo "Installation des dépendances..."
    npm install
    if [ $? -ne 0 ]; then
        echo "ERREUR: Échec de l'installation des dépendances"
        read -p "Appuyez sur Entrée pour continuer..."
        exit 1
    fi
fi

echo "Démarrage du serveur..."
echo
echo "Le serveur sera accessible sur:"
echo "- Local: http://localhost:8080"
echo "- Réseau: http://$(hostname):8080"
echo
echo "Appuyez sur Ctrl+C pour arrêter le serveur"
echo

# Démarrer le serveur
npm start
