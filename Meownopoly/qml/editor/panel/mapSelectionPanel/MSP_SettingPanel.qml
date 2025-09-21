import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

import MapInfo

Rectangle {
    id: sidePanel
    width: sidePanelScroll.width - 20 // Account for scrollbar

    property string mapName
    property int mapVersion
    property string backgroundPath: ""
    property string backgroundScaling: "Stretch"
    property string dateOfCreation
    property string dateOfLastModification
    property string description

    height : getContentHeight()
    function getContentHeight() {
        // Calculer précisément la hauteur en fonction de la vue active
        var contentHeight = 0;
        switch (contentArea.currentView) {
        case "general": contentHeight = generalParamsView.height; break;
        case "saveLoad": contentHeight = saveLoadView.height; break;
        case "background": contentHeight = backgroundView.height; break;
        }

        // Utiliser la hauteur exacte sans padding supplémentaire
        return titleSection.height + contentHeight;
    }

    // Mettre à jour la hauteur quand la vue change
    Connections {
        target: contentArea
        function onCurrentViewChanged() {
            Qt.callLater(function() {
                sidePanel.height = getContentHeight();
            });
        }
    }

    // Mettre à jour également quand le panneau devient visible
    onVisibleChanged: {
        if (visible) {
            Qt.callLater(function() {
                sidePanel.height = getContentHeight();
            });
        }
    }
    // Visual properties
    color: "#2a2a2a"
    radius: 12
    border.color: "#444444"
    border.width: 1

    // Pas de marges excessives
    anchors.margins: 5

    // Title section - always visible
    Item {
        id: titleSection
        width: parent.width
        height: 60 // Réduit la hauteur
        z: 10

        // Title card
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#2a2a2a"
            radius: 8
            border.color: "#555555"
            border.width: 1

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#333333" }
                GradientStop { position: 1.0; color: "#2a2a2a" }
            }

            Row {
                anchors.centerIn: parent
                spacing: 15

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: "#4A90E2"
                    opacity: 0.3

                    Text {
                        anchors.centerIn: parent
                        text: "✏️"
                        font.pixelSize: 18
                    }
                }

                Text {
                    text: "Map Settings"
                    color: "white"
                    font.pixelSize: 20
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // General parameters view
    Item {
        id: generalParamsView
        visible: contentArea.currentView === "general"
        width: parent.width
        height: generalLayout.height
        anchors.top: titleSection.bottom

        Column {
            id: generalLayout
            width: parent.width
            spacing: 10 // réduit l'espacement
            padding: 5 // réduit le padding

            // Controls container
            Rectangle {
                width: parent.width - parent.padding * 2
                color: "#333333"
                radius: 6
                border.color: "#444444"
                border.width: 1
                height: controlsColumn.height + 20

                // Main details column
                Column {
                    id: controlsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15

                    // Map info header with icon - distinct section 1
                    Rectangle {
                        width: parent.width
                        height: 40
                        color: "#383838"
                        radius: 6

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: "#4A90E2"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "🗺️"
                                    font.pixelSize: 16
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Map Information"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }

                    // Grid layout for map details
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 15

                        // Map name
                        Text {
                            text: "Map Name"
                            color: "#999999"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 4

                            Row {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5
                                
                                Text {
                                    text: "📁"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }
                                
                                TextField {
                                    width: parent.width - 25
                                    height: parent.height
                                    color: "#4CAF50"
                                    font.pixelSize: 14
                                    verticalAlignment: Text.AlignVCenter
                                    placeholderTextColor: "#666666"
                                    placeholderText: "Name of the map"
                                    onFocusChanged: {
                                        if (focus && text === "") {placeholderText = ""}
                                        else if (!focus && text === "") {placeholderText = "Name of the map"}
                                    }
                                    onEditingFinished: mapName = text
                                }
                            }
                        }

                        // Version
                        Text {
                            text: "Version"
                            color: "#999999"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 4

                            Row {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5
                                Text {
                                    text: "📈"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }
                                
                                TextField {
                                    width: parent.width - 25
                                    height: parent.height
                                    color: "white"
                                    font.pixelSize: 14
                                    verticalAlignment: TextInput.AlignVCenter
                                    onFocusChanged: {
                                        if (focus && text === "") {placeholderText = ""}
                                        else if (!focus && text === "") {placeholderText = "1.0"}
                                    }
                                    placeholderTextColor: "#666666"
                                    placeholderText: "1.0"
                                    onEditingFinished: mapVersion = parseInt(text) || 1
                                }
                            }
                        }

                        // Creation date
                        Text {
                            text: "Created"
                            color: "#999999"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 4

                            Row {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5

                                Text {
                                    text: "📅"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }

                                TextField {
                                    width: parent.width - 25
                                    height: parent.height
                                    color: "white"
                                    font.pixelSize: 14
                                    onFocusChanged: {
                                        if (focus && text === "") {placeholderText = ""}
                                        else if (!focus && text === "") {placeholderText = "2023-09-15"}
                                    }
                                    placeholderTextColor: "#666666"
                                    placeholderText: "2023-09-15"
                                    onEditingFinished: dateOfCreation = text
                                    verticalAlignment: TextInput.AlignVCenter
                                }
                            }
                        }

                        // Last modification
                        Text {
                            text: "Modified"
                            color: "#999999"
                            font.pixelSize: 14
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 4

                            Row {
                                anchors.fill: parent
                                anchors.margins: 5
                                spacing: 5

                                Text {
                                    text: "🕒"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }

                                TextField {
                                    width: parent.width - 25
                                    height: parent.height
                                    color: "#4CAF50"
                                    font.pixelSize: 14
                                    verticalAlignment: Text.AlignVCenter
                                    placeholderTextColor: "#666666"
                                    placeholderText: "2023-09-18 (3 days ago)"
                                    onEditingFinished: dateOfCreation = text
                                    onFocusChanged: {
                                        if (focus && text === "") {placeholderText = ""}
                                        else if (!focus && text === "") {placeholderText = "2023-09-18 (3 days ago)"}
                                    }
                                }
                            }
                        }
                    }

                    // Description section - distinct section 2
                    Rectangle {
                        width: parent.width
                        height: 40
                        color: "#383838"
                        radius: 6

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: "#FFC107"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📝"
                                    font.pixelSize: 16
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Description"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }

                    // Description text area
                    Rectangle {
                        width: parent.width
                        height: 120
                        color: "transparent"
                        border.color: "#4A90E2"
                        border.width: 1
                        radius: 4

                        Flickable {
                            id: flickable
                            anchors.fill: parent
                            anchors.margins: 5
                            contentWidth: descriptionInput.paintedWidth
                            contentHeight: descriptionInput.paintedHeight
                            clip: true

                            TextArea {
                                id: descriptionInput
                                width: flickable.width
                                height: Math.max(flickable.height, paintedHeight)
                                color: "white"
                                font.pixelSize: 14
                                wrapMode: TextEdit.Wrap
                                placeholderText: "Enter map description here..."
                                placeholderTextColor: "#666666"
                                text: ""
                                background: null
                            }
                        }

                        // Scrollbar for description
                        ScrollBar {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            width: 8
                            policy: ScrollBar.AsNeeded
                            active: true
                            orientation: Qt.Vertical
                            size: flickable.height / flickable.contentHeight
                            position: flickable.contentY / flickable.contentHeight
                            visible: flickable.contentHeight > flickable.height

                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: width / 2
                                color: "#999999"
                                opacity: 0.5
                            }
                        }
                    }

                    // Stats section - distinct section 3
                    Rectangle {
                        width: parent.width
                        height: 40
                        color: "#383838"
                        radius: 6

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: "#E91E63"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📊"
                                    font.pixelSize: 16
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Statistics"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }

                    // Quick stats in badges
                    Flow {
                        width: parent.width
                        spacing: 10

                        // Stats badges with subtle colors
                        Repeater {
                            model: [
                                {icon: "🏠", label: "Tiles", value: "36", color: "#4A90E2"},
                                {icon: "🎮", label: "Players", value: "4", color: "#4CAF50"},
                                {icon: "🛒", label: "Items", value: "52", color: "#FFC107"},
                                {icon: "🎲", label: "Events", value: "12", color: "#E91E63"}
                            ]

                            Rectangle {
                                width: modelData.label.length * 11 + 50
                                height: 30
                                radius: 15
                                color: Qt.rgba(
                                           parseInt(modelData.color.substr(1, 2), 16) / 255,
                                           parseInt(modelData.color.substr(3, 2), 16) / 255,
                                           parseInt(modelData.color.substr(5, 2), 16) / 255,
                                           0.15
                                           )
                                border.color: modelData.color
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label + ": " + modelData.value
                                        color: "white"
                                        font.pixelSize: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Save/Load map view
    Item {
        id: saveLoadView
        visible: contentArea.currentView === "saveLoad"
        width: parent.width
        height: saveLoadLayout.height
        anchors.top: titleSection.bottom

        Column {
            id: saveLoadLayout
            width: parent.width
            spacing: 10 // réduit l'espacement
            padding: 5 // réduit le padding

            Text {
                text: "Save/Load Options"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }

            // Controls container
            Rectangle {
                width: parent.width - parent.padding * 2
                color: "#333333"
                radius: 6
                border.color: "#444444"
                border.width: 1
                height: buttonsColumn.height + 20

                Column {
                    id: buttonsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15

                    // Save button
                    Button {
                        width: parent.width
                        height: 40
                        flat: true

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#4CAF50"
                            border.width: 1
                            radius: 4
                        }

                        contentItem: Text {
                            text: "Save Current Map"
                            color: "#4CAF50"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }

                        onClicked: {
                            console.log("Saving map:", contentArea.mapName, "v" + contentArea.mapVersion)
                            if (typeof logic !== 'undefined' && typeof logic.saveMap === 'function') {
                                var mapInfo = logic.mapInfo
                                mapInfo.mapName = contentArea.mapName
                                mapInfo.version = contentArea.mapVersion

                                logic.saveMap()
                            } else {
                                console.error("La fonction saveMap n'est pas accessible. Vérifiez que la variable 'logic' est définie.")
                            }
                        }
                    }

                    // Load button
                    Button {
                        width: parent.width
                        height: 40
                        flat: true

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 4
                        }

                        contentItem: Text {
                            text: "Load Map"
                            color: "#4A90E2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }

                        onClicked: {
                            console.log("Open load map dialog")
                        }
                    }

                    // New map button
                    Button {
                        width: parent.width
                        height: 40
                        flat: true

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#FFC107"
                            border.width: 1
                            radius: 4
                        }

                        contentItem: Text {
                            text: "Create New Map"
                            color: "#FFC107"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }

                        onClicked: {
                            console.log("Creating new map")
                            contentArea.mapName = "New Map"
                            contentArea.mapVersion = "1.0"
                        }
                    }
                }
            }
        }
    }

    // Background modification view
    Item {
        id: backgroundView
        visible: contentArea.currentView === "background"
        width: parent.width
        height: backgroundLayout.height
        anchors.top: titleSection.bottom

        Column {
            id: backgroundLayout
            width: parent.width
            spacing: 10 // réduit l'espacement
            padding: 5 // réduit le padding

            Text {
                text: "Background Settings"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }

            // Controls container
            Rectangle {
                width: parent.width - parent.padding * 2
                color: "#333333"
                radius: 6
                border.color: "#444444"
                border.width: 1
                height: bgControlsColumn.height + 20

                Column {
                    id: bgControlsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15

                    // Select background button
                    Button {
                        width: parent.width
                        height: 40
                        flat: true

                        background: Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: "#E91E63"
                            border.width: 1
                            radius: 4
                        }

                        contentItem: Text {
                            text: "Select Image/GIF"
                            color: "#E91E63"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }

                        onClicked: {
                        }
                    }

                    // Current background path
                    Column {
                        width: parent.width
                        spacing: 5
                        visible: contentArea.backgroundPath !== ""

                        Text {
                            text: "Selected File:"
                            color: "#999999"
                            font.pixelSize: 14
                        }

                        Text {
                            text: contentArea.backgroundPath
                            color: "#4CAF50"
                            font.pixelSize: 12
                            width: parent.width
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideMiddle
                        }
                    }

                    // Image scaling options
                    Column {
                        width: parent.width
                        spacing: 5
                        visible: contentArea.backgroundPath !== ""

                        Text {
                            text: "Image Scaling"
                            color: "#999999"
                            font.pixelSize: 14
                        }

                        ComboBox {
                            width: parent.width
                            height: 40
                            model: ["Stretch", "Preserve Aspect Ratio", "Preserve Aspect Fit", "Tile"]

                            contentItem: Text {
                                text: parent.displayText
                                color: "white"
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                leftPadding: 5
                            }

                            background: Rectangle {
                                color: "transparent"
                                border.color: "#4A90E2"
                                border.width: 1
                                radius: 4
                            }

                            popup.background: Rectangle {
                                color: "#222222"
                                border.color: "#4A90E2"
                                border.width: 1
                                radius: 4
                            }

                            delegate: ItemDelegate {
                                width: parent.width
                                contentItem: Text {
                                    text: modelData
                                    color: "white"
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                                highlighted: parent.highlightedIndex === index
                            }

                            onActivated: {
                                console.log("Selected scaling mode:", model[index])
                            }
                        }
                    }
                }
            }
        }
    }
}
