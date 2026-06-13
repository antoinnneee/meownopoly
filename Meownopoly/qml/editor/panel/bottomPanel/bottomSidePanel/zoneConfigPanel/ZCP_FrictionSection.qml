import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme
import ui_item

GroupBox {
    id: root
    title: "Friction"
    
    // Properties
    property var targetZoneParameter: null
    property bool updatingValues: false
    
    // Signal
    signal configurationChanged()
    
    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusS
        border.color: Theme.border
        border.width: 1
    }

    label: Text {
        text: root.title
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeBody
        font.bold: true
        leftPadding: Theme.spacingM
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        // Note explicative
        MeowInfoBox {
            Layout.fillWidth: true
            fontSize: Theme.fontSizeSmall
            text: "🎯 Force de friction appliquée aux objets dans la zone"
        }
        
        // Friction Strength
        MeowSlider {
            id: frictionSlider
            Layout.fillWidth: true
            label: "Friction Strength:"
            labelWidth: 120
            labelBold: false
            from: 0.0
            to: 1.0
            stepSize: 0.01
            value: targetZoneParameter ? targetZoneParameter.frictionStrenght : 0.0
            decimals: 2

            onMoved: {
                if (!root.updatingValues && targetZoneParameter) {
                    targetZoneParameter.frictionStrenght = value
                    root.configurationChanged()
                }
            }
        }
    }
    
    // Function to update controls from the target
    function updateControls() {
        if (!targetZoneParameter) return
        
        updatingValues = true
        frictionSlider.value = targetZoneParameter.frictionStrenght
        console.log("friction updated", targetZoneParameter.frictionStrenght)
        updatingValues = false
    }
}
