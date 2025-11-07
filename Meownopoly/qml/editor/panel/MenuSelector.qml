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

    property bool isExpanded : true
    property bool isSidePanelExpanded: false

    // Propriétés pour gérer les onglets dynamiques
    property int currentPanelIndex: 0 // 0=Assets, 1=Cases, 2=Map
    property int assetTabIndex: 0 // 0=Visual Effects, 1=Transform
    property int caseTabIndex: 0 // 0=Case, 1=Connexions
    property int activeTabIndex: 0 // 0-3 pour les 4 boutons d'onglets

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
                root.isExpanded = !root.isExpanded;
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
        // Sélecteur avec 4 boutons d'onglets (1 actif sur 4)
        RowLayout {
            id: tabSelector
            visible: root.isExpanded
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height
            Layout.leftMargin: 10
            spacing: 2
            
            Repeater {
                model: [
                    { icon: "✨", tooltip: "Visual Effects", tabIndex: 0 },
                    { icon: "🔧", tooltip: "Transform", tabIndex: 1 },
                    { icon: "⚙️", tooltip: "Case Configuration", tabIndex: 2 },
                    { icon: "🔗", tooltip: "Connections", tabIndex: 3 }
                ]
                
                Button {
                    required property var modelData
                    required property int index
                    
                    text: modelData.icon
                    Layout.fillHeight: true
                    Layout.preferredWidth: 70
                    Layout.minimumHeight: 32
                    
                    background: Rectangle {
                        color: root.activeTabIndex === index ? "#4a90e2" : "#333333"
                        border.color: root.activeTabIndex === index ? "#5a9fe8" : "#444444"
                        border.width: 2
                        radius: 6
                        
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: root.activeTabIndex === index ? "#ffffff" : "#888888"
                        font.pixelSize: 20
                        font.bold: root.activeTabIndex === index
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.tooltip
                    ToolTip.delay: 500
                    
                    onClicked: {
                        root.activeTabIndex = index
                        
                        // Synchroniser avec les anciennes propriétés
                        if (index === 0) {
                            root.assetTabChanged(0)
                        } else if (index === 1) {
                            root.assetTabChanged(1)
                        } else if (index === 2) {
                            root.caseTabChanged(0)
                        } else if (index === 3) {
                            root.caseTabChanged(1)
                        }
                    }
                }
            }

            Button {
                id : expendSidePanelBt

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
                    text: root.isSidePanelExpanded ? "◀" : "▶"
                    color: "white"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    anchors.fill:expendSidePanelBt
                }

                onClicked: {
                    console.log("Side panel expand button clicked, " + root.isSidePanelExpanded);
                    root.isSidePanelExpanded = !root.isSidePanelExpanded;
                }
            }

            // MenuSelector_SizeControl {
            //     tileLogic: logic.tileLogic
            //     height: Screen.pixelDensity * 12.5
            // }
        }
    }
}
