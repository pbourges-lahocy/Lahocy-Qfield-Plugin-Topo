import QtQuick
import org.qfield.core
import "TopoCore.js" as Core
import "TopoCalc.js" as Topo

/*
 * TopoStation - contexte station totale (menu Station du logiciel de référence) :
 * mise en station, visées de référence, station libre, mesures TPS,
 * excentrements TPS, pilotage, export polaire.
 *
 * Les échanges avec l'appareil passent par TopoDevices (pont local).
 */
Item {
  id: station

  required property var engine
  required property var db
  required property var devices

  /* ---------------- réglages ---------------- */
  property real hr: 1.5                  // hauteur du prisme
  property real hiDefaut: 1.5            // hauteur tourillons proposée
  property real hauteurDisto: 1.2
  property real decalageBicapteur: 0.0   // hauteur antenne GNSS = hr + décalage
  property bool bicapteur: false
  property bool doubleRetournement: false
  property bool courbure: true
  property real toleranceEcart: 0.04
  property real spiraleHz: 10
  property real spiraleV: 10
  property string modeMesure: "prisme"   // prisme | sans_prisme
  property string driver: "simulateur"
  property string port: "COM3"
  property int baud: 115200

  /* ---------------- station courante ---------------- */
  property var current: null            // {fid, matricule, x, y, z, hi, v0, type, oriente, refs: []}
  readonly property bool active: current !== null
  readonly property bool oriente: current !== null && current.oriente
  property var pendingFace1: null       // 1re face en double retournement
  property string excentTps: ""         // "" | station | dist_rec | vertical_tps
  property var excentState: ({})
  property var libre: null              // état de la station libre en cours {matricule, hi, refs: []}
  property string message: ""

  signal toast(string msg)
  signal requestDialog(string kind, var payload)
  signal changed()

  /* ================================================================== */
  /* Initialisation / persistance                                       */
  /* ================================================================== */

  function init() {
    hr = parseFloat(db.getParam("hauteur_prisme", "1.500")) || 1.5;
    hiDefaut = parseFloat(db.getParam("hauteur_tourillons", "1.500")) || 1.5;
    hauteurDisto = parseFloat(db.getParam("hauteur_disto", "1.20")) || 1.2;
    decalageBicapteur = parseFloat(db.getParam("decalage_bicapteur", "0")) || 0;
    doubleRetournement = db.getParam("tps_double_retournement", "0") === "1";
    courbure = db.getParam("tps_correction_courbure", "1") === "1";
    toleranceEcart = parseFloat(db.getParam("tps_tolerance_ecart_moyenne", "0.04")) || 0.04;
    spiraleHz = parseFloat(db.getParam("tps_spirale_hz", "10")) || 10;
    spiraleV = parseFloat(db.getParam("tps_spirale_v", "10")) || 10;
    driver = db.getParam("tps_driver", "simulateur");
    port = db.getParam("tps_port", "COM3");
    baud = parseInt(db.getParam("tps_baud", "115200")) || 115200;
    devices.url = db.getParam("bridge_url", "http://127.0.0.1:8765");
    const list = db.features("station", "\"statut\" = 'active'");
    if (list.length) current = stationFromFeature(list[0]);
    changed();
  }

  function saveSettings() {
    db.setParam("hauteur_prisme", hr.toFixed(3));
    db.setParam("hauteur_tourillons", hiDefaut.toFixed(3));
    db.setParam("hauteur_disto", hauteurDisto.toFixed(3));
    db.setParam("decalage_bicapteur", decalageBicapteur.toFixed(3));
    db.setParam("tps_double_retournement", doubleRetournement ? "1" : "0");
    db.setParam("tps_correction_courbure", courbure ? "1" : "0");
    db.setParam("tps_tolerance_ecart_moyenne", String(toleranceEcart));
    db.setParam("tps_spirale_hz", String(spiraleHz));
    db.setParam("tps_spirale_v", String(spiraleV));
    db.setParam("tps_driver", driver);
    db.setParam("tps_port", port);
    db.setParam("tps_baud", String(baud));
    db.setParam("bridge_url", devices.url);
  }

  function stationFromFeature(f) {
    let params = {};
    try { params = JSON.parse(db.str(f, "params_json") || "{}"); } catch (e) { }
    return {
      "fid": f.id, "matricule": db.str(f, "matricule"), "type": db.str(f, "type"), "statut": db.str(f, "statut"),
      "x": db.num(f, "x"), "y": db.num(f, "y"), "z": db.num(f, "z"), "hi": db.num(f, "hi"), "v0": db.num(f, "v0"),
      "oriente": !!params.oriente, "refs": params.refs || []
    };
  }

  function saveCurrent() {
    if (!current) return;
    const s = current;
    db.updateFeature("station", s.fid, Core.pointWkt(Core.pt(s.x, s.y, s.z)), {
      "x": s.x, "y": s.y, "z": s.z, "hi": s.hi, "v0": s.v0, "statut": "active", "nb_ref": s.refs.filter(r => !r.exclue).length,
      "params_json": JSON.stringify({ "oriente": s.oriente, "refs": s.refs }), "horodatage": Core.nowIso()
    });
    changed();
  }

  function stationList() {
    return db.features("station", "").map(stationFromFeature);
  }

  function nextStationMatricule() {
    let m = db.getParam("station_matricule_prochain", "S.1");
    let guard = 0;
    while (db.features("station", "\"matricule\" = '" + m + "'").length > 0 && guard < 1000) { m = Core.nextMatricule(m); guard++; }
    db.setParam("station_matricule_prochain", Core.nextMatricule(m));
    return m;
  }

  function setHr(h) {
    hr = h;
    db.setParam("hauteur_prisme", h.toFixed(3));
    devices.tpsSetup({ "hr": h });
    if (bicapteur && engine.positionSource) { engine.hauteurCanne = h + decalageBicapteur; engine.setHauteurCanne(h + decalageBicapteur); }
    changed();
  }

  /* ================================================================== */
  /* Connexion                                                          */
  /* ================================================================== */

  function connecter(cb) {
    saveSettings();
    devices.tpsConnect(driver, port, baud, function (res) {
      if (res.ok) { toast("Station connectée : " + (res.model || driver)); devices.tpsSetup({ "hr": hr }); }
      else toast("Connexion impossible : " + (res.error || ""));
      if (cb) cb(res);
    });
  }
  function deconnecter() { devices.tpsDisconnect(function () { toast("Station déconnectée"); }); }

  /* ================================================================== */
  /* Mise en station                                                    */
  /* ================================================================== */

  function deactivateCurrent(statut) {
    if (!current) return;
    db.updateFeature("station", current.fid, "", { "statut": statut || "stationnee", "params_json": JSON.stringify({ "oriente": current.oriente, "refs": current.refs }) });
  }

  function createStationFeature(matricule, p, hi, type, statut, extra) {
    return db.createFeature("station", Core.pointWkt(p), Object.assign({
      "matricule": matricule, "type": type, "statut": statut, "x": p.x, "y": p.y, "z": p.z, "hi": hi, "v0": NaN, "nb_ref": 0,
      "params_json": JSON.stringify({ "oriente": false, "refs": [] }), "horodatage": Core.nowIso(), "operateur": db.operateur
    }, extra || {}));
  }

  function activateStation(fid, matricule, p, hi, oriente, v0, refs) {
    deactivateCurrent("stationnee");
    current = { "fid": fid, "matricule": matricule, "type": "", "statut": "active", "x": p.x, "y": p.y, "z": p.z, "hi": hi, "v0": Core.isNum(v0) ? v0 : 0, "oriente": !!oriente, "refs": refs || [] };
    saveCurrent();
    engine.zoomToPoints([p]);
    message = "Station " + matricule + (oriente ? "" : " – visées de référence à effectuer");
    changed();
  }

  /** Saisie de coordonnées. */
  function stationCoordonnees(matricule, x, y, z, hi) {
    const m = matricule || nextStationMatricule();
    const p = Core.pt(x, y, z);
    const fid = createStationFeature(m, p, hi, "CONNUE", "active");
    // 1re station : locale, V0 = 0 (mesures autorisées, orientation par référence conseillée)
    const first = stationList().length <= 1;
    activateStation(fid, m, p, hi, first, 0, []);
    toast("Station " + m + " créée" + (first ? " (station locale, V0 = 0)" : ""));
  }

  /** Clic sur point connu : un point topo / une station devient la station. */
  function stationSurPoint(pt, hi) {
    const p = Core.pt(pt.x, pt.y, pt.z);
    let fid = -1, m = pt.matricule;
    if (pt.role === "station") {
      fid = pt.fid;
      db.updateFeature("station", fid, "", { "hi": hi });
    } else {
      fid = createStationFeature(m, p, hi, "CONNUE", "active", { "params_json": JSON.stringify({ "oriente": false, "refs": [], "point_topo": pt.fid }) });
      db.updateFeature("pt_topo", pt.fid, "", { "type": "STATION" });
    }
    const first = stationList().length <= 1;
    activateStation(fid, m, p, hi, first, 0, []);
    toast("Station sur le point " + m);
  }

  /** Clic libre dans le plan. */
  function stationClicLibre(p, hi, matricule) {
    const m = matricule || nextStationMatricule();
    const fid = createStationFeature(m, p, hi, "CLIC", "active");
    const first = stationList().length <= 1;
    activateStation(fid, m, p, hi, first, 0, []);
    toast("Station " + m + " placée (Z = " + Core.fmt(p.z, 2) + ")");
  }

  /** Visée avant : crée une station future depuis la station active. */
  function viseeAvant(matricule) {
    if (!current || !current.oriente) { toast("Station active orientée requise"); return; }
    mesurerBrut(function (obs) {
      const p = Topo.polarToXYZ(current, current.v0, obs, { "courbure": courbure });
      const m = matricule || nextStationMatricule();
      const fid = createStationFeature(m, p, NaN, "VISEE_AVANT", "non_utilisee", { "params_json": JSON.stringify({ "oriente": false, "refs": [], "depuis": current.matricule, "obs": obs }) });
      db.createFeature("visee", "", { "station": current.matricule, "cible": m, "type": "VISEE_AVANT", "hz": obs.hz, "v": obs.v, "sd": obs.sd, "hi": current.hi, "hr": obs.hr, "face": obs.face || 1, "exclue": 0, "horodatage": Core.nowIso() });
      requestDialog("visee_avant_resultat", { "matricule": m, "point": p, "obs": obs, "fid": fid });
      toast("Station " + m + " créée par visée avant");
      changed();
    });
  }

  /** Changement de station (l'appareil est déplacé sur une station existante). */
  function changerStation(fid, hi) {
    const f = db.getFeature("station", fid);
    if (!f) return;
    const s = stationFromFeature(f);
    activateStation(fid, s.matricule, Core.pt(s.x, s.y, s.z), hi, false, NaN, []);
    db.updateFeature("station", fid, "", { "hi": hi });
    toast("Station " + s.matricule + " active – visées de référence obligatoires");
  }

  /* ================================================================== */
  /* Visées de référence                                                */
  /* ================================================================== */

  /** cible = {matricule, x, y, z} ; type = REF_ANGLE_DIST | REF_ANGLE | REF_APPROCHEE */
  function viseeReference(type, cible, cb) {
    if (!current) { toast("Aucune station active"); return; }
    mesurerBrut(function (obs) {
      if (type === "REF_ANGLE" || type === "REF_APPROCHEE") obs.sd = NaN;
      const v0i = Topo.v0FromReference(current, cible, obs.hz);
      let ecarts = { "plani": NaN, "alti": NaN };
      if (type === "REF_ANGLE_DIST") ecarts = Topo.referenceEcarts(current, v0i, obs, cible, { "courbure": courbure });
      const ref = { "cible": cible.matricule, "x": cible.x, "y": cible.y, "z": cible.z, "type": type, "hz": obs.hz, "v": obs.v, "sd": obs.sd, "hr": obs.hr, "v0": v0i, "ecart_plani": ecarts.plani, "ecart_alti": ecarts.alti, "exclue": false };
      requestDialog("reference_resultat", { "ref": ref, "cb": function (accepted) { if (accepted) acceptReference(ref); if (cb) cb(accepted); } });
    });
  }

  function acceptReference(ref) {
    // une visée précise remplace une visée approchée sur la même cible
    current.refs = current.refs.filter(r => !(r.type === "REF_APPROCHEE" && r.cible === ref.cible));
    current.refs.push(ref);
    db.createFeature("visee", "", { "station": current.matricule, "cible": ref.cible, "type": ref.type, "hz": ref.hz, "v": ref.v, "sd": ref.sd, "hi": current.hi, "hr": ref.hr, "face": 1, "ecart_plani": ref.ecart_plani, "ecart_alti": ref.ecart_alti, "exclue": 0, "horodatage": Core.nowIso() });
    recomputeV0();
  }

  function excludeReference(index, exclue) {
    if (!current || !current.refs[index]) return;
    current.refs[index].exclue = exclue;
    recomputeV0();
  }

  function recomputeV0() {
    const used = current.refs.filter(r => !r.exclue);
    const oldV0 = current.v0;
    if (used.length) { current.v0 = Topo.meanV0(used.map(r => r.v0)); current.oriente = true; }
    saveCurrent();
    if (Core.isNum(oldV0) && Math.abs(Topo.normGr(current.v0 - oldV0)) > 1e-6) recomputePoints();
    message = "Station " + current.matricule + " – V0 = " + Topo.fmtGr(current.v0) + " (" + used.length + " réf.)";
    changed();
  }

  /** Recalcul des points levés depuis la station active (V0 ou position modifiés). */
  function recomputePoints() {
    if (!current) return;
    const list = db.features("pt_topo", "\"type\" = 'TPS' AND \"station\" = '" + current.matricule + "'");
    let matricules = [];
    for (const f of list) {
      const obs = { "hz": db.num(f, "hz"), "v": db.num(f, "v"), "sd": db.num(f, "sd"), "hr": db.num(f, "hr") };
      const p = Topo.polarToXYZ(current, current.v0, obs, { "courbure": courbure });
      db.updateFeature("pt_topo", f.id, Core.pointWkt(p), { "x": p.x, "y": p.y, "z": p.z, "hi": current.hi });
      matricules.push(db.str(f, "matricule"));
    }
    if (matricules.length) { engine.regenerateFromPoints(matricules); toast(matricules.length + " point(s) recalculé(s)"); }
  }

  /* ================================================================== */
  /* Station libre                                                      */
  /* ================================================================== */

  function libreStart(matricule, hi) {
    libre = { "matricule": matricule || nextStationMatricule(), "hi": hi, "refs": [], "result": null };
    message = "Station libre " + libre.matricule + " – viser une référence";
    changed();
  }

  /** Une visée de station libre : mesure puis identification de la cible (ou point GNSS en bicapteur). */
  function libreVisee(cible, cb) {
    if (!libre) return;
    mesurerBrut(function (obs) {
      let c = cible;
      if (!c && bicapteur) {
        const g = engine.gnssPosition();
        if (!g) { toast("Bicapteur : pas de position GNSS"); return; }
        const pt = engine.createPointTopo(g, "GPS", { "commentaire": "référence station libre" });
        c = { "matricule": pt.matricule, "x": pt.x, "y": pt.y, "z": pt.z };
      }
      const ref = { "cible": c, "hz": obs.hz, "v": obs.v, "sd": obs.sd, "hr": obs.hr, "useXY": true, "useZ": true, "useDist": Core.isNum(obs.sd), "exclue": false };
      libre.refs.push(ref);
      libreCompute();
      if (cb) cb(ref);
    });
  }

  function libreSetOption(index, key, value) { if (libre && libre.refs[index]) { libre.refs[index][key] = value; libreCompute(); } }

  function libreCompute() {
    if (!libre) return;
    libre.result = Topo.stationLibre(libre.refs, libre.hi, { "courbure": courbure });
    libre = Object.assign({}, libre);
    changed();
  }

  function libreValidate() {
    if (!libre || !libre.result || !libre.result.ok) { toast("Calcul de station libre impossible"); return; }
    const r = libre.result;
    const p = Core.pt(r.x, r.y, r.z);
    const refs = libre.refs.map((ref, i) => ({ "cible": ref.cible.matricule, "x": ref.cible.x, "y": ref.cible.y, "z": ref.cible.z, "type": "REF_ANGLE_DIST", "hz": ref.hz, "v": ref.v, "sd": ref.sd, "hr": ref.hr, "v0": r.v0, "ecart_plani": r.residus[i] ? r.residus[i].dPlani : NaN, "ecart_alti": r.residus[i] ? r.residus[i].dZ : NaN, "exclue": !!ref.exclue }));
    const fid = createStationFeature(libre.matricule, p, libre.hi, "LIBRE", "active", { "emq_plani": r.emq_plani, "emq_alti": r.emq_alti });
    for (const ref of refs) db.createFeature("visee", "", { "station": libre.matricule, "cible": ref.cible, "type": "REF_ANGLE_DIST", "hz": ref.hz, "v": ref.v, "sd": ref.sd, "hi": libre.hi, "hr": ref.hr, "face": 1, "ecart_plani": ref.ecart_plani, "ecart_alti": ref.ecart_alti, "exclue": ref.exclue ? 1 : 0, "horodatage": Core.nowIso() });
    activateStation(fid, libre.matricule, p, libre.hi, true, r.v0, refs);
    toast("Station libre " + libre.matricule + " : EMQ " + Core.fmt(r.emq_plani, 3) + " m");
    libre = null;
    changed();
  }

  function libreCancel() { libre = null; changed(); }

  /* ================================================================== */
  /* Mesures                                                            */
  /* ================================================================== */

  /** Mesure brute (gère le double retournement et le simulateur). */
  function mesurerBrut(cb, sim) {
    if (!devices.tpsConnected) { toast("Station non connectée"); return; }
    if (driver === "simulateur" && !sim) { requestDialog("saisie_mesure", { "cb": function (values) { mesurerBrut(cb, values); } }); return; }
    const face = (doubleRetournement && pendingFace1) ? 2 : 1;
    devices.tpsMeasureRequest(modeMesure, face, sim, function (res) {
      if (!res.ok) { toast("Mesure impossible : " + (res.error || "")); return; }
      if (res.warn) toast("Station : " + res.warn);
      let obs = { "hz": res.hz, "v": res.v, "sd": res.sd, "hr": hr, "face": face, "mode": modeMesure };
      if (doubleRetournement) {
        if (face === 1) { pendingFace1 = obs; message = "Face 1 mesurée – tourner en face 2 et mesurer à nouveau"; changed(); return; }
        const combined = Topo.doubleRetournement(pendingFace1, obs);
        pendingFace1 = null;
        obs = { "hz": combined.hz, "v": combined.v, "sd": combined.sd, "hr": hr, "face": 0, "mode": modeMesure, "collimation": combined.collimation };
      }
      cb(obs);
    });
  }

  /** Mesure d'un point topo (Point unique / avec liaison). */
  function mesurerPoint(withLink) {
    if (!current) { toast("Aucune station : faire une mise en station"); return; }
    if (!current.oriente) { toast("Station non orientée : visées de référence obligatoires"); return; }
    if (excentTps) { excentTpsMeasure(withLink); return; }
    mesurerBrut(function (obs) {
      const pt = createTpsPoint(obs, "TPS", {});
      if (withLink) engine.feedPoint(pt); else engine.setMessage("Point unique " + pt.matricule + " mesuré");
    });
  }

  function pointFromObs(obs) { return Topo.polarToXYZ(current, current.v0, obs, { "courbure": courbure }); }

  function createTpsPoint(obs, type, extra) {
    const p = Topo.polarToXYZ(current, current.v0, obs, { "courbure": courbure });
    return engine.createPointTopo(p, type, Object.assign({
      "station": current.matricule, "hz": obs.hz, "v": obs.v, "sd": obs.sd, "hi": current.hi, "hr": obs.hr, "face": obs.face || 1, "mode_mesure": obs.mode || modeMesure, "hv": obs.hr
    }, extra));
  }

  /* ================================================================== */
  /* Excentrements TPS                                                  */
  /* ================================================================== */

  function setExcentTps(mode) {
    if (excentTps === mode || !mode) { excentTps = ""; excentState = {}; message = ""; changed(); return; }
    excentTps = mode; excentState = { "step": 1 };
    message = { "station": "Par rapport à la station : mesurer le point d'appui", "dist_rec": "Distance/Recouvrement : mesurer d'abord la DISTANCE", "vertical_tps": "Vertical : mesurer le point d'appui puis viser le point déporté" }[mode];
    changed();
  }

  function excentTpsMeasure(withLink) {
    const mode = excentTps;
    if (mode === "station") {
      mesurerBrut(function (obs) {
        const appui = createTpsPoint(obs, "TPS", {});
        excentState = { "appui": appui, "withLink": withLink };
        requestDialog("excent", { "mode": "station", "appui": appui, "ref": current, "distoOk": devices.distoConnected });
      });
    } else if (mode === "dist_rec") {
      if (excentState.step === 1) {
        mesurerBrut(function (obs) {
          excentState = { "step": 2, "first": obs, "withLink": withLink };
          message = "Distance mesurée (" + Core.fmt(obs.sd, 3) + " m) – se placer dans l'alignement et mesurer l'ANGLE";
          changed();
        });
      } else {
        mesurerBrut(function (obs) {
          const combined = { "hz": obs.hz, "v": obs.v, "sd": excentState.first.sd, "hr": hr, "face": obs.face, "mode": "dist_rec" };
          const appui = createTpsPoint(excentState.first, "TPS", { "commentaire": "appui dist/rec" });
          const pt = createTpsPoint(combined, "EXCENTRE", { "pt_appui": appui.matricule, "methode_excent": "dist_rec" });
          excentTps = ""; excentState = {}; message = "";
          if (excentState.withLink !== false) engine.feedPoint(pt);
          toast("Point excentré " + pt.matricule + " (distance/recouvrement)");
          changed();
        });
      }
    } else if (mode === "vertical_tps") {
      if (excentState.step === 1) {
        mesurerBrut(function (obs) {
          const appui = createTpsPoint(obs, "TPS", {});
          excentState = { "step": 2, "appui": appui, "withLink": withLink };
          message = "Point d'appui " + appui.matricule + " – viser le point déporté puis mesurer (angles seuls)";
          changed();
        });
      } else {
        const done = function (res) {
          if (!res || !res.ok) { toast("Lecture des angles impossible"); return; }
          const appui = excentState.appui;
          const dh = Topo.distH(current, appui);
          const vr = Topo.gr2rad(res.v);
          const z = current.z + current.hi + dh * Math.cos(vr) / Math.sin(vr);
          const pt = engine.createPointTopo(Core.pt(appui.x, appui.y, z), "EXCENTRE", { "pt_appui": appui.matricule, "methode_excent": "vertical_tps", "dist_excent": z - appui.z, "station": current.matricule, "hz": res.hz, "v": res.v });
          const wl = excentState.withLink;
          excentTps = ""; excentState = {}; message = "";
          if (wl !== false) engine.feedPoint(pt);
          toast("Point excentré vertical " + pt.matricule);
          changed();
        };
        if (driver === "simulateur") requestDialog("saisie_mesure", { "anglesSeuls": true, "cb": function (values) { done({ "ok": true, "hz": values.hz, "v": values.v }); } });
        else devices.tpsAngles(null, done);
      }
    }
  }

  /** Validation du dialogue "par rapport à la station" : {direction, distance}. */
  function excentStationValidate(values) {
    const appui = excentState.appui;
    const res = Core.excentParRapportAPoint(current, appui, values.direction, values.distance);
    const pt = engine.createPointTopo(res, "EXCENTRE", { "pt_appui": appui.matricule, "pt_ref": current.matricule, "methode_excent": "station_" + values.direction, "dist_excent": values.distance });
    const wl = excentState.withLink;
    excentTps = ""; excentState = {}; message = "";
    if (wl !== false) engine.feedPoint(pt);
    toast("Point excentré " + pt.matricule);
    changed();
  }

  /** Distance disto (mesure horizontale ou visée au sol corrigée de la hauteur du disto). */
  function distoDistance(auSol, cb) {
    devices.distoMeasureRequest(null, function (res) {
      if (!res.ok) { toast("Disto : " + (res.error || "")); return; }
      let d = res.distance;
      if (auSol && d > hauteurDisto) d = Math.sqrt(d * d - hauteurDisto * hauteurDisto);
      cb(d);
    });
  }

  /* ================================================================== */
  /* Pilotage                                                           */
  /* ================================================================== */

  function powerSearch(etendu) { devices.tpsSearch(etendu ? "powersearch_etendu" : "powersearch", {}, function (r) { if (!r.ok) toast("PowerSearch : " + (r.error || "")); }); }
  function spirale() { devices.tpsSearch("spirale", { "hz": spiraleHz, "v": spiraleV }, function (r) { if (!r.ok) toast("Recherche spirale : " + (r.error || "")); }); }
  function joystick(dir, speed) { devices.tpsJoystick(dir, speed); }
  function stopMoteurs() { devices.tpsStop(); }
  function lock(on) { devices.tpsLockRequest(on); }
  function laser(on) { devices.tpsLaser(on); }
  function tracking(on) { devices.tpsTracking(on); }

  /** Relockage dans le plan : tourner l'appareil vers un point (recherche si point topo). */
  function relockVers(p, search) {
    if (!current) { toast("Station active requise"); return; }
    const th = Topo.xyzToPolar(current, current.oriente ? current.v0 : 0, p, current.hi, hr);
    devices.tpsTurn(th.hz, th.v, search, function (r) { if (!r.ok) toast("Rotation : " + (r.error || "")); else toast("Rotation vers Hz " + Topo.fmtGr(th.hz, 2)); });
  }

  /** Position courante du prisme à partir du suivi (angles + distance en tracking). */
  function prismPosition() {
    if (!current || !current.oriente || !devices.tpsConnected) return null;
    if (!Core.isNum(devices.tpsHz) || !Core.isNum(devices.tpsV) || !Core.isNum(devices.tpsSd)) return null;
    return Topo.polarToXYZ(current, current.v0, { "hz": devices.tpsHz, "v": devices.tpsV, "sd": devices.tpsSd, "hr": hr }, { "courbure": courbure });
  }

  /** Axe de visée courant pour l'affichage (gisement en grades). */
  function axeVisee() {
    if (!current || !Core.isNum(devices.tpsHz)) return NaN;
    return Topo.normGr((current.oriente ? current.v0 : 0) + devices.tpsHz);
  }

  /* ================================================================== */
  /* Carnet polaire / exports                                           */
  /* ================================================================== */

  function carnetPolaire() {
    let out = [];
    const stations = stationList();
    for (const s of stations) {
      out.push({ "kind": "station", "matricule": s.matricule, "type": s.type, "x": s.x, "y": s.y, "z": s.z, "hi": s.hi, "v0": s.v0, "statut": s.statut });
      for (const f of db.features("visee", "\"station\" = '" + s.matricule + "'")) {
        out.push({ "kind": "visee", "station": s.matricule, "cible": db.str(f, "cible"), "type": db.str(f, "type"), "hz": db.num(f, "hz"), "v": db.num(f, "v"), "sd": db.num(f, "sd"), "hr": db.num(f, "hr"), "ecart_plani": db.num(f, "ecart_plani"), "ecart_alti": db.num(f, "ecart_alti"), "exclue": db.num(f, "exclue") === 1 });
      }
      for (const f of db.features("pt_topo", "\"type\" = 'TPS' AND \"station\" = '" + s.matricule + "'")) {
        out.push({ "kind": "point", "station": s.matricule, "matricule": db.str(f, "matricule"), "hz": db.num(f, "hz"), "v": db.num(f, "v"), "sd": db.num(f, "sd"), "hr": db.num(f, "hr"), "z_signif": db.num(f, "z_signif") === 1 });
      }
    }
    return out;
  }

  function exportGsi() {
    let lines = [];
    for (const row of carnetPolaire()) {
      if (row.kind === "station") lines.push(Topo.gsi16(row.matricule, NaN, NaN, NaN, NaN, row.hi) + " 84..10+" + Math.round(row.x * 1000) + " 85..10+" + Math.round(row.y * 1000) + " 86..10+" + Math.round(row.z * 1000));
      else if (row.kind === "visee") lines.push(Topo.gsi16(row.cible, row.hz, row.v, row.sd, row.hr, NaN));
      else lines.push(Topo.gsi16(row.matricule, row.hz, row.v, row.sd, row.hr, NaN));
    }
    const path = engine.exportDir() + "/carnet_" + Core.stampFile() + ".gsi";
    QfFileUtils.writeFileContent(path, lines.join("\r\n") + "\r\n");
    toast("Export GSI : " + path);
    return path;
  }

  function exportCsvPolaire() {
    let rows = ["type;station;matricule;hz_gr;v_gr;di_m;hi;hr;x;y;z;ecart_plani;ecart_alti"];
    for (const r of carnetPolaire()) {
      if (r.kind === "station") rows.push(["STATION", r.matricule, "", "", "", "", Core.fmt(r.hi, 3), "", Core.fmt(r.x, 3), Core.fmt(r.y, 3), Core.fmt(r.z, 3), "", ""].join(";"));
      else if (r.kind === "visee") rows.push([r.type, r.station, r.cible, Topo.fmtGr(r.hz), Topo.fmtGr(r.v), Core.fmt(r.sd, 3), "", Core.fmt(r.hr, 3), "", "", "", Core.fmt(r.ecart_plani, 3), Core.fmt(r.ecart_alti, 3)].join(";"));
      else rows.push(["POINT", r.station, r.matricule, Topo.fmtGr(r.hz), Topo.fmtGr(r.v), Core.fmt(r.sd, 3), "", Core.fmt(r.hr, 3), "", "", "", "", ""].join(";"));
    }
    const path = engine.exportDir() + "/carnet_polaire_" + Core.stampFile() + ".csv";
    QfFileUtils.writeFileContent(path, rows.join("\n") + "\n");
    toast("Export : " + path);
    return path;
  }
}
