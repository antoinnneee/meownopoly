import QtQuick 2.15

Rectangle {
    id: root

    property bool isExpanded: true
    required property var logic


    property alias contentArea: contentPlaceHolder.children

    property alias titleBar: titlePlaceHolder.children
    // Filter Properties
    property string currentView: "categories" // "categories" or "assets"
    property string searchText: ""

    // Dimensions
    property int collapsedHeight: 0
    property int expandedHeight: 400

    // State management
    height: isExpanded ? expandedHeight : collapsedHeight

    color: "#E6000000" // Semi-transparent black
    border.color: "#333333"
    border.width: 1

    Item{
        id: titlePlaceHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: {
            return (children.length > 0) ? children[0].height + 10 : 0
        }
    }

    Item{
        id: contentPlaceHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titlePlaceHolder.bottom
        anchors.bottom: parent.bottom
        }


}
