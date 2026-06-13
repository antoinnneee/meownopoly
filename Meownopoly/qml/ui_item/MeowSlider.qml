import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

/*
 * MeowSlider — slider étiqueté canonique des panneaux de l'éditeur.
 *
 * Unifie VEP_Slider, SEP_Slider et les sliders inline de ZCP_GeneralSection.
 * Deux modèles d'interaction coexistent (le call-site branche celui qu'il veut) :
 *   - live          : `moved(real v)` à chaque déplacement (aperçu immédiat).
 *   - transactionnel : `gestureBegan()` / `moved(v)` / `gestureCommitted()`
 *                      (snapshot au début du geste, un seul delta committé → undo/save).
 *
 * Présentation paramétrable :
 *   - `label` interne optionnel ("" = pas de label, ex: cellule de GridLayout externe).
 *   - valeur en encadré (`boxedValue`) ou en texte simple.
 *   - `unitText` préfixe la valeur (ex: "×"), `accentColor` colore piste/poignée/bord.
 *   - `resettable` ajoute un bouton Reset → `resetValue`.
 */
RowLayout {
    id: control

    property string label: ""
    property real labelWidth: 0          // 0 = largeur naturelle
    property bool labelBold: true

    property alias from: slider.from
    property alias to: slider.to
    property alias value: slider.value
    property alias stepSize: slider.stepSize
    property alias snapMode: slider.snapMode

    property int decimals: 2
    property string unitText: ""         // préfixe affiché devant la valeur
    property color accentColor: Theme.accentAlt
    property bool boxedValue: true       // valeur en encadré (sinon texte simple)
    property bool showValue: true        // false = l'appelant fournit son propre afficheur/champ
    property real valueWidth: Theme.px(45)

    property bool resettable: false
    property real resetValue: 0

    signal moved(real value)
    signal gestureBegan()
    signal gestureCommitted()

    spacing: Theme.spacingM

    Label {
        visible: control.label !== ""
        text: control.label
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeSmall
        font.bold: control.labelBold
        verticalAlignment: Text.AlignVCenter
        Layout.preferredWidth: control.labelWidth > 0 ? control.labelWidth : implicitWidth
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        from: 0; to: 1; value: 0

        onMoved: control.moved(value)
        onPressedChanged: pressed ? control.gestureBegan() : control.gestureCommitted()

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 100
            implicitHeight: 4
            width: slider.availableWidth
            height: implicitHeight
            radius: 2
            color: Theme.surfaceHover

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: control.accentColor
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 14
            implicitHeight: 14
            radius: 7
            color: "#ffffff"
            border.color: control.accentColor
            border.width: 2
        }
    }

    // Valeur — encadré (défaut) ou texte simple.
    Rectangle {
        visible: control.showValue && control.boxedValue
        Layout.preferredWidth: control.valueWidth
        Layout.preferredHeight: Theme.px(26)
        radius: Theme.radiusS
        color: Theme.surface
        border.color: control.accentColor
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: control.unitText + slider.value.toFixed(control.decimals)
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
    }

    Text {
        visible: control.showValue && !control.boxedValue
        text: control.unitText + slider.value.toFixed(control.decimals)
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeCaption
        Layout.preferredWidth: control.valueWidth
        horizontalAlignment: Text.AlignRight
    }

    Button {
        id: resetBtn
        visible: control.resettable
        text: "Reset"
        Layout.preferredWidth: Theme.px(56)
        Layout.preferredHeight: Theme.px(28)
        onClicked: {
            slider.value = control.resetValue
            control.moved(slider.value)
        }
        background: Rectangle {
            color: resetBtn.pressed ? Theme.hover(Theme.borderLight) : Theme.borderLight
            radius: Theme.radiusS
        }
        contentItem: Text {
            text: resetBtn.text
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
