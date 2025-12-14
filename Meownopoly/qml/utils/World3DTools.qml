pragma Singleton
import QtQuick
import ItemSnapable

import QtQuick3D
import QtQuick3D.Helpers

Item {

    property  var  view3D: null
     property var gridManager: null

    function init(v3d, gm)
    {
        view3D = v3d
        gridManager = gm
    }


    function position3dToGridRealPosition(xPos, yPos, zPos)
    {
        if (!view3D || !gridManager) {
            console.error("position3dToGridRealPosition: view3D, ou gridManager non défini");
            return Qt.point(0, 0);
        }
        var viewPos = view3D.mapFrom3DScene(Qt.vector3d(xPos, yPos, zPos));
        var gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y);

        return Qt.point(gridPos.x / gridManager.gridSize, gridPos.y / gridManager.gridSize);
    }

    function updateInputVector(x, y, baseSpeed)
    {
        // Créer le vecteur de direction
        var direction = Qt.vector2d(x, y)
        
        // Normalisation pour éviter d'aller plus vite en diagonale
        if (direction.length() > 1) {
            direction = direction.normalized()
        }
        
        // Multiplier par baseSpeed pour intégrer la vitesse dans le vecteur
        return Qt.vector2d(direction.x * baseSpeed, direction.y * baseSpeed)
    }

    /**
     * Convertit un rayon 3D en rayon de grille
     * @param radius3D Rayon en unités 3D
     * @returns Rayon en unités de grille
     */
    function radius3DToGridRadius(radius3D)
    {
        if (!gridManager) {
            console.error("radius3DToGridRadius: gridManager non défini");
            return radius3D; // Retourner tel quel si pas de conversion possible
        }
        
        // Pour convertir un rayon 3D en rayon de grille, on utilise deux points
        // séparés par le rayon et on calcule leur distance en unités de grille
        // Approche simplifiée : on utilise la même conversion que pour les positions
        // Le rayon en unités de grille = rayon 3D / gridSize
        // Mais comme la conversion passe par une projection, on fait une approximation
        
        // On calcule la position de deux points séparés par le rayon
        var centerPos = position3dToGridRealPosition(0, 0, 0)
        var offsetPos = position3dToGridRealPosition(radius3D, 0, 0)
        
        // Distance entre les deux points en unités de grille
        var dx = offsetPos.x - centerPos.x
        var dy = offsetPos.y - centerPos.y
        var gridRadius = Math.sqrt(dx * dx + dy * dy)
        
        return gridRadius
    }

}
