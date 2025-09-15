import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts
import "../editorBottomPanel"

EBP_Content {
    id: contentArea

    property bool showEffectsPanel: true
    
    property string mapName: "New Map"
    property string mapVersion: "1.0"
    property string backgroundPath: ""

    signal effectChanged()

    Component.onCompleted: currentView = "general"     // property string currentView: "general" // "general", "saveLoad", or "background"


    mainContent: MSP_SettingSelection {
        id: mainContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.rightMargin: 15
        width: parent.width

    }


    // Main content area (left side - 58%)
    
    sidePanel : ScrollView {
        id: sidePanelScroll
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left
        width: parent.width
        contentHeight: sidePanel.height

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        // Content changes based on selected view
        MSP_SettingPanel {
            id: sidePanel
        }
    }
}
