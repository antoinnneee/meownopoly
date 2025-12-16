import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AssetManager

import "../"
import "../editorBottomPanel"

EBP_TitleBar {
    id: titleBar
    
    // Propriété pour contrôler l'onglet actif
    property int currentTabIndex: 0
    
    searchBar.visible: false
    backButton.visible: false

    titleText: "Paramétrage de la carte"
    subTitleText: {
        switch(currentTabIndex) {
            case 0: return "Configuration générale de la carte"
            case 1: return "Charger une carte existante"
            case 2: return "Personnaliser l'arrière-plan"
            default: return ""
        }
    }
    subTitleColor: "#999999"
    buttonModel: ["Paramètres généraux", "Charger une carte", "Fond d'écran"]
    activeFilter: "Paramètres généraux" // Premier bouton sélectionné par défaut

    onButtonClicked: function(text, index) {
        console.log("MSP_TitleBar - Button clicked:", text, index)
        titleBar.activeFilter = text
        titleBar.currentTabIndex = index
    }

    // Spacer
    Item { Layout.fillWidth: true }

}
