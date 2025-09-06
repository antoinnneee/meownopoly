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

    signal assetSelected(string category, string type, string id)
    required property string currentView // "categories" or "assets"

    titleText: "Asset Library"
    subTitleText: titleBar.currentSelectedId !== "" ?
                      "Selected: " + titleBar.currentSelectedType + " #" + titleBar.currentSelectedId :
                      "Click to select an asset"
    subTitleColor: titleBar.currentSelectedId !== "" ? "#4CAF50" : "#999999"
    buttonModel: ["All", "Decoration", "Tile"]

    onButtonClicked: function(text, index) {
        console.log(index, "filter button clicked", text)
        titleBar.activeFilter = text
        titleBar.currentView = "categories"
    }

    // Spacer
    Item { Layout.fillWidth: true }

    backButton.visible: titleBar.isExpanded && titleBar.currentView === "assets"


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
