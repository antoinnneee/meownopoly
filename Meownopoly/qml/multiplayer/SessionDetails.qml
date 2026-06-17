import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme
import Meownopoly.Chat 1.0
import "../ui_item"
import "./components"

/**
 * Vue complète des détails d'une session
 * Contient: header, infos session, liste joueurs, boutons actions
 */
Rectangle {
    id: root

    color: Theme.background
    
    // Props reçues de la navigation
    required property string sessionName
    required property string sessionId
    required property int players
    required property int maxPlayers
    // ChatClient mutualisé (injecté par le lobby) pour suivre l'état de connexion / ping.
    property ChatClient chatClient: null
    
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
        anchors.margins: Theme.spacingHuge
        spacing: Theme.spacingHuge
        
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
                spacing: Theme.spacingXS

                Text {
                    text: root.sessionName
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeHero
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                Text {
                    text: "ID: " + root.sessionId
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeTitle
                    font.family: "Consolas, Monaco, monospace"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
            
            // StatusIndicator (droite)
            StatusIndicator {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                isOnline: root.chatClient ? root.chatClient.connected : false
                ping: root.chatClient ? root.chatClient.pingMs : -1
            }
        }
        
        // INFO PANEL INTÉGRÉ
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            color: "#252525"
            radius: Theme.radiusXL
            border.color: Theme.surfaceAlt
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingXXL
                spacing: Theme.spacingXL
                
                // Statut de la session
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: statusText.width + 24
                    Layout.preferredHeight: 32
                    radius: 16
                    color: root.players < root.maxPlayers ? Theme.success : Theme.warning

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingS

                        Text {
                            text: root.players < root.maxPlayers ? "⏳" : "✋"
                            font.pixelSize: Theme.fontSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            id: statusText
                            text: root.players < root.maxPlayers ? "En attente de joueurs" : "Session complète"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeBody
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                
                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.surfaceAlt
                }

                // Informations de la session
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    
                    Row {
                        spacing: Theme.spacingM
                        Text {
                            text: "🗺️ Map:"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeMedium
                        }
                        Text {
                            text: "Classic Meownopoly Board"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                        }
                    }
                    
                    Row {
                        spacing: Theme.spacingM
                        Text {
                            text: "⏱️ Durée:"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeMedium
                        }
                        Text {
                            text: "45-60 minutes"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                        }
                    }
                    
                    Row {
                        spacing: Theme.spacingM
                        Text {
                            text: "🎮 Mode:"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeMedium
                        }
                        Text {
                            text: "Standard"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeMedium
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
                spacing: Theme.spacingXXL

                Text {
                    text: "Joueurs (" + playersModel.count + "/" + root.maxPlayers + ")"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeHeading
                    font.bold: true
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXL
                    
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
            spacing: Theme.spacingXXL

            // Bouton secondaire: Retour
            Button {
                text: "Retour à la liste"
                Layout.preferredWidth: 180
                Layout.preferredHeight: 50
                
                background: Rectangle {
                    color: parent.pressed ? Theme.pressed(Theme.borderLight) : Theme.borderLight
                    radius: Theme.radiusL
                    border.color: parent.hovered ? Theme.hover(Theme.textDisabled) : Theme.textDisabled
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeMedium
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

                // Style unifié via MeowButton (variant succès).
                variant: "success"

                particleColor: "#7CB518"
                particleColorVariation: Theme.success
                particleCount: 30

                onClicked: {
                    console.log("Rejoindre la partie:", root.sessionName)
                    root.joinRequested()
                }
            }
        }
    }
}
