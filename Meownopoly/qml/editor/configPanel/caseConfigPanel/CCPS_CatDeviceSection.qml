import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MapTypes
import ui_item
import theme

CollapsableGroupBox {
    id: control
    title: "Configuration Cat Device"
    
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
    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onTaxeChanged() {
            if (!updatingValues) {
                updateControls()
            }
        }
    }
    
    content: [
        // Note explicative
        Text {
            text: "🔌 Configuration de l'Appareil Électronique - Service public achetable"
            font.italic: true
            font.pixelSize: Theme.fontSizeCaption
            color: Theme.textMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        },
        
        // Configuration des prix CaseCatPerks (héritée)
        CCP_CatPerksConfig {
            id: caseCatPerksConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        },
        
        // Configuration spécifique au Device - Taxe d'utilisation
        Rectangle {
            Layout.fillWidth: true
            color: Theme.surface
            radius: Theme.radiusXS
            border.color: Theme.border
            border.width: 1
            height: taxeLayout.implicitHeight + 20
            
            ColumnLayout {
                id: taxeLayout
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM
                
                Text {
                    text: "⚡ Configuration du Service"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.infoTitle
                }
                
                Text {
                    text: "Configurez la taxe d'utilisation que les autres joueurs devront payer"
                    font.italic: true
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingM
                    
                    Text {
                        text: "💡 Taxe d'utilisation:"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        Layout.minimumWidth: 130
                    }
                    
                    SpinBox {
                        id: taxeSpinBox
                        from: 0
                        to: 999
                        stepSize: 10
                        value: 50
                        
                        Layout.preferredWidth: 110
                        
                        textFromValue: function(value, locale) {
                            return value + "K"
                        }
                        
                        valueFromText: function(text, locale) {
                            return parseInt(text.replace("K", ""))
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase) {
                                targetCase.taxe = value
                                configurationChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: Theme.background
                            border.color: Theme.borderLight
                            border.width: 1
                            radius: Theme.radiusXS
                        }
                        
                        contentItem: TextInput {
                            text: taxeSpinBox.textFromValue(taxeSpinBox.value, taxeSpinBox.locale)
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textPrimary
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !taxeSpinBox.editable
                            validator: taxeSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                    
                    Text {
                        text: "kibbles"
                        font.pixelSize: Theme.fontSizeCaption
                        color: Theme.textMuted
                    }
                    
                    Item { Layout.fillWidth: true }
                }
            }
        },
        // Section d'information sur le fonctionnement
        Rectangle {
            Layout.fillWidth: true
            height: 90
            color: Theme.infoBg
            radius: Theme.radiusS
            border.color: Theme.infoBorder
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingS
                
                Text {
                    text: "🔍 Fonctionnement"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.infoTitle
                }
                
                Text {
                    text: "• Les joueurs peuvent acheter cet appareil électronique\n• Quand un autre joueur atterrit dessus, il paie la taxe d'utilisation au propriétaire\n• Plus vous possédez d'appareils du même type, plus les revenus augmentent"
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.infoText
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        },
        
        // Section de conseils économiques
        Rectangle {
            Layout.fillWidth: true
            height: 70
            color: Theme.tipBg
            radius: Theme.radiusS
            border.color: Theme.tipBorder
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingS
                
                Text {
                    text: "💰 Conseil Économique"
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.tipTitle
                }
                
                Text {
                    text: "Équilibrez le prix d'achat avec la taxe d'utilisation pour créer un investissement attractif mais pas trop puissant."
                    font.pixelSize: Theme.fontSizeTiny
                    color: Theme.tipText
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    ]
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        
        caseCatPerksConfig.updateControls()
        
        // Mettre à jour la taxe
        taxeSpinBox.value = targetCase.taxe || 50
    }
}

