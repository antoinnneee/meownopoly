import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MapTypes
import ui_item
import theme

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
        MeowInfoBox {
            Layout.fillWidth: true
            fontSize: Theme.fontSizeCaption
            text: "📦 Configuration de la Boîte en Carton - Case Caisse de Communauté"
        },

        // Section d'information sur le fonctionnement
        MeowInfoBox {
            Layout.fillWidth: true
            variant: "warning"
            title: "🎯 Fonctionnement"
            text: "• Quand un joueur atterrit sur cette case, une carte de la Caisse de Communauté est tirée\n• Les cartes peuvent donner des récompenses, des pénalités ou des actions spéciales\n• C'est un élément de chance qui pimente le jeu"
        },

        // Section de statistiques/informations (layout 2 colonnes custom — tokens Theme)
        Rectangle {
            Layout.fillWidth: true
            height: 70
            color: Theme.infoBg
            radius: Theme.radiusS
            border.color: Theme.infoBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingS

                Text {
                    text: "📊 Informations"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.infoTitle
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXXL

                    Text {
                        text: "Type: Caisse de Communauté"
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.infoText
                    }

                    Text {
                        text: "Action: Tirage de carte"
                        font.pixelSize: Theme.fontSizeTiny
                        color: Theme.infoText
                    }
                }
            }
        },

        // Section de conseils de design
        MeowInfoBox {
            Layout.fillWidth: true
            variant: "tip"
            title: "💡 Conseils de Placement"
            text: "• Placez ces cases de manière équilibrée sur le plateau\n• Alternez avec les cases Chance pour varier l'expérience\n• Évitez de les concentrer dans une seule zone"
        }
    ]
    
    // Functions
    function updateControls() {
        // Pas de propriétés spécifiques à mettre à jour
    }
}

