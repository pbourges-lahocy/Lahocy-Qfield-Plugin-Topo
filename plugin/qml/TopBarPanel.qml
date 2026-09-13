import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Theme

// Panneau de test ancre en haut de l'ecran, en survol de la carte (QField
// n'expose pas de "topMargin" sur son canvas, contrairement a rightMargin
// et bottomMargin - voir PaletteScreen.qml et BottomBarPanel.qml pour le
// detail de cette contrainte). Sert uniquement a juger si 3 panneaux
// ancres simultanement (haut/droite/bas) restent utilisables a l'ecran.
Item {
    id: topBar

    property bool panelVisible: false

    parent: iface.mainWindow().contentItem
    anchors.top: parent.top
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
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.gray
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10

        Label { text: qsTr("Panneau haut (test)"); font.bold: true }
        Item { Layout.fillWidth: true }
    }
}
