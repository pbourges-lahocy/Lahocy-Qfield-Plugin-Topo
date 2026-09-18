import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoPanel - panneau latéral du plugin : ruban (haut), zone 3 palette,
 * zone 4 mesure et dessin, zone 5 objets actifs. Ancré à droite (droitier)
 * ou à gauche (gaucher).
 *
 * Implémenté en Popup non modal (closePolicy: NoAutoClose) et non en Item
 * reparenté : sur les tablettes Android testées avec le POC, seuls les
 * éléments gérés par l'Overlay de QtQuick Controls (Dialog / Popup) se
 * repeignent de façon fiable. Positionné dans la zone sûre du système
 * (mainWindow.sceneTopMargin / sceneBottomMargin / sceneRightMargin).
 */
Popup {
  id: panel

  required property var engine
  required property var station
  required property var devices
  required property var mainWindow
  property bool collapsed: false

  signal openCarnet()
  signal openImplantation()
  signal openStationMenu()
  signal openSettings()
  signal openDetection()

  readonly property bool droitier: engine.droitier
  readonly property real safeTop: mainWindow.sceneTopMargin !== undefined ? mainWindow.sceneTopMargin : 0
  readonly property real safeBottom: mainWindow.sceneBottomMargin !== undefined ? mainWindow.sceneBottomMargin : 0
  readonly property real safeRight: mainWindow.sceneRightMargin !== undefined ? mainWindow.sceneRightMargin : 0
  readonly property real safeLeft: mainWindow.sceneLeftMargin !== undefined ? mainWindow.sceneLeftMargin : 0
  readonly property real measureWidth: Math.min(290, Math.max(220, mainWindow.width * 0.22))
  readonly property real fullWidth: paletteZone.width + measureWidth + activeZone.width + 48

  parent: mainWindow.contentItem
  x: droitier ? parent.width - width - safeRight : safeLeft
  y: safeTop
  width: collapsed ? 40 : Math.min(fullWidth, parent.width - safeLeft - safeRight)
  height: parent.height - safeTop - safeBottom
  padding: 0
  modal: false
  dim: false
  closePolicy: Popup.NoAutoClose

  background: Rectangle {
    color: QfTheme.darkTheme ? "#1f1f1f" : "#fafafa"
    border.color: QfTheme.mainColor
    border.width: 1
    opacity: 0.97
  }

  contentItem: Item {
    // bouton de repli
    TopoBtn {
      id: collapseBtn
      width: 32; height: 60
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: panel.droitier ? undefined : parent.right
      anchors.left: panel.droitier ? parent.left : undefined
      anchors.margins: 2
      emoji: panel.collapsed ? (panel.droitier ? "◀" : "▶") : (panel.droitier ? "▶" : "◀")
      z: 5
      onClicked: panel.collapsed = !panel.collapsed
    }

    ColumnLayout {
      id: content
      visible: !panel.collapsed
      anchors.fill: parent
      anchors.leftMargin: panel.droitier ? 36 : 4
      anchors.rightMargin: panel.droitier ? 4 : 36
      anchors.topMargin: 4
      anchors.bottomMargin: 4
      spacing: 4

      /* ---------------- ruban ---------------- */
      Flow {
        Layout.fillWidth: true
        spacing: 3
        TopoBtn { width: 52; height: 44; emoji: "↪"; text: "Continuer"; fontSize: 8; checked: engine.clickMode === "continuer"; onClicked: engine.setClickMode(engine.clickMode === "continuer" ? "" : "continuer") }
        TopoBtn { width: 52; height: 44; emoji: "🗑"; text: "Supprimer"; fontSize: 8; checked: engine.clickMode === "supprimer"; onClicked: engine.setClickMode(engine.clickMode === "supprimer" ? "" : "supprimer") }
        TopoBtn { width: 52; height: 44; emoji: "⟳"; text: "Relance\nplan"; fontSize: 8; checked: engine.clickMode === "relance"; onClicked: engine.setClickMode(engine.clickMode === "relance" ? "" : "relance") }
        TopoBtn { width: 52; height: 44; emoji: "👀"; text: "Où\nsuis-je"; fontSize: 8; onClicked: panel.ouSuisJe() }
        TopoBtn { width: 52; height: 44; emoji: "⤢"; text: "Zoom\ntotal"; fontSize: 8; onClicked: { const l = engine.db.getLayer("pt_topo"); if (l) engine.mapCanvas.mapSettings.setCenterToLayer(l, true); } }
        TopoBtn { width: 52; height: 44; emoji: "📒"; text: "Carnet"; fontSize: 8; onClicked: panel.openCarnet() }
        TopoBtn { width: 52; height: 44; emoji: "🎯"; text: "Implan-\ntation"; fontSize: 8; checked: engine.implantation.actif; onClicked: panel.openImplantation() }
        TopoBtn { width: 52; height: 44; emoji: "△"; text: "Menu\nstation"; fontSize: 8; baseColor: devices.tpsConnected ? "#d9f2d9" : (QfTheme.darkTheme ? "#3a3a3a" : "#e6e6e6"); onClicked: panel.openStationMenu() }
        TopoBtn { width: 52; height: 44; emoji: "📡"; text: "Détec-\nteur"; fontSize: 8; baseColor: engine.detection ? "#ffb347" : (QfTheme.darkTheme ? "#3a3a3a" : "#e6e6e6"); onClicked: panel.openDetection() }
        TopoBtn { width: 52; height: 44; emoji: "⚙"; text: "Param."; fontSize: 8; onClicked: panel.openSettings() }
        TopoBtn { width: 52; height: 44; emoji: engine.modeBureau ? "🖱" : "☝"; text: engine.modeBureau ? "Bureau" : "Terrain"; fontSize: 8; onClicked: { engine.modeBureau = !engine.modeBureau; engine.saveSettings(); } }
      }

      /* ---------------- zones 3 / 4 / 5 ---------------- */
      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 4
        layoutDirection: panel.droitier ? Qt.LeftToRight : Qt.RightToLeft

        TopoPalette {
          id: paletteZone
          Layout.fillHeight: true
          engine: panel.engine
          onLeft: !panel.droitier
        }

        Flickable {
          Layout.preferredWidth: panel.measureWidth
          Layout.fillHeight: true
          contentHeight: measureCol.implicitHeight + 8
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ColumnLayout {
            id: measureCol
            width: parent.width
            spacing: 6
            TopoMeasureBox { Layout.fillWidth: true; engine: panel.engine; station: panel.station; devices: panel.devices }
            Rectangle { Layout.fillWidth: true; height: 1; color: QfTheme.darkTheme ? "#555" : "#c8c8c8" }
            TopoDrawOptions { Layout.fillWidth: true; engine: panel.engine; station: panel.station }
          }
        }

        TopoActiveObjects {
          id: activeZone
          Layout.fillHeight: true
          engine: panel.engine
        }
      }
    }
  }

  function ouSuisJe() {
    if (engine.mesureSource === "tps") {
      const p = station.prismPosition();
      if (p) { engine.mapCanvas.mapSettings.setCenter(engine.db.workToMap(p)); return; }
      if (station.active) { engine.mapCanvas.mapSettings.setCenter(engine.db.workToMap(station.current)); return; }
    }
    const ps = engine.positionSource;
    if (ps && ps.active && ps.positionInformation.latitudeValid) engine.mapCanvas.mapSettings.setCenter(ps.projectedPosition);
    else engine.toast("Pas de position");
  }
}
