import QtQuick 2.15
import QtQuick.Particles
import QtQuick.Controls
import AssetManager

Rectangle {
    id: root

    // --- Properties ---
    property bool blockEffectChangedSignal: false
    onBlockEffectChangedSignalChanged: {
        console.log("blockEffectChangedSignal changed for", blockEffectChangedSignal)
    }

    property bool effectLocked  // prevent set effect on panel

    property bool isExpanded: true
    property bool isResizing : false
    property var logic
    // required property EditorLogic logic

    // Filter Properties
    property string currentView: "categories" // "categories" or "assets"
    property string searchText: ""

    // Dimensions
    property int collapsedHeight: 0
    property int expandedHeight: 400

    // --- Aliases ---
    property alias visualEffectsPanel : content.effectsPanel
    property alias caseConfigurationPanel: content.caseConfigurationPanel
    property alias connectionsConfigurationPanel: content.connectionsConfigurationPanel
    property alias zoneConfigurationPanel: content.zoneConfigurationPanel

    // --- Signals ---
    signal effectChanged()
    signal connectionRequested(string kind)  // Propager les demandes de connexion
    signal modelSelected(string name)
    signal configurationChanged()

    // --- Bindings ---
    width : Screen.pixelDensity * 120
    height: Screen.pixelDensity * 75
    // height: isExpanded ? expandedHeight : collapsedHeight

    color: "#E6002200"
    border.color: "#333333"
    border.width: 1

    Behavior on height {
        NumberAnimation {
            duration: isResizing ? 0 : 50
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on x {
        NumberAnimation {
            duration: 300
            easing.type: Easing.InOutQuad
        }
    }

    // --- Items ---
    // Zone de redimensionnement
    Rectangle {
        id: resizeHandle
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 10
        color: resizeMouseArea.pressed ? "#E6333333" : "#E6000000"
        z: 15

        // Indicateur visuel subtil
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.3
            height: 2
            color: resizeMouseArea.containsMouse || root.isResizing ? "#4A90E2" : "#CCCCCC"
            radius: 1
        }

        MouseArea {
            id: resizeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            enabled: root.isExpanded

            property real startY: 0
            property real startHeight: 0

            property int minSize : 100
            property int maxSize : root.parent.height

            property bool isHorizontal: false
            // property bool isStart: modelData.isStart
            property bool isStart: true

            property real startSize: 0
            property real startRootPos: 0
            property point startGlobalPos: Qt.point(0, 0)


            onPressed: function(mouse) {
                isResizing = true
                // Capturer les valeurs initiales
                startSize = isHorizontal ? root.width : root.height
                startRootPos = isHorizontal ? root.x : root.y

                // Utiliser les coordonnées globales (par rapport au parent de root)
                var globalPos = mapToItem(root.parent, mouse.x, mouse.y)
                startGlobalPos = Qt.point(globalPos.x, globalPos.y)
            }


            onPositionChanged: function(mouse) {
                if (pressed) {
                    isResizing = true
                    // Coordonnées globales actuelles
                    var globalPos = mapToItem(root.parent, mouse.x, mouse.y)

                    // Calculer le delta depuis le début
                    var delta = isHorizontal ?
                        (globalPos.x - startGlobalPos.x) :
                        (globalPos.y - startGlobalPos.y)

                    var newSize = isStart ? startSize - delta : startSize + delta
                    var minSize = resizeMouseArea.minSize
                    var maxSize = resizeMouseArea.maxSize

                    if (newSize >= minSize && newSize <= maxSize) {
                        if (isHorizontal) {
                            root.width = newSize
                            if (isStart) {
                                root.x = startRootPos + delta
                            }
                        } else {
                            root.height = newSize
                            if (isStart) {
                                root.y = startRootPos + delta
                            }
                        }
                    }
                }
                isResizing = false
            }
        }

        // Animation de couleur au survol
        Behavior on color { ColorAnimation { duration: 150 }}
    }

    ParticleSystem {
        id: particleSystem
        anchors.fill: parent
        clip: true
        // Emitter for the initial burst
        Emitter {
            id: burstEmitter
            enabled: true
            anchors.fill: parent
            lifeSpan: 2000
            size: 50
            emitRate: 15
            velocity: AngleDirection {
                angle: 270
                angleVariation: 15
                magnitude: 200
                magnitudeVariation: 50
            }
        }

        // Particle image for the initial burst
        ImageParticle {
            id: firework
            source : AssetManager.getAssetById("ui","particules","pawn1").path
            color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1)
            colorVariation: 0.5
            alpha: 0.75
            rotationVariation: 360
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            burstEmitter.burst(1);
            firework.color = Qt.rgba(Math.random(), Math.random(), Math.random(), 1);
        }
    }

    ScrollView {
        id: scrollView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: resizeHandle.bottom
        anchors.bottom: parent.bottom
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.width: content.effectsPanel.rightPadding
        clip: true
        BottomSidePanel_Content {
            id: content
            logic: root.logic
            width: scrollView.width

            onEffectChanged: {
                console.log("effect changed")
                if(root.blockEffectChangedSignal)
                {
                    console.log("apply effect cancel")
                    return;
                }
                console.log("apply effect changed")
                root.effectChanged()
            }
            onConnectionRequested: function(kind) {
                root.connectionRequested(kind)
            }
            onModelSelected: function(name) {
                root.modelSelected(name)
            }
            onConfigurationChanged: {
                root.configurationChanged()
            }
        }
    }

    // --- Functions ---
    function updateFromDisplayParameter(dispParam) {
        console.log("updateFromDisplayParameter")
        if (effectLocked){
            effectChanged()
        }
        else
        {

            root.blockEffectChangedSignal = true
            visualEffectsPanel.updateFromDisplayParameter(dispParam)
            root.blockEffectChangedSignal = false
        }
    }

    // --- Functions ---
    function updateSidePanel(snapableParameter) {
        root.blockEffectChangedSignal = true

        visualEffectsPanel.updateFromDisplayParameter(snapableParameter.displayParameter)
        zoneConfigurationPanel.updateFromZoneParameter(snapableParameter.zoneParameter)
       root. blockEffectChangedSignal = false
    }
}
