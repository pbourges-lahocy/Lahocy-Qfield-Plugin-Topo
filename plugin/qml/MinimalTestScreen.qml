import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import Theme

// Test minimal et temporaire : un bouton, un compteur affiche dans un
// Label. Sert a determiner si le probleme de rafraichissement touche
// TOUT le plugin (meme le cas le plus simple possible, dans une vraie
// Dialog comme Diagnostic/Leve qui fonctionnent) ou seulement la palette.
Dialog {
    id: testScreen

    property int counter: 0

    parent: iface.mainWindow().contentItem
    title: qsTr("Test minimal")
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(300, parent.width - 20)
    height: Math.min(implicitHeight, parent.height - 20)

    ColumnLayout {
        width: parent.width
        spacing: 12

        Label {
            text: qsTr("Compteur : %1").arg(testScreen.counter)
            font.pixelSize: 20
            font.bold: true
        }

        Button {
            Layout.fillWidth: true
            text: qsTr("Incrementer")
            onClicked: testScreen.counter = testScreen.counter + 1
        }
    }
}
