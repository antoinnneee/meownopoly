import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

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

    sidePanelRatio: 0

    // Activer le mode template quand le panneau devient visible
    onVisibleChanged: {
        if (!logic || !logic.mouseLogic) return
        
        if (visible) {
            console.log("[TP_Content] Activating TEMPLATE mode")
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_TEMPLATE)
        } else {
            console.log("[TP_Content] Deactivating TEMPLATE mode")
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
                        console.log("Enregistrer template")
                        // TODO: Logique d'enregistrement
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
                        console.log("Supprimer template: " + root.selectedTemplateName)
                        // TODO: Logique de suppression
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

                    model: ListModel {
                        ListElement { name: "Village" }
                        ListElement { name: "Foret" }
                        ListElement { name: "Montagne" }
                    }

                    delegate: Rectangle {
                        width: templateListView.width
                        height: root.listItemHeight
                        radius: 6
                        color: {
                            if (root.selectedTemplateName === model.name) {
                                return "#3d5a80"
                            }
                            return itemMouseArea.containsMouse ? "#353535" : "#2a2a2a"
                        }
                        border.color: root.selectedTemplateName === model.name ? "#5DADE2" : "transparent"
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
                                text: model.name
                                font.pointSize: 9
                                color: "#ffffff"
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.selectedTemplateName === model.name ? "✓" : ""
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
                                root.selectedTemplateName = model.name
                                console.log("Template sélectionné: " + model.name)
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
}
