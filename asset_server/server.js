const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
const port = 8080;

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

// Logger middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${req.method} ${req.path} - ${req.ip}`);
    next();
});

// Utilitaires
function getFileChecksum(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    const hashSum = crypto.createHash('sha256');
    hashSum.update(fileBuffer);
    return hashSum.digest('hex');
}

function getLatestVersion() {
    try {
        const versionFiles = fs.readdirSync(VERSIONS_DIR)
            .filter(file => file.endsWith('.json'))
            .map(file => {
                const content = fs.readFileSync(path.join(VERSIONS_DIR, file), 'utf8');
                return JSON.parse(content);
            })
            .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        
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

function saveVersionInfo(versionData) {
    const filePath = path.join(VERSIONS_DIR, `${versionData.version}.json`);
    fs.writeFileSync(filePath, JSON.stringify(versionData, null, 2));
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
app.get('/api/version', (req, res) => {
    try {
        const latestVersion = getLatestVersion();
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
app.get('/api/versions', (req, res) => {
    try {
        const versionFiles = fs.readdirSync(VERSIONS_DIR)
            .filter(file => file.endsWith('.json'))
            .map(file => {
                const content = fs.readFileSync(path.join(VERSIONS_DIR, file), 'utf8');
                return JSON.parse(content);
            })
            .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
        
        res.json({ versions: versionFiles });
    } catch (error) {
        console.error('Erreur versions:', error);
        res.status(500).json({ 
            error: 'Erreur lors de la récupération des versions' 
        });
    }
});

// Téléchargement d'une version spécifique
app.get('/api/download/:version', (req, res) => {
    const version = req.params.version;
    const fileName = `assets_v${version}.meow`;
    const filePath = path.join(ASSETS_DIR, fileName);
    
    console.log(`Tentative de téléchargement: ${filePath}`);
    
    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ 
            error: 'Version non trouvée',
            version: version,
            availableFiles: fs.readdirSync(ASSETS_DIR)
        });
    }
    
    try {
        const stats = fs.statSync(filePath);
        
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        res.setHeader('Content-Type', 'application/octet-stream');
        res.setHeader('Content-Length', stats.size);
        
        const fileStream = fs.createReadStream(filePath);
        fileStream.pipe(res);
        
        console.log(`Téléchargement démarré pour ${fileName} (${stats.size} bytes)`);
        
    } catch (error) {
        console.error('Erreur download:', error);
        res.status(500).json({ 
            error: 'Erreur lors du téléchargement',
            details: error.message 
        });
    }
});

// Upload d'un nouveau paquet
app.post('/api/upload', upload.single('package'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'Aucun fichier fourni' });
    }
    
    try {
        const uploadedFile = req.file;
        const version = req.body.version;
        
        if (!version) {
            fs.unlinkSync(uploadedFile.path); // Nettoyer le fichier temporaire
            return res.status(400).json({ error: 'Version requise' });
        }
        
        // Déplacer le fichier vers le dossier assets
        const finalFileName = `assets_v${version}.meow`;
        const finalPath = path.join(ASSETS_DIR, finalFileName);
        
        fs.renameSync(uploadedFile.path, finalPath);
        
        // Calculer le checksum
        const checksum = getFileChecksum(finalPath);
        const stats = fs.statSync(finalPath);
        
        // Créer les métadonnées de version
        const versionData = {
            version: version,
            timestamp: new Date().toISOString(),
            description: req.body.description || 'Nouvelle version uploadée',
            size: stats.size,
            checksum: `sha256:${checksum}`,
            filename: finalFileName
        };
        
        saveVersionInfo(versionData);
        
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
        
        // Nettoyer en cas d'erreur
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        
        res.status(500).json({ 
            error: 'Erreur lors de l\'upload',
            details: error.message 
        });
    }
});

// Route pour lister les fichiers disponibles (debug)
app.get('/api/files', (req, res) => {
    try {
        const assetFiles = fs.readdirSync(ASSETS_DIR);
        const versionFiles = fs.readdirSync(VERSIONS_DIR);
        const modelFiles = fs.existsSync(MODELS_DIR) ? fs.readdirSync(MODELS_DIR) : [];
        
        res.json({
            assets: assetFiles,
            versions: versionFiles,
            models: modelFiles,
            paths: {
                assets: ASSETS_DIR,
                versions: VERSIONS_DIR,
                models: MODELS_DIR,
                uploads: UPLOADS_DIR
            }
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
app.get('/api/models/list', (req, res) => {
    try {
        const files = fs.readdirSync(MODELS_DIR);
        const packs = {};

        // Analyse des fichiers nom_vVersion.meow
        files.forEach(file => {
            if (!file.endsWith('.meow')) return;

            // Regex pour extraire nom et version: packName_v1.0.0.meow
            const match = file.match(/^(.+)_v(.+)\.meow$/);
            if (match) {
                const name = match[1];
                const version = match[2];
                const filePath = path.join(MODELS_DIR, file);
                const stats = fs.statSync(filePath);

                // On garde une liste de toutes les versions ou juste la dernière
                if (!packs[name]) {
                    packs[name] = [];
                }

                packs[name].push({
                    name: name,
                    version: version,
                    filename: file,
                    size: stats.size,
                    uploadedAt: stats.mtime
                });
            }
        });

        // Pour chaque pack, on peut trier par version si besoin, 
        // ou renvoyer la structure complète pour que le client choisisse.
        res.json({
            success: true,
            packs: packs
        });

    } catch (error) {
        console.error('Erreur liste modèles:', error);
        res.status(500).json({ error: 'Erreur lors de la récupération de la liste des modèles' });
    }
});

// 2. Télécharger un pack spécifique
app.get('/api/models/download/:name/:version', (req, res) => {
    const { name, version } = req.params;
    // Sécurisation basique du nom de fichier pour éviter les ../
    const safeName = name.replace(/[^a-zA-Z0-9_-]/g, '');
    const safeVersion = version.replace(/[^a-zA-Z0-9._-]/g, '');
    
    const fileName = `${safeName}_v${safeVersion}.meow`;
    const filePath = path.join(MODELS_DIR, fileName);

    if (!fs.existsSync(filePath)) {
        return res.status(404).json({ error: 'Pack de modèle non trouvé' });
    }

    try {
        const stats = fs.statSync(filePath);
        res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
        res.setHeader('Content-Type', 'application/octet-stream');
        res.setHeader('Content-Length', stats.size);
        
        const fileStream = fs.createReadStream(filePath);
        fileStream.pipe(res);
        
    } catch (error) {
        console.error('Erreur download modèle:', error);
        res.status(500).json({ error: 'Erreur lors du téléchargement' });
    }
});

// 3. Upload d'un pack de modèle spécifique
app.post('/api/models/upload', upload.single('package'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ error: 'Aucun fichier fourni' });
    }

    try {
        const uploadedFile = req.file;
        const name = req.body.name; // Identifiant du pack (ex: "ville", "personnages")
        const version = req.body.version;

        if (!version || !name) {
            fs.unlinkSync(uploadedFile.path);
            return res.status(400).json({ error: 'Nom du pack et version requis' });
        }

        // Nettoyage des inputs
        const safeName = name.replace(/[^a-zA-Z0-9_-]/g, '');
        const safeVersion = version.replace(/[^a-zA-Z0-9._-]/g, '');

        const finalFileName = `${safeName}_v${safeVersion}.meow`;
        const finalPath = path.join(MODELS_DIR, finalFileName);

        // Si une version identique existe déjà, on l'écrase (ou on pourrait rejeter)
        if (fs.existsSync(finalPath)) {
            console.log(`Remplacement du fichier existant: ${finalFileName}`);
        }

        fs.renameSync(uploadedFile.path, finalPath);
        
        const stats = fs.statSync(finalPath);
        const checksum = getFileChecksum(finalPath);

        console.log(`Upload Modèle réussi: ${finalFileName} (${stats.size} bytes)`);

        res.json({
            success: true,
            message: 'Pack de modèle uploadé avec succès',
            file: {
                name: safeName,
                version: safeVersion,
                filename: finalFileName,
                size: stats.size,
                checksum: checksum
            }
        });

    } catch (error) {
        console.error('Erreur upload modèle:', error);
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        res.status(500).json({ error: 'Erreur lors de l\'upload du modèle' });
    }
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

// Démarrage du serveur
app.listen(port, '0.0.0.0', () => {
    console.log('='.repeat(50));
    console.log('🚀 Serveur Meownopoly démarré');
    console.log(`📡 URL: http://localhost:${port}`);
    console.log(`📁 Assets: ${ASSETS_DIR}`);
    console.log(`📦 Models: ${MODELS_DIR}`);
    console.log(`📋 Versions: ${VERSIONS_DIR}`);
    console.log(`⬆️  Uploads: ${UPLOADS_DIR}`);
    console.log('='.repeat(50));
    
    // Afficher la version actuelle
    try {
        const latest = getLatestVersion();
        console.log(`📦 Version actuelle: ${latest.version}`);
    } catch (error) {
        console.log('⚠️  Aucune version disponible');
    }
});

// Gestion propre de l'arrêt
process.on('SIGINT', () => {
    console.log('\n🛑 Arrêt du serveur...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('\n🛑 Arrêt du serveur...');
    process.exit(0);
});
