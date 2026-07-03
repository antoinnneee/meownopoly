import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme
import ui_item

/*
 * ZCP_TriggerSection — déclencheur "plaque de pression" d'une zone
 * (non-exclusion). Activé quand une caisse (PhysicalObjectTile) est poussée
 * dans la zone : les éléments liés (next) sont ouverts et la récompense
 * éventuelle est créditée via les modules de gameplay.
 *
 * Lier la zone aux éléments cibles avec l'outil de connexion standard
 * (zone --next--> porte / décoration).
 */
GroupBox {
    id: root
    title: "Déclencheur (plaque de pression)"

    property bool updatingValues: false

    readonly property int triggerMode: plateSwitch.checked ? 1 : 0
    readonly property bool triggerOnce: onceCheck.checked
    readonly property int rewardCurrency: rewardCurrencySpin.value
    readonly property string rewardItemName: rewardItemField.text
    readonly property int rewardItemQuantity: rewardQtySpin.value

    signal configurationChanged()
    signal focusReleased()

    function updateFromZoneParameter(zoneParam) {
        if (root.updatingValues) return
        plateSwitch.checked = zoneParam.triggerMode === 1
        onceCheck.checked = zoneParam.triggerOnce
        rewardCurrencySpin.value = zoneParam.rewardCurrency
        rewardItemField.text = zoneParam.rewardItemName
        rewardQtySpin.value = zoneParam.rewardItemQuantity
    }

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
        spacing: Theme.spacingS

        MeowPropertyRow {
            Layout.fillWidth: true
            label: "Plaque de pression"
            MeowSwitch {
                id: plateSwitch
                onCheckedChanged: if (!root.updatingValues) root.configurationChanged()
            }
        }

        MeowInfoBox {
            Layout.fillWidth: true
            visible: plateSwitch.checked
            text: "Poussez une caisse dans la zone pour activer les éléments " +
                  "liés (next) : une zone d'exclusion liée s'ouvre, une " +
                  "décoration liée s'estompe. Utilisez l'outil de connexion " +
                  "pour lier la zone à ses cibles."
        }

        MeowPropertyRow {
            Layout.fillWidth: true
            visible: plateSwitch.checked
            label: "Une seule fois"
            MeowCheckBox {
                id: onceCheck
                onCheckedChanged: if (!root.updatingValues) root.configurationChanged()
            }
        }

        MeowPropertyRow {
            Layout.fillWidth: true
            visible: plateSwitch.checked
            label: "Récompense 💰"
            MeowSpinBox {
                id: rewardCurrencySpin
                Layout.fillWidth: true
                from: 0; to: 99999; stepSize: 5; value: 0
                onValueChanged: if (!root.updatingValues) root.configurationChanged()
            }
        }

        MeowPropertyRow {
            Layout.fillWidth: true
            visible: plateSwitch.checked
            label: "Récompense objet"
            MeowTextField {
                id: rewardItemField
                Layout.fillWidth: true
                placeholderText: "Vide = aucun..."
                onEditingFinished: if (!root.updatingValues) root.configurationChanged()
            }
        }

        MeowPropertyRow {
            Layout.fillWidth: true
            visible: plateSwitch.checked && rewardItemField.text !== ""
            label: "Quantité objet"
            MeowSpinBox {
                id: rewardQtySpin
                Layout.fillWidth: true
                from: 1; to: 99; value: 1
                onValueChanged: if (!root.updatingValues) root.configurationChanged()
            }
        }
    }
}
