import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

// Popup de sélection des modules à ajouter au gestionnaire. Affiche les
// modules disponibles sous forme d'icônes sélectionnables ; le bouton
// "Valider" émet la liste des ids retenus via le signal `validated`.
// Les icônes sont des emoji placeholders — remplaçables par des images.
Popup {
    id: popup

    // Modules disponibles : tableau de { id, label, icon }. Fourni par le parent.
    required property var modules

    // Émis à la validation avec la liste des ids sélectionnés (Array<string>).
    signal validated(var ids)

    modal: true
    focus: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Centré dans l'overlay applicatif (au-dessus de toute la scène).
    parent: Overlay.overlay
    anchors.centerIn: parent

    padding: Theme.spacingL

    // Ids sélectionnés. Réassigné (jamais muté en place) pour notifier les
    // bindings — cf. conventions QML du repo.
    property var selectedIds: []

    onOpened: popup.selectedIds = []

    function _toggle(id) {
        const next = popup.selectedIds.slice()
        const i = next.indexOf(id)
        if (i >= 0) next.splice(i, 1)
        else next.push(id)
        popup.selectedIds = next
    }

    background: Rectangle {
        color: Theme.background
        border.color: Theme.accent
        border.width: 1
        radius: Theme.radiusL
    }

    contentItem: ColumnLayout {
        spacing: Theme.spacingL

        Text {
            text: "Ajouter un module"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // Grille d'icônes des modules disponibles.
        Flow {
            Layout.fillWidth: true
            Layout.preferredWidth: Theme.px(400)
            spacing: Theme.spacingM

            Repeater {
                model: popup.modules

                delegate: Rectangle {
                    id: cell
                    required property var modelData

                    width: Theme.px(72)
                    height: Theme.px(86)
                    radius: Theme.radiusM

                    readonly property bool selected:
                        popup.selectedIds.indexOf(cell.modelData.id) >= 0

                    color: selected ? Theme.surfaceHover : Theme.surface
                    border.color: selected ? Theme.accent : Theme.border
                    border.width: selected ? 2 : 1

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.icon
                            font.pixelSize: Theme.fontSizeHero
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.label
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup._toggle(cell.modelData.id)
                    }
                }
            }
        }

        // Barre d'actions : Annuler / Valider.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Item { Layout.fillWidth: true }

            Button {
                id: cancelButton
                text: "Annuler"
                onClicked: popup.close()

                contentItem: Text {
                    text: cancelButton.text
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: Theme.px(90)
                    implicitHeight: Theme.px(30)
                    radius: Theme.radiusS
                    color: cancelButton.pressed ? Theme.pressed(Theme.surface)
                         : cancelButton.hovered ? Theme.hover(Theme.surface)
                                                : Theme.surface
                    border.color: Theme.border
                    border.width: 1
                }
            }

            Button {
                id: validateButton
                text: "Valider"
                enabled: popup.selectedIds.length > 0
                onClicked: {
                    popup.validated(popup.selectedIds)
                    popup.close()
                }

                contentItem: Text {
                    text: validateButton.text
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    implicitWidth: Theme.px(90)
                    implicitHeight: Theme.px(30)
                    radius: Theme.radiusS
                    opacity: validateButton.enabled ? 1.0 : 0.4
                    color: validateButton.pressed ? Theme.pressed(Theme.accentAlt)
                         : validateButton.hovered ? Theme.hover(Theme.accentAlt)
                                                  : Theme.accentAlt
                    border.color: Theme.accentAlt
                    border.width: 1
                }
            }
        }
    }
}
