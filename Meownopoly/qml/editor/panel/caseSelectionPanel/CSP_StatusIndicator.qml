import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager
import Game
import Case
import CaseRestArea
import "../assetSelectionPanel"
import "../"
import "../editorBottomPanel"

Rectangle {
    width: statusText.width + 10
    height: 20
    color: "#444444"
    radius: 10
    Text {
        id: statusText
        anchors.centerIn: parent
        text: {
            if (root.currentView === "categories") {
                return "Select a category"
            } else {
                return root.selectedCategory === "proprietes" ? "Propriétés" : "Spéciales"
            }
        }
        color: "#CCCCCC"
        font.pixelSize: 10
    }
}
