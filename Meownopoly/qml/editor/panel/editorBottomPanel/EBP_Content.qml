import QtQuick 2.15

Item {
    property bool isExpended: false
    property string currentView: "categories"

    property string searchText: ""
    required property string activeFilter


    visible: isExpanded
    opacity: isExpanded ? 1.0 : 0.0

}
