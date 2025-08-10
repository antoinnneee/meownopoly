import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: controlsRoot
    
    // Propriétés requises du parent
    required property var targetElement
    required property bool isVisible
    
    // Signaux
    signal layerChanged(int newLayer)
    signal deleteRequested()
    signal configurationRequested()
    signal connectionsConfigurationRequested()
    
    // Propriétés pour accéder aux données du target
    readonly property var zLayers: targetElement ? targetElement.zLayers : null
    readonly property int currentZLayer: targetElement ? targetElement.zLayer : 0
    readonly property int zLayerBase: targetElement ? targetElement.zLayerBase : 0
    
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
            
            Repeater {
                model: 3
                
                Rectangle {
                    id: layerOption
                    width: parent.width
                    height: 20
                    radius: 4
                    
                    property bool isSelected: index === currentZLayer
                    property color baseColor: zLayers ? zLayers.colors[index] : "gray"
                    
                    color: isSelected ? baseColor : Qt.darker(baseColor, 1.5)
                    border.color: "white"
                    border.width: isSelected ? 2 : 1
                    scale: isSelected ? 1.1 : 1.0
                    
                    Behavior on scale {
                        NumberAnimation { duration: 100 }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: zLayers ? zLayers.names[index][0] : "?"  // Première lettre uniquement
                        color: "white"
                        font.bold: true
                        font.pixelSize: 12
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onClicked: {
                            layerChanged(index)
                        }
                        
                        onEntered: parent.scale = 1.1
                        onExited: parent.scale = parent.isSelected ? 1.1 : 1.0
                    }
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
