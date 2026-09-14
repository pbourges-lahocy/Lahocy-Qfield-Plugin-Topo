import QtQuick
import QtQuick.Controls

import org.qfield
import org.qgis
import Theme

import "qml" as LahocyTopo

// Point d'entree du plugin d'application Lahocy Topo.
//
// Ce fichier ne fait qu'orchestrer : un bouton dans la barre d'outils des
// plugins ouvre le menu d'accueil (HomeMenu.qml), qui redirige vers l'un
// des ecrans dans qml/. Toute la logique de calcul topo vit dans
// TopoEngine.js, independamment de l'UI.
Item {
    id: plugin

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(pluginButton);
    }

    QfToolButton {
        id: pluginButton
        iconSource: 'icon.svg'
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true

        onClicked: homeMenu.open()
    }

    LahocyTopo.HomeMenu {
        id: homeMenu

        onEntrySelected: function (key) {
            switch (key) {
            case "survey":
                polarSurveyScreen.open();
                break;
            case "diagnostic":
                diagnosticScreen.open();
                break;
            case "palette_test":
                paletteScreen.toggle();
                topBarPanel.panelVisible = paletteScreen.panelVisible;
                bottomBarPanel.panelVisible = paletteScreen.panelVisible;
                break;
            case "minimal_test":
                minimalTestScreen.open();
                break;
            case "gnss":
                openPlaceholder(qsTr("GNSS"));
                break;
            case "totalstation":
                openPlaceholder(qsTr("Station totale"));
                break;
            case "stakeout":
                openPlaceholder(qsTr("Implantation"));
                break;
            case "traverse":
                openPlaceholder(qsTr("Polygonale"));
                break;
            case "devices":
                openPlaceholder(qsTr("Appareils"));
                break;
            }
        }
    }

    LahocyTopo.DiagnosticScreen {
        id: diagnosticScreen
    }

    LahocyTopo.PolarSurveyScreen {
        id: polarSurveyScreen
    }

    LahocyTopo.PaletteScreen {
        id: paletteScreen

        onCloseRequested: {
            paletteScreen.panelVisible = false;
            topBarPanel.panelVisible = false;
            bottomBarPanel.panelVisible = false;
        }
    }

    LahocyTopo.TopBarPanel {
        id: topBarPanel
    }

    LahocyTopo.BottomBarPanel {
        id: bottomBarPanel
    }

    LahocyTopo.PlaceholderScreen {
        id: placeholderScreen
    }

    LahocyTopo.MinimalTestScreen {
        id: minimalTestScreen
    }

    function openPlaceholder(title) {
        placeholderScreen.screenTitle = title;
        placeholderScreen.open();
    }
}
