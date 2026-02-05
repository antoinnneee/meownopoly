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
     * Construit un tableau d'objets JSON à partir des éléments sélectionnés.
     * Chaque objet a gridRelativePositionX/Y en top-level pour le C++.
     */
    function buildElementsJsonFromSelection() {
        if (!logic || !logic.mouseLogic || !logic.mouseLogic.getTemplateSelectedElements){
            console.log("Error : buildElementsJsonFromSelection() Can't access logic or its content")
            return []
        }
        var elements = logic.mouseLogic.getTemplateSelectedElements()
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
            if (obj.displayParameter) {
                obj.gridRelativePositionX = obj.displayParameter.gridRelativePositionX
                obj.gridRelativePositionY = obj.displayParameter.gridRelativePositionY
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
    }

    // Activer le mode template quand le panneau devient visible
    onVisibleChanged: {
        if (!logic || !logic.mouseLogic) return
        
        if (visible) {
            console.log("[TP_Content] Activating TEMPLATE mode")
            refreshTemplateList()
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
                                console.log("Template sélectionné: " + templateName)
                                
                                // Activer le mode placement
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
                placeholderText: "Ex: Village, Foret..."
                font.pointSize: 9
                onAccepted: root.doSaveTemplate(text)
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8

                Button {
                    text: "Annuler"
                    font.pointSize: 9
                    onClicked: saveTemplatePopup.close()
                }
                Button {
                    text: "Enregistrer"
                    font.pointSize: 9
                    highlighted: true
                    onClicked: root.doSaveTemplate(saveNameInput.text)
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
