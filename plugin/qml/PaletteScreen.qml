import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import org.qgis
import Theme

import "TopoEngine.js" as TopoEngine

// Panneau de palette ancre a droite de l'ecran, non modal : contrairement
// a une Dialog, il reste ouvert et accessible en permanence pendant que
// l'utilisateur continue a naviguer/zoomer sur la carte - c'est ce
// fonctionnement (jamais de popup a rouvrir) qui rend Land2Map fluide sur
// le terrain.
//
// Toujours 2 niveaux : palette principale de categories -> sous-palette de
// codes -> panneau contextuel "pose du point".
//
// Catalogue ci-dessous : donnees d'exemple pour tester l'interaction,
// PAS le catalogue Lahocy definitif.
Item {
    id: palette

    property bool panelVisible: false
    function toggle() {
        panelVisible = !panelVisible;
    }

    signal closeRequested()

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
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 260
    visible: panelVisible
    z: 1000

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

        var targetX = p.x;
        var targetY = p.y;

        if (palette.excentrementEnabled) {
            if (!TopoEngine.isValidNumber(gisementField.text) || !TopoEngine.isValidNumber(distanceField.text)) {
                iface.mainWindow().displayToast(qsTr("Gisement et distance d'excentrement requis"));
                return;
            }
            var offsetPoint = TopoEngine.polarPoint(p.x, p.y, Number(gisementField.text), Number(distanceField.text));
            targetX = offsetPoint.x;
            targetY = offsetPoint.y;
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

        var wkt = "POINT(" + targetX + " " + targetY + ")";
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
        // Le panneau reste ouvert : on revient a la sous-palette pour
        // enchainer directement sur le prochain point du meme theme.
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.mainBackgroundColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: Theme.gray
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Label { text: qsTr("Palette (test)"); font.bold: true; Layout.fillWidth: true }
            Button {
                text: "✕"
                flat: true
                onClicked: palette.closeRequested()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            StackLayout {
                id: paletteStack
                width: palette.width - 20
                currentIndex: palette.selectedCode !== "" ? 2 : (palette.selectedCategoryIndex !== -1 ? 1 : 0)

                onCurrentIndexChanged: iface.mainWindow().displayToast("DEBUG: currentIndex=" + currentIndex)

                // --- Niveau 1 : palette principale (categories) ---
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label { text: qsTr("Categories") + " (DEBUG idx=" + paletteStack.currentIndex + ")"; font.bold: true }

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
                                onClicked: {
                                    iface.mainWindow().displayToast("DEBUG: clic " + index + " selCat.before=" + palette.selectedCategoryIndex);
                                    palette.selectedCategoryIndex = index;
                                    iface.mainWindow().displayToast("DEBUG: selCat.after=" + palette.selectedCategoryIndex);
                                }
                            }
                        }
                    }
                }

                // --- Niveau 2 : sous-palette (codes de la categorie) ---
                ColumnLayout {
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

                    GridLayout {
                        visible: palette.excentrementEnabled
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8

                        Label { text: qsTr("Gisement (gon)") }
                        TextField {
                            id: gisementField
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        Label { text: qsTr("Distance (m)") }
                        TextField {
                            id: distanceField
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                        color: Theme.gray
                        text: palette.poseMode === "1pt"
                            ? (palette.excentrementEnabled
                                ? qsTr("Pose decalee de la position actuelle (gisement + distance).")
                                : qsTr("Pose direct sur la position actuelle."))
                            : qsTr("Modes 2/3 points : a cabler plus tard (POC).")
                    }

                    Button {
                        Layout.fillWidth: true
                        text: qsTr("Lever le point")
                        enabled: palette.poseMode === "1pt"
                        onClicked: palette.leverPointCourant()
                    }
                }
            }
        }
    }
}
