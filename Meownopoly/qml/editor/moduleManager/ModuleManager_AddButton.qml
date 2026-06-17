import QtQuick
import QtQuick.Controls
import theme

// Bouton "+" du gestionnaire de modules. Sert à ajouter un nouveau module
// (= un "menu" de l'éditeur : Case, Decoration, Template/Scène, Zone, …).
// Style volontairement minimal : personnalisation prévue ultérieurement.
// Émet le signal hérité `clicked` de Button — câblé par le ModuleManager.
Button {
    id: control

    implicitWidth: Theme.px(32)
    implicitHeight: Theme.px(32)

    background: Rectangle {
        anchors.fill: parent
        radius: Theme.radiusS
        color: control.pressed ? Theme.pressed(Theme.surface)
             : control.hovered ? Theme.hover(Theme.surface)
                                : Theme.surface
        border.color: control.hovered ? Theme.borderLight : Theme.border
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
    }

    contentItem: Text {
        text: "+"
        color: Theme.textPrimary
        // Glyphe proportionnel à la taille du bouton (qui suit BtSideMenu).
        font.pixelSize: Math.max(Theme.fontSizeTitle, Math.round(control.height * 0.5))
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
