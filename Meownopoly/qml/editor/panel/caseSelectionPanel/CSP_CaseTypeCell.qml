import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import "../editorBottomPanel"

Item {
    id: root
    
    // Propriétés
    property int caseType: 0
    property bool isSelected: false
    property string caseName: ""
    property string caseIcon: ""
    property color caseColor: "#E0E0E0"

    // Signaux
    signal clicked(int type)
    signal hovered(bool hovered)
    
    // Dimensions
    width: 80
    height: 80
    
    // Rectangle principal
    Rectangle {
        id: cellBackground
        anchors.fill: parent
        radius: 8
        color: {
            if (root.isSelected) return "#4CAF50"
            else if (mouseArea.containsMouse) return "#E8F5E8"
            else return "#F5F5F5"
        }
        border.color: {
            if (root.isSelected) return "#2E7D32"
            else if (mouseArea.containsMouse) return "#4CAF50"
            else return "#E0E0E0"
        }
        border.width: 2
        
        // Animation de sélection
        Behavior on color {
            ColorAnimation { duration: 200 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }
    }
    
    // Icône de la case
    Rectangle {
        id: iconContainer
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: 20
        color: root.caseColor
        
        // Icône temporaire (à remplacer par de vraies icônes)
        Text {
            anchors.centerIn: parent
            text: {
                switch(root.caseType) {
                    case 0: return "🏁"  // Départ
                    case 1: return "🏠"  // Propriétés
                    case 2: return "📦"  // Caisse de Communauté
                    case 3: return "🎲"  // Chance
                    case 4: return "🔒"  // Prison (Visite)
                    case 5: return "⬆️"  // Allez en Prison
                    case 6: return "🚂"  // Gares
                    case 7: return "🆓"  // Parc Gratuit
                    case 8: return "⚡"  // Compagnies
                    case 9: return "💰"  // Taxes
                    default: return "❓"
                }
            }
            font.pixelSize: 20
        }
    }
    
    // Nom de la case
    Text {
        id: caseNameText
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 4
        text: root.caseName
        font.pixelSize: 10
        font.bold: root.isSelected
        color: root.isSelected ? "white" : "#333333"
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    
    // Indicateur de sélection
    Rectangle {
        id: selectionIndicator
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        width: 16
        height: 16
        radius: 8
        color: "#4CAF50"
        visible: root.isSelected
        
        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "white"
            font.pixelSize: 12
            font.bold: true
        }
        
        // Animation d'apparition
        scale: root.isSelected ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
        }
    }
    
    // Zone de clic
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            root.clicked(root.caseType)
        }
        
        onEntered: {
            root.hovered(true)
        }
        
        onExited: {
            root.hovered(false)
        }
    }
    
    // Tooltip
    ToolTip {
        id: tooltip
        visible: mouseArea.containsMouse
        text: root.caseName + " (Type " + root.caseType + ")"
        delay: 500
    }
}
