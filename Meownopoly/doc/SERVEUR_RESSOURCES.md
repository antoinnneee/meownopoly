# Serveur de Ressources Meownopoly

## Vue d'ensemble

Ce document décrit l'architecture et l'implémentation recommandée pour le serveur local qui hébergera les ressources du jeu Meownopoly.

## Architecture du Serveur

### Endpoints API Requis

Le serveur doit implémenter les endpoints suivants :

#### 1. Test de Connexion
```
GET /api/ping
```
**Réponse :**
```json
{
    "status": "ok",
    "message": "Serveur Meownopoly actif",
    "timestamp": "2024-01-15T10:30:00Z"
}
```

#### 2. Vérification de Version
```
GET /api/version
```
**Réponse :**
```json
{
    "version": "1.2.3",
    "timestamp": "2024-01-15T10:30:00Z",
    "description": "Mise à jour des textures et sons",
    "size": 125847296,
    "checksum": "sha256:abc123..."
}
```

#### 3. Téléchargement de Ressources
```
GET /api/download/{version}
```
**Paramètres :**
- `version` : Version spécifique à télécharger (ex: "1.2.3")

**Réponse :** Fichier binaire `.meow` (archive compressée)

#### 4. Upload de Paquet (optionnel)
```
POST /api/upload
```
**Body :** Multipart form data avec le fichier `.meow`

**Réponse :**
```json
{
    "success": true,
    "version": "1.2.4",
    "message": "Paquet uploadé avec succès"
}
```

## Technologies Recommandées

### Option 1 : Node.js + Express
**Avantages :** Rapide à mettre en place, nombreux modules disponibles
```bash
npm init -y
npm install express multer cors
```

**Exemple d'implémentation :**
```javascript
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
const port = 8080;

// Configuration multer pour upload
const upload = multer({ dest: 'uploads/' });

app.use(express.json());
app.use(cors());

// Ping endpoint
app.get('/api/ping', (req, res) => {
    res.json({
        status: 'ok',
        message: 'Serveur Meownopoly actif',
        timestamp: new Date().toISOString()
    });
});

// Version endpoint
app.get('/api/version', (req, res) => {
    // Lire le fichier de version le plus récent
    const versionInfo = getLatestVersion();
    res.json(versionInfo);
});

// Download endpoint
app.get('/api/download/:version', (req, res) => {
    const version = req.params.version;
    const filePath = path.join(__dirname, 'assets', `assets_v${version}.meow`);
    
    if (fs.existsSync(filePath)) {
        res.download(filePath);
    } else {
        res.status(404).json({ error: 'Version non trouvée' });
    }
});

// Upload endpoint
app.post('/api/upload', upload.single('package'), (req, res) => {
    // Traitement du fichier uploadé
    // ...
});

app.listen(port, () => {
    console.log(`Serveur Meownopoly sur http://localhost:${port}`);
});
```

### Option 2 : Python + Flask
**Avantages :** Syntaxe simple, bon pour prototypage
```bash
pip install flask flask-cors
```

**Exemple d'implémentation :**
```python
from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import os
import json
from datetime import datetime

app = Flask(__name__)
CORS(app)

@app.route('/api/ping')
def ping():
    return jsonify({
        'status': 'ok',
        'message': 'Serveur Meownopoly actif',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/version')
def get_version():
    # Logique pour récupérer la dernière version
    return jsonify({
        'version': '1.0.0',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/download/<version>')
def download_version(version):
    file_path = f'assets/assets_v{version}.meow'
    if os.path.exists(file_path):
        return send_file(file_path, as_attachment=True)
    else:
        return jsonify({'error': 'Version non trouvée'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
```

### Option 3 : Go + Gin
**Avantages :** Performance élevée, compilation en binaire unique
```bash
go mod init meownopoly-server
go get github.com/gin-gonic/gin
```

## Structure des Fichiers

```
serveur-ressources/
├── assets/                    # Dossier des paquets de ressources
│   ├── assets_v1.0.0.meow
│   ├── assets_v1.0.1.meow
│   └── assets_v1.1.0.meow
├── versions/                  # Métadonnées des versions
│   ├── 1.0.0.json
│   ├── 1.0.1.json
│   └── 1.1.0.json
├── uploads/                   # Dossier temporaire pour uploads
├── logs/                      # Logs du serveur
├── config.json               # Configuration du serveur
└── server.js|server.py|main.go  # Fichier principal
```

## Format des Métadonnées de Version

Chaque fichier dans `versions/` doit contenir :
```json
{
    "version": "1.0.1",
    "timestamp": "2024-01-15T10:30:00Z",
    "description": "Correction de bugs et nouvelles textures",
    "size": 125847296,
    "checksum": "sha256:abc123def456...",
    "files": [
        "textures/cat_house.png",
        "sounds/meow.wav",
        "models/dice.obj"
    ],
    "changes": [
        "Ajout de nouvelles textures pour les maisons",
        "Correction du bug de son",
        "Optimisation des modèles 3D"
    ]
}
```

## Configuration Réseau

### Serveur Local
```json
{
    "host": "0.0.0.0",
    "port": 8080,
    "cors": true,
    "max_upload_size": "500MB",
    "assets_directory": "./assets",
    "versions_directory": "./versions"
}
```

### Accès depuis le réseau local
Pour permettre l'accès depuis d'autres machines :
1. Configurer le firewall pour autoriser le port 8080
2. Utiliser l'IP locale (ex: `http://192.168.1.100:8080`)
3. Optionnel : Configurer un nom DNS local

## Sécurité

### Recommandations de base :
1. **Authentification** : Implémenter un système de token pour l'upload
2. **Validation** : Vérifier les fichiers uploadés (type, taille, contenu)
3. **Rate Limiting** : Limiter le nombre de requêtes par IP
4. **HTTPS** : Utiliser SSL en production (même local)

### Exemple avec authentification simple :
```javascript
const API_KEY = 'your-secret-key';

app.post('/api/upload', (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || authHeader !== `Bearer ${API_KEY}`) {
        return res.status(401).json({ error: 'Non autorisé' });
    }
    // Continuer avec l'upload...
});
```

## Déploiement et Maintenance

### Démarrage automatique (Windows)
Créer un fichier batch `start_server.bat` :
```batch
@echo off
cd /d "C:\path\to\your\server"
node server.js
pause
```

### Démarrage automatique (Linux/Mac)
Créer un service systemd ou utiliser PM2 :
```bash
npm install -g pm2
pm2 start server.js --name meownopoly-server
pm2 startup
pm2 save
```

### Monitoring
- Logs des accès et erreurs
- Surveillance de l'espace disque
- Monitoring des performances réseau

## Tests

### Test du serveur avec curl :
```bash
# Test ping
curl http://localhost:8080/api/ping

# Test version
curl http://localhost:8080/api/version

# Test download
curl -O http://localhost:8080/api/download/1.0.0
```

## Dépannage

### Problèmes courants :
1. **Port déjà utilisé** : Changer le port dans la configuration
2. **Firewall bloque** : Autoriser le port dans Windows Defender/iptables
3. **Fichiers corrompus** : Vérifier les checksums
4. **Permissions** : S'assurer que le serveur peut lire/écrire dans les dossiers

### Logs utiles :
```javascript
// Logger les requêtes
app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
});
```

## Extension Future

### Fonctionnalités avancées possibles :
1. **Delta Updates** : Télécharger seulement les changements
2. **CDN Integration** : Utiliser un CDN pour la distribution
3. **Multi-serveurs** : Load balancing et réplication
4. **Interface Web** : Panel d'administration
5. **Statistiques** : Tracking des téléchargements et usage
