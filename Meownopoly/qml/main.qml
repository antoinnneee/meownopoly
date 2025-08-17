pragma ComponentBehavior:Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import "test/"
import "editor/"
import "archiver/"
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
                stackView.push(caseCreator)
            }

            onTest3DRequested: {
                stackView.pop()
                stackView.push(test3D)
            }

            onArchiverRequested: {
                stackView.pop()
                stackView.push(assetArchiver)
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
        id: caseCreator
        TEST_JSON{
            width:parent.width
            height:parent.height
            visible: false
        }
    }
    
    Component {
        id: test3D
        TEST_3D {
            width: parent.width
            height: parent.height
            visible: false
            
            // Fonction pour revenir à l'écran titre
            function goBack() {
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }
    
    Component {
        id: assetArchiver
        AssetArchiver {
            width: parent.width
            height: parent.height
            visible: false
            
            onBackRequested: {
                stackView.pop()
                stackView.push(titleScreen)
            }
        }
    }
}
