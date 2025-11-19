import QtQuick
import QtQuick3D

Node {
    id: node4

    // Resources
    property url textureData6: "maps/textureData6.fbm"
    Texture {
        id: princessV2_fbm_texture
        objectName: "princessV2.fbm"
        source: node4.textureData6
    }
    PrincipledMaterial {
        id: pbr_Material_003_material
        objectName: "PBR_Material.003"
        baseColor: "#ffcccccc"
        baseColorMap: princessV2_fbm_texture
        roughness: 0.5
    }

    // Nodes:
    Node {
        id: rootNode3
        objectName: "RootNode"
        Model {
            id: textured_mesh_obj4
            objectName: "textured_mesh.obj"
            rotation: Qt.quaternion(0.707107, -0.707107, 0, 0)
            scale: Qt.vector3d(100, 100, 100)
            source: "meshes/textured_mesh_obj_001_mesh4.mesh"
            materials: [
                pbr_Material_003_material
            ]
        }
    }

    // Animations:
}
