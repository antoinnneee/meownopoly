import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

Rectangle {
    id: statusIndicator
    width: statusText.width + 10
    height: 20
    color: "#444444"
    radius: 10
    property string currentSelectedCategory: ""
    required property string currentView // "categories" or "assets"
    Text {
        id: statusText
        anchors.centerIn: parent
        text: {
            if (statusIndicator.currentView === "categories") {
                return "Select a category"
            } else {
                return statusIndicator.selectedCategory + " > " + statusIndicator.selectedType
            }
        }
        color: "#CCCCCC"
        font.pixelSize: 10
    }
}
