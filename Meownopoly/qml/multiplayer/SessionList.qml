import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../ui_item"
import Meownopoly.Chat 1.0
import Meownopoly.Account 1.0

/**
 * Vue complète de la liste des sessions disponibles
 * Connectée au serveur chat pour récupérer les sessions réelles
 */
Rectangle {
    id: root
    
    color: "#1a1a1a"
    
    signal sessionSelected(var sessionData)
    
    // Instance ChatClient pour le lobby
    ChatClient {
        id: lobbyChatClient
        sessionId: "lobby_discovery" // Session spéciale pour la découverte
        
        onConnectedChanged: {
            if (connected) {
                console.log("✅ Lobby connected, requesting sessions...")
                lobbyChatClient.requestSessionsList()
                refreshTimer.start()
            } else {
                console.log("❌ Lobby disconnected")
                refreshTimer.stop()
            }
        }
        
        onAvailableSessionsChanged: {
            console.log("📋 Sessions updated:", lobbyChatClient.availableSessions.length)
        }
        
        onErrorOccurred: function(error) {
            console.error("❌ Lobby error:", error)
            errorText.text = "Erreur: " + error
            errorText.visible = true
        }
    }
    
    // Timer de rafraîchissement automatique
    Timer {
        id: refreshTimer
        interval: 5000 // Rafraîchir toutes les 5 secondes
        running: false
        repeat: true
        onTriggered: {
            if (lobbyChatClient.connected) {
                lobbyChatClient.requestSessionsList()
            }
        }
    }
    
    Component.onCompleted: {
        console.log("🚀 SessionList loaded, connecting to server...")
        // Se connecter au serveur
        lobbyChatClient.connectToServer(
            "ws://pattounecorp.ovh:3000",
            AccountManager.uniqueId,
            "123", // Mot de passe pour le lobby
            AccountManager.nickname
        )
    }
    
    Component.onDestruction: {
        refreshTimer.stop()
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
                text: lobbyChatClient.connected ? 
                    ("🐱 " + lobbyChatClient.availableSessions.length + " parties en cours") :
                    "🔌 Connexion au serveur..."
                color: lobbyChatClient.connected ? "#888888" : "#ff9800"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignHCenter
            }
        }
        
        // Message d'erreur
        Text {
            id: errorText
            visible: false
            color: "#f44336"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        // COMPTEUR EN LIGNE INTÉGRÉ
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 40
            color: "#2a2a2a"
            radius: 20
            border.color: lobbyChatClient.connected ? "#4caf50" : "#666666"
            border.width: 2
            
            Row {
                anchors.centerIn: parent
                spacing: 10
                
                Text {
                    text: lobbyChatClient.connected ? "🌐" : "⏳"
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    text: lobbyChatClient.connected ? "Serveur connecté" : "Connexion..."
                    color: lobbyChatClient.connected ? "#4caf50" : "#888888"
                    font.pixelSize: 14
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
        
        // LISTE DES SESSIONS (DONNÉES RÉELLES)
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            // Message si aucune session
            Item {
                width: parent.width
                height: sessionsListView.count === 0 ? 200 : 0
                visible: sessionsListView.count === 0
                
                Column {
                    anchors.centerIn: parent
                    spacing: 16
                    
                    Text {
                        text: lobbyChatClient.connected ? "😿" : "⏳"
                        font.pixelSize: 48
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: lobbyChatClient.connected ? 
                            "Aucune partie disponible pour l'instant" :
                            "Connexion au serveur..."
                        color: "#888888"
                        font.pixelSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "Créez une nouvelle session pour commencer !"
                        color: "#666666"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: lobbyChatClient.connected
                    }
                }
            }
            
            ListView {
                id: sessionsListView
                model: lobbyChatClient.availableSessions // 🎯 DONNÉES RÉELLES !
                spacing: 12
                width: parent.width
                
                delegate: SessionCard {
                    // Les propriétés sont automatiquement liées via required property
                    
                    onClicked: {
                        console.log("Session sélectionnée:", sessionId)
                        root.sessionSelected({
                            name: name,
                            sessionId: sessionId,
                            players: players,
                            maxPlayers: maxPlayers
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
            
            enabled: lobbyChatClient.connected
            
            particleColor: "#E67E22"
            particleColorVariation: "#ff9800"
            particleCount: 25
            
            background: Rectangle {
                color: parent.enabled ? 
                    (parent.down ? "#d35400" : "#E67E22") : "#555555"
                radius: 8
                border.color: parent.enabled ?
                    (parent.hovered ? "#FFFFFF" : "#d35400") : "#666666"
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
                color: parent.enabled ? "white" : "#888888"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                console.log("⚠️ Création de session demandée (pas encore implémenté)")
            }
        }
        
        // HELP TEXT INTÉGRÉ avec bouton refresh
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            
            Text {
                text: "💡 Cliquez sur une session pour rejoindre"
                color: "#666666"
                font.pixelSize: 14
                font.italic: true
                anchors.verticalCenter: parent.verticalCenter
            }
            
            Button {
                text: "🔄"
                width: 32
                height: 32
                
                background: Rectangle {
                    color: parent.pressed ? "#444444" : "#333333"
                    radius: 16
                    border.color: "#555555"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#cccccc"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    if (lobbyChatClient.connected) {
                        lobbyChatClient.requestSessionsList()
                    }
                }
                
                ToolTip {
                    visible: parent.hovered
                    text: "Rafraîchir la liste"
                    delay: 500
                }
            }
        }
    }
}
