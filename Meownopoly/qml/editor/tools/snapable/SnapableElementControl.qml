import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import "../../../item_icon"

Item {
    id: controlsRoot
    
    // Propriétés requises du parent
    required property var targetElement
    required property bool isVisible
    required property int zLayer
    
    // Signaux
    signal layerChanged(int newLayer)
    signal deleteRequested()
    signal configurationRequested()
    signal connectionsConfigurationRequested()

    // Propriété pour accéder à la valeur z du target
    readonly property int currentZ: targetElement ? targetElement.z : 0

    visible: isVisible
    z: 200  // Au-dessus de tout
    
    // Positionner à droite de l'élément parent
    anchors.left: parent.right
    anchors.top: parent.top
    anchors.leftMargin: 10
    width: 40
    height: controlsColumn.height
    
    // Colonne de contrôles
    Column {
        id: controlsColumn
        spacing: 5
        
        // Sélecteur de plans
        Column {
            id: layerSelector
            spacing: 2
            width: 40

            LayerVisualizer {
                id: layerOption
                width: parent.width
                selectedLayer: zLayer -1
                onLayerClicked: function(index){
                    console.log("layer " + index + "clicked")
                    layerChanged(index +1)
                }

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }

            }
        }
        
        // Séparateur
        Rectangle {
            width: parent.width
            height: 1
            color: "white"
            opacity: 0.3
        }
        
        // Bouton de configuration
        Rectangle {
            id: configButton
            width: parent.width
            height: width
            color: "#2196F3"
            border.color: "white"
            border.width: 1
            radius: 4
            
            Text {
                anchors.centerIn: parent
                text: "⚙️"
                color: "white"
                font.bold: true
                font.pixelSize: 20
            }
            
            MouseArea {
                id: configButtonMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    console.log("Configuration de l'élément demandée")
                    configurationRequested()
                }
                
                onEntered: configButton.state = "hovered"
                onExited: configButton.state = ""
            }
            
            states: State {
                name: "hovered"
                PropertyChanges { 
                    target: configButton
                    scale: 1.05
                }
            }
            
            transitions: Transition {
                NumberAnimation { 
                    properties: "scale"
                    duration: 100
                }
            }
        }

        // Bouton de configuration des connexions (en dessous du bouton d'attributs)
        Rectangle {
            id: connectionsButton
            width: parent.width
            height: width
            color: "#6f42c1" // violet
            border.color: "white"
            border.width: 1
            radius: 4

            Text {
                anchors.centerIn: parent
                text: "🔗"
                color: "white"
                font.bold: true
                font.pixelSize: 20
            }

            MouseArea {
                id: connectionsButtonMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    console.log("Configuration des connexions demandée")
                    connectionsConfigurationRequested()
                }

                onEntered: connectionsButton.state = "hovered"
                onExited: connectionsButton.state = ""
            }

            states: State {
                name: "hovered"
                PropertyChanges {
                    target: connectionsButton
                    scale: 1.05
                }
            }

            transitions: Transition {
                NumberAnimation {
                    properties: "scale"
                    duration: 100
                }
            }
        }
        
        // Bouton de suppression
        Rectangle {
            id: deleteButton
            width: parent.width
            height: width
            color: "#F44336"
            border.color: "white"
            border.width: 1
            radius: 4
            
            Text {
                anchors.centerIn: parent
                text: "🗑️"
                color: "white"
                font.bold: true
                font.pixelSize: 24
            }
            
            MouseArea {
                id: deleteButtonMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    console.log("Suppression de l'élément demandée")
                    deleteRequested()
                }
                
                onEntered: deleteButton.state = "hovered"
                onExited: deleteButton.state = ""
            }
            
            states: State {
                name: "hovered"
                PropertyChanges { 
                    target: deleteButton
                    scale: 1.05
                }
            }
            
            transitions: Transition {
                NumberAnimation { 
                    properties: "scale"
                    duration: 100
                }
            }
        }
    }
}
