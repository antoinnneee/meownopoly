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
import LauncherManager 1.0

import AssetManager

Rectangle {
    id: root
    color: "#1e1e1e"

    property bool autoUpdate : true
    // Bascule entre la vue principale du launcher et le configurateur 3D.
    // "launcher" (défaut) | "modelConfigurator"
    property string currentView: "launcher"
    // Dossier à charger d'emblée dans le configurateur (bouton « Éditer »).
    // Vide = configurateur ouvert sans modèle (création depuis zéro).
    property string configFolderPath: ""

    signal launchGame()
    signal backRequested()
    
    // Logic component
    LauncherLogic {
        id: logic

        onUpdateAvailable: {
            if (autoUpdate) {
                logic.downloadResources()
            } else {
                updateBanner.visible = true
            }
        }
        
        onLogMessage: function(message) {
            logsSection.addLog(message)
        }
        
        onVersionInfoUpdated: {
            // Bindings déclaratifs dans les sections — rien à faire ici
        }

        onDownloadProgressUpdated: {
            // Bindings déclaratifs dans les sections — rien à faire ici
        }
        
        onDownloadStatusUpdated: {
            // Binding déclaratif dans VersionInfoSection — rien à faire ici
            console.log("download state changed : ", logic.downloadStatus)
        }
        
        onPackageCreationCompleted: function(success) {
            packagingSection.packageCreated = success
        }

        onDownloadSucess: {
            AssetManager.loadAssets()
        }

        Component.onCompleted: {
            console.log("LauncherLogic completed")
            logic.testConnection()
            logic.checkForUpdates()
            logic.fetchModelsList()
        }
    }
    
    // Bannière de mise à jour (quand autoUpdate est désactivé)
    Rectangle {
        id: updateBanner
        visible: false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 40
        color: "#FF9800"
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10

            Text {
                text: "Nouvelle version disponible: " + logic.latestVersion
                color: "white"
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: "Telecharger"
                onClicked: { logic.downloadResources(); updateBanner.visible = false }
                background: Rectangle { color: "#E65100"; radius: 4 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }

            Button {
                text: "x"
                onClicked: updateBanner.visible = false
                background: Rectangle { color: "transparent" }
                contentItem: Text { text: parent.text; color: "white"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    // Configurateur de modèle 3D (plein écran, masque le launcher)
    Loader {
        id: modelConfigLoader
        anchors.fill: parent
        active: root.currentView === "modelConfigurator"
        visible: active
        z: 100
        sourceComponent: ModelConfigurator {
            serverUrl: logic.serverUrl
            initialFolderPath: root.configFolderPath
            onCloseRequested: root.currentView = "launcher"
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.topMargin: updateBanner.visible ? updateBanner.height + 10 : 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        contentWidth: availableWidth
        visible: root.currentView === "launcher"

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
                uploadToken: logic.settings.uploadToken

                onServerUrlChanged: logic.updateServerUrl(serverUrl)
                onTestConnectionRequested: logic.testConnection()
                onUploadTokenEdited: function(token) { logic.updateUploadToken(token) }
            }

            // Connexion test résultat (via LauncherLogic, plus de couplage direct)
            Connections {
                target: logic
                function onConnectionTestResult(success, message) {
                    serverConfigSection.connectionValid = success
                    serverConfigSection.connectionMessage = message
                    serverConfigSection.statusAnimation.start()
                    serverConfigSection.statusIcon.state = success ? "valid" : "invalid"
                }
            }

            // Section 2: Informations de version
            VersionInfoSection {
                id: versionInfoSection
                currentVersion: logic.currentVersion
                latestVersion: logic.latestVersion
                downloadStatus: logic.downloadStatus
                isDownloading: logic.isDownloading
                downloadProgress: logic.downloadProgress
                bytesReceived: logic.bytesReceived
                bytesTotal: logic.bytesTotal
                versionDescription: logic.versionDescription
            }
            
            // Section 3: Actions
            ActionsSection {
                id: actionsSection
                isDownloading: logic.isDownloading
                currentVersion: logic.currentVersion
                latestVersion: logic.latestVersion
                
                onCheckForUpdatesRequested: logic.checkForUpdates()
                onDownloadResourcesRequested: logic.downloadResources()
                onLaunchGameRequested: root.launchGame()
                onForceDownloadRequested: logic.forceDownloadResources()
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
                
                onCreateModelPackageRequested: function(folderPath, name, version) {
                    logic.createModelPackage(folderPath, name, version)
                }
                onUploadModelRequested: function(name, version) {
                    logic.uploadModelPackage(name, version)
                }

                onOpenModelConfiguratorRequested: {
                    root.configFolderPath = ""   // création depuis zéro
                    root.currentView = "modelConfigurator"
                }
            }

            // Section Modèles (Nouveau)
            ModelsSection {
                id: modelsSection
                modelsList: logic.modelsList
                isDownloading: logic.isDownloading
                
                onRefreshRequested: logic.fetchModelsList()
                onDownloadRequested: function(name, version) {
                    logic.downloadModel(name, version)
                }
                onEditRequested: function(name) {
                    const dir = LauncherManager.installedModelDir(name)
                    if (dir && dir.length > 0) {
                        root.configFolderPath = dir
                        root.currentView = "modelConfigurator"
                    }
                }
            }
            
            // Section 5: Logs
            LogsSection {
                id: logsSection
                
                onResetDownloadStateRequested: logic.resetDownloadState()
            }
        }
    }
}
