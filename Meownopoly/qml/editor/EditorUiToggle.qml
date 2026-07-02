import QtQuick
import QtQuick.Controls
import theme

// Badge de bascule entre l'interface classique et la nouvelle interface de
// l'éditeur. Toujours visible (dans les deux UIs) pour permettre de revenir en
// arrière. Le choix est persisté par l'appelant (QSettings Editor/UiConfig).
Rectangle {
    id: root

    // État courant (piloté par l'appelant via binding sur la valeur QSettings).
    property bool useNewUi: false

    // Émis au clic — l'appelant inverse et persiste la valeur.
    signal toggleRequested()

    implicitWidth: contentRow.implicitWidth + Theme.spacingL * 2
    implicitHeight: Theme.px(30)
    radius: height / 2
    color: hoverHandler.hovered ? Theme.hover(Theme.surfaceAlt) : Theme.surfaceAlt
    border.color: root.useNewUi ? Theme.accent : Theme.border
    border.width: 1
    opacity: 0.95

    Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "🎨"
            font.pixelSize: Theme.fontSizeBody
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.useNewUi ? "Nouvelle interface" : "Interface classique"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }

        // Petit indicateur d'état (pastille) façon interrupteur.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(10)
            height: Theme.px(10)
            radius: width / 2
            color: root.useNewUi ? Theme.accent : Theme.textDisabled
        }
    }

    HoverHandler { id: hoverHandler }

    TapHandler {
        onTapped: root.toggleRequested()
    }

    ToolTip.visible: hoverHandler.hovered
    ToolTip.text: "Basculer entre l'interface classique et la nouvelle interface"
    ToolTip.delay: 500
}
