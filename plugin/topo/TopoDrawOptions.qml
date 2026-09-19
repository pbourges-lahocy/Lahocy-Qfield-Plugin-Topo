import QtQuick
import QtQuick.Layouts
import org.qfield.gui

/*
 * TopoDrawOptions - primitives de dessin et réglages de l'objet en cours
 * (varient selon la famille), détection en attente, guidage d'implantation.
 * La consigne et la confirmation des clics sont dans la barre du bas.
 */
ColumnLayout {
  id: opts

  required property var engine
  required property var station
  spacing: 4
  visible: opts.fam !== "" || engine.detection !== null || engine.implantation.actif

  readonly property string fam: engine.currentFamily
  readonly property real b: 44

  /* ---------------- objet en cours ---------------- */
  Text {
    Layout.fillWidth: true
    visible: opts.fam !== ""
    text: (engine.currentObj ? engine.currentObj.nom : "") + (opts.fam === "lineaire"
      ? ("  ·  " + engine.currentVertexCount + " sommet" + (engine.currentVertexCount > 1 ? "s" : "") + ", " + engine.currentLength.toFixed(2) + " m")
      : ("  ·  point " + (engine.pendingCount + 1) + " / " + engine.pendingNeeded))
    font.pixelSize: 11; font.bold: true
    color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"
    elide: Text.ElideRight
  }
  Text {
    Layout.fillWidth: true
    visible: opts.fam === "texte"
    text: "« " + engine.pendingText + " »"
    font.pixelSize: 11; color: QfTheme.darkTheme ? "#f0f0f0" : "#202020"
    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
  }

  /* ---------------- linéaire ---------------- */
  Flow {
    Layout.fillWidth: true
    visible: opts.fam === "lineaire"
    spacing: 3
    TopoBtn { width: opts.b; height: opts.b; ui: "ligne"; text: "ligne"; fontSize: 7; checked: engine.currentMode === "ligne"; onClicked: engine.setMode("ligne") }
    TopoBtn { width: opts.b; height: opts.b; ui: "arc3"; text: "arc 3 pts"; fontSize: 7; checked: engine.currentMode === "arc3"; onClicked: engine.setMode("arc3") }
    TopoBtn { width: opts.b; height: opts.b; ui: "arc2"; text: "arc 2 pts"; fontSize: 7; checked: engine.currentMode === "arc2"; enabled: engine.currentTangent; onClicked: engine.setMode("arc2") }
    TopoBtn { width: opts.b; height: opts.b; ui: "courbe"; text: "courbe"; fontSize: 7; checked: engine.currentMode === "courbe"; onClicked: engine.setMode("courbe") }
    TopoBtn { width: opts.b; height: opts.b; ui: "tangent"; text: engine.currentTangent ? "tangent" : "fixe"; fontSize: 7; checked: engine.currentTangent; onClicked: engine.toggleTangent() }
    TopoBtn { width: opts.b; height: opts.b; ui: "fermer"; text: "fermer"; fontSize: 7; enabled: engine.currentVertexCount >= 3; onClicked: engine.closeCurrent() }
    TopoBtn { width: opts.b; height: opts.b; ui: "hachure"; text: "hachure"; fontSize: 7; checked: engine.currentHachure; onClicked: engine.toggleHachure() }
    TopoBtn { width: opts.b; height: opts.b; ui: "ajust_deb"; text: "ajust. déb."; fontSize: 7; checked: engine.currentAjustDeb; onClicked: engine.toggleAjustDeb() }
    TopoBtn { width: opts.b; height: opts.b; ui: "ajust_fin"; text: "ajust. fin"; fontSize: 7; checked: engine.currentAjustFin; onClicked: engine.toggleAjustFin() }
  }

  /* ---------------- symbole / texte / entrée / escalier ---------------- */
  Flow {
    Layout.fillWidth: true
    visible: ["symbole", "texte", "entree", "escalier"].indexOf(opts.fam) >= 0
    spacing: 3
    // nombre de points de pose du symbole (valeur du carnet par défaut)
    TopoBtn { visible: opts.fam === "symbole"; width: opts.b; height: opts.b; ui: "point_unique"; text: "1 point"; fontSize: 7; checked: engine.pendingNeeded === 1; onClicked: engine.setSymbolePoints(1) }
    TopoBtn { visible: opts.fam === "symbole"; width: opts.b; height: opts.b; ui: "ligne"; text: "2 points"; fontSize: 7; checked: engine.pendingNeeded === 2; onClicked: engine.setSymbolePoints(2) }
    TopoBtn { visible: opts.fam === "symbole"; width: opts.b; height: opts.b; ui: "rect3"; text: "3 points"; fontSize: 7; checked: engine.pendingNeeded === 3; onClicked: engine.setSymbolePoints(3) }
    TopoBtn { visible: opts.fam === "texte"; width: opts.b; height: opts.b; ui: "modifier"; text: "modifier"; fontSize: 7; onClicked: engine.requestDialog("texte", { "obj": engine.currentObj, "liste": [], "defaut": engine.pendingText }) }
    TopoBtn { visible: opts.fam === "symbole"; width: opts.b; height: opts.b; ui: "symetrie"; text: "symétrie"; fontSize: 7; enabled: engine.lastPlaced !== null; onClicked: engine.adjustSymetrie() }
    TopoBtn { visible: opts.fam !== "texte"; width: opts.b; height: opts.b; ui: "inverser"; text: "inverser"; fontSize: 7; enabled: engine.lastPlaced !== null; onClicked: engine.adjustInverser() }
    TopoBtn { visible: opts.fam === "symbole"; width: opts.b; height: opts.b; ui: "decaler"; text: "décaler"; fontSize: 7; enabled: engine.lastPlaced !== null; onClicked: engine.requestDialog("decalage", {}) }
  }

  /* ---------------- rectangle / cercle ---------------- */
  Flow {
    Layout.fillWidth: true
    visible: opts.fam === "rectangle" || opts.fam === "cercle"
    spacing: 3
    TopoBtn { visible: opts.fam === "rectangle"; width: opts.b; height: opts.b; ui: "rect2"; text: "2 points"; fontSize: 7; checked: engine.rectanglePoints === 2; onClicked: engine.setRectanglePoints(2) }
    TopoBtn { visible: opts.fam === "rectangle"; width: opts.b; height: opts.b; ui: "rect3"; text: "3 points"; fontSize: 7; checked: engine.rectanglePoints === 3; onClicked: engine.setRectanglePoints(3) }
    TopoBtn { visible: opts.fam === "cercle"; width: opts.b; height: opts.b; ui: "cercle"; text: "centre + R"; fontSize: 7; checked: engine.pendingNeeded < 3; onClicked: engine.setCercle3Points(false) }
    TopoBtn { visible: opts.fam === "cercle"; width: opts.b; height: opts.b; ui: "cercle3"; text: "3 points"; fontSize: 7; checked: engine.pendingNeeded === 3; onClicked: engine.setCercle3Points(true) }
    TopoBtn { visible: opts.fam === "cercle"; width: opts.b + 16; height: opts.b; ui: engine.rayonVerrouille ? "verrou" : "deverrouille"; text: "R = " + engine.rayonCercle.toFixed(2); fontSize: 7; checked: engine.rayonVerrouille; onClicked: engine.requestDialog("rayon", {}) }
  }

  /* ---------------- détection ---------------- */
  RowLayout {
    Layout.fillWidth: true
    visible: engine.detection !== null
    Text { Layout.fillWidth: true; text: "Détection : profondeur " + (engine.detection ? Number(engine.detection.profondeur).toFixed(2) : "") + " m"; font.pixelSize: 11; color: "#b35c00"; font.bold: true; wrapMode: Text.WordWrap }
    TopoBtn { width: 36; height: 32; ui: "refuser"; small: true; onClicked: engine.detection = null }
  }

  /* ---------------- guidage d'implantation ---------------- */
  TopoGuidage {
    Layout.fillWidth: true
    visible: engine.implantation.actif
    engine: opts.engine
    station: opts.station
  }
}
