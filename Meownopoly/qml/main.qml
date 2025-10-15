pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "editor/"
import "launcher/"
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
        initialItem: titleScreen
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
            }

            onTest3DRequested: {
                stackView.pop()
                stackView.push(testComp)
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
        Editor{
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
