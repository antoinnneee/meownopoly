import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui_item"
import "./components"

/**
 * Vue complète des détails d'une session
 * Contient: header, infos session, liste joueurs, boutons actions
 */
Rectangle {
    id: root
    
    color: "#1a1a1a"
    
    // Props reçues de la navigation
    required property string sessionName
    required property string sessionId
    required property int players
    required property int maxPlayers
    
    signal backRequested()
    signal joinRequested()
    
    // Modèle de joueurs factices (4 joueurs)
    ListModel {
        id: playersModel
        
        ListElement {
            nickname: "MisterWhiskers"
            avatar: "🐱"
            isHost: true
        }
        ListElement {
            nickname: "LadyPaws"
            avatar: "😺"
            isHost: false
        }
        ListElement {
            nickname: "SirMeowsAlot"
            avatar: "😸"
            isHost: false
        }
        ListElement {
            nickname: "CaptainFluff"
            avatar: "😻"
            isHost: false
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // HEADER INTÉGRÉ
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            color: "transparent"
            
            // Bouton retour
            BackButton {
                id: backBtn
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                
                onBackClicked: root.backRequested()
            }
            
            // Nom et ID de session (centré)
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4
                
                Text {
                    text: root.sessionName
                    color: "#ffffff"
                    font.pixelSize: 36
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "ID: " + root.sessionId
                    color: "#888888"
                    font.pixelSize: 18
                    font.family: "Consolas, Monaco, monospace"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
            
            // StatusIndicator (droite)
            StatusIndicator {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                isOnline: true
                ping: 42
            }
        }
        
        // INFO PANEL INTÉGRÉ
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: "#252525"
            radius: 10
            border.color: "#333333"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                
                // Statut de la session
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: statusText.width + 24
                    Layout.preferredHeight: 32
                    radius: 16
                    color: root.players < root.maxPlayers ? "#4caf50" : "#ff9800"
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        
                        Text {
                            text: root.players < root.maxPlayers ? "⏳" : "✋"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            id: statusText
                            text: root.players < root.maxPlayers ? "En attente de joueurs" : "Session complète"
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#333333"
                }
                
                // Informations de la session
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Row {
                        spacing: 8
                        Text {
                            text: "🗺️ Map:"
                            color: "#888888"
                            font.pixelSize: 14
                        }
                        Text {
                            text: "Classic Meownopoly Board"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    Row {
                        spacing: 8
                        Text {
                            text: "⏱️ Durée:"
                            color: "#888888"
                            font.pixelSize: 14
                        }
                        Text {
                            text: "45-60 minutes"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    Row {
                        spacing: 8
                        Text {
                            text: "🎮 Mode:"
                            color: "#888888"
                            font.pixelSize: 14
                        }
                        Text {
                            text: "Standard"
                            color: "#ffffff"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }
        }
        
        // LISTE DES JOUEURS
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ColumnLayout {
                width: parent.width
                spacing: 16
                
                Text {
                    text: "Joueurs (" + playersModel.count + "/" + root.maxPlayers + ")"
                    color: "#ffffff"
                    font.pixelSize: 22
                    font.bold: true
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    
                    Repeater {
                        model: playersModel
                        
                        PlayerCard {
                            Layout.fillWidth: true
                            nickname: model.nickname
                            avatar: model.avatar
                            isHost: model.isHost
                        }
                    }
                }
            }
        }
        
        // BOUTONS ACTIONS INTÉGRÉS
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            // Bouton secondaire: Retour
            Button {
                text: "Retour à la liste"
                Layout.preferredWidth: 180
                Layout.preferredHeight: 50
                
                background: Rectangle {
                    color: parent.pressed ? "#444444" : "#555555"
                    radius: 8
                    border.color: parent.hovered ? "#777777" : "#666666"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#cccccc"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: root.backRequested()
            }
            
            Item { Layout.fillWidth: true }
            
            // Bouton primaire: Rejoindre
            ParticleButton {
                text: "Rejoindre la Partie"
                Layout.preferredWidth: 220
                Layout.preferredHeight: 50
                
                particleColor: "#7CB518"
                particleColorVariation: "#4caf50"
                particleCount: 30
                
                background: Rectangle {
                    color: parent.down ? "#388e3c" : "#4caf50"
                    radius: 8
                    border.color: parent.hovered ? "#FFFFFF" : "#388e3c"
                    border.width: 2
                    
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                        }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    console.log("Rejoindre la partie:", root.sessionName)
                    root.joinRequested()
                }
            }
        }
    }
}
