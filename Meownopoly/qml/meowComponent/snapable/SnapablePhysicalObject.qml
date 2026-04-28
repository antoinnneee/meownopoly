import QtQuick 2.15
import QtQuick.Controls

import ItemSnapable
import TileType

/**
 * Phase 9 — caisse à pousser.
 *
 * Tile snapable représentant un objet physique dynamique (Body de type
 * `Dynamic` côté moteur Pattounx). Le cercle visible ici n'est que la
 * **représentation éditeur 2D** : la vraie collision se calcule côté
 * worker à partir de la position grille + rayon dérivé du `unitSizeWidth`
 * du `displayParameter`. Le node 3D associé (caisse posée dans le monde)
 * est porté par `qml/world3d/PhysicsObject.qml`.
 *
 * Le rayon physique = `unitSizeWidth / 2.0` (un cercle inscrit dans la
 * bounding box de la tile, côté `EditorPhysicsBridge`).
 */
SnapableElement {
    id: root

    // Pas de redimensionnement aux poignées : la taille est verrouillée
    // sur le `unitSizeWidth/Height` que le bridge utilisera comme rayon.
    // Pour redimensionner la caisse, la prochaine itération exposera un
    // slider dédié ; pour l'instant on évite les bugs de cohérence
    // édition/physique.
    isResizable: false
    autoSnap: true

    elementColor: "transparent"
    borderWidth: 0

    visible: gridManager.isEdit
    opacity: isSelected ? 1.0 : 0.85

    // Couleur dérivée de la masse : interpolation orange clair (mass=0.5)
    // → rouge foncé (mass=5+). Lecture défensive : si la tile n'a pas
    // de physicalObjectParameter (vieux JSON), on retombe sur orange.
    readonly property real _mass: snapableParameters.physicalObjectParameter
                                    ? snapableParameters.physicalObjectParameter.mass
                                    : 1.0
    readonly property real _massT: Math.max(0, Math.min(1, (_mass - 0.5) / 4.5))
    property color crateColor: Qt.rgba(
        // R : 0.98 → 0.78 (rouge foncé garde du rouge)
        0.98 - 0.20 * _massT,
        // G : 0.57 → 0.18 (passage de orange à brun-rouge)
        0.57 - 0.39 * _massT,
        // B : 0.24 → 0.18 (peu de bleu, garde la chaleur)
        0.24 - 0.06 * _massT,
        1.0)
    property color outlineColor: Qt.darker(crateColor, 1.5)

    // Cercle représentant la bounding shape physique. Centre = centre de
    // la tile, diamètre = min(width, height) pour rester inscrit même si
    // unitSizeWidth ≠ unitSizeHeight (cas non supporté par le moteur pour
    // l'instant — Phase 9 utilise la dimension W).
    Rectangle {
        id: circle
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        radius: width / 2
        color: Qt.rgba(root.crateColor.r, root.crateColor.g, root.crateColor.b, 0.25)
        border.color: root.outlineColor
        border.width: root.isSelected ? 3 : 2
        z: 1
    }

    // Croix centrale pour rappeler que c'est un objet physique posable.
    Item {
        anchors.centerIn: parent
        width: circle.width * 0.5
        height: circle.height * 0.5
        z: 2
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 2
            color: root.outlineColor
        }
        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: parent.height
            color: root.outlineColor
        }
    }

    // Étiquette debug en mode sélection : rayon + masse.
    Text {
        visible: root.isSelected
        text: "r=" + (root.snapableParameters.displayParameter.unitSizeWidth / 2.0).toFixed(2)
            + "  m=" + root._mass.toFixed(1)
        color: "white"
        font.pixelSize: 12
        font.bold: true
        x: 4; y: 4
        z: 3
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: Qt.rgba(0, 0, 0, 0.55)
            radius: 2
            z: -1
        }
    }
}
