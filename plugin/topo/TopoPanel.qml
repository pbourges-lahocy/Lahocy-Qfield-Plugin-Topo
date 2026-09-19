import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoPanel - les deux colonnes de droite (ou de gauche en mode gaucher) :
 *   - colonne « objets » : palette sur 3 colonnes (familles, sous-palette, recherche) ;
 *   - panneau « mesure » : source et appareils, hauteur, voyants, réglages de pose de
 *     l'objet en cours, excentrements, Mesurer / STOP, objets actifs (plus tard : attributs).
 *
 * Implémenté en Popup non modal (closePolicy: NoAutoClose) et non en Item
 * reparenté : sur les tablettes Android testées avec le POC, seuls les
 * éléments gérés par l'Overlay de QtQuick Controls (Dialog / Popup) se
 * repeignent de façon fiable.
 */
Popup {
  id: panel

  required property var engine
  required property var station
  required property var devices
  required property var mainWindow

  signal openStationMenu()

  readonly property bool droitier: engine.droitier
  readonly property real safeTop: mainWindow.sceneTopMargin !== undefined ? mainWindow.sceneTopMargin : 0
  readonly property real safeBottom: mainWindow.sceneBottomMargin !== undefined ? mainWindow.sceneBottomMargin : 0
  readonly property real safeRight: mainWindow.sceneRightMargin !== undefined ? mainWindow.sceneRightMargin : 0
  readonly property real safeLeft: mainWindow.sceneLeftMargin !== undefined ? mainWindow.sceneLeftMargin : 0
  readonly property real cell: 52
  readonly property real paletteWidth: 3 * cell + 2 * 4 + 20
  readonly property real measureWidth: 244

  // collé au bord et aux angles de l'écran (zone sûre du système)
  parent: mainWindow.contentItem
  x: droitier ? parent.width - width - safeRight : safeLeft
  y: safeTop
  width: paletteWidth + measureWidth
  height: parent.height - safeTop - safeBottom
  padding: 0
  modal: false
  dim: false
  closePolicy: Popup.NoAutoClose

  background: Rectangle {
    color: QfTheme.darkTheme ? "#1f1f1f" : "#ffffff"
    border.color: QfTheme.darkTheme ? "#505050" : "#d4d4d4"
    border.width: 1
    opacity: 0.97
  }

  contentItem: RowLayout {
    spacing: 0
    layoutDirection: panel.droitier ? Qt.LeftToRight : Qt.RightToLeft

    /* ---------------- colonne objets ---------------- */
    ColumnLayout {
      Layout.preferredWidth: panel.paletteWidth
      Layout.maximumWidth: panel.paletteWidth
      Layout.fillHeight: true
      Layout.margins: 6
      spacing: 6

      RowLayout {
        Layout.fillWidth: true
        spacing: 4
        TopoBtn { visible: paletteZone.inSub || paletteZone.searching; width: 28; height: 28; ui: "retour"; small: true; onClicked: paletteZone.back() }
        Text { Layout.fillWidth: true; text: paletteZone.title; font.pixelSize: 12; font.bold: true; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"; elide: Text.ElideRight }
        TopoBtn { width: 28; height: 28; ui: "recherche"; small: true; checked: paletteZone.searching; onClicked: paletteZone.toggleSearch() }
      }
      TopoPalette {
        id: paletteZone
        Layout.fillWidth: true
        Layout.fillHeight: true
        engine: panel.engine
        cell: panel.cell
        columns: 3
      }
    }

    Rectangle { Layout.fillHeight: true; width: 1; color: QfTheme.darkTheme ? "#505050" : "#e0e0e0" }

    /* ---------------- panneau mesure ---------------- */
    Flickable {
      Layout.preferredWidth: panel.measureWidth
      Layout.fillHeight: true
      contentHeight: measureCol.implicitHeight + 12
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: measureCol
        x: 6
        y: 6
        width: panel.measureWidth - 12
        spacing: 8

        TopoSourceBox { Layout.fillWidth: true; engine: panel.engine; station: panel.station; devices: panel.devices; onOpenStationMenu: panel.openStationMenu() }

        Rectangle { Layout.fillWidth: true; height: 1; color: QfTheme.darkTheme ? "#505050" : "#e0e0e0" }

        // comment l'objet en cours est posé / dessiné
        TopoDrawOptions { Layout.fillWidth: true; engine: panel.engine; station: panel.station }

        Rectangle { Layout.fillWidth: true; height: 1; color: QfTheme.darkTheme ? "#505050" : "#e0e0e0" }

        // excentrements, Mesurer / STOP, point unique, dernier point
        TopoMeasureBox { Layout.fillWidth: true; engine: panel.engine; station: panel.station; devices: panel.devices }

        Rectangle { Layout.fillWidth: true; height: 1; color: QfTheme.darkTheme ? "#505050" : "#e0e0e0" }

        TopoActiveObjects { Layout.fillWidth: true; engine: panel.engine }
      }
    }
  }
}
