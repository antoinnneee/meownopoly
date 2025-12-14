import QtQuick 2.15
import QtQuick3D
import QtQuick3D.Helpers
import AssetManager
import "../component/grid"
import "../utils"

Item {
    id: root

    // --- Public API ---
    property alias view3D: view3D
    property alias scene: sceneNode
    property alias camera: cameraOrthographic
    property alias entity: entityNode
    property alias environment: sceneEnvironment
    required property GridManager gridManager
    
    // Properties for camera control
    property real cameraMagnification: 1.0

    // Component pour créer des sphères dynamiquement
    Component {
        id: sphereComponent
        Model {
            source: "#Sphere"
            materials: PrincipledMaterial {
                baseColor: "white"
            }
        }
    }

    function generateSphere(x, y, z, radius, color) {
        // Créer une nouvelle instance de sphère dans sceneNode
        var sphere = sphereComponent.createObject(sceneNode, {
            "x": x,
            "y": y,
            "z": z,
            // Le scale de la sphère primitive #Sphere est de 100 unités de diamètre par défaut
            // Donc pour un rayon donné, on divise par 50 (diamètre/100)
            "scale": Qt.vector3d(radius / 50, radius / 50, radius / 50)
        });

        if (sphere === null) {
            console.error("Erreur lors de la création de la sphère");
            return null;
        }

        // Appliquer la couleur au matériau
        sphere.materials[0].baseColor = color;

        return sphere;
    }

    // Déplace un node/model à une position de grille (en coordonnées pixel de la vue)
    function moveEntityToGridPixelPosition(node, gridPixelX, gridPixelY) {
        if (!view3D || !node) {
            console.error("moveEntityToGridPixelPosition: view3D ou node non défini");
            return;
        }

        // Calculer la position 3D correspondante aux coordonnées pixel
        var pos3D = World3DTools.getGroundIntersection(gridPixelX, gridPixelY);

        // Appliquer la position au node
        node.x = pos3D.x;
        node.y = pos3D.y;
        node.z = pos3D.z;
    }

    function moveEntityToGridPosition(node, gridX, gridY) {
        if (!view3D || !node) {
            console.error("moveEntityToGridPosition: view3D ou node non défini");
            return;
        }

        var gridPos = gridManager.getGridPixelPosition(gridX, gridY);
        var pos3D = World3DTools.getGroundIntersection(gridPos.x, gridPos.y);
        node.x = pos3D.x;
        node.y = pos3D.y;
        node.z = pos3D.z;
    }

    // Retourne la position d'une entity en coordonnées pixel de la grille
    // Inverse de moveEntityToGridPixelPosition: coordonnées 3D -> coordonnées 2D grille
    function getEntityGridPixelPosition(node) {
        if (!view3D || !node || !gridManager) {
            console.error("getEntityGridPixelPosition: view3D, node ou gridManager non défini");
            return Qt.point(0, 0);
        }

        // 1. Projeter la position 3D du node vers les coordonnées 2D de la View3D
        var viewPos = view3D.mapFrom3DScene(Qt.vector3d(node.x, node.y, node.z));

        // 2. Convertir les coordonnées View3D vers les coordonnées de la grille
        var gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y);

        return Qt.point(gridPos.x, gridPos.y);
    }

    // Retourne la position d'une entity en coordonnées pixel de la grille
    // Inverse de moveEntityToGridPixelPosition: coordonnées 3D -> coordonnées 2D grille
    function getEntityGridRealPosition(node) {
        if (!view3D || !node || !gridManager) {
            console.error("getEntityGridPixelPosition: view3D, node ou gridManager non défini");
            return Qt.point(0, 0);
        }

        // 1. Projeter la position 3D du node vers les coordonnées 2D de la View3D
        var viewPos = view3D.mapFrom3DScene(Qt.vector3d(node.x, node.y, node.z));

        // 2. Convertir les coordonnées View3D vers les coordonnées de la grille
        var gridPos = view3D.mapToItem(gridManager, viewPos.x, viewPos.y);

        return Qt.point(gridPos.x/gridManager.gridSize, gridPos.y/gridManager.gridSize);
    }

    // Internal scene structure
    Node {
        id: sceneNode

        DirectionalLight {
            x: 0
            y: 264.806
            z: 1111.39001
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1.0)
            brightness: 1.2
            eulerRotation.x: -25
        }
        
        Node {
            id: entityNode
            x: 0
            y: 0
            z: 0


            Loader3D {
                id: modelLoader
                property string modelName: "Princess" // Nom du modèle par défaut
                
                // Construction du chemin vers AppData/models/Nom/Nom.qml
                source: "file:///" + AssetManager.getAppDataPath() + "/models/" + modelName + "/" + modelName + ".qml"
                
                onStatusChanged: {
                    if (status === Loader3D.Error) {
                        console.error("Erreur chargement modèle 3D:", sourceComponent.errorString())
                    } else if (status === Loader3D.Ready) {
                        console.log("Modèle 3D chargé:", source)
                    }
                }
            }
        }

        // Stationary orthographic camera viewing from the top
        OrthographicCamera {
            id: cameraOrthographic
            x: 0
            y: 1000
            clipNear: -10000
            clipFar: 1000055
            eulerRotation.z: 0
            eulerRotation.y: 0
            pivot.x: 0
            z: 600
            eulerRotation.x: -55
            horizontalMagnification: root.cameraMagnification
            verticalMagnification: root.cameraMagnification
        }
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: cameraOrthographic
        importScene: sceneNode

        environment: SceneEnvironment {
            id: sceneEnvironment
            antialiasingMode: SceneEnvironment.ProgressiveAA
            backgroundMode: SceneEnvironment.Transparent
        }
    }
}

