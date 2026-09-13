import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import org.qgis
import Theme

import "TopoEngine.js" as TopoEngine

// Leve polaire (rayonnement) : calcul topo POC.
//
// Saisie X/Y station + gisement (gon) + distance horizontale -> calcul du
// point vise, puis creation optionnelle de ce point dans la couche
// ponctuelle active de QField (via le formulaire d'ajout standard de
// QField, pour que l'utilisateur verifie/valide les attributs avant
// enregistrement).
Dialog {
    id: polarSurvey

    property var dashBoard: iface.findItemByObjectName('dashBoard')
    property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')

    property var computedPoint: null

    parent: iface.mainWindow().contentItem
    title: qsTr("Leve polaire")
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(380, parent.width - 20)
    height: Math.min(implicitHeight, parent.height - 20)

    function recompute() {
        if (TopoEngine.isValidNumber(xStationField.text) &&
            TopoEngine.isValidNumber(yStationField.text) &&
            TopoEngine.isValidNumber(gisementField.text) &&
            TopoEngine.isValidNumber(distanceField.text)) {
            polarSurvey.computedPoint = TopoEngine.polarPoint(
                Number(xStationField.text),
                Number(yStationField.text),
                Number(gisementField.text),
                Number(distanceField.text)
            );
        } else {
            polarSurvey.computedPoint = null;
        }
    }

    function createPointFeature() {
        if (!polarSurvey.computedPoint) {
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

        var wkt = "POINT(" + polarSurvey.computedPoint.x + " " + polarSurvey.computedPoint.y + ")";
        var geometry = GeometryUtils.createGeometryFromWkt(wkt);
        var feature = FeatureUtils.createFeature(activeLayer, geometry);

        if (!feature) {
            iface.mainWindow().displayToast(qsTr("Echec de la creation du point"));
            return;
        }

        overlayFeatureFormDrawer.state = 'Add';
        overlayFeatureFormDrawer.featureModel.feature = feature;
        overlayFeatureFormDrawer.open();
        polarSurvey.close();
    }

    ColumnLayout {
        width: parent.width
        spacing: 8

        Label { text: qsTr("Station connue") ; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8

            Label { text: qsTr("X station") }
            TextField {
                id: xStationField
                Layout.fillWidth: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextChanged: polarSurvey.recompute()
            }

            Label { text: qsTr("Y station") }
            TextField {
                id: yStationField
                Layout.fillWidth: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextChanged: polarSurvey.recompute()
            }
        }

        Label { text: qsTr("Visee") ; font.bold: true }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8

            Label { text: qsTr("Gisement (gon)") }
            TextField {
                id: gisementField
                Layout.fillWidth: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextChanged: polarSurvey.recompute()
            }

            Label { text: qsTr("Distance horizontale (m)") }
            TextField {
                id: distanceField
                Layout.fillWidth: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextChanged: polarSurvey.recompute()
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

        Label {
            Layout.fillWidth: true
            font.bold: true
            text: polarSurvey.computedPoint
                ? qsTr("Point calcule : X=%1  Y=%2").arg(polarSurvey.computedPoint.x.toFixed(3)).arg(polarSurvey.computedPoint.y.toFixed(3))
                : qsTr("Renseignez les 4 champs pour calculer le point")
        }

        Button {
            Layout.fillWidth: true
            text: qsTr("Creer le point dans la couche active")
            enabled: polarSurvey.computedPoint !== null
            onClicked: polarSurvey.createPointFeature()
        }
    }
}
