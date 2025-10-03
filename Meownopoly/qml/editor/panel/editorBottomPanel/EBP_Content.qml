import QtQuick 2.15
import QtQuick.Controls 2.15

Item {

    id: contentArea

    property bool isExpanded: false
    required property var currentView

    property string searchText: ""
    required property string activeFilter



    visible: isExpanded
    opacity: isExpanded ? 1.0 : 0.0

    property real sidePanelRatio: 0.42
    property alias mainContent : mainContentHolder.children
    property alias sidePanel : sidePanel.children

    Item {
        id: mainContentHolder
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.rightMargin: 5
        anchors.leftMargin: 5

        width: parent.width * (1-sidePanelRatio)

    }

    Item {
        id : sidePanel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width * sidePanelRatio
    }

}
