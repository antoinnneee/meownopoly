import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game

Dialog {
    id: testDialog
    title: "TEST_VIEW_3 - Menu de création de joueurs"
    width: 750
    height: 500
    modal: true
    
    // Modèle de données pour les joueurs
    ListModel {
        id: playersModel
        
        Component.onCompleted: {
            // Ajouter un premier joueur par défaut
            append({
                "name": "",
                "color": "#ff6b6b",
                "iconIndex": 0,
                "playerId": 0
            })
        }
    }
    
    // Couleurs disponibles pour les joueurs
    property var availableColors: [
        "#ff6b6b", "#4ecdc4", "#45b7d1", "#f9ca24", 
        "#6c5ce7", "#a29bfe", "#fd79a8", "#00b894"
    ]
    
    // Icônes disponibles pour les joueurs (générées automatiquement)
    property var availableIcons: generateAvatarList()
    
    // Fonction pour générer automatiquement la liste des avatars
    function generateAvatarList() {
        var avatars = []
        // Parcourir les avatars de 1 à 6 (ou plus si nécessaire)
        for (var i = 1; i <= 6; i++) {
            avatars.push("qrc:/asset/avatar/avatar" + i + ".png")
        }
        return avatars
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Zone de scrolling pour les joueurs
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Column {
                id: playersColumn
                width: parent.width
                spacing: 10
                
                // Répéteur pour créer les rectangles de joueurs
                Repeater {
                    model: playersModel
                    
                    Rectangle {
                        id: playerRow
                        width: parent.width
                        height: 100
                        
                        color: "#ffffff"
                        border.color: "#cccccc"
                        border.width: 1
                        radius: 8
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            // Champ texte à gauche
                            TextField {
                                id: playerNameField
                                Layout.fillWidth: true
                                Layout.preferredHeight: 80
                                
                                text: model.name
                                placeholderText: "Nom du joueur " + (index + 1)
                                selectByMouse: true
                                
                                onTextChanged: {
                                    playersModel.setProperty(index, "name", text)
                                }
                                
                                background: Rectangle {
                                    color: "#ffffff"
                                    border.color: "#cccccc"
                                    border.width: 1
                                    radius: 4
                                }
                            }
                            
                            // Sélecteur d'icônes
                            Rectangle {
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 80
                                color: "#ffffff"
                                border.color: "#cccccc"
                                border.width: 1
                                radius: 4
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    spacing: 2
                                    
                                    // Flèche gauche
                                    Button {
                                        id: leftArrowButton
                                        Layout.preferredWidth: 35
                                        Layout.preferredHeight: parent.height
                                        
                                        background: Rectangle {
                                            color: leftArrowButton.pressed ? "#e0e0e0" : "transparent"
                                            radius: 2
                                        }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "◀"
                                            color: "#666666"
                                            font.pixelSize: 20
                                        }
                                        
                                        onClicked: {
                                            var newIndex = (model.iconIndex - 1 + availableIcons.length) % availableIcons.length
                                            playersModel.setProperty(index, "iconIndex", newIndex)
                                        }
                                    }
                                    
                                    // Image de l'icône sélectionnée
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        
                                        Image {
                                            anchors.centerIn: parent
                                            width: Math.min(parent.width, parent.height) - 4
                                            height: width
                                            source: availableIcons[model.iconIndex]
                                            sourceSize.width: width
                                            sourceSize.height: height
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                        }
                                    }
                                    
                                    // Flèche droite
                                    Button {
                                        id: rightArrowButton
                                        Layout.preferredWidth: 35
                                        Layout.preferredHeight: parent.height
                                        
                                        background: Rectangle {
                                            color: rightArrowButton.pressed ? "#e0e0e0" : "transparent"
                                            radius: 2
                                        }
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: "▶"
                                            color: "#666666"
                                            font.pixelSize: 20
                                        }
                                        
                                        onClicked: {
                                            var newIndex = (model.iconIndex + 1) % availableIcons.length
                                            playersModel.setProperty(index, "iconIndex", newIndex)
                                        }
                                    }
                                }
                            }
                            
                            // Bouton carré pour la sélection de couleur
                            Button {
                                id: colorButton
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 80
                                
                                background: Rectangle {
                                    color: colorButton.pressed ? "#e0e0e0" : "#ffffff"
                                    border.color: "#cccccc"
                                    border.width: 1
                                    radius: 4
                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width - 10
                                        height: parent.height - 10
                                        color: model.color
                                        border.color: "#888888"
                                        border.width: 1
                                        radius: 2
                                    }
                                }
                                
                                onClicked: colorMenu.open()
                                
                                // Menu déroulant pour les couleurs
                                Menu {
                                    id: colorMenu
                                    
                                    Repeater {
                                        model: availableColors
                                        
                                        MenuItem {
                                            Rectangle {
                                                width: 30
                                                height: 30
                                                color: modelData
                                                border.color: "#888888"
                                                border.width: 1
                                                radius: 2
                                            }
                                            onClicked: {
                                                playersModel.setProperty(index, "color", modelData)
                                                colorMenu.close()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Croix rouge pour supprimer
                            Button {
                                id: deleteButton
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 80
                                
                                background: Rectangle {
                                    color: deleteButton.pressed ? "#ffcccc" : "#ffffff"
                                    border.color: "#ff6666"
                                    border.width: 1
                                    radius: 4
                                }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: "#ff3333"
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                                
                                onClicked: {
                                    if (playersModel.count > 1) {
                                        playersModel.remove(index)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Placeholder si pas de joueurs (ne devrait pas arriver)
                Rectangle {
                    width: parent.width
                    height: 100
                    color: "#f8f9fa"
                    border.color: "#dee2e6"
                    border.width: 1
                    radius: 8
                    opacity: 0.7
                    visible: playersModel.count === 0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Aucun joueur créé"
                        color: "#6c757d"
                        font.italic: true
                    }
                }
            }
        }
        
        // Barre de navigation en bas
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: "#f8f9fa"
            border.color: "#dee2e6"
            border.width: 1
            radius: 8
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                
                // Bouton retour à gauche
                Button {
                    id: backButton
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: backButton.pressed ? "#dc3545" : "#f8f9fa"
                        border.color: "#dc3545"
                        border.width: 2
                        radius: 6
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        
                        Text {
                            text: "◀"
                            color: "#dc3545"
                            font.pixelSize: 14
                            font.bold: true
                        }
                        
                        Text {
                            text: "Retour"
                            color: "#dc3545"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    onClicked: {
                        testDialog.close()
                    }
                }
                
                // Espace flexible au milieu
                Item {
                    Layout.fillWidth: true
                }
                
                // Bouton ajouter joueur
                Button {
                    id: addPlayerButtonBottom
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: addPlayerButtonBottom.pressed ? "#218838" : "#28a745"
                        border.color: "#1e7e34"
                        border.width: 1
                        radius: 6
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        
                        Text {
                            text: "➕"
                            color: "white"
                            font.pixelSize: 14
                        }
                        
                        Text {
                            text: "Ajouter"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    
                    onClicked: {
                        // Choisir une couleur différente pour le nouveau joueur
                        var newColor = availableColors[playersModel.count % availableColors.length]
                        // Choisir une icône différente pour le nouveau joueur
                        var newIconIndex = playersModel.count % availableIcons.length
                        
                        // Ajouter un nouveau joueur au modèle
                        playersModel.append({
                            "name": "",
                            "color": newColor,
                            "iconIndex": newIconIndex,
                            "playerId": playersModel.count
                        })
                        
                        console.log("Nouveau joueur ajouté, total:", playersModel.count)
                    }
                }
                
                // Bouton valider
                Button {
                    id: validateButton
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    
                    background: Rectangle {
                        color: validateButton.pressed ? "#0056b3" : "#007bff"
                        border.color: "#0056b3"
                        border.width: 1
                        radius: 6
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✓ Valider"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    
                    onClicked: {
                        // Logique de validation - afficher les joueurs créés
                        console.log("Validation des joueurs:")
                        for (var i = 0; i < playersModel.count; i++) {
                            var player = playersModel.get(i)
                            console.log("Joueur " + (i + 1) + ":", player.name, player.color, "Avatar index:", player.iconIndex)
                        }
                        testDialog.close()
                    }
                }
            }
        }
    }
    
    standardButtons: Dialog.Close
} 
