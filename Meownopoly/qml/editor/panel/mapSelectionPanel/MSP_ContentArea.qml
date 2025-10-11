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

    // property string currentView: "general" // "general", "saveLoad", or "background"
    Component.onCompleted:{
        currentView = "general"
    }
    onCurrentViewChanged: {
        sidePanel.getContentHeight()
        sidePanelScroll.height = sidePanel
    }

    mainContent: MSP_SettingSelection {
        id: mainContent
        anchors.fill: parent
    }


    // Main content area (left side - 58%)
    
    sidePanel : ScrollView {
        id: sidePanelScroll
        anchors.fill: parent
        contentHeight: sidePanel.height

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        // Content changes based on selected view
        MSP_SettingPanel {
            id: sidePanel
        }
    }
}
