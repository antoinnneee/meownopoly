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
    
    // Settings
    property Settings settings: Settings {
        property string serverUrl: "http://pattounecorp.ovh"
        property string lastVersion: "0.0.0"
    }
    
    // Signals pour communication avec l'interface
    signal logMessage(string message)
    signal versionInfoUpdated()
    signal downloadProgressUpdated()
    signal downloadStatusUpdated()
    signal packageCreationCompleted(bool success)
    signal updateAvailable();
    
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
    
    function updateServerUrl(newUrl) {
        root.serverUrl = newUrl
        root.settings.serverUrl = newUrl
    }
    
    function resetDownloadState() {
        LauncherManager.resetDownloadState()
    }
    
    // Connexions avec le singleton LauncherManager
    property Connections launcherConnections: Connections {
        target: LauncherManager

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
        
        function onLogMessage(message) {
            root.logMessage(message)
        }
        
        function onConnectionTestResult(success, message) {
            // Ce signal est déjà géré directement par les composants si nécessaire
        }
    }
    
    // Initialisation
    Component.onCompleted: {
        root.logMessage("Launcher Logic initialisé")
    }
}
