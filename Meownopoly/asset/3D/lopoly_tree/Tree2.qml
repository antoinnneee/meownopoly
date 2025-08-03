import QtQuick
import QtQuick3D

Node {
    id: node

    // Resources

    // Nodes:

    Node {
        id: __materialLibrary__

        PrincipledMaterial {
            id: material_002_material
            objectName: "Material.002"
            baseColor: "#ff110301"
            roughness: 0.5
        }

        PrincipledMaterial {
            id: material_001_material
            objectName: "Material.001"
            baseColor: "#ff023501"
            roughness: 0.6727272868156433
        }
    }

    // Animations:
    Node {
        id: rootNode
        objectName: "RootNode"
        Model {
            id: cylinder
            objectName: "Cylinder"
            rotation: Qt.quaternion(0.707107, -0.707107, 0, 0)
            scale: Qt.vector3d(100, 100, 100)
            source: "meshes/cylinder_000_mesh.mesh"
            materials: [
                material_002_material
            ]
        }
        Model {
            id: icosphere
            objectName: "Icosphere"
            position: Qt.vector3d(350.534, 1367.57, -117.282)
            rotation: Qt.quaternion(0.707107, -0.707107, 0, 0)
            scale: Qt.vector3d(496.762, 496.762, 496.762)
            source: "meshes/icosphere_001_mesh.mesh"
            materials: [
                material_001_material
            ]
        }
    }
}
