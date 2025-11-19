import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    buttonModel: ["Decoration", "Case"]

    onButtonClicked: function(text, index) {
    }

    // Spacer
    Item { Layout.fillWidth: true }

    backButton.visible: titleBar.currentView === "assets"


    // Clear selection button (visible when asset is selected)
    ASP_ClearButton {
        id: clearButton
        visible: titleBar.currentSelectedId !== ""
    }
}
