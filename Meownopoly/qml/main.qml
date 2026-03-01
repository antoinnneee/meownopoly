pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "launcher/"
import "board"
import "editor"
import "account/"
import "multiplayer/"

import QtQuick.Window
import Qt.labs.platform
import QtCore

import Game
import Meownopoly.Account 1.0


ApplicationWindow {
    id: root
    
    Settings {
        id: stVideoConfig
        category: "Video"
    }

    width: {
        let res = stVideoConfig.value("resolution", "1280x720")
        let parts = res.split("x")
        return parts.length === 2 ? parseInt(parts[0]) : 1280
    }
    
    height: {
        let res = stVideoConfig.value("resolution", "1280x720")
        let parts = res.split("x")
        return parts.length === 2 ? parseInt(parts[1]) : 720
    }
    
    visible: true
    title: "Meownopoly"
    
    visibility: (Qt.platform.os === "android") ? Window.FullScreen
        : ((stVideoConfig.value("fullscreen", false) === "true" || stVideoConfig.value("fullscreen", false) === true) ? Window.FullScreen : Window.Windowed)

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: AccountManager.hasAccount ? titleScreen : accountSetup
    }

    // Account setup page for first launch
    Component {
        id: accountSetup
        AccountSetupPage {
            onAccountCreated: {
                stackView.replace(titleScreen)
            }
        }
    }

    Component {
        id: titleScreen
        TitleScreen {
            onStartGameRequested: {
                stackView.push(gameBoard)
            }

            onEditorRequested:{
                //stackView.pop()
                stackView.push(editor)
            }
            onTestViewRequested: {
                stackView.pop()
                stackView.push(test_view)
            }

            onCaseCreatorRequested: {
                stackView.pop()
            }

            onTest3DRequested: {
                stackView.pop()
                stackView.push(test_view)
            }
            
            onLauncherRequested: {
                stackView.pop()
                stackView.push(launcher)
            }
            
            onAssetManagerTestRequested: {
                stackView.push(assetManagerTest)
            }
            
            onMultiplayerLobbyRequested: {
                stackView.push(multiplayerLobby)
            }

            onCatwayTestRequested: {
                stackView.push(catwayTest)
            }
        }
    }

    Component {
        id: gameBoard
        GameBoard {
            width:root.width
            height:root.height
            visible: false
        }
    }

    Component {
        id: editor
        Editor {
            width:root.width
            height:root.height
            visible: false
            appPositionX: root.x
            appPositionY: root.y
            escMenu.onReturnToMainMenu: {
                console.log("Retour au menu principal demandé")
                stackView.pop()
            }
        }
    }
    Component{
        id: test_view
        TEST_3D{
            width:root.width
            height:root.height
            visible: false
        }
    }
    Component {
        id: testPaw
        TEST_PAW_MENU{
            width:root.width
            height:root.height
            visible: false
        }
    }


    Component {
        id: testComp
        Test_Comp {
            width: root.width
            height: root.height
            visible: false
            
            // Fonction pour revenir à l'écran titre
            function goBack() {
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }

    Component {
        id: launcher
        Launcher {
            width: root.width
            height: root.height
            visible: false
            
            onBackRequested: {
                stackView.pop()
                stackView.push(titleScreen)
            }
            onLaunchGame: {
                // Ici on peut ajouter la logique pour lancer le jeu principal
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }
    
    Component {
        id: assetManagerTest
        TEST_ASSET_MANAGER {
            width: root.width
            height: root.height
            visible: false
            
            onBackRequested: {
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }
    
    Component {
        id: multiplayerLobby
        MultiplayerLobby {
            width: root.width
            height: root.height

            onBackToTitleScreen: {
                stackView.pop()
            }
        }
    }

    Component {
        id: catwayTest
        CatwayTest {
            width: root.width
            height: root.height

            onBackRequested: {
                stackView.pop()
            }
        }
    }
}
