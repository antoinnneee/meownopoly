import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

// Inspecteur contextuel (nouvelle UI) : dock droit vertical affiché dès
// qu'une sélection existe — remplace le module "config" (BottomSidePanel)
// côté nouvelle UI. Le contenu (onglets) est résolu par InspectorRegistry
// selon le type de l'élément sélectionné.
// Point d'entrée unique du dispatch : setSelection(elements), appelé par
// MouseLogic_Base.notifyInspector().
Rectangle {
    id: root
    objectName: "inspectorPanel"

    property var logic

    // Sélection courante (copie défensive, éléments null filtrés).
    property var selection: []
    readonly property var currentElement: selection.length === 1 ? selection[0] : null

    // Vrai pendant qu'on pousse l'état d'un élément dans les onglets : les
    // signaux relayés par les onglets sont ignorés (anti-boucle, équivalent
    // du blockEffectChangedSignal de BottomSidePanel).
    property bool _updating: false

    // Onglets résolus pour la sélection courante : [{id, label, source}].
    property var _tabs: []
    property int _currentTabIndex: 0

    signal effectChanged()
    signal zoneConfigurationChanged()
    signal focusReleased()

    visible: selection.length > 0
    width: Theme.px(320)

    // Chrome unifié : même surface tokenisée que les panneaux dockés.
    color: Theme.panelSurface
    topLeftRadius: Theme.radiusL
    bottomLeftRadius: Theme.radiusL
    border.color: Theme.border
    border.width: 1

    InspectorRegistry { id: registry }

    // Bloque clics et molette : sans ça ils traversent vers le workArea et
    // un clic « dans le vide » du panneau désélectionnerait (l'inspecteur
    // disparaîtrait sous la souris). Placé avant le contenu → les contrôles
    // enfants reçoivent leurs événements en premier.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: function(wheel) { wheel.accepted = true }
    }

    // ── API ──────────────────────────────────────────────────────────────
    function setSelection(elements) {
        const list = []
        if (elements)
            for (var i = 0; i < elements.length; i++)
                if (elements[i])
                    list.push(elements[i])
        selection = list
        _rebuildTabs(false)
    }

    // Re-résout les onglets pour l'élément courant (ex : après changement de
    // type de case, l'onglet Économie apparaît/disparaît).
    function refresh() {
        _rebuildTabs(true)
    }

    // Même contrat que editorSidePanel.visualEffectsPanel.getCurrentEffects()
    // — consommé par le flush d'ops SetDisplayParameter dans Editor.qml.
    function getCurrentEffects() {
        const tab = _tabItem("visual")
        return tab && tab.getCurrentEffects ? tab.getCurrentEffects() : ({})
    }

    function _tabItem(tabId) {
        for (let i = 0; i < _tabs.length; i++) {
            if (_tabs[i].id === tabId) {
                const loader = tabRepeater.itemAt(i)
                return loader ? loader.item : null
            }
        }
        return null
    }

    // ── Interne ──────────────────────────────────────────────────────────
    function _rebuildTabs(force) {
        let tabs = []
        if (selection.length === 1)
            tabs = registry.tabsFor(selection[0])
        else if (selection.length > 1)
            tabs = registry.tabsForMulti(selection)

        // Ne recrée les delegates que si la liste change réellement
        // (la sélection rectangle re-notifie souvent la même forme d'onglets).
        if (force || JSON.stringify(tabs) !== JSON.stringify(_tabs)) {
            // Préserver l'onglet actif si son id existe encore.
            const prevId = (_currentTabIndex >= 0 && _currentTabIndex < _tabs.length)
                         ? _tabs[_currentTabIndex].id : ""
            _tabs = tabs
            let idx = 0
            for (let i = 0; i < tabs.length; i++)
                if (tabs[i].id === prevId) { idx = i; break }
            _currentTabIndex = idx
        }
        _pushTargets()
    }

    // Pousse l'élément courant dans tous les onglets chargés, sous garde
    // _updating pour que les mouvements de sliders induits ne repartent pas
    // en ops.
    function _pushTargets() {
        _updating = true
        for (let i = 0; i < tabRepeater.count; i++) {
            const loader = tabRepeater.itemAt(i)
            if (loader && loader.item)
                _pushTargetToItem(loader.item)
        }
        _updating = false
    }

    function _pushTargetToItem(item) {
        // En multi-sélection, l'onglet Visuel est alimenté par le premier
        // élément (les changements s'appliquent ensuite à toute la sélection
        // via _applyToSelectionAndSave côté Editor.qml).
        const el = currentElement ? currentElement
                                  : (selection.length > 0 ? selection[0] : null)
        if (el && item.setTarget)
            item.setTarget(el)
        else if (item.clearTarget)
            item.clearTarget()
    }

    // ── Layout ───────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.border.width
        spacing: 0

        InspectorHeader {
            id: header
            Layout.fillWidth: true
            selectionCount: root.selection.length
            icon: root.currentElement ? registry.headerInfo(root.currentElement).icon : ""
            typeLabel: root.currentElement ? registry.headerInfo(root.currentElement).typeLabel : ""
        }

        // Barre d'onglets (masquée s'il n'y a qu'un onglet).
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: tabRow.implicitHeight
            visible: root._tabs.length > 1
            color: Theme.surface

            RowLayout {
                id: tabRow
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                Repeater {
                    model: root._tabs
                    delegate: Item {
                        id: tabButton
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: root._currentTabIndex === index

                        Layout.fillWidth: true
                        implicitHeight: tabText.implicitHeight + Theme.spacingS * 2

                        Rectangle {
                            anchors.fill: parent
                            color: tabButton.isCurrent
                                   ? Theme.surfaceHover
                                   : (tabHover.hovered ? Theme.hover(Theme.surface) : "transparent")
                            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        }

                        // Soulignement de l'onglet actif.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 2
                            color: tabButton.isCurrent ? Theme.accent : "transparent"
                        }

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: tabButton.modelData.label
                            color: tabButton.isCurrent ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeBody
                        }

                        HoverHandler { id: tabHover }
                        TapHandler { onTapped: root._currentTabIndex = tabButton.index }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root._currentTabIndex

            Repeater {
                id: tabRepeater
                model: root._tabs
                delegate: Loader {
                    required property var modelData
                    source: modelData.source
                    onLoaded: {
                        // Relais des signaux d'édition, filtrés par la garde
                        // anti-boucle.
                        if (item.effectChanged)
                            item.effectChanged.connect(function() {
                                if (!root._updating) root.effectChanged()
                            })
                        if (item.zoneConfigurationChanged)
                            item.zoneConfigurationChanged.connect(function() {
                                if (!root._updating) root.zoneConfigurationChanged()
                            })
                        if (item.focusReleased)
                            item.focusReleased.connect(root.focusReleased)

                        // Un Loader créé après _pushTargets (reconstruction du
                        // modèle) reçoit sa cible ici.
                        root._updating = true
                        root._pushTargetToItem(item)
                        root._updating = false
                    }
                }
            }
        }
    }
}
