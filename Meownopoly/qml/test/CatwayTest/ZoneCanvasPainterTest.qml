// Harness isolé pour tester le composant ZoneCanvasPainter (Qt 6.11+).
// Affiche une zone polygonale avec fill + stroke + hachures, dessinée via
// la nouvelle API QtCanvasPainter (rendu GPU). Ne fait pas partie du flow
// éditeur : à brancher manuellement dans CatwayTest si on veut le voir.
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import MeowPainter 1.0
import theme

Rectangle {
    id: root
    color: Theme.background
    implicitWidth: 600
    implicitHeight: 480

    // Polygone test : un pentagone en coordonnées de "grille"
    property var demoPoints: [
        { x: 1.0, y: 1.0 },
        { x: 5.0, y: 1.5 },
        { x: 6.0, y: 4.0 },
        { x: 3.0, y: 6.0 },
        { x: 0.5, y: 4.0 }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingM

        Label {
            text: "Test ZoneCanvasPainter (Qt 6.11 CanvasPainter)"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
        }

        RowLayout {
            spacing: Theme.spacingXL
            Label { text: "gridSize: " + gridSlider.value.toFixed(1); color: Theme.textPrimary }
            Slider {
                id: gridSlider
                from: 10
                to: 80
                value: 40
                Layout.preferredWidth: 200
            }
            Label { text: "hatchSpacing: " + hatchSlider.value.toFixed(0); color: Theme.textPrimary }
            Slider {
                id: hatchSlider
                from: 4
                to: 30
                value: 12
                Layout.preferredWidth: 200
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#101010"
            border.color: Theme.border

            ZoneCanvasPainter {
                id: zone
                anchors.centerIn: parent
                width: 400
                height: 320
                polygonPoints: root.demoPoints
                gridSize: gridSlider.value
                zoneColor: "#FF5722"
                strokeColor: Qt.darker("#FF5722", 1.3)
                strokeWidth: 2
                hatchSpacing: hatchSlider.value
            }
        }

        Label {
            text: "→ Si tu vois le pentagone (orange + contour + hachures), CanvasPainter fonctionne."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
