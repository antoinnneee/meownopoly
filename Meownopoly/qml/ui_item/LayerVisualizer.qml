import QtQuick 2.15

// Sélecteur de zLayer compact, tactile, contrôlé au drag.
// - Badge carré/arrondi (~9 mm) affichant "Z<n>" + couleur codée par couche.
// - Drag vertical : vers le haut = couche supérieure, ~1 cm par niveau.
// - Aucun menu : la sélection commit au relâchement.
Item {
    id: control

    property int maxLayer: 10
    property int selectedLayer: 0

    // Cible tactile ~9 mm, min 32 px pour garder une lisibilité souris
    readonly property real badgeSize: Math.max(32, Screen.pixelDensity * 9)
    // Pas de drag : ~1 cm = 1 couche
    readonly property real dragStepPx: Math.max(18, Screen.pixelDensity * 6)

    signal layerClicked(var index)

    implicitWidth: badgeSize
    implicitHeight: badgeSize
    width: implicitWidth
    height: implicitHeight

    // Preview pendant le drag ; -1 = pas de drag actif
    property int _previewLayer: -1
    readonly property int _displayLayer: _previewLayer >= 0 ? _previewLayer : selectedLayer

    // Code couleur : teinte HSV étalée 0 → 0.85 (évite que max et min retombent sur du rouge)
    function colorForLayer(i) {
        if (i < 0 || i >= maxLayer) return "#888888"
        var hue = (maxLayer > 1) ? (i * 0.85 / (maxLayer - 1)) : 0
        return Qt.hsva(hue, 0.6, 0.9, 1.0)
    }

    Rectangle {
        id: badge
        anchors.fill: parent
        radius: Math.min(width, height) * 0.25
        color: control.colorForLayer(control._displayLayer)
        border.color: dragHandler.active ? "white" : "#2c2030"
        border.width: dragHandler.active ? 2 : 1
        scale: dragHandler.active ? 1.08 : 1.0

        Behavior on color       { ColorAnimation  { duration: 90 } }
        Behavior on border.width { NumberAnimation { duration: 80 } }
        Behavior on scale       { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        // Jauge verticale interne : montre la position de la couche dans la pile
        Rectangle {
            width: 3
            height: parent.height * 0.72
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.verticalCenter: parent.verticalCenter
            radius: 1.5
            color: "#30000000"

            Rectangle {
                width: parent.width
                height: parent.height / control.maxLayer
                // layer 1 (index 0) → bas ; layer max → haut
                y: parent.height - height - (parent.height - height) * control._displayLayer / Math.max(1, control.maxLayer - 1)
                radius: 1.5
                color: "white"
                opacity: 0.95
                Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "Z" + (control._displayLayer + 1)
            color: "white"
            font.bold: true
            font.pixelSize: Math.round(parent.height * 0.38)
            style: Text.Outline
            styleColor: "#60000000"
        }

        // État interne du drag
        property int  _startLayer: 0
        property real _startY: 0

        DragHandler {
            id: dragHandler
            target: null
            xAxis.enabled: false
            yAxis.enabled: true
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchScreen | PointerDevice.Stylus

            onActiveChanged: {
                if (active) {
                    badge._startLayer = control.selectedLayer
                    badge._startY = centroid.scenePosition.y
                    control._previewLayer = control.selectedLayer
                } else {
                    var committed = control._previewLayer
                    control._previewLayer = -1
                    if (committed >= 0 && committed !== control.selectedLayer) {
                        control.layerClicked(committed)
                    }
                }
            }

            onCentroidChanged: {
                if (!active) return
                var dy = centroid.scenePosition.y - badge._startY
                // drag vers le haut = couche supérieure
                var steps = Math.round(-dy / control.dragStepPx)
                control._previewLayer = Math.max(0, Math.min(control.maxLayer - 1, badge._startLayer + steps))
            }
        }
    }
}
