import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"

Rectangle {
    id: sidePanel
    width: sidePanelScroll.width - 20 // Account for scrollbar
    height: Math.max(generalParamsView.height, saveLoadView.height, backgroundView.height) + 20 // Add padding

    // Visual properties
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1
    
    // Add internal margins
    anchors.margins: 10
    
    // General parameters view
    Item {
        id: generalParamsView
        visible: contentArea.currentView === "general"
        width: parent.width
        height: generalLayout.height
        
        Column {
            id: generalLayout
            width: parent.width
            spacing: 15
            padding: 10
            
            Text {
                text: "Map Settings"
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
                height: controlsColumn.height + 20
                
                // Main details column
                Column {
                    id: controlsColumn
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    spacing: 15
                    
                    // Map info header with icon
                    Item {
                        width: parent.width
                        height: 30
                        
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
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            text: "Map Information"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
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
                            
                            TextInput {
                                anchors.fill: parent
                                anchors.margins: 5
                                color: "white"
                                font.pixelSize: 14
                                text: contentArea.mapName
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                
                                onTextChanged: {
                                    contentArea.mapName = text
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
                            
                            TextInput {
                                anchors.fill: parent
                                anchors.margins: 5
                                color: "white"
                                font.pixelSize: 14
                                text: contentArea.mapVersion
                                clip: true
                                verticalAlignment: TextInput.AlignVCenter
                                
                                onTextChanged: {
                                    contentArea.mapVersion = text
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
                                
                                TextInput {
                                    width: parent.width - 25
                                    height: parent.height
                                    color: "white"
                                    font.pixelSize: 14
                                    text: "2023-09-15"
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
                                
                                Text {
                                    width: parent.width - 25
                                    height: parent.height
                                    color: "#4CAF50"
                                    font.pixelSize: 14
                                    text: "2023-09-18 (3 days ago)"
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                    
                    // Description section
                    Item {
                        width: parent.width
                        height: 30
                        
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
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            text: "Description"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
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
                    
                    // Stats section
                    Item {
                        width: parent.width
                        height: 30
                        
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
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            text: "Statistics"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
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
        
        Column {
            id: saveLoadLayout
            width: parent.width
            spacing: 15
            padding: 10
            
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
        
        Column {
            id: backgroundLayout
            width: parent.width
            spacing: 15
            padding: 10
            
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
