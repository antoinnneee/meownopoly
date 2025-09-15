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

    mainContent: MSP_SettingSelection {
        id: mainContent
    }


    // Main content area (left side - 58%)
    
    sidePanel : ScrollView {
        id: secondContent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: parent.width

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded

        // Content changes based on selected view
        MSP_SettingPanel {
            id: contentContainer
        }
    }
}
