import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

/**
 * Panneau pour créer et gérer les zones d'exclusion
 */
Rectangle {
    id: root
    color: "#2a2a2a"
    
    required property var logic
    
    // Signal émis quand on active le mode dessin
    signal drawModeActivated()
    signal drawModeDeactivated()
    
    // Propriété pour suivre si le mode dessin est actif
    property bool isDrawModeActive: logic && logic.editorMouseMode === EditorEnum.EM_DRAW_POLYGON
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        // Titre
        Text {
            text: "Zones d'exclusion"
            font.pixelSize: 18
            font.bold: true
            color: "white"
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Description
        Text {
            text: "Les zones d'exclusion empêchent l'accès à certaines parties du plateau.\nElles sont visibles uniquement en mode édition."
            font.pixelSize: 12
            color: "#aaaaaa"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }
        
        // Instructions
        Text {
            visible: root.isDrawModeActive
            text: "Mode dessin actif :\n• Clic gauche : ajouter un point\n• Clic droit : terminer le polygone\n• Échap : annuler"
            font.pixelSize: 11
            color: "#ffcc00"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        // Bouton pour activer/désactiver le mode dessin
        Button {
            id: drawButton
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 50
            
            text: root.isDrawModeActive ? "Annuler le dessin" : "Dessiner une zone"
            
            background: Rectangle {
                radius: 8
                color: root.isDrawModeActive ? "#e74c3c" : "#FF5722"
                border.color: root.isDrawModeActive ? "#c0392b" : "#E64A19"
                border.width: 2
                
                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
            
            contentItem: Text {
                text: drawButton.text
                font.pixelSize: 14
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                if (root.isDrawModeActive) {
                    // Désactiver le mode dessin
                    if (logic && logic.mouseLogic) {
                        logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                    }
                    root.drawModeDeactivated()
                } else {
                    // Activer le mode dessin
                    if (logic && logic.mouseLogic) {
                        logic.mouseLogic.changeMouseMode(EditorEnum.EM_DRAW_POLYGON)
                    }
                    root.drawModeActivated()
                }
            }
        }
        
        // Sélecteur de couleur
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            
            Text {
                text: "Couleur :"
                color: "white"
                font.pixelSize: 12
            }
            
            Row {
                spacing: 5
                
                Repeater {
                    model: ["#FF5722", "#E91E63", "#9C27B0", "#3F51B5", "#00BCD4", "#4CAF50", "#FFEB3B"]
                    
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: modelData
                        border.color: colorPicker.selectedColor === modelData ? "white" : "transparent"
                        border.width: 2
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                colorPicker.selectedColor = modelData
                                // Mettre à jour la couleur dans la logique de souris
                                if (logic && logic.mouseLogic && logic.mouseLogic.setZoneColor) {
                                    logic.mouseLogic.setZoneColor(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        QtObject {
            id: colorPicker
            property string selectedColor: "#FF5722"
        }
        
        // Spacer
        Item {
            Layout.fillHeight: true
        }
        
        // Info sur les zones existantes
        Text {
            text: "Conseil : Les zones d'exclusion sont sauvegardées avec la carte et seront chargées lors de l'ouverture."
            font.pixelSize: 10
            color: "#666666"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}

