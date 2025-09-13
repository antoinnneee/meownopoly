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
     titleBar: null

     contentArea: SSP_ContentArea {
            id: contentArea
            anchors.fill: parent

            currentView: root.currentView
            activeFilter: titleBar.activeFilter

            isExpanded: true
            searchText: root.searchText

    }
}
