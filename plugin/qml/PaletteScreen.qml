import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import org.qgis
import Theme

// Test d'interaction "palette a 2 niveaux", inspire du fonctionnement reel
// de Land2Map : une palette principale de categories, un appui sur une
// categorie ouvre sa sous-palette de codes precis, puis un panneau
// contextuel "pose du point" apparait une fois un code choisi.
//
// Catalogue ci-dessous : donnees d'exemple pour tester l'interaction,
// PAS le catalogue Lahocy definitif.
Dialog {
    id: palette

    property var dashBoard: iface.findItemByObjectName('dashBoard')
    property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')
    property var positioning: iface.positioning()

    property var categories: [
        { key: "reseaux", label: qsTr("Reseaux"), codes: ["237", "238", "239", "240", "241", "242", "243", "244"] },
        { key: "voirie", label: qsTr("Voirie"), codes: ["301", "302", "303", "304"] },
        { key: "assain", label: qsTr("Assainissement"), codes: ["410", "411", "412"] },
        { key: "divers", label: qsTr("Divers"), codes: ["901", "902"] }
    ]

    property int selectedCategoryIndex: -1
    property string selectedCode: ""
    property string poseMode: "1pt"
    property bool excentrementEnabled: false

    parent: iface.mainWindow().contentItem
    title: qsTr("Palette (test)")
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(360, parent.width - 20)
    height: Math.min(implicitHeight, parent.height - 20)

    onClosed: {
        selectedCategoryIndex = -1;
        selectedCode = "";
    }

    function reset() {
        selectedCategoryIndex = -1;
        selectedCode = "";
    }

    function findAttributeIndex(layer) {
        var candidates = ["code", "CODE", "Code"];
        for (var i = 0; i < candidates.length; i++) {
            var idx = layer.fields.indexOf(candidates[i]);
            if (idx !== -1) {
                return idx;
            }
        }
        return -1;
    }

    function leverPointCourant() {
        if (!positioning || !positioning.active) {
            iface.mainWindow().displayToast(qsTr("Positionnement inactif"));
            return;
        }
        var p = positioning.projectedPosition;
        if (!p || isNaN(p.x) || isNaN(p.y)) {
            iface.mainWindow().displayToast(qsTr("Position actuelle indisponible"));
            return;
        }
        if (!dashBoard) {
            iface.mainWindow().displayToast(qsTr("Impossible d'acceder au tableau de bord QField"));
            return;
        }

        dashBoard.ensureEditableLayerSelected();
        var activeLayer = dashBoard.activeLayer;

        if (!activeLayer || !activeLayer.isValid) {
            iface.mainWindow().displayToast(qsTr("Aucune couche active valide"));
            return;
        }
        if (activeLayer.geometryType() !== Qgis.GeometryType.Point) {
            iface.mainWindow().displayToast(qsTr("La couche active doit etre une couche ponctuelle"));
            return;
        }

        var wkt = "POINT(" + p.x + " " + p.y + ")";
        var geometry = GeometryUtils.createGeometryFromWkt(wkt);
        var feature = FeatureUtils.createFeature(activeLayer, geometry);

        if (!feature) {
            iface.mainWindow().displayToast(qsTr("Echec de la creation du point"));
            return;
        }

        var codeFieldIndex = palette.findAttributeIndex(activeLayer);
        if (codeFieldIndex !== -1) {
            feature.setAttribute(codeFieldIndex, palette.selectedCode);
        }

        overlayFeatureFormDrawer.state = 'Add';
        overlayFeatureFormDrawer.featureModel.feature = feature;
        overlayFeatureFormDrawer.open();
        palette.close();
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        // --- Niveau 1 : palette principale (categories) ---
        ColumnLayout {
            visible: palette.selectedCategoryIndex === -1
            Layout.fillWidth: true
            spacing: 6

            Label { text: qsTr("Categories"); font.bold: true }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: palette.categories

                    delegate: Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        text: modelData.label
                        onClicked: palette.selectedCategoryIndex = index
                    }
                }
            }
        }

        // --- Niveau 2 : sous-palette (codes de la categorie) ---
        ColumnLayout {
            visible: palette.selectedCategoryIndex !== -1 && palette.selectedCode === ""
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("< Categories")
                    onClicked: palette.selectedCategoryIndex = -1
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    font.bold: true
                    text: palette.selectedCategoryIndex !== -1 ? palette.categories[palette.selectedCategoryIndex].label : ""
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: palette.selectedCategoryIndex !== -1 ? palette.categories[palette.selectedCategoryIndex].codes : []

                    delegate: Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: modelData
                        onClicked: palette.selectedCode = modelData
                    }
                }
            }
        }

        // --- Pose du point (contextuel, code choisi) ---
        ColumnLayout {
            visible: palette.selectedCode !== ""
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("< Codes")
                    onClicked: palette.selectedCode = ""
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    font.bold: true
                    text: qsTr("Code %1").arg(palette.selectedCode)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

            Label { text: qsTr("Pose du point"); font.bold: true }

            RowLayout {
                spacing: 6
                Button {
                    text: qsTr("1 pt")
                    highlighted: palette.poseMode === "1pt"
                    onClicked: palette.poseMode = "1pt"
                }
                Button {
                    text: qsTr("2 pts")
                    highlighted: palette.poseMode === "2pt"
                    onClicked: palette.poseMode = "2pt"
                }
                Button {
                    text: qsTr("3 pts")
                    highlighted: palette.poseMode === "3pt"
                    onClicked: palette.poseMode = "3pt"
                }
            }

            RowLayout {
                Label { text: qsTr("Excentrement") }
                Item { Layout.fillWidth: true }
                Switch {
                    checked: palette.excentrementEnabled
                    onCheckedChanged: palette.excentrementEnabled = checked
                }
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: Theme.gray
                text: palette.poseMode === "1pt"
                    ? qsTr("Pose direct sur la position actuelle.")
                    : qsTr("Modes 2/3 points et excentrement : a cabler plus tard (POC).")
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("Lever le point (position actuelle)")
                enabled: palette.poseMode === "1pt"
                onClicked: palette.leverPointCourant()
            }
        }
    }
}
