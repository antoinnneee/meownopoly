import QtQuick 2.15
import QtQuick.Particles
import AssetManager

Rectangle {
    id: root

    property bool isExpanded: true
    required property EditorLogic logic


    property alias contentArea: contentPlaceHolder.children

    property alias titleBar: titlePlaceHolder.children

    // Filter Properties
    property string currentView: "categories" // "categories" or "assets"
    property string searchText: ""

    // Dimensions
    property int collapsedHeight: 0
    property int expandedHeight: 400

    // State management
    height: isExpanded ? expandedHeight : collapsedHeight

    color: "#E6000000" // Semi-transparent black
    border.color: "#333333"
    border.width: 1
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
    Item{
        id: titlePlaceHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: {
            return (children.length > 0) ? children[0].height + 10 : 0
        }
    }

    Item{
        id: contentPlaceHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titlePlaceHolder.bottom
        anchors.bottom: parent.bottom
    }
}
