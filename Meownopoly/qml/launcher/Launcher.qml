/*
 * Launcher.qml - Gestionnaire de ressources pour Meownopoly
 * 
 * Ce launcher gère le téléchargement, la mise à jour et la création des paquets de ressources
 * du jeu Meownopoly. Il permet de synchroniser les assets (textures, sons, modèles 3D, etc.)
 * avec un serveur distant.
 *
 * Structure du launcher :
 * ----------------------
 * 1. LauncherHeader
 *    - En-tête avec titre et bouton retour
 *    - Navigation vers l'écran titre
 *
 * 2. ServerConfigSection
 *    - Configuration de l'URL du serveur de ressources
 *    - Test de connexion au serveur
 *    - Sauvegarde automatique des paramètres
 *
 * 3. VersionInfoSection
 *    - Affichage des versions (actuelle et dernière disponible)
 *    - Barre de progression des téléchargements
 *    - Statut des opérations en cours
 *
 * 4. ActionsSection
 *    - Vérification des mises à jour
 *    - Téléchargement des ressources
 *    - Forçage du téléchargement
 *    - Lancement du jeu
 *
 * 5. PackagingSection
 *    - Création de nouveaux paquets de ressources
 *    - Upload vers le serveur
 *    - Gestion des versions automatique
 *
 * 6. LogsSection
 *    - Journal des opérations
 *    - Bouton de réinitialisation
 *    - Historique des actions
 *
 * Communication :
 * --------------
 * - LauncherLogic : Pont entre l'interface QML et le backend C++
 * - LauncherManager : Singleton C++ gérant toute la logique métier
 * - Signaux et propriétés bindées pour la synchronisation d'état
 *
 * Format des ressources :
 * ----------------------
 * - Paquets compressés au format .meow
 * - Nommage : assets_vX.X.X.meow (ex: assets_v1.0.3.meow)
 * - Manifest JSON inclus avec métadonnées
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "#1e1e1e"
    
    signal launchGame()
    signal backRequested()
    
    // Logic component
    LauncherLogic {
        id: logic
        
        onLogMessage: function(message) {
            logsSection.addLog(message)
        }
        
        onVersionInfoUpdated: {
            versionInfoSection.currentVersion = logic.currentVersion
            versionInfoSection.latestVersion = logic.latestVersion
            actionsSection.currentVersion = logic.currentVersion
            actionsSection.latestVersion = logic.latestVersion
        }
        
        onDownloadProgressUpdated: {
            versionInfoSection.downloadProgress = logic.downloadProgress
            versionInfoSection.isDownloading = logic.isDownloading
            actionsSection.isDownloading = logic.isDownloading
            packagingSection.isDownloading = logic.isDownloading
        }
        
        onDownloadStatusUpdated: {
            versionInfoSection.downloadStatus = logic.downloadStatus
        }
        
        onPackageCreationCompleted: function(success) {
            packagingSection.packageCreated = success
        }
    }
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: availableWidth
        
        ColumnLayout {
            width: parent.width
            spacing: 15
            
            // Header
            LauncherHeader {
                onBackRequested: root.backRequested()
            }
            
            // Section 1: Configuration du serveur
            ServerConfigSection {
                id: serverConfigSection
                serverUrl: logic.serverUrl
                
                onServerUrlChanged: logic.updateServerUrl(serverUrl)
                onTestConnectionRequested: logic.testConnection()
            }
            
            // Section 2: Informations de version
            VersionInfoSection {
                id: versionInfoSection
                currentVersion: logic.currentVersion
                latestVersion: logic.latestVersion
                downloadStatus: logic.downloadStatus
                isDownloading: logic.isDownloading
                downloadProgress: logic.downloadProgress
            }
            
            // Section 3: Actions
            ActionsSection {
                id: actionsSection
                isDownloading: logic.isDownloading
                currentVersion: logic.currentVersion
                latestVersion: logic.latestVersion
                
                onCheckForUpdatesRequested: logic.checkForUpdates()
                onDownloadResourcesRequested: logic.downloadResources()
                onForceDownloadRequested: logic.forceDownload()
                onLaunchGameRequested: root.launchGame()
            }
            
            // Section 4: Création de paquets
            PackagingSection {
                id: packagingSection
                packageCreated: logic.packageCreated
                isDownloading: logic.isDownloading
                currentVersion: logic.currentVersion
                
                onCreatePackageRequested: function(folderPath, version) {
                    logic.createResourcePackage(folderPath, version)
                }
                onUploadPackageRequested: logic.uploadPackage()
            }
            
            // Section 5: Logs
            LogsSection {
                id: logsSection
                
                onResetDownloadStateRequested: logic.resetDownloadState()
            }
        }
    }
}
