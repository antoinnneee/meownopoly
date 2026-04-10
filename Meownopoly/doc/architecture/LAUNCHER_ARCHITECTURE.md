# Architecture du Launcher - Singleton Pattern

## Vue d'ensemble

Le launcher a été refactorisé pour utiliser un pattern singleton séparé, déplaçant toute la logique métier de `QmlApp` vers un nouveau composant dédié `LauncherManager`.

## Nouvelle Architecture

### 🏗️ Structure des Composants

```
┌─────────────────────────────────────────────────────────────┐
│                     QML Interface                           │
├─────────────────────────────────────────────────────────────┤
│ Launcher.qml (orchestrateur)                               │
│ ├── LauncherHeader.qml                                      │
│ ├── ServerConfigSection.qml                                │
│ ├── VersionInfoSection.qml                                 │
│ ├── ActionsSection.qml                                     │
│ ├── PackagingSection.qml                                   │
│ └── LogsSection.qml                                        │
├─────────────────────────────────────────────────────────────┤
│ LauncherLogic.qml (pont QML)                               │
├─────────────────────────────────────────────────────────────┤
│                   C++ Backend                              │
├─────────────────────────────────────────────────────────────┤
│ LauncherManager (singleton C++)                            │
│ ├── Network Management                                     │
│ ├── File Operations                                        │
│ ├── Version Control                                        │
│ └── Package Creation                                       │
├─────────────────────────────────────────────────────────────┤
│ QmlApp (application principale)                            │
│ └── Asset Management (legacy)                              │
└─────────────────────────────────────────────────────────────┘
```

## Composants Principaux

### 🔧 LauncherManager (C++ Singleton)

**Fichiers :** `launcher_manager.h`, `launcher_manager.cpp`

**Responsabilités :**
- Gestion des connexions réseau
- Téléchargement et upload de fichiers (assets + modèles 3D)
- Compression/décompression avec FolderCompressor
- Gestion des versions et métadonnées
- Communication avec le serveur de ressources
- Vérification d'intégrité SHA-256 des téléchargements
- Queue de téléchargement avec retry automatique
- Authentification des uploads par token

**Propriétés Q_PROPERTY :**
```cpp
Q_PROPERTY(QString currentVersion READ currentVersion NOTIFY currentVersionChanged)
Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
Q_PROPERTY(QString downloadStatus READ downloadStatus NOTIFY downloadStatusChanged)
Q_PROPERTY(bool packageCreated READ packageCreated NOTIFY packageCreatedChanged)
Q_PROPERTY(QVariantList modelsList READ modelsList NOTIFY modelsListChanged)
Q_PROPERTY(qint64 bytesReceived READ bytesReceived NOTIFY downloadProgressChanged)
Q_PROPERTY(qint64 bytesTotal READ bytesTotal NOTIFY downloadProgressChanged)
Q_PROPERTY(QString versionDescription READ versionDescription NOTIFY latestVersionChanged)
```

**Méthodes Q_INVOKABLE :**
```cpp
// Assets
Q_INVOKABLE void testServerConnection(const QString &serverUrl);
Q_INVOKABLE void checkForUpdates(const QString &serverUrl);
Q_INVOKABLE void downloadResources(const QString &serverUrl, const QString &version);
Q_INVOKABLE void forceDownloadResources(const QString &serverUrl);
Q_INVOKABLE void createResourcePackage(const QString &folderPath, const QString &version);
Q_INVOKABLE void uploadPackageToServer(const QString &serverUrl);
Q_INVOKABLE void resetDownloadState();
Q_INVOKABLE void setUploadToken(const QString &token);

// Modèles 3D
Q_INVOKABLE void fetchModelsList(const QString &serverUrl);
Q_INVOKABLE void downloadModel(const QString &serverUrl, const QString &name, const QString &version);
Q_INVOKABLE void createModelPackage(const QString &folderPath, const QString &name, const QString &version);
Q_INVOKABLE void uploadModelPackage(const QString &serverUrl, const QString &name, const QString &version);

// Utilitaire
static int compareVersions(const QString &v1, const QString &v2);
```

### 🌉 LauncherLogic.qml (Pont QML)

**Responsabilités :**
- Interface entre les composants QML et le singleton C++
- Gestion des Settings (configuration utilisateur)
- Propagation des signaux et mises à jour d'état
- Coordination des actions utilisateur

**Connexions principales :**
```qml
property Connections launcherConnections: Connections {
    target: LauncherManager
    
    function onCurrentVersionChanged() { /* ... */ }
    function onDownloadProgressChanged() { /* ... */ }
    function onLogMessage(message) { /* ... */ }
}
```

### 🎨 Composants QML d'Interface

Chaque composant est spécialisé et communique via des signaux :

1. **LauncherHeader.qml** - En-tête et navigation
2. **ServerConfigSection.qml** - Configuration serveur
3. **VersionInfoSection.qml** - Informations de versions
4. **ActionsSection.qml** - Boutons d'actions
5. **PackagingSection.qml** - Création/upload de paquets
6. **LogsSection.qml** - Logs et debug

## Avantages de cette Architecture

### ✅ Séparation des Responsabilités

- **QmlApp** : Gestion générale de l'application et assets legacy
- **LauncherManager** : Logique métier du launcher uniquement
- **LauncherLogic** : Pont et coordination QML
- **Composants UI** : Interface utilisateur pure

### ✅ Singleton Pattern

- **Instance unique** : `LauncherManager::instance()`
- **Accès global** : Disponible partout dans l'application
- **État cohérent** : Pas de duplication de données
- **Performance** : Une seule instance en mémoire

### ✅ Réutilisabilité

- Le singleton peut être utilisé depuis n'importe quel composant QML
- Logique métier indépendante de l'interface
- Tests unitaires facilités

### ✅ Maintenabilité

- Code C++ concentré dans un seul endroit
- Debugging simplifié
- Évolution facilitée

## Migration depuis l'Ancienne Architecture

### 🔄 Ce qui a changé

**Avant :**
```qml
// Dans QML
if (appInstance) {
    appInstance.downloadResources(serverUrl, version)
}
```

**Après :**
```qml
// Dans QML
LauncherManager.downloadResources(serverUrl, version)
```

**Avant (C++) :**
```cpp
// Dans QmlApp
void QmlApp::downloadResources(const QString &serverUrl, const QString &version) {
    // Logique mélangée avec l'app principale
}
```

**Après (C++) :**
```cpp
// Dans LauncherManager
void LauncherManager::downloadResources(const QString &serverUrl, const QString &version) {
    // Logique dédiée et isolée
}
```

### 🗑️ Code Supprimé de QmlApp

- Toutes les méthodes `Q_INVOKABLE` de launcher
- Signaux spécifiques au launcher
- Variables membres du launcher
- Slots de gestion réseau du launcher

### ➕ Code Ajouté

- `launcher_manager.h` et `launcher_manager.cpp`
- Enregistrement QML : `LauncherManager::registerQml()`
- Import QML : `import LauncherManager 1.0`

## Utilisation

### 📝 Depuis QML

```qml
import LauncherManager 1.0

Rectangle {
    // Accès aux propriétés
    Text { text: "Version: " + LauncherManager.currentVersion }
    
    // Appel des méthodes
    Button {
        text: "Télécharger"
        onClicked: LauncherManager.downloadResources(url, version)
    }
    
    // Écoute des signaux
    Connections {
        target: LauncherManager
        function onLogMessage(message) {
            console.log("Launcher:", message)
        }
    }
}
```

### 🔧 Depuis C++

```cpp
// Accès à l'instance
LauncherManager *launcher = LauncherManager::instance();

// Utilisation
launcher->testServerConnection("http://localhost:8080");
```

## Tests et Debugging

### 🧪 Tests Unitaires

Le singleton facilite les tests :

```cpp
// Test d'une fonctionnalité
LauncherManager *launcher = LauncherManager::instance();
QSignalSpy spy(launcher, &LauncherManager::downloadProgressChanged);
launcher->downloadResources("http://test", "1.0.0");
QVERIFY(spy.wait());
```

### 🐛 Debugging

- Tous les logs passent par le signal `logMessage`
- État centralisé dans le singleton
- Pas de duplication de données entre composants

## Fonctionnalités Avancées

### 🔒 Authentification des Uploads

Les uploads (assets et modèles) nécessitent un token d'authentification Bearer :
- Le token est configuré côté serveur via la variable d'environnement `UPLOAD_TOKEN`
- Côté client, le token est sauvegardé dans les Settings QML et transmis via `setUploadToken()`
- Le header `Authorization: Bearer <token>` est ajouté automatiquement aux requêtes POST

### 📥 Queue de Téléchargement

Le système gère une file d'attente de téléchargements :

```cpp
struct DownloadRequest {
    enum Type { Asset, Model };
    Type type;
    QString serverUrl, version, modelName, modelVersion;
};
QQueue<DownloadRequest> m_downloadQueue;
```

- Si un téléchargement est en cours, les nouveaux sont mis en queue
- `processNextDownload()` est appelé automatiquement à la fin de chaque téléchargement
- Élimine le besoin d'un flag `m_isModelDownload` — le type est dans la requête

### 🔄 Retry Automatique avec Reprise

En cas d'échec de téléchargement :
1. **3 tentatives** avec backoff exponentiel (2s, 4s, 8s)
2. **Reprise** : le fichier partiel est conservé entre les tentatives
3. **HTTP Range** : le header `Range: bytes=X-` reprend là où le téléchargement s'est arrêté
4. Le fichier partiel est pré-hashé pour maintenir la vérification d'intégrité

### ✅ Vérification d'Intégrité SHA-256

- Le hash est calculé en streaming pendant le téléchargement via `QCryptographicHash`
- Comparé au checksum retourné par le serveur (champ `checksum` de la version ou header `X-Checksum-Sha256`)
- En cas de mismatch, le fichier est supprimé et une erreur est signalée

### ⏱️ Timeout de Téléchargement

- Timer de 5 minutes (`DOWNLOAD_TIMEOUT_MS`) initialisé au début du téléchargement
- Réinitialisé à chaque progression (`onDownloadProgress`)
- Si aucune donnée n'est reçue pendant 5 minutes, le téléchargement est avorté

### 📊 Comparaison Sémantique de Versions

```cpp
static int compareVersions(const QString &v1, const QString &v2);
// Retourne -1 si v1 < v2, 0 si égales, 1 si v1 > v2
```

- Utilisé pour détecter les mises à jour (remplace la comparaison string `!=`)
- Utilisé aussi pour trier les versions de modèles 3D
- Gère correctement les cas comme `1.0.10 > 1.0.9`

### 🎨 Composants QML d'Interface

1. **LauncherHeader.qml** - En-tête et navigation
2. **ServerConfigSection.qml** - Configuration serveur + token d'upload
3. **VersionInfoSection.qml** - Versions, progression (avec taille en Mo), description
4. **ActionsSection.qml** - Boutons d'actions
5. **PackagingSection.qml** - Création/upload de paquets (assets et modèles 3D)
6. **ModelsSection.qml** - Liste et gestion des modèles 3D
7. **LogsSection.qml** - Logs et debug

Cette architecture moderne et modulaire rend le launcher plus robuste, maintenable et extensible pour les futures évolutions !
