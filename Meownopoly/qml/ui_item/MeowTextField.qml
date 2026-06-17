import QtQuick
import QtQuick.Controls
import theme

/*
 * MeowTextField — champ texte stylé canonique des panneaux de l'éditeur.
 *
 * Factorise le bloc TextField + background + border focus animée recopié dans
 * ZCP/CCPS/etc. Ne porte PAS de label (à placer dans la cellule de grille ou via
 * MeowPropertyRow) afin de rester insérable dans n'importe quel layout.
 *
 * Le call-site garde la maîtrise des handlers (onEditingFinished, Keys.*) :
 * seul le style est mutualisé. Couleurs surchargeables pour les rares variantes
 * (fond surface au lieu de background, border claire).
 */
TextField {
    id: control

    // Variantes de couleur (défauts = usage le plus fréquent, cf. ZCP_GeneralSection).
    property color fieldColor: Theme.background
    property color borderColor: Theme.border
    property color focusBorderColor: Theme.accentAlt

    color: Theme.textPrimary
    font.pixelSize: Theme.fontSizeSmall
    padding: Theme.spacingS

    background: Rectangle {
        color: control.fieldColor
        radius: Theme.radiusXS
        border.color: control.activeFocus ? control.focusBorderColor : control.borderColor
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
    }
}
