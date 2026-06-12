/*
 * LauncherLogic.qml - Pont logique entre l'interface QML et le backend C++
 *
 * Ce composant sert de couche d'abstraction entre l'interface utilisateur et le backend.
 * Il gère :
 * - La configuration (URL serveur, etc.)
 * - La propagation des signaux et mises à jour d'état
 * - La délégation des actions au singleton LauncherManager
 * - Le calcul des versions suivantes pour les paquets
 *
 * Propriétés exposées :
 * --------------------
 * - serverUrl : URL du serveur de ressources
 * - currentVersion : Version actuelle des ressources
 * - latestVersion : Dernière version disponible
 * - isDownloading : État du téléchargement
 * - downloadProgress : Progression (0.0 à 1.0)
 * - downloadStatus : Statut textuel des opérations
 * - packageCreated : État de création du paquet
 *
 * Signaux émis :
 * -------------
 * - logMessage : Messages pour le journal
 * - versionInfoUpdated : Mise à jour des versions
 * - downloadProgressUpdated : Progression du téléchargement
 * - downloadStatusUpdated : Changement de statut
 * - packageCreationCompleted : Résultat de la création
 */

import QtQuick 2.15
import QtCore
import LauncherManager 1.0

QtObject {
    id: root
    
    // Properties from Settings
    property string serverUrl: settings.serverUrl
    
    // Properties from LauncherManager singleton
    property string currentVersion: LauncherManager.currentVersion
    property string latestVersion: LauncherManager.latestVersion
    property bool isDownloading: LauncherManager.isDownloading
    property real downloadProgress: LauncherManager.downloadProgress
    property string downloadStatus: LauncherManager.downloadStatus
    property bool packageCreated: LauncherManager.packageCreated
    property var modelsList: LauncherManager.modelsList
    property real bytesReceived: LauncherManager.bytesReceived
    property real bytesTotal: LauncherManager.bytesTotal
    property string versionDescription: LauncherManager.versionDescription

    // Settings
    property Settings settings: Settings {
        property string serverUrl: "https://pattounecorp.ovh"
        property string lastVersion: "0.0.0"
        property string uploadToken: ""
    }
    
    // Signals pour communication avec l'interface
    signal logMessage(string message)
    signal versionInfoUpdated()
    signal downloadProgressUpdated()
    signal downloadStatusUpdated()
    signal packageCreationCompleted(bool success)
    signal updateAvailable();
    signal downloadSucess();
    signal modelsListUpdated();
    signal connectionTestResult(bool success, string message);

    // Helper pour calculer la version suivante
    function getNextVersion(currentVersion) {
        let parts = currentVersion.split('.')
        if (parts.length !== 3) return "1.0.0"
        
        let major = parseInt(parts[0])
        let minor = parseInt(parts[1])
        let patch = parseInt(parts[2])
        
        // Incrémenter le numéro de patch
        patch++
        
        return major + "." + minor + "." + patch
    }
    
    function forceDownloadResources() {
        root.settings.lastVersion = "0.0.0"
        LauncherManager.forceDownloadResources(root.serverUrl)
    }

    // Fonctions appelées par l'interface - délèguent au singleton
    function testConnection() {
        LauncherManager.testServerConnection(root.serverUrl)
    }
    
    function checkForUpdates() {
        LauncherManager.checkForUpdates(root.serverUrl)
    }
    
    function downloadResources() {
        LauncherManager.downloadResources(root.serverUrl, root.latestVersion)
    }

    function createResourcePackage(folderPath, version) {
        LauncherManager.createResourcePackage(folderPath, version)
    }
    
    function uploadPackage() {
        LauncherManager.uploadPackageToServer(root.serverUrl)
    }
    
    // Fonctions Modèles
    function fetchModelsList() {
        LauncherManager.fetchModelsList(root.serverUrl)
    }

    function downloadModel(name, version) {
        LauncherManager.downloadModel(root.serverUrl, name, version)
    }

    function deleteModel(name) {
        return LauncherManager.deleteModel(name)
    }

    function createModelPackage(folderPath, name, version) {
        LauncherManager.createModelPackage(folderPath, name, version)
    }

    function uploadModelPackage(name, version) {
        LauncherManager.uploadModelPackage(root.serverUrl, name, version)
    }

    function deleteModelFromServer(name, version) {
        LauncherManager.deleteModelPackage(root.serverUrl, name, version)
    }

    // --- Configurateur de modèle 3D ---
    function findModelQml(folderPath) {
        return LauncherManager.findModelQml(folderPath)
    }

    function readModelManifest(folderPath) {
        return LauncherManager.readModelManifest(folderPath)
    }

    function readModelTransform(folderPath, modelName) {
        return LauncherManager.readModelTransform(folderPath, modelName)
    }

    function writeModelTransform(folderPath, modelName, sx, sy, sz, rx, ry, rz, px, py, pz) {
        return LauncherManager.writeModelTransform(folderPath, modelName, sx, sy, sz, rx, ry, rz, px, py, pz)
    }

    function updateServerUrl(newUrl) {
        root.settings.serverUrl = newUrl
    }

    function updateUploadToken(token) {
        root.settings.uploadToken = token
        LauncherManager.setUploadToken(token)
    }

    function resetDownloadState() {
        LauncherManager.resetDownloadState()
    }
    
    // Connexions avec le singleton LauncherManager
    property Connections launcherConnections: Connections {
        target: LauncherManager

        function onDownloadSucess() {
            root.downloadSucess()
        }

        function onUpdateAvailable() {
            root.updateAvailable();
        }
        
        function onCurrentVersionChanged() {
            root.versionInfoUpdated()
        }
        
        function onLatestVersionChanged() {
            root.versionInfoUpdated()
        }
        
        function onIsDownloadingChanged() {
            root.downloadProgressUpdated()
        }
        
        function onDownloadProgressChanged() {
            root.downloadProgressUpdated()
        }
        
        function onDownloadStatusChanged() {
            root.downloadStatusUpdated()
        }
        
        function onPackageCreatedChanged() {
            root.packageCreationCompleted(LauncherManager.packageCreated)
        }
        
        function onModelsListChanged() {
            root.modelsListUpdated()
        }

        function onLogMessage(message) {
            root.logMessage(message)
        }
        
        function onConnectionTestResult(success, message) {
            root.connectionTestResult(success, message)
        }
    }
    
    // Initialisation
    Component.onCompleted: {
        root.logMessage("Launcher Logic initialisé")
        // Charger le token depuis les settings
        if (root.settings.uploadToken.length > 0) {
            LauncherManager.setUploadToken(root.settings.uploadToken)
        }
    }
}
