import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EditorEnum
import theme
import "."

// Nouvelle interface (chrome) de l'éditeur : rail latéral gauche compact +
// cluster de statuts discret. Ne contient AUCUNE logique métier : elle pilote
// exactement les mêmes états que l'UI classique.
//
//   - Les modes de pose/édition passent par `moduleManager.toggleModule(id)`,
//     donc les panneaux de contenu existants (DecoPanel, CasePanel, ZonePanel,
//     NPCPanel, TemplatePanel, PlayerPanel, Config3DPanel, BottomSidePanel)
//     s'affichent/replient via leurs bindings `visible: selectedModuleId===...`.
//   - Infos map / Chat / Menu sont délégués via signaux à Editor.qml.
//
// Instanciée sous Loader { active: useNewUi } → non instanciée en UI classique
// (aucun backing GPU résiduel).
Item {
    id: root

    // Références injectées depuis Editor.qml.
    property var editorModuleManager: null
    property var editorLogic: null

    // Délégations vers Editor.qml (drawers/menus partagés).
    signal mapInfoRequested()
    signal chatRequested()
    signal menuRequested()
    // Toggle du mode « Chemin » (tracé des connexions entre cases).
    signal pathModeToggled()

    // Largeur du rail — Editor.qml décale les panneaux du bas de cette valeur
    // pour qu'ils ne passent pas sous le rail.
    readonly property real railWidth: Theme.px(58)

    readonly property string _activeModule: editorModuleManager ? editorModuleManager.selectedModuleId : ""

    // ── Bouton de rail réutilisable (composant inline) ───────────────────
    component RailButton: Item {
        id: btn
        property string icon: ""
        property string label: ""
        property bool active: false
        property int badgeCount: 0
        signal clicked()

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Theme.px(44)
        Layout.preferredHeight: Theme.px(44)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusM
            color: btn.active
                   ? Theme.surfaceHover
                   : (btnHover.hovered ? Theme.hover(Theme.surfaceAlt) : "transparent")
            border.color: btn.active ? Theme.accent : "transparent"
            border.width: btn.active ? 2 : 0
            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.pixelSize: Theme.px(20)
        }

        // Pastille de compteur (ex: nombre d'éléments sélectionnés).
        Rectangle {
            visible: btn.badgeCount > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.px(2)
            anchors.rightMargin: Theme.px(2)
            width: Theme.px(16)
            height: Theme.px(16)
            radius: width / 2
            color: Theme.accent
            Text {
                anchors.centerIn: parent
                text: btn.badgeCount > 9 ? "9+" : btn.badgeCount
                color: "white"
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
            }
        }

        HoverHandler { id: btnHover }
        TapHandler { onTapped: btn.clicked() }

        ToolTip.visible: btnHover.hovered && btn.label !== ""
        ToolTip.text: btn.label
        ToolTip.delay: 400
    }

    // ── Rail latéral gauche ──────────────────────────────────────────────
    Rectangle {
        id: rail
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.railWidth
        color: Theme.surface
        opacity: 0.97

        // Séparateur de bord droit.
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Theme.border
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Theme.spacingM
            anchors.bottomMargin: Theme.spacingM
            spacing: Theme.spacingXS

            // Logo / identité.
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "🐾"
                font.pixelSize: Theme.px(22)
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.railWidth - Theme.spacingL * 2
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // Grands modes de pose/édition (pilotent moduleManager).
            Repeater {
                model: [
                    { "id": "deco",     "icon": "🌳", "label": "Décors" },
                    { "id": "case",     "icon": "📦", "label": "Cases" },
                    { "id": "zone",     "icon": "🟥", "label": "Zones" },
                    { "id": "npc",      "icon": "🎭", "label": "PNJ" },
                    { "id": "enemy",    "icon": "👹", "label": "Ennemis" },
                    { "id": "crate",    "icon": "🗃️", "label": "Caisses" },
                    { "id": "template", "icon": "🧩", "label": "Templates" },
                    { "id": "player",   "icon": "🐱", "label": "Joueurs" },
                    { "id": "config3d", "icon": "🧊", "label": "Réglages 3D" }
                ]
                delegate: RailButton {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.label
                    active: root._activeModule === modelData.id
                    onClicked: if (root.editorModuleManager) root.editorModuleManager.toggleModule(modelData.id)
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.railWidth - Theme.spacingL * 2
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // La configuration de la sélection passe désormais par
            // l'inspecteur contextuel (dock droit, InspectorPanel) : plus de
            // module "config" à activer — la sélection est le déclencheur.
            // (Le module reste dans le catalogue ModuleManager pour l'UI
            // classique.)

            // Outil « Chemin » : chaînage des connexions A→B→C au clic
            // (mode EM_SELECTION_LINK en chainMode). Remplace les boutons
            // « Ajouter Précédent/Suivant » du panneau de config.
            RailButton {
                icon: "🔗"
                label: "Tracer un chemin"
                active: root.editorLogic
                        && root.editorLogic.editorMouseMode === EditorEnum.EM_SELECTION_LINK
                onClicked: root.pathModeToggled()
            }

            // Affichage persistant des flèches de connexion (indépendant du
            // mode chemin, qui les force déjà pendant le tracé).
            RailButton {
                icon: "👁"
                label: "Afficher les connexions"
                active: root.editorLogic && root.editorLogic.tileLogic
                        && root.editorLogic.tileLogic.displayLinkEnable === true
                onClicked: {
                    if (root.editorLogic && root.editorLogic.tileLogic)
                        root.editorLogic.tileLogic.displayLinkEnable
                                = !root.editorLogic.tileLogic.displayLinkEnable
                }
            }

            // Espace flexible : pousse les actions globales en bas du rail.
            Item { Layout.fillHeight: true; Layout.fillWidth: true }

            RailButton {
                icon: "ℹ️"
                label: "Infos de la carte"
                onClicked: root.mapInfoRequested()
            }
            RailButton {
                icon: "💬"
                label: "Messagerie"
                onClicked: root.chatRequested()
            }
            RailButton {
                icon: "☰"
                label: "Menu"
                onClicked: root.menuRequested()
            }
        }
    }

    // ── Cluster de statuts discret (collab + physique) ───────────────────
    // Réutilise les badges existants ; ils restent auto-masqués/agrandis au clic.
    Column {
        anchors.top: parent.top
        anchors.left: rail.right
        anchors.topMargin: Theme.spacingM
        anchors.leftMargin: Theme.spacingM
        spacing: Theme.spacingS

        CollabStatusPanel {}
        PhysicsStatusPanel {}
    }
}
