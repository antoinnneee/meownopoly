import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
    title: "Configuration Famille"
    property alias familyIndex: familyComboBox.currentIndex

    visible: targetCase && targetCase.type === Case.CS_RestArea

    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        function onFamilyChanged() {
            if (!updatingValues) {
                updatingValues = true
                familyComboBox.currentIndex = findFamilyIndex(targetCase.family)
                updatingValues = false
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        
        // Note explicative
        Text {
            text: "🏠 Configuration de la famille de propriété"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }
        
        // Famille/Couleur
        RowLayout {
            Layout.fillWidth: true
            
            Label {
                text: "Famille:"
                font.bold: true
                Layout.preferredWidth: 80
            }
            
            ComboBox {
                id: familyComboBox
                Layout.fillWidth: true
                
                model: [
                    { value: CaseRestArea.FT_NONE, textValue: "Aucune", color: "#ecf0f1" },
                    { value: CaseRestArea.FT_BROWN, textValue: "Marron", color: "#795548" },
                    { value: CaseRestArea.FT_LIGHTBLUE, textValue: "Bleu Clair", color: "#81D4FA" },
                    { value: CaseRestArea.FT_PINK, textValue: "Rose", color: "#F48FB1" },
                    { value: CaseRestArea.FT_ORANGE, textValue: "Orange", color: "#FF9800" },
                    { value: CaseRestArea.FT_RED, textValue: "Rouge", color: "#e74c3c" },
                    { value: CaseRestArea.FT_YELLOW, textValue: "Jaune", color: "#F9E155" },
                    { value: CaseRestArea.FT_GREEN, textValue: "Vert", color: "#66BB6A" },
                    { value: CaseRestArea.FT_DARKBLUE, textValue: "Bleu Foncé", color: "#006064" }
                ]
                
                textRole: "textValue"
                valueRole: "value"
                
                Component.onCompleted: {
                    if (targetCase) {
                        currentIndex = findFamilyIndex(targetCase.family)
                    }
                }
                
                onCurrentValueChanged: {
                    if (!updatingValues && targetCase && currentValue !== undefined) {
                        targetCase.family = currentValue
                    }
                }

                
                // Delegate personnalisé avec couleurs
                delegate: ItemDelegate {
                    id: delegate
                    width: familyComboBox.width
                    height: 40
                    required property color color
                    required property int index
                    required property string textValue
                    
                    contentItem: Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: 24
                            height: 24
                            color: delegate.color
                            border.color: "#333333"
                            border.width: 1
                            radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: delegate.textValue
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14
                            color: "#333333"
                        }
                    }
                    
                    highlighted: familyComboBox.highlightedIndex === index
                    
                    background: Rectangle {
                        color: highlighted ? "#e3f2fd" : "transparent"
                        radius: 2
                    }
                }
                
                // Contenu affiché dans la ComboBox fermée
                contentItem: Row {
                    spacing: 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: familyComboBox.currentIndex >= 0 ? familyComboBox.model[familyComboBox.currentIndex].color : "#ecf0f1"
                        border.color: "#333333"
                        border.width: 1
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: familyComboBox.displayText
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 14
                        color: "#333333"
                    }
                }
            }
        }
    }

    // Fonction utilitaire pour trouver l'index de la famille
    function findFamilyIndex(familyValue) {
        const families = [
            CaseRestArea.FT_NONE, CaseRestArea.FT_BROWN, CaseRestArea.FT_LIGHTBLUE,
            CaseRestArea.FT_PINK, CaseRestArea.FT_ORANGE, CaseRestArea.FT_RED,
            CaseRestArea.FT_YELLOW, CaseRestArea.FT_GREEN, CaseRestArea.FT_DARKBLUE
        ]
        return families.indexOf(familyValue)
    }
}
