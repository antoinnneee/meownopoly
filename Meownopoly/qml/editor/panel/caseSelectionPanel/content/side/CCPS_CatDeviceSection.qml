import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import "caseConfigPanel"

GroupBox {
    id: control
    title: "Configuration Cat Device"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    
    // Signals
    signal configurationChanged()
    
    // Visual styling
    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }
    
    label: Text {
        x: control.leftPadding
        width: control.availableWidth
        text: control.title
        color: "#cccccc"
        elide: Text.ElideRight
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
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // Note explicative
        Text {
            text: "🔌 Configuration de l'Appareil Électronique - Service public achetable"
            font.italic: true
            font.pixelSize: 10
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Configuration des prix CaseCatPerks (héritée)
        CCP_CatPerksConfig {
            id: caseCatPerksConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        }
        
        // Configuration spécifique au Device - Taxe d'utilisation
        Rectangle {
            Layout.fillWidth: true
            color: "#2a2a2a"
            radius: 3
            border.color: "#444444"
            border.width: 1
            height: taxeLayout.implicitHeight + 20
            
            ColumnLayout {
                id: taxeLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                
                Text {
                    text: "⚡ Configuration du Service"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#99f0f0"
                }
                
                Text {
                    text: "Configurez la taxe d'utilisation que les autres joueurs devront payer"
                    font.italic: true
                    font.pixelSize: 9
                    color: "#888888"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Text {
                        text: "💡 Taxe d'utilisation:"
                        color: "#cccccc"
                        font.pixelSize: 11
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
                            color: "#1a1a1a"
                            border.color: "#555555"
                            border.width: 1
                            radius: 3
                        }
                        
                        contentItem: TextInput {
                            text: taxeSpinBox.textFromValue(taxeSpinBox.value, taxeSpinBox.locale)
                            font.pixelSize: 11
                            color: "#ffffff"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !taxeSpinBox.editable
                            validator: taxeSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }
                    
                    Text {
                        text: "kibbles"
                        font.pixelSize: 10
                        color: "#888888"
                    }
                    
                    Item { Layout.fillWidth: true }
                }
            }
        }
        
        // Section d'information sur le fonctionnement
        Rectangle {
            Layout.fillWidth: true
            height: 90
            color: "#1a2a3a"
            radius: 4
            border.color: "#2a3a4a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                
                Text {
                    text: "🔍 Fonctionnement"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#99ccff"
                }
                
                Text {
                    text: "• Les joueurs peuvent acheter cet appareil électronique\n• Quand un autre joueur atterrit dessus, il paie la taxe d'utilisation au propriétaire\n• Plus vous possédez d'appareils du même type, plus les revenus augmentent"
                    font.pixelSize: 9
                    color: "#80b3d9"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
        
        // Section de conseils économiques
        Rectangle {
            Layout.fillWidth: true
            height: 70
            color: "#1a3a3a"
            radius: 4
            border.color: "#2a4a4a"
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6
                
                Text {
                    text: "💰 Conseil Économique"
                    font.bold: true
                    font.pixelSize: 11
                    color: "#99f0d9"
                }
                
                Text {
                    text: "Équilibrez le prix d'achat avec la taxe d'utilisation pour créer un investissement attractif mais pas trop puissant."
                    font.pixelSize: 9
                    color: "#80d9c0"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        
        caseCatPerksConfig.updateControls()
        
        // Mettre à jour la taxe
        taxeSpinBox.value = targetCase.taxe || 50
    }
}

