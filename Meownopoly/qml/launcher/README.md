# Structure du Launcher Modulaire

## Vue d'ensemble

Le launcher a été divisé en plusieurs composants modulaires pour améliorer la maintenabilité et la lisibilité du code.

## Architecture des fichiers

### 📁 Fichiers principaux

- **`Launcher.qml`** - Fichier principal qui orchestre tous les composants
- **`LauncherLogic.qml`** - Logique métier et gestion des données

### 🎨 Composants d'interface

- **`LauncherHeader.qml`** - En-tête avec titre et bouton retour
- **`ServerConfigSection.qml`** - Configuration du serveur et tests de connexion
- **`VersionInfoSection.qml`** - Affichage des versions et barre de progression
- **`ActionsSection.qml`** - Boutons d'actions (vérifier, télécharger, etc.)
- **`PackagingSection.qml`** - Création et upload de paquets de ressources
- **`LogsSection.qml`** - Zone d'affichage des logs avec bouton d'effacement

## Communication entre composants

### 🔄 Flux de données

```
Launcher.qml (orchestrateur)
    ├── LauncherLogic.qml (données + logique)
    │   ├── Settings (persistance)
    │   └── Connections (backend C++)
    │
    └── Composants UI
        ├── LauncherHeader.qml
        ├── ServerConfigSection.qml
        ├── VersionInfoSection.qml
        ├── ActionsSection.qml
        ├── PackagingSection.qml
        └── LogsSection.qml
```

### 📡 Signaux et propriétés

**LauncherLogic → Interface :**
- `logMessage(string)` - Nouveau message de log
- `versionInfoUpdated()` - Mise à jour des versions
- `downloadProgressUpdated()` - Progression du téléchargement
- `downloadStatusUpdated()` - Changement de statut
- `packageCreationCompleted(bool)` - Fin de création de paquet

**Interface → LauncherLogic :**
- `testConnection()` - Test de connexion serveur
- `checkForUpdates()` - Vérification des mises à jour
- `downloadResources()` - Téléchargement des ressources
- `forceDownload()` - Téléchargement forcé
- `createResourcePackage(folder, version)` - Création de paquet
- `uploadPackage()` - Upload vers serveur
- `updateServerUrl(url)` - Mise à jour URL serveur

## Avantages de cette architecture

### ✅ Maintenabilité
- Chaque composant a une responsabilité unique
- Modifications localisées sans impact sur les autres composants
- Code plus facile à comprendre et déboguer

### ✅ Réutilisabilité
- Les composants peuvent être réutilisés dans d'autres parties de l'application
- Logique métier séparée de l'interface utilisateur

### ✅ Testabilité
- Chaque composant peut être testé indépendamment
- Logique métier isolée dans LauncherLogic.qml

### ✅ Lisibilité
- Fichiers plus petits et focalisés
- Structure claire et organisée
- Séparation des préoccupations

## Modification et extension

### 🔧 Ajouter une nouvelle section

1. Créer un nouveau fichier `NouvelleSection.qml`
2. L'ajouter dans `Launcher.qml`
3. L'inclure dans `qml.qrc`
4. Connecter les signaux si nécessaire

### 🔧 Modifier la logique métier

- Toutes les modifications de logique se font dans `LauncherLogic.qml`
- Les composants UI restent inchangés

### 🔧 Modifier l'apparence

- Chaque composant UI peut être modifié indépendamment
- Styles cohérents définis dans chaque composant

## Exemple d'utilisation

```qml
// Dans Launcher.qml
PackagingSection {
    id: packagingSection
    packageCreated: logic.packageCreated
    isDownloading: logic.isDownloading
    
    onCreatePackageRequested: function(folderPath, version) {
        logic.createResourcePackage(folderPath, version)
    }
    onUploadPackageRequested: logic.uploadPackage()
}
```

Cette architecture modulaire rend le launcher plus robuste, maintenable et extensible pour les futures évolutions.
