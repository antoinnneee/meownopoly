import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

Rectangle {
    id: root
    
    // Propriétés
    property var targetCase: null
    property bool isVisible: false
    
    // Propriétés internes pour éviter les binding loops
    property bool updatingValues: false
    
    // Signaux
    signal configurationClosed()
    signal configurationApplied(var caseData)
    
    visible: isVisible
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 2
    radius: 8
    
    width: 600
    height: 700

    z: 1000  // Au-dessus de tout
    
    ScrollView {
        anchors.fill: parent
        anchors.margins: 15
        contentWidth: availableWidth
        clip: true
        
        ColumnLayout {
            width: parent.width
            spacing: 15
            
            // En-tête
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: "#007bff"
                radius: 4
                
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    
                    Text {
                        text: "Configuration de Case"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 16
                        Layout.fillWidth: true
                    }
                    
                    Button {
                        text: "×"
                        background: Rectangle {
                            color: "transparent"
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.bold: true
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            root.isVisible = false
                            configurationClosed()
                        }
                    }
                }
            }
            
            // Type de case (lecture seule pour l'instant)
            GroupBox {
                title: "Type de Case"
                Layout.fillWidth: true
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5
                    
                    Text {
                        text: targetCase ? getCaseTypeName(targetCase.type) : "Aucune case sélectionnée"
                        font.pixelSize: 14
                        color: "#495057"
                    }
                }
            }
            
            // Configuration générale
            GroupBox {
                title: "Configuration Générale"
                Layout.fillWidth: true
                
                GridLayout {
                    anchors.fill: parent
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10
                    
                    Label {
                        text: "Nom:"
                        font.bold: true
                    }
                    
                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        placeholderText: "Nom de la case"
                        
                        Component.onCompleted: {
                            if (targetCase) {
                                text = targetCase.name
                            }
                        }
                        
                        onEditingFinished: {
                            if (!updatingValues && targetCase) {
                                targetCase.name = text
                            }
                        }
                        
                        // Mise à jour quand targetCase change
                        Connections {
                            target: targetCase
                            function onNameChanged() {
                                if (!updatingValues) {
                                    updatingValues = true
                                    nameField.text = targetCase.name
                                    updatingValues = false
                                }
                            }
                        }
                    }
                    
                    Label {
                        text: "Position:"
                        font.bold: true
                    }
                    
                    SpinBox {
                        id: positionSpinBox
                        Layout.fillWidth: true
                        from: 0
                        to: 39
                        
                        Component.onCompleted: {
                            if (targetCase) {
                                value = targetCase.position
                            }
                        }
                        
                        onValueChanged: {
                            if (!updatingValues && targetCase) {
                                targetCase.position = value
                            }
                        }
                        
                        // Mise à jour quand targetCase change
                        Connections {
                            target: targetCase
                            function onPositionChanged() {
                                if (!updatingValues) {
                                    updatingValues = true
                                    positionSpinBox.value = targetCase.position
                                    updatingValues = false
                                }
                            }
                        }
                    }
                }
            }
            
            // Configuration spécifique RestArea
            GroupBox {
                title: "Configuration Rest Area"
                Layout.fillWidth: true
                visible: targetCase && targetCase.type === Case.CS_RestArea
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    
                    // Note explicative
                    Text {
                        text: "🏠 Configuration spécifique aux zones de repos (terrains)"
                        font.italic: true
                        font.pixelSize: 12
                        color: "#6c757d"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        Layout.bottomMargin: 5
                    }
                    
                    // Famille/Couleur
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Label {
                            text: "Famille:"
                            font.bold: true
                            Layout.preferredWidth: 80
                        }
                        
                        ComboBox {
                            id: familyComboBox
                            Layout.fillWidth: true
                            
                            model: [
                                { value: CaseRestArea.FT_NONE, textValue: "Aucune", color: "#ecf0f1" },
                                { value: CaseRestArea.FT_BROWN, textValue: "Marron", color: "#795548" },
                                { value: CaseRestArea.FT_LIGHTBLUE, textValue: "Bleu Clair", color: "#81D4FA" },
                                { value: CaseRestArea.FT_PINK, textValue: "Rose", color: "#F48FB1" },
                                { value: CaseRestArea.FT_ORANGE, textValue: "Orange", color: "#FF9800" },
                                { value: CaseRestArea.FT_RED, textValue: "Rouge", color: "#e74c3c" },
                                { value: CaseRestArea.FT_YELLOW, textValue: "Jaune", color: "#F9E155" },
                                { value: CaseRestArea.FT_GREEN, textValue: "Vert", color: "#66BB6A" },
                                { value: CaseRestArea.FT_DARKBLUE, textValue: "Bleu Foncé", color: "#006064" }
                            ]
                            
                            textRole: "textValue"
                            valueRole: "value"
                            
                            Component.onCompleted: {
                                if (targetCase) {
                                    currentIndex = findFamilyIndex(targetCase.family)
                                }
                            }
                            
                            onCurrentValueChanged: {
                                if (!updatingValues && targetCase && currentValue !== undefined) {
                                    targetCase.family = currentValue
                                }
                            }
                            
                            // Mise à jour quand targetCase change
                            Connections {
                                target: targetCase
                                function onFamilyChanged() {
                                    if (!updatingValues) {
                                        updatingValues = true
                                        familyComboBox.currentIndex = findFamilyIndex(targetCase.family)
                                        updatingValues = false
                                    }
                                }
                            }
                            
                            // Delegate personnalisé avec couleurs
                            delegate: ItemDelegate {
                                id: delegate
                                width: familyComboBox.width
                                height: 40
                                required property color color
                                required property int index
                                required property string textValue
                                
                                contentItem: Row {
                                    spacing: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        color: delegate.color
                                        border.color: "#333333"
                                        border.width: 1
                                        radius: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    Text {
                                        text: delegate.textValue
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: 14
                                        color: "#333333"
                                    }
                                }
                                
                                highlighted: familyComboBox.highlightedIndex === index
                                
                                background: Rectangle {
                                    color: highlighted ? "#e3f2fd" : "transparent"
                                    radius: 2
                                }
                            }
                            
                            // Contenu affiché dans la ComboBox fermée
                            contentItem: Row {
                                spacing: 10
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                
                                Rectangle {
                                    width: 20
                                    height: 20
                                    color: familyComboBox.currentIndex >= 0 ? familyComboBox.model[familyComboBox.currentIndex].color : "#ecf0f1"
                                    border.color: "#333333"
                                    border.width: 1
                                    radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                
                                Text {
                                    text: familyComboBox.displayText
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                    color: "#333333"
                                }
                            }
                        }
                    }

                    // Configuration des prix CaseCatPerks
                    GroupBox {
                        title: "Prix et Finances"
                        Layout.fillWidth: true
                        visible: targetCase && (targetCase.type === Case.CS_RestArea || 
                                               targetCase.type === Case.CS_CatDoor || 
                                               targetCase.type === Case.CS_Device)
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10
                            
                            // Note explicative
                            Text {
                                text: "💡 Configuration des prix pour les propriétés achetables"
                                font.italic: true
                                font.pixelSize: 12
                                color: "#6c757d"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                Layout.bottomMargin: 5
                            }
                            
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 10
                                columnSpacing: 10
                            
                            // Prix d'achat
                            Label {
                                text: "💰 Prix d'achat:"
                                font.bold: true
                                Layout.preferredWidth: 120
                            }
                            
                            SpinBox {
                                id: priceSpinBox
                                Layout.fillWidth: true
                                from: 0
                                to: 9999
                                stepSize: 10
                                
                                textFromValue: function(value, locale) {
                                    return value + "K"
                                }
                                
                                valueFromText: function(text, locale) {
                                    return parseInt(text.replace("K", ""))
                                }
                                
                                Component.onCompleted: {
                                    if (targetCase) {
                                        value = targetCase.price
                                    }
                                }
                                
                                onValueChanged: {
                                    if (!updatingValues && targetCase) {
                                        targetCase.price = value
                                    }
                                }
                                
                                // Mise à jour quand targetCase change
                                Connections {
                                    target: targetCase
                                    function onPriceChanged() {
                                        if (!updatingValues) {
                                            updatingValues = true
                                            priceSpinBox.value = targetCase.price
                                            updatingValues = false
                                        }
                                    }
                                }
                            }
                            
                            // Prix de vente
                            Label {
                                text: "💸 Prix de vente:"
                                font.bold: true
                                Layout.preferredWidth: 120
                            }
                            
                            SpinBox {
                                id: sellPriceSpinBox
                                Layout.fillWidth: true
                                from: 0
                                to: 9999
                                stepSize: 10
                                
                                textFromValue: function(value, locale) {
                                    return value + "K"
                                }
                                
                                valueFromText: function(text, locale) {
                                    return parseInt(text.replace("K", ""))
                                }
                                
                                Component.onCompleted: {
                                    if (targetCase) {
                                        value = targetCase.sellPrice
                                    }
                                }
                                
                                onValueChanged: {
                                    if (!updatingValues && targetCase) {
                                        targetCase.sellPrice = value
                                    }
                                }
                                
                                // Mise à jour quand targetCase change
                                Connections {
                                    target: targetCase
                                    function onSellPriceChanged() {
                                        if (!updatingValues) {
                                            updatingValues = true
                                            sellPriceSpinBox.value = targetCase.sellPrice
                                            updatingValues = false
                                        }
                                    }
                                }
                            }
                            
                            // Prix d'hypothèque
                            Label {
                                text: "🏦 Prix hypothèque:"
                                font.bold: true
                                Layout.preferredWidth: 120
                            }
                            
                            SpinBox {
                                id: morgagePriceSpinBox
                                Layout.fillWidth: true
                                from: 0
                                to: 9999
                                stepSize: 5
                                
                                textFromValue: function(value, locale) {
                                    return value + "K"
                                }
                                
                                valueFromText: function(text, locale) {
                                    return parseInt(text.replace("K", ""))
                                }
                                
                                Component.onCompleted: {
                                    if (targetCase) {
                                        value = targetCase.morgagePrice
                                    }
                                }
                                
                                onValueChanged: {
                                    if (!updatingValues && targetCase) {
                                        targetCase.morgagePrice = value
                                    }
                                }
                                
                                // Mise à jour quand targetCase change
                                Connections {
                                    target: targetCase
                                    function onMorgagePriceChanged() {
                                        if (!updatingValues) {
                                            updatingValues = true
                                            morgagePriceSpinBox.value = targetCase.morgagePrice
                                            updatingValues = false
                                        }
                                    }
                                }
                            }
                            } // Fin GridLayout

                            
                        } // Fin ColumnLayout
                    } // Fin GroupBox Prix et Finances
                    
                    // Qualité du repos (RestArea uniquement)
                    GroupBox {
                        title: "Qualité du repos"
                        Layout.fillWidth: true
                        visible: targetCase && targetCase.type === Case.CS_RestArea
                        
                        RowLayout {
                            anchors.fill: parent
                            
                            Label {
                                text: "⭐ Niveau:"
                                font.bold: true
                                Layout.preferredWidth: 80
                            }
                            
                            ComboBox {
                                id: qualityComboBox
                                Layout.fillWidth: true
                                
                                model: [
                                    { value: CaseRestArea.RQ_NONE, textValue: "Aucune (0 étoile)" },
                                    { value: CaseRestArea.RQ_ONE, textValue: "Basique (1 étoile)" },
                                    { value: CaseRestArea.RQ_TWO, textValue: "Confortable (2 étoiles)" },
                                    { value: CaseRestArea.RQ_THREE, textValue: "Luxueux (3 étoiles)" },
                                    { value: CaseRestArea.RQ_FOUR, textValue: "Premium (4 étoiles)" }
                                ]
                                
                                textRole: "textValue"
                                valueRole: "value"
                                
                                Component.onCompleted: {
                                    if (targetCase) {
                                        currentIndex = targetCase.restQuality
                                    }
                                }
                                
                                onCurrentValueChanged: {
                                    if (!updatingValues && targetCase && currentValue !== undefined) {
                                        targetCase.restQuality = currentValue
                                    }
                                }
                                
                                // Mise à jour quand targetCase change
                                Connections {
                                    target: targetCase
                                    function onRestQualityChanged() {
                                        if (!updatingValues) {
                                            updatingValues = true
                                            qualityComboBox.currentIndex = targetCase.restQuality
                                            updatingValues = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Prix de location
                    GroupBox {
                        title: "Prix de Location"
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8
                            
                            // Note explicative
                            Text {
                                text: "💡 Définissez les prix de location selon le niveau d'amélioration de la propriété"
                                font.italic: true
                                font.pixelSize: 12
                                color: "#6c757d"
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                Layout.bottomMargin: 5
                            }
                            
                            // Prix terrain nu à 4 étoiles
                            Repeater {
                                model: [
                                    { index: 0, label: "🏞️ Terrain nu:", step: 5, color: "#495057", bold: true },
                                    { index: 1, label: "⭐ 1 étoile:", step: 5, color: "#495057", bold: true },
                                    { index: 2, label: "⭐⭐ 2 étoiles:", step: 5, color: "#495057", bold: true },
                                    { index: 3, label: "⭐⭐⭐ 3 étoiles:", step: 5, color: "#495057", bold: true },
                                    { index: 4, label: "⭐⭐⭐⭐ 4 étoiles:", step: 5, color: "#495057", bold: true }
                                ]
                                
                                RowLayout {
                                    Layout.fillWidth: true
                                    
                                    Label {
                                        text: modelData.label
                                        font.bold: modelData.bold
                                        Layout.preferredWidth: 120
                                        color: modelData.color
                                    }
                                    
                                    SpinBox {
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 10000
                                        stepSize: modelData.step
                                        
                                        property int rentIndex: modelData.index
                                        
                                        textFromValue: function(value, locale) {
                                            return value + "K"
                                        }
                                        
                                        valueFromText: function(text, locale) {
                                            return parseInt(text.replace("K", ""))
                                        }
                                        
                                        Component.onCompleted: {
                                            if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                                value = targetCase.rentPrice[rentIndex]
                                            }
                                        }
                                        
                                        onValueChanged: {
                                            if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > rentIndex) {
                                                targetCase.rentPrice[rentIndex] = value
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Séparateur visuel
                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: "#dee2e6"
                                Layout.topMargin: 5
                                Layout.bottomMargin: 5
                            }
                            
                            // Hôtel
                            RowLayout {
                                Layout.fillWidth: true
                                
                                Label {
                                    text: "🏨 Hôtel:"
                                    font.bold: true
                                    Layout.preferredWidth: 120
                                    color: "#dc3545"
                                    font.pixelSize: 16
                                }
                                
                                SpinBox {
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 10000
                                    stepSize: 10
                                    
                                    textFromValue: function(value, locale) {
                                        return value + "K"
                                    }
                                    
                                    valueFromText: function(text, locale) {
                                        return parseInt(text.replace("K", ""))
                                    }
                                    
                                    Component.onCompleted: {
                                        if (targetCase && targetCase.rentPrice && targetCase.rentPrice.length > 5) {
                                            value = targetCase.rentPrice[5]
                                        }
                                    }
                                    
                                    onValueChanged: {
                                        if (!updatingValues && targetCase && targetCase.rentPrice && targetCase.rentPrice.length > 5) {
                                            targetCase.rentPrice[5] = value
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Boutons d'action
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                
                Item { Layout.fillWidth: true } // Spacer
                
                Button {
                    text: "Annuler"
                    background: Rectangle {
                        color: "#6c757d"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.isVisible = false
                        configurationClosed()
                    }
                }
                
                Button {
                    text: "Appliquer"
                    background: Rectangle {
                        color: "#28a745"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        configurationApplied(targetCase)
                        root.isVisible = false
                        configurationClosed()
                    }
                }
            }
        }
    }
    
    // Fonctions utilitaires
    function getCaseTypeName(type) {
        const typeNames = {
            [Case.CS_KibbleDispenser]: "Kibble Dispenser (Départ)",
            [Case.CS_RestArea]: "Rest Area (Terrain)",
            [Case.CS_CardBoardBox]: "Cardboard Box (Caisse communauté)",
            [Case.CS_CatNip]: "Cat Nip (Chance)",
            [Case.CS_Jail]: "Jail (Prison)",
            [Case.CS_ToJail]: "To Jail (Aller en prison)",
            [Case.CS_CatDoor]: "Cat Door (Gare)",
            [Case.CS_FreeNap]: "Free Nap (Parking gratuit)",
            [Case.CS_Device]: "Device (Service électricité)",
            [Case.CS_Taxe]: "Taxe (Taxe de luxe)",
            [Case.CS_Unknow]: "Unknown (Inconnu)"
        }
        return typeNames[type] || "Type inconnu"
    }
    
    function findFamilyIndex(familyValue) {
        const families = [
            CaseRestArea.FT_NONE, CaseRestArea.FT_BROWN, CaseRestArea.FT_LIGHTBLUE,
            CaseRestArea.FT_PINK, CaseRestArea.FT_ORANGE, CaseRestArea.FT_RED,
            CaseRestArea.FT_YELLOW, CaseRestArea.FT_GREEN, CaseRestArea.FT_DARKBLUE
        ]
        return families.indexOf(familyValue)
    }
    
    // Fonction pour ouvrir le panneau avec une case
    function openConfiguration(caseData) {
        targetCase = caseData
        isVisible = true
        updateControls()
    }
    
    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        
        updatingValues = true
        
        // Mise à jour des contrôles généraux
        nameField.text = targetCase.name
        positionSpinBox.value = targetCase.position
        
        // Mise à jour des contrôles CaseCatPerks (prix)
        priceSpinBox.value = targetCase.price || 0
        sellPriceSpinBox.value = targetCase.sellPrice || 0
        morgagePriceSpinBox.value = targetCase.morgagePrice || 0
        
        // Mise à jour des contrôles RestArea
        if (targetCase.type === Case.CS_RestArea) {
            familyComboBox.currentIndex = findFamilyIndex(targetCase.family)
            qualityComboBox.currentIndex = targetCase.restQuality || 0
        }
        
        updatingValues = false
    }
}
