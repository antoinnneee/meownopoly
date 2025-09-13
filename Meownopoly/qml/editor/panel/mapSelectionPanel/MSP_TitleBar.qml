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

    // Spacer
    Item { Layout.fillWidth: true }

    backButton.visible: titleBar.isExpanded


    // Clear selection button (visible when asset is selected)
}
