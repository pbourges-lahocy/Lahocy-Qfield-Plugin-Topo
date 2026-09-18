import QtQuick
import QtQuick.Layouts
import org.qfield.gui
import "TopoCore.js" as Core

/*
 * TopoGuidage - assistant de navigation pour l'implantation de points :
 * cible bleue, position orange, écarts, flèches, cercle de tolérance.
 */
ColumnLayout {
  id: guidage

  required property var engine
  required property var station
  spacing: 4

  property var deltas: null
  property real heading: 0   // degrés depuis le nord, sens horaire
  readonly property var cible: engine.implantation.actif ? engine.implantation.liste[engine.implantation.index] : null
  readonly property bool inTol: deltas !== null && deltas.dist <= engine.tolImplantation

  Timer {
    interval: 400
    repeat: true
    running: engine.implantation.actif
    triggeredOnStart: true
    onTriggered: guidage.update()
  }

  function update() {
    if (!engine.implantation.actif) { deltas = null; return; }
    if (engine.mesureSource === "tps") {
      const pos = station.prismPosition();
      const c = cible;
      if (!pos || !c) { deltas = null; canvas.requestPaint(); return; }
      const dx = c.x - pos.x, dy = c.y - pos.y;
      deltas = { "dx": dx, "dy": dy, "dz": (Core.isNum(c.z) && Core.isNum(pos.z)) ? c.z - pos.z : NaN, "dist": Math.sqrt(dx * dx + dy * dy), "pos": pos, "cible": c };
      heading = 0;
    } else {
      deltas = engine.implantationDeltas();
      const info = engine.positionSource ? engine.positionSource.positionInformation : null;
      heading = (info && info.directionValid) ? info.direction : 0;
    }
    canvas.requestPaint();
  }

  // composantes avant / droite par rapport au cap
  readonly property real avant: deltas ? (deltas.dx * Math.sin(heading * Math.PI / 180) + deltas.dy * Math.cos(heading * Math.PI / 180)) : 0
  readonly property real droite: deltas ? (deltas.dx * Math.cos(heading * Math.PI / 180) - deltas.dy * Math.sin(heading * Math.PI / 180)) : 0

  Text {
    Layout.fillWidth: true
    text: cible ? ("Implantation de " + cible.matricule + "  (" + (engine.implantation.index + 1) + "/" + engine.implantation.liste.length + ")") : ""
    font.bold: true; font.pixelSize: 12; color: QfTheme.mainTextColor
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 6
    Canvas {
      id: canvas
      Layout.preferredWidth: 150; Layout.preferredHeight: 150
      onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2, cy = height / 2;
        const d = guidage.deltas;
        // échelle : le cercle extérieur = max(1 m, 2 x distance)
        const scale = d ? Math.max(1.0, d.dist * 2) : 1.0;
        const px = (width / 2 - 10) / scale;
        ctx.fillStyle = guidage.inTol ? "#b9f0b9" : "#f4f4f4";
        ctx.strokeStyle = guidage.inTol ? "#1e9e3a" : "#909090";
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(cx, cy, width / 2 - 8, 0, 2 * Math.PI); ctx.fill(); ctx.stroke();
        // cercle de tolérance
        ctx.strokeStyle = "#1e9e3a"; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(cx, cy, Math.max(4, engine.tolImplantation * px), 0, 2 * Math.PI); ctx.stroke();
        // axes (cap vers le haut)
        ctx.strokeStyle = "#2d98da"; ctx.beginPath(); ctx.moveTo(cx, 6); ctx.lineTo(cx, height - 6); ctx.stroke();
        ctx.strokeStyle = "#ff8c00"; ctx.beginPath(); ctx.moveTo(6, cy); ctx.lineTo(width - 6, cy); ctx.stroke();
        // position courante (orange) au centre, cible (bleue) décalée
        if (d) {
          const tx = cx + guidage.droite * px, ty = cy - guidage.avant * px;
          ctx.strokeStyle = "#1f5fbf"; ctx.lineWidth = 2;
          ctx.beginPath(); ctx.arc(tx, ty, 9, 0, 2 * Math.PI); ctx.stroke();
          ctx.beginPath(); ctx.moveTo(tx - 12, ty - 12); ctx.lineTo(tx + 12, ty + 12); ctx.moveTo(tx + 12, ty - 12); ctx.lineTo(tx - 12, ty + 12); ctx.stroke();
          ctx.setLineDash([4, 3]); ctx.strokeStyle = "#606060"; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(tx, ty); ctx.stroke(); ctx.setLineDash([]);
        }
        ctx.fillStyle = "#ff8c00"; ctx.beginPath(); ctx.arc(cx, cy, 7, 0, 2 * Math.PI); ctx.fill();
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2
      Text { text: deltas ? ((guidage.avant >= 0 ? "▲ Avancer " : "▼ Reculer ") + Math.abs(guidage.avant).toFixed(3) + " m") : "Position inconnue"; font.pixelSize: 13; font.bold: true; color: QfTheme.mainTextColor }
      Text { text: deltas ? ((guidage.droite >= 0 ? "▶ Droite " : "◀ Gauche ") + Math.abs(guidage.droite).toFixed(3) + " m") : ""; font.pixelSize: 13; font.bold: true; color: QfTheme.mainTextColor }
      Text { text: deltas ? ("Distance " + deltas.dist.toFixed(3) + " m") : ""; font.pixelSize: 11; color: QfTheme.mainTextColor }
      Text { text: deltas && Core.isNum(deltas.dz) ? ("ΔZ " + (deltas.dz >= 0 ? "+" : "") + deltas.dz.toFixed(3) + " m (" + (deltas.dz >= 0 ? "remblai" : "déblai") + ")") : ""; font.pixelSize: 11; color: QfTheme.mainTextColor }
      Text { text: deltas ? ("dX " + deltas.dx.toFixed(3) + "  dY " + deltas.dy.toFixed(3)) : ""; font.pixelSize: 10; color: QfTheme.secondaryTextColor }
      Text { text: "Tolérance " + (engine.tolImplantation * 100).toFixed(1) + " cm" + (engine.mesureSource === "tps" ? " – suivi prisme" : (heading ? " – cap " + heading.toFixed(0) + "°" : "")); font.pixelSize: 10; color: QfTheme.secondaryTextColor }
    }
  }

  Flow {
    Layout.fillWidth: true
    spacing: 4
    TopoBtn { width: 92; height: 46; text: "Implanter"; emoji: "💾"; fontSize: 9; baseColor: guidage.inTol ? "#8fe08f" : "#ffb347"; enabled: deltas !== null; onClicked: engine.implanter(false) }
    TopoBtn { width: 92; height: 46; text: "Implanter\nZ en attente"; emoji: "💾"; fontSize: 8; enabled: deltas !== null; onClicked: engine.implanter(true) }
    TopoBtn { width: 46; height: 46; emoji: "◀"; text: "Préc."; fontSize: 8; onClicked: engine.implantationNext(-1) }
    TopoBtn { width: 46; height: 46; emoji: "▶"; text: "Suiv."; fontSize: 8; onClicked: engine.implantationNext(1) }
    TopoBtn { width: 46; height: 46; emoji: "🔍"; text: "Zoom"; fontSize: 8; onClicked: if (cible) engine.zoomToPoints([cible]) }
    TopoBtn { width: 92; height: 46; emoji: "⛔"; text: "Retour au\ngestionnaire"; fontSize: 8; baseColor: "#ffd6d6"; onClicked: engine.implantationStop() }
  }
}
