import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case

CCP_PanelElement {
    title: "Configuration Cat Device"
    visible: targetCase && targetCase.type === Case.CS_Device

    property alias caseCatPerksConfig: caseCatPerksConfig

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        caseCatPerksConfig.updateControls()
        updateDeviceSpecificControls()
    }
    
    // Fonction pour mettre à jour les contrôles spécifiques au Device
    function updateDeviceSpecificControls() {
        if (!targetCase) return
        
        updatingValues = true
        taxeSpinBox.value = targetCase.taxe || 0
        updatingValues = false
    }
    
    property bool updatingValues: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 15
        
        // Note explicative
        Text {
            text: "🔌 Configuration de l'Appareil Électronique - Service public achetable"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Configuration des prix CaseCatPerks (héritée)
        CCP_CatPerksConfig {
            id: caseCatPerksConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }

        // Configuration spécifique au Device - Taxe d'utilisation
        GroupBox {
            title: "⚡ Configuration du Service"
            Layout.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                Text {
                    text: "Configurez la taxe d'utilisation que les autres joueurs devront payer"
                    font.italic: true
                    font.pixelSize: 11
                    color: "#6c757d"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    
                    Label {
                        text: "💡 Taxe d'utilisation:"
                        font.bold: true
                        font.pixelSize: 14
                        Layout.minimumWidth: 150
                    }
                    
                    SpinBox {
                        id: taxeSpinBox
                        from: 0
                        to: 999
                        stepSize: 10
                        value: 50
                        
                        Layout.preferredWidth: 120
                        
                        textFromValue: function(value, locale) {
                            return value + "K"
                        }
                        
                        valueFromText: function(text, locale) {
                            return parseInt(text.replace("K", ""))
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase) {
                                targetCase.taxe = value
                            }
                        }
                        
                        // Style personnalisé
                        background: Rectangle {
                            color: "#ffffff"
                            border.color: "#ced4da"
                            border.width: 1
                            radius: 4
                        }
                        
                        contentItem: TextInput {
                            text: taxeSpinBox.textFromValue(taxeSpinBox.value, taxeSpinBox.locale)
                            font.pixelSize: 14
                            color: "#495057"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !taxeSpinBox.editable
                            validator: taxeSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                    
                    Text {
                        text: "kibbles"
                        font.pixelSize: 12
                        color: "#6c757d"
                    }
                    
                    Item { Layout.fillWidth: true } // Spacer
                }
            }
        }
        
        // Section d'information sur le fonctionnement
        Rectangle {
            Layout.fillWidth: true
            height: 100
            color: "#e7f3ff"
            radius: 6
            border.color: "#b3d9ff"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "🔍 Fonctionnement"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#004085"
                }
                
                Text {
                    text: "• Les joueurs peuvent acheter cet appareil électronique\n• Quand un autre joueur atterrit dessus, il paie la taxe d'utilisation au propriétaire\n• Plus vous possédez d'appareils du même type, plus les revenus augmentent"
                    font.pixelSize: 11
                    color: "#004085"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Section de conseils économiques
        Rectangle {
            Layout.fillWidth: true
            height: 80
            color: "#d1f2eb"
            radius: 6
            border.color: "#a3e4d7"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 8
                
                Text {
                    text: "💰 Conseil Économique"
                    font.bold: true
                    font.pixelSize: 13
                    color: "#00695c"
                }
                
                Text {
                    text: "Équilibrez le prix d'achat avec la taxe d'utilisation pour créer un investissement attractif mais pas trop puissant."
                    font.pixelSize: 11
                    color: "#00695c"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        Item { Layout.fillHeight: true } // Spacer vertical
    }
}
