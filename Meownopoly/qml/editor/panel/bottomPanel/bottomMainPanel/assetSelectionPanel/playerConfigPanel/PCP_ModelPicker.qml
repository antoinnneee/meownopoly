import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AssetManager

/*
 * ComboBox de sélection du modèle 3D pour un PlayerProfile.
 * Source : AssetManager.availablePlayerModels() (QRC + AppData + primitives).
 */
RowLayout {
    id: root

    property string currentModel: ""
    signal modelSelected(string name)

    spacing: Screen.pixelDensity * 2

    Label {
        text: "Modèle 3D"
        color: "#cccccc"
        font.pixelSize: Math.round(Screen.pixelDensity * 3)
    }

    ComboBox {
        id: combo
        Layout.fillWidth: true
        model: AssetManager.availablePlayerModels()

        Component.onCompleted: _syncToCurrent()

        function _syncToCurrent() {
            if (!root.currentModel) { currentIndex = 0; return }
            const idx = combo.find(root.currentModel)
            currentIndex = idx >= 0 ? idx : 0
        }

        Connections {
            target: root
            function onCurrentModelChanged() { combo._syncToCurrent() }
        }

        onActivated: {
            if (currentText !== root.currentModel)
                root.modelSelected(currentText)
        }
    }

    PCP_StyledButton {
        text: "↻"
        ToolTip.visible: hovered
        ToolTip.text: "Recharger la liste de modèles"
        Layout.preferredWidth: 32
        onClicked: {
            const cur = combo.currentText
            combo.model = AssetManager.availablePlayerModels()
            combo._syncToCurrent()
        }
    }
}
