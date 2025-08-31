import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: titleBar
    property string activeFilter: ""
    property string searchText: ""
    property bool isExpanded : false
    onActiveFilterChanged: {
        console.log("active filter changed", activeFilter)
    }


    anchors.margins: 10
    anchors.rightMargin: 6
    spacing: 15

    height: isExpanded ? 40 : 0



}
