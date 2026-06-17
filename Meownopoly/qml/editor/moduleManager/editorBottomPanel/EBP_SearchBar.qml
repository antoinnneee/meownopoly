import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import AssetManager
import theme

TextField {
    placeholderText: "Search assets..."
    signal focusReleased()
    background: Rectangle {
        color: Theme.border
        border.color: Theme.textDisabled
        border.width: 1
        radius: Theme.radiusS
    }

    color: Theme.textPrimary

    Keys.onReturnPressed: {
        focus = false
        focusReleased()
    }

}
