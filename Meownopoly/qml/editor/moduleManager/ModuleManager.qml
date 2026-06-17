import QtQuick
import theme

// Gestionnaire de modules : barre horizontale listant les "modules", c.-à-d.
// les menus de l'éditeur (Case, Déco, Zone, Template, Joueur).
//
// Le bouton "+" (en tête de liste) ouvre un popup de sélection ; à la
// validation, les modules choisis s'ajoutent à la suite du "+". La ListView
// fait la même hauteur que le bouton "+" de référence, avec quelques marges.
Item {
    id: root

    // Émis pour chaque module effectivement ajouté à la liste.
    signal moduleAdded(string moduleId)

    // Module actuellement sélectionné (vignette active). "" = aucun → l'hôte
    // garde son/ses panneau(x) repliés. Un seul module actif à la fois.
    property string selectedModuleId: ""

    // Émis à chaque changement de sélection (clic vignette). moduleId == "" quand
    // on désélectionne (re-clic sur la vignette active) → l'hôte replie le panneau.
    signal moduleSelected(string moduleId)

    // Sélectionne un module, ou le désélectionne si déjà actif (toggle), puis
    // notifie l'hôte via moduleSelected.
    function toggleModule(id) {
        root.selectedModuleId = (root.selectedModuleId === id) ? "" : id
        root.moduleSelected(root.selectedModuleId)
    }

    // Hauteur de référence = celle du bouton "+". La ListView et les vignettes
    // de module s'alignent dessus.
    property int itemSize: Theme.px(32)
    // Marges autour de la ListView (haut/bas via le centrage vertical dans la
    // barre, gauche/droite explicites).
    property int sideMargin: Theme.spacingXS

    implicitHeight: itemSize + 2 * Theme.spacingXS

    // Catalogue des modules disponibles. Icônes emoji = placeholders.
    readonly property var availableModules: [
        { "id": "case",     "label": "Case",     "icon": "📦" },
        { "id": "deco",     "label": "Déco",     "icon": "🌳" },
        { "id": "zone",     "label": "Zone",       "icon": "🟥" },
        { "id": "template", "label": "Template",   "icon": "🧩" },
        { "id": "player",   "label": "Joueur",     "icon": "🐱" },
        { "id": "config",   "label": "Config",     "icon": "⚙️" },
        { "id": "chat",     "label": "Messagerie", "icon": "💬" },
        { "id": "config3d", "label": "Config 3D",  "icon": "🧊" }
    ]

    // Retourne le module du catalogue correspondant à `id` (ou null).
    function _moduleById(id) {
        for (let i = 0; i < root.availableModules.length; i++)
            if (root.availableModules[i].id === id)
                return root.availableModules[i]
        return null
    }

    // Vrai si un module est déjà présent dans la liste (anti-doublon).
    function _hasModule(id) {
        for (let i = 0; i < addedModulesModel.count; i++)
            if (addedModulesModel.get(i).moduleId === id)
                return true
        return false
    }

    ListView {
        id: moduleList
        height: root.itemSize
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.sideMargin
        anchors.rightMargin: root.sideMargin
        orientation: ListView.Horizontal
        // Sens droite→gauche : le header "+" se place à droite, collé au
        // BtSideMenu, et les modules ajoutés défilent à sa suite vers la gauche.
        layoutDirection: Qt.RightToLeft
        spacing: Theme.spacingXS
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Bouton "+" en tête : c'est la référence de hauteur de la barre.
        // En RightToLeft, la tête est rendue à l'extrémité droite (côté BtSideMenu).
        header: ModuleManager_AddButton {
            width: root.itemSize
            height: root.itemSize
            onClicked: addPopup.open()
        }

        // Modules ajoutés (peuplés à la validation du popup).
        model: ListModel { id: addedModulesModel }

        delegate: Rectangle {
            id: moduleCell
            required property string moduleId
            required property string icon

            // Vignette active = module actuellement affiché par l'hôte.
            readonly property bool active: root.selectedModuleId === moduleCell.moduleId

            width: root.itemSize
            height: root.itemSize
            radius: Theme.radiusS
            color: moduleCell.active ? Theme.surfaceHover : Theme.surfaceAlt
            border.color: moduleCell.active ? Theme.accent : Theme.border
            border.width: moduleCell.active ? 2 : 1

            Text {
                anchors.centerIn: parent
                text: moduleCell.icon
                font.pixelSize: Math.round(root.itemSize * 0.55)
            }

            // Clic = sélectionne ce module (ou le désélectionne si déjà actif).
            TapHandler {
                onTapped: root.toggleModule(moduleCell.moduleId)
            }

            Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
        }
    }

    // Popup de sélection des modules.
    ModuleManager_AddPopup {
        id: addPopup
        modules: root.availableModules

        onValidated: function (ids) {
            for (let i = 0; i < ids.length; i++) {
                if (root._hasModule(ids[i]))
                    continue
                const m = root._moduleById(ids[i])
                if (!m)
                    continue
                addedModulesModel.append({
                    "moduleId": m.id,
                    "icon": m.icon,
                    "label": m.label
                })
                root.moduleAdded(m.id)
            }
        }
    }
}
