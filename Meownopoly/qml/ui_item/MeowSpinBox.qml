import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

/*
 * MeowSpinBox — spin box numérique canonique des panneaux de l'éditeur.
 *
 * Promu depuis CCP_StyledSpinBox. Boutons ± latéraux, champ central éditable,
 * auto-repeat au maintien, formatage des milliers, suffixe d'unité.
 * Valeurs ENTIÈRES (prix, loyers, perks…). Émet `valueChanged()` à la main.
 */
Item {
    id: root

    // Properties
    property int from: 0
    property int to: 9999
    property int value: 0
    property int stepSize: 1
    property bool editable: true
    property string suffix: "K"

    implicitHeight: 32
    implicitWidth: 150

    // Main container
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Theme.radiusS
        border.color: textField.activeFocus ? Theme.accentAlt : Theme.border
        border.width: 1

        Behavior on border.color {
            ColorAnimation { duration: Theme.durationNormal }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Decrease button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                color: decreaseArea.pressed ? Theme.surfaceAlt : (decreaseArea.containsMouse ? Theme.surface : "transparent")
                radius: Theme.radiusS

                Behavior on color {
                    ColorAnimation { duration: Theme.durationFast }
                }

                Text {
                    anchors.centerIn: parent
                    text: "−"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: root.value > root.from ? Theme.textSecondary : Theme.textDisabled
                }

                MouseArea {
                    id: decreaseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.value > root.from

                    onClicked: {
                        if (root.value > root.from) {
                            root.value = Math.max(root.from, root.value - root.stepSize)
                            root.valueChanged()
                        }
                    }

                    // Auto-repeat on press and hold
                    onPressAndHold: {
                        repeatTimer.targetValue = -1
                        repeatTimer.start()
                    }

                    onReleased: {
                        repeatTimer.stop()
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Theme.spacingXS
                Layout.bottomMargin: Theme.spacingXS
                color: Theme.surfaceAlt
            }

            // Text input field
            TextField {
                id: textField
                Layout.fillWidth: true
                Layout.fillHeight: true

                text: formatNumber(root.value) + root.suffix
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true

                readOnly: !root.editable
                selectByMouse: true

                background: Rectangle {
                    color: "transparent"
                }

                validator: IntValidator {
                    bottom: root.from
                    top: root.to
                }

                onEditingFinished: {
                    // Enlever les espaces et le suffixe pour parser
                    var cleanText = text.replace(root.suffix, "").replace(/\s/g, "")
                    var newValue = parseInt(cleanText)
                    if (!isNaN(newValue)) {
                        root.value = Math.max(root.from, Math.min(root.to, newValue))
                        text = formatNumber(root.value) + root.suffix
                        root.valueChanged()
                    } else {
                        text = formatNumber(root.value) + root.suffix
                    }
                }

                onActiveFocusChanged: {
                    if (activeFocus) {
                        selectAll()
                    }
                }

                Keys.onUpPressed: {
                    root.value = Math.min(root.to, root.value + root.stepSize)
                    root.valueChanged()
                }

                Keys.onDownPressed: {
                    root.value = Math.max(root.from, root.value - root.stepSize)
                    root.valueChanged()
                }
            }

            // Separator
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Theme.spacingXS
                Layout.bottomMargin: Theme.spacingXS
                color: Theme.surfaceAlt
            }

            // Increase button
            Rectangle {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                color: increaseArea.pressed ? Theme.surfaceAlt : (increaseArea.containsMouse ? Theme.surface : "transparent")
                radius: Theme.radiusS

                Behavior on color {
                    ColorAnimation { duration: Theme.durationFast }
                }

                Text {
                    anchors.centerIn: parent
                    text: "+"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: root.value < root.to ? Theme.textSecondary : Theme.textDisabled
                }

                MouseArea {
                    id: increaseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.value < root.to

                    onClicked: {
                        if (root.value < root.to) {
                            root.value = Math.min(root.to, root.value + root.stepSize)
                            root.valueChanged()
                        }
                    }

                    // Auto-repeat on press and hold
                    onPressAndHold: {
                        repeatTimer.targetValue = 1
                        repeatTimer.start()
                    }

                    onReleased: {
                        repeatTimer.stop()
                    }
                }
            }
        }
    }

    // Timer for auto-repeat
    Timer {
        id: repeatTimer
        interval: 100
        repeat: true
        property int targetValue: 0

        onTriggered: {
            if (targetValue > 0 && root.value < root.to) {
                root.value = Math.min(root.to, root.value + root.stepSize)
                root.valueChanged()
            } else if (targetValue < 0 && root.value > root.from) {
                root.value = Math.max(root.from, root.value - root.stepSize)
                root.valueChanged()
            }
        }
    }

    // Function to format number with thousands separator
    function formatNumber(num) {
        return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ")
    }
}
