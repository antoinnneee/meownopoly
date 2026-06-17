import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum
import Game
import TemplateFileManager

import "../"
import editorBottomPanel
import theme

/**
 * Panneau de gestion des templates
 * Permet d'enregistrer, supprimer et sélectionner des templates
 */
EBP_Content {
    id: root

    required property var logic

    // Coefficients de taille (ajustables)
    readonly property real buttonSizeCoef: 8.5
    readonly property real listItemSizeCoef: 6.5

    // Tailles calculées
    readonly property real buttonHeight: Screen.pixelDensity * buttonSizeCoef
    readonly property real listItemHeight: Screen.pixelDensity * listItemSizeCoef

    // Template actuellement sélectionné
    property string selectedTemplateName: ""

    // Liste des noms de templates (alimentée par TemplateFileManager)
    property var templateNameList: []

    sidePanelRatio: 0

    /** Rafraîchit la liste des templates depuis le disque */
    function refreshTemplateList() {
        var list = TemplateFileManager.getAvailableTemplates()
        templateNameList = list || []
    }

    /** Éléments en attente d'enregistrement (après clic Enregistrer, avant saisie du nom) */
    property var pendingSaveElementsJson: []

    /**
     * Sélection capturée avant le changement de mode vers EM_TEMPLATE.
     * Le Loader détruit l'ancien MouseLogic → son `selectedElements` est perdu,
     * alors qu'une nouvelle MouseLogic_Template démarre vide. On réinjecte cette
     * liste dans `templateSelectedElements` dès que le nouveau mouseLogic est prêt.
     */
    property var _capturedPreviousSelection: []

    /** Capture la sélection courante (avant swap du MouseLogic) */
    function _capturePreviousSelection() {
        _capturedPreviousSelection = []
        if (!logic || !logic.mouseLogic) return
        var src = logic.mouseLogic.selectedElements
        if (!src || src.length === 0) return
        var copy = []
        for (var i = 0; i < src.length; i++) {
            if (src[i]) copy.push(src[i])
        }
        _capturedPreviousSelection = copy
    }

    /** Importe la sélection capturée dans le nouveau MouseLogic_Template */
    function _importCapturedSelectionIntoTemplate() {
        if (!_capturedPreviousSelection || _capturedPreviousSelection.length === 0) return
        var ml = logic ? logic.mouseLogic : null
        if (!ml || typeof ml.getTemplateSelectedElements !== "function") return

        // Si l'utilisateur a déjà fait une sélection en mode template, ne pas écraser
        var existing = ml.getTemplateSelectedElements() || []
        if (existing.length > 0) {
            _capturedPreviousSelection = []
            return
        }

        var tSel = []
        var sSel = []
        for (var i = 0; i < _capturedPreviousSelection.length; i++) {
            var el = _capturedPreviousSelection[i]
            if (!el) continue
            tSel.push(el)
            sSel.push(el)
            // Recréer les bindings x/y dans le nouveau MouseLogic (l'ancien a été détruit)
            if (typeof ml.createBindingsForElement === "function") {
                ml.createBindingsForElement(el)
            }
        }
        ml.templateSelectedElements = tSel
        ml.selectedElements = sSel
        if (typeof ml.updateTemplateBoundingBox === "function") {
            ml.updateTemplateBoundingBox()
        }
        console.log("[TP_Content] Imported", tSel.length, "element(s) from previous selection into template mode")
        _capturedPreviousSelection = []
    }

    // Réinjecter la sélection capturée dès que le mouseLogic bascule sur le nouveau
    Connections {
        target: logic
        function onMouseLogicChanged() {
            if (!root.visible) return
            if (!logic || !logic.mouseLogic) return
            if (logic.editorMouseMode !== EditorEnum.EM_TEMPLATE) return
            root._importCapturedSelectionIntoTemplate()
        }
    }

    /**
     * Construit un tableau d'objets JSON à partir des éléments sélectionnés.
     * Chaque objet a gridRelativePositionX/Y en top-level pour le C++.
     *
     * Résout la sélection selon le mode courant :
     *  - EM_TEMPLATE → templateSelectedElements (via getTemplateSelectedElements)
     *  - autres      → selectedElements (sélection classique MouseLogic_Selection)
     */
    function buildElementsJsonFromSelection() {
        if (!logic) {
            console.warn("[TP_Content] buildElementsJsonFromSelection: logic is null")
            return []
        }
        if (!logic.mouseLogic) {
            console.warn("[TP_Content] buildElementsJsonFromSelection: logic.mouseLogic is null (mode=" + logic.editorMouseMode + ")")
            return []
        }

        var ml = logic.mouseLogic
        var elements = []
        if (typeof ml.getTemplateSelectedElements === "function") {
            elements = ml.getTemplateSelectedElements() || []
        }
        // Fallback : si pas en mode TEMPLATE ou templateSelectedElements vide, utiliser selectedElements
        if ((!elements || elements.length === 0) && ml.selectedElements) {
            console.log("[TP_Content] Fallback sur selectedElements (mode=" + logic.editorMouseMode + ")")
            elements = ml.selectedElements
        }

        var arr = []
        for (var i = 0; i < elements.length; i++) {
            var el = elements[i]
            var isParam = el && el.snapableParameters
            if (!isParam || typeof isParam.toJSON !== "function") continue
            var jsonStr = isParam.toJSON()
            var obj = {}
            try {
                obj = JSON.parse(jsonStr)
            } catch (e) {
                console.warn("[TP_Content] Failed to parse element JSON:", e)
                continue
            }
            arr.push(obj)
        }
        return arr
    }

    /** Déclenche l'enregistrement : vérifie la sélection puis ouvre le popup de nom */
    function requestSaveTemplate() {
        var elementsJson = buildElementsJsonFromSelection()
        if (elementsJson.length === 0) {
            console.warn("[TP_Content] Aucun élément sélectionné pour enregistrer le template.")
            return
        }
        root.pendingSaveElementsJson = elementsJson
        saveNameInput.text = ""
        saveTemplatePopup.open()
    }

    /** Enregistre le template avec le nom saisi (appelé après OK dans le popup) */
    function doSaveTemplate(templateName) {
        var name = (templateName || "").trim()
        if (!name) return
        if (pendingSaveElementsJson.length === 0) return
        var ok = Game.saveTemplate(name, pendingSaveElementsJson)
        if (ok) {
            refreshTemplateList()
            root.selectedTemplateName = name
            saveTemplatePopup.close()
        }
        root.pendingSaveElementsJson = []
    }

    /** Supprime le template actuellement sélectionné dans la liste */
    function requestDeleteTemplate() {
        var name = root.selectedTemplateName
        if (!name || !name.length) {
            console.warn("[TP_Content] Aucun template sélectionné pour suppression.")
            return
        }
        var ok = Game.deleteTemplate(name)
        if (ok) {
            if (root.selectedTemplateName === name) root.selectedTemplateName = ""
            refreshTemplateList()
        }
    }

    Component.onCompleted: {
        refreshTemplateList()
        // onVisibleChanged ne tire pas si visible est déjà true à la création
        // (signal change-only) — activer explicitement le mode template si c'est le cas.
        if (visible && logic && logic.mouseLogic && logic.mouseLogic.changeMouseMode) {
            _capturePreviousSelection()
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_TEMPLATE)
        }
    }

    // Activer le mode template quand le panneau devient visible
    onVisibleChanged: {
        if (!logic || !logic.mouseLogic) return

        if (visible) {
            console.log("[TP_Content] Activating TEMPLATE mode")
            refreshTemplateList()
            // Capturer la sélection AVANT le swap : le Loader va détruire
            // l'ancien MouseLogic et sa liste selectedElements avec.
            _capturePreviousSelection()
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_TEMPLATE)
        } else {
            console.log("[TP_Content] Deactivating TEMPLATE mode")
            
            // Sortir du mode placement si actif
            if (logic.mouseLogic.isPlacementMode) {
                logic.mouseLogic.exitPlacementMode()
            }
            
            // Nettoyer la sélection template si on quitte le mode
            if (logic.mouseLogic.clearTemplateSelection) {
                logic.mouseLogic.clearTemplateSelection()
            }
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
    }

    // Arrière-plan
    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    // Contenu principal
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingXL

        // ==================== COLONNE 1: BOUTONS ====================
        ColumnLayout {
            Layout.preferredWidth: 110
            Layout.fillHeight: true
            spacing: Theme.spacingL

            // Bouton Enregistrer
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: root.buttonHeight
                Layout.alignment: Qt.AlignHCenter
                radius: Theme.radiusL
                color: saveMouseArea.containsMouse ? "#2d5a2d" : "#1e3d1e"
                border.color: Theme.success
                border.width: 2

                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    Text {
                        text: "💾"
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Text {
                        text: "Enregistrer"
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                MouseArea {
                    id: saveMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.requestSaveTemplate()
                    }
                }
            }

            // Bouton Supprimer
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: root.buttonHeight
                Layout.alignment: Qt.AlignHCenter
                radius: Theme.radiusL
                color: deleteMouseArea.containsMouse ? "#5a2d2d" : "#3d1e1e"
                border.color: Theme.danger
                border.width: 2

                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    Text {
                        text: "🗑️"
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Text {
                        text: "Supprimer"
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                MouseArea {
                    id: deleteMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        root.requestDeleteTemplate()
                    }
                }
            }

            // Espaceur
            Item {
                Layout.fillHeight: true
            }
        }

        // ==================== SÉPARATEUR VERTICAL ====================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            Layout.leftMargin: Theme.spacingXXL
            Layout.rightMargin: Theme.spacingXXL
            color: Theme.surfaceHover
        }

        // ==================== COLONNE 2: LISTE DES TEMPLATES ====================
        ColumnLayout {
            Layout.preferredWidth: 140
            Layout.fillHeight: true
            spacing: Theme.spacingM

            // Titre
            Text {
                text: "📋 Templates"
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }

            // Liste des templates
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusM
                color: "#252525"
                border.color: Theme.surfaceHover
                border.width: 1

                ListView {
                    id: templateListView
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    clip: true
                    spacing: Theme.spacingXS

                    model: root.templateNameList

                    delegate: Rectangle {
                        width: templateListView.width
                        height: root.listItemHeight
                        radius: Theme.radiusM
                        property string templateName: modelData
                        color: {
                            if (root.selectedTemplateName === templateName) {
                                return "#3d5a80"
                            }
                            return itemMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                        }
                        border.color: root.selectedTemplateName === templateName ? Theme.hover(Theme.accent) : "transparent"
                        border.width: 2

                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingL
                            anchors.rightMargin: Theme.spacingL
                            spacing: Theme.spacingM

                            Text {
                                text: "📁"
                                font.pixelSize: Theme.fontSizeBody
                            }

                            Text {
                                text: templateName
                                font.pixelSize: Theme.fontSizeBody
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.selectedTemplateName === templateName ? "✓" : ""
                                font.pixelSize: Theme.fontSizeBody
                                color: Theme.hover(Theme.accent)
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                root.selectedTemplateName = templateName

                                // Filet de sécurité : si le mode a dérivé (side-effects
                                // de tab switch etc.), reforcer EM_TEMPLATE avant
                                // d'appeler enterPlacementMode (dispo uniquement sur
                                // MouseLogic_Template).
                                if (logic.editorMouseMode !== EditorEnum.EM_TEMPLATE
                                        && logic && logic.mouseLogic
                                        && logic.mouseLogic.changeMouseMode) {
                                    logic.mouseLogic.changeMouseMode(EditorEnum.EM_TEMPLATE)
                                }

                                if (logic && logic.mouseLogic && logic.mouseLogic.enterPlacementMode) {
                                    var success = logic.mouseLogic.enterPlacementMode(templateName)
                                    if (!success) {
                                        console.warn("[TP_Content] Failed to enter placement mode for:", templateName)
                                        root.selectedTemplateName = ""
                                    }
                                }
                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded

                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: Theme.radiusXS
                            color: Theme.borderLight
                        }

                        background: Rectangle {
                            implicitWidth: 6
                            radius: Theme.radiusXS
                            color: Theme.surface
                        }
                    }
                }
            }
        }

        // Espaceur pour ne pas utiliser toute la largeur
        Item {
            Layout.fillWidth: true
        }
    }

    // Popup pour saisir le nom du template à enregistrer
    Popup {
        id: saveTemplatePopup
        parent: root
        anchors.centerIn: parent
        width: Math.min(320, root.width * 0.9)
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        padding: Theme.spacingXXL
        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.spacingXL

            Text {
                text: "Nom du template"
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                color: Theme.textPrimary
            }

            TextField {
                id: saveNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholderText: "Ex: Village, Foret..."
                placeholderTextColor: Theme.textDisabled
                selectByMouse: true
                font.pixelSize: Theme.fontSizeBody
                color: Theme.textPrimary
                onAccepted: root.doSaveTemplate(text)

                background: Rectangle {
                    radius: Theme.radiusM
                    color: Theme.surface
                    border.color: saveNameInput.activeFocus ? Theme.hover(Theme.accent) : Theme.surfaceHover
                    border.width: 2
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Theme.spacingM

                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    radius: Theme.radiusM
                    color: cancelBtnMouseArea.containsMouse ? Theme.surfaceHover : Theme.surface
                    border.color: Theme.surfaceHover
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                    Text {
                        anchors.centerIn: parent
                        text: "Annuler"
                        font.pixelSize: Theme.fontSizeBody
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        id: cancelBtnMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: saveTemplatePopup.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 32
                    radius: Theme.radiusM
                    color: saveBtnMouseArea.containsMouse ? "#2d5a2d" : "#1e3d1e"
                    border.color: Theme.success
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                    Text {
                        anchors.centerIn: parent
                        text: "Enregistrer"
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    MouseArea {
                        id: saveBtnMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: root.doSaveTemplate(saveNameInput.text)
                    }
                }
            }
        }

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            radius: Theme.radiusL
        }
    }
}
