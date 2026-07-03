import QtQuick
import QtQuick.Layouts
import theme

// Header de l'inspecteur : icône + libellé du type de l'élément sélectionné,
// ou bandeau « N éléments » en multi-sélection. Le nom éditable et le
// sélecteur de type de case (MeowComboBox) arrivent en Phase 2.
Rectangle {
    id: root

    property string icon: ""
    property string typeLabel: ""
    property int selectionCount: 0

    implicitHeight: headerRow.implicitHeight + Theme.spacingM * 2
    color: Theme.surfaceAlt
    topLeftRadius: Theme.radiusL

    RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingS

        Text {
            text: root.selectionCount > 1 ? "▣" : root.icon
            font.pixelSize: Theme.px(20)
        }

        Text {
            Layout.fillWidth: true
            text: root.selectionCount > 1
                  ? root.selectionCount + " éléments"
                  : root.typeLabel
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            elide: Text.ElideRight
        }
    }
}
