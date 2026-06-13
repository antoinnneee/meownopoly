import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlayerProfile
import theme

/*
 * Sélecteur du PickMode + minOccurrences pour un PlayerProfile.
 *  - 3 RadioButton : Unique / Shared / Mandatory
 *  - SpinBox minOccurrences visible uniquement quand Mandatory
 *
 * Émet pickModeChanged(int) et minOccurrencesChanged(int) — le parent
 * applique la mutation au profil (via mutation directe + updateMapMetadata,
 * Phase 4 routera via op bus).
 */
ColumnLayout {
    id: root

    property int pickMode: PlayerProfile.Unique
    property int minOccurrences: 1

    signal pickModeRequested(int mode)
    signal minOccurrencesRequested(int n)

    spacing: Screen.pixelDensity * 1.5

    RowLayout {
        Layout.fillWidth: true
        spacing: Screen.pixelDensity * 3

        Label {
            text: "Mode de sélection"
            color: Theme.textSecondary
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
        }

        ButtonGroup { id: modeGroup }

        PCP_StyledRadioButton {
            id: rbUnique
            text: "Unique"
            ButtonGroup.group: modeGroup
            checked: root.pickMode === PlayerProfile.Unique
            onToggled: if (checked) root.pickModeRequested(PlayerProfile.Unique)
        }
        PCP_StyledRadioButton {
            id: rbShared
            text: "Shared"
            ButtonGroup.group: modeGroup
            checked: root.pickMode === PlayerProfile.Shared
            onToggled: if (checked) root.pickModeRequested(PlayerProfile.Shared)
        }
        PCP_StyledRadioButton {
            id: rbMandatory
            text: "Mandatory"
            ButtonGroup.group: modeGroup
            checked: root.pickMode === PlayerProfile.Mandatory
            onToggled: if (checked) root.pickModeRequested(PlayerProfile.Mandatory)
        }

        Item { Layout.fillWidth: true }

        Label {
            text: "min ×"
            color: Theme.textSecondary
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            visible: root.pickMode === PlayerProfile.Mandatory
        }
        PCP_StyledSpinBox {
            id: minOccSpin
            from: 1
            to: 8
            visible: root.pickMode === PlayerProfile.Mandatory
            editable: true

            // Binding "soft" pour ne pas être brisé par les modifs UI : on
            // s'assure que la valeur reste synchro avec root.minOccurrences
            // tant que l'utilisateur n'agit pas, via un Connections.
            Component.onCompleted: value = root.minOccurrences
            Connections {
                target: root
                function onMinOccurrencesChanged(n) {
                    if (minOccSpin.value !== n) minOccSpin.value = n
                }
            }
            onValueModified: {
                if (value !== root.minOccurrences)
                    root.minOccurrencesRequested(value)
            }
        }
    }
}
