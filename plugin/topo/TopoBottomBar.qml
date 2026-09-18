import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoBottomBar - barre du bas : consigne en cours, confirmation des clics en
 * mode terrain, actions de contexte (annuler, continuer, attente, supprimer,
 * relance du plan, où suis-je, zoom total) et dernier point mesuré.
 */
Popup {
  id: bar

  required property var engine
  required property var station
  required property var devices
  required property var mainWindow
  property real reserve: 0

  readonly property bool droitier: engine.droitier
  readonly property real safeBottom: mainWindow.sceneBottomMargin !== undefined ? mainWindow.sceneBottomMargin : 0
  readonly property real safeRight: mainWindow.sceneRightMargin !== undefined ? mainWindow.sceneRightMargin : 0
  readonly property real safeLeft: mainWindow.sceneLeftMargin !== undefined ? mainWindow.sceneLeftMargin : 0
  readonly property bool wide: width > 820
  readonly property bool hasCandidate: engine.clickCandidate !== null

  // collée au bord bas et à l'angle opposé au panneau
  parent: mainWindow.contentItem
  x: droitier ? safeLeft : safeLeft + reserve
  y: parent.height - safeBottom - height
  width: parent.width - safeLeft - safeRight - reserve
  height: 52
  padding: 4
  modal: false
  dim: false
  closePolicy: Popup.NoAutoClose

  background: Rectangle {
    color: QfTheme.darkTheme ? "#1f1f1f" : "#ffffff"
    border.color: bar.hasCandidate ? QfTheme.mainColor : (QfTheme.darkTheme ? "#505050" : "#d4d4d4")
    border.width: bar.hasCandidate ? 2 : 1
    opacity: 0.96
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

  function fmtPoint(p) {
    if (!p) return "";
    return p.matricule + "   " + Number(p.x).toFixed(2) + "  " + Number(p.y).toFixed(2) + "  " + Number(p.z).toFixed(2);
  }

  contentItem: RowLayout {
    spacing: 6

    Image {
      source: Qt.resolvedUrl("../theme/ui/") + (bar.hasCandidate ? "alerte" : "info") + (QfTheme.darkTheme ? "_w" : "") + ".svg"
      width: 18; height: 18; sourceSize.width: 36; sourceSize.height: 36
      Layout.leftMargin: 4
    }
    Text {
      Layout.fillWidth: true
      text: bar.hasCandidate ? engine.clickCandidate.descr : (engine.message + (engine.mesureSource === "tps" && station.message !== "" ? "   ·   " + station.message : ""))
      font.pixelSize: 12
      font.bold: bar.hasCandidate
      color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }

    // confirmation de clic (mode terrain)
    TopoBtn { visible: bar.hasCandidate; width: 56; height: 42; ui: "valider"; baseColor: "#d9f2d9"; onClicked: engine.validateCandidate() }
    TopoBtn { visible: bar.hasCandidate; width: 56; height: 42; ui: "refuser"; baseColor: "#ffd0d0"; onClicked: engine.cancelCandidate() }

    // actions de contexte
    TopoBtn { visible: !bar.hasCandidate && (engine.currentVertexCount > 0 || engine.pendingCount > 0); width: 46; height: 42; ui: "annuler"; text: "annuler"; fontSize: 8; onClicked: engine.undoVertex() }
    TopoBtn { visible: !bar.hasCandidate; width: 46; height: 42; ui: "continuer"; text: "continuer"; fontSize: 8; checked: engine.clickMode === "continuer"; onClicked: engine.setClickMode(engine.clickMode === "continuer" ? "" : "continuer") }
    TopoBtn {
      visible: !bar.hasCandidate; width: 46; height: 42; ui: "attente"; text: "attente"; fontSize: 8
      baseColor: engine.hasWaiting ? "#ffe2b8" : (QfTheme.darkTheme ? "#3a3a3a" : "#f2f2f2")
      onClicked: engine.wait()
      onPressAndHold: engine.requestDialog("attente", { "items": engine.waitingList() })
    }
    TopoBtn { visible: !bar.hasCandidate; width: 46; height: 42; ui: "supprimer"; text: "supprimer"; fontSize: 8; checked: engine.clickMode === "supprimer"; onClicked: engine.setClickMode(engine.clickMode === "supprimer" ? "" : "supprimer") }
    TopoBtn { visible: !bar.hasCandidate; width: 46; height: 42; ui: "relance"; text: "relance"; fontSize: 8; checked: engine.clickMode === "relance"; onClicked: engine.setClickMode(engine.clickMode === "relance" ? "" : "relance") }
    TopoBtn { visible: !bar.hasCandidate; width: 46; height: 42; ui: "position"; text: "où suis-je"; fontSize: 8; onClicked: bar.ouSuisJe() }
    TopoBtn { visible: !bar.hasCandidate; width: 46; height: 42; ui: "zoom_total"; text: "zoom"; fontSize: 8; onClicked: { const l = engine.db.getLayer("pt_topo"); if (l) engine.mapCanvas.mapSettings.setCenterToLayer(l, true); } }

    Rectangle {
      visible: bar.wide && engine.lastPoint !== null && !bar.hasCandidate
      implicitWidth: lastTxt.implicitWidth + 16
      implicitHeight: 34
      radius: 8
      color: QfTheme.darkTheme ? "#3a3a3a" : "#ececec"
      Text { id: lastTxt; anchors.centerIn: parent; text: bar.fmtPoint(engine.lastPoint); font.family: "monospace"; font.pixelSize: 11; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020" }
      MouseArea { anchors.fill: parent; onClicked: engine.useLastPoint() }
    }
  }
}
