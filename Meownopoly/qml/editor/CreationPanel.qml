import QtQuick 2.15
import QtQuick.Controls
import Case

Rectangle {
    id: creationPanel
    
    // Propriétés exposées
    property var snapableTilesList: []
    property alias totalCreated: creationInfo.totalCreated
    
    // Signaux
    signal createTileRequested(int caseType)
    
    width: 280
    height: 200
    color: "#f8f8f8"
    border.color: "#4CAF50"
    border.width: 2
    radius: 5
    
    Column {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 8
        
        Text {
            text: "Créer une nouvelle case"
            font.bold: true
            font.pixelSize: 14
            color: "#2E7D32"
        }
        
        Rectangle {
            width: parent.width
            height: 1
            color: "#4CAF50"
        }
        
        // Boutons pour différents types de cases - Ligne 1
        Row {
            spacing: 5
            
            Button {
                text: "🛌 Zone repos"
                font.pixelSize: 10
                width: 90
                height: 30
                onClicked: createTileRequested(Case.CS_RestArea)
                
                background: Rectangle {
                    color: parent.pressed ? "#81C784" : (parent.hovered ? "#A5D6A7" : "#C8E6C9")
                    border.color: "#4CAF50"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "🐱 Kibble"
                font.pixelSize: 10
                width: 80
                height: 30
                onClicked: createTileRequested(Case.CS_KibbleDispenser)
                
                background: Rectangle {
                    color: parent.pressed ? "#FFB74D" : (parent.hovered ? "#FFCC02" : "#FFF3E0")
                    border.color: "#FF9800"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "🌿 CatNip"
                font.pixelSize: 10
                width: 85
                height: 30
                onClicked: createTileRequested(Case.CS_CatNip)
                
                background: Rectangle {
                    color: parent.pressed ? "#AED581" : (parent.hovered ? "#C5E1A5" : "#DCEDC8")
                    border.color: "#8BC34A"
                    border.width: 1
                    radius: 4
                }
            }
        }
        
        // Boutons pour différents types de cases - Ligne 2
        Row {
            spacing: 5
            
            Button {
                text: "📦 Carton"
                font.pixelSize: 10
                width: 80
                height: 30
                onClicked: createTileRequested(Case.CS_CardBoardBox)
                
                background: Rectangle {
                    color: parent.pressed ? "#BCAAA4" : (parent.hovered ? "#D7CCC8" : "#EFEBE9")
                    border.color: "#795548"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "🔒 Prison"
                font.pixelSize: 10
                width: 80
                height: 30
                onClicked: createTileRequested(Case.CS_Jail)
                
                background: Rectangle {
                    color: parent.pressed ? "#E57373" : (parent.hovered ? "#EF9A9A" : "#FFEBEE")
                    border.color: "#F44336"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "😴 Sieste"
                font.pixelSize: 10
                width: 85
                height: 30
                onClicked: createTileRequested(Case.CS_FreeNap)
                
                background: Rectangle {
                    color: parent.pressed ? "#BA68C8" : (parent.hovered ? "#CE93D8" : "#F3E5F5")
                    border.color: "#9C27B0"
                    border.width: 1
                    radius: 4
                }
            }
        }
        
        // Boutons pour types supplémentaires - Ligne 3
        Row {
            spacing: 5
            
            Button {
                text: "🚪 CatDoor"
                font.pixelSize: 10
                width: 90
                height: 30
                onClicked: createTileRequested(Case.CS_CatDoor)
                
                background: Rectangle {
                    color: parent.pressed ? "#64B5F6" : (parent.hovered ? "#90CAF9" : "#E3F2FD")
                    border.color: "#2196F3"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "⚡ Device"
                font.pixelSize: 10
                width: 80
                height: 30
                onClicked: createTileRequested(Case.CS_Device)
                
                background: Rectangle {
                    color: parent.pressed ? "#FFD54F" : (parent.hovered ? "#FFF176" : "#FFFDE7")
                    border.color: "#FFEB3B"
                    border.width: 1
                    radius: 4
                }
            }
            
            Button {
                text: "→🔒 ToJail"
                font.pixelSize: 10
                width: 85
                height: 30
                onClicked: createTileRequested(Case.CS_ToJail)
                
                background: Rectangle {
                    color: parent.pressed ? "#FF8A65" : (parent.hovered ? "#FFAB91" : "#FBE9E7")
                    border.color: "#FF5722"
                    border.width: 1
                    radius: 4
                }
            }
        }
        
        Rectangle {
            width: parent.width
            height: 1
            color: "#4CAF50"
        }
        
        // Informations sur la création
        Item {
            id: creationInfo
            width: parent.width
            height: 20
            
            property int totalCreated: snapableTilesList.length
            
            Text {
                text: "Total créé: " + creationInfo.totalCreated + " tiles"
                font.pixelSize: 10
                color: "#666666"
                anchors.left: parent.left
            }
            
            Text {
                text: "✨ Cliquez pour créer"
                font.pixelSize: 9
                color: "#4CAF50"
                anchors.right: parent.right
                font.italic: true
            }
        }
    }
    
    // Animation de feedback lors de la création
    SequentialAnimation {
        id: createFeedback
        
        PropertyAnimation {
            target: creationPanel
            property: "scale"
            from: 1.0
            to: 1.05
            duration: 100
        }
        PropertyAnimation {
            target: creationPanel
            property: "scale"
            from: 1.05
            to: 1.0
            duration: 100
        }
    }
    
    // Fonction publique pour déclencher l'animation
    function triggerCreateFeedback() {
        createFeedback.start()
    }
} 