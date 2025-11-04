import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../ui_item"
import ".."

Item {
    id: root
    height: Screen.pixelDensity * 12.5
    width: 800
    required property EditorLogic logic
    property bool isExpanded: false
    
    // Propriétés pour gérer les onglets dynamiques
    property int currentPanelIndex: 0 // 0=Assets, 1=Cases, 2=Map
    property int assetTabIndex: 0 // 0=Visual Effects, 1=Transform
    property int caseTabIndex: 0 // 0=Case, 1=Connexions

    // Signal émis quand un bouton est cliqué

    enum ButtonType {
        Assets,
        Cases,
        Edition
    }
    
    signal buttonClicked(int index)
    signal assetTabChanged(int tabIndex)
    signal caseTabChanged(int tabIndex)

    // Boutons de menu
    RowLayout {
        id: menuSelector
        anchors.left: parent.left
        height: parent.height
        spacing: 0

        Button {
            id: expandButton
            width: 30
            Layout.fillHeight: true
            background: Rectangle {
                anchors.fill: parent
                color: parent.pressed ? "#555555" : "#444444"
                border.color: "#666666"
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: root.isExpanded ? "▼" : "▲"
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.fill:expandButton
            }

            onClicked: {
                console.log("Expand button clicked");
                isExpanded = !isExpanded;
            }
        }

        ListModel {
            id: menuSelectorModel
            ListElement {
                menuText: "Menu Assets"
                menuColor: "#b05758"
                menuBorderColor: "#862a2a"
            }
            ListElement {
                menuText: "Menu Cases"
                menuColor: "#b3ab48"
                menuBorderColor: "#8a8224"
            }
            ListElement {
                menuText: "Menu Carte"
                menuColor: "#4a90e2"
                menuBorderColor: "#306aa8"
            }
        }

        Repeater {
            model: menuSelectorModel
            MenuSelector_Button {
                required property int index
                required property color menuColor
                required property string menuBorderColor
                required property string menuText
                Layout.fillHeight: true
                Layout.leftMargin: (index) ? -8 : 0
                z: -index
                buttonIndex: index
                mainColor: menuColor
                borderColor: menuBorderColor
                text: menuText
                onButtonClicked: function(index) {
                    root.buttonClicked(index)

                }
            }
        }
        MenuSelector_SizeControl {
            tileLogic: logic.tileLogic

            height: Screen.pixelDensity * 12.5
        }
        
        // Boutons d'onglets dynamiques (Assets Panel)
        RowLayout {
            id: assetTabButtons
            visible: root.isExpanded && root.currentPanelIndex === 0
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height
            Layout.leftMargin: 10
            spacing: -1
            
            Button {
                id: visualEffectsTabButton
                text: "✨"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.assetTabIndex === 0 ? "#4a90e2" : "#333333"
                    border.color: root.assetTabIndex === 0 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.assetTabIndex === 0 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.assetTabIndex === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Visual Effects"
                ToolTip.delay: 500
                
                onClicked: {
                    root.assetTabChanged(0)
                }
            }
            
            Button {
                id: transformTabButton
                text: "🔧"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.assetTabIndex === 1 ? "#4a90e2" : "#333333"
                    border.color: root.assetTabIndex === 1 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.assetTabIndex === 1 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.assetTabIndex === 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Transform"
                ToolTip.delay: 500
                
                onClicked: {
                    root.assetTabChanged(1)
                }
            }
        }
        
        // Boutons d'onglets dynamiques (Case Panel)
        RowLayout {
            id: caseTabButtons
            visible: root.isExpanded && root.currentPanelIndex === 1
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height
            Layout.leftMargin: 10
            spacing: -1
            
            Button {
                id: caseConfigTabButton
                text: "⚙️"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.caseTabIndex === 0 ? "#4a90e2" : "#333333"
                    border.color: root.caseTabIndex === 0 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.caseTabIndex === 0 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.caseTabIndex === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Case Configuration"
                ToolTip.delay: 500
                
                onClicked: {
                    root.caseTabChanged(0)
                }
            }
            
            Button {
                id: connectionsTabButton
                text: "🔗"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.caseTabIndex === 1 ? "#4a90e2" : "#333333"
                    border.color: root.caseTabIndex === 1 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.caseTabIndex === 1 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.caseTabIndex === 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Connections"
                ToolTip.delay: 500
                
                onClicked: {
                    root.caseTabChanged(1)
                }
            }
        }
    }
}
