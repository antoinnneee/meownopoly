pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "launcher/"
import "board"
import "Editor"

import QtQuick.Window
import Qt.labs.platform

import Game


ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Meownopoly"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: titleScreen
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
}
