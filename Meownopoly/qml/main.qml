pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "editor/"
import "launcher/"
import "asset_tools/"
import QtQuick.Window
import Game

import Qt.labs.platform

ApplicationWindow {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Meownopoly"
    
    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: launcher
    }

    Component {
        id: titleScreen
        TitleScreen {
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
                stackView.push(caseCreator)
            }

            onTest3DRequested: {
                stackView.pop()
                stackView.push(testPaw)
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
        id: editor
        GameBoard{
        width:root.width
        height:root.height
        visible: false
        }
    }
    Component{
        id: test_view
        TEST_CASE{
            width:root.width
            height:root.height
            visible: false
        }
    }
    Component {
        id: caseCreator
        TEST_JSON{
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
        id: test3D
        TEST_3D {
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
