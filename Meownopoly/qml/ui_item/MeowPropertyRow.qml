import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

/*
 * MeowPropertyRow — ligne « label + contrôle » alignée des panneaux plats.
 *
 *   MeowPropertyRow {
 *       label: "Mode Exclusion:"
 *       MeowSwitch { onToggled: ... }        // contrôle ajouté après le label
 *   }
 *
 * Le(s) contrôle(s) déclarés par l'appelant s'ajoutent après le Label interne
 * (comportement natif des enfants par défaut). Pour qu'un contrôle occupe la
 * largeur restante, lui mettre `Layout.fillWidth: true`.
 *
 * Pour les panneaux en GridLayout 2 colonnes (ex: ZCP_GeneralSection), garder la
 * grille et n'utiliser que les contrôles (MeowSwitch/MeowSlider) ; ce composant
 * vise les ColumnLayout plats où label et contrôle vont par paires.
 */
RowLayout {
    id: control

    property string label: ""
    property real labelWidth: Theme.px(120)
    property bool labelBold: true
    property color labelColor: Theme.textPrimary

    spacing: Theme.spacingL

    Label {
        text: control.label
        color: control.labelColor
        font.pixelSize: Theme.fontSizeSmall
        font.bold: control.labelBold
        verticalAlignment: Text.AlignVCenter
        Layout.preferredWidth: control.labelWidth
        Layout.alignment: Qt.AlignVCenter
    }
}
