import QtQuick 2.15

Rectangle {

    property bool isExpanded: true
    required property var logic


    // Filter Properties
    property string currentView: "categories" // "categories" or "assets"
    property string searchText: ""

    // Dimensions
    readonly property int collapsedHeight: 0
    readonly property int expandedHeight: 400
    readonly property int animationDuration: 200
    // State management
    height: isExpanded ? expandedHeight : collapsedHeight

    color: "#E6000000" // Semi-transparent black
    border.color: "#333333"
    border.width: 1

    // Smooth height animation
    Behavior on height {
        NumberAnimation {
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
    }
}
