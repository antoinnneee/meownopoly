import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Case
import Player

import "../case/"
import "../boardTile/"

Rectangle {
    id: root
    width: 800
    height: 800

    color: "#2c3e50"

    // Card dimensions
    property real cardWidth: Screen.pixelDensity * 20  // 2.5cm
    property real cardHeight: Screen.pixelDensity * 35   // Alternative height
    
    property list<CaseTile> listCaseTile
    property list<Player_Test>  listPlayerTest
    property var colorList: ["red", "green", "blue", "orange", "purple"]
    property int selectedPlayerIndex: 0



    // Card display area
    RowLayout {
        id: cardContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 50
        spacing: 10

        Repeater {
            id : repeater
            model: 10
            delegate : CaseTile {
                required property int index
                width: cardWidth
                height: cardHeight
                caseData: Game.listCases[index]
                Component.onCompleted: {
                    listCaseTile.push(this)
                }
            }
        }
    }

    // Bouton pour ajouter un player
    Rectangle {
        id: addPlayerButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        color: "#27ae60"
        width: 120
        height: 40
        border.color: "#229954"
        border.width: 2
        radius: 8
        
        Text {
            anchors.centerIn: parent
            text: "Ajouter Player"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.color = "#58d68d"
            onExited: parent.color = "#27ae60"
            onClicked: {
                // Créer un nouveau Player_Test dynamiquement
                var component = Qt.createComponent("../boardTile/Player_Test.qml")
                if (component.status === Component.Ready) {
                    var newPlayerTest = component.createObject(root, {})
                    newPlayerTest.playerInfo.color = colorList[listPlayerTest.length % colorList.length]
                    listPlayerTest.push(newPlayerTest)
                }
            }
        }
    }

    // Panneau unifié: Sélecteur + Informations joueur
    Rectangle {
        id: playerPanel
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 20
        color: "#9b59b6"
        width: Math.max(200, listPlayerTest.length * 25 + 10)
        height: listPlayerTest.length > 0 ? 170 : 80
        border.color: "#8e44ad"
        border.width: 2
        radius: 8
        
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 0
            
            // Section Sélecteur
            Item {
                width: parent.width
                height: 40
                
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Select:"
                    color: "white"
                    font.pixelSize: 10
                    font.bold: true
                }
                
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    
                    Repeater {
                        model: listPlayerTest.length
                        delegate: Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            property var selectedPlayerInfo : listPlayerTest[index].playerInfo
                            color : selectedPlayerInfo.color
                            border.color: selectedPlayerIndex === index ? "white" : "transparent"
                            border.width: 3
                            
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: "white"
                                font.pixelSize: 10
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    selectedPlayerIndex = index
                                    console.log("Player sélectionné:", index)
                                }
                            }
                        }
                    }
                }
            }
            
            // Démarcation
            Rectangle {
                width: parent.width
                height: 2
                color: "#8e44ad"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Section Informations
            Item {
                width: parent.width
                height: listPlayerTest.length > 0 ? 120 : 30
                
                Column {
                    anchors.fill: parent
                    anchors.topMargin: 10
                    spacing: 5
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: listPlayerTest.length > 0 ? "Informations Joueur " + (selectedPlayerIndex + 1) : "Aucun joueur"
                        color: "white"
                        font.pixelSize: 12
                        font.bold: true
                    }
                    
                    // Afficher les infos uniquement s'il y a des joueurs
                    Item {
                        width: parent.width
                        height: listPlayerTest.length > 0 ? childrenRect.height : 0
                        visible: listPlayerTest.length > 0
                        
                        Column {
                            width: parent.width
                            spacing: 3
                            
                            property var currentPlayer: listPlayerTest.length > selectedPlayerIndex ? listPlayerTest[selectedPlayerIndex].playerInfo : null
                            
                            Text {
                                text: "Nom: " + (parent.currentPlayer ? parent.currentPlayer.name || "Sans nom" : "N/A")
                                color: "white"
                                font.pixelSize: 10
                            }
                            
                            Row {
                                spacing: 5
                                Text {
                                    text: "Couleur:"
                                    color: "white"
                                    font.pixelSize: 10
                                }
                                Rectangle {
                                    width: 15
                                    height: 15
                                    radius: 7
                                    color: parent.parent.currentPlayer ? parent.parent.currentPlayer.color : "transparent"
                                    border.color: "white"
                                    border.width: 1
                                }
                            }
                            
                            Text {
                                text: "Position: " + (parent.currentPlayer ? parent.currentPlayer.position : "0")
                                color: "white"
                                font.pixelSize: 10
                            }
                            
                            Text {
                                text: "Kibbles: " + (parent.currentPlayer ? parent.currentPlayer.kibble : "0")
                                color: "white"
                                font.pixelSize: 10
                            }
                            
                            Text {
                                text: "Propriétés: " + (parent.currentPlayer ? parent.currentPlayer.propertyCount : "0")
                                color: "white"
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    // Bouton pour déplacer le player sélectionné
    Rectangle {
        id: moveButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        color: "#3498db"
        width: 120
        height: 40
        border.color: "#2980b9"
        border.width: 2
        radius: 8
        
        Text {
            anchors.centerIn: parent
            text: "Avancer Player"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: parent.color = "#5dade2"
            onExited: parent.color = "#3498db"
            onClicked: {
                if (listPlayerTest.length > 0 && selectedPlayerIndex < listPlayerTest.length) {

                    var currentPos = listPlayerTest[selectedPlayerIndex].playerInfo.position
                    var newPos = (currentPos + 1) % (listCaseTile.length)

                    listPlayerTest[selectedPlayerIndex].playerInfo.position = newPos
                    //event "on position changed" called -> updatePosition()
                    //                                      emit signal onLand() and onLeave()

                    console.log("Player " + (selectedPlayerIndex + 1) + " déplacé vers position " + newPos)
                } else {
                    console.log("Aucun player à déplacer ou index invalide")
                }
            }
        }
    }
}
