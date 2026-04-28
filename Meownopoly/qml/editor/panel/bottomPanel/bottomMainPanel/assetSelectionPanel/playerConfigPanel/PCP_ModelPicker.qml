import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AssetManager

/*
 * Sélecteur de modèle 3D : PCP_StyledComboBox + bouton ↻ pour rescanner.
 * Le label "Modèle 3D" est laissé au parent (variable selon le layout).
 * Source : AssetManager.availablePlayerModels() (QRC + AppData + primitives).
 */
RowLayout {
    id: root

    property string currentModel: ""
    signal modelSelected(string name)

    spacing: 4

    PCP_StyledComboBox {
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
        onClicked: combo.model = AssetManager.availablePlayerModels()
    }
}
