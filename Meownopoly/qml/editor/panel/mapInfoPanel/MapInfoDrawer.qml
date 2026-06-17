import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore
import QtQuick.Dialogs
import Case
import ItemSnapable
import ui_item
import "../../../meowComponent"

import Game
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import EditorOpBus
import Logger
import DisplayParameter
import DecorationParameter
import ItemSnapableFactory
import AssetManager
import theme
Drawer {

    id: mapInfoDrawer
    height: parent.height
    width: Screen.pixelDensity * 75
    edge: Qt.RightEdge

    modal : false

    // --- Dynamic tile counting ---
    property int _refreshTrigger: 0

    Connections {
        target: mapInfoPanel.logic
        function onSnapableTilesListUpdated() {
            _refreshTrigger++
        }
    }

    function countByType(tileType) {
        var _trigger = _refreshTrigger  // force re-eval on signal
        var list = mapInfoPanel.logic.snapableTilesList
        if (!list) return 0
        var count = 0
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].snapableParameters
                    && list[i].snapableParameters.tileType === tileType)
                count++
        }
        return count
    }

    readonly property int caseCount: countByType(ItemSnapable.CaseTile)
    readonly property int decoCount: countByType(ItemSnapable.DecorationTile)
    readonly property int zoneCount: countByType(ItemSnapable.PhysicZoneTile)


    signal requestNewMap()
    background : Rectangle {
        anchors.fill: parent
        color: "#383838"
    }

    // Header avec titre
    Rectangle {
        id: headerSection
        width: parent.width*0.9
        height: 32
        color: "#383838"
        radius: Theme.radiusS
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingM
        anchors.horizontalCenter: parent.horizontalCenter

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingS
            spacing: Theme.spacingS

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: Theme.accent
                opacity: 0.2

                Text {
                    anchors.centerIn: parent
                    text: mapInfoPanel.currentView === 0 ? "🗺️" : "🖼️"
                    font.pixelSize: Theme.fontSizeCaption
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mapInfoPanel.currentView === 0 ? "Infos carte" : "Fond d'écran"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
            }

            // Bouton "+" pour créer une nouvelle carte
            Button {
                visible: mapInfoPanel.currentView === 0
                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                
                contentItem: Text {
                    text: "NOUVELLE CARTE"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    color: parent.parent.hovered ? Theme.textPrimary : "#7dd3fc"
                }
                
                background: Rectangle {
                    radius: Theme.radiusXL
                    color: parent.hovered ? Theme.accent : "transparent"
                    border.color: parent.hovered ? Theme.hover(Theme.accent) : Theme.accent
                    border.width: 1
                    
                    Behavior on color {
                        ColorAnimation { duration: Theme.durationNormal }
                    }
                }
                
                onClicked: {
                    // refreshMapList() pré-création retiré : inutile puisque
                    // MapNavigationBar écoute désormais
                    // MapFileManager.currentMapChanged et se re-sync
                    // automatiquement quand la nouvelle carte est chargée.
                    mapInfoDrawer.requestNewMap()
                }
            }
        }

        // Bouton fermer
        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Theme.spacingS
            width: 24
            height: 24
            text: "✕"
            background: Rectangle {
                color: parent.hovered ? Theme.borderLight : "transparent"
                radius: Theme.radiusXS
            }

            onClicked: {
                isOpening = false
                selectionPanel.visible =  selectionPanel.visible ? false: true
                sidePanel.visible = sidePanel.visible ? false: true
            }
        }
    }

    // Boutons de navigation
    Row {
        id: navigationButtons
        anchors.top: headerSection.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingXS
        height: 30
        spacing: Theme.spacingXS

        Button {
            width: (parent.width - parent.spacing) / 2
            height: parent.height

            background: Rectangle {
                color: mapInfoPanel.currentView === 0 ? Theme.accent : Theme.border
                radius: Theme.radiusXS
                border.color: mapInfoPanel.currentView === 0 ? Theme.hover(Theme.accent) : Theme.borderLight
                border.width: 1
            }

            contentItem: Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXXS

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🗺️"
                    font.pixelSize: Theme.fontSizeBody
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "Cartes"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: mapInfoPanel.currentView === 0
                }
            }
            onClicked: {
                mapInfoPanel.currentView = 0
            }
        }

        Button {
            width: (parent.width - parent.spacing) / 2
            height: parent.height

            background: Rectangle {
                color: mapInfoPanel.currentView === 1 ? Theme.accent : Theme.border
                radius: Theme.radiusXS
                border.color: mapInfoPanel.currentView === 1 ? Theme.hover(Theme.accent) : Theme.borderLight
                border.width: 1
            }

            contentItem: Row {
                anchors.centerIn: parent
                spacing: Theme.spacingXXS

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🖼️"
                    font.pixelSize: Theme.fontSizeBody
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Arrière-plan"
                    horizontalAlignment: Text.AlignHCenter

                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: mapInfoPanel.currentView === 1
                }
            }

            onClicked: {
                mapInfoPanel.currentView = 1
            }
        }
    }

    // Informations générales de la carte
    Flickable {
        id: mapInfoFlickable
        anchors.top: navigationButtons.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: parent.height - headerSection.height - navigationButtons.height - 16 - 6 - 8 // parent.height - headerSection - navigationButtons - marges
        clip: true
        visible: mapInfoPanel.currentView === 0
        contentHeight: generalInfoColumn.height
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            active: mapInfoFlickable.contentHeight > mapInfoFlickable.height
            policy: ScrollBar.AlwaysOff
            interactive: true
            anchors.rightMargin: Theme.spacingXS
            anchors.topMargin: Theme.spacingXXS
            anchors.bottomMargin: Theme.spacingXXS

            contentItem: Rectangle {
                implicitWidth: 6
                radius: width / 2
                color: "#999999"
                opacity: scrollBar.pressed ? 0.8 : 0.5
            }
        }

        Column {
            id: generalInfoColumn
            width: parent.width
            spacing: Theme.spacingS

            Settings {
                id: stEnableAutoSave
                category: "Editor/SaveConfig"
                property var lastOpenedMap : value("lastOpenedMap", mapInfo.autosaveMapName)
                property var enableAutoSave: value("enableAutoSave", 0)
            }

            // Map Information Container
            Rectangle {
                width: parent.width
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                height: mapInfoContent.height + 12

                Column {
                    id: mapInfoContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    // Map info header with icon
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: Theme.radiusS

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: Theme.accent
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "🗺️"
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Map Information"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                        }
                    }

                    // Save button - separate row
                    ParticleButton {
                        id: saveButton
                        width: parent.width
                        height: 30

                        // Style unifié via MeowButton ; couleur + libellé
                        // dépendants de l'état de la carte.
                        baseColor: {
                            if (logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName === "")
                                return "#5E5A66"
                            if (MapFileManager.mapExists(logic.mapInfo.mapName, MapTypes.CUSTOM))
                                return "#008B8B"
                            return Theme.success
                        }
                        text: {
                            if (logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName === "")
                                return "Sauvegarde par défaut"
                            if (MapFileManager.mapExists(logic.mapInfo.mapName, MapTypes.CUSTOM))
                                return "Mettre a jour"
                            return "Créer une carte"
                        }
                        fontSize: Theme.fontSizeBody

                        particleColor: "#32CD32"
                        particleColorVariation: "#00FF00"
                        particleCount: 30
                        particleSize: 6
                        particleLifeSpan: 1500

                        onClicked: {
                            if (typeof logic !== 'undefined' && typeof logic.saveMap === 'function') {
                                var mapInfoLocal = logic.mapInfo
                                logic.saveMap(logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName == "" ? MapTypes.AUTOSAVE : MapTypes.CUSTOM)

                                stEnableAutoSave.setValue("lastOpenedMap", mapInfoLocal.mapName)
                            } else {
                                console.error("La fonction saveMap n'est pas accessible. Verifiez que la variable 'logic' est definie.")
                            }
                        }
                    }

                    // Grid layout for map details
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: Theme.spacingS
                        rowSpacing: Theme.spacingM

                        // ============ CHAMPS NON-ÉDITABLES (lecture seule) ============

                        // Map name (lecture seule)
                        Text {
                            text: "Map Name"
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeBody
                            font.italic: true
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusXS

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXS
                                spacing: Theme.spacingXS

                                Text {
                                    text: "📁"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: Theme.fontSizeMedium
                                    opacity: 0.6
                                }

                                Text {
                                    id: mapNameInput
                                    width: parent.width - 24
                                    height: parent.height
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: logic.mapInfo.mapName !== "" ? logic.mapInfo.mapName : "—"
                                }
                            }

                        }

                        // Version (lecture seule)
                        Text {
                            text: "Version"
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeBody
                            font.italic: true
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusXS

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXS
                                spacing: Theme.spacingXS

                                Text {
                                    text: "📈"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: Theme.fontSizeMedium
                                    opacity: 0.6
                                }

                                Text {
                                    id: versionInput
                                    width: parent.width - 24
                                    height: parent.height
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: logic.mapInfo.version.toString()
                                }
                            }
                        }

                        // Creation date (lecture seule)
                        Text {
                            text: "Created"
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeBody
                            font.italic: true
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusXS

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXS
                                spacing: Theme.spacingXS

                                Text {
                                    text: "📅"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: Theme.fontSizeMedium
                                    opacity: 0.6
                                }

                                Text {
                                    id: creationDateInput
                                    width: parent.width - 24
                                    height: parent.height
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: logic.mapInfo.mapCreationDate !== "" ? logic.mapInfo.mapCreationDate : "—"
                                }
                            }

                        }

                        // Last modification (lecture seule)
                        Text {
                            text: "Modified"
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeBody
                            font.italic: true
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusXS

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXS
                                spacing: Theme.spacingXS

                                Text {
                                    text: "🕒"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: Theme.fontSizeMedium
                                    opacity: 0.6
                                }

                                Text {
                                    id: lastModifiedInput
                                    width: parent.width - 24
                                    height: parent.height
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeBody
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: logic.mapInfo.mapLastModified !== "" ? logic.mapInfo.mapLastModified : "—"
                                }
                            }

                        }

                        // ============ CHAMPS ÉDITABLES ============

                        // Min joueurs
                        Text {
                            text: "Min joueurs"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeBody
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusXS

                            SpinBox {
                                id: minPlayersSpinBox
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXXS
                                from: 1
                                to: logic.mapInfo ? logic.mapInfo.maxPlayers : 8
                                value: logic.mapInfo ? logic.mapInfo.minPlayers : 2
                                editable: true

                                property bool _syncing: false
                                Connections {
                                    target: logic.mapInfo
                                    function onMinPlayersChanged() {
                                        if (minPlayersSpinBox.value !== logic.mapInfo.minPlayers) {
                                            minPlayersSpinBox._syncing = true
                                            minPlayersSpinBox.value = logic.mapInfo.minPlayers
                                            minPlayersSpinBox._syncing = false
                                        }
                                    }
                                }

                                onValueModified: {
                                    if (_syncing || !logic.mapInfo) return
                                    if (logic.mapInfo.minPlayers === value) return
                                    var before = logic.mapInfo.toJSON()
                                    logic.mapInfo.minPlayers = value
                                    Game.updateMapMetadata(before, logic.mapInfo.toJSON())
                                    EditorOpBus.submitOp(EditorOpBus.makeSetMapPlayerLimitsOp(
                                                            { "minPlayers": logic.mapInfo.minPlayers }))
                                }

                                contentItem: TextInput {
                                    text: minPlayersSpinBox.displayText
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeBody
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !minPlayersSpinBox.editable
                                    validator: minPlayersSpinBox.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                                background: Rectangle { color: "transparent" }
                            }
                        }

                        // Max joueurs
                        Text {
                            text: "Max joueurs"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeBody
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.surface
                            border.color: Theme.border
                            border.width: 1
                            radius: Theme.radiusXS

                            SpinBox {
                                id: maxPlayersSpinBox
                                anchors.fill: parent
                                anchors.margins: Theme.spacingXXS
                                from: logic.mapInfo ? logic.mapInfo.minPlayers : 1
                                to: 8
                                value: logic.mapInfo ? logic.mapInfo.maxPlayers : 8
                                editable: true

                                property bool _syncing: false
                                Connections {
                                    target: logic.mapInfo
                                    function onMaxPlayersChanged() {
                                        if (maxPlayersSpinBox.value !== logic.mapInfo.maxPlayers) {
                                            maxPlayersSpinBox._syncing = true
                                            maxPlayersSpinBox.value = logic.mapInfo.maxPlayers
                                            maxPlayersSpinBox._syncing = false
                                        }
                                    }
                                }

                                onValueModified: {
                                    if (_syncing || !logic.mapInfo) return
                                    if (logic.mapInfo.maxPlayers === value) return
                                    var before = logic.mapInfo.toJSON()
                                    logic.mapInfo.maxPlayers = value
                                    Game.updateMapMetadata(before, logic.mapInfo.toJSON())
                                    EditorOpBus.submitOp(EditorOpBus.makeSetMapPlayerLimitsOp(
                                                            { "maxPlayers": logic.mapInfo.maxPlayers }))
                                }

                                contentItem: TextInput {
                                    text: maxPlayersSpinBox.displayText
                                    color: Theme.textSecondary
                                    font.pixelSize: Theme.fontSizeBody
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !maxPlayersSpinBox.editable
                                    validator: maxPlayersSpinBox.validator
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                }
                                background: Rectangle { color: "transparent" }
                            }
                        }
                    }
                }
            }

            // Description Container
            Rectangle {
                width: parent.width
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                height: descriptionContent.height + 12

                Column {
                    id: descriptionContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: Theme.radiusS

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#FFC107"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📝"
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Description"
                                color: Theme.textDisabled
                                font.pixelSize: Theme.fontSizeBody
                                font.italic: true
                            }
                        }
                    }

                    // Description text (lecture seule)
                    Rectangle {
                        width: parent.width
                        height: Math.max(80, descriptionInput.height + 8)
                        color: Theme.surface
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusXS

                        Flickable {
                            id: descriptionFlickable
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXS
                            contentWidth: descriptionInput.paintedWidth
                            contentHeight: descriptionInput.paintedHeight
                            clip: true

                            Text {
                                id: descriptionInput
                                width: descriptionFlickable.width
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSizeBody
                                wrapMode: Text.Wrap
                                text: logic.mapInfo.mapDescription !== "" ? logic.mapInfo.mapDescription : "—"
                            }
                        }

                        // Scrollbar for description
                        ScrollBar {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: Theme.spacingXS
                            anchors.topMargin: Theme.spacingXXS
                            anchors.bottomMargin: 0
                            width: 6
                            policy: ScrollBar.AlwaysOff
                            active: true
                            orientation: Qt.Vertical
                            size: descriptionFlickable.height / descriptionFlickable.contentHeight
                            position: descriptionFlickable.contentY / descriptionFlickable.contentHeight
                            visible: descriptionFlickable.contentHeight > descriptionFlickable.height

                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: width / 2
                                color: "#999999"
                                opacity: 0.5
                            }
                        }
                    }
                }
            }

            // Statistics Container
            Rectangle {
                width: parent.width
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                height: statsContent.height + 12

                Column {
                    id: statsContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingS
                    spacing: Theme.spacingM

                    // Stats section header
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: Theme.radiusS

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#E91E63"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📊"
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Statistics"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                        }
                    }

                    // Quick stats in badges
                    Flow {
                        width: parent.width
                        spacing: Theme.spacingXS

                        // Stats badges with subtle colors
                        Repeater {
                            model: [
                                {icon: "🏠", label: "Cases", value: mapInfoDrawer.caseCount.toString(), color: Theme.accent},
                                {icon: "🌳", label: "Déco", value: mapInfoDrawer.decoCount.toString(), color: "#FFC107"},
                                {icon: "🔷", label: "Zone", value: mapInfoDrawer.zoneCount.toString(), color: "#E91E63"}
                            ]

                            Rectangle {
                                width: (parent.width - 5) / 2
                                height: 28
                                radius: 14
                                color: Qt.alpha(modelData.color, 0.15)
                                border.color: modelData.color
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: Theme.fontSizeBody
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label + ": " + modelData.value
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeSmall
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Liste des fonds d'�cran
    // Vue Arrière-plan avec ScrollBar globale
    Flickable {
        id: backgroundFlickable
        anchors.top: navigationButtons.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        height: parent.height - headerSection.height - navigationButtons.height - 16 - 6 - 8
        clip: true
        visible: mapInfoPanel.currentView === 1
        contentHeight: backgroundColumn.height
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: backgroundScrollBar
            policy: ScrollBar.AlwaysOff
            active: backgroundFlickable.contentHeight > backgroundFlickable.height
            interactive: true
            anchors.rightMargin: Theme.spacingXS
            anchors.topMargin: Theme.spacingXXS
            anchors.bottomMargin: Theme.spacingXXS

            contentItem: Rectangle {
                implicitWidth: 6
                radius: width / 2
                color: "#999999"
                opacity: backgroundScrollBar.pressed ? 0.8 : 0.5
            }
        }

        Column {
            id: backgroundColumn
            width: parent.width
            spacing: Theme.spacingL

            // Contrôles d'affichage
            Rectangle {
                width: parent.width
                height: displayControlsColumn.height + 16
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1
                visible: logic.mapInfo.backgroundPath !== ""

                Column {
                    id: displayControlsColumn
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingL

                    Text {
                        text: "Mode d'affichage:"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }

                    // Checkbox "Fixé à la grille"
                    MeowCheckBox {
                        id: snapToGridCheckBox
                        text: "Fixé à la grille ?"
                        width: parent.width
                        checked: logic.mapInfo ? logic.mapInfo.isBackgroundOnGrill : false
                        accentColor: Theme.accent

                        // onToggled (action utilisateur) plutôt que
                        // onCheckedChanged (qui fire aussi sur re-eval du binding).
                        // Évite un appel parasite à updateMapMetadata à l'init
                        // qui créait un cycle setMapInfo → _syncMapInfo → binding.
                        onToggled: {
                            if (!logic.mapInfo) return
                            var before = logic.mapInfo.toJSON()
                            logic.mapInfo.isBackgroundOnGrill = checked
                            Game.updateMapMetadata(before, logic.mapInfo.toJSON())
                        }
                    }

                    // Boutons de mode d'affichage
                    Row {
                        width: parent.width
                        height: 36
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                {text: "Ajuster", icon: "📐", mode: "Fit"},
                                {text: "Étirer", icon: "↔️", mode: "Stretch"},
                                {text: "Mosaïque", icon: "🔲", mode: "Tile"}
                            ]

                            Rectangle {
                                width: (parent.width - parent.spacing * 2) / 3
                                height: parent.height
                                radius: Theme.radiusS
                                color: logic.mapInfo.backgroundScaling === modelData.mode ? Theme.accent : Theme.surfaceHover
                                border.color: logic.mapInfo.backgroundScaling === modelData.mode ? Theme.hover(Theme.accent) : Theme.borderLight
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Theme.spacingXS

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: Theme.fontSizeMedium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.text
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeBody
                                        font.bold: logic.mapInfo.backgroundScaling === modelData.mode
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var before = logic.mapInfo.toJSON()
                                        logic.mapInfo.backgroundScaling = modelData.mode
                                        Game.updateMapMetadata(before, logic.mapInfo.toJSON())
                                    }
                                }
                            }
                        }
                    }

                    // Slider pour la taille des tuiles (visible seulement en mode Tile)
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: logic.mapInfo.backgroundScaling === "Tile"

                        Text {
                            text: "Taille des tuiles: " + tileSizeSlider.value + "px"
                            color: "#AAAAAA"
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MeowSlider {
                            id: tileSizeSlider
                            width: parent.width
                            showValue: false   // valeur affichée dans le Text ci-dessus
                            from: 20
                            to: 400
                            stepSize: 20
                            value: (logic.mapInfo ? logic.mapInfo.backgroundTileSize : 0) || 100
                            decimals: 0
                            accentColor: Theme.accent
                            property string _beforeJson: ""

                            // moved (action utilisateur seulement) — évite le
                            // write-back parasite à l'init du binding value.
                            onMoved: {
                                if (logic.mapInfo)
                                    logic.mapInfo.backgroundTileSize = value
                            }
                            onGestureBegan: {
                                if (logic.mapInfo)
                                    _beforeJson = logic.mapInfo.toJSON()
                            }
                            onGestureCommitted: {
                                if (logic.mapInfo)
                                    Game.updateMapMetadata(_beforeJson, logic.mapInfo.toJSON())
                            }
                        }
                    }
                }
            }

            // Sélecteur de fond d'écran personnalisé
            Rectangle {
                width: parent.width
                height: customBackgroundContent.height + 16
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1

                Column {
                    id: customBackgroundContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    // Header
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: Theme.radiusS

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#E91E63"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📷"
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Thème personnalisé"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                        }
                    }

                    // Zone de sélection d'image
                    Rectangle {
                        id: customBackgroundSelector
                        width: parent.width
                        height: 100
                        color: Theme.surfaceHover
                        radius: Theme.radiusM
                        border.color: imageMouseArea.containsMouse ? "#E91E63" : Theme.borderLight
                        border.width: imageMouseArea.containsMouse ? 2 : 1


                        // Default image icon
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingS
                            visible: mapInfo.backgroundPath === "" || mapInfo.backgroundPath.indexOf("background/") !== -1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "📷"
                                font.pixelSize: Theme.fontSizeHero
                                color: "#AAAAAA"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Cliquez pour choisir une image"
                                color: "#AAAAAA"
                                font.pixelSize: Theme.fontSizeBody
                                opacity: 0.7
                            }
                        }

                        // Selected image
                        Image {
                            id: selectedCustomImage
                            anchors.fill: parent
                            anchors.margins: Theme.spacingXXS
                            visible: mapInfo.backgroundPath !== "" && mapInfo.backgroundPath.indexOf("background/") === -1
                            source: mapInfo.backgroundPath
                            fillMode: Image.PreserveAspectCrop

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 28
                                color: "#80000000"

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (mapInfo.backgroundPath === "" || mapInfo.backgroundPath.indexOf("background/") === -1) {
                                            return ""
                                        }
                                        var path = mapInfo.backgroundPath.toString()
                                        var fileName = path.substring(path.lastIndexOf("/") + 1)
                                        return fileName.replace(/\.[^/.]+$/, "")
                                    }
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeBody
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Remove image button
                        Rectangle {
                            id: removeButton
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingS
                            width: 28
                            height: 28
                            radius: 14
                            color: "#CC2222"
                            visible: mapInfo.backgroundPath !== "" && mapInfo.backgroundPath.indexOf("background/") === -1
                            opacity: removeMouseArea.containsMouse ? 1.0 : 0.8
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: removeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var before = mapInfo.toJSON()
                                    mapInfo.backgroundPath = ""
                                    Game.updateMapMetadata(before, mapInfo.toJSON())
                                }
                            }
                        }

                        MouseArea {
                            id: imageMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: customFileDialog.open()
                        }
                    }
                }
            }

            // Séparateur
            Rectangle {
                width: parent.width
                height: 30
                color: "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingL

                    Rectangle {
                        width: 60
                        height: 1
                        color: Theme.borderLight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "OU"
                        color: "#999999"
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 60
                        height: 1
                        color: Theme.borderLight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Thèmes par défaut
            Rectangle {
                width: parent.width
                height: defaultBackgroundsContent.height + 16
                color: Theme.surfaceAlt
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1

                Column {
                    id: defaultBackgroundsContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    // Header
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: Theme.radiusS

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingS
                            spacing: Theme.spacingS

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: Theme.accent
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "🖼️"
                                    font.pixelSize: Theme.fontSizeMedium
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Thèmes par défaut"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                            }
                        }
                    }

                    // Liste des thèmes
                    Column {
                        width: parent.width
                        spacing: Theme.spacingL

                        Repeater {
                            id: backgroundsList
                            model: AssetManager.getAvailableBackgrounds()

                            Item {
                                width: parent.width
                                height: 90

                                Rectangle {
                                    width: parent.width
                                    height: 90
                                    radius: Theme.radiusM
                                    border.width: mapInfo.backgroundPath === modelData ? 3 : 1
                                    border.color: mapInfo.backgroundPath === modelData ? Theme.accent : Theme.borderLight
                                    color: Theme.surfaceHover

                                    Image {
                                        id: bgImage
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingXXS
                                        source: modelData
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 28
                                            color: "#80000000"

                                            Text {
                                                anchors.centerIn: parent
                                                text: {
                                                    var fullPath = modelData.toString()
                                                    var fileName = fullPath.substring(fullPath.lastIndexOf('/') + 1)
                                                    return fileName.substring(0, fileName.lastIndexOf('.'))
                                                }
                                                color: Theme.textPrimary
                                                font.pixelSize: Theme.fontSizeBody
                                                font.bold: true
                                                elide: Text.ElideRight
                                                width: parent.width - 10
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            var before = mapInfo.toJSON()
                                            mapInfo.backgroundPath = modelData
                                            Game.updateMapMetadata(before, mapInfo.toJSON())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
