import QtQuick
import org.qfield.core
import org.qgis
import "TopoCore.js" as Core

/*
 * TopoEngine - logique métier du plugin (cycle de placement du logiciel de référence) :
 * activation d'objets, mesures GNSS, excentrements, linéaires actifs multiples,
 * symboles / textes / entrées / escaliers, carnet, implantation, détection.
 *
 * L'interface (TopoPanel & co) ne fait que refléter les propriétés de l'engine.
 */
Item {
  id: engine

  required property var db            // TopoData
  required property var mainWindow
  required property var mapCanvas
  required property var positionSource

  property var theme: ({ "palette": [], "objets": {}, "listes_textes": {} })
  property bool ready: false
  property var station: null             // TopoStation (contexte station totale)
  property string mesureSource: "gnss"   // gnss | tps

  /* ---------------- réglages ---------------- */
  property bool droitier: true
  property bool modeBureau: false
  property real hauteurCanne: 2.0
  property var seuils: ({ "hrms": { "actif": true, "limite": 0.05 }, "vrms": { "actif": false, "limite": 0.10 },
                          "hdop": { "actif": false, "limite": 2.0 }, "pdop": { "actif": false, "limite": 3.0 },
                          "vdop": { "actif": false, "limite": 3.0 }, "nb_sat_min": 6, "fix_requis": 4, "tolerance_orange": 2.0 })
  property real tolImplantation: 0.05
  property var excentFavoris: ["point", "perp_prec", "perp_suiv", "vertical", "milieu", "deux_dist"]
  property bool zoomAuto: true
  property bool pointsAppuiVisibles: true

  /* ---------------- état exposé à l'UI ---------------- */
  property string message: ""            // consigne en tête de panneau
  property string courant: ""            // clé de l'objet linéaire courant
  property var activeList: []            // [{key, label, icone, current, orange}]
  property var currentObj: null          // objet du thème en cours (linéaire ou commande ponctuelle)
  property string currentFamily: ""      // lineaire | symbole | texte | entree | escalier | talus | surface | ""
  property string currentMode: "ligne"   // ligne | arc3 | arc2 | courbe | rectangle | cercle
  property bool currentTangent: true
  property bool currentClosed: false
  property bool currentHachure: false
  property bool currentAjustDeb: false
  property bool currentAjustFin: false
  property int currentVertexCount: 0
  property real currentLength: 0
  property int pendingNeeded: 0
  property int pendingCount: 0
  property string pendingText: ""
  property bool hasWaiting: false        // objets en attente en base
  property string lastObjectCode: ""
  property var lastPoint: null           // dernier point topo créé
  property string excentMode: ""         // "" | point | perp_prec | perp_suiv | vertical | milieu | deux_dist
  property string excentStep: ""
  property string clickMode: ""          // "" | continuer | supprimer | relance | ref_point | appui_point | talus_bas | talus_haut | impl_pick
  property var clickCandidate: null      // {mode, point, descr, feature, role}
  property var detection: null           // {profondeur, ...} en attente d'une mesure
  property bool detectionAuto: false
  property var lastPlaced: null          // {role, fid, kind} dernier objet ponctuel placé (pour ajustements)
  property var implantation: ({ "actif": false, "liste": [], "index": -1 })
  property real rayonCercle: 0
  property bool rayonVerrouille: false
  property int rectanglePoints: 3

  /* ---------------- qualité GNSS ---------------- */
  property string qualityState: "none"   // none | ok | warn | bad
  property string qualityText: "GNSS inactif"
  property string qualityDetail: ""

  signal toast(string msg)
  signal requestDialog(string kind, var payload)
  signal uiChanged()

  /* ================================================================== */
  /* Initialisation                                                     */
  /* ================================================================== */

  property var actifs: ({})
  property var actifsOrdre: []
  property var pending: null
  property var excent: ({})
  property var indices: ({})

  function init(themeJson) {
    theme = themeJson;
    db.mapSettings = mapCanvas.mapSettings;
    loadSettings();
    recoverActiveObjects();
    refreshWaiting();
    ready = true;
    setMessage("Prêt – choisir un objet dans la palette");
  }

  function loadSettings() {
    droitier = db.getParam("droitier", "1") === "1";
    modeBureau = db.getParam("mode_bureau", "0") === "1";
    hauteurCanne = parseFloat(db.getParam("hauteur_canne", "2.000")) || 2.0;
    seuils = db.getJsonParam("gnss_seuils", seuils);
    tolImplantation = parseFloat(db.getParam("tol_implantation", "0.05")) || 0.05;
    const fav = db.getParam("excentrements_favoris", "");
    if (fav) excentFavoris = fav.split(";").filter(s => s.length > 0);
    zoomAuto = db.getParam("zoom_auto", "1") === "1";
    if (positionSource) positionSource.antennaHeight = hauteurCanne;
  }

  function saveSettings() {
    db.setParam("droitier", droitier ? "1" : "0");
    db.setParam("mode_bureau", modeBureau ? "1" : "0");
    db.setParam("hauteur_canne", hauteurCanne.toFixed(3));
    db.setParam("gnss_seuils", JSON.stringify(seuils));
    db.setParam("tol_implantation", String(tolImplantation));
    db.setParam("excentrements_favoris", excentFavoris.join(";"));
    db.setParam("zoom_auto", zoomAuto ? "1" : "0");
  }

  function setHauteurCanne(h) {
    hauteurCanne = h;
    if (positionSource) positionSource.antennaHeight = h;
    db.setParam("hauteur_canne", h.toFixed(3));
  }

  property string themeBase: ""          // URL du dossier theme/ du plugin (fournie par main.qml)

  function objet(code) { return theme.objets ? theme.objets[code] : undefined; }
  function iconUrl(name) {
    if (!name) return "";
    return themeBase + "icons/" + name;
  }

  /** Bascule GNSS / station totale pour les boutons de mesure. */
  function setMesureSource(src) {
    mesureSource = src;
    db.setParam("mesure_source", src);
    setMessage(src === "tps" ? "Mesures à la station totale" : "Mesures au GNSS");
    refreshUi();
  }

  function setMessage(m) { message = m; }

  /* ================================================================== */
  /* Qualité GNSS                                                       */
  /* ================================================================== */

  Connections {
    target: engine.positionSource
    function onPositionInformationChanged() { engine.evalQuality(); }
    function onActiveChanged() { engine.evalQuality(); }
  }

  function evalQuality() {
    if (!positionSource || !positionSource.active) { qualityState = "none"; qualityText = "GNSS inactif"; qualityDetail = ""; return; }
    const info = positionSource.positionInformation;
    if (!info.latitudeValid || !info.longitudeValid) { qualityState = "none"; qualityText = "Pas de position"; qualityDetail = ""; return; }
    let bad = false, warn = false;
    let lines = [];
    const q = info.quality;
    const fixReq = seuils.fix_requis || 0;
    let fixOk = true;
    if (fixReq === 4) fixOk = (q === 4);
    else if (fixReq === 5) fixOk = (q === 4 || q === 5);
    else if (fixReq === 2) fixOk = (q >= 2);
    if (!fixOk) bad = true;
    lines.push("Qualité = " + Core.fixLabel(q));
    const tol = seuils.tolerance_orange || 1.0;
    function check(label, value, s, unit) {
      if (!s || !s.actif) return;
      if (!Core.isNum(value)) { warn = true; lines.push(label + " = ?"); return; }
      lines.push(label + " = " + Core.fmt(value, unit === "m" ? 3 : 1) + (unit ? " " + unit : ""));
      if (value > s.limite * tol) bad = true;
      else if (value > s.limite) warn = true;
    }
    check("HRMS", info.hacc, seuils.hrms, "m");
    check("VRMS", info.vacc, seuils.vrms, "m");
    check("HDOP", info.hdop, seuils.hdop, "");
    check("PDOP", info.pdop, seuils.pdop, "");
    check("VDOP", info.vdop, seuils.vdop, "");
    const nsat = info.satellitesUsed;
    lines.push(nsat + " satellites");
    if ((seuils.nb_sat_min || 0) > 0 && nsat > 0 && nsat < seuils.nb_sat_min) bad = true;
    qualityState = bad ? "bad" : (warn ? "warn" : "ok");
    qualityText = (seuils.hrms && seuils.hrms.actif && Core.isNum(info.hacc)) ? ("HRMS = " + Core.fmt(info.hacc, 3) + " m") : ("Qualité = " + Core.fixLabel(q));
    qualityDetail = lines.join("\n");
  }

  /* ================================================================== */
  /* Objets actifs (linéaires)                                          */
  /* ================================================================== */

  function refreshUi() {
    let list = [];
    for (const key of actifsOrdre) {
      const o = actifs[key];
      list.push({ "key": key, "label": o.label, "icone": iconUrl(o.obj.icone), "current": key === courant, "orange": !!o.perpSuivant });
    }
    activeList = list;
    const o = courant ? actifs[courant] : null;
    if (o) {
      currentObj = o.obj; currentFamily = "lineaire"; currentMode = o.mode; currentTangent = o.tangent;
      currentClosed = o.closed; currentHachure = o.hachure; currentAjustDeb = o.ajustDeb; currentAjustFin = o.ajustFin;
      currentVertexCount = o.vertices.length; currentLength = Core.length2d(Core.buildPolyline(o.vertices, o.closed));
      pendingNeeded = 0; pendingCount = 0;
    } else if (pending) {
      currentObj = pending.obj; currentFamily = pending.kind; currentMode = pending.mode || "";
      pendingNeeded = pending.needed; pendingCount = pending.points.length; currentVertexCount = 0; currentLength = 0;
    } else {
      currentObj = null; currentFamily = ""; currentVertexCount = 0; currentLength = 0; pendingNeeded = 0; pendingCount = 0;
    }
    uiChanged();
  }

  function nextIndice(code) {
    indices[code] = (indices[code] || 0) + 1;
    return indices[code];
  }

  /** Activation d'un objet du catalogue (méthode 1 de Topo). */
  function activate(code) {
    const obj = objet(code);
    if (!obj) { toast("Objet inconnu : " + code); return; }
    lastObjectCode = code;
    const fam = obj.famille;
    if (fam === "categorie") return;
    excentMode = ""; excent = {};
    if (fam === "lineaire" || fam === "batiment") {
      const m = obj.methode || {};
      const type = fam === "batiment" ? "batiment" : (m.type || "ligne_arc");
      if (type === "rectangle" || type === "cercle") { startPending(type, obj); return; }
      const key = code + "#" + Date.now();
      const o = {
        "key": key, "code": code, "obj": obj, "fid": -1, "indice": nextIndice(code),
        "vertices": [], "mode": m.mode || "ligne", "tangent": m.tangent !== false, "closed": false,
        "hachure": !!m.remplissage, "ajustDeb": !!m.ajust_debut, "ajustFin": !!m.ajust_fin,
        "type": type, "largeur": m.largeur || 0, "largeur12": m.largeur_12 || 0, "ligneDirectrice": m.ligne_directrice || 4,
        "fermDeb": !!m.fermeture_debut, "fermFin": !!m.fermeture_fin, "arcMidPending": false, "perpSuivant": null,
        "fuyante": m.fuyante || "", "longueurFuyante": m.longueur_fuyante || 0
      };
      o.label = (obj.nom || code) + " " + o.indice;
      if (actifsOrdre.length >= 10) { toast("10 linéaires actifs maximum"); return; }
      actifs[key] = o; actifsOrdre.push(key); courant = key; pending = null;
      setMessage((obj.libelle_audio || obj.nom) + " – " + modeLabel(o.mode) + " : mesurer le 1er sommet");
      refreshUi();
      return;
    }
    if (fam === "symbole") { startPending("symbole", obj); return; }
    if (fam === "texte") { startPending("texte", obj); return; }
    if (fam === "entree") { startPending("entree", obj); return; }
    if (fam === "escalier") { startPending("escalier", obj); return; }
    if (fam === "talus") { startTalus(obj); return; }
    toast("Famille non gérée : " + fam);
  }

  function modeLabel(mode) {
    return { "ligne": "ligne brisée", "arc3": "arc 3 points", "arc2": "arc 2 points", "courbe": "courbe lissée", "rectangle": "rectangle", "cercle": "cercle" }[mode] || mode;
  }

  function switchTo(key) {
    if (!actifs[key]) return;
    courant = key; pending = null;
    const o = actifs[key];
    setMessage(o.label + " – " + modeLabel(o.mode) + (o.perpSuivant ? " – 2e point de l'excentrement suivant attendu" : ""));
    refreshUi();
  }

  function setMode(mode) {
    const o = actifs[courant];
    if (o) {
      if (mode === "arc2" && !o.tangent) { toast("Arc 2 points : mode tangent requis"); return; }
      o.mode = mode; o.arcMidPending = false;
      setMessage(o.label + " – " + modeLabel(mode));
    } else if (pending && (pending.kind === "rectangle" || pending.kind === "cercle")) {
      pending.mode = mode;
    }
    refreshUi();
  }
  function toggleTangent() { const o = actifs[courant]; if (o) { o.tangent = !o.tangent; if (!o.tangent && o.mode === "arc2") o.mode = "ligne"; refreshUi(); } }
  function toggleHachure() { const o = actifs[courant]; if (o) { o.hachure = !o.hachure; saveActive(o); refreshUi(); } }
  function toggleAjustDeb() { const o = actifs[courant]; if (o) { o.ajustDeb = !o.ajustDeb; refreshUi(); } }
  function toggleAjustFin() { const o = actifs[courant]; if (o) { o.ajustFin = !o.ajustFin; refreshUi(); } }

  /** Fermeture sur le 1er point puis STOP. */
  function closeCurrent() {
    const o = actifs[courant];
    if (!o) return;
    if (o.vertices.length < 3) { toast("Au moins 3 sommets pour fermer"); return; }
    o.closed = true;
    saveActive(o);
    stop(courant);
  }

  function undoVertex() {
    const o = actifs[courant];
    if (o) {
      if (o.vertices.length === 0) return;
      const v = o.vertices.pop();
      o.arcMidPending = (o.vertices.length > 0 && o.vertices[o.vertices.length - 1].seg === "A3m");
      saveActive(o);
      setMessage(o.label + " – sommet " + v.m + " annulé");
      refreshUi();
    } else if (pending && pending.points.length > 0) {
      pending.points.pop();
      refreshUi();
    }
  }

  function addVertex(key, p) {
    const o = actifs[key];
    if (!o) return;
    let seg = "L";
    if (o.vertices.length > 0) {
      if (o.mode === "arc3") { seg = o.arcMidPending ? "A3" : "A3m"; o.arcMidPending = !o.arcMidPending; }
      else if (o.mode === "arc2") seg = (o.vertices.length >= 2 || Core.isNum(Core.endTangent(Core.buildPolyline(o.vertices, false)))) ? "A2" : "L";
      else if (o.mode === "courbe") seg = "C";
    }
    o.vertices.push({ "m": p.matricule, "x": p.x, "y": p.y, "z": p.z, "seg": seg });
    saveActive(o);
    const n = o.vertices.length;
    setMessage(o.label + " – " + n + " sommet" + (n > 1 ? "s" : "") + (o.arcMidPending ? " – point de fin d'arc attendu" : ""));
    refreshUi();
  }

  function activeParams(o) {
    return {
      "type": o.type, "mode": o.mode, "tangent": o.tangent, "closed": o.closed, "hachure": o.hachure,
      "ajust_debut": o.ajustDeb, "ajust_fin": o.ajustFin, "largeur": o.largeur, "largeur_12": o.largeur12,
      "ligne_directrice": o.ligneDirectrice, "fermeture_debut": o.fermDeb, "fermeture_fin": o.fermFin,
      "fuyante": o.fuyante, "longueur_fuyante": o.longueurFuyante, "vertices": o.vertices,
      "perp_suivant": o.perpSuivant, "indice": o.indice
    };
  }

  function saveActive(o, statut) {
    const points = Core.buildPolyline(o.vertices, o.closed);
    const attrs = {
      "code_objet": o.code, "nom_objet": o.obj.nom, "famille": o.obj.famille, "calque": o.obj.calque || "",
      "matricules": o.vertices.map(v => v.m).join(";"), "statut": statut || "en_cours", "indice": o.indice,
      "params_json": JSON.stringify(activeParams(o)), "type_lineaire": o.type, "largeur": o.largeur,
      "ferme": o.closed ? 1 : 0, "hachure": o.hachure ? 1 : 0, "horodatage": Core.nowIso(), "operateur": db.operateur
    };
    if (points.length < 2) {
      if (o.fid >= 0) { db.deleteFeature("lineaire", o.fid); o.fid = -1; }
      return;
    }
    const wkt = Core.lineWkt(points);
    if (o.fid < 0) o.fid = db.createFeature("lineaire", wkt, attrs);
    else db.updateFeature("lineaire", o.fid, wkt, attrs);
  }

  function removeActive(key) {
    delete actifs[key];
    actifsOrdre = actifsOrdre.filter(k => k !== key);
    if (courant === key) courant = actifsOrdre.length ? actifsOrdre[actifsOrdre.length - 1] : "";
  }

  /** STOP : finalise l'objet courant (ou la commande ponctuelle). */
  function stop(key) {
    const k = key || courant;
    const o = actifs[k];
    if (o) {
      if (o.vertices.length < 2) {
        if (o.fid >= 0) db.deleteFeature("lineaire", o.fid);
        removeActive(k);
        toast(o.label + " abandonné (moins de 2 sommets)");
      } else {
        saveActive(o, "termine");
        finalizeLinear(o);
        removeActive(k);
        toast(o.label + " terminé");
      }
      refreshUi();
      if (courant) switchTo(courant); else setMessage("Prêt");
      return;
    }
    if (pending) { pending = null; setMessage("Prêt"); refreshUi(); return; }
    if (excentMode) { cancelExcent(); return; }
    if (clickMode) { setClickMode(""); return; }
  }

  /** Parallèles de multiligne et surface hachurée après finalisation. */
  function finalizeLinear(o) {
    const points = Core.buildPolyline(o.vertices, o.closed);
    const base = { "code_objet": o.code, "nom_objet": o.obj.nom, "famille": o.obj.famille, "calque": o.obj.calque || "",
                   "matricules": o.vertices.map(v => v.m).join(";"), "statut": "termine", "indice": o.indice,
                   "horodatage": Core.nowIso(), "operateur": db.operateur };
    if ((o.type === "multiligne_double" || o.type === "multiligne_triple") && o.largeur > 0) {
      // ligne directrice : 1 = côté gauche levé, 4 = axe, 7 = côté droit levé (convention Topo PosLinDir)
      const dir = o.ligneDirectrice;
      let offsets = [];
      if (o.type === "multiligne_double") {
        if (dir <= 3) offsets = [-o.largeur];
        else if (dir >= 5) offsets = [o.largeur];
        else offsets = [o.largeur / 2, -o.largeur / 2];
      } else {
        const l = o.largeur, l12 = o.largeur12 || l / 2;
        if (dir <= 3) offsets = [-l12, -l];
        else if (dir >= 5) offsets = [l12, l];
        else offsets = [l / 2, -l / 2];
      }
      offsets.forEach((d, i) => {
        const par = Core.offsetPolyline(points, d);
        let a = Object.assign({}, base);
        a.type_lineaire = "parallele"; a.largeur = d;
        a.params_json = JSON.stringify({ "parallele_de": o.fid, "decalage": d, "rang": i + 1 });
        db.createFeature("lineaire", Core.lineWkt(par), a);
        if (o.fermDeb) db.createFeature("lineaire", Core.lineWkt([points[0], par[0]]), Object.assign({}, a, { "type_lineaire": "fermeture", "params_json": JSON.stringify({ "fermeture_de": o.fid, "position": "debut" }) }));
        if (o.fermFin) db.createFeature("lineaire", Core.lineWkt([points[points.length - 1], par[par.length - 1]]), Object.assign({}, a, { "type_lineaire": "fermeture", "params_json": JSON.stringify({ "fermeture_de": o.fid, "position": "fin" }) }));
      });
    }
    if (o.closed && o.hachure && points.length >= 4) {
      let a = Object.assign({}, base);
      a.type_surface = "ferme"; a.hachure = 1; a.params_json = JSON.stringify({ "lineaire": o.fid, "hachure": o.obj.hachure || {} });
      db.createFeature("surface", Core.polygonWkt(points), a);
    }
  }

  /** Mise en attente (appui court sur le bouton attente). */
  function wait(key) {
    const k = key || courant;
    const o = actifs[k];
    if (o) {
      if (o.vertices.length < 2) { toast("Rien à mettre en attente"); return; }
      saveActive(o, "attente");
      removeActive(k);
      toast(o.label + " mis en attente");
      refreshUi();
      refreshWaiting();
      if (courant) switchTo(courant); else setMessage("Prêt");
      return;
    }
    if (lastPlaced && lastPlaced.role === "symbole") {
      db.updateFeature("symbole", lastPlaced.fid, "", { "statut": "attente" });
      toast("Symbole mis en attente");
      refreshWaiting();
    }
  }

  function refreshWaiting() {
    hasWaiting = db.features("lineaire", "\"statut\" = 'attente'").length > 0 || db.features("symbole", "\"statut\" = 'attente'").length > 0;
  }

  /** Liste des objets en attente (pour le dialogue de reprise). */
  function waitingList() {
    let out = [];
    for (const f of db.features("lineaire", "\"statut\" = 'attente'")) out.push({ "role": "lineaire", "fid": f.id, "label": db.str(f, "nom_objet") + " " + db.str(f, "indice"), "code": db.str(f, "code_objet") });
    for (const f of db.features("symbole", "\"statut\" = 'attente'")) out.push({ "role": "symbole", "fid": f.id, "label": db.str(f, "nom_objet"), "code": db.str(f, "code_objet") });
    return out;
  }

  /** Reprise d'un linéaire (attente, terminé ou en cours après plantage). */
  function resumeLinear(fid, fromStart) {
    const f = db.getFeature("lineaire", fid);
    if (!f) return false;
    const code = db.str(f, "code_objet");
    const obj = objet(code);
    if (!obj) { toast("Objet " + code + " absent du catalogue"); return false; }
    let params = {};
    try { params = JSON.parse(db.str(f, "params_json") || "{}"); } catch (e) { params = {}; }
    let vertices = params.vertices || [];
    if (fromStart) {
      // reprise par le début : on repart des points segmentés en sens inverse (les arcs deviennent des segments)
      const pts = Core.buildPolyline(vertices, false).reverse();
      vertices = pts.map((p, i) => ({ "m": "", "x": p.x, "y": p.y, "z": p.z, "seg": "L" }));
    }
    const key = code + "#" + Date.now();
    const o = {
      "key": key, "code": code, "obj": obj, "fid": fid, "indice": params.indice || nextIndice(code),
      "vertices": vertices, "mode": params.mode || "ligne", "tangent": params.tangent !== false, "closed": false,
      "hachure": !!params.hachure, "ajustDeb": !!params.ajust_debut, "ajustFin": !!params.ajust_fin,
      "type": params.type || "ligne_arc", "largeur": params.largeur || 0, "largeur12": params.largeur_12 || 0,
      "ligneDirectrice": params.ligne_directrice || 4, "fermDeb": !!params.fermeture_debut, "fermFin": !!params.fermeture_fin,
      "arcMidPending": false, "perpSuivant": params.perp_suivant || null, "fuyante": params.fuyante || "", "longueurFuyante": params.longueur_fuyante || 0
    };
    o.label = obj.nom + " " + o.indice;
    actifs[key] = o; actifsOrdre.push(key); courant = key; pending = null;
    saveActive(o, "en_cours");
    refreshWaiting();
    setMessage(o.label + " repris – " + modeLabel(o.mode));
    refreshUi();
    return true;
  }

  function resumeWaiting(item) {
    if (item.role === "lineaire") resumeLinear(item.fid, false);
    else if (item.role === "symbole") {
      db.updateFeature("symbole", item.fid, "", { "statut": "termine" });
      lastPlaced = { "role": "symbole", "fid": item.fid, "kind": "symbole" };
      zoomToFeature("symbole", item.fid);
      toast("Symbole réactivé : utiliser les ajustements");
      refreshWaiting();
    }
  }

  /** Objets restés "en_cours" en base (plantage / fermeture) : réactivation. */
  function recoverActiveObjects() {
    const list = db.features("lineaire", "\"statut\" = 'en_cours'");
    for (const f of list) resumeLinear(f.id, false);
    if (list.length > 0) toast(list.length + " linéaire(s) en cours réactivé(s)");
  }

  function relaunchLast() {
    if (!lastObjectCode) { toast("Aucun objet précédent"); return; }
    activate(lastObjectCode);
  }

  /* ================================================================== */
  /* Commandes ponctuelles : symbole, texte, entrée, escalier, formes    */
  /* ================================================================== */

  function startPending(kind, obj) {
    const m = obj.methode || {};
    let needed = 1, mode = "";
    if (kind === "symbole") needed = m.points || 1;
    else if (kind === "texte") { needed = (m.placement === "1pt") ? 1 : 2; }
    else if (kind === "entree") needed = 2;
    else if (kind === "escalier") needed = m.points || 3;
    else if (kind === "rectangle") { needed = rectanglePoints; mode = "rectangle"; }
    else if (kind === "cercle") { needed = rayonVerrouille && rayonCercle > 0 ? 1 : 2; mode = "cercle"; }
    pending = { "kind": kind, "obj": obj, "code": obj.code, "points": [], "needed": needed, "mode": mode, "text": "" };
    courant = "";
    if (kind === "texte") {
      requestDialog("texte", { "obj": obj, "liste": (m.liste && theme.listes_textes) ? (theme.listes_textes[m.liste] || []) : [], "defaut": m.texte_defaut || "" });
      setMessage((obj.libelle_audio || obj.nom) + " – saisir le texte");
    } else {
      setMessage((obj.libelle_audio || obj.nom) + " – méthode " + needed + " point" + (needed > 1 ? "s" : ""));
    }
    refreshUi();
  }

  function setPendingText(t) {
    if (!pending) return;
    pending.text = t; pendingText = t;
    setMessage(pending.obj.nom + " : « " + t + " » – placer le texte (" + pending.needed + " pt)");
    refreshUi();
  }

  function setRectanglePoints(n) { rectanglePoints = n; if (pending && pending.kind === "rectangle") { pending.needed = n; refreshUi(); } }
  function setRayon(r, lock) { rayonCercle = r; rayonVerrouille = lock; if (pending && pending.kind === "cercle") { pending.needed = (lock && r > 0) ? 1 : (pending.mode3 ? 3 : 2); refreshUi(); } }
  function setCercle3Points(b) { if (pending && pending.kind === "cercle") { pending.mode3 = b; pending.needed = b ? 3 : ((rayonVerrouille && rayonCercle > 0) ? 1 : 2); refreshUi(); } }

  function pendingFeed(p) {
    pending.points.push(p);
    const n = pending.points.length;
    if (n < pending.needed) { setMessage(pending.obj.nom + " – point " + (n + 1) + " / " + pending.needed); refreshUi(); return; }
    const pts = pending.points, obj = pending.obj, m = obj.methode || {};
    const base = { "code_objet": obj.code, "nom_objet": obj.nom, "famille": obj.famille, "calque": obj.calque || "",
                   "matricules": pts.map(q => q.matricule).join(";"), "statut": "termine", "indice": nextIndice(obj.code),
                   "horodatage": Core.nowIso(), "operateur": db.operateur };
    let fid = -1;
    if (pending.kind === "symbole") {
      const rot = pts.length >= 2 ? Core.rotationDeg(pts[0], pts[1]) : 0;
      const d12 = pts.length >= 2 ? Core.dist2d(pts[0], pts[1]) : 0;
      let d23 = 0;
      if (pts.length >= 3) { const a = Core.angle(pts[0], pts[1]); d23 = Math.abs(-(pts[2].x - pts[1].x) * Math.sin(a) + (pts[2].y - pts[1].y) * Math.cos(a)); }
      const ex = (m.verrou_longueur || !(m.longueur > 0) || d12 <= 0) ? 1 : d12 / m.longueur;
      const ey = (m.verrou_largeur || !(m.largeur > 0) || d23 <= 0) ? 1 : d23 / m.largeur;
      fid = db.createFeature("symbole", Core.pointWkt(pts[0]), Object.assign(base, {
        "famille_bloc": (obj.symbole || {}).famille_bloc || "", "bloc": (obj.symbole || {}).bloc || "",
        "rotation": rot, "echelle_x": ex, "echelle_y": ey, "dist_12": d12, "dist_23": d23, "nb_points": pts.length, "symetrie": 0,
        "params_json": JSON.stringify({ "methode": m, "points": pts })
      }));
      lastPlaced = { "role": "symbole", "fid": fid, "kind": "symbole", "rotation": rot, "points": pts };
      toast(obj.nom + " placé");
    } else if (pending.kind === "texte") {
      const rot = pts.length >= 2 ? Core.rotationDeg(pts[0], pts[1]) : 0;
      fid = db.createFeature("texte", Core.pointWkt(pts[0]), Object.assign(base, {
        "texte": pending.text, "rotation": rot, "taille": m.taille || 1, "ancrage": m.ancrage || 6,
        "params_json": JSON.stringify({ "placement": m.placement || "1pt", "points": pts })
      }));
      lastPlaced = { "role": "texte", "fid": fid, "kind": "texte" };
    } else if (pending.kind === "entree") {
      fid = db.createFeature("entree", Core.lineWkt([pts[0], pts[1]]), Object.assign(base, {
        "delimiteur_g": String(m.delimiteur_1 || 0), "delimiteur_d": String(m.delimiteur_2 || 0),
        "seuil": m.seuil === false ? 0 : 1, "decalage_seuil": 0, "sens": (m.sens || 0) === 0 ? "entrante" : "sortante",
        "texte": m.texte || "", "decalage_texte": 0, "params_json": JSON.stringify({ "methode": m, "points": pts })
      }));
      lastPlaced = { "role": "entree", "fid": fid, "kind": "entree", "points": pts };
      toast("Entrée placée");
    } else if (pending.kind === "escalier") {
      const ring = pts.length === 3 ? Core.rectangleFrom3(pts[0], pts[1], pts[2]) : [pts[0], pts[1], pts[2], pts[3], pts[0]];
      fid = db.createFeature("surface", Core.polygonWkt(ring), Object.assign(base, {
        "type_surface": "escalier", "hachure": 0,
        "nb_marches": m.calcul_marches === "nombre" ? Math.round(m.valeur || 0) : 0,
        "prof_marche": m.calcul_marches === "profondeur" ? (m.valeur || 0) : 0,
        "fleche": m.fleche === false ? 0 : 1, "sens": "montant", "params_json": JSON.stringify({ "methode": m, "points": pts })
      }));
      lastPlaced = { "role": "surface", "fid": fid, "kind": "escalier" };
      toast("Escalier placé");
    } else if (pending.kind === "rectangle") {
      const ring = pts.length === 2 ? Core.rectangleFrom2(pts[0], pts[1]) : Core.rectangleFrom3(pts[0], pts[1], pts[2]);
      fid = db.createFeature("surface", Core.polygonWkt(ring), Object.assign(base, {
        "type_surface": "rectangle", "hachure": (obj.methode || {}).remplissage ? 1 : 0, "params_json": JSON.stringify({ "points": pts })
      }));
      lastPlaced = { "role": "surface", "fid": fid, "kind": "rectangle" };
      toast("Rectangle placé");
    } else if (pending.kind === "cercle") {
      let c = null, r = 0;
      if (pts.length === 3) { const cc = Core.circleFrom3(pts[0], pts[1], pts[2]); if (!cc) { toast("Points alignés"); pending.points = []; refreshUi(); return; } c = cc.center; r = cc.radius; }
      else if (pts.length === 2) { c = pts[0]; r = Core.dist2d(pts[0], pts[1]); }
      else { c = pts[0]; r = rayonCercle; }
      fid = db.createFeature("surface", Core.polygonWkt(Core.circlePolygon(c, r, c.z)), Object.assign(base, {
        "type_surface": "cercle", "rayon": r, "hachure": (obj.methode || {}).remplissage ? 1 : 0, "params_json": JSON.stringify({ "centre": c, "rayon": r, "points": pts })
      }));
      lastPlaced = { "role": "surface", "fid": fid, "kind": "cercle" };
      toast("Cercle placé (R = " + Core.fmt(r, 2) + " m)");
    }
    // fonction réentrante : on repart pour un objet identique
    pending.points = [];
    setMessage(obj.nom + " – prêt pour le suivant (STOP pour terminer)");
    refreshUi();
  }

  /* --- ajustements du dernier objet ponctuel (symétrie, inversion) --- */
  function adjustSymetrie() {
    if (!lastPlaced || lastPlaced.role !== "symbole") { toast("Aucun symbole à ajuster"); return; }
    const f = db.getFeature("symbole", lastPlaced.fid);
    if (!f) return;
    const s = db.num(f, "symetrie") === 1 ? 0 : 1;
    db.updateFeature("symbole", lastPlaced.fid, "", { "symetrie": s });
    toast("Symétrie " + (s ? "appliquée" : "retirée"));
  }
  function adjustInverser() {
    if (!lastPlaced) return;
    if (lastPlaced.role === "symbole") {
      const f = db.getFeature("symbole", lastPlaced.fid);
      if (!f) return;
      db.updateFeature("symbole", lastPlaced.fid, "", { "rotation": (db.num(f, "rotation") + 180) % 360 });
      toast("Symbole retourné");
    } else if (lastPlaced.role === "entree") {
      const f = db.getFeature("entree", lastPlaced.fid);
      if (!f) return;
      const s = db.str(f, "sens") === "entrante" ? "sortante" : "entrante";
      db.updateFeature("entree", lastPlaced.fid, "", { "sens": s });
      toast("Entrée " + s);
    } else if (lastPlaced.role === "surface" && lastPlaced.kind === "escalier") {
      const f = db.getFeature("surface", lastPlaced.fid);
      if (!f) return;
      const s = db.str(f, "sens") === "montant" ? "descendant" : "montant";
      db.updateFeature("surface", lastPlaced.fid, "", { "sens": s });
      toast("Escalier " + s);
    }
  }
  function adjustDecalage(dist) {
    if (!lastPlaced || lastPlaced.role !== "symbole" || !lastPlaced.points) return;
    const f = db.getFeature("symbole", lastPlaced.fid);
    if (!f) return;
    const pts = lastPlaced.points;
    const a = pts.length >= 2 ? Core.angle(pts[0], pts[1]) + Math.PI / 2 : Math.PI / 2;
    const np = Core.pointAt(pts[0], a, dist, pts[0].z);
    lastPlaced.points[0] = np;
    db.updateFeature("symbole", lastPlaced.fid, Core.pointWkt(np), { "params_json": JSON.stringify({ "decalage": dist, "points": pts }) });
    toast("Symbole décalé de " + Core.fmt(dist, 2) + " m");
  }

  /* --- talus : sélection de 2 linéaires existants --- */
  property var talusObj: null
  property var talusBas: null
  function startTalus(obj) {
    talusObj = obj; talusBas = null; pending = null; courant = "";
    const m = obj.methode || {};
    setClickMode(m.mode === 2 ? "talus_haut" : "talus_bas");
    setMessage("Habillage de talus – cliquer sur le " + (m.mode === 2 ? "HAUT" : "BAS") + " de talus dans le plan");
    refreshUi();
  }
  function talusPick(f, role) {
    if (role !== "lineaire") { toast("Sélectionner un linéaire"); return; }
    const m = talusObj.methode || {};
    if (clickMode === "talus_bas" && m.mode !== 3) {
      talusBas = f; setClickMode("talus_haut"); setMessage("Talus – cliquer maintenant sur le HAUT de talus"); return;
    }
    const haut = clickMode === "talus_haut" ? f : null;
    const bas = clickMode === "talus_bas" ? f : talusBas;
    const src = haut || bas;
    let params = {};
    try { params = JSON.parse(db.str(src, "params_json") || "{}"); } catch (e) { }
    const pts = Core.buildPolyline(params.vertices || [], false);
    if (pts.length < 2) { toast("Linéaire sans sommets exploitables"); setClickMode(""); return; }
    db.createFeature("talus", Core.lineWkt(pts), {
      "code_objet": talusObj.code, "nom_objet": talusObj.nom, "famille": "talus", "calque": talusObj.calque || "",
      "statut": "termine", "indice": nextIndice(talusObj.code), "fid_haut": haut ? haut.id : -1, "fid_bas": bas ? bas.id : -1,
      "mode": m.mode || 0, "espace": m.espace || 0.4, "nb_lignes": m.nb_lignes || 4, "pct_court": m.pct_court || 35,
      "pct_long": m.pct_long || 90, "pct_inter": m.pct_inter || 30, "horodatage": Core.nowIso(), "operateur": db.operateur,
      "params_json": JSON.stringify({ "methode": m })
    });
    toast("Habillage de talus enregistré (barbules générées au bureau)");
    setClickMode(""); talusObj = null; talusBas = null; setMessage("Prêt"); refreshUi();
  }

  /* ================================================================== */
  /* Mesures GNSS et points topo                                        */
  /* ================================================================== */

  function gnssPosition() {
    if (!positionSource || !positionSource.active) return null;
    const info = positionSource.positionInformation;
    if (!info.latitudeValid || !info.longitudeValid) return null;
    const pp = positionSource.projectedPosition;
    let p = db.mapToWork(pp);
    if (!Core.isNum(p.z)) p.z = info.elevationValid ? info.elevation : NaN;
    p.info = info;
    return p;
  }

  /** Crée un point topo ; p = {x,y,z,[info]} ; renvoie le point enrichi (fid, matricule). */
  function createPointTopo(p, type, extra) {
    const m = db.takeMatricule();
    const info = p.info;
    let attrs = {
      "matricule": m, "type": type, "x": p.x, "y": p.y, "z": p.z, "z_signif": Core.isNum(p.z) ? 1 : 0,
      "hv": hauteurCanne, "horodatage": Core.nowIso(), "visible": 1, "operateur": db.operateur,
      "code_objet": currentObj ? currentObj.code : ""
    };
    if (info) {
      attrs.qualite = Core.fixLabel(info.quality); attrs.fix_quality = info.quality; attrs.nb_sat = info.satellitesUsed;
      attrs.hrms = info.hacc; attrs.vrms = info.vacc; attrs.pdop = info.pdop; attrs.hdop = info.hdop; attrs.vdop = info.vdop;
      attrs.lat = info.latitude; attrs.lon = info.longitude; attrs.alt_ellips = info.elevation;
    }
    if (p.tpsObs && station && station.current) {
      const o = p.tpsObs;
      if (type === "GPS") attrs.type = "TPS";
      attrs.station = station.current.matricule; attrs.hz = o.hz; attrs.v = o.v; attrs.sd = o.sd; attrs.hi = station.current.hi;
      attrs.hr = o.hr; attrs.hv = o.hr; attrs.face = o.face || 1; attrs.mode_mesure = o.mode || "";
    }
    for (const k in (extra || {})) attrs[k] = extra[k];
    const fid = db.createFeature("pt_topo", Core.pointWkt(p), attrs);
    const out = { "fid": fid, "matricule": m, "x": p.x, "y": p.y, "z": p.z, "type": type };
    lastPoint = out;
    if (zoomAuto) ensureVisible(out);
    return out;
  }

  function ensureVisible(p) {
    const q = db.workToMap(p);
    const ext = mapCanvas.mapSettings.visibleExtent;
    if (q.x < ext.xMinimum || q.x > ext.xMaximum || q.y < ext.yMinimum || q.y > ext.yMaximum) mapCanvas.mapSettings.setCenter(q);
  }

  /** Bouton "Point unique" / "Mesure point avec liaison". */
  function measure(withLink, confirmed) {
    if (mesureSource === "tps") {
      if (!station) { toast("Module station indisponible"); return; }
      if (detection) {
        if (!station.active || !station.oriente) { toast("Station orientée requise"); return; }
        station.mesurerBrut(function (obs) { let q = station.pointFromObs(obs); q.tpsObs = obs; detectionMeasure(q, withLink); });
        return;
      }
      station.mesurerPoint(withLink);
      return;
    }
    const p = gnssPosition();
    if (!p) { toast("Pas de position GNSS"); return; }
    if (qualityState === "bad") { toast("Mesure interdite : qualité GNSS insuffisante"); return; }
    if (qualityState === "warn" && !confirmed) { requestDialog("confirm_warn", { "withLink": withLink }); return; }
    if (detection) { detectionMeasure(p, withLink); return; }
    const pt = createPointTopo(p, "GPS");
    if (withLink) feedPoint(pt); else setMessage("Point unique " + pt.matricule + " mesuré");
  }

  /** Bouton "Dernier point". */
  function useLastPoint() {
    const p = lastPoint || db.lastPointTopo();
    if (!p) { toast("Aucun point dans le carnet"); return; }
    feedPoint(p);
  }

  /** Routage d'un point vers la commande en cours. */
  function feedPoint(p) {
    if (excentMode) { excentFeed(p); return; }
    if (pending) { pendingFeed(p); return; }
    if (courant) {
      const o = actifs[courant];
      if (o.perpSuivant) { perpSuivantSecond(o, p); return; }
      addVertex(courant, p);
      return;
    }
    setMessage("Point " + p.matricule + " – aucun objet actif");
  }

  /* ================================================================== */
  /* Excentrements                                                      */
  /* ================================================================== */

  readonly property var excentLabels: ({
      "point": "Par rapport à un point", "perp_prec": "Perpendiculaire point précédent", "perp_suiv": "Perpendiculaire point suivant",
      "vertical": "Vertical", "milieu": "Milieu", "deux_dist": "Deux distances"
    })

  function setExcentMode(mode) {
    if (excentMode === mode || mode === "") { cancelExcent(); return; }
    if (mode === "perp_prec") {
      const o = actifs[courant];
      if (!o || o.vertices.length === 0) { toast("Perpendiculaire point précédent : un linéaire avec au moins 1 sommet doit être actif"); return; }
    }
    if (mode === "perp_suiv" && !actifs[courant]) { toast("Perpendiculaire point suivant : activer d'abord un linéaire"); return; }
    excentMode = mode; excent = { "points": [] }; excentStep = "appui";
    const hint = {
      "point": "mesurer le point d'appui (ou Dernier point)", "perp_prec": "mesurer la position décalée",
      "perp_suiv": "mesurer le 1er point décalé", "vertical": "point d'appui = dernier point (ou mesurer)",
      "milieu": "mesurer le 1er côté", "deux_dist": "mesurer (ou cliquer) le 1er point"
    }[mode];
    setMessage("Excentrement " + excentLabels[mode] + " – " + hint);
    if (mode === "vertical" && (lastPoint || db.lastPointTopo())) {
      excent.appui = lastPoint || db.lastPointTopo();
      excentStep = "saisie";
      requestDialog("excent", { "mode": mode, "appui": excent.appui });
    }
    refreshUi();
  }

  function cancelExcent() { excentMode = ""; excentStep = ""; excent = {}; setMessage(courant ? actifs[courant].label : "Prêt"); refreshUi(); }

  function excentFeed(p) {
    excent.points.push(p);
    const n = excent.points.length;
    switch (excentMode) {
      case "point":
        excent.appui = p;
        excent.ref = excent.ref || previousPoint(p);
        excentStep = "saisie";
        requestDialog("excent", { "mode": excentMode, "appui": p, "ref": excent.ref });
        break;
      case "perp_prec": {
        const o = actifs[courant];
        excent.appui = p; excent.p1 = o.vertices[o.vertices.length - 1];
        excentStep = "saisie";
        requestDialog("excent", { "mode": excentMode, "appui": p, "ref": excent.p1 });
        break;
      }
      case "perp_suiv":
        excent.appui = p; excentStep = "saisie";
        requestDialog("excent", { "mode": excentMode, "appui": p });
        break;
      case "vertical":
        excent.appui = p; excentStep = "saisie";
        requestDialog("excent", { "mode": excentMode, "appui": p });
        break;
      case "milieu":
        if (n < 2) { setMessage("Milieu – mesurer le 2e côté"); return; }
        finishExcent(Core.excentMilieu(excent.points[0], excent.points[1]), { "pt_appui": excent.points[0].matricule + ";" + excent.points[1].matricule, "methode_excent": "milieu" });
        break;
      case "deux_dist":
        if (n < 2) { setMessage("Deux distances – mesurer (ou cliquer) le 2e point"); return; }
        excentStep = "saisie";
        requestDialog("excent", { "mode": excentMode, "appui": excent.points[0], "ref": excent.points[1] });
        break;
    }
    refreshUi();
  }

  function previousPoint(p) {
    // point de référence par défaut = point du carnet précédant le point d'appui
    const lyr = db.getLayer("pt_topo");
    let best = null;
    let it = QfLayerUtils.createFeatureIteratorFromExpression(lyr, "$id < " + p.fid + " AND \"type\" <> 'CLIC'");
    while (it.hasNext()) { const f = it.next(); if (!best || f.id > best.id) best = f; }
    it.close();
    return db.pointFromFeature(best);
  }

  function setExcentRef(p) { excent.ref = p; toast("Référence : " + p.matricule); if (excentStep === "saisie") requestDialog("excent", { "mode": excentMode, "appui": excent.appui, "ref": p }); }

  /** Validation du dialogue d'excentrement : values = {direction, side, distance, dz, d1, d2, swap}. */
  function excentValidate(values) {
    let res = null, extra = {};
    switch (excentMode) {
      case "point": {
        let appui = excent.appui, ref = excent.ref;
        if (values.swap) { const t = appui; appui = ref; ref = t; }
        if (!ref) { toast("Pas de point de référence"); return; }
        res = Core.excentParRapportAPoint(ref, appui, values.direction, values.distance);
        extra = { "pt_appui": appui.matricule, "pt_ref": ref.matricule, "methode_excent": "point_" + values.direction, "dist_excent": values.distance };
        break;
      }
      case "perp_prec":
        res = Core.excentPerpendiculaire(excent.p1, excent.appui, values.side, values.distance);
        extra = { "pt_appui": excent.appui.matricule, "pt_ref": excent.p1.m || "", "methode_excent": "perp_prec_" + values.side, "dist_excent": values.distance };
        break;
      case "perp_suiv": {
        const o = actifs[courant];
        o.perpSuivant = { "p1": excent.appui, "side": values.side, "d1": values.distance };
        saveActive(o);
        cancelExcent();
        setMessage(o.label + " – 2e point de l'excentrement suivant attendu (mesure directe ou excentrée)");
        refreshUi();
        return;
      }
      case "vertical":
        res = Core.excentVertical(excent.appui, values.dz);
        extra = { "pt_appui": excent.appui.matricule, "methode_excent": "vertical", "dist_excent": values.dz };
        break;
      case "deux_dist":
        res = Core.excentDeuxDistances(excent.points[0], excent.points[1], values.d1, values.d2, values.side);
        if (!res) { toast("Cercles sans intersection : vérifier les distances"); return; }
        extra = { "pt_appui": excent.points[0].matricule + ";" + excent.points[1].matricule, "methode_excent": "deux_dist_" + values.side, "dist_excent": values.d1 };
        break;
    }
    finishExcent(res, extra);
  }

  function finishExcent(p, extra) {
    const pt = createPointTopo(p, "EXCENTRE", extra);
    const mode = excentMode;
    excentMode = ""; excentStep = ""; excent = {};
    toast("Point excentré " + pt.matricule);
    // le point excentré alimente la commande en cours
    if (pending) pendingFeed(pt);
    else if (courant) { const o = actifs[courant]; if (o.perpSuivant) perpSuivantSecond(o, pt); else addVertex(courant, pt); }
    else setMessage("Point excentré " + pt.matricule + " créé (" + excentLabels[mode] + ")");
    refreshUi();
  }

  /** 2e point de l'excentrement "perpendiculaire point suivant". */
  function perpSuivantSecond(o, p2) {
    o.pendingSecond = p2;
    requestDialog("excent", { "mode": "perp_suiv_2", "appui": p2, "ref": o.perpSuivant.p1, "defaut": o.perpSuivant.d1, "side": o.perpSuivant.side });
  }

  function perpSuivantValidate(values) {
    const o = actifs[courant];
    if (!o || !o.perpSuivant || !o.pendingSecond) return;
    const p1 = o.perpSuivant.p1, p2 = o.pendingSecond, side = o.perpSuivant.side;
    const a = Core.angle(p1, p2) + (side === "gauche" ? Math.PI / 2 : -Math.PI / 2);
    const q1 = Core.pointAt(p1, a, o.perpSuivant.d1, p1.z);
    const q2 = Core.pointAt(p2, a, values.distance, p2.z);
    const e1 = createPointTopo(q1, "EXCENTRE", { "pt_appui": p1.matricule, "methode_excent": "perp_suiv_" + side, "dist_excent": o.perpSuivant.d1 });
    const e2 = createPointTopo(q2, "EXCENTRE", { "pt_appui": p2.matricule, "methode_excent": "perp_suiv_" + side, "dist_excent": values.distance });
    o.perpSuivant = null; o.pendingSecond = null;
    addVertex(courant, e1);
    addVertex(courant, e2);
    toast("Excentrement point suivant terminé");
  }

  /* ================================================================== */
  /* Détection (saisie manuelle de profondeur)                          */
  /* ================================================================== */

  function setDetection(values) {
    detection = values; // {profondeur, index, intensite, frequence}
    setMessage("Détection : profondeur " + Core.fmt(values.profondeur, 2) + " m en attente – mesurer le point");
    if (detectionAuto) measure(true, false);
  }

  function detectionMeasure(p, withLink) {
    const d = detection;
    detection = null;
    const tn = createPointTopo(p, "GPS", { "profondeur": d.profondeur, "commentaire": "TN détection" });
    const zgs = Core.excentVertical(tn, -d.profondeur);
    const gs = createPointTopo(zgs, "EXCENTRE", { "pt_appui": tn.matricule, "methode_excent": "vertical", "dist_excent": -d.profondeur, "profondeur": d.profondeur,
                                                   "commentaire": JSON.stringify({ "detection": d }) });
    toast("Détection : ZTN " + Core.fmt(tn.z, 2) + " / ZGS " + Core.fmt(gs.z, 2));
    if (withLink) feedPoint(gs); else setMessage("Points " + tn.matricule + " (TN) et " + gs.matricule + " (réseau) créés");
  }

  /* ================================================================== */
  /* Clics dans le plan                                                 */
  /* ================================================================== */

  function setClickMode(mode) {
    clickMode = mode; clickCandidate = null;
    const hints = {
      "continuer": "Continuer : cliquer sur le linéaire à reprendre (début ou fin)",
      "supprimer": "Supprimer : cliquer sur l'élément à effacer",
      "relance": "Relance : cliquer sur un élément du plan pour activer un objet identique",
      "ref_point": "Cliquer sur le point topo de référence",
      "appui_point": "Cliquer sur le point topo d'appui",
      "impl_pick": "Implantation : cliquer sur le point du carnet à implanter"
    };
    if (mode && hints[mode]) setMessage(hints[mode]);
    refreshUi();
  }

  function screenTolerance() { return mapCanvas.mapSettings.mapUnitsPerPoint * 16; }

  /** Appelé par le gestionnaire de clics carte. Renvoie true si le clic est consommé. */
  function mapClicked(screenPoint, interactionType) {
    if (interactionType !== "clicked") return false;
    if (!clickMode && !(modeBureau && (courant || pending || excentMode))) return false;
    const mapPt = mapCanvas.mapSettings.screenToCoordinate(screenPoint);
    const p = db.mapToWork(mapPt);
    const tol = screenTolerance();
    if (!clickMode) {
      // mode bureau : le clic vaut un sommet (accroché à un point topo si proche)
      let pt = db.nearestPointTopo(p, tol);
      if (!pt) pt = createPointTopo(Core.pt(p.x, p.y, NaN), "CLIC");
      feedPoint(pt);
      return true;
    }
    let cand = buildCandidate(p, tol);
    if (!cand) { toast("Rien à cet endroit"); return true; }
    if (modeBureau) { executeCandidate(cand); return true; }
    clickCandidate = cand;
    highlight(cand);
    setMessage(cand.descr + " – Valider ?");
    refreshUi();
    return true;
  }

  property var clickCallback: null     // rappel pour le mode "pick_point"

  /** Sélection graphique d'un point (point topo ou station) puis rappel cb(point). */
  function pickPoint(cb, hint) {
    clickCallback = cb;
    setClickMode("pick_point");
    setMessage(hint || "Cliquer sur un point topo ou une station dans le plan");
  }

  function nearestStation(p, tol) {
    const list = db.featuresInRect("station", Core.pt(p.x - tol, p.y - tol), Core.pt(p.x + tol, p.y + tol));
    let best = null, bestD = tol;
    for (const f of list) {
      const q = { "fid": f.id, "matricule": db.str(f, "matricule"), "x": db.num(f, "x"), "y": db.num(f, "y"), "z": db.num(f, "z"), "role": "station", "type": "STATION" };
      const d = Core.dist2d(p, q);
      if (d <= bestD) { best = q; bestD = d; }
    }
    return best;
  }

  function buildCandidate(p, tol) {
    const mode = clickMode;
    if (mode === "station_libre_clic") {
      // clic libre : Z du point topo / de la station proche, sinon 0
      let near = db.nearestPointTopo(p, tol);
      const st = nearestStation(p, tol);
      if (st && (!near || Core.dist2d(p, st) < Core.dist2d(p, near))) near = st;
      const q = near ? Core.pt(near.x, near.y, near.z) : Core.pt(p.x, p.y, 0);
      return { "mode": mode, "point": q, "descr": near ? ("Station sur " + near.matricule) : "Station au point cliqué (Z = 0)" };
    }
    if (mode === "ref_point" || mode === "appui_point" || mode === "impl_pick" || mode === "pick_point" || mode === "relock") {
      let pt = db.nearestPointTopo(p, tol);
      if (pt) pt.role = "pt_topo";
      const st = nearestStation(p, tol);
      if (st && (!pt || Core.dist2d(p, st) < Core.dist2d(p, pt))) pt = st;
      if (mode === "relock") return { "mode": mode, "point": pt || Core.pt(p.x, p.y, NaN), "descr": pt ? ("Relockage vers " + pt.matricule) : "Rotation vers le point cliqué", "isPoint": !!pt };
      return pt ? { "mode": mode, "point": pt, "descr": (pt.role === "station" ? "Station " : "Point ") + pt.matricule } : null;
    }
    // recherche dans les couches de primitives (+ points topo pour la suppression)
    let roles = db.primitiveLayers.slice();
    if (mode === "supprimer") roles.push("pt_topo");
    let found = [];
    for (const role of roles) {
      const list = db.featuresInRect(role, Core.pt(p.x - tol, p.y - tol), Core.pt(p.x + tol, p.y + tol));
      for (const f of list) {
        const d = featureDistance(role, f, p);
        if (d <= tol) found.push({ "role": role, "feature": f, "fid": f.id, "dist": d, "label": featureLabel(role, f) });
      }
    }
    if (found.length === 0) return null;
    found.sort((a, b) => a.dist - b.dist);
    if (mode === "continuer" || mode === "talus_bas" || mode === "talus_haut") found = found.filter(c => c.role === "lineaire");
    if (found.length === 0) return null;
    return { "mode": mode, "point": p, "descr": found[0].label, "feature": found[0].feature, "role": found[0].role, "fid": found[0].fid, "others": found };
  }

  function featureLabel(role, f) {
    if (role === "pt_topo") return "Point topo " + db.str(f, "matricule");
    const nom = db.str(f, "nom_objet"), ind = db.str(f, "indice");
    const prefix = role === "lineaire" ? "Linéaire" : role === "symbole" ? "Symbole" : role === "texte" ? "Texte" : role.charAt(0).toUpperCase() + role.slice(1);
    const label = nom.toLowerCase().startsWith(prefix.toLowerCase()) ? nom : prefix + " " + nom;
    return label + (ind ? " " + ind : "") + (role === "texte" ? " « " + db.str(f, "texte") + " »" : "");
  }

  function featureDistance(role, f, p) {
    if (role === "pt_topo" || role === "symbole" || role === "texte") {
      let q;
      if (role === "pt_topo") q = Core.pt(db.num(f, "x"), db.num(f, "y"), NaN);
      else { const prm = paramsOf(f); const pts = prm.points || []; if (pts.length) q = pts[0]; else return Infinity; }
      return Core.dist2d(p, q);
    }
    const pts = featurePoints(f);
    if (pts.length === 0) return Infinity;
    const near = Core.nearestOnPolyline(p, pts);
    return near ? near.dist : Infinity;
  }

  function paramsOf(f) { try { return JSON.parse(db.str(f, "params_json") || "{}"); } catch (e) { return {}; } }

  function pointsFromParams(prm, typeSurface) {
    if (prm.vertices) return Core.buildPolyline(prm.vertices, !!prm.closed);
    if (prm.points) {
      const pts = prm.points;
      if (prm.centre) return Core.circlePolygon(prm.centre, prm.rayon || 0, prm.centre.z);
      if (pts.length === 2 && typeSurface === "rectangle") return Core.rectangleFrom2(pts[0], pts[1]);
      if (pts.length === 3 && (typeSurface === "rectangle" || typeSurface === "escalier")) return Core.rectangleFrom3(pts[0], pts[1], pts[2]);
      if (pts.length === 4) return [pts[0], pts[1], pts[2], pts[3], pts[0]];
      return pts;
    }
    return [];
  }

  function featurePoints(f) { return pointsFromParams(paramsOf(f), db.str(f, "type_surface")); }

  /**
   * Régénération : après recalcul de points topo (V0, station libre, compensation),
   * met à jour les primitives qui les utilisent (équivalent "régénération du plan" Topo).
   */
  function regenerateFromPoints(matricules) {
    let lookup = {};
    for (const m of matricules) { const p = db.pointByMatricule(m); if (p) lookup[m] = p; }
    function apply(list) {
      let changed = false;
      for (let v of list) {
        const m = v.m || v.matricule;
        if (m && lookup[m]) { v.x = lookup[m].x; v.y = lookup[m].y; v.z = lookup[m].z; changed = true; }
      }
      return changed;
    }
    let n = 0;
    for (const role of ["lineaire", "surface", "symbole", "texte", "entree"]) {
      for (const f of db.features(role, "")) {
        const ms = db.str(f, "matricules").split(";");
        if (!ms.some(m => lookup[m])) continue;
        let prm = paramsOf(f);
        let changed = false;
        if (prm.vertices) changed = apply(prm.vertices) || changed;
        if (prm.points) changed = apply(prm.points) || changed;
        if (!changed) continue;
        let wkt = "";
        if (role === "lineaire" && prm.vertices) wkt = Core.lineWkt(Core.buildPolyline(prm.vertices, !!prm.closed));
        else if (role === "surface") { const pts = pointsFromParams(prm, db.str(f, "type_surface")); wkt = pts.length >= 3 ? Core.polygonWkt(pts) : ""; }
        else if ((role === "symbole" || role === "texte") && prm.points && prm.points.length) wkt = Core.pointWkt(prm.points[0]);
        else if (role === "entree" && prm.points && prm.points.length >= 2) wkt = Core.lineWkt([prm.points[0], prm.points[1]]);
        db.updateFeature(role, f.id, wkt, { "params_json": JSON.stringify(prm) });
        n++;
      }
    }
    for (const key of actifsOrdre) { const o = actifs[key]; if (apply(o.vertices)) saveActive(o); }
    if (n) toast(n + " objet(s) régénéré(s)");
    refreshUi();
  }

  function highlight(cand) {
    const gh = iface.findItemByObjectName("geometryHighlighter");
    if (!gh) return;
    let wkt = "";
    if (cand.point && !cand.feature) wkt = Core.pointWkt(cand.point);
    else if (cand.role === "pt_topo" || cand.role === "symbole" || cand.role === "texte") {
      const q = cand.role === "pt_topo" ? Core.pt(db.num(cand.feature, "x"), db.num(cand.feature, "y"), 0) : (paramsOf(cand.feature).points || [cand.point])[0];
      wkt = Core.pointWkt(q);
    } else {
      const pts = featurePoints(cand.feature);
      wkt = pts.length >= 2 ? Core.lineWkt(pts) : Core.pointWkt(cand.point);
    }
    if (!wkt) return;
    gh.geometryWrapper.qgsGeometry = QfGeometryUtils.createGeometryFromWkt(wkt);
    gh.geometryWrapper.crs = db.workCrs();
  }

  function validateCandidate() { if (clickCandidate) executeCandidate(clickCandidate); }
  function cancelCandidate() { clickCandidate = null; setMessage(clickMode ? "Cliquer à nouveau ou STOP" : "Prêt"); refreshUi(); }

  function executeCandidate(cand) {
    clickCandidate = null;
    switch (cand.mode) {
      case "continuer": {
        const pts = featurePoints(cand.feature);
        const near = Core.nearestOnPolyline(cand.point, pts);
        const total = Core.length2d(pts);
        const before = Core.length2d(pts.slice(0, near.index + 1)) + Core.dist2d(pts[near.index], near.point);
        const fromStart = before < total / 2;
        resumeLinear(cand.fid, fromStart);
        setClickMode("");
        toast("Reprise par " + (fromStart ? "le début" : "la fin"));
        break;
      }
      case "supprimer":
        if (cand.others && cand.others.length > 1) { requestDialog("ambiguite", { "items": cand.others }); return; }
        deleteElement(cand.role, cand.fid);
        break;
      case "relance": {
        const code = db.str(cand.feature, "code_objet");
        setClickMode("");
        if (objet(code)) activate(code); else toast("Objet " + code + " absent du catalogue");
        break;
      }
      case "ref_point": setExcentRef(cand.point); setClickMode(""); break;
      case "pick_point":
      case "station_libre_clic": {
        const cb = clickCallback;
        clickCallback = null;
        setClickMode("");
        if (cb) cb(cand.point);
        break;
      }
      case "relock":
        setClickMode("");
        if (station) station.relockVers(cand.point, cand.isPoint);
        break;
      case "appui_point":
        setClickMode("");
        if (excentMode) excentFeed(cand.point); else feedPoint(cand.point);
        break;
      case "impl_pick":
        setClickMode("");
        implantationAddPoint(cand.point);
        break;
      case "talus_bas": case "talus_haut": talusPick(cand.feature, cand.role); break;
    }
    refreshUi();
  }

  /** Suppression d'un élément (avec gestion des points excentrés dépendants). */
  function deleteElement(role, fid, keepExcent) {
    if (role === "pt_topo") {
      const f = db.getFeature("pt_topo", fid);
      if (!f) return;
      const m = db.str(f, "matricule");
      const deps = db.features("pt_topo", "\"pt_appui\" = '" + m + "' OR \"pt_appui\" LIKE '" + m + ";%' OR \"pt_appui\" LIKE '%;" + m + "'");
      if (deps.length > 0 && keepExcent === undefined) { requestDialog("suppr_appui", { "fid": fid, "matricule": m, "nb": deps.length }); return; }
      for (const d of deps) {
        if (keepExcent) db.updateFeature("pt_topo", d.id, "", { "type": "CONSTRUIT", "pt_appui": "" });
        else db.deleteFeature("pt_topo", d.id);
      }
      db.deleteFeature("pt_topo", fid);
      toast("Point " + m + " supprimé");
    } else {
      // objets actifs pointant sur cette entité
      for (const k of actifsOrdre.slice()) if (actifs[k].fid === fid && role === "lineaire") removeActive(k);
      db.deleteFeature(role, fid);
      toast("Élément supprimé");
    }
    refreshWaiting();
    refreshUi();
  }

  /* ================================================================== */
  /* Carnet de terrain                                                  */
  /* ================================================================== */

  function carnetList(types, search) {
    let out = [];
    const lyr = db.getLayer("pt_topo");
    if (!lyr) return out;
    let it = QfLayerUtils.createFeatureIterator(lyr);
    while (it.hasNext()) {
      const f = it.next();
      const p = db.pointFromFeature(f);
      if (types && types.length && types.indexOf(p.type) < 0) continue;
      if (search && p.matricule.toLowerCase().indexOf(search.toLowerCase()) < 0) continue;
      out.push(p);
    }
    it.close();
    out.sort((a, b) => a.fid - b.fid);
    return out;
  }

  function zoomToPoints(points) {
    if (points.length === 0) return;
    let pts = points.map(p => db.workToMap(p));
    if (pts.length === 1) { mapCanvas.mapSettings.setCenter(pts[0]); return; }
    mapCanvas.mapSettings.setExtentFromPoints(pts, 200);
  }

  function zoomToFeature(role, fid) {
    const f = db.getFeature(role, fid);
    if (!f) return;
    const pts = role === "pt_topo" ? [Core.pt(db.num(f, "x"), db.num(f, "y"), 0)] : featurePoints(f);
    if (pts.length) zoomToPoints(pts);
  }

  function changeHv(points, newHv) {
    for (const p of points) {
      const dz = (Core.isNum(p.hv) ? p.hv : hauteurCanne) - newHv;
      const z = Core.isNum(p.z) ? p.z + dz : NaN;
      db.updateFeature("pt_topo", p.fid, Core.isNum(z) ? Core.pointWkt(Core.pt(p.x, p.y, z)) : "", { "hv": newHv, "z": z });
    }
    toast(points.length + " point(s) : hauteur de canne " + Core.fmt(newHv, 3));
  }

  function setZSignif(points, signif) {
    for (const p of points) db.updateFeature("pt_topo", p.fid, "", { "z_signif": signif ? 1 : 0 });
    toast(points.length + " point(s) : Z " + (signif ? "significatif" : "non significatif"));
  }

  function setPointsAppuiVisibles(vis) {
    pointsAppuiVisibles = vis;
    const lyr = db.getLayer("pt_topo");
    if (!lyr) return;
    try { lyr.setSubsetString(vis ? "" : "\"matricule\" NOT IN (SELECT pt_appui FROM pt_topo WHERE pt_appui IS NOT NULL AND pt_appui NOT LIKE '%;%')"); }
    catch (e) { toast("Filtre des points d'appui non disponible"); }
  }

  function exportDir() {
    const dir = qgisProject.homePath + "/export";
    platformUtilities.createDir(qgisProject.homePath, "export");
    return dir;
  }

  /** Export MXYZ (.xyz) du carnet. */
  function exportXyz(points) {
    const lines = points.map(p => [p.matricule, Core.fmt(p.x, 3), Core.fmt(p.y, 3), Core.isNum(p.z) && p.z_signif ? Core.fmt(p.z, 3) : ""].join(" "));
    const path = exportDir() + "/carnet_" + Core.stampFile() + ".xyz";
    QfFileUtils.writeFileContent(path, lines.join("\n") + "\n");
    toast("Export : " + path);
    return path;
  }

  /** Export CSV des données GPS (précisions, satellites, heure). */
  function exportCsvGps() {
    const list = db.features("pt_topo", "\"type\" = 'GPS'");
    let rows = ["matricule;x;y;z;lat;lon;alt_ellips;hv;qualite;nb_sat;hrms;vrms;pdop;hdop;vdop;horodatage;code_objet"];
    for (const f of list) {
      rows.push(["matricule", "x", "y", "z", "lat", "lon", "alt_ellips", "hv", "qualite", "nb_sat", "hrms", "vrms", "pdop", "hdop", "vdop", "horodatage", "code_objet"].map(k => db.str(f, k)).join(";"));
    }
    const path = exportDir() + "/gps_" + Core.stampFile() + ".csv";
    QfFileUtils.writeFileContent(path, rows.join("\n") + "\n");
    toast("Export : " + path);
    return path;
  }

  /** Import d'un texte "M X Y Z" (séparateur espace, ; ou tabulation). target = "pt_topo" | "implantation". */
  function importPointsFromText(content, target) {
    let n = 0, ordre = implantationList().length;
    for (const raw of content.split(/\r?\n/)) {
      const line = raw.trim();
      if (!line || line.startsWith("#")) continue;
      const parts = line.split(/[;\t ]+/);
      if (parts.length < 3) continue;
      const m = parts[0], x = parseFloat(parts[1]), y = parseFloat(parts[2]), z = parts.length > 3 ? parseFloat(parts[3]) : NaN;
      if (isNaN(x) || isNaN(y)) continue;
      const p = Core.pt(x, y, z);
      if (target === "implantation") {
        db.createFeature("implantation", Core.pointWkt(p), { "matricule": m, "ordre": ++ordre, "x": x, "y": y, "z": z, "implante": 0 });
      } else {
        db.createFeature("pt_topo", Core.pointWkt(p), { "matricule": m, "type": "IMPORTE", "x": x, "y": y, "z": z, "z_signif": Core.isNum(z) ? 1 : 0, "horodatage": Core.nowIso(), "visible": 1 });
      }
      n++;
    }
    toast(n + " point(s) importé(s)");
    return n;
  }

  /* ================================================================== */
  /* Implantation de points                                             */
  /* ================================================================== */

  function implantationList() {
    return db.features("implantation", "").map(f => ({
      "fid": f.id, "matricule": db.str(f, "matricule"), "ordre": db.num(f, "ordre"),
      "x": db.num(f, "x"), "y": db.num(f, "y"), "z": db.num(f, "z"), "implante": db.num(f, "implante") === 1
    })).sort((a, b) => (a.ordre || 0) - (b.ordre || 0));
  }

  function implantationAddPoint(p) {
    const n = implantationList().length;
    db.createFeature("implantation", Core.pointWkt(p), { "matricule": p.matricule, "ordre": n + 1, "x": p.x, "y": p.y, "z": p.z, "implante": 0 });
    toast("Point " + p.matricule + " ajouté à la liste d'implantation");
  }

  function implantationStart(index) {
    const liste = implantationList();
    if (liste.length === 0) { toast("Liste d'implantation vide"); return; }
    let i = index !== undefined ? index : liste.findIndex(p => !p.implante);
    if (i < 0) i = 0;
    implantation = { "actif": true, "liste": liste, "index": i };
    setMessage("Implantation de " + liste[i].matricule);
    if (zoomAuto) zoomToPoints([liste[i]]);
    refreshUi();
  }

  function implantationStop() { implantation = { "actif": false, "liste": [], "index": -1 }; setMessage("Prêt"); refreshUi(); }

  function implantationNext(delta) {
    if (!implantation.actif) return;
    let i = implantation.index + (delta || 1);
    if (i >= implantation.liste.length || i < 0) { toast("Fin de la liste"); implantationStop(); return; }
    implantation = Object.assign({}, implantation, { "index": i });
    setMessage("Implantation de " + implantation.liste[i].matricule);
    if (zoomAuto) zoomToPoints([implantation.liste[i]]);
    refreshUi();
  }

  /** Écarts courants {dx, dy, dz, dist, gisement} entre la position GNSS et la cible. */
  function implantationDeltas() {
    if (!implantation.actif) return null;
    const cible = implantation.liste[implantation.index];
    const p = gnssPosition();
    if (!p) return null;
    const dx = cible.x - p.x, dy = cible.y - p.y;
    const dz = (Core.isNum(cible.z) && Core.isNum(p.z)) ? cible.z - p.z : NaN;
    return { "dx": dx, "dy": dy, "dz": dz, "dist": Math.sqrt(dx * dx + dy * dy), "gisement": Core.gisementGr(p, cible), "cible": cible, "pos": p };
  }

  function implanter(avecZ) {
    const d = implantationDeltas();
    if (!d) { toast("Pas de position GNSS"); return; }
    if (qualityState === "bad") { toast("Qualité GNSS insuffisante"); return; }
    const pt = createPointTopo(d.pos, "IMPLANTE", { "commentaire": "implantation de " + d.cible.matricule });
    db.updateFeature("implantation", d.cible.fid, "", {
      "implante": 1, "dx": d.dx, "dy": d.dy, "dz": avecZ ? NaN : d.dz, "dist": d.dist, "matricule_leve": pt.matricule, "horodatage": Core.nowIso()
    });
    toast(d.cible.matricule + " implanté (écart " + Core.fmt(d.dist, 3) + " m)");
    implantation.liste[implantation.index].implante = true;
    implantationNext(1);
  }

  function exportImplantation() {
    const list = db.features("implantation", "");
    let rows = ["matricule;x;y;z;implante;dx;dy;dz;dist;matricule_leve;horodatage"];
    for (const f of list) rows.push(["matricule", "x", "y", "z", "implante", "dx", "dy", "dz", "dist", "matricule_leve", "horodatage"].map(k => db.str(f, k)).join(";"));
    const path = exportDir() + "/implantation_" + Core.stampFile() + ".csv";
    QfFileUtils.writeFileContent(path, rows.join("\n") + "\n");
    toast("Rapport : " + path);
  }
}
