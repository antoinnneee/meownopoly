import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import PlayerProfile

/*
 * Panneau "Aperçu" du PCP_ProfileDetail (popup d'édition de classe).
 *
 * Encapsule un PCP_Profile3DPreview agrandi, un titre, le nom du modèle,
 * et un drag souris pour pilotage manuel de la rotation. Pendant un drag,
 * la rotation auto est suspendue ; au relâchement, elle reprend depuis
 * l'angle courant pour éviter le saut visuel.
 *
 * Le composant est volontairement séparé pour rester réutilisable hors
 * du popup (ex: vignette agrandie au survol d'une card, side-panel d'un
 * mode de jeu, etc.).
 */
Item {
    id: root

    /// Profil actuellement édité. On lit `modelName` et `name`. null = vide.
    property var profile: null

    /// Couleur de fond du cadre.
    property color backgroundColor: "#1f1f1f"
    property color borderColor: "#3a3a3a"

    /// Hauteur monde-3D du modèle (transmise à PCP_Profile3DPreview pour
    /// calibrer la magnification ortho). Valeur par défaut OK pour la
    /// plupart des modèles cat-themed du projet.
    property real modelHeight: 160

    /// Inclinaison de la caméra du preview (légère plongée par défaut).
    property real cameraPitchDeg: 18

    /// Vitesse de rotation automatique (deg/s). 0 = arrêt.
    property real autoSpinDegPerSec: 30

    /// Affiche le titre "Aperçu" en haut. Off quand un titre externe
    /// (nom de la classe par ex.) est déjà au-dessus du Pane.
    property bool showTitle: false

    /// Affiche le nom du modèle 3D en footer. Off quand un sélecteur de
    /// modèle (PCP_ModelPicker) est juste en dessous → redondant.
    property bool showModelLabel: false

    // ---- État de pilotage manuel ---------------------------------------
    // _manualSpinning vrai pendant un drag → désactive l'auto-spin du
    // preview et impose l'angle via offset additif. Quand on relâche, on
    // copie l'angle courant dans le seed pour démarrer la prochaine
    // animation auto à partir de la dernière position vue.
    property bool _dragging: false

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: 6
        border.color: root.borderColor
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Screen.pixelDensity * 1.5
            spacing: Screen.pixelDensity * 1

            // ---- Titre (optionnel) ----
            Label {
                Layout.fillWidth: true
                visible: root.showTitle
                text: "Aperçu"
                color: "#cccccc"
                font.pixelSize: Math.round(Screen.pixelDensity * 3)
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            // ---- Preview 3D (rempli, drag pour rotation manuelle) ----
            Item {
                id: previewWrap
                Layout.fillWidth: true
                Layout.fillHeight: true

                PCP_Profile3DPreview {
                    id: preview
                    anchors.fill: parent
                    modelName: root.profile ? root.profile.modelName : "Cube"
                    modelHeight: root.modelHeight
                    cameraPitchDeg: root.cameraPitchDeg
                    spinDegPerSec: root.autoSpinDegPerSec
                    // Pause de l'auto-spin pendant un drag manuel.
                    spinning: !root._dragging && root.autoSpinDegPerSec > 0
                }

                // Drag horizontal = pilote l'angle Y du modèle. On modifie
                // directement la property interne `_spinAngle` du preview.
                // Volontairement intrusif : c'est l'API la plus simple pour
                // un pilotage immédiat sans recâbler l'animation.
                MouseArea {
                    id: spinDrag
                    anchors.fill: parent
                    cursorShape: Qt.OpenHandCursor
                    property real _startX: 0
                    property real _startAngle: 0

                    onPressed: function(mouse) {
                        root._dragging = true
                        _startX = mouse.x
                        _startAngle = preview._spinAngle
                        cursorShape = Qt.ClosedHandCursor
                    }
                    onReleased: {
                        root._dragging = false
                        cursorShape = Qt.OpenHandCursor
                    }
                    onPositionChanged: function(mouse) {
                        if (!pressed) return
                        // 1 px = 0.5 deg → tour complet en ~720 px de drag,
                        // confortable sur une zone de preview ~6-10 cm.
                        const dx = mouse.x - _startX
                        preview._spinAngle = _startAngle + dx * 0.5
                    }
                }
            }

            // ---- Footer : nom du modèle (optionnel) ----
            Label {
                Layout.fillWidth: true
                visible: root.showModelLabel
                text: root.profile ? root.profile.modelName : ""
                color: "#9a9a9a"
                font.pixelSize: Math.round(Screen.pixelDensity * 2.6)
                font.italic: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
            }
        }
    }
}
