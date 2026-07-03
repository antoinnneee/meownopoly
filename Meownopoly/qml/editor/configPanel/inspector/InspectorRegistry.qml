import QtQuick
import ItemSnapable

// Registre unique type d'élément → onglets de l'inspecteur.
// Remplace le double dispatch historique (MouseLogic_Base.updateCaseConfiguration
// + BottomSidePanel.updateSidePanel) côté nouvelle UI : ajouter un type ou un
// onglet = une entrée ici + un fichier InspectorTab_*.qml.
// Les `source` sont résolues relativement à InspectorPanel.qml (même dossier).
QtObject {

    // Onglets pour un élément unique sélectionné.
    // Phase 1 : seul l'onglet Visuel est branché ; les onglets par type
    // (Général/Économie/Zone/PNJ/Ennemi/Caisse/Liens) arrivent en Phase 2/3.
    function tabsFor(element) {
        if (!element || !element.snapableParameters)
            return []
        return [_visualTab()]
    }

    // Onglets pour une multi-sélection : intersection des propriétés
    // communes — les effets visuels s'appliquent à tout élément.
    function tabsForMulti(elements) {
        return [_visualTab()]
    }

    // Infos de header pour un élément unique : icône (mêmes emojis que le
    // rail NewEditorChrome), libellé du type, et présence du sélecteur de
    // type de case (Phase 2).
    function headerInfo(element) {
        if (!element || !element.snapableParameters)
            return { icon: "❓", typeLabel: "", showCaseTypeSelector: false }
        switch (element.snapableParameters.tileType) {
        case ItemSnapable.CaseTile:
            return { icon: "📦", typeLabel: "Case", showCaseTypeSelector: true }
        case ItemSnapable.DecorationTile:
            return { icon: "🌳", typeLabel: "Décoration", showCaseTypeSelector: false }
        case ItemSnapable.PhysicZoneTile:
            return { icon: "🟥", typeLabel: "Zone", showCaseTypeSelector: false }
        case ItemSnapable.NPCTile:
            return { icon: "🎭", typeLabel: "PNJ", showCaseTypeSelector: false }
        case ItemSnapable.EnemyTile:
            return { icon: "👹", typeLabel: "Ennemi", showCaseTypeSelector: false }
        case ItemSnapable.PhysicalObjectTile:
            return { icon: "🗃️", typeLabel: "Caisse", showCaseTypeSelector: false }
        }
        return { icon: "❓", typeLabel: "", showCaseTypeSelector: false }
    }

    function _visualTab() {
        return { id: "visual", label: "Visuel", source: "InspectorTab_Visual.qml" }
    }
}
