# Serveur de Ressources Meownopoly

## Installation

1. Installer Node.js (version 16 ou plus récente)
2. Installer les dépendances :
```bash
npm install
```

## Démarrage

```bash
npm start
```

Le serveur sera accessible sur `http://localhost:8080`

## Structure des dossiers

Le serveur créera automatiquement ces dossiers :
- `assets/` : Fichiers .meow des ressources
- `versions/` : Métadonnées des versions (JSON)
- `uploads/` : Dossier temporaire pour les uploads

## Test du serveur

```bash
# Tester la connexion
curl http://localhost:8080/api/ping

# Voir les versions disponibles
curl http://localhost:8080/api/version

# Lister tous les fichiers
curl http://localhost:8080/api/files
```

## Upload d'un paquet

Utilisez le launcher Meownopoly ou curl :
```bash
curl -X POST -F "package=@assets_v1.0.0.meow" -F "version=1.0.0" -F "description=Première version" http://localhost:8080/api/upload
```

## Configuration réseau

Pour accéder depuis d'autres machines du réseau local :
1. Trouvez votre IP locale : `ipconfig` (Windows) ou `ifconfig` (Linux/Mac)
2. Utilisez cette IP dans le launcher : `http://192.168.1.XXX:8080`
3. Assurez-vous que le port 8080 n'est pas bloqué par le firewall
