import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: titleBar
    property bool isExpanded : false
    property string activeFilter: ""

    property string titleText: "DEMO"
    property string subTitleText: "DEMO"
    property string subTitleColor: "#999999"

    property string searchText: ""
    property var buttonModel:  [/*"All", "Decoration", "Tile"*/]


    property alias titleBarArea: titleBarArea
    property alias backButton: backButton

    signal buttonClicked(string text, int index)
    signal backButtonClicked()


    anchors.margins: 10
    anchors.rightMargin: 6
    spacing: 15

    height: isExpanded ? 40 : 0
    // Title with selection indicator
    ColumnLayout {
        id: titleBarArea
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        Text {
            text: titleBar.titleText
            color: "white"
            font.pixelSize: 16
            font.bold: true
            Layout.fillHeight: true
        }

        Text {
            text: titleBar.subTitleText
            color: titleBar.subTitleColor
            font.pixelSize: 10
            font.italic: true
            visible: titleBar.isExpanded
            Layout.fillHeight: true
        }
    }
    // Quick filters (visible only when expanded)
    EBP_FilterButton {
        Layout.alignment: Qt.AlignVCenter
        visible: titleBar.isExpanded
        activeFilter: titleBar.activeFilter
        buttonModel: titleBar.buttonModel
        onButtonClicked: function(text, index) {
            titleBar.buttonClicked(text, index)
        }

    }
    // Search bar (optional, visible when expanded)
    EBP_SearchBar {
        id: searchbar
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 200
        text: titleBar.searchText
        visible: titleBar.isExpanded
        onTextChanged: titleBar.searchText = text
    }

    // Back button (visible when in assets view)
    EBP_BackButton {
        id: backButton
        visible: titleBar.isExpanded
        onClicked: {
            backButtonClicked()
        }
    }


}
