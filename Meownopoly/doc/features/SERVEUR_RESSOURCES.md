# Serveur de Ressources Meownopoly

## Vue d'ensemble

Ce document décrit l'architecture et l'implémentation recommandée pour le serveur local qui hébergera les ressources du jeu Meownopoly.

## Architecture du Serveur

### Endpoints API

#### Routes publiques (sans authentification)

##### 1. Test de Connexion
```
GET /api/ping
```
**Réponse :**
```json
{
    "status": "ok",
    "message": "Serveur Meownopoly actif",
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0.0"
}
```

##### 2. Vérification de Version
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

##### 3. Liste des versions
```
GET /api/versions
```

##### 4. Téléchargement de Ressources
```
GET /api/download/{version}
```
- Paramètre `version` sanitisé (alphanum + `.` + `-` + `_` uniquement)
- Supporte le header `Range` pour la reprise de téléchargement (réponse 206)
- Inclut le header `X-Checksum-Sha256` si les métadonnées de version existent
- Header `Accept-Ranges: bytes` dans la réponse

##### 5. Liste des modèles 3D
```
GET /api/models/list
```

##### 6. Téléchargement d'un modèle
```
GET /api/models/download/{name}/{version}
```
- Paramètres sanitisés contre le path traversal
- Supporte Range + checksum comme la route assets

##### 7. Liste des fichiers (debug, désactivé en production)
```
GET /api/files
```
- Retourne 403 en mode production (`NODE_ENV=production`)

#### Routes protégées (authentification + rate limiting)

##### 8. Upload d'un paquet d'assets
```
POST /api/upload
Authorization: Bearer <UPLOAD_TOKEN>
```
- **Rate limit** : 10 requêtes par 15 minutes
- **Body** : Multipart form-data (`package`, `version`, `description`)
- **Réponse :**
```json
{
    "success": true,
    "version": "1.2.4",
    "message": "Paquet uploadé avec succès",
    "size": 125847296,
    "checksum": "abc123..."
}
```

##### 9. Upload d'un modèle 3D
```
POST /api/models/upload
Authorization: Bearer <UPLOAD_TOKEN>
```
- **Rate limit** : 10 requêtes par 15 minutes
- **Body** : Multipart form-data (`package`, `name`, `version`)

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
asset_server/
├── assets/                    # Paquets de ressources (.meow)
│   ├── assets_v1.0.0.meow
│   └── assets_v1.1.0.meow
├── models/                    # Paquets de modèles 3D (.meow)
│   ├── PionChat_v1.0.0.meow
│   └── Ville_v2.0.0.meow
├── versions/                  # Métadonnées des versions (JSON)
│   ├── 1.0.0.json
│   └── 1.1.0.json
├── uploads/                   # Dossier temporaire pour uploads
├── server.js                  # Serveur Express principal
├── package.json               # Dépendances Node.js
├── package-lock.json          # Lockfile npm
├── README.md                  # Documentation du serveur
├── .env                       # Configuration locale (créé par l'utilisateur depuis .env.example, absent par défaut)
├── .env.example               # Template de configuration
├── deploy.sh                  # Déploiement (scp + npm install --production + systemctl restart, lit .deployEnv)
├── .deployEnv                 # Config de déploiement (non versionné)
├── setup-domain.sh            # Script de déploiement (Nginx + SSL + systemd)
├── start_server.sh            # Script de démarrage Linux
└── start_server.bat           # Script de démarrage Windows
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

### Serveur déployé (configuration active)

Le serveur déployé écoute en **HTTPS sur le port 443**. Au démarrage, `server.js` lit les certificats Let's Encrypt du domaine `pattounecorp.ovh` (`/etc/letsencrypt/live/pattounecorp.ovh/privkey.pem` et `fullchain.pem`, cf. `server.js:511-512`) puis lance `https.createServer(sslOptions, app).listen(443, '0.0.0.0', ...)`. C'est le seul listener actif.

Côté client, le launcher C++ préfixe les URLs avec `https://` par défaut : `reformat_server_url` (`launcher_manager.cpp:65-67`) ajoute `https://` si l'URL ne commence ni par `https://` ni par `http://`.

### Fallback local en HTTP (optionnel, désactivé par défaut)

Pour un usage purement local, un serveur HTTP simple sur le port 8080 peut être réactivé. Le code correspondant existe dans `server.js` mais **le bloc `app.listen(8080, '0.0.0.0', ...)` est entièrement commenté** (`server.js:542-560`), tout comme la variable `const port = 8080` (`server.js:16`) qui n'est plus utilisée. Configuration de référence pour ce mode :

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
Pour permettre l'accès depuis d'autres machines (en réactivant le fallback HTTP local) :
1. Configurer le firewall pour autoriser le port 8080
2. Utiliser l'IP locale (ex: `http://192.168.1.100:8080`)
3. Optionnel : Configurer un nom DNS local

## Sécurité

### Mesures implémentées

1. **Authentification Bearer Token** : Les routes d'upload (`/api/upload`, `/api/models/upload`) exigent le header `Authorization: Bearer <token>`. Le token est configuré via la variable d'environnement `UPLOAD_TOKEN`. Si le token n'est pas configuré, les uploads sont désactivés (403).

2. **Rate Limiting** : `express-rate-limit` limite les uploads à 10 requêtes par 15 minutes par IP.

3. **Sanitisation des paramètres** : Les paramètres `version`, `name` sont nettoyés avec `replace(/[^a-zA-Z0-9._-]/g, '')` pour empêcher le path traversal.

4. **Protection debug** : La route `/api/files` est désactivée en production (`NODE_ENV=production`). Les chemins absolus du serveur ne sont plus exposés.

5. **HTTPS** : SSL via Let's Encrypt avec renouvellement automatique.

6. **Taille max** : Limite de 500 Mo par upload (multer).

### Configuration
```bash
# .env (copier depuis .env.example)
UPLOAD_TOKEN=votre_token_secret_ici
NODE_ENV=production
```

Générer un token :
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
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

Le serveur déployé répond en HTTPS sur le port 443. Cibler le domaine :
```bash
# Test ping
curl https://pattounecorp.ovh/api/ping

# Test version
curl https://pattounecorp.ovh/api/version

# Test download
curl -O https://pattounecorp.ovh/api/download/1.0.0
```

Les exemples ci-dessous ne valent que si le fallback HTTP local (port 8080) a été réactivé dans `server.js` (bloc `app.listen` commenté par défaut) :
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

## Fonctionnalités Avancées Implémentées

- **Modèles 3D** : Routes dédiées pour les packs de modèles (`/api/models/*`)
- **Reprise de téléchargement** : Support HTTP Range (réponse 206) pour reprendre les downloads interrompus
- **Vérification d'intégrité** : Header `X-Checksum-Sha256` sur les téléchargements, checksum SHA-256 dans les métadonnées de version
- **I/O asynchrone** : La plupart des opérations fichier (lecture/écriture de versions, `rename`, `unlink`, `readdir`) utilisent `fs.promises` pour ne pas bloquer le serveur ; les vérifications d'existence (`fs.existsSync`/`fs.statSync`) et le chargement des certificats SSL au démarrage (`fs.readFileSync`) restent synchrones
- **Checksum streaming** : Le calcul de hash utilise `createReadStream` au lieu de charger le fichier entier en mémoire

## Extension Future

### Fonctionnalités avancées possibles :
1. **Delta Updates** : Télécharger seulement les changements
2. **CDN Integration** : Utiliser un CDN pour la distribution
3. **Multi-serveurs** : Load balancing et réplication
4. **Interface Web** : Panel d'administration
5. **Statistiques** : Tracking des téléchargements et usage
