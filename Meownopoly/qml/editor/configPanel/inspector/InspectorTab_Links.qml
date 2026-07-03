import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MapTypes
import EditorOpBus 1.0
import ui_item
import connectionConfigPanel
import theme

// Onglet « Liens » : consultation et suppression des connexions de l'élément
// sélectionné (2× ConnectionListSection réutilisées). La CRÉATION passe par
// le mode « Chemin » (rail 🔗 ou bouton ci-dessous) — plus de boutons
// « Ajouter Précédent/Suivant » : l'UI ne manipule que le sens du parcours,
// le backend symétrique previous/next est inchangé.
ColumnLayout {
    id: root

    property var logic: null
    property var targetSnapableElement: null
    property var hoveredConnectionElement: null

    signal pathModeRequested()

    // Copies des listes du connectionManager : previousElements/nextElements
    // sont mutées EN PLACE (splice) par le backend, donc un binding direct ne
    // se ré-évalue jamais. On réassigne des copies sur les signaux
    // *ElementAdded/*ElementRemoved.
    property var _prevModel: []
    property var _nextModel: []

    spacing: Theme.spacingM

    function setTarget(element) {
        targetSnapableElement = element
        _refreshLists()
    }

    function clearTarget() {
        targetSnapableElement = null
        _refreshLists()
    }

    function _refreshLists() {
        const cm = targetSnapableElement ? targetSnapableElement.connectionManager : null
        _prevModel = cm ? cm.previousElements.slice() : []
        _nextModel = cm ? cm.nextElements.slice() : []
    }

    Connections {
        target: root.targetSnapableElement ? root.targetSnapableElement.connectionManager : null
        ignoreUnknownSignals: true
        function onNextElementAdded() { root._refreshLists() }
        function onPreviousElementAdded() { root._refreshLists() }
        function onNextElementRemoved() { root._refreshLists() }
        function onPreviousElementRemoved() { root._refreshLists() }
    }

    MeowButton {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingM
        Layout.rightMargin: Theme.spacingM
        Layout.topMargin: Theme.spacingM
        iconText: "🔗"
        text: "Tracer un chemin depuis cet élément"
        fontSize: Theme.fontSizeBody
        onClicked: root.pathModeRequested()
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: Theme.spacingM
        Layout.rightMargin: Theme.spacingM
        Layout.bottomMargin: Theme.spacingM
        spacing: Theme.spacingL

        // Handlers de suppression/hover : mêmes patterns que
        // ConnectionsConfigurationSection (submitOpWithUndo + remove +
        // saveMap UNDOREDO), conservés pour l'undo et la collab.
        ConnectionListSection {
            id: previousSection
            Layout.fillWidth: true
            Layout.fillHeight: true

            title: "Précédents"
            emptyMessage: "Aucun élément précédent"
            emptyIcon: "📭"
            directionIcon: "⬅️"
            headerColor: "#74b9ff"
            badgeColor: "#74b9ff"
            connectionType: "previous"

            listModel: root._prevModel

            onRemoveElement: function(element, index) {
                if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                    if (root.targetSnapableElement.snapableParameters && element && element.snapableParameters) {
                        const sid = String(root.targetSnapableElement.snapableParameters.uniqueId)
                        const tid = String(element.snapableParameters.uniqueId)
                        EditorOpBus.submitOpWithUndo(
                            EditorOpBus.makeUnlinkOp(sid, tid, "previous"),
                            EditorOpBus.makeLinkOp(sid, tid, "previous"))
                    }
                    root.targetSnapableElement.connectionManager.removePreviousElement(element)
                    if (root.logic)
                        root.logic.saveMap(MapTypes.UNDOREDO)
                }
            }

            onElementHovered: function(element) {
                root.hoveredConnectionElement = element
                if (element && element.connectionManager)
                    element.connectionManager.hoveredElement = root.targetSnapableElement
            }

            onElementUnhovered: {
                if (root.hoveredConnectionElement && root.hoveredConnectionElement.connectionManager)
                    root.hoveredConnectionElement.connectionManager.hoveredElement = null
                root.hoveredConnectionElement = null
            }
        }

        ConnectionListSection {
            id: nextSection
            Layout.fillWidth: true
            Layout.fillHeight: true

            title: "Suivants"
            emptyMessage: "Aucun élément suivant"
            emptyIcon: "📪"
            directionIcon: "➡️"
            headerColor: "#00b894"
            badgeColor: "#00b894"
            connectionType: "next"

            listModel: root._nextModel

            onRemoveElement: function(element, index) {
                if (root.targetSnapableElement && root.targetSnapableElement.connectionManager) {
                    if (root.targetSnapableElement.snapableParameters && element && element.snapableParameters) {
                        const sid = String(root.targetSnapableElement.snapableParameters.uniqueId)
                        const tid = String(element.snapableParameters.uniqueId)
                        EditorOpBus.submitOpWithUndo(
                            EditorOpBus.makeUnlinkOp(sid, tid, "next"),
                            EditorOpBus.makeLinkOp(sid, tid, "next"))
                    }
                    root.targetSnapableElement.connectionManager.removeNextElement(element)
                    if (root.logic)
                        root.logic.saveMap(MapTypes.UNDOREDO)
                }
            }

            onElementHovered: function(element) {
                root.hoveredConnectionElement = element
                if (root.targetSnapableElement && root.targetSnapableElement.connectionManager)
                    root.targetSnapableElement.connectionManager.hoveredElement = element
            }

            onElementUnhovered: {
                if (root.targetSnapableElement && root.targetSnapableElement.connectionManager)
                    root.targetSnapableElement.connectionManager.hoveredElement = null
                root.hoveredConnectionElement = null
            }
        }
    }
}
