import QtQuick 2.15
import QtQuick.Controls 2.15


ScrollView {
    id: effectsScrollView
    anchors.top: parent.top
    anchors.right: parent.right
    contentHeight: sidePanelHolder.height
    anchors.bottom: parent.bottom

    width: parent.width *0.42

    visible: root.showEffectsPanel

    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded

    property alias panel : panelHolder.children

    Item  {
        id: panelHolder
        width: effectsScrollView.width - 20 // Account for scrollbar
        anchors.bottom: parent.bottom
    }

}
