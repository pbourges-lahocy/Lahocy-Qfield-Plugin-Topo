import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoPanel - panneau latéral de levé : palette (familles, sous-palette,
 * recherche), primitives de dessin de l'objet en cours, mesure, objets actifs.
 * Ancré à droite (droitier) ou à gauche (gaucher), repliable.
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
  property bool collapsed: false

  readonly property bool droitier: engine.droitier
  readonly property real safeTop: mainWindow.sceneTopMargin !== undefined ? mainWindow.sceneTopMargin : 0
  readonly property real safeBottom: mainWindow.sceneBottomMargin !== undefined ? mainWindow.sceneBottomMargin : 0
  readonly property real safeRight: mainWindow.sceneRightMargin !== undefined ? mainWindow.sceneRightMargin : 0
  readonly property real safeLeft: mainWindow.sceneLeftMargin !== undefined ? mainWindow.sceneLeftMargin : 0
  readonly property real cell: 52
  readonly property real openWidth: 4 * cell + 3 * 4 + 54   // poignée + marges du panneau et de la palette

  parent: mainWindow.contentItem
  x: droitier ? parent.width - width - safeRight - 6 : safeLeft + 6
  y: safeTop + 6
  width: collapsed ? 34 : openWidth
  height: parent.height - safeTop - safeBottom - 12
  padding: 0
  modal: false
  dim: false
  closePolicy: Popup.NoAutoClose

  background: Rectangle {
    color: QfTheme.darkTheme ? "#1f1f1f" : "#ffffff"
    border.color: QfTheme.darkTheme ? "#505050" : "#d4d4d4"
    border.width: 1
    radius: 8
    opacity: 0.97
  }

  contentItem: Item {
    // poignée de repli
    Rectangle {
      width: 26; height: 56; radius: 8
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: panel.droitier ? parent.left : undefined
      anchors.right: panel.droitier ? undefined : parent.right
      anchors.margins: 4
      color: QfTheme.darkTheme ? "#3a3a3a" : "#ececec"
      z: 5
      Image {
        anchors.centerIn: parent
        source: Qt.resolvedUrl("../theme/ui/") + ((panel.collapsed !== panel.droitier) ? "replier_droite" : "replier_gauche") + (QfTheme.darkTheme ? "_w" : "") + ".svg"
        width: 18; height: 18; sourceSize.width: 36; sourceSize.height: 36
      }
      MouseArea { anchors.fill: parent; onClicked: panel.collapsed = !panel.collapsed }
    }

    ColumnLayout {
      visible: !panel.collapsed
      anchors.fill: parent
      anchors.leftMargin: panel.droitier ? 34 : 6
      anchors.rightMargin: panel.droitier ? 6 : 34
      anchors.topMargin: 6
      anchors.bottomMargin: 6
      spacing: 6

      /* ---------------- palette ---------------- */
      RowLayout {
        Layout.fillWidth: true
        spacing: 4
        TopoBtn { visible: paletteZone.inSub || paletteZone.searching; width: 30; height: 28; ui: "retour"; small: true; onClicked: paletteZone.back() }
        Text { Layout.fillWidth: true; text: paletteZone.title; font.pixelSize: 12; font.bold: true; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"; elide: Text.ElideRight }
        TopoBtn { width: 30; height: 28; ui: "recherche"; small: true; checked: paletteZone.searching; onClicked: paletteZone.toggleSearch() }
      }
      TopoPalette {
        id: paletteZone
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 150
        engine: panel.engine
        cell: panel.cell
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: QfTheme.darkTheme ? "#505050" : "#e0e0e0" }

      /* ---------------- dessin (selon l'objet en cours) ---------------- */
      TopoDrawOptions { Layout.fillWidth: true; engine: panel.engine; station: panel.station }

      /* ---------------- mesure ---------------- */
      TopoMeasureBox { Layout.fillWidth: true; engine: panel.engine; station: panel.station; devices: panel.devices }

      /* ---------------- objets actifs ---------------- */
      TopoActiveObjects { Layout.fillWidth: true; engine: panel.engine }
    }
  }
}
