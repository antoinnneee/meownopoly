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

    titleText: "Paramétrage de la carte"
    subTitleText: titleBar.currentSelectedId !== "" ?
                      "Selected: " + titleBar.currentSelectedType + " #" + titleBar.currentSelectedId :
                      "Click to select an asset"
    subTitleColor: titleBar.currentSelectedId !== "" ? "#4CAF50" : "#999999"
    buttonModel: ["All", "Decoration", "Tile"]

    onButtonClicked: function(text, index) {
    }

    // Spacer
    Item { Layout.fillWidth: true }

    backButton.visible: titleBar.isExpanded && titleBar.currentView === "assets"

}
