import QtQuick
import org.qfield.core
import org.qgis
import "TopoCore.js" as Core

/*
 * TopoData - accès aux couches du GeoPackage Topo (création / mise à jour /
 * suppression d'entités, paramètres persistants, reprojection).
 *
 * Convention : toutes les coordonnées manipulées par le plugin sont dans le
 * "CRS de travail" = CRS de la couche pt_topo. Les positions GNSS et les clics
 * carte (CRS de la carte) sont convertis via mapToWork() / workToMap().
 */
Item {
  id: store

  property var project: qgisProject
  property var mapSettings: null
  property string operateur: ""

  // Couches connues (rôle -> nom de couche dans le projet)
  readonly property var roles: ({
      "pt_topo": "pt_topo", "lineaire": "lineaire", "surface": "surface", "symbole": "symbole",
      "texte": "texte", "entree": "entree", "talus": "talus", "implantation": "implantation", "topo_param": "topo_param"
    })
  readonly property var primitiveLayers: ["lineaire", "surface", "symbole", "texte", "entree", "talus"]

  QfFeatureModel {
    id: fm
    project: store.project
  }

  function getLayer(role) {
    if (!project) return null;
    const list = project.mapLayersByName(roles[role] || role);
    return list.length > 0 ? list[0] : null;
  }

  function hasLayers() {
    return getLayer("pt_topo") !== null && getLayer("lineaire") !== null && getLayer("topo_param") !== null;
  }

  function workCrs() {
    const l = getLayer("pt_topo");
    return l ? l.crs : (mapSettings ? mapSettings.destinationCrs : null);
  }

  function sameCrs() {
    if (!mapSettings) return true;
    const w = workCrs();
    return !w || w.authid === mapSettings.destinationCrs.authid;
  }

  // QgsPoint (CRS carte) -> {x, y, z} (CRS de travail)
  function mapToWork(qgsPt) {
    if (sameCrs()) return Core.pt(qgsPt.x, qgsPt.y, qgsPt.z);
    const p = QfGeometryUtils.reprojectPoint(qgsPt, mapSettings.destinationCrs, workCrs());
    return Core.pt(p.x, p.y, qgsPt.z);
  }

  // {x, y, z} (CRS de travail) -> QgsPoint (CRS carte)
  function workToMap(p) {
    const q = QfGeometryUtils.point(p.x, p.y, Core.isNum(p.z) ? p.z : 0);
    if (sameCrs()) return q;
    return QfGeometryUtils.reprojectPoint(q, workCrs(), mapSettings.destinationCrs);
  }

  function geometryFromWkt(wkt, lyr) {
    let geom = QfGeometryUtils.createGeometryFromWkt(wkt);
    const w = workCrs();
    if (lyr && w && lyr.crs.authid !== w.authid) {
      geom = QfGeometryUtils.reprojectGeometry(geom, w, lyr.crs);
    }
    return geom;
  }

  function v(value) {
    // NaN / undefined -> NULL
    if (value === undefined) return null;
    if (typeof value === "number" && isNaN(value)) return null;
    return value;
  }

  function attr(feature, name) {
    if (!feature) return null;
    const a = feature.attribute(name);
    if (a === undefined || a === null) return null;
    return a;
  }

  function num(feature, name) {
    const a = attr(feature, name);
    if (a === null || a === "") return NaN;
    const n = Number(a);
    return isNaN(n) ? NaN : n;
  }

  function str(feature, name) {
    const a = attr(feature, name);
    return a === null ? "" : String(a);
  }

  /** Crée une entité ; renvoie son id (ou -1). wkt peut être vide (table). */
  function createFeature(role, wkt, attrs) {
    const lyr = getLayer(role);
    if (!lyr) { console.warn("Topo: couche absente " + role); return -1; }
    const geom = wkt ? geometryFromWkt(wkt, lyr) : QfGeometryUtils.createGeometryFromWkt("");
    let f = QfFeatureUtils.createFeature(lyr, geom);
    for (const k in attrs) f.setAttribute(k, v(attrs[k]));
    fm.currentLayer = lyr;
    fm.feature = f;
    if (!fm.create()) { console.warn("Topo: création impossible dans " + role); return -1; }
    return fm.feature.id;
  }

  /** Met à jour attributs (et géométrie si wkt non vide) d'une entité existante. */
  function updateFeature(role, fid, wkt, attrs) {
    const lyr = getLayer(role);
    if (!lyr) return false;
    let f = getFeature(role, fid);
    if (!f) { console.warn("Topo: entité " + fid + " introuvable dans " + role); return false; }
    for (const k in attrs) f.setAttribute(k, v(attrs[k]));
    fm.currentLayer = lyr;
    fm.feature = f;
    if (wkt) fm.changeGeometry(geometryFromWkt(wkt, lyr));
    return fm.save();
  }

  function deleteFeature(role, fid) {
    const lyr = getLayer(role);
    if (!lyr) return false;
    return QfLayerUtils.deleteFeature(project, lyr, fid, true);
  }

  function getFeature(role, fid) {
    const list = features(role, "$id = " + fid);
    return list.length > 0 ? list[0] : null;
  }

  /** Liste d'entités (QgsFeature) répondant à une expression QGIS. */
  function features(role, expression) {
    const lyr = getLayer(role);
    let out = [];
    if (!lyr) return out;
    let it = expression ? QfLayerUtils.createFeatureIteratorFromExpression(lyr, expression) : QfLayerUtils.createFeatureIterator(lyr);
    while (it.hasNext()) out.push(it.next());
    it.close();
    return out;
  }

  /** Entités dont la boîte englobante intersecte le rectangle (coordonnées de la couche). */
  function featuresInRect(role, p1, p2) {
    const lyr = getLayer(role);
    let out = [];
    if (!lyr) return out;
    const rect = QfGeometryUtils.createRectangleFromPoints(QfGeometryUtils.point(p1.x, p1.y), QfGeometryUtils.point(p2.x, p2.y));
    let it = QfLayerUtils.createFeatureIteratorFromRectangle(lyr, rect);
    while (it.hasNext()) out.push(it.next());
    it.close();
    return out;
  }

  /* ---------------- paramètres persistants (table topo_param) ---------------- */

  function getParam(cle, def) {
    const list = features("topo_param", "\"cle\" = '" + cle + "'");
    if (list.length === 0) return def;
    const val = str(list[0], "valeur");
    return val === "" ? def : val;
  }

  function setParam(cle, valeur) {
    const list = features("topo_param", "\"cle\" = '" + cle + "'");
    if (list.length === 0) return createFeature("topo_param", "", { "cle": cle, "valeur": String(valeur) }) >= 0;
    return updateFeature("topo_param", list[0].id, "", { "valeur": String(valeur) });
  }

  function getJsonParam(cle, def) {
    const s = getParam(cle, "");
    if (!s) return def;
    try { return JSON.parse(s); } catch (e) { return def; }
  }

  /** Renvoie le prochain matricule et incrémente le compteur. */
  function takeMatricule() {
    let m = getParam("matricule_prochain", "1000");
    // éviter les doublons avec des points déjà présents
    let guard = 0;
    while (features("pt_topo", "\"matricule\" = '" + m + "'").length > 0 && guard < 10000) { m = Core.nextMatricule(m); guard++; }
    setParam("matricule_prochain", Core.nextMatricule(m));
    return m;
  }

  /* ---------------- points topo ---------------- */

  function pointFromFeature(f) {
    if (!f) return null;
    return {
      "fid": f.id, "matricule": str(f, "matricule"), "type": str(f, "type"),
      "x": num(f, "x"), "y": num(f, "y"), "z": num(f, "z"), "hv": num(f, "hv"),
      "z_signif": num(f, "z_signif") === 1, "horodatage": str(f, "horodatage"),
      "pt_appui": str(f, "pt_appui"), "pt_ref": str(f, "pt_ref"), "code_objet": str(f, "code_objet")
    };
  }

  function pointByMatricule(m) {
    const list = features("pt_topo", "\"matricule\" = '" + m + "'");
    return list.length ? pointFromFeature(list[0]) : null;
  }

  function lastPointTopo() {
    // dernier point créé = plus grand id
    const lyr = getLayer("pt_topo");
    if (!lyr) return null;
    let best = null;
    let it = QfLayerUtils.createFeatureIterator(lyr);
    while (it.hasNext()) { const f = it.next(); if (!best || f.id > best.id) best = f; }
    it.close();
    return pointFromFeature(best);
  }

  /** Point topo le plus proche d'un point (CRS de travail) dans un rayon donné. */
  function nearestPointTopo(p, radius) {
    const list = featuresInRect("pt_topo", Core.pt(p.x - radius, p.y - radius), Core.pt(p.x + radius, p.y + radius));
    let best = null, bestD = radius;
    for (const f of list) {
      const q = pointFromFeature(f);
      const d = Core.dist2d(p, q);
      if (d <= bestD) { best = q; bestD = d; }
    }
    return best;
  }
}
