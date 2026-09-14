import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Theme

// Panneau de test ancre en bas de l'ecran, en survol de la carte.
//
// Contrairement au panneau haut, QField expose bien un "bottomMargin" sur
// son mapCanvas (voir PaletteScreen.qml pour rightMargin) : il serait donc
// possible, plus tard, de vraiment reserver cet espace plutot que de
// simplement survoler la carte - mais cela ecraserait le binding que
// QField utilise en interne pour ses propres tiroirs, donc pas fait ici.
// Ce panneau reste en survol comme les deux autres, pour une comparaison
// homogene pendant le test.
//
// anchors.bottomMargin: mainWindow.sceneBottomMargin pour ne pas passer
// sous les boutons de navigation Android (retour/accueil/multitaches),
// quand ils sont affiches a l'ecran plutot que geres par gestes.
Item {
    id: bottomBar

    property bool panelVisible: false

    parent: iface.mainWindow().contentItem
    anchors.bottom: parent.bottom
    anchors.bottomMargin: iface.mainWindow().sceneBottomMargin
    anchors.left: parent.left
    anchors.right: parent.right
    height: 40
    visible: panelVisible
    z: 999

    Rectangle {
        anchors.fill: parent
        color: Theme.mainBackgroundColor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.gray
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        Label { text: qsTr("Panneau bas (test)"); font.bold: true }
        Item { Layout.fillWidth: true }
    }
}
