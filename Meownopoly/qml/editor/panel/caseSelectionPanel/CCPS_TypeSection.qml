import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MeowStyle

GroupBox {
    id: control
    title: "Type de Case"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    
    // Signals
    signal typeChanged(int newType)
    
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
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        Text {
            text: "Sélectionnez le type de case :"
            font.pixelSize: 10
            color: "#888888"
            font.italic: true
            Layout.fillWidth: true
        }
        
        // Type selector
        Rectangle {
            Layout.fillWidth: true
            height: 45
            color: "#2a2a2a"
            border.color: "#555555"
            border.width: 1
            radius: 6
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 0
                
                // Bouton flèche gauche
                Button {
                    id: leftArrow
                    Layout.preferredWidth: 35
                    Layout.fillHeight: true
                    
                    background: Rectangle {
                        color: parent.hovered ? "#444444" : "transparent"
                        radius: 4
                        border.color: parent.hovered ? "#666666" : "transparent"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }
                    
                    contentItem: Text {
                        text: "◀"
                        font.pixelSize: 14
                        font.bold: true
                        color: leftArrow.enabled ? "#cccccc" : "#555555"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    
                    enabled: currentIndex > 0
                    
                    onClicked: {
                        if (currentIndex > 0 && !updatingValues) {
                            let newIndex = currentIndex - 1
                            let newType = availableTypes[newIndex]
                            currentType = newType
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
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on text {
                            SequentialAnimation {
                                PropertyAnimation {
                                    target: parent
                                    property: "opacity"
                                    to: 0.5
                                    duration: 100
                                }
                                PropertyAnimation {
                                    target: parent
                                    property: "opacity"
                                    to: 1.0
                                    duration: 100
                                }
                            }
                        }
                    }
                    
                    // Indicateur visuel subtil
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 4
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
                        color: parent.hovered ? "#444444" : "transparent"
                        radius: 4
                        border.color: parent.hovered ? "#666666" : "transparent"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }
                    
                    contentItem: Text {
                        text: "▶"
                        font.pixelSize: 14
                        font.bold: true
                        color: rightArrow.enabled ? "#cccccc" : "#555555"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
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
    }
    
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

