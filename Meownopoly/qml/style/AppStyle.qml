pragma Singleton
import QtQuick 2.12

QtObject {
    id:style
    property bool darkEnable: false
    property color primary: "#4f5af8"
    property color primaryAccentLight: Qt.darker(primary,1.1)
    property color primaryAccentDark: Qt.lighter(primary,1.1)
    property color backgroundDark: "#12111D"
    property color backgroundLight: "#fefffe"
    property color backgroundButDark: "#161425"
    property color backgroundButLight: "#fbfdfe"
    property color textDark: "#03120e"
    property color textLight: "#fef9ff"
    property color valid: "#0aae59"
    property color validDark: "#088243"
    property color cancel: "#ff4769"
    property color cancelDark: "#922038"
    property color buttonDown: "#d7dae5"
    property color listSelectedBackgroundDark : "#2D3166"
    property color listSelectedBackgroundLight : "#A79DFF"
    property color globalListSelectedBackground : (darkEnable)?listSelectedBackgroundDark : listSelectedBackgroundLight
    property color globalBackground : (darkEnable)?backgroundDark : backgroundLight
    property color globalText: (darkEnable) ? textLight : textDark
    property color globalPrimaryAccent: (darkEnable) ? primaryAccentLight : primaryAccentDark
    property color globalInvertPrimaryAccent: (darkEnable) ? primaryAccentDark : primaryAccentLight
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
