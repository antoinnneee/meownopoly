import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Editor
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
            // ListElement {
            //     menuText: "Séléction d'assets"
            //     menuColor: "#b05758"
            //     menuBorderColor: "#862a2a"
            // }
            // ListElement {
            //     menuText: "Menu Cases"
            //     menuColor: "#b3ab48"
            //     menuBorderColor: "#8a8224"
            // }
            // ListElement {
            //     menuText: "Menu Carte"
            //     menuColor: "#4a90e2"
            //     menuBorderColor: "#306aa8"
            // }
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
    }

    Button {
        id : expendSidePanelBt

        height: parent.height
        anchors.right: parent.right
        anchors.top: parent.bottom
        anchors.rightMargin: 0
        anchors.topMargin: 0
        anchors.bottomMargin: 0
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
}
