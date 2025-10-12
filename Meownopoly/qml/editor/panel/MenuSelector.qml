import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../item_icon"
import ".."

Item {
    id: root    
    required property EditorLogic logic
    property bool isExpanded: false
    
    // Propriétés pour gérer les onglets dynamiques
    property int currentPanelIndex: 0 // 0=Assets, 1=Cases, 2=Map
    property int assetTabIndex: 0 // 0=Visual Effects, 1=Transform
    property int caseTabIndex: 0 // 0=Case, 1=Connexions
    property int mapTabIndex: 0 // 0=General, 1=Load, 2=Background

    // Signal émis quand un bouton est cliqué

    enum ButtonType {
        Assets,
        Cases,
        Edition
    }
    
    signal buttonClicked(int index)
    signal assetTabChanged(int tabIndex)
    signal caseTabChanged(int tabIndex)
    signal mapTabChanged(int tabIndex)

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
        ColumnLayout
        {
            height: parent.height
            width: Screen.pixelDensity * 35
            spacing: 0
            Layout.fillHeight: true
            SizeSelector{
                text: "W:"
                // @disable-check M16
                topLeftRadius: 3
                // @disable-check M16
                topRightRadius: 3
                Layout.fillHeight: true
                Layout.fillWidth: true
                widthSpinBox.value: logic.tileLogic.currentElementWidth
                onValueChanged: function(value) { logic.tileLogic.currentElementWidth = value }
            }
            SizeSelector{
                text: "H:"
                // @disable-check M16
                bottomLeftRadius: 3
                // @disable-check M16
                bottomRightRadius: 3
                Layout.fillHeight: true
                Layout.fillWidth: true
                widthSpinBox.value: logic.tileLogic.currentElementHeight
                onValueChanged: function(value) { logic.tileLogic.currentElementHeight = value }
            }
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
        
        // Boutons d'onglets dynamiques (Map Panel)
        RowLayout {
            id: mapTabButtons
            visible: root.isExpanded && root.currentPanelIndex === 2
            Layout.fillHeight: true
            Layout.preferredHeight: parent.height
            Layout.leftMargin: 10
            spacing: -1
            
            Button {
                id: generalSettingsTabButton
                text: "⚙️"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.mapTabIndex === 0 ? "#4a90e2" : "#333333"
                    border.color: root.mapTabIndex === 0 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.mapTabIndex === 0 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.mapTabIndex === 0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Paramètres généraux"
                ToolTip.delay: 500
                
                onClicked: {
                    root.mapTabChanged(0)
                }
            }
            
            Button {
                id: loadMapTabButton
                text: "📂"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.mapTabIndex === 1 ? "#4a90e2" : "#333333"
                    border.color: root.mapTabIndex === 1 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.mapTabIndex === 1 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.mapTabIndex === 1
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Charger carte"
                ToolTip.delay: 500
                
                onClicked: {
                    root.mapTabChanged(1)
                }
            }
            
            Button {
                id: backgroundTabButton
                text: "🖼️"
                Layout.fillHeight: true
                Layout.preferredWidth: 70
                Layout.minimumHeight: 32
                
                background: Rectangle {
                    color: root.mapTabIndex === 2 ? "#4a90e2" : "#333333"
                    border.color: root.mapTabIndex === 2 ? "#5a9fe8" : "#444444"
                    border.width: 2
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: parent.text
                    color: root.mapTabIndex === 2 ? "#ffffff" : "#888888"
                    font.pixelSize: 20
                    font.bold: root.mapTabIndex === 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                ToolTip.visible: hovered
                ToolTip.text: "Modifier fond d'écran"
                ToolTip.delay: 500
                
                onClicked: {
                    root.mapTabChanged(2)
                }
            }
        }
    }
    
    // Contrôles de dimensions et outil curseur
    Rectangle {
        id: controlsBackground
        anchors.left: menuSelector.right
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: controlsRow.width + 20
        color: "#333333"
        radius: 4
        border.color: "#444444"
        border.width: 1
        
        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 10
            height: parent.height

            // Mouse cursor button
            Rectangle {
                id: cursorButton
                property bool checked: false
                
                width: 32
                height: 32
                radius: 4
                color: checked ? "#4A90E2" : "#444444"
                border.color: "#666666"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: "🖱️"
                    color: "white"
                    font.pixelSize: 14
                    anchors.centerIn: parent
                }
                
                MouseArea {
                    id: cursorMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        checked = !checked
                        if (checked)
                            root.buttonClicked(root.BTN_EDITION)
                    }
                }
                
                ToolTip {
                    visible: cursorMouseArea.containsMouse
                    text: "Select cursor tool"
                    delay: 500
                }
            }
        }
    }
}
