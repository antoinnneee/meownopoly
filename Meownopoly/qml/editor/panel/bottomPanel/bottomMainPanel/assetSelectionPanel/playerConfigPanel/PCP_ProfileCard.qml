import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlayerProfile

/*
 * Vignette d'un profil joueur — preview 3D + nom inline éditable + badge
 * pickMode + overlay actions au survol.
 *
 * Largeur min 3 cm, ratio 1:1.6 (portrait).
 *
 * Signaux :
 *  - selected()                — clic simple
 *  - duplicateRequested()      — bouton ⎘
 *  - removeRequested()         — bouton ✕
 *  - moveLeftRequested()       — flèche ←
 *  - moveRightRequested()      — flèche →
 *  - nameEditRequested(string) — submit du TextField inline
 */
Rectangle {
    id: root

    property var profile: null
    property bool isSelected: false
    property bool verticalLayout: false   // true → flèches ↑/↓, sinon ←/→

    signal selected()
    signal duplicateRequested()
    signal removeRequested()
    signal moveLeftRequested()
    signal moveRightRequested()
    signal nameEditRequested(string newName)

    readonly property real _minW: Screen.pixelDensity * 30   // 3 cm
    readonly property real _ratio: 1.6                       // h / w

    implicitWidth: Math.max(_minW, height / _ratio)
    color: "#262626"
    border.color: root.isSelected ? "#4A90E2" : "#3a3a3a"
    border.width: root.isSelected ? 2 : 1
    radius: 6
    clip: true

    // ----- Preview 3D (75% top) -----
    PCP_Profile3DPreview {
        id: preview
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height * 0.75
        modelName: root.profile ? root.profile.modelName : "Cube"
        spinning: hover.hovered
    }

    // ----- Nom (25% bottom) -----
    Item {
        id: nameRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.25

        Label {
            id: nameLabel
            anchors.fill: parent
            anchors.margins: Screen.pixelDensity * 1
            text: root.profile ? root.profile.name : ""
            color: "#e0e0e0"
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            font.bold: root.isSelected
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: !nameEdit.visible

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onDoubleClicked: {
                    nameEdit.text = nameLabel.text
                    nameEdit.visible = true
                    nameEdit.forceActiveFocus()
                    nameEdit.selectAll()
                }
                onClicked: root.selected()
            }
        }

        TextField {
            id: nameEdit
            anchors.fill: parent
            anchors.margins: Screen.pixelDensity * 1
            visible: false
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            onAccepted: _commit()
            onActiveFocusChanged: if (!activeFocus && visible) _commit()

            function _commit() {
                visible = false
                const newName = text.trim()
                if (newName && root.profile && newName !== root.profile.name)
                    root.nameEditRequested(newName)
            }
        }
    }

    // ----- Badge pickMode (haut-gauche) -----
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Screen.pixelDensity * 1
        width: badgeText.implicitWidth + Screen.pixelDensity * 2
        height: badgeText.implicitHeight + Screen.pixelDensity * 1
        radius: 4
        color: {
            if (!root.profile) return "#444444"
            switch (root.profile.pickMode) {
            case PlayerProfile.Unique:    return "#7e57c2"
            case PlayerProfile.Shared:    return "#26a69a"
            case PlayerProfile.Mandatory: return "#ef6c00"
            }
            return "#444444"
        }
        opacity: 0.85

        Label {
            id: badgeText
            anchors.centerIn: parent
            text: {
                if (!root.profile) return ""
                switch (root.profile.pickMode) {
                case PlayerProfile.Unique:    return "U"
                case PlayerProfile.Shared:    return "S"
                case PlayerProfile.Mandatory: return "M×" + root.profile.minOccurrences
                }
                return ""
            }
            color: "white"
            font.bold: true
            font.pixelSize: Math.round(Screen.pixelDensity * 2.5)
        }
    }

    // ----- Overlay actions (haut-droit, visible au survol) -----
    HoverHandler { id: hover }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Screen.pixelDensity * 1
        spacing: Screen.pixelDensity * 0.5
        visible: hover.hovered

        ToolButton {
            text: root.verticalLayout ? "↑" : "←"
            ToolTip.visible: hovered
            ToolTip.text: root.verticalLayout ? "Monter" : "Déplacer à gauche"
            onClicked: root.moveLeftRequested()
            implicitWidth: Screen.pixelDensity * 5
            implicitHeight: Screen.pixelDensity * 5
        }
        ToolButton {
            text: root.verticalLayout ? "↓" : "→"
            ToolTip.visible: hovered
            ToolTip.text: root.verticalLayout ? "Descendre" : "Déplacer à droite"
            onClicked: root.moveRightRequested()
            implicitWidth: Screen.pixelDensity * 5
            implicitHeight: Screen.pixelDensity * 5
        }
        ToolButton {
            text: "⎘"
            ToolTip.visible: hovered
            ToolTip.text: "Dupliquer"
            onClicked: root.duplicateRequested()
            implicitWidth: Screen.pixelDensity * 5
            implicitHeight: Screen.pixelDensity * 5
        }
        ToolButton {
            text: "✕"
            ToolTip.visible: hovered
            ToolTip.text: "Supprimer"
            onClicked: root.removeRequested()
            implicitWidth: Screen.pixelDensity * 5
            implicitHeight: Screen.pixelDensity * 5
        }
    }

    // Clic sur la zone preview pour sélectionner
    MouseArea {
        anchors.fill: preview
        acceptedButtons: Qt.LeftButton
        onClicked: root.selected()
    }
}
