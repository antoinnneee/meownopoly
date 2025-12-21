import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel

/**
 * Panneau pour gérer les templates (groupes d'éléments réutilisables)
 */
EBP_Content {
    id: root

    required property var logic

    // Propriétés internes pour gérer l'état de l'interface
    property string templateName: ""
    property string templateDescription: ""
    property color templateColor: "#4A90E2"
    
    // Propriété pour suivre si le mode template est actif
    property bool isTemplateModeActive: logic && logic.editorMouseMode === EditorEnum.EM_TEMPLATE
    
    // Propriété pour suivre le nombre d'éléments sélectionnés
    property int selectedElementsCount: logic && logic.mouseLogic ? logic.mouseLogic.selectedElements.length : 0

    // Signaux
    signal templateModeActivated()
    signal templateModeDeactivated()
    signal templateCreated(string name, var elements)
    signal templateCancelled()

    sidePanelRatio: 0

    ScrollView {
        id: mainContentScroll
        anchors.fill: parent
        anchors.margins: 10
        clip: true
        contentHeight: contentLayout.height

        // Layout horizontal principal avec 2 colonnes
        RowLayout {
            id: contentLayout
            width: mainContentScroll.width - 20
            spacing: 20

            // ==================== COLONNE GAUCHE ====================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / 2
                Layout.alignment: Qt.AlignTop
                spacing: 10

                // --- En-tête ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Création de Template"
                        font.pointSize: 13
                        font.bold: true
                        color: "white"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Sélectionnez des éléments pour créer un template réutilisable."
                        font.pointSize: 8
                        color: "#aaaaaa"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#444444"
                }

                // --- Nom du template ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Nom du template"
                        color: "white"
                        font.pointSize: 10
                        font.bold: true
                    }

                    TextField {
                        id: templateNameField
                        Layout.fillWidth: true
                        placeholderText: "Entrez le nom du template..."
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
                }

                // --- Description du template ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Description (optionnel)"
                        color: "white"
                        font.pointSize: 10
                        font.bold: true
                    }

                    TextArea {
                        id: templateDescriptionField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        placeholderText: "Description du template..."
                        placeholderTextColor: "#888888"
                        color: "white"
                        font.pointSize: 9
                        wrapMode: TextEdit.Wrap

                        background: Rectangle {
                            color: "#333333"
                            radius: 6
                            border.color: templateDescriptionField.activeFocus ? "#4A90E2" : "#555555"
                            border.width: templateDescriptionField.activeFocus ? 2 : 1
                        }

                        onTextChanged: {
                            root.templateDescription = text
                        }
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#444444"
                }

                // --- Couleur du template ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Couleur du template"
                        color: "white"
                        font.pointSize: 10
                        font.bold: true
                    }

                    // Grille de couleurs
                    Grid {
                        Layout.alignment: Qt.AlignHCenter
                        columns: 8
                        spacing: 6

                        Repeater {
                            model: ["#4A90E2", "#E91E63", "#9C27B0", "#3F51B5",
                                    "#00BCD4", "#4CAF50", "#FFEB3B", "#FF9800"]

                            Rectangle {
                                width: 30
                                height: 30
                                radius: 15
                                color: modelData
                                border.color: root.templateColor === modelData ? "white" : "#555555"
                                border.width: root.templateColor === modelData ? 3 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.templateColor = modelData
                                        updateTemplateVisualization()
                                    }
                                }

                                Behavior on border.width {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                }
            }

            // ==================== COLONNE DROITE ====================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / 2
                Layout.alignment: Qt.AlignTop
                spacing: 10

                // --- Bouton Mode Sélection ---
                Button {
                    id: selectButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    text: root.isTemplateModeActive ? "❌ Quitter le mode sélection" : "🔲 Sélectionner des éléments"

                    background: Rectangle {
                        radius: 8
                        color: root.isTemplateModeActive ? "#c0392b" : "#4A90E2"
                        border.color: Qt.lighter(color, 1.2)
                        border.width: 2

                        Behavior on color {
                            ColorAnimation { duration: 200 }
                        }

                        opacity: selectButton.hovered ? 0.9 : 1.0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    contentItem: Text {
                        text: selectButton.text
                        font.pointSize: 10
                        font.bold: true
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (root.isTemplateModeActive) {
                            // Désactiver le mode template
                            if (logic && logic.mouseLogic) {
                                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                            }
                            root.templateModeDeactivated()
                        } else {
                            // Activer le mode template
                            if (logic && logic.mouseLogic) {
                                logic.mouseLogic.changeMouseMode(EditorEnum.EM_TEMPLATE)
                            }
                            root.templateModeActivated()
                        }
                    }
                }

                // --- Indicateur de sélection ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    color: "#2c3e50"
                    radius: 6
                    border.color: root.selectedElementsCount > 0 ? "#4CAF50" : "#555555"
                    border.width: 2

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "Éléments sélectionnés"
                            font.pointSize: 9
                            color: "#aaaaaa"
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.selectedElementsCount.toString()
                            font.pointSize: 18
                            font.bold: true
                            color: root.selectedElementsCount > 0 ? "#4CAF50" : "#888888"
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // --- Instructions ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: instructionsText.height + 16
                    visible: root.isTemplateModeActive
                    color: "#2c3e50"
                    radius: 6
                    border.color: "#4A90E2"
                    border.width: 2

                    Text {
                        id: instructionsText
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: "• Clic gauche : sélectionner un élément\n• Ctrl + Clic : ajouter à la sélection\n• Glisser : sélection rectangle\n• Clic sur espace vide : désélectionner"
                        font.pointSize: 8
                        color: "#4A90E2"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        lineHeight: 1.2
                    }
                }

                // Séparateur
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#444444"
                }

                // --- Boutons d'action ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Bouton Créer Template
                    Button {
                        id: createTemplateButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        enabled: root.selectedElementsCount > 0 && root.templateName.length > 0

                        text: "✅ Créer le template"

                        background: Rectangle {
                            radius: 8
                            color: createTemplateButton.enabled ? "#4CAF50" : "#555555"
                            border.color: Qt.lighter(color, 1.2)
                            border.width: 2
                            opacity: createTemplateButton.hovered && createTemplateButton.enabled ? 0.9 : 1.0
                        }

                        contentItem: Text {
                            text: createTemplateButton.text
                            font.pointSize: 10
                            font.bold: true
                            color: createTemplateButton.enabled ? "white" : "#888888"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            createTemplate()
                        }
                    }

                    // Bouton Générer Rectangle Englobant
                    Button {
                        id: generateBoundingRectButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        enabled: root.selectedElementsCount > 1

                        text: "📐 Générer rectangle englobant"

                        background: Rectangle {
                            radius: 8
                            color: generateBoundingRectButton.enabled ? "#FF9800" : "#555555"
                            border.color: Qt.lighter(color, 1.2)
                            border.width: 2
                            opacity: generateBoundingRectButton.hovered && generateBoundingRectButton.enabled ? 0.9 : 1.0
                        }

                        contentItem: Text {
                            text: generateBoundingRectButton.text
                            font.pointSize: 9
                            font.bold: true
                            color: generateBoundingRectButton.enabled ? "white" : "#888888"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (logic && logic.mouseLogic) {
                                logic.mouseLogic.generateBoundingRectangle(root.templateColor)
                            }
                        }
                    }

                    // Bouton Annuler
                    Button {
                        id: cancelButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 35

                        text: "🗑️ Annuler la sélection"

                        background: Rectangle {
                            radius: 8
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
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // --- Fonctions utilitaires ---

    function updateTemplateVisualization() {
        if (logic && logic.mouseLogic && logic.mouseLogic.updateSelectionColor) {
            logic.mouseLogic.updateSelectionColor(root.templateColor)
        }
    }

    function createTemplate() {
        if (logic && logic.mouseLogic) {
            var selectedElements = logic.mouseLogic.selectedElements
            if (selectedElements.length > 0) {
                // Générer le rectangle englobant
                var boundingRect = logic.mouseLogic.calculateBoundingRectangle()
                
                // Émettre le signal avec les informations du template
                root.templateCreated(root.templateName, {
                    name: root.templateName,
                    description: root.templateDescription,
                    color: root.templateColor,
                    elements: selectedElements,
                    boundingRect: boundingRect
                })
                
                console.log("Template créé:", root.templateName, "avec", selectedElements.length, "éléments")
                
                // Réinitialiser l'interface
                resetInterface()
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
        templateDescriptionField.text = ""
        root.templateName = ""
        root.templateDescription = ""
        root.templateColor = "#4A90E2"
        
        if (logic && logic.mouseLogic) {
            logic.mouseLogic.unselectSelectedElements()
        }
    }

    // Connexion pour mettre à jour le compteur d'éléments sélectionnés
    Connections {
        target: logic && logic.mouseLogic ? logic.mouseLogic : null
        function onTemplateSelectionChanged() {
            root.selectedElementsCount = logic.mouseLogic.selectedElements.length
        }
    }
}
