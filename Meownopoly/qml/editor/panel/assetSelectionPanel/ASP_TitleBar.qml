import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
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
    required property string currentView // "categories" or "assets"


        
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
        ASP_FilterButton {
            Layout.alignment: Qt.AlignVCenter
            visible: titleBar.isExpanded
            width: 300
        }
        
        // Search bar (optional, visible when expanded)
        ASP_SearchBar {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 200
            text: titleBar.searchText
            visible: titleBar.isExpanded
            onTextChanged: titleBar.searchText = text
        }
        
        // Spacer
        Item { Layout.fillWidth: true }
        
        // Back button (visible when in assets view)
        EBP_BackButton {
            id: backButton
            visible: titleBar.isExpanded && titleBar.currentView === "assets"
            onClicked: titleBar.currentView = "categories"
        }
        
        // Clear selection button (visible when asset is selected)
        ASP_ClearButton {
            id: clearButton
            visible: titleBar.isExpanded && titleBar.currentSelectedId !== ""
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
