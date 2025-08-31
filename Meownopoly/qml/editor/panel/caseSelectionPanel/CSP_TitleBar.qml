import QtQuick 2.15

import "../"
import "../editorBottomPanel"


EBP_TitleBar {
    id: titleBar
    property string currentSelectedCategory: ""
    property string currentSelectedType: ""
    property string currentSelectedId: ""
    signal caseSelected(string category, string type, string id)
    required property string currentView // "categories" or "assets"

    titleText: "Case Library"
    subTitleText: titleBar.currentSelectedId !== "" ?
                      "Selected: " + titleBar.currentSelectedType + " #" + titleBar.currentSelectedId :
                      "Click to select a case"
    subTitleColor: titleBar.currentSelectedId !== "" ? "#4CAF50" : "#999999"
    buttonModel: ["All"]

    onButtonClicked: function(text, index) {
        console.log(index, "filter button clicked", text)
        titleBar.activeFilter = text
        titleBar.currentView = "categories"
    }


    backButton.visible: titleBar.isExpanded && (titleBar.currentView === "cases" || titleBar.currentView === "types")
    // backButton.Layout.column: 0
    onBackButtonClicked: {
        titleBar.currentView = "categories"
    }

    // Clear selection button (visible when case is selected)
    CSP_ClearButton {
        id: clearButton
        visible: titleBar.isExpanded && titleBar.currentSelectedId !== ""
        onClicked: {
            titleBar.caseSelected("", "", "")
        }
    }


}
