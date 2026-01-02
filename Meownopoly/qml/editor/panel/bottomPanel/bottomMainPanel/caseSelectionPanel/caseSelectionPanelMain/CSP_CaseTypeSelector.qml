import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import editorBottomPanel

EBP_Content {
    id: root
    
    // Propriétés requises par EBP_Content
    currentView: "categories"
    activeFilter: "All"
    isExpanded: true
    
    // Propriétés spécifiques
    property int selectedType: -1
    property int gridColumns: 4
    
    // Signaux
    signal typeSelected(int type, string typeName)
    signal typeCleared()
    
    // Modèle des types de cases
    ListModel {
        id: caseTypesModel
        
        ListElement {
            modelCaseType: 0
            modelCaseName: "Départ"
            modelCaseIcon: "🏁"
            modelCaseColor: "#FFD700"
            modelCaseCategory: "Event"
        }
        ListElement {
            modelCaseType: 1
            modelCaseName: "Propriétés"
            modelCaseIcon: "🏠"
            modelCaseColor: "#4CAF50"
            modelCaseCategory: "Property"
        }
        ListElement {
            modelCaseType: 2
            modelCaseName: "Caisse de Communauté"
            modelCaseIcon: "📦"
            modelCaseColor: "#2196F3"
            modelCaseCategory: "Event"
        }
        ListElement {
            modelCaseType: 3
            modelCaseName: "Chance"
            modelCaseIcon: "🎲"
            modelCaseColor: "#FF9800"
            modelCaseCategory: "Event"
        }
        ListElement {
            modelCaseType: 4
            modelCaseName: "Prison (Visite)"
            modelCaseIcon: "🔒"
            modelCaseColor: "#9C27B0"
            modelCaseCategory: "Event"
        }
        ListElement {
            modelCaseType: 5
            modelCaseName: "Allez en Prison"
            modelCaseIcon: "⬆️"
            modelCaseColor: "#F44336"
            modelCaseCategory: "Event"
        }
        ListElement {
            modelCaseType: 6
            modelCaseName: "Gares"
            modelCaseIcon: "🚂"
            modelCaseColor: "#795548"
            modelCaseCategory: "Property"
        }
        ListElement {
            modelCaseType: 7
            modelCaseName: "Parc Gratuit"
            modelCaseIcon: "🆓"
            modelCaseColor: "#00BCD4"
            modelCaseCategory: "Event"
        }
        ListElement {
            modelCaseType: 8
            modelCaseName: "Compagnies"
            modelCaseIcon: "⚡"
            modelCaseColor: "#FFC107"
            modelCaseCategory: "Property"
        }
        ListElement {
            modelCaseType: 9
            modelCaseName: "Taxes"
            modelCaseIcon: "💰"
            modelCaseColor: "#607D8B"
            modelCaseCategory: "Event"
        }
    }
    
    // Fonction pour filtrer les types selon la catégorie active
    function getFilteredModel() {
        var filtered = []
        for (var i = 0; i < caseTypesModel.count; i++) {
            var item = caseTypesModel.get(i)
            if (root.activeFilter === "All" || item.modelCaseCategory === root.activeFilter) {
                filtered.push(item)
            }
        }
        return filtered
    }
    
    // Contenu principal
    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 8
        
        // Grille des types de cases
        GridLayout {
            id: gridLayout
            width: scrollView.width - 20
            columns: root.gridColumns
            rowSpacing: 12
            columnSpacing: 12
            
            // Repeater pour créer les cellules
            Repeater {
                id: repeater
                model: getFilteredModel()
                
                CSP_CaseTypeCell {
                    id: cell
                    required property int modelCaseType
                    required property string modelCaseName
                    required property string modelCaseIcon
                    required property color modelCaseColor
                    required property string modelCaseCategory

                    caseType: modelCaseType
                    caseName: modelCaseName
                    caseIcon: modelCaseIcon
                    caseColor: modelCaseColor

                    isSelected: root.selectedType === caseType
                    
                    // Calculer la largeur en fonction du nombre de colonnes
                    Layout.preferredWidth: (gridLayout.width - (gridLayout.columnSpacing * (gridLayout.columns - 1))) / gridLayout.columns
                    Layout.preferredHeight: 80
                    
                    onClicked: function(type) {
                        if (root.selectedType === type) {
                            // Désélectionner si déjà sélectionné
                            root.selectedType = -1
                            root.typeCleared()
                        } else {
                            // Sélectionner le nouveau type
                            root.selectedType = type
                            root.typeSelected(type, caseName)
                        }
                    }
                    
                    onHovered: function(hovered) {
                        // Feedback visuel au survol
                        if (hovered) {
                            cell.scale = 1.05
                        } else {
                            cell.scale = 1.0
                        }
                    }
                    
                    // Animation de scale
                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    // Fonction pour calculer le nombre de colonnes optimal
    function calculateOptimalColumns() {
        var availableWidth = width - 40 // Marges
        var cellWidth = 80
        var spacing = 12
        var optimalColumns = Math.floor((availableWidth + spacing) / (cellWidth + spacing))
        return Math.max(2, Math.min(optimalColumns, 6)) // Entre 2 et 6 colonnes
    }
    function clearCaseSelection()
    {
        root.selectedType = -1
        root.typeCleared()
    }
    
    // Mise à jour automatique du nombre de colonnes
    onWidthChanged: {
        root.gridColumns = calculateOptimalColumns()
    }
    
    Component.onCompleted: {
        root.gridColumns = calculateOptimalColumns()
    }
}
