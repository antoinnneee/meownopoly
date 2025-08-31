import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

RowLayout {
    anchors.margins: 10
    anchors.rightMargin: 6
    spacing: 15

    property bool isExpanded : false
    height: isExpanded ? 40 : 0


}
