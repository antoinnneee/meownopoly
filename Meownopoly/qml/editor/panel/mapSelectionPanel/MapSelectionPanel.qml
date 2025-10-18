import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EditorBottomPanel {
    id: root

    property bool showEffectsPanel: true
    property alias currentTabIndex: titleBar.currentTabIndex

    // Signals

    signal effectChanged()


    // Title bar
     titleBar: MSP_TitleBar {
         id: titleBar
         anchors.left: parent.left
         anchors.right: parent.horizontalCenter
         anchors.top: parent.top
         isExpanded: true
         
         onCurrentTabIndexChanged: {
             titleBar.currentTabIndex = currentTabIndex
         }
     }

     contentArea: MSP_ContentArea {
            id: contentArea
            anchors.fill: parent

            currentView: ""
            activeFilter: ""
            currentTabIndex: titleBar.currentTabIndex

            isExpanded: true
            searchText: root.searchText
            titleHeight: titleBar.height

    }
}
