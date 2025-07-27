import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window
import Game

Rectangle {
    id: caseCreatorWindow
//    title: "Créateur de Cases - Meownopoly"
    width: 1200
    height: 800
//    modality: Qt.ApplicationModal
    color: "#f0f0f0"  // Fond gris clair fixe pour assurer la visibilité

    property var caseTypes: [
        { value: 0, text: "Départ" },
        { value: 1, text: "Propriété" },
        { value: 2, text: "Caisse de Communauté" },
        { value: 3, text: "Chance" },
        { value: 4, text: "Prison (Visite)" },
        { value: 5, text: "Allez en Prison" },
        { value: 6, text: "Gare" },
        { value: 7, text: "Parc Gratuit" },
        { value: 8, text: "Compagnie" },
        { value: 9, text: "Taxe" }
    ]

    property var familyTypes: [
        { value: null, text: "Aucune" },
        { value: 1, text: "Marron" },
        { value: 2, text: "Bleu clair" },
        { value: 3, text: "Rose" },
        { value: 4, text: "Orange" },
        { value: 5, text: "Rouge" },
        { value: 6, text: "Jaune" },
        { value: 7, text: "Vert" },
        { value: 8, text: "Bleu foncé" }
    ]

    // Modèle pour stocker les cases en attente
    ListModel {
        id: pendingCasesModel
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.bottomMargin: 80  // Espace pour le bandeau de boutons
        spacing: 20

        // Colonne de gauche - Formulaire de création
        ScrollView {
            Layout.preferredWidth: parent.width * 0.6
            Layout.fillHeight: true
            
            ColumnLayout {
                width: parent.width
                spacing: 20

                // En-tête
                Text {
                    text: "Créer de nouvelles cases"
                    font.pixelSize: 24
                    font.bold: true
                    color: "#4f5af8"
                    Layout.alignment: Qt.AlignHCenter
                }

                // Index - Rectangle pour tous les types
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    color: "white"
                    border.color: "#4f5af8"
                    border.width: 2
                    radius: 8
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        
                        Text {
                            text: "Index de la case :"
                            color: "#333"
                            font.pixelSize: 16
                            font.bold: true
                        }
                        
                        ComboBox {
                            id: indexCombo
                            model: Array.from({length: 100}, (_, i) => i)
                            currentIndex: 0
                            Layout.preferredWidth: 100
                        }
                    }
                }

                // Informations de base
                GroupBox {
                    title: "Informations de base"
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: "white"
                        border.color: "#4f5af8"
                        border.width: 1
                        radius: 6
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15
                        
                        RowLayout {
                            Text { 
                                text: "Type de case :" 
                                color: "#333"
                            }
                            ComboBox {
                                id: typeCombo
                                Layout.preferredWidth: 200
                                model: caseTypes
                                textRole: "text"
                                valueRole: "value"
                                onCurrentValueChanged: updateFieldsVisibility()
                            }
                        }
                        
                        RowLayout {
                            Text { 
                                text: "Nom :" 
                                color: "#333"
                            }
                            TextField {
                                id: nameField
                                Layout.fillWidth: true
                                placeholderText: "Nom de la case"
                            }
                        }
                        
                        RowLayout {
                            Text { 
                                text: "Position :" 
                                color: "#333"
                            }
                            SpinBox {
                                id: positionField
                                from: 0
                                to: 100
                                value: getNextPosition()
                            }
                        }
                    }
                }

                // Propriétés économiques
                GroupBox {
                    id: economicGroup
                    title: "Propriétés économiques"
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: "white"
                        border.color: "#4f5af8"
                        border.width: 1
                        radius: 6
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15
                        
                        RowLayout {
                            Text { 
                                text: "Prix d'achat :" 
                                color: "#333"
                            }
                            SpinBox {
                                id: priceField
                                from: 0
                                to: 999999
                                stepSize: 100
                            }
                        }
                        
                        RowLayout {
                            Text { 
                                text: "Prix d'hypothèque :" 
                                color: "#333"
                            }
                            SpinBox {
                                id: mortgagePriceField
                                from: 0
                                to: 999999
                                stepSize: 50
                            }
                        }
                        
                        RowLayout {
                            id: familyRow
                            Text { 
                                text: "Famille :" 
                                color: "#333"
                            }
                            ComboBox {
                                id: familyCombo
                                Layout.preferredWidth: 150
                                model: familyTypes
                                textRole: "text"
                                valueRole: "value"
                            }
                        }
                        
                        RowLayout {
                            id: travelPriceRow
                            visible: false
                            Text { 
                                text: "Prix de voyage :" 
                                color: "#333"
                            }
                            SpinBox {
                                id: travelPriceField
                                from: 0
                                to: 999999
                                stepSize: 25
                                value: 25
                            }
                        }
                    }
                }

                // Loyers
                GroupBox {
                    id: rentGroup
                    title: "Loyers"
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: "white"
                        border.color: "#4f5af8"
                        border.width: 1
                        radius: 6
                    }
                    
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        columns: 2
                        columnSpacing: 20
                        rowSpacing: 10
                        
                        Text { text: "Loyer de base :"; color: "#333" }
                        SpinBox { id: rent0Field; from: 0; to: 99999; stepSize: 10 }
                        
                        Text { text: "1 maison :"; color: "#333" }
                        SpinBox { id: rent1Field; from: 0; to: 99999; stepSize: 10 }
                        
                        Text { text: "2 maisons :"; color: "#333" }
                        SpinBox { id: rent2Field; from: 0; to: 99999; stepSize: 10 }
                        
                        Text { text: "3 maisons :"; color: "#333" }
                        SpinBox { id: rent3Field; from: 0; to: 99999; stepSize: 10 }
                        
                        Text { text: "Hôtel :"; color: "#333" }
                        SpinBox { id: rent4Field; from: 0; to: 99999; stepSize: 10 }
                    }
                }

                // Construction
                GroupBox {
                    id: constructionGroup
                    title: "Prix de construction"
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: "white"
                        border.color: "#4f5af8"
                        border.width: 1
                        radius: 6
                    }
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 15
                        
                        RowLayout {
                            Text { 
                                text: "Prix maison :" 
                                color: "#333"
                            }
                            SpinBox {
                                id: housePriceField
                                from: 0
                                to: 99999
                                stepSize: 100
                            }
                        }
                        
                        RowLayout {
                            Text { 
                                text: "Prix hôtel :" 
                                color: "#333"
                            }
                            SpinBox {
                                id: hotelPriceField
                                from: 0
                                to: 99999
                                stepSize: 100
                            }
                        }
                    }
                }

                // Taxe
                GroupBox {
                    id: taxGroup
                    title: "Taxe"
                    Layout.fillWidth: true
                    
                    background: Rectangle {
                        color: "white"
                        border.color: "#4f5af8"
                        border.width: 1
                        radius: 6
                    }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        
                        Text { 
                            text: "Montant de la taxe :" 
                            color: "#333"
                        }
                        SpinBox {
                            id: taxField
                            from: 0
                            to: 99999
                            stepSize: 100
                        }
                    }
                }

                // Espacement en bas pour éviter que le contenu soit caché par le bandeau
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                }
            }
        }

        // Colonne de droite - Liste des cases en attente
        ColumnLayout {
            Layout.preferredWidth: parent.width * 0.4
            Layout.fillHeight: true
            spacing: 10

            // En-tête de la liste
            Rectangle {
                Layout.fillWidth: true
                height: 60
                color: "#4f5af8"
                radius: 8
                
                Text {
                    anchors.centerIn: parent
                    text: "Cases en attente (" + pendingCasesModel.count + ")"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }
            }

            // Liste des cases
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                border.color: "#4f5af8"
                border.width: 2
                radius: 8
                
                ListView {
                    id: pendingCasesList
                    anchors.fill: parent
                    anchors.margins: 10
                    model: pendingCasesModel
                    spacing: 5
                    
                    delegate: Rectangle {
                        width: pendingCasesList.width
                        height: 80
                        color: "#f5f5f5"
                        border.color: "#ddd"
                        border.width: 1
                        radius: 4
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                
                                Text {
                                    text: model.name
                                    font.bold: true
                                    color: "#333"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: "Type: " + getTypeText(model.type) + " | Position: " + model.position + " | Index: " + model.index
                                    color: "#666"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: model.price > 0 ? "Prix: " + model.price : "Pas de prix"
                                    color: "#666"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }
                            
                            Button {
                                text: "✗"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                background: Rectangle {
                                    color: parent.pressed ? "#d32f2f" : "#f44336"
                                    radius: 15
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.bold: true
                                }
                                onClicked: {
                                    console.log("Clic suppression - Index:", index, "Nom:", model.name)
                                    removeCaseById(model.uniqueId)
                                }
                            }
                        }
                    }
                }
                
                Text {
                    anchors.centerIn: parent
                    text: "Aucune case en attente\nUtilisez 'Ajouter à la liste' pour commencer"
                    color: "#999"
                    horizontalAlignment: Text.AlignHCenter
                    visible: pendingCasesModel.count === 0
                }
            }

            // Boutons de gestion de la liste
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Enregistrer toutes (" + pendingCasesModel.count + ")"
                    Layout.fillWidth: true
                    enabled: pendingCasesModel.count > 0
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#0aae59" : "#4caf50") : "#cccccc"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.bold: true
                    }
                    onClicked: saveAllCases()
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    text: "Vider la liste"
                    Layout.fillWidth: true
                    enabled: pendingCasesModel.count > 0
                    background: Rectangle {
                        color: parent.enabled ? (parent.pressed ? "#e65100" : "#ff9800") : "#cccccc"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: pendingCasesModel.clear()
                }
                
                Button {
                    text: "Fermer"
                    Layout.fillWidth: true
                    background: Rectangle {
                        color: parent.pressed ? "#d32f2f" : "#f44336"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: caseCreatorWindow.close()
                }
            }
        }
    }

    // Bandeau fixe en bas avec les boutons principaux
    Rectangle {
        id: bottomBanner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 70
        color: "#4f5af8"
        border.color: "#3f51b5"
        border.width: 1
        
        RowLayout {
            anchors.centerIn: parent
            spacing: 30
            
            Button {
                text: "➕ Ajouter à la liste"
                Layout.preferredWidth: 200
                Layout.preferredHeight: 45
                background: Rectangle {
                    color: parent.pressed ? "#1976d2" : "#2196f3"
                    radius: 8
                    border.color: "#1565c0"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 14
                }
                onClicked: addCaseToList()
            }
            
            Button {
                text: "🔄 Réinitialiser"
                Layout.preferredWidth: 150
                Layout.preferredHeight: 45
                background: Rectangle {
                    color: parent.pressed ? "#e65100" : "#ff9800"
                    radius: 8
                    border.color: "#f57c00"
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.bold: true
                    font.pixelSize: 14
                }
                onClicked: resetFields()
            }
        }
    }

    function removeCaseById(caseId) {
        console.log("Tentative de suppression de la case ID:", caseId)
        for (var i = 0; i < pendingCasesModel.count; i++) {
            var item = pendingCasesModel.get(i)
            if (item.uniqueId === caseId) {
                console.log("Case trouvée à l'index", i, "Nom:", item.name, "Suppression...")
                pendingCasesModel.remove(i)
                console.log("Suppression réussie. Nouveau count:", pendingCasesModel.count)
                return
            }
        }
        console.log("ERREUR: Case non trouvée avec ID:", caseId)
    }

    function getTypeText(typeValue) {
        for (var i = 0; i < caseTypes.length; i++) {
            if (caseTypes[i].value === typeValue) {
                return caseTypes[i].text
            }
        }
        return "Inconnu"
    }

    function updateFieldsVisibility() {
        var currentType = typeCombo.currentValue

        // Par défaut, masquer tout
        economicGroup.visible = false
        rentGroup.visible = false
        constructionGroup.visible = false
        taxGroup.visible = false
        familyRow.visible = false
        travelPriceRow.visible = false

        switch(currentType) {
            case 1: // Propriété
                economicGroup.visible = true
                rentGroup.visible = true
                constructionGroup.visible = true
                familyRow.visible = true
                break
            case 6: // Gare
                economicGroup.visible = true
                travelPriceRow.visible = true
                // Pas de famille pour les gares
                break
            case 8: // Compagnie
                economicGroup.visible = true
                familyRow.visible = true
                break
            case 9: // Taxe
                taxGroup.visible = true
                break
        }
    }

    function getNextPosition() {
        // Retourne la prochaine position disponible
        // Pour l'instant, on commence à 40 (après le plateau standard)
        return 40
    }

    function resetFields() {
        typeCombo.currentIndex = 0
        nameField.text = ""
        positionField.value = getNextPosition()
        priceField.value = 0
        mortgagePriceField.value = 0
        familyCombo.currentIndex = 0
        travelPriceField.value = 25
        rent0Field.value = 0
        rent1Field.value = 0
        rent2Field.value = 0
        rent3Field.value = 0
        rent4Field.value = 0
        housePriceField.value = 0
        hotelPriceField.value = 0
        taxField.value = 0
        indexCombo.currentIndex = 0
        updateFieldsVisibility()
    }

    function addCaseToList() {
        if (nameField.text.trim() === "") {
            showMessage("Erreur", "Le nom de la case est obligatoire!")
            return
        }
        
        // Créer un ID unique basé sur le timestamp et un compteur
        var uniqueId = Date.now() + "_" + Math.random().toString(36).substr(2, 9)
        
        var caseData = {
            "uniqueId": uniqueId,
            "type": typeCombo.currentValue,
            "name": nameField.text.trim(),
            "position": positionField.value,
            "index": indexCombo.currentIndex,
            "price": economicGroup.visible && priceField.value > 0 ? priceField.value : 0,
            "mortgagePrice": economicGroup.visible && mortgagePriceField.value > 0 ? mortgagePriceField.value : null,
            "familly": (familyRow.visible && familyCombo.currentValue !== null) ? familyCombo.currentValue : null,
            "travelPrice": travelPriceRow.visible ? travelPriceField.value : null,
            "rent_0": rentGroup.visible && rent0Field.value > 0 ? rent0Field.value : null,
            "rent_1": rentGroup.visible && rent1Field.value > 0 ? rent1Field.value : null,
            "rent_2": rentGroup.visible && rent2Field.value > 0 ? rent2Field.value : null,
            "rent_3": rentGroup.visible && rent3Field.value > 0 ? rent3Field.value : null,
            "rent_4": rentGroup.visible && rent4Field.value > 0 ? rent4Field.value : null,
            "housePrice": constructionGroup.visible && housePriceField.value > 0 ? housePriceField.value : null,
            "hotelPrice": constructionGroup.visible && hotelPriceField.value > 0 ? hotelPriceField.value : null,
            "taxe": taxGroup.visible && taxField.value > 0 ? taxField.value : null
        }
        
        console.log("Avant ajout, nombre de cases:", pendingCasesModel.count)
        pendingCasesModel.append(caseData)
        console.log("Case ajoutée à la liste:", caseData.name, "ID:", uniqueId, "- Total cases:", pendingCasesModel.count)
        
        // Auto-incrémenter la position et l'index pour la prochaine case
        positionField.value = positionField.value + 1
        indexCombo.currentIndex = indexCombo.currentIndex + 1
        
        // Optionnel: vider le nom pour forcer une nouvelle saisie
        nameField.text = ""
        nameField.focus = true
    }

    function saveAllCases() {
        if (pendingCasesModel.count === 0) {
            showMessage("Erreur", "Aucune case à enregistrer!")
            return
        }
        
        var allCases = []
        for (var i = 0; i < pendingCasesModel.count; i++) {
            var caseData = pendingCasesModel.get(i)
            // Exclure l'uniqueId de la sauvegarde
            allCases.push({
                "type": caseData.type,
                "name": caseData.name,
                "position": caseData.position,
                "index": caseData.index,
                "price": caseData.price > 0 ? caseData.price : null,
                "mortgagePrice": caseData.mortgagePrice,
                "familly": caseData.familly,
                "travelPrice": caseData.travelPrice,
                "rent_0": caseData.rent_0,
                "rent_1": caseData.rent_1,
                "rent_2": caseData.rent_2,
                "rent_3": caseData.rent_3,
                "rent_4": caseData.rent_4,
                "housePrice": caseData.housePrice,
                "hotelPrice": caseData.hotelPrice,
                "taxe": caseData.taxe
            })
        }
        
        console.log("Sauvegarde de", allCases.length, "cases")
        
        if (Game.saveMultipleCasesToJson(allCases)) {
            showMessage("Succès", "Toutes les cases (" + allCases.length + ") ont été sauvegardées avec succès!")
            pendingCasesModel.clear()
        } else {
            showMessage("Erreur", "Impossible de sauvegarder les cases.")
        }
    }

    function showMessage(title, message) {
        messageDialog.title = title
        messageDialog.text = message
        messageDialog.open()
    }

    MessageDialog {
        id: messageDialog
        buttons: MessageDialog.Ok
    }

    Component.onCompleted: {
        updateFieldsVisibility()
    }
}
