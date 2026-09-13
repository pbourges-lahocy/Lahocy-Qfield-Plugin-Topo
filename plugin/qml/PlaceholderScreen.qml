import QtQuick
import QtQuick.Controls

// Ecran generique "a venir" pour les menus dont la fonctionnalite n'est pas
// encore developpee. Reutilise par tous les menus non implementes afin de
// ne pas dupliquer 6 fois le meme squelette de Dialog.
Dialog {
    id: placeholder

    property string screenTitle: ""

    parent: iface.mainWindow().contentItem
    title: screenTitle
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(320, parent.width - 20)
    height: Math.min(implicitHeight, parent.height - 20)

    Label {
        width: parent.width
        wrapMode: Text.WordWrap
        text: qsTr("Cette fonctionnalite arrive dans une prochaine version de Lahocy Topo.")
    }
}
