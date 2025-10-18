import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15
import "../editorBottomPanel"
import "../../../ui_item"

import MapInfo

Item {
    id: generalParamsView
    width: parent.width
    height: generalLayout.height

    // Propriétés pour stocker les informations de la carte
    property string mapName: logic.mapInfo.mapName
    property string mapVersion: logic.mapInfo.version
    property string dateOfCreation: logic.mapInfo.mapCreationDate
    property string dateOfLastModification: logic.mapInfo.mapLastModified
    property string description: logic.mapInfo.mapDescription

    signal newMap()

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
                        
                        // Spacer
                        Item {
                            width: parent.parent.width - saveButton.width - 210
                            height: 1
                        }
                        
                        // Save button
                        ParticleButton {
                            id: saveButton
                            width: 100
                            height: 30
                            text: "Save Map"
                            
                            // Configuration des particules avec les couleurs vertes
                            particleColor: "#32CD32"
                            particleColorVariation: "#00FF00"
                            particleCount: 30
                            particleSize: 6
                            particleLifeSpan: 1500
                            
                            background: Rectangle {
                                anchors.fill: parent
                                color: saveButton.down ? "#45a049" : "#4CAF50"
                                opacity: saveButton.hovered ? 1.0 : 0.8
                                radius: 4
                                
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                                
                                // Effet de brillance au clic
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: "white"
                                    opacity: saveButton.down ? 0.2 : 0.0
                                    
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 100
                                        }
                                    }
                                }
                            }
                            
                            contentItem: Text {
                                text: "Save Map"
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 12
                                font.bold: true
                            }
                            
                            onClicked: {
                                console.log("Saving map:", mapName, "v" + mapVersion)
                                if (typeof logic !== 'undefined' && typeof logic.saveMap === 'function') {
                                    var mapInfo = logic.mapInfo
                                    mapInfo.mapName = mapName
                                    mapInfo.version = mapVersion
                                    mapInfo.mapDescription = description
                                    mapInfo.mapCreationDate = dateOfCreation
                                    mapInfo.mapLastModified = dateOfLastModification
                                    logic.saveMap()
                                    newMap()
                                } else {
                                    console.error("La fonction saveMap n'est pas accessible. Vérifiez que la variable 'logic' est définie.")
                                }
                            }
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
                                placeholderText: text === "" ? "Name of the map" : ""
                                text: logic.mapInfo.mapName
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
                                placeholderTextColor: "#666666"
                                placeholderText: text === "" ? "1.0" : ""
                                text: logic.mapInfo.version.toString()
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
                                placeholderTextColor: "#666666"
                                placeholderText: text === "" ? "2023-09-15" : ""
                                text: logic.mapInfo.mapCreationDate
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
                                placeholderText: text === "" ? "2023-09-18 (3 days ago)" : ""
                                text: logic.mapInfo.mapLastModified
                                onEditingFinished: dateOfCreation = text
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
                            placeholderText: text === "" ? "Enter map description here..." : ""
                            text : logic.mapInfo.mapDescription
                            placeholderTextColor: "#666666"
                            background: null
                        }
                    }
                    
                    // Scrollbar for description
                    ScrollBar {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: 8
                        anchors.topMargin: 5
                        anchors.bottomMargin: 5
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
