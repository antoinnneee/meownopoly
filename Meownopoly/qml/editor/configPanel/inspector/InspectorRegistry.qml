import QtQuick
import ItemSnapable
import Case

// Registre unique type d'élément → onglets de l'inspecteur.
// Remplace le double dispatch historique (MouseLogic_Base.updateCaseConfiguration
// + BottomSidePanel.updateSidePanel) côté nouvelle UI : ajouter un type ou un
// onglet = une entrée ici + un fichier InspectorTab_*.qml.
// Les `source` sont résolues relativement à InspectorPanel.qml (même dossier).
QtObject {

    // Onglets pour un élément unique sélectionné.
    function tabsFor(element) {
        if (!element || !element.snapableParameters)
            return []
        const sp = element.snapableParameters
        const tabs = []
        switch (sp.tileType) {
        case ItemSnapable.CaseTile:
            // Nom + type de case vivent dans le header ; seuls les 4 types à
            // config économique ont un onglet dédié (les 6 autres n'ont
            // aucune donnée spécifique — CatNip, Jail, ToJail, CatDoor,
            // FreeNap, Taxe).
            if (sp.caseData && _hasEconomy(sp.caseData.type))
                tabs.push({ id: "economy", label: "Économie", source: "InspectorTab_CaseEconomy.qml" })
            break
        case ItemSnapable.PhysicZoneTile:
            tabs.push({ id: "zone", label: "Zone", source: "InspectorTab_Zone.qml" })
            break
        case ItemSnapable.NPCTile:
            tabs.push({ id: "npc", label: "PNJ", source: "InspectorTab_Npc.qml" })
            break
        case ItemSnapable.EnemyTile:
            tabs.push({ id: "enemy", label: "Ennemi", source: "InspectorTab_Enemy.qml" })
            break
        case ItemSnapable.PhysicalObjectTile:
            tabs.push({ id: "crate", label: "Caisse", source: "InspectorTab_Crate.qml" })
            break
        }
        tabs.push(_visualTab())
        return tabs
    }

    // Onglets pour une multi-sélection : intersection des propriétés
    // communes — les effets visuels s'appliquent à tout élément.
    function tabsForMulti(elements) {
        return [_visualTab()]
    }

    // Infos de header pour un élément unique : icône (mêmes emojis que le
    // rail NewEditorChrome), libellé du type, et présence du sélecteur de
    // type de case.
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

    function _hasEconomy(caseType) {
        return caseType === Case.CS_RestArea
            || caseType === Case.CS_KibbleDispenser
            || caseType === Case.CS_CardBoardBox
            || caseType === Case.CS_Device
    }

    function _visualTab() {
        return { id: "visual", label: "Visuel", source: "InspectorTab_Visual.qml" }
    }
}
