import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case

CCP_PanelElement {
    title: "Configuration Cardboard Box"
    visible: targetCase && targetCase.type === Case.CS_CardBoardBox

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        
        // Pour l'instant, pas de propriétés spécifiques à mettre à jour
        // Le CardBoardBox n'a que les propriétés de base de Case
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        // Note explicative
        Text {
            text: "📦 Configuration de la Boîte en Carton - Case Caisse de Communauté"
            font.italic: true
            font.pixelSize: 12
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Section d'information sur le fonctionnement
        Rectangle {
            Layout.fillWidth: true
            height: 120
            color: "#3a3a1a"
            radius: 6
            border.color: "#4a4a2a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "🎯 Fonctionnement"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#ffeb99"
                }
                
                Text {
                    text: "• Quand un joueur atterrit sur cette case, une carte de la Caisse de Communauté est tirée\n• Les cartes peuvent donner des récompenses, des pénalités ou des actions spéciales\n• C'est un élément de chance qui pimente le jeu"
                    font.pixelSize: 11
                    color: "#d4c894"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Section de statistiques/informations
        Rectangle {
            Layout.fillWidth: true
            height: 80
            color: "#1a2e3a"
            radius: 6
            border.color: "#2a3e4a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "📊 Informations"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#99d6f0"
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    
                    Text {
                        text: "Type: Caisse de Communauté"
                        font.pixelSize: 11
                        color: "#80c1d9"
                    }
                    
                    Text {
                        text: "Action: Tirage de carte"
                        font.pixelSize: 11
                        color: "#80c1d9"
                    }
                }
            }
        }
        
        // Section de conseils de design
        Rectangle {
            Layout.fillWidth: true
            height: 100
            color: "#1a3a2a"
            radius: 6
            border.color: "#2a4a3a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "💡 Conseils de Placement"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#99f0c0"
                }
                
                Text {
                    text: "• Placez ces cases de manière équilibrée sur le plateau\n• Alternez avec les cases Chance pour varier l'expérience\n• Évitez de les concentrer dans une seule zone"
                    font.pixelSize: 11
                    color: "#80d9a8"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Section de personnalisation future
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#2a2a2a"
            radius: 6
            border.color: "#444444"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 5
                
                Text {
                    text: "🔧 Personnalisation Future"
                    font.bold: true
                    font.pixelSize: 12
                    color: "#cccccc"
                }
                
                Text {
                    text: "Dans une version future, vous pourrez personnaliser le jeu de cartes associé à cette case."
                    font.pixelSize: 10
                    color: "#888888"
                    font.italic: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        Item { Layout.fillHeight: true } // Spacer vertical
    }
}
