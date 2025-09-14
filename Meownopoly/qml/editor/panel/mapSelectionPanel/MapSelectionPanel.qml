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

    // Signals

    signal effectChanged()


    // Title bar
     titleBar: MSP_TitleBar {
         anchors.left: parent.left
         anchors.right: parent.horizontalCenter
         anchors.top: parent.top
         isExpanded: true

         currentView: root.currentView // "general", "saveLoad", or "background"
         activeFilter: ""

         // onCurrentViewChanged:  {
         //     root.currentView = titleBar.currentView
         // }
     }

     contentArea: MSP_ContentArea {
            id: contentArea
            anchors.fill: parent


            currentView: ""
            activeFilter: ""

            isExpanded: true
            searchText: root.searchText

    }
}
