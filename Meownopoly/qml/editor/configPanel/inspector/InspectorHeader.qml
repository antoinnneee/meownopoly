import QtQuick
import QtQuick.Layouts
import Case
import MeowStyle
import ui_item
import theme

// Header de l'inspecteur : icône + libellé du type de l'élément sélectionné,
// ou bandeau « N éléments » en multi-sélection. Pour une case : nom éditable
// (MeowTextField) + sélecteur de type (MeowComboBox — remplace le ◀▶ de
// CCPS_TypeSection). Les mutations remontent à InspectorPanel via signaux.
Rectangle {
    id: root

    property string icon: ""
    property string typeLabel: ""
    property int selectionCount: 0
    // caseData de la case sélectionnée, ou null (active nom + combo type).
    property var targetCase: null
    property bool updatingValues: false

    signal nameEdited(string newName)
    signal caseTypeSelected(int newType)

    readonly property bool _caseEditable: targetCase !== null && selectionCount === 1

    // Mêmes types que CCPS_TypeSection.availableTypes (sans CS_Unknow/CS_Count).
    readonly property var _caseTypes: [
        Case.CS_KibbleDispenser,
        Case.CS_RestArea,
        Case.CS_CardBoardBox,
        Case.CS_CatNip,
        Case.CS_Jail,
        Case.CS_ToJail,
        Case.CS_CatDoor,
        Case.CS_FreeNap,
        Case.CS_Device,
        Case.CS_Taxe
    ]

    implicitHeight: headerColumn.implicitHeight + Theme.spacingM * 2
    color: Theme.surfaceAlt
    topLeftRadius: Theme.radiusL

    // Repousse l'état de l'élément dans les contrôles (appelé par
    // InspectorPanel sous garde updatingValues — pas de bindings sur les
    // champs éditables pour éviter les warnings qt.qml.binding.removal).
    function updateControls() {
        nameField.text = targetCase ? (targetCase.name || "") : ""
        typeCombo.currentIndex = targetCase
                ? Math.max(0, _caseTypes.indexOf(targetCase.type)) : 0
    }

    ColumnLayout {
        id: headerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        anchors.topMargin: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Text {
                text: root.selectionCount > 1 ? "▣" : root.icon
                font.pixelSize: Theme.px(20)
            }

            // Nom éditable (cases uniquement).
            MeowTextField {
                id: nameField
                visible: root._caseEditable
                Layout.fillWidth: true
                placeholderText: "Nom de la case"
                fieldColor: Theme.surface
                borderColor: Theme.borderLight
                onEditingFinished: {
                    if (!root.updatingValues && root.targetCase)
                        root.nameEdited(text)
                }
            }

            // Libellé du type (éléments sans nom éditable / multi-sélection).
            Text {
                visible: !root._caseEditable
                Layout.fillWidth: true
                text: root.selectionCount > 1
                      ? root.selectionCount + " éléments"
                      : root.typeLabel
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                elide: Text.ElideRight
            }
        }

        // Sélecteur de type de case.
        MeowComboBox {
            id: typeCombo
            visible: root._caseEditable
            Layout.fillWidth: true
            model: root._caseTypes.map(function(t) { return MeowStyle.getCaseTypeName(t) })
            onActivated: function(index) {
                if (!root.updatingValues)
                    root.caseTypeSelected(root._caseTypes[index])
            }
        }
    }
}
