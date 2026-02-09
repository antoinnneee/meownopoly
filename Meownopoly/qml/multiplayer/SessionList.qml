import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui_item"

/**
 * Vue complète de la liste des sessions disponibles
 * Contient: header, compteur joueurs, liste, bouton création, help text
 */
Rectangle {
    id: root
    
    color: "#1a1a1a"
    
    signal sessionSelected(var sessionData)

    // Modèle de données factices (5 sessions)
    ListModel {
        id: sessionsModel
        ListElement {
            name: "Partie de Minuit 🌙"
            sessionId: "MSN-2847"
            players: 2
            maxPlayers: 4
        }
        ListElement {
            name: "Les Chats Royaux"
            sessionId: "RYL-5612"
            players: 3
            maxPlayers: 4
        }
        ListElement {
            name: "Patte de Velours"
            sessionId: "VLV-8923"
            players: 1
            maxPlayers: 4
        }
        ListElement {
            name: "Ronron Express"
            sessionId: "RNR-3456"
            players: 4
            maxPlayers: 4
        }
        ListElement {
            name: "Griffes & Stratégie"
            sessionId: "GRF-7891"
            players: 2
            maxPlayers: 6
        }
    }


    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        
        // HEADER INTÉGRÉ
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            
            Text {
                text: "Sessions Disponibles"
                color: "#ffffff"
                font.pixelSize: 28
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            
            Text {
                text: "🐱 " + sessionsModel.count + " parties en cours"
                color: "#888888"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
        }
        
        // COMPTEUR EN LIGNE INTÉGRÉ
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 40
            color: "#2a2a2a"
            radius: 20
            border.color: "#4caf50"
            border.width: 2
            
            Row {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: "🌐"
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: "127 joueurs en ligne"
                    color: "#4caf50"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        
        // LISTE DES SESSIONS
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ListView {
                id: sessionsListView
                model: sessionsModel
                spacing: 12
                
                delegate: SessionCard {
                    name: model.name
                    sessionId: model.sessionId
                    players: model.players
                    maxPlayers: model.maxPlayers
                    
                    onClicked: {
                        root.sessionSelected({
                            name: model.name,
                            sessionId: model.sessionId,
                            players: model.players,
                            maxPlayers: model.maxPlayers
                        })
                    }
                }
            }
        }
        
        // BOUTON CRÉATION (ParticleButton direct)
        ParticleButton {
            text: "➕ Créer une Session"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 55
            
            particleColor: "#E67E22"
            particleColorVariation: "#ff9800"
            particleCount: 25
            
            background: Rectangle {
                color: parent.down ? "#d35400" : "#E67E22"
                radius: 8
                border.color: parent.hovered ? "#FFFFFF" : "#d35400"
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
                console.log("Création de session demandée (pas encore implémenté)")
            }
        }
        
        // HELP TEXT INTÉGRÉ
        Text {
            text: "💡 Cliquez sur une session pour rejoindre"
            color: "#666666"
            font.pixelSize: 14
            font.italic: true
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
