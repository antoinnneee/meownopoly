import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case

ConfigPanelElement {
    title: "Configuration Cardboard Box"
    visible: targetCase && targetCase.type === Case.CS_CardBoardBox

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        
        // Pour l'instant, pas de propriétés spécifiques à mettre à jour
        // Le CardBoardBox n'a que les propriétés de base de Case
    }

    property bool updatingValues: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        // Note explicative
        Text {
            text: "📦 Configuration de la Boîte en Carton - Case Caisse de Communauté"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Section d'information sur le fonctionnement
        Rectangle {
            Layout.fillWidth: true
            height: 120
            color: "#fff3cd"
            radius: 6
            border.color: "#ffeaa7"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "🎯 Fonctionnement"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#856404"
                }
                
                Text {
                    text: "• Quand un joueur atterrit sur cette case, une carte de la Caisse de Communauté est tirée\n• Les cartes peuvent donner des récompenses, des pénalités ou des actions spéciales\n• C'est un élément de chance qui pimente le jeu"
                    font.pixelSize: 11
                    color: "#856404"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Section de statistiques/informations
        Rectangle {
            Layout.fillWidth: true
            height: 80
            color: "#d1ecf1"
            radius: 6
            border.color: "#bee5eb"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "📊 Informations"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#0c5460"
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    
                    Text {
                        text: "Type: Caisse de Communauté"
                        font.pixelSize: 11
                        color: "#0c5460"
                    }
                    
                    Text {
                        text: "Action: Tirage de carte"
                        font.pixelSize: 11
                        color: "#0c5460"
                    }
                }
            }
        }
        
        // Section de conseils de design
        Rectangle {
            Layout.fillWidth: true
            height: 100
            color: "#d4edda"
            radius: 6
            border.color: "#c3e6cb"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "💡 Conseils de Placement"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#155724"
                }
                
                Text {
                    text: "• Placez ces cases de manière équilibrée sur le plateau\n• Alternez avec les cases Chance pour varier l'expérience\n• Évitez de les concentrer dans une seule zone"
                    font.pixelSize: 11
                    color: "#155724"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Section de personnalisation future
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#f8f9fa"
            radius: 6
            border.color: "#dee2e6"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 5
                
                Text {
                    text: "🔧 Personnalisation Future"
                    font.bold: true
                    font.pixelSize: 12
                    color: "#495057"
                }
                
                Text {
                    text: "Dans une version future, vous pourrez personnaliser le jeu de cartes associé à cette case."
                    font.pixelSize: 10
                    color: "#6c757d"
                    font.italic: true
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        Item { Layout.fillHeight: true } // Spacer vertical
    }
}