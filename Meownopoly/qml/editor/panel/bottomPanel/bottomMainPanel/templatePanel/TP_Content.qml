import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel

// Import des modules Template
import TemplateManager
import TemplateModel

/**
 * Panneau pour gérer les templates (groupes d'éléments réutilisables)
 * 
 * Ce panneau permet:
 * - De créer de nouveaux templates à partir d'éléments sélectionnés
 * - De visualiser et sélectionner des templates existants
 * - De poser des templates sur la carte
 */
EBP_Content {
    id: root

    required property var logic

    // Propriétés internes pour gérer l'état de l'interface
    property string templateName: ""
    
    // Propriété pour suivre le nombre d'éléments sélectionnés
    property int selectedElementsCount: 0
    
    // Mode actuel: "create" pour créer, "select" pour sélectionner un template existant
    property string currentMode: "select"
    
    // Template actuellement sélectionné pour placement
    property string selectedTemplateName: ""

    // Signaux
    signal templateCreated(string name, var elements)
    signal templateCancelled()
    signal templateSelectedForPlacement(string name)

    sidePanelRatio: 0

    // Activer automatiquement le mode template quand le panneau devient visible
    onVisibleChanged: {
        if (visible) {
            activateTemplateMode()
            TemplateModel.refresh()
        } else {
            deactivateTemplateMode()
        }
    }

    Component.onCompleted: {
        if (visible) {
            activateTemplateMode()
            TemplateModel.refresh()
        }
    }

    function activateTemplateMode() {
        if (logic && logic.editorMouseMode !== EditorEnum.EM_TEMPLATE) {
            logic.editorMouseMode = EditorEnum.EM_TEMPLATE
            console.log("Template mode activated")
        }
    }

    function deactivateTemplateMode() {
        if (logic && logic.editorMouseMode === EditorEnum.EM_TEMPLATE) {
            logic.editorMouseMode = EditorEnum.EM_NORMAL
            console.log("Template mode deactivated")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // --- En-tête avec tabs ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 5

            // Tab: Sélection de template
            Button {
                id: selectTabBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                text: "📋 Templates"
                
                background: Rectangle {
                    radius: 6
                    color: root.currentMode === "select" ? "#4A90E2" : "#333333"
                    border.color: Qt.lighter(color, 1.2)
                    border.width: 1
                }
                
                contentItem: Text {
                    text: selectTabBtn.text
                    font.pointSize: 10
                    font.bold: root.currentMode === "select"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    root.currentMode = "select"
                    if (logic && logic.mouseLogic) {
                        logic.mouseLogic.unselectSelectedElements()
                    }
                }
            }

            // Tab: Création de template
            Button {
                id: createTabBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                text: "✨ Créer"
                
                background: Rectangle {
                    radius: 6
                    color: root.currentMode === "create" ? "#4CAF50" : "#333333"
                    border.color: Qt.lighter(color, 1.2)
                    border.width: 1
                }
                
                contentItem: Text {
                    text: createTabBtn.text
                    font.pointSize: 10
                    font.bold: root.currentMode === "create"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    root.currentMode = "create"
                    TemplateManager.clearSelection()
                    root.selectedTemplateName = ""
                }
            }
        }

        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }

        // === MODE SÉLECTION DE TEMPLATE ===
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentMode === "select"
            spacing: 8

            // Titre
            Text {
                text: "Sélectionnez un template à placer"
                font.pointSize: 10
                color: "#aaaaaa"
                Layout.alignment: Qt.AlignHCenter
            }

            // Liste des templates
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1a1a2e"
                radius: 8
                border.color: "#333333"
                border.width: 1

                ListView {
                    id: templateListView
                    anchors.fill: parent
                    anchors.margins: 5
                    clip: true
                    spacing: 4
                    
                    model: TemplateModel
                    
                    delegate: Rectangle {
                        width: templateListView.width
                        height: 60
                        radius: 6
                        color: root.selectedTemplateName === model.name ? "#3A5F8A" : (mouseArea.containsMouse ? "#2c3e50" : "#252540")
                        border.color: model.isDefault ? "#FFD700" : (root.selectedTemplateName === model.name ? "#4A90E2" : "#333333")
                        border.width: root.selectedTemplateName === model.name ? 2 : 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            // Icône/Preview
                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: 6
                                color: model.isDefault ? "#2d4a2d" : "#1e3a5f"
                                border.color: model.isDefault ? "#4CAF50" : "#4A90E2"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: model.isDefault ? "📦" : "🎨"
                                    font.pointSize: 18
                                }
                            }

                            // Informations
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: model.name
                                    font.pointSize: 10
                                    font.bold: true
                                    color: "white"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 10
                                    
                                    Text {
                                        text: model.elementCount + " éléments"
                                        font.pointSize: 8
                                        color: "#888888"
                                    }
                                    
                                    Text {
                                        text: model.boundingBoxWidth + "×" + model.boundingBoxHeight
                                        font.pointSize: 8
                                        color: "#666666"
                                    }
                                    
                                    Text {
                                        visible: model.isDefault
                                        text: "Par défaut"
                                        font.pointSize: 8
                                        color: "#FFD700"
                                    }
                                }
                            }

                            // Bouton supprimer (seulement pour les templates utilisateur)
                            Button {
                                visible: !model.isDefault
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                text: "🗑️"
                                
                                background: Rectangle {
                                    radius: 4
                                    color: parent.hovered ? "#c0392b" : "transparent"
                                }
                                
                                onClicked: {
                                    deleteConfirmDialog.templateToDelete = model.name
                                    deleteConfirmDialog.open()
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            
                            onClicked: {
                                root.selectedTemplateName = model.name
                                TemplateManager.selectTemplate(model.name)
                                root.templateSelectedForPlacement(model.name)
                                console.log("Template selected for placement:", model.name)
                            }
                        }
                    }

                    // Message si liste vide
                    Text {
                        anchors.centerIn: parent
                        visible: templateListView.count === 0
                        text: "Aucun template disponible.\nCréez-en un nouveau !"
                        font.pointSize: 10
                        color: "#666666"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Bouton rafraîchir
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                text: "🔄 Rafraîchir la liste"
                
                background: Rectangle {
                    radius: 6
                    color: parent.hovered ? "#3A5F8A" : "#2c3e50"
                    border.color: "#4A90E2"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: parent.text
                    font.pointSize: 9
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: {
                    TemplateModel.refresh()
                }
            }

            // Info sur le template sélectionné
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                visible: root.selectedTemplateName !== ""
                color: "#2c3e50"
                radius: 6
                border.color: "#4A90E2"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    
                    Text {
                        text: "🎯 Cliquez sur la grille pour placer: "
                        font.pointSize: 9
                        color: "#aaaaaa"
                    }
                    
                    Text {
                        text: root.selectedTemplateName
                        font.pointSize: 10
                        font.bold: true
                        color: "#4A90E2"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // === MODE CRÉATION DE TEMPLATE ===
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentMode === "create"
            spacing: 8

            // Instructions
            Text {
                text: "Cliquez sur les éléments pour les sélectionner/désélectionner"
                font.pointSize: 9
                color: "#aaaaaa"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            // Layout horizontal principal
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Colonne gauche: Nom et compteur
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width / 2
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    // Nom du template
                    Text {
                        text: "Nom du template"
                        color: "white"
                        font.pointSize: 10
                        font.bold: true
                    }

                    TextField {
                        id: templateNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        placeholderText: "Entrez le nom..."
                        placeholderTextColor: "#888888"
                        color: "white"
                        font.pointSize: 10

                        background: Rectangle {
                            color: "#333333"
                            radius: 6
                            border.color: templateNameField.activeFocus ? "#4A90E2" : "#555555"
                            border.width: templateNameField.activeFocus ? 2 : 1
                        }

                        onTextChanged: {
                            root.templateName = text
                        }
                    }

                    // Indicateur de sélection
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        color: "#2c3e50"
                        radius: 6
                        border.color: root.selectedElementsCount > 0 ? "#4CAF50" : "#555555"
                        border.width: 1

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            Text {
                                text: "Éléments sélectionnés"
                                font.pointSize: 8
                                color: "#aaaaaa"
                            }

                            Text {
                                text: root.selectedElementsCount.toString()
                                font.pointSize: 16
                                font.bold: true
                                color: root.selectedElementsCount > 0 ? "#4CAF50" : "#888888"
                            }
                        }
                    }
                }

                // Colonne droite: Boutons
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width / 2
                    Layout.alignment: Qt.AlignTop
                    spacing: 8

                    // Bouton Créer
                    Button {
                        id: createTemplateButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        enabled: root.selectedElementsCount > 0 && root.templateName.length > 0

                        text: "✅ Créer Template"

                        background: Rectangle {
                            radius: 6
                            color: createTemplateButton.enabled ? "#4CAF50" : "#555555"
                            border.color: Qt.lighter(color, 1.2)
                            border.width: 1
                            opacity: createTemplateButton.hovered && createTemplateButton.enabled ? 0.9 : 1.0
                        }

                        contentItem: Text {
                            text: createTemplateButton.text
                            font.pointSize: 11
                            font.bold: true
                            color: createTemplateButton.enabled ? "white" : "#888888"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            createTemplate()
                        }
                    }

                    // Bouton Annuler sélection
                    Button {
                        id: cancelButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        text: "🗑️ Annuler sélection"

                        background: Rectangle {
                            radius: 6
                            color: "#c0392b"
                            border.color: Qt.lighter(color, 1.2)
                            border.width: 1
                            opacity: cancelButton.hovered ? 0.9 : 1.0
                        }

                        contentItem: Text {
                            text: cancelButton.text
                            font.pointSize: 9
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            cancelTemplateCreation()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // --- Dialog de confirmation de suppression ---
    Dialog {
        id: deleteConfirmDialog
        title: "Confirmer la suppression"
        modal: true
        anchors.centerIn: parent
        
        property string templateToDelete: ""

        background: Rectangle {
            color: "#2c2c3e"
            radius: 10
            border.color: "#c0392b"
            border.width: 2
        }

        contentItem: ColumnLayout {
            spacing: 15
            
            Text {
                text: "Voulez-vous vraiment supprimer le template\n\"" + deleteConfirmDialog.templateToDelete + "\" ?"
                color: "white"
                font.pointSize: 10
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    Layout.fillWidth: true
                    text: "Annuler"
                    onClicked: deleteConfirmDialog.close()
                    
                    background: Rectangle {
                        radius: 6
                        color: "#555555"
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Supprimer"
                    onClicked: {
                        TemplateManager.deleteTemplate(deleteConfirmDialog.templateToDelete)
                        if (root.selectedTemplateName === deleteConfirmDialog.templateToDelete) {
                            root.selectedTemplateName = ""
                        }
                        deleteConfirmDialog.close()
                    }
                    
                    background: Rectangle {
                        radius: 6
                        color: "#c0392b"
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    // --- Fonctions utilitaires ---

    function createTemplate() {
        if (logic && logic.mouseLogic) {
            var selectedElements = logic.mouseLogic.selectedElements
            if (selectedElements.length > 0 && root.templateName.length > 0) {
                // Convertir les éléments en JSON pour le TemplateManager
                var elementsJson = []
                for (var i = 0; i < selectedElements.length; i++) {
                    var element = selectedElements[i]
                    if (element && element.snapableParameters) {
                        var jsonStr = element.snapableParameters.toJSON()
                        try {
                            elementsJson.push(JSON.parse(jsonStr))
                        } catch (e) {
                            console.error("Failed to parse element JSON:", e)
                        }
                    }
                }
                
                // Créer le template via TemplateManager
                if (TemplateManager.createTemplateFromJson(root.templateName, elementsJson)) {
                    console.log("Template créé avec succès:", root.templateName)
                    
                    // Émettre le signal
                    root.templateCreated(root.templateName, {
                        name: root.templateName,
                        elements: selectedElements,
                        elementCount: selectedElements.length
                    })
                    
                    // Réinitialiser l'interface
                    resetInterface()
                    
                    // Retourner au mode sélection
                    root.currentMode = "select"
                } else {
                    console.error("Échec de la création du template")
                }
            }
        }
    }

    function cancelTemplateCreation() {
        if (logic && logic.mouseLogic) {
            logic.mouseLogic.unselectSelectedElements()
        }
        root.templateCancelled()
    }

    function resetInterface() {
        templateNameField.text = ""
        root.templateName = ""
        
        if (logic && logic.mouseLogic) {
            logic.mouseLogic.unselectSelectedElements()
        }
    }

    // Mise à jour automatique du compteur d'éléments sélectionnés
    Binding {
        target: root
        property: "selectedElementsCount"
        value: (logic && logic.mouseLogic && logic.mouseLogic.selectedElements) 
               ? logic.mouseLogic.selectedElements.length 
               : 0
        when: logic && logic.mouseLogic
    }
    
    // Connexion au signal templateSelectionChanged
    Connections {
        id: templateConnections
        enabled: logic && logic.mouseLogic
        target: enabled ? logic.mouseLogic : null
        function onTemplateSelectionChanged() {
            if (logic && logic.mouseLogic && logic.mouseLogic.selectedElements) {
                root.selectedElementsCount = logic.mouseLogic.selectedElements.length
            }
        }
    }
    
    // Connexion aux signaux du TemplateManager
    Connections {
        target: TemplateManager
        
        function onTemplateCreated(templateName) {
            console.log("Template créé signal reçu:", templateName)
            TemplateModel.refresh()
        }
        
        function onTemplateDeleted(templateName) {
            console.log("Template supprimé signal reçu:", templateName)
            TemplateModel.refresh()
        }
    }
}
