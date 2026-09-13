import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Menu d'accueil de Lahocy Topo. Chaque entree emet entrySelected(key) et
// c'est main.qml qui decide quel ecran ouvrir : ce composant ne connait pas
// le contenu des ecrans, uniquement la liste des entrees du menu.
Dialog {
    id: homeMenu

    signal entrySelected(string key)

    parent: iface.mainWindow().contentItem
    title: qsTr("Lahocy Topo")
    modal: true
    standardButtons: Dialog.Close
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(360, parent.width - 20)
    height: Math.min(implicitHeight, parent.height - 20)

    ColumnLayout {
        width: parent.width
        spacing: 6

        Repeater {
            model: [
                { key: "gnss", label: qsTr("GNSS") },
                { key: "totalstation", label: qsTr("Station totale") },
                { key: "survey", label: qsTr("Leve") },
                { key: "stakeout", label: qsTr("Implantation") },
                { key: "traverse", label: qsTr("Polygonale") },
                { key: "devices", label: qsTr("Appareils") },
                { key: "diagnostic", label: qsTr("Diagnostic") }
            ]

            delegate: Button {
                Layout.fillWidth: true
                text: modelData.label
                onClicked: {
                    homeMenu.entrySelected(modelData.key);
                    homeMenu.close();
                }
            }
        }
    }
}
