import QtQuick 2.12

Rectangle {
    id: rectangle
    width: 200
    height: 200
    border.color: (AppStyle.darkEnable) ? Qt.lighter(AppStyle.primary, 1.1) : Qt.darker(AppStyle.primary, 1.1)

    color: AppStyle.globalBackground

}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
