import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum
import Game
import TemplateFileManager

import "../"
import editorBottomPanel

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
        color: "#1a1a1a"
    }

    // Contenu principal
    RowLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ==================== COLONNE 1: BOUTONS ====================
        ColumnLayout {
            Layout.preferredWidth: 110
            Layout.fillHeight: true
            spacing: 10

            // Bouton Enregistrer
            Rectangle {
                Layout.preferredWidth: 100
                Layout.preferredHeight: root.buttonHeight
                Layout.alignment: Qt.AlignHCenter
                radius: 8
                color: saveMouseArea.containsMouse ? "#2d5a2d" : "#1e3d1e"
                border.color: "#4CAF50"
                border.width: 2

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "💾"
                        font.pointSize: 12
                    }

                    Text {
                        text: "Enregistrer"
                        font.pointSize: 9
                        font.bold: true
                        color: "#ffffff"
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
                radius: 8
                color: deleteMouseArea.containsMouse ? "#5a2d2d" : "#3d1e1e"
                border.color: "#F44336"
                border.width: 2

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "🗑️"
                        font.pointSize: 12
                    }

                    Text {
                        text: "Supprimer"
                        font.pointSize: 9
                        font.bold: true
                        color: "#ffffff"
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
            Layout.leftMargin: 15
            Layout.rightMargin: 15
            color: "#3a3a3a"
        }

        // ==================== COLONNE 2: LISTE DES TEMPLATES ====================
        ColumnLayout {
            Layout.preferredWidth: 140
            Layout.fillHeight: true
            spacing: 8

            // Titre
            Text {
                text: "📋 Templates"
                font.pointSize: 10
                font.bold: true
                color: "#ffffff"
                Layout.alignment: Qt.AlignHCenter
            }

            // Liste des templates
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 6
                color: "#252525"
                border.color: "#3a3a3a"
                border.width: 1

                ListView {
                    id: templateListView
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    spacing: 4

                    model: root.templateNameList

                    delegate: Rectangle {
                        width: templateListView.width
                        height: root.listItemHeight
                        radius: 6
                        property string templateName: modelData
                        color: {
                            if (root.selectedTemplateName === templateName) {
                                return "#3d5a80"
                            }
                            return itemMouseArea.containsMouse ? "#353535" : "#2a2a2a"
                        }
                        border.color: root.selectedTemplateName === templateName ? "#5DADE2" : "transparent"
                        border.width: 2

                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: "📁"
                                font.pointSize: 10
                            }

                            Text {
                                text: templateName
                                font.pointSize: 9
                                color: "#ffffff"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.selectedTemplateName === templateName ? "✓" : ""
                                font.pointSize: 10
                                color: "#5DADE2"
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
                            radius: 3
                            color: "#5a5a5a"
                        }

                        background: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: "#2a2a2a"
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

        padding: 16
        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                text: "Nom du template"
                font.pointSize: 10
                font.bold: true
                color: "#ffffff"
            }

            TextField {
                id: saveNameInput
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                placeholderText: "Ex: Village, Foret..."
                placeholderTextColor: "#666666"
                selectByMouse: true
                font.pointSize: 9
                color: "#ffffff"
                onAccepted: root.doSaveTemplate(text)

                background: Rectangle {
                    radius: 6
                    color: "#2a2a2a"
                    border.color: saveNameInput.activeFocus ? "#5DADE2" : "#3a3a3a"
                    border.width: 2
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    radius: 6
                    color: cancelBtnMouseArea.containsMouse ? "#3a3a3a" : "#2a2a2a"
                    border.color: "#3a3a3a"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Annuler"
                        font.pointSize: 9
                        color: "#b0b0b0"
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
                    radius: 6
                    color: saveBtnMouseArea.containsMouse ? "#2d5a2d" : "#1e3d1e"
                    border.color: "#4CAF50"
                    border.width: 2

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Enregistrer"
                        font.pointSize: 9
                        font.bold: true
                        color: "#ffffff"
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
            color: "#2a2a2a"
            border.color: "#4a4a4a"
            radius: 8
        }
    }
}
