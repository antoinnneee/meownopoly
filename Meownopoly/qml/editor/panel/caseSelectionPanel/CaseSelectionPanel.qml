import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import "../editorBottomPanel"

EditorBottomPanel {
    id: root

    property alias activeFilter: titleBar.activeFilter


    // Title bar
     titleBar: CSP_TitleBar {
         id: titleBar
         activeFilter: "All"
         anchors.left: parent.left
         anchors.right: parent.horizontalCenter
         anchors.top: parent.top
         isExpanded: true

         onCaseSelected: function(category, type, id) {
             console.log("titleBar select asset", category, type, id)
             root.assetSelected(category, type, id)
         }
         onSearchTextChanged: {
             // console.log("EditorBottomPanel - searchText filter changed", searchText)
             root.searchText = searchText
             root.searchText = Qt.binding(function(){ return root.searchText})
         }


         onCurrentViewChanged:  {
             root.currentView = titleBar.currentView
         }

         onBackButtonClicked: {
             root.currentView = "categories"
         }
         onButtonClicked: function(text, index)  {
             titleBar.activeFilter = text
             root.currentView = "categories"
         }

         searchText: root.searchText
         currentView: root.currentView

    }

    // Content area (visible only when expanded)
     contentArea: CSP_ContentArea {
            id: contentArea
            anchors.fill: parent
            currentView: root.currentView
            activeFilter: titleBar.activeFilter
            searchText: root.searchText
            isExpanded: true
    }


}
