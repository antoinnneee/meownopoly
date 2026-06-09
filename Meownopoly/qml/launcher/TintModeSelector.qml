/*
 * TintModeSelector.qml — sélecteur segmenté à 3 positions pour le mode de
 * teinte Color ID Map : A (Aplat) / × (Multiply) / O (Overlay).
 *
 * Chaque position a sa couleur ; le segment actif est rempli, les autres
 * restent sombres. Émet picked(mode) au clic — le parent applique la valeur
 * (on ne mute pas `mode` en interne pour rester pilotable par binding).
 */
import QtQuick
import QtQuick.Controls

Rectangle {
    id: sel

    property int mode: 0
    signal picked(int newMode)

    readonly property var _labels: ["A", "×", "O"]
    readonly property var _names:  ["Aplat", "Multiply", "Overlay"]
    readonly property var _colors: ["#3b82f6", "#f59e0b", "#a855f7"]  // A bleu / × ambre / O violet

    implicitWidth: 99
    implicitHeight: 26
    radius: 5
    clip: true
    color: "#26262b"
    border.color: "#52525b"
    border.width: 1

    Row {
        anchors.fill: parent

        Repeater {
            model: 3
            delegate: Item {
                required property int index
                width: Math.round(sel.width / 3)
                height: sel.height

                // Remplissage du segment actif (couleur propre à la position).
                Rectangle {
                    anchors.fill: parent
                    color: sel.mode === index ? sel._colors[index] : "transparent"
                }
                // Séparateur entre segments.
                Rectangle {
                    visible: index > 0
                    width: 1; height: parent.height
                    color: "#52525b"
                }
                Text {
                    anchors.centerIn: parent
                    text: sel._labels[index]
                    color: sel.mode === index ? "white" : "#9ca3af"
                    font.bold: true
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sel.picked(index)
                    ToolTip.text: sel._names[index]
                    ToolTip.visible: containsMouse
                    ToolTip.delay: 400
                }
            }
        }
    }
}
