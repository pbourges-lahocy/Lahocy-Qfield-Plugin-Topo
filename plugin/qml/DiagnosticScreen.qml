import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield

// Ecran de diagnostic GNSS/QField.
//
// Affiche uniquement des proprietes reellement exposees par QField sur
// `iface.positioning()` (QfPositioning) et sa `positionInformation`
// (QfGnssPositionInformation), verifiees dans le code source de QField.
// Aucune propriete n'est inventee : si un champ n'existe pas sur cette
// version de QField, il n'apparait pas ici plutot que d'afficher une
// valeur fausse.
Dialog {
    id: diagnostic

    property var positioning: iface.positioning()
    property var pi: positioning ? positioning.positionInformation : undefined

    parent: iface.mainWindow().contentItem
    title: qsTr("Diagnostic QField / GNSS")
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(420, parent.width - 20)
    height: Math.min(implicitHeight, parent.height - 40)

    function fmtNum(value, decimals) {
        if (value === undefined || value === null || isNaN(value)) {
            return "-";
        }
        return Number(value).toFixed(decimals !== undefined ? decimals : 3);
    }

    function fmtValid(value, validFlag, decimals) {
        return validFlag ? fmtNum(value, decimals) : qsTr("indisponible");
    }

    function fmtBool(value) {
        return value ? qsTr("oui") : qsTr("non");
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: diagnostic.availableWidth
            spacing: 12

            // --- Etat de la source de positionnement (QfPositioning) ---
            Label {
                text: qsTr("Source de positionnement")
                font.bold: true
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12

                Label { text: qsTr("Active") }
                Label { text: positioning ? diagnostic.fmtBool(positioning.active) : "-" }

                Label { text: qsTr("Valide") }
                Label { text: positioning ? diagnostic.fmtBool(positioning.valid) : "-" }

                Label { text: qsTr("Identifiant appareil") }
                Label { text: positioning && positioning.deviceId ? positioning.deviceId : qsTr("(interne)") }

                Label { text: qsTr("Antenne (hauteur)") }
                Label { text: positioning ? diagnostic.fmtNum(positioning.antennaHeight, 3) + " m" : "-" }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

            // --- Position (QfGnssPositionInformation) ---
            Label {
                text: qsTr("Position")
                font.bold: true
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12

                Label { text: qsTr("Latitude") }
                Label { text: pi ? diagnostic.fmtValid(pi.latitude, pi.latitudeValid, 7) : "-" }

                Label { text: qsTr("Longitude") }
                Label { text: pi ? diagnostic.fmtValid(pi.longitude, pi.longitudeValid, 7) : "-" }

                Label { text: qsTr("Altitude") }
                Label { text: pi ? diagnostic.fmtValid(pi.elevation, pi.elevationValid, 3) + " m" : "-" }

                Label { text: qsTr("Horodatage (UTC)") }
                Label { text: pi && pi.utcDateTime ? pi.utcDateTime.toString() : "-" }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

            // --- Qualite / statut du fix ---
            Label {
                text: qsTr("Qualite du fix")
                font.bold: true
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12

                Label { text: qsTr("Statut du fix") }
                Label { text: pi ? pi.fixStatusDescription : "-" }

                Label { text: qsTr("Description qualite") }
                Label { text: pi ? pi.qualityDescription : "-" }

                Label { text: qsTr("Type de fix (1=aucun,2=2D,3=3D)") }
                Label { text: pi ? pi.fixType : "-" }

                Label { text: qsTr("Qualite (indicateur brut)") }
                Label { text: pi ? pi.quality : "-" }

                Label { text: qsTr("Mode fix (M/A)") }
                Label { text: pi ? pi.fixMode : "-" }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

            // --- Precision ---
            Label {
                text: qsTr("Precision")
                font.bold: true
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12

                Label { text: qsTr("PDOP") }
                Label { text: pi ? diagnostic.fmtNum(pi.pdop, 2) : "-" }

                Label { text: qsTr("HDOP") }
                Label { text: pi ? diagnostic.fmtNum(pi.hdop, 2) : "-" }

                Label { text: qsTr("VDOP") }
                Label { text: pi ? diagnostic.fmtNum(pi.vdop, 2) : "-" }

                Label { text: qsTr("Precision horizontale") }
                Label { text: pi ? diagnostic.fmtValid(pi.hacc, pi.haccValid, 3) + " m" : "-" }

                Label { text: qsTr("Precision verticale") }
                Label { text: pi ? diagnostic.fmtValid(pi.vacc, pi.vaccValid, 3) + " m" : "-" }

                Label { text: qsTr("Precision 3D") }
                Label { text: pi ? diagnostic.fmtNum(pi.hvacc, 3) + " m" : "-" }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

            // --- Satellites ---
            Label {
                text: qsTr("Satellites")
                font.bold: true
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12

                Label { text: qsTr("Satellites utilises") }
                Label { text: pi ? pi.satellitesUsed : "-" }

                Label { text: qsTr("Infos satellites completes") }
                Label { text: pi ? diagnostic.fmtBool(pi.satInfoComplete) : "-" }

                Label { text: qsTr("Satellites en vue") }
                Label { text: pi && pi.satellitesInView ? pi.satellitesInView.length : "-" }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.gray }

            // --- Mouvement / divers ---
            Label {
                text: qsTr("Mouvement et divers")
                font.bold: true
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12

                Label { text: qsTr("Vitesse") }
                Label { text: pi ? diagnostic.fmtValid(pi.speed, pi.speedValid, 2) + " km/h" : "-" }

                Label { text: qsTr("Direction") }
                Label { text: pi ? diagnostic.fmtValid(pi.direction, pi.directionValid, 1) + " deg" : "-" }

                Label { text: qsTr("Vitesse verticale") }
                Label { text: pi ? diagnostic.fmtNum(pi.verticalSpeed, 2) + " km/h" : "-" }

                Label { text: qsTr("Declinaison magnetique") }
                Label { text: pi ? diagnostic.fmtNum(pi.magneticVariation, 1) + " deg" : "-" }

                Label { text: qsTr("Nom de la source") }
                Label { text: pi && pi.sourceName ? pi.sourceName : "-" }

                Label { text: qsTr("Position moyennee (nb releves)") }
                Label { text: pi ? pi.averagedCount : "-" }
            }
        }
    }
}
