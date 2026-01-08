import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MapTypes
import ui_item

CollapsableGroupBox {
    id: control
    title: "Configuration CardBoard Box"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    property var logic: null  // Référence au logic pour sauvegarder
    
    // Signals
    signal configurationChanged()
    
    onConfigurationChanged: {
        if (logic) {
            logic.saveMap(MapTypes.UNDOREDO)
        }
    }

    
    content: [
        // Note explicative
        Text {
            text: "📦 Configuration de la Boîte en Carton - Case Caisse de Communauté"
            font.italic: true
            font.pixelSize: 10
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        },
        
        // Section d'information sur le fonctionnement
        Rectangle {
            Layout.fillWidth: true
            height: 110
            color: "#3a3a1a"
            radius: 4
            border.color: "#4a4a2a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                
                Text {
                    text: "🎯 Fonctionnement"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#ffeb99"
                }
                
                Text {
                    text: "• Quand un joueur atterrit sur cette case, une carte de la Caisse de Communauté est tirée\n• Les cartes peuvent donner des récompenses, des pénalités ou des actions spéciales\n• C'est un élément de chance qui pimente le jeu"
                    font.pixelSize: 9
                    color: "#d4c894"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        },
        
        // Section de statistiques/informations
        Rectangle {
            Layout.fillWidth: true
            height: 70
            color: "#1a2e3a"
            radius: 4
            border.color: "#2a3e4a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                
                Text {
                    text: "📊 Informations"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#99d6f0"
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 15
                    
                    Text {
                        text: "Type: Caisse de Communauté"
                        font.pixelSize: 9
                        color: "#80c1d9"
                    }
                    
                    Text {
                        text: "Action: Tirage de carte"
                        font.pixelSize: 9
                        color: "#80c1d9"
                    }
                }
            }
        },
        
        // Section de conseils de design
        Rectangle {
            Layout.fillWidth: true
            height: 85
            color: "#1a3a2a"
            radius: 4
            border.color: "#2a4a3a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                
                Text {
                    text: "💡 Conseils de Placement"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#99f0c0"
                }
                
                Text {
                    text: "• Placez ces cases de manière équilibrée sur le plateau\n• Alternez avec les cases Chance pour varier l'expérience\n• Évitez de les concentrer dans une seule zone"
                    font.pixelSize: 9
                    color: "#80d9a8"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    ]
    
    // Functions
    function updateControls() {
        // Pas de propriétés spécifiques à mettre à jour
    }
}

