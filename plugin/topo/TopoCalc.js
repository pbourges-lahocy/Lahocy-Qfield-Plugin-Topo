.pragma library
/*
 * TopoCalc.js - calculs de topographie classique (station totale) :
 * réduction des observations polaires, V0, station libre (résection par
 * moindres carrés), double retournement, polygonale.
 *
 * Angles en GRADES (Hz : 0 à 400, V : angle zénithal 0 = zénith, 100 = horizon).
 * Gisement : 0 = nord (axe Y), sens horaire.
 */

var R_TERRE = 6371000.0;
var K_REFRACTION = 0.13;

function gr2rad(g) { return g * Math.PI / 200.0; }
function rad2gr(r) { return r * 200.0 / Math.PI; }
function normGr(g) { g = g % 400.0; if (g < 0) g += 400.0; return g; }
function isNum(v) { return typeof v === "number" && !isNaN(v); }
function fmtGr(g, dec) { return isNum(g) ? normGr(g).toFixed(dec === undefined ? 4 : dec) : "-"; }

/** Gisement en grades de a vers b. */
function gisement(a, b) { return normGr(rad2gr(Math.atan2(b.x - a.x, b.y - a.y))); }
function distH(a, b) { return Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)); }

/**
 * Réduction d'une observation polaire.
 * station : {x, y, z, hi}   v0 : grades   obs : {hz, v, sd, hr}
 * options : {courbure: bool}
 * Renvoie {x, y, z, dh, gis}
 */
function polarToXYZ(station, v0, obs, options) {
  var gis = normGr(v0 + obs.hz);
  var vr = gr2rad(obs.v);
  var dh = obs.sd * Math.sin(vr);
  var dz = obs.sd * Math.cos(vr);
  if (options && options.courbure) dz += dh * dh * (1 - K_REFRACTION) / (2 * R_TERRE);
  var gr = gr2rad(gis);
  var x = station.x + dh * Math.sin(gr);
  var y = station.y + dh * Math.cos(gr);
  var hi = isNum(station.hi) ? station.hi : 0;
  var hr = isNum(obs.hr) ? obs.hr : 0;
  var z = (isNum(station.z) && isNum(obs.sd)) ? station.z + hi + dz - hr : NaN;
  return { x: x, y: y, z: z, dh: dh, gis: gis };
}

/**
 * Observation polaire théorique vers un point connu (pour implantation, relockage).
 * Renvoie {hz, v, sd, dh} (hz = gisement - v0).
 */
function xyzToPolar(station, v0, point, hi, hr) {
  var dh = distH(station, point);
  var gis = gisement(station, point);
  var hz = normGr(gis - v0);
  var dz = (isNum(point.z) && isNum(station.z)) ? (point.z + (isNum(hr) ? hr : 0)) - (station.z + (isNum(hi) ? hi : 0)) : 0;
  var sd = Math.sqrt(dh * dh + dz * dz);
  var v = sd > 0 ? rad2gr(Math.acos(dz / sd)) : 100;
  return { hz: hz, v: v, sd: sd, dh: dh, gis: gis };
}

/** V0 issu d'une visée sur un point connu. */
function v0FromReference(station, cible, hz) { return normGr(gisement(station, cible) - hz); }

/** Moyenne circulaire de V0 (grades). */
function meanV0(list) {
  if (list.length === 0) return NaN;
  var sx = 0, sy = 0;
  for (var i = 0; i < list.length; i++) { var a = gr2rad(list[i]); sx += Math.cos(a); sy += Math.sin(a); }
  return normGr(rad2gr(Math.atan2(sy, sx)));
}

/**
 * Écarts d'une visée de référence (angle + distance) : point calculé vs point connu.
 * Renvoie {plani, alti, dh_mesure, dh_theo}
 */
function referenceEcarts(station, v0, obs, cible, options) {
  var p = polarToXYZ(station, v0, obs, options);
  return {
    plani: distH(p, cible),
    alti: (isNum(p.z) && isNum(cible.z)) ? p.z - cible.z : NaN,
    dh_mesure: p.dh,
    dh_theo: distH(station, cible)
  };
}

/** Double retournement : combine une mesure en face 1 et une en face 2. */
function doubleRetournement(f1, f2) {
  var hz2 = normGr(f2.hz - 200);
  var d = hz2 - f1.hz;
  if (d > 200) hz2 -= 400; else if (d < -200) hz2 += 400;
  return {
    hz: normGr((f1.hz + hz2) / 2),
    v: (f1.v + (400 - f2.v)) / 2,
    sd: (isNum(f1.sd) && isNum(f2.sd)) ? (f1.sd + f2.sd) / 2 : (isNum(f1.sd) ? f1.sd : f2.sd),
    hr: f1.hr,
    collimation: (f1.v + f2.v - 400) / 2,
    ecart_hz: d
  };
}

/* ------------------------------------------------------------------ */
/* Station libre (résection) par moindres carrés                        */
/* ------------------------------------------------------------------ */

/** Résolution d'un système linéaire par Gauss (A carrée). */
function solve(A, b) {
  var n = b.length;
  var M = [];
  for (var i = 0; i < n; i++) M.push(A[i].slice().concat([b[i]]));
  for (var c = 0; c < n; c++) {
    var piv = c;
    for (var r = c + 1; r < n; r++) if (Math.abs(M[r][c]) > Math.abs(M[piv][c])) piv = r;
    if (Math.abs(M[piv][c]) < 1e-12) return null;
    var t = M[c]; M[c] = M[piv]; M[piv] = t;
    for (var r2 = 0; r2 < n; r2++) {
      if (r2 === c) continue;
      var f = M[r2][c] / M[c][c];
      for (var k = c; k <= n; k++) M[r2][k] -= f * M[c][k];
    }
  }
  var x = [];
  for (var i2 = 0; i2 < n; i2++) x.push(M[i2][n] / M[i2][i2]);
  return x;
}

/**
 * Station libre.
 * refs : [{cible:{x,y,z}, hz, v, sd, hr, useXY, useZ, useDist, exclue}]
 * hi : hauteur tourillons. options : {courbure, sigmaAngleGr (ex 0.0015), sigmaDist (ex 0.005), ppm}
 * Renvoie {ok, x, y, z, v0, emq_plani, emq_alti, residus:[{cible, dHz(gr), dDist, dPlani, dZ}], iterations, message}
 */
function stationLibre(refs, hi, options) {
  options = options || {};
  var used = refs.filter(function (r) { return !r.exclue && r.useXY !== false && r.cible && isNum(r.cible.x) && isNum(r.cible.y); });
  if (used.length < 2) return { ok: false, message: "Au moins 2 visées de référence" };
  var withDist = used.filter(function (r) { return r.useDist !== false && isNum(r.sd) && r.sd > 0; });
  if (withDist.length < 1 && used.length < 3) return { ok: false, message: "3 visées angulaires ou 2 visées avec distance minimum" };

  // --- valeurs approchées ---
  var X0, Y0;
  if (withDist.length >= 2) {
    // intersection de 2 cercles (distances horizontales)
    var a = withDist[0], b = withDist[1];
    var ra = a.sd * Math.sin(gr2rad(a.v)), rb = b.sd * Math.sin(gr2rad(b.v));
    var d = distH(a.cible, b.cible);
    if (d < 1e-6) return { ok: false, message: "Références confondues" };
    var xx = (ra * ra - rb * rb + d * d) / (2 * d);
    var h2 = ra * ra - xx * xx; var h = h2 > 0 ? Math.sqrt(h2) : 0;
    var ux = (b.cible.x - a.cible.x) / d, uy = (b.cible.y - a.cible.y) / d;
    var px = a.cible.x + xx * ux, py = a.cible.y + xx * uy;
    var c1 = { x: px - h * uy, y: py + h * ux }, c2 = { x: px + h * uy, y: py - h * ux };
    // choisir la solution cohérente avec l'angle Hz entre a et b
    var dHzObs = normGr(b.hz - a.hz);
    function score(c) { var g = normGr(gisement(c, b.cible) - gisement(c, a.cible)); var e = Math.abs(g - dHzObs); return Math.min(e, 400 - e); }
    var best = score(c1) <= score(c2) ? c1 : c2;
    X0 = best.x; Y0 = best.y;
  } else if (withDist.length === 1) {
    // distance + angle sur une 2e référence : point sur le cercle, orientation par l'angle entre les 2
    var a1 = withDist[0]; var other = used.filter(function (r) { return r !== a1; })[0];
    var r1 = a1.sd * Math.sin(gr2rad(a1.v));
    var bestS = null;
    for (var i = 0; i < 360; i++) {
      var g = gr2rad(i * 400 / 360);
      var c = { x: a1.cible.x + r1 * Math.sin(g), y: a1.cible.y + r1 * Math.cos(g) };
      var gg = normGr(gisement(c, other.cible) - gisement(c, a1.cible)); var e = Math.abs(gg - normGr(other.hz - a1.hz)); e = Math.min(e, 400 - e);
      if (!bestS || e < bestS.e) bestS = { e: e, c: c };
    }
    X0 = bestS.c.x; Y0 = bestS.c.y;
  } else {
    // relèvement : recherche grossière du minimum sur une grille autour du barycentre puis affinage
    var cx = 0, cy = 0;
    used.forEach(function (r) { cx += r.cible.x; cy += r.cible.y; });
    cx /= used.length; cy /= used.length;
    var span = 0;
    used.forEach(function (r) { span = Math.max(span, distH(r.cible, { x: cx, y: cy })); });
    var bestG = null;
    for (var gx = -2; gx <= 2; gx += 0.1) for (var gy = -2; gy <= 2; gy += 0.1) {
      var cand = { x: cx + gx * span, y: cy + gy * span };
      var v0s = used.map(function (r) { return v0FromReference(cand, r.cible, r.hz); });
      var m = meanV0(v0s), s = 0;
      v0s.forEach(function (v) { var e = Math.abs(normGr(v - m)); e = Math.min(e, 400 - e); s += e * e; });
      if (!bestG || s < bestG.s) bestG = { s: s, c: cand };
    }
    X0 = bestG.c.x; Y0 = bestG.c.y;
  }
  var V0 = meanV0(used.map(function (r) { return v0FromReference({ x: X0, y: Y0 }, r.cible, r.hz); }));

  // --- ajustement Gauss-Newton sur (X, Y, V0) ---
  var sigA = options.sigmaAngleGr || 0.0015;
  var sigD = options.sigmaDist || 0.005;
  var ppm = options.ppm || 5;
  var iter = 0, converged = false;
  for (iter = 0; iter < 20; iter++) {
    var N = [[0, 0, 0], [0, 0, 0], [0, 0, 0]], t = [0, 0, 0];
    used.forEach(function (r) {
      var dx = r.cible.x - X0, dy = r.cible.y - Y0;
      var d2 = dx * dx + dy * dy, dd = Math.sqrt(d2);
      // équation d'angle : gis(calc) - (V0 + hz) = 0 ; dérivées en grades
      var gisC = gisement({ x: X0, y: Y0 }, r.cible);
      var resA = normGr(gisC - (V0 + r.hz)); if (resA > 200) resA -= 400;
      var rowA = [rad2gr(dy / d2), rad2gr(-dx / d2), -1]; // d(gis)/dXs = -cos/ d ... signes : gis = atan2(dx,dy) avec dx = Xc - Xs
      // d gis / d Xs = -dy/d2 (rad) ; d gis / d Ys = dx/d2 (rad)
      rowA = [rad2gr(-dy / d2), rad2gr(dx / d2), -1];
      var wA = 1 / (sigA * sigA);
      for (var i = 0; i < 3; i++) { for (var j = 0; j < 3; j++) N[i][j] += wA * rowA[i] * rowA[j]; t[i] += wA * rowA[i] * (-resA); }
      if (r.useDist !== false && isNum(r.sd) && r.sd > 0) {
        var dh = r.sd * Math.sin(gr2rad(r.v));
        var resD = dd - dh;
        var rowD = [-dx / dd, -dy / dd, 0];
        var sd = sigD + ppm * 1e-6 * dh;
        var wD = 1 / (sd * sd);
        for (var i2 = 0; i2 < 3; i2++) { for (var j2 = 0; j2 < 3; j2++) N[i2][j2] += wD * rowD[i2] * rowD[j2]; t[i2] += wD * rowD[i2] * (-resD); }
      }
    });
    var dxv = solve(N, t);
    if (!dxv) return { ok: false, message: "Système singulier (références alignées ?)" };
    X0 += dxv[0]; Y0 += dxv[1]; V0 = normGr(V0 + dxv[2]);
    if (Math.abs(dxv[0]) < 1e-5 && Math.abs(dxv[1]) < 1e-5 && Math.abs(dxv[2]) < 1e-6) { converged = true; break; }
  }

  // --- Z ---
  var zs = [], zRes = [];
  refs.forEach(function (r) {
    if (r.exclue || r.useZ === false || !r.cible || !isNum(r.cible.z) || !isNum(r.sd)) return;
    var dz = r.sd * Math.cos(gr2rad(r.v));
    if (options.courbure) { var dh2 = r.sd * Math.sin(gr2rad(r.v)); dz += dh2 * dh2 * (1 - K_REFRACTION) / (2 * R_TERRE); }
    zs.push(r.cible.z + (isNum(r.hr) ? r.hr : 0) - dz - (isNum(hi) ? hi : 0));
  });
  var Z = NaN;
  if (zs.length) { Z = 0; zs.forEach(function (z) { Z += z; }); Z /= zs.length; }

  // --- résidus ---
  var st = { x: X0, y: Y0, z: Z, hi: hi };
  var residus = [], sp = 0, np = 0, sz = 0, nz = 0;
  refs.forEach(function (r) {
    if (!r.cible) return;
    var th = xyzToPolar(st, V0, r.cible, hi, r.hr);
    var dHz = normGr(r.hz - th.hz); if (dHz > 200) dHz -= 400;
    var dh = isNum(r.sd) ? r.sd * Math.sin(gr2rad(r.v)) : NaN;
    var dDist = isNum(dh) ? dh - th.dh : NaN;
    var p = polarToXYZ(st, V0, r, options);
    var dPlani = distH(p, r.cible);
    var dZ = (isNum(p.z) && isNum(r.cible.z)) ? p.z - r.cible.z : NaN;
    residus.push({ cible: r.cible.matricule || "", dHz: dHz, dDist: dDist, dPlani: dPlani, dZ: dZ, exclue: !!r.exclue });
    if (!r.exclue && r.useXY !== false) { sp += dPlani * dPlani; np++; }
    if (!r.exclue && r.useZ !== false && isNum(dZ)) { sz += dZ * dZ; nz++; }
  });
  return {
    ok: true, x: X0, y: Y0, z: Z, v0: V0,
    emq_plani: np ? Math.sqrt(sp / np) : NaN, emq_alti: nz ? Math.sqrt(sz / nz) : NaN,
    residus: residus, iterations: iter + 1, converged: converged, message: converged ? "" : "Convergence non atteinte"
  };
}

/* ------------------------------------------------------------------ */
/* Exports polaires                                                    */
/* ------------------------------------------------------------------ */

/** Ligne GSI16 Leica (WI 11 matricule, 21 Hz, 22 V, 31 Di, 87 hr, 88 hi). */
function gsi16(matricule, hz, v, sd, hr, hi) {
  function w(wi, val, mult) {
    var n = Math.round(val * mult);
    var s = Math.abs(n).toString();
    while (s.length < 16) s = "0" + s;
    return wi + "..1" + (n < 0 ? "-" : "+") + s;
  }
  var id = String(matricule);
  while (id.length < 16) id = "0" + id;
  var line = "*11....+" + id;
  if (isNum(hz)) line += " " + w("21", hz, 100000);
  if (isNum(v)) line += " " + w("22", v, 100000);
  if (isNum(sd)) line += " " + w("31", sd, 1000);
  if (isNum(hr)) line += " " + w("87", hr, 1000);
  if (isNum(hi)) line += " " + w("88", hi, 1000);
  return line + " ";
}
