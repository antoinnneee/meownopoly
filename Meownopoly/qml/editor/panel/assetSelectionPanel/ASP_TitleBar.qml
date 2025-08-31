import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EBP_TitleBar {
    id: titleBar
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    property string activeFilter: ""
    property string searchText: ""

    signal assetSelected(string category, string type, string id)

    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.rightMargin: 6
        spacing: 15
        
        // Title with selection indicator
        ColumnLayout {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            
            Text {
                text: "Asset Library"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                Layout.fillHeight: true
            }
            
            Text {
                text: titleBar.currentSelectedId !== "" ?
                          "Selected: " + titleBar.currentSelectedType + " #" + titleBar.currentSelectedId :
                          "Click to select an asset"
                color: titleBar.currentSelectedId !== "" ? "#4CAF50" : "#999999"
                font.pixelSize: 10
                font.italic: true
                visible: titleBar.isExpanded
                Layout.fillHeight: true
            }
        }
        
        // Quick filters (visible only when expanded)
        Row {
            visible: titleBar.isExpanded
            spacing: 10
            Layout.alignment: Qt.AlignVCenter
            
            Repeater {
                model: ["All", "Decoration", "Tile"]
                
                Button {
                    text: modelData
                    flat: true
                    checkable: true
                    checked: titleBar.activeFilter === modelData
                    
                    background: Rectangle {
                        color: parent.checked ? "#4A90E2" : "transparent"
                        border.color: "#4A90E2"
                        border.width: 1
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? "white" : "#4A90E2"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        titleBar.activeFilter = text
                        root.currentView = "categories"
                    }
                }
            }
        }
        
        // Search bar (optional, visible when expanded)
        TextField {
            visible: titleBar.isExpanded
            Layout.preferredWidth: 200
            Layout.alignment: Qt.AlignVCenter
            placeholderText: "Search assets..."
            text: titleBar.searchText
            
            background: Rectangle {
                color: "#444444"
                border.color: "#666666"
                border.width: 1
                radius: 4
            }
            
            color: "white"
            
            onTextChanged: titleBar.searchText = text
        }
        
        // Spacer
        Item { Layout.fillWidth: true }
        
        // Back button (visible when in assets view)
        Button {
            visible: titleBar.isExpanded && root.currentView === "assets"
            text: "← Back"
            flat: true
            
            background: Rectangle {
                color: parent.pressed ? "#555555" : "transparent"
                border.color: "#666666"
                border.width: 1
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: root.currentView = "categories"
        }
        
        // Clear selection button (visible when asset is selected)
        Button {
            visible: titleBar.isExpanded && titleBar.currentSelectedId !== ""
            text: "✕ Clear"
            flat: true
            
            background: Rectangle {
                color: parent.pressed ? "#AA4444" : "transparent"
                border.color: "#FF6666"
                border.width: 1
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: "#FF6666"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
            }
            
            onClicked: {
                // Signal to parent to clear selection
                titleBar.assetSelected("", "", "")
            }
        }
        
        // Expand/collapse button
        // Button {
        //     id: expandButton
        //     width: 30
        //     Layout.fillHeight: true
        //     Layout.topMargin: -6
        //     Layout.bottomMargin:  0
        
        //     background: Rectangle {
        //         color: parent.pressed ? "#555555" : "#444444"
        //         border.color: "#666666"
        //         border.width: 1
        //         radius: 4
        //     }
        
        //     contentItem: Text {
        //         text: root.isExpanded ? "▼" : "▲"
        //         color: "white"
        //         font.pixelSize: 12
        //         horizontalAlignment: Text.AlignHCenter
        //         verticalAlignment: Text.AlignVCenter
        //         anchors.fill:expandButton
        //     }
        
        //     onClicked: root.isExpanded = !root.isExpanded
        // }
    }
}
