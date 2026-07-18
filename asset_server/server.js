require('dotenv').config();

const express = require('express');
const multer = require('multer');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const path = require('path');
const fs = require('fs');
const fsp = fs.promises;
const crypto = require('crypto');
const https = require('https');
const http = require('http');

const app = express();
app.set('trust proxy', 1);
const port = 8080;

// Configuration depuis .env
const UPLOAD_TOKEN = process.env.UPLOAD_TOKEN || '';
const IS_PRODUCTION = process.env.NODE_ENV === 'production';

// Configuration
const ASSETS_DIR = path.join(__dirname, 'assets');
const MODELS_DIR = path.join(__dirname, 'models'); // Nouveau dossier pour les modèles 3D
const VERSIONS_DIR = path.join(__dirname, 'versions');
const UPLOADS_DIR = path.join(__dirname, 'uploads');

// Créer les dossiers s'ils n'existent pas
[ASSETS_DIR, MODELS_DIR, VERSIONS_DIR, UPLOADS_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// Configuration multer pour upload
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, UPLOADS_DIR);
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    }
});

const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 500 * 1024 * 1024 // 500MB max
    }
});

// Middleware
app.use(express.json());
app.use(cors({
    origin: [
        'http://localhost:8080', // Pour le développement local
        'https://pattounecorp.ovh', // Remplacez par votre domaine
        'https://www.pattounecorp.ovh' // Avec www si nécessaire
    ],
    credentials: true
}));

app.use(express.static(path.join(__dirname, 'public'), { dotfiles: 'allow' }));

// Logger middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path} - ${req.ip}`);
    next();
});

// Rate limiter pour les uploads (10 requêtes par 15 minutes)
const uploadLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
    message: { error: 'Trop de requetes. Reessayez plus tard.' },
    standardHeaders: true,
    legacyHeaders: false,
});

// Middleware d'authentification pour les uploads
function authUpload(req, res, next) {
    if (!UPLOAD_TOKEN) {
        return res.status(403).json({ error: 'Uploads desactives (pas de UPLOAD_TOKEN configure)' });
    }
    const authHeader = req.headers['authorization'];
    if (!authHeader || authHeader !== `Bearer ${UPLOAD_TOKEN}`) {
        return res.status(401).json({ error: 'Token invalide ou manquant' });
    }
    next();
}

// Utilitaires (async)
function getFileChecksum(filePath) {
    return new Promise((resolve, reject) => {
        const hash = crypto.createHash('sha256');
        const stream = fs.createReadStream(filePath);
        stream.on('data', chunk => hash.update(chunk));
        stream.on('end', () => resolve(hash.digest('hex')));
        stream.on('error', reject);
    });
}

async function getLatestVersion() {
    try {
        const files = await fsp.readdir(VERSIONS_DIR);
        const jsonFiles = files.filter(file => file.endsWith('.json'));

        const versionFiles = await Promise.all(
            jsonFiles.map(async file => {
                const content = await fsp.readFile(path.join(VERSIONS_DIR, file), 'utf8');
                return JSON.parse(content);
            })
        );

        versionFiles.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

        return versionFiles[0] || {
            version: '0.0.0',
            timestamp: new Date().toISOString(),
            description: 'Version initiale',
            size: 0
        };
    } catch (error) {
        console.error('Erreur lors de la lecture des versions:', error);
        return {
            version: '0.0.0',
            timestamp: new Date().toISOString(),
            description: 'Erreur de lecture des versions',
            size: 0
        };
    }
}

async function saveVersionInfo(versionData) {
    const filePath = path.join(VERSIONS_DIR, `${versionData.version}.json`);
    await fsp.writeFile(filePath, JSON.stringify(versionData, null, 2));
}

// Routes API

// Test de connexion
app.get('/api/ping', (req, res) => {
    res.json({
        status: 'ok',
        message: 'Serveur Meownopoly actif',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Informations de version
app.get('/api/version', async (req, res) => {
    try {
        const latestVersion = await getLatestVersion();
        res.json(latestVersion);
    } catch (error) {
        console.error('Erreur version:', error);
        res.status(500).json({
            error: 'Erreur lors de la récupération de la version',
            details: error.message
        });
    }
});

// Liste de toutes les versions
app.get('/api/versions', async (req, res) => {
    try {
        const files = await fsp.readdir(VERSIONS_DIR);
        const jsonFiles = files.filter(file => file.endsWith('.json'));

        const versionFiles = await Promise.all(
            jsonFiles.map(async file => {
                const content = await fsp.readFile(path.join(VERSIONS_DIR, file), 'utf8');
                return JSON.parse(content);
            })
        );

        versionFiles.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        res.json({ versions: versionFiles });
    } catch (error) {
        console.error('Erreur versions:', error);
        res.status(500).json({
            error: 'Erreur lors de la récupération des versions'
        });
    }
});

// Téléchargement d'une version spécifique
app.get('/api/download/:version', async (req, res) => {
    const safeVersion = req.params.version.replace(/[^a-zA-Z0-9._-]/g, '');
    const fileName = `assets_v${safeVersion}.meow`;
    const filePath = path.join(ASSETS_DIR, fileName);

    console.log(`Tentative de téléchargement: ${filePath}`);

    if (!fs.existsSync(filePath)) {
        return res.status(404).json({
            error: 'Version non trouvée',
            version: safeVersion
        });
    }

    try {
        const stats = fs.statSync(filePath);

        // Checksum depuis les métadonnées de version
        const versionMetaPath = path.join(VERSIONS_DIR, `${safeVersion}.json`);
        if (fs.existsSync(versionMetaPath)) {
            try {
                const meta = JSON.parse(await fsp.readFile(versionMetaPath, 'utf8'));
                if (meta.checksum) {
                    const hash = meta.checksum.startsWith('sha256:') ? meta.checksum.slice(7) : meta.checksum;
                    res.setHeader('X-Checksum-Sha256', hash);
                }
            } catch (_) { /* métadonnées optionnelles */ }
        }

        // Support HTTP Range pour reprise de téléchargement
        const range = req.headers.range;
        if (range) {
            const parts = range.replace(/bytes=/, '').split('-');
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
            const chunkSize = end - start + 1;

            res.writeHead(206, {
                'Content-Range': `bytes ${start}-${end}/${stats.size}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunkSize,
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': `attachment; filename="${fileName}"`,
            });
            fs.createReadStream(filePath, { start, end }).pipe(res);
        } else {
            res.setHeader('Accept-Ranges', 'bytes');
            res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
            res.setHeader('Content-Type', 'application/octet-stream');
            res.setHeader('Content-Length', stats.size);
            fs.createReadStream(filePath).pipe(res);
        }

        console.log(`Téléchargement démarré pour ${fileName} (${stats.size} bytes)`);

    } catch (error) {
        console.error('Erreur download:', error);
        res.status(500).json({
            error: 'Erreur lors du téléchargement',
            details: error.message
        });
    }
});

// Upload d'un nouveau paquet (authentifié + rate limité)
app.post('/api/upload', uploadLimiter, authUpload, upload.single('package'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'Aucun fichier fourni' });
    }

    try {
        const uploadedFile = req.file;
        const version = req.body.version;

        if (!version) {
            await fsp.unlink(uploadedFile.path);
            return res.status(400).json({ error: 'Version requise' });
        }

        const finalFileName = `assets_v${version}.meow`;
        const finalPath = path.join(ASSETS_DIR, finalFileName);

        await fsp.rename(uploadedFile.path, finalPath);

        const checksum = await getFileChecksum(finalPath);
        const stats = await fsp.stat(finalPath);

        const versionData = {
            version: version,
            timestamp: new Date().toISOString(),
            description: req.body.description || 'Nouvelle version uploadée',
            size: stats.size,
            checksum: `sha256:${checksum}`,
            filename: finalFileName
        };

        await saveVersionInfo(versionData);

        console.log(`Upload réussi: ${finalFileName} (${stats.size} bytes)`);

        res.json({
            success: true,
            version: version,
            message: 'Paquet uploadé avec succès',
            size: stats.size,
            checksum: checksum
        });

    } catch (error) {
        console.error('Erreur upload:', error);

        if (req.file && fs.existsSync(req.file.path)) {
            await fsp.unlink(req.file.path).catch(() => {});
        }

        res.status(500).json({
            error: 'Erreur lors de l\'upload',
            details: error.message
        });
    }
});

// Route pour lister les fichiers disponibles (debug, désactivé en production)
app.get('/api/files', async (req, res) => {
    if (IS_PRODUCTION) {
        return res.status(403).json({ error: 'Endpoint desactive en production' });
    }

    try {
        const assetFiles = await fsp.readdir(ASSETS_DIR);
        const versionFiles = await fsp.readdir(VERSIONS_DIR);
        let modelFiles = [];
        try { modelFiles = await fsp.readdir(MODELS_DIR); } catch (_) {}

        res.json({
            assets: assetFiles,
            versions: versionFiles,
            models: modelFiles
        });
    } catch (error) {
        res.status(500).json({
            error: 'Erreur lors de la liste des fichiers',
            details: error.message
        });
    }
});

// -------------------------------------------------------
// NOUVELLES ROUTES POUR LES MODÈLES 3D (OPTIMISATION)
// -------------------------------------------------------

// 1. Lister les packs de modèles disponibles
app.get('/api/models/list', async (req, res) => {
    try {
        const files = await fsp.readdir(MODELS_DIR);
        const packs = {};

        for (const file of files) {
            if (!file.endsWith('.meow')) continue;

            const match = file.match(/^(.+)_v(.+)\.meow$/);
            if (match) {
                const name = match[1];
                const version = match[2];
                const filePath = path.join(MODELS_DIR, file);
                const stats = await fsp.stat(filePath);

                if (!packs[name]) {
                    packs[name] = [];
                }

                // Manifeste de package V3 (M11, D38) associé, si présent.
                const manifestFile = `${name}_v${version}.manifest.json`;
                const hasManifest = fs.existsSync(path.join(MODELS_DIR, manifestFile));

                packs[name].push({
                    name: name,
                    version: version,
                    filename: file,
                    size: stats.size,
                    uploadedAt: stats.mtime,
                    hasManifest: hasManifest
                });
            }
        }

        res.json({
            success: true,
            packs: packs
        });

    } catch (error) {
        console.error('Erreur liste modèles:', error);
        res.status(500).json({ error: 'Erreur lors de la récupération de la liste des modèles' });
    }
});

// 2. Télécharger un pack spécifique (avec checksum + Range)
app.get('/api/models/download/:name/:version', async (req, res) => {
    const safeName = req.params.name.replace(/[^a-zA-Z0-9_-]/g, '');
    const safeVersion = req.params.version.replace(/[^a-zA-Z0-9._-]/g, '');

    const fileName = `${safeName}_v${safeVersion}.meow`;
    const filePath = path.join(MODELS_DIR, fileName);

    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'Pack de modèle non trouvé' });
    }

    try {
        const stats = fs.statSync(filePath);

        // Checksum du fichier
        const checksum = await getFileChecksum(filePath);
        res.setHeader('X-Checksum-Sha256', checksum);

        // Support HTTP Range pour reprise
        const range = req.headers.range;
        if (range) {
            const parts = range.replace(/bytes=/, '').split('-');
            const start = parseInt(parts[0], 10);
            const end = parts[1] ? parseInt(parts[1], 10) : stats.size - 1;
            const chunkSize = end - start + 1;

            res.writeHead(206, {
                'Content-Range': `bytes ${start}-${end}/${stats.size}`,
                'Accept-Ranges': 'bytes',
                'Content-Length': chunkSize,
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': `attachment; filename="${fileName}"`,
            });
            fs.createReadStream(filePath, { start, end }).pipe(res);
        } else {
            res.setHeader('Accept-Ranges', 'bytes');
            res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
            res.setHeader('Content-Type', 'application/octet-stream');
            res.setHeader('Content-Length', stats.size);
            fs.createReadStream(filePath).pipe(res);
        }

    } catch (error) {
        console.error('Erreur download modèle:', error);
        res.status(500).json({ error: 'Erreur lors du téléchargement' });
    }
});

// 2 bis. Servir le manifeste de package V3 (M11, D38) d'un pack
app.get('/api/models/manifest/:name/:version', async (req, res) => {
    const safeName = req.params.name.replace(/[^a-zA-Z0-9_-]/g, '');
    const safeVersion = req.params.version.replace(/[^a-zA-Z0-9._-]/g, '');

    const manifestPath = path.join(MODELS_DIR, `${safeName}_v${safeVersion}.manifest.json`);
    if (!fs.existsSync(manifestPath)) {
        return res.status(404).json({ error: 'Manifeste de package non trouvé' });
    }
    try {
        const content = await fsp.readFile(manifestPath, 'utf8');
        res.setHeader('Content-Type', 'application/json');
        res.send(content);
    } catch (error) {
        console.error('Erreur lecture manifeste:', error);
        res.status(500).json({ error: 'Erreur lors de la lecture du manifeste' });
    }
});

// 3. Upload d'un pack de modèle spécifique (authentifié + rate limité)
app.post('/api/models/upload', uploadLimiter, authUpload, upload.single('package'), async (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'Aucun fichier fourni' });
    }

    try {
        const uploadedFile = req.file;
        const name = req.body.name;
        const version = req.body.version;

        if (!version || !name) {
            await fsp.unlink(uploadedFile.path);
            return res.status(400).json({ error: 'Nom du pack et version requis' });
        }

        const safeName = name.replace(/[^a-zA-Z0-9_-]/g, '');
        const safeVersion = version.replace(/[^a-zA-Z0-9._-]/g, '');

        const finalFileName = `${safeName}_v${safeVersion}.meow`;
        const finalPath = path.join(MODELS_DIR, finalFileName);

        if (fs.existsSync(finalPath)) {
            console.log(`Remplacement du fichier existant: ${finalFileName}`);
        }

        await fsp.rename(uploadedFile.path, finalPath);

        const stats = await fsp.stat(finalPath);
        const checksum = await getFileChecksum(finalPath);

        // Manifeste de package V3 (M11, D38) optionnel : stocké à côté du .meow.
        let manifestStored = false;
        if (req.body.manifest) {
            try {
                const parsed = JSON.parse(req.body.manifest); // valide le JSON
                const manifestPath = path.join(MODELS_DIR, `${safeName}_v${safeVersion}.manifest.json`);
                await fsp.writeFile(manifestPath, JSON.stringify(parsed, null, 2));
                manifestStored = true;
            } catch (e) {
                console.warn(`Manifeste de package ignoré (JSON invalide): ${e.message}`);
            }
        }

        console.log(`Upload Modèle réussi: ${finalFileName} (${stats.size} bytes)`);

        res.json({
            success: true,
            message: 'Pack de modèle uploadé avec succès',
            file: {
                name: safeName,
                version: safeVersion,
                filename: finalFileName,
                size: stats.size,
                checksum: checksum,
                hasManifest: manifestStored
            }
        });

    } catch (error) {
        console.error('Erreur upload modèle:', error);
        if (req.file && fs.existsSync(req.file.path)) {
            await fsp.unlink(req.file.path).catch(() => {});
        }
        res.status(500).json({ error: 'Erreur lors de l\'upload du modèle' });
    }
});

// 4. Suppression d'un pack de modèle spécifique (authentifié)
app.delete('/api/models/delete/:name/:version', authUpload, async (req, res) => {
    const safeName = req.params.name.replace(/[^a-zA-Z0-9_-]/g, '');
    const safeVersion = req.params.version.replace(/[^a-zA-Z0-9._-]/g, '');

    const fileName = `${safeName}_v${safeVersion}.meow`;
    const filePath = path.join(MODELS_DIR, fileName);

    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'Pack de modèle non trouvé' });
    }

    try {
        await fsp.unlink(filePath);
        // Manifeste de package V3 associé (M11), si présent.
        const manifestPath = path.join(MODELS_DIR, `${safeName}_v${safeVersion}.manifest.json`);
        if (fs.existsSync(manifestPath)) {
            await fsp.unlink(manifestPath).catch(() => {});
        }
        console.log(`Suppression Modèle réussie: ${fileName}`);
        res.json({
            success: true,
            message: 'Pack de modèle supprimé avec succès',
            file: { name: safeName, version: safeVersion, filename: fileName }
        });
    } catch (error) {
        console.error('Erreur suppression modèle:', error);
        res.status(500).json({ error: 'Erreur lors de la suppression du modèle' });
    }
});

// Page d'accueil
app.get('/', (req, res) => {
    res.send('Serveur Meownopoly en ligne !');
});

// Gestion des erreurs
app.use((error, req, res, next) => {
    console.error('Erreur serveur:', error);
    res.status(500).json({
        error: 'Erreur interne du serveur',
        message: error.message
    });
});

// Route 404
app.use((req, res) => {
    res.status(404).json({
        error: 'Endpoint non trouvé',
        path: req.path,
        method: req.method
    });
});

// --- CONFIGURATION SSL ---
const domain = 'pattounecorp.ovh';
const sslOptions = {
    key: fs.readFileSync(`/etc/letsencrypt/live/${domain}/privkey.pem`),
    cert: fs.readFileSync(`/etc/letsencrypt/live/${domain}/fullchain.pem`)
};

// --- DÉMARRAGE DES SERVEURS ---

// 1. Serveur HTTPS (Le serveur principal sur le port 443 ou ton port personnalisé)
const httpsPort = 443; 
https.createServer(sslOptions, app).listen(httpsPort, '0.0.0.0', () => {
    console.log('='.repeat(50));
    console.log('🚀 Serveur Meownopoly SÉCURISÉ (HTTPS) démarré');
    console.log(`📡 URL: https://${domain}`);
    console.log(`📁 Assets: ${ASSETS_DIR}`);
    console.log(`📦 Models: ${MODELS_DIR}`);
    console.log(`📋 Versions: ${VERSIONS_DIR}`);
    console.log(`⬆️  Uploads: ${UPLOADS_DIR}`);
    console.log('='.repeat(50));
    // Afficher la version actuelle
    getLatestVersion().then(latest => {
        console.log(`📦 Version actuelle: ${latest.version}`);
    }).catch(() => {
        console.log('⚠️  Aucune version disponible');
    });
});

// 2. Optionnel : Serveur HTTP (Port 80) pour rediriger automatiquement vers le HTTPS
// Très utile pour que les utilisateurs n'aient pas à taper "https://"
// http.createServer((req, res) => {
//     res.writeHead(301, { "Location": "https://" + req.headers['host'] + req.url });
//     res.end();
// }).listen(80);
// // Démarrage du serveur
// app.listen(port, '0.0.0.0', () => {
//     console.log('='.repeat(50));
//     console.log('🚀 Serveur Meownopoly démarré');
//     console.log(`📡 URL: http://localhost:${port}`);
//     console.log(`📁 Assets: ${ASSETS_DIR}`);
//     console.log(`📦 Models: ${MODELS_DIR}`);
//     console.log(`📋 Versions: ${VERSIONS_DIR}`);
//     console.log(`⬆️  Uploads: ${UPLOADS_DIR}`);
//     console.log('='.repeat(50));
    
//     // Afficher la version actuelle
//     try {
//         const latest = getLatestVersion();
//         console.log(`📦 Version actuelle: ${latest.version}`);
//     } catch (error) {
//         console.log('⚠️  Aucune version disponible');
//     }
// });

// Gestion propre de l'arrêt
process.on('SIGINT', () => {
    console.log('\n🛑 Arrêt du serveur...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Arrêt du serveur...');
    process.exit(0);
});
