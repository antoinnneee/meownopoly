import QtQuick
import QtQuick.Controls
import MyApp.Images
import AnimationProvider
import QtQuick.Effects

Rectangle {
    id: root
    width: 800
    height: 600
    color: "#2b2b2b"

    Repeater{
        model: 400
        LiveImage {
            required property int index
            width: 480
            height: 480
            x: index*6
            y: 0
            z: 400 - index


            MultiEffect {
                id: multiEffect
                anchors.fill: parent
                source: parent
                z: 2  // Above the source image but below handles
                visible: true


                // Color effects (always available)
                brightness: 1.2
                contrast: 1.2
                saturation: 1.2
                colorization: 0.8
                colorizationColor: "red"


                // Performance optimization: auto-padding management
                autoPaddingEnabled: false//displaySettings.effectBlurEnabled || displaySettings.effectShadowEnabled
            }

        }
    }

}
