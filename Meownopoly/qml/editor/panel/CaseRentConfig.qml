import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
    title: "Prix de Location"
    
    visible: targetCase && targetCase.type === Case.CS_RestArea

    ColumnLayout{
        anchors.fill: parent
        spacing: 8
        // Note explicative
        Text {
            text: "💡 Définissez les prix de location selon le niveau d'amélioration de la propriété"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Prix terrain nu à 4 étoiles
        Repeater {
            model: [
                { index: 0, label: "🏞️ Terrain nu:", step: 5, color: "#495057", bold: true },
                { index: 1, label: "⭐ 1 étoile:", step: 5, color: "#495057", bold: true },
                { index: 2, label: "⭐⭐ 2 étoiles:", step: 5, color: "#495057", bold: true },
                { index: 3, label: "⭐⭐⭐ 3 étoiles:", step: 5, color: "#495057", bold: true },
                { index: 4, label: "⭐⭐⭐⭐ 4 étoiles:", step: 5, color: "#495057", bold: true }
            ]

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: modelData.label
                    font.bold: modelData.bold
                    Layout.preferredWidth: 120
                    color: modelData.color
                }

                SpinBox {
                    Layout.fillWidth: true
                    from: 0
                    to: 10000
                    stepSize: modelData.step

                    property int rentIndex: modelData.index

                    textFromValue: function(value, locale) {
                        return value + "K"
                    }

                    valueFromText: function(text, locale) {
                        return parseInt(text.replace("K", ""))
                    }

                    Component.onCompleted: {
                        if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                            value = targetCase.rentPrice[rentIndex]
                        }
                    }

                    onValueChanged: {
                        if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                            targetCase.rentPrice[rentIndex] = value
                        }
                    }
                }
            }
        }
        // Séparateur visuel
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#dee2e6"
            Layout.topMargin: 5
            Layout.bottomMargin: 5
        }

        // Hôtel
        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "🏨 Hôtel:"
                font.bold: true
                Layout.preferredWidth: 120
                color: "#dc3545"
                font.pixelSize: 16
            }

            SpinBox {
                Layout.fillWidth: true
                from: 0
                to: 10000
                stepSize: 10

                textFromValue: function(value, locale) {
                    return value + "K"
                }

                valueFromText: function(text, locale) {
                    return parseInt(text.replace("K", ""))
                }

                Component.onCompleted: {
                    if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > 5) {
                        value = targetCase.rentPrice[5]
                    }
                }

                onValueChanged: {
                    if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > 5) {
                        targetCase.rentPrice[5] = value
                    }
                }
            }
        }
    }
}
