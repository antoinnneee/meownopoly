pragma Singleton
import QtQuick
import ItemSnapable

import QtQuick3D
import QtQuick3D.Helpers

Item {

    property  var  view3D: null
    property var cameraOrthographic: null
     property var gridManager: null

    function init(v3d, gm, co)
    {
        view3D = v3d
        gridManager = gm
        cameraOrthographic = co
    }


    function position3dToGridRealPosition(xPos, yPos, zPos)
    {
        if (!view3D || !gridManager) {
            console.error("position3dToGridRealPosition: view3D, ou gridManager non défini");
            return Qt.point(0, 0);
        }
        var viewPos = view3D.mapFrom3DScene(Qt.vector3d(xPos, yPos, zPos));
        // console.log("[position3dToGridRealPosition] viewPos", viewPos)
        var gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y);

        return Qt.point(gridPos.x / gridManager.gridSize, gridPos.y / gridManager.gridSize);
    }

    /**
     * Convertit des coordonnées de grille 2D en coordonnées 3D du monde
     * C'est l'INVERSE de position3dToGridRealPosition
     */
    function gridPositionTo3D(gridX, gridY)
    {
        if (!gridManager || !view3D) {
            console.error("gridPositionTo3D: gridManager ou view3D non défini");
            return Qt.vector3d(0, 0, 0);
        }
        
        // 1. Convertir les coordonnées de grille en pixels sur le gridManager
        var gridPixelX = gridX * gridManager.gridSize
        var gridPixelY = gridY * gridManager.gridSize
        
        // 2. Convertir les coordonnées du gridManager vers les coordonnées de la view3D
        var viewPos = gridManager.mapToItem(view3D, gridPixelX, gridPixelY)
        // console.log("[gridPositionTo3D] grid:", gridX.toFixed(2), gridY.toFixed(2),
        //             "-> gridPixel:", gridPixelX.toFixed(2), gridPixelY.toFixed(2),
        //             "-> viewPos:", viewPos.x.toFixed(2), viewPos.y.toFixed(2))
        
        // 3. Projeter sur le sol (Y=0) dans la scène 3D
        var pos3D = getGroundIntersection(viewPos.x, viewPos.y);

        return pos3D
    }

    /**
     * Projette un point de la vue 2D sur le plan Y=0 dans la scène 3D
     * @param viewX, viewY Coordonnées en pixels dans la View3D
     * @returns Position 3D sur le plan Y=0
     */
    function getGroundIntersection(viewX, viewY) {
        if (!view3D || !cameraOrthographic) {
            console.error("getGroundIntersection: view3D ou cameraOrthographic non défini");
            return Qt.vector3d(0, 0, 0);
        }
        
        // Obtenir le point dans l'espace 3D de la scène
        var scenePos = view3D.mapTo3DScene(Qt.point(viewX, viewY));

        // Angle de la caméra (eulerRotation.x = -55 degrés typiquement)
        var angleDeg = cameraOrthographic.eulerRotation.x;
        var rad = angleDeg * Math.PI / 180;

        // Direction du rayon de la caméra (vers où elle regarde)
        // Avec rotation X négative, la caméra regarde vers le bas
        var rayDirY = Math.sin(rad); // Composante Y (négatif = vers le bas)
        var rayDirZ = -Math.cos(rad); // Composante Z

        var targetX = scenePos.x;
        var targetZ = scenePos.z;

        // Calculer l'intersection avec le plan Y=0
        if (Math.abs(rayDirY) > 0.0001) {
            var t = -scenePos.y / rayDirY;
            targetX = scenePos.x; // X ne change pas (pas de rotation Y)
            targetZ = scenePos.z + t * rayDirZ;
        }
        

        return Qt.vector3d(targetX, 0, targetZ);
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
            return radius3D;
        }
        
        var centerPos = position3dToGridRealPosition(0, 0, 0)
        var offsetPos = position3dToGridRealPosition(radius3D, 0, 0)
        
        var dx = offsetPos.x - centerPos.x
        var dy = offsetPos.y - centerPos.y
        var gridRadius = Math.sqrt(dx * dx + dy * dy)
        
        return gridRadius
    }

    // ==================== CONVERSION DIRECTE POUR PHYSIQUE 2D ====================
    // Ces fonctions sont SYMÉTRIQUES et n'utilisent pas la projection de caméra
    // Elles travaillent directement avec les coordonnées 3D (X, Z) ↔ 2D (x, y)

    /**
     * Convertit une position 3D (X, Z) en position 2D pour la physique
     * Conversion directe sans projection de caméra
     * @param x3D Position X dans le monde 3D
     * @param z3D Position Z dans le monde 3D
     * @returns Qt.vector2d(x2D, y2D) en unités de grille
     */
    function world3DToGrid2D(x3D, z3D)
    {
        if (!gridManager) {
            console.error("world3DToGrid2D: gridManager non défini");
            return Qt.vector2d(0, 0);
        }
        
        // X3D -> X2D (même direction)
        // Z3D -> Y2D (inversé : Z+ 3D = Y- 2D)
        var x2D = x3D / gridManager.gridSize
        var y2D = -z3D / gridManager.gridSize
        
        return Qt.vector2d(x2D, y2D)
    }

    /**
     * Convertit une position 2D en position 3D (X, Y=0, Z)
     * Conversion directe sans projection de caméra
     * @param x2D Position X en unités de grille 2D
     * @param y2D Position Y en unités de grille 2D
     * @returns Qt.vector3d(x3D, 0, z3D)
     */
    function grid2DToWorld3D(x2D, y2D)
    {
        if (!gridManager) {
            console.error("grid2DToWorld3D: gridManager non défini");
            return Qt.vector3d(0, 0, 0);
        }
        
        // X2D -> X3D (même direction)
        // Y2D -> Z3D (inversé : Y+ 2D = Z- 3D)
        var x3D = x2D * gridManager.gridSize
        var z3D = -y2D * gridManager.gridSize
        
        return Qt.vector3d(x3D, 0, z3D)
    }

    /**
     * Calcule la distance entre deux points 2D
     * @param p1 Premier point (Qt.point ou objet avec x, y)
     * @param p2 Deuxième point (Qt.point ou objet avec x, y)
     * @returns Distance
     */
    function distance2D(p1, p2)
    {
        var dx = p2.x - p1.x
        var dy = p2.y - p1.y
        return Math.sqrt(dx * dx + dy * dy)
    }

    /**
     * Calcule le produit scalaire de deux vecteurs 2D
     * @param v1 Premier vecteur (vector2d ou objet avec x, y)
     * @param v2 Deuxième vecteur (vector2d ou objet avec x, y)
     * @returns Produit scalaire
     */
    function dot2D(v1, v2)
    {
        return v1.x * v2.x + v1.y * v2.y
    }

    /**
     * Normalise un vecteur 2D
     * @param v Vecteur à normaliser
     * @returns Vecteur normalisé (ou vecteur nul si longueur = 0)
     */
    function normalize2D(v)
    {
        var len = Math.sqrt(v.x * v.x + v.y * v.y)
        if (len < 0.0001) return Qt.vector2d(0, 0)
        return Qt.vector2d(v.x / len, v.y / len)
    }

}
