import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MeowStyle
import ui_item
import theme

CollapsableGroupBox {
    id: control
    title: "Type de Case"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    padding: Theme.spacingXL
    spacing: 0

    // Signals
    signal typeChanged(int newType)

    // Types de cases disponibles (excluant CS_Unknow et CS_Count)
    property var availableTypes: [
        Case.CS_KibbleDispenser,
        Case.CS_RestArea,
        Case.CS_CardBoardBox,
        Case.CS_CatNip,
        Case.CS_Jail,
        Case.CS_ToJail,
        Case.CS_CatDoor,
        Case.CS_FreeNap,
        Case.CS_Device,
        Case.CS_Taxe
    ]
    
    property int currentType: targetCase ? targetCase.type : Case.CS_Unknow

    // Index actuel dans la liste des types
    property int currentIndex: {
        let index = availableTypes.indexOf(currentType)
        return index >= 0 ? index : 0
    }
    
    content: [
        Text {
            text: "Sélectionnez le type de case :"
            font.pixelSize: Theme.fontSizeCaption
            color: Theme.textMuted
            font.italic: true
            Layout.fillWidth: true
        },
        
        // Type selector
        Rectangle {
            Layout.fillWidth: true
            height: 45
            color: Theme.surface
            border.color: Theme.borderLight
            border.width: 1
            radius: Theme.radiusM

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                spacing: 0
                
                // Bouton flèche gauche
                Button {
                    id: leftArrow
                    Layout.preferredWidth: 35
                    Layout.fillHeight: true
                    
                    background: Rectangle {
                        color: parent.hovered ? Theme.border : "transparent"
                        radius: Theme.radiusS
                        border.color: parent.hovered ? Theme.hover(Theme.borderLight) : "transparent"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
                    }
                    
                    contentItem: Text {
                        text: "◀"
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: leftArrow.enabled ? Theme.textSecondary : Theme.textDisabled
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                    }
                    
                    enabled: currentIndex > 0
                    
                    onClicked: {
                        if (currentIndex > 0 && !updatingValues) {
                            let newIndex = currentIndex - 1
                            let newType = availableTypes[newIndex]
                            typeChanged(newType)
                        }
                    }
                    
                    hoverEnabled: true
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Type précédent"
                    ToolTip.delay: 500
                }
                
                // Zone centrale avec le nom du type
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: MeowStyle.getCaseTypeName(currentType)
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        color: Theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on text {
                            SequentialAnimation {
                                PropertyAnimation {
                                    target: parent
                                    property: "opacity"
                                    to: 0.5
                                    duration: Theme.durationFast
                                }
                                PropertyAnimation {
                                    target: parent
                                    property: "opacity"
                                    to: 1.0
                                    duration: Theme.durationFast
                                }
                            }
                        }
                    }
                    
                    // Indicateur visuel subtil
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: Theme.spacingXS
                        width: parent.width * 0.8
                        height: 2
                        color: getTypeColor(currentType)
                        radius: 1
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                
                // Bouton flèche droite
                Button {
                    id: rightArrow
                    Layout.preferredWidth: 35
                    Layout.fillHeight: true
                    
                    background: Rectangle {
                        color: parent.hovered ? Theme.border : "transparent"
                        radius: Theme.radiusS
                        border.color: parent.hovered ? Theme.hover(Theme.borderLight) : "transparent"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
                    }
                    
                    contentItem: Text {
                        text: "▶"
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: rightArrow.enabled ? Theme.textSecondary : Theme.textDisabled
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
                    }
                    
                    enabled: currentIndex < availableTypes.length - 1
                    
                    onClicked: {
                        if (currentIndex < availableTypes.length - 1 && !updatingValues) {
                            let newIndex = currentIndex + 1
                            let newType = availableTypes[newIndex]
                            //currentType = newType
                            typeChanged(newType)
                        }
                    }
                    
                    hoverEnabled: true
                    
                    ToolTip.visible: hovered
                    ToolTip.text: "Type suivant"
                    ToolTip.delay: 500
                }
            }
        }
    ]
    
    // Functions
    function getTypeColor(type) {
        switch(type) {
            case Case.CS_KibbleDispenser: return "#28a745"
            case Case.CS_RestArea: return "#007bff"
            case Case.CS_CardBoardBox: return "#ffc107"
            case Case.CS_CatNip: return "#fd7e14"
            case Case.CS_Jail: return "#6c757d"
            case Case.CS_ToJail: return "#dc3545"
            case Case.CS_CatDoor: return "#20c997"
            case Case.CS_FreeNap: return "#e83e8c"
            case Case.CS_Device: return "#6f42c1"
            case Case.CS_Taxe: return "#fd7e14"
            default: return "#777777"
        }
    }

}

