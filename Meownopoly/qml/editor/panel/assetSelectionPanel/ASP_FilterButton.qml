import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EBP_FilterButton {
    visible: true
    spacing: 10

    buttonModel : ["All", "Decoration", "Tile"]
    onButtonClicked: function(text, index) {
        titleBar.activeFilter = text
        root.currentView = "categories"
    }
}
