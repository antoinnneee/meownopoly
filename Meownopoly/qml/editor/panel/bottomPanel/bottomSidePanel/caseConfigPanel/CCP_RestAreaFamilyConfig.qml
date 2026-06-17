import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player
import MeowStyle
import theme

CCP_PanelElement {
    title: "Configuration Famille"
    property alias familyIndex: familyComboBox.currentIndex

    visible: targetCase && targetCase.type === Case.CS_RestArea

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        updatingValues = true
        familyComboBox.currentIndex = findFamilyIndex(targetCase.family)
        updatingValues = false
    }

    // Mise à jour quand targetCase change
    Connections {
        target: targetCase
        ignoreUnknownSignals: true
        function onFamilyChanged() {
            updateControls()
        }
    }
    ColumnLayout {
        anchors.fill: parent
        // Famille/Couleur
        RowLayout {
            Layout.fillWidth: true
            
            Label {
                text: "Famille:"
                font.bold: true
                Layout.preferredWidth: 80
                color: Theme.textSecondary
            }
            
            ComboBox {
                id: familyComboBox
                Layout.fillWidth: true
                
                model: [
                    { value: CaseRestArea.FT_NONE, textValue: "Aucune", color:  MeowStyle.familyColors[CaseRestArea.FT_NONE]},
                    { value: CaseRestArea.FT_BROWN, textValue: "Marron", color:  MeowStyle.familyColors[CaseRestArea.FT_BROWN]},
                    { value: CaseRestArea.FT_LIGHTBLUE, textValue: "Bleu Clair", color:  MeowStyle.familyColors[CaseRestArea.FT_LIGHTBLUE]},
                    { value: CaseRestArea.FT_PINK, textValue: "Rose", color:  MeowStyle.familyColors[CaseRestArea.FT_PINK]},
                    { value: CaseRestArea.FT_ORANGE, textValue: "Orange", color:  MeowStyle.familyColors[CaseRestArea.FT_ORANGE]},
                    { value: CaseRestArea.FT_RED, textValue: "Rouge", color:  MeowStyle.familyColors[CaseRestArea.FT_RED]},
                    { value: CaseRestArea.FT_YELLOW, textValue: "Jaune", color:  MeowStyle.familyColors[CaseRestArea.FT_YELLOW]},
                    { value: CaseRestArea.FT_GREEN, textValue: "Vert", color:  MeowStyle.familyColors[CaseRestArea.FT_GREEN]},
                    { value: CaseRestArea.FT_DARKBLUE, textValue: "Bleu Foncé", color:  MeowStyle.familyColors[CaseRestArea.FT_DARKBLUE]}
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
                        spacing: Theme.spacingL
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: 24
                            height: 24
                            color: delegate.color
                            border.color: Theme.surfaceAlt
                            border.width: 1
                            radius: Theme.radiusXS
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: delegate.textValue
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeMedium
                            color: "#000000"
                        }
                    }
                    
                    highlighted: familyComboBox.highlightedIndex === index
                    
                    background: Rectangle {
                        color: highlighted ? "#e3f2fd" : Theme.surfaceLight
                        radius: Theme.radiusXS
                    }
                }
                
                // Contenu affiché dans la ComboBox fermée
                contentItem: Row {
                    spacing: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: familyComboBox.currentIndex >= 0 ? familyComboBox.model[familyComboBox.currentIndex].color : "#ecf0f1"
                        border.color: Theme.surfaceAlt
                        border.width: 1
                        radius: Theme.radiusXS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Text {
                        text: familyComboBox.displayText
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.textPrimary
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
