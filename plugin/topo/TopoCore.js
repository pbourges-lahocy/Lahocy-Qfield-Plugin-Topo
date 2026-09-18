.pragma library
/*
 * TopoCore.js - calculs géométriques du plugin (équivalent Lahocy Topo)
 * Toutes les coordonnées sont en projection (mètres), objets {x, y, z}.
 */

var ARC_STEP_DEG = 5.0;     // pas angulaire de segmentation des arcs
var CURVE_SUBDIV = 8;       // subdivisions par segment de courbe lissée
var EPS = 1e-9;

function isNum(v) { return typeof v === "number" && !isNaN(v); }
function pt(x, y, z) { return { x: x, y: y, z: (isNum(z) ? z : NaN) }; }
function copyPt(p) { return pt(p.x, p.y, p.z); }

function dist2d(a, b) { return Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)); }
function dist3d(a, b) {
  var d = dist2d(a, b);
  if (isNum(a.z) && isNum(b.z)) return Math.sqrt(d * d + (b.z - a.z) * (b.z - a.z));
  return d;
}
// angle mathématique (radians, trigonométrique depuis l'axe X)
function angle(a, b) { return Math.atan2(b.y - a.y, b.x - a.x); }
// gisement en grades (0 = nord, sens horaire)
function gisementGr(a, b) {
  var g = Math.atan2(b.x - a.x, b.y - a.y) * 200.0 / Math.PI;
  return (g + 400) % 400;
}
// rotation QGIS : degrés sens horaire depuis le nord
function rotationDeg(a, b) {
  var d = Math.atan2(b.x - a.x, b.y - a.y) * 180.0 / Math.PI;
  return (d + 360) % 360;
}
function pointAt(a, ang, d, z) { return pt(a.x + d * Math.cos(ang), a.y + d * Math.sin(ang), isNum(z) ? z : a.z); }
function midpoint(a, b) {
  var z = (isNum(a.z) && isNum(b.z)) ? (a.z + b.z) / 2 : (isNum(a.z) ? a.z : b.z);
  return pt((a.x + b.x) / 2, (a.y + b.y) / 2, z);
}
function samePoint(a, b, tol) { return dist2d(a, b) < (tol || 0.001); }

/* ------------------------------------------------------------------ */
/* Excentrements                                                       */
/* ------------------------------------------------------------------ */

/**
 * Excentrement par rapport à un point : l'axe est ref -> appui.
 * direction : "avant" | "arriere" | "gauche" | "droite" ; d en mètres.
 * Résultat : point de même Z que l'appui.
 */
function excentParRapportAPoint(ref, appui, direction, d) {
  var a = angle(ref, appui);
  var da = 0;
  if (direction === "arriere") da = Math.PI;
  else if (direction === "gauche") da = Math.PI / 2;
  else if (direction === "droite") da = -Math.PI / 2;
  return pointAt(appui, a + da, d, appui.z);
}

/**
 * Perpendiculaire : p1 = point précédent de l'objet, p2 = position GNSS (appui).
 * side : "gauche" | "droite" par rapport au sens p1 -> p2. Résultat : p3 = p2 décalé.
 */
function excentPerpendiculaire(p1, p2, side, d) {
  var a = angle(p1, p2) + (side === "gauche" ? Math.PI / 2 : -Math.PI / 2);
  return pointAt(p2, a, d, p2.z);
}

/** Excentrement vertical : même XY, Z + dz (dz négatif vers le bas). */
function excentVertical(appui, dz) { return pt(appui.x, appui.y, isNum(appui.z) ? appui.z + dz : NaN); }

/** Excentrement milieu : deux appuis de part et d'autre. */
function excentMilieu(a, b) { return midpoint(a, b); }

/**
 * Excentrement par deux distances : intersection des cercles (a, ra) et (b, rb).
 * side : "gauche" | "droite" par rapport au sens a -> b. Z = moyenne.
 */
function excentDeuxDistances(a, b, ra, rb, side) {
  var d = dist2d(a, b);
  if (d < EPS || d > ra + rb + EPS || d < Math.abs(ra - rb) - EPS) return null;
  var x = (ra * ra - rb * rb + d * d) / (2 * d);
  var h2 = ra * ra - x * x;
  var h = h2 > 0 ? Math.sqrt(h2) : 0;
  var ux = (b.x - a.x) / d, uy = (b.y - a.y) / d;
  var px = a.x + x * ux, py = a.y + x * uy;
  var s = (side === "gauche") ? 1 : -1;
  var z = midpoint(a, b).z;
  return pt(px - s * h * uy, py + s * h * ux, z);
}

/* ------------------------------------------------------------------ */
/* Arcs, courbes, formes                                               */
/* ------------------------------------------------------------------ */

/** Centre du cercle passant par 3 points (null si alignés). */
function circleCenter(a, b, c) {
  var d = 2 * (a.x * (b.y - c.y) + b.x * (c.y - a.y) + c.x * (a.y - b.y));
  if (Math.abs(d) < 1e-12) return null;
  var a2 = a.x * a.x + a.y * a.y, b2 = b.x * b.x + b.y * b.y, c2 = c.x * c.x + c.y * c.y;
  var ux = (a2 * (b.y - c.y) + b2 * (c.y - a.y) + c2 * (a.y - b.y)) / d;
  var uy = (a2 * (c.x - b.x) + b2 * (a.x - c.x) + c2 * (b.x - a.x)) / d;
  return pt(ux, uy, NaN);
}

function lerpZ(z1, z2, t) {
  if (isNum(z1) && isNum(z2)) return z1 + (z2 - z1) * t;
  return isNum(z1) ? z1 : z2;
}

/**
 * Arc par 3 points (départ, intermédiaire, fin), segmenté. Renvoie les points
 * APRÈS le départ (le départ étant déjà dans la polyligne), fin incluse.
 */
function arc3Points(p1, pm, p2) {
  var c = circleCenter(p1, pm, p2);
  if (!c) return [copyPt(pm), copyPt(p2)];
  var r = dist2d(c, p1);
  var a1 = angle(c, p1), am = angle(c, pm), a2 = angle(c, p2);
  // sens de parcours : on passe par pm entre p1 et p2
  var ccw = ((am - a1 + 2 * Math.PI) % (2 * Math.PI)) < ((a2 - a1 + 2 * Math.PI) % (2 * Math.PI));
  var sweep = ccw ? ((a2 - a1 + 2 * Math.PI) % (2 * Math.PI)) : -((a1 - a2 + 2 * Math.PI) % (2 * Math.PI));
  var n = Math.max(2, Math.ceil(Math.abs(sweep) * 180 / Math.PI / ARC_STEP_DEG));
  var out = [];
  for (var i = 1; i <= n; i++) {
    var t = i / n;
    var a = a1 + sweep * t;
    out.push(pt(c.x + r * Math.cos(a), c.y + r * Math.sin(a), lerpZ(p1.z, p2.z, t)));
  }
  return out;
}

/**
 * Arc par 2 points tangent à la direction d'arrivée (tangentAngle, radians)
 * au point p1, se terminant en p2. Renvoie les points après p1, fin incluse.
 */
function arc2Points(p1, p2, tangentAngle) {
  var chord = dist2d(p1, p2);
  if (chord < EPS) return [copyPt(p2)];
  var chordAngle = angle(p1, p2);
  var theta = chordAngle - tangentAngle; // demi-angle au centre = theta ; angle balayé = 2 theta
  while (theta > Math.PI) theta -= 2 * Math.PI;
  while (theta < -Math.PI) theta += 2 * Math.PI;
  if (Math.abs(theta) < 1e-4 || Math.abs(Math.abs(theta) - Math.PI) < 1e-4) return [copyPt(p2)];
  var r = chord / (2 * Math.sin(Math.abs(theta)));
  var side = theta > 0 ? 1 : -1;
  var c = pointAt(p1, tangentAngle + side * Math.PI / 2, r, NaN);
  var a1 = angle(c, p1);
  var sweep = 2 * theta;
  var n = Math.max(2, Math.ceil(Math.abs(sweep) * 180 / Math.PI / ARC_STEP_DEG));
  var out = [];
  for (var i = 1; i <= n; i++) {
    var t = i / n;
    var a = a1 + sweep * t;
    out.push(pt(c.x + r * Math.cos(a), c.y + r * Math.sin(a), lerpZ(p1.z, p2.z, t)));
  }
  return out;
}

/** Courbe de Catmull-Rom passant par les points (lissage Topo "courbe lissée"). */
function catmullRom(points) {
  if (points.length < 3) return points.map(copyPt);
  var out = [copyPt(points[0])];
  for (var i = 0; i < points.length - 1; i++) {
    var p0 = points[Math.max(0, i - 1)], p1 = points[i], p2 = points[i + 1], p3 = points[Math.min(points.length - 1, i + 2)];
    for (var j = 1; j <= CURVE_SUBDIV; j++) {
      var t = j / CURVE_SUBDIV, t2 = t * t, t3 = t2 * t;
      var x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
      var y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
      out.push(pt(x, y, lerpZ(p1.z, p2.z, t)));
    }
  }
  return out;
}

/**
 * Construit la polyligne segmentée à partir de la liste des sommets levés.
 * Chaque sommet : { m: matricule, x, y, z, seg: "L" | "A3m" | "A3" | "A2" | "C" }
 *  - "L"   : segment droit depuis le sommet précédent
 *  - "A3m" : point intermédiaire d'un arc 3 points (attend un sommet "A3")
 *  - "A3"  : fin d'arc 3 points
 *  - "A2"  : fin d'arc 2 points, tangent à la direction précédente
 *  - "C"   : sommet de courbe lissée (les suites de "C" sont lissées ensemble)
 * closed : fermeture sur le premier point.
 */
function buildPolyline(vertices, closed) {
  var out = [];
  var i = 0;
  var pendingMid = null;
  var lastTangent = NaN;
  while (i < vertices.length) {
    var v = vertices[i];
    var seg = v.seg || "L";
    if (out.length === 0) {
      out.push(pt(v.x, v.y, v.z));
      i++;
      continue;
    }
    var prev = out[out.length - 1];
    if (seg === "A3m") {
      pendingMid = v;
      // si aucun sommet de fin, on trace provisoirement une ligne
      if (i === vertices.length - 1) out.push(pt(v.x, v.y, v.z));
      i++;
      continue;
    }
    if (seg === "A3" && pendingMid) {
      var arc = arc3Points(prev, pendingMid, v);
      out = out.concat(arc);
      pendingMid = null;
      if (arc.length >= 2) lastTangent = angle(arc[arc.length - 2], arc[arc.length - 1]);
      i++;
      continue;
    }
    if (seg === "A2" && isNum(lastTangent)) {
      var arc2 = arc2Points(prev, v, lastTangent);
      out = out.concat(arc2);
      if (arc2.length >= 2) lastTangent = angle(arc2[arc2.length - 2], arc2[arc2.length - 1]);
      else lastTangent = angle(prev, v);
      i++;
      continue;
    }
    if (seg === "C") {
      // regrouper la suite de sommets "C" (en incluant le point précédent)
      var group = [prev];
      var j = i;
      while (j < vertices.length && (vertices[j].seg || "L") === "C") {
        group.push(pt(vertices[j].x, vertices[j].y, vertices[j].z));
        j++;
      }
      var curve = catmullRom(group);
      out = out.concat(curve.slice(1));
      lastTangent = angle(curve[curve.length - 2], curve[curve.length - 1]);
      i = j;
      continue;
    }
    // segment droit (ou repli)
    out.push(pt(v.x, v.y, v.z));
    lastTangent = angle(prev, v);
    i++;
  }
  if (closed && out.length >= 3 && !samePoint(out[0], out[out.length - 1])) out.push(copyPt(out[0]));
  return out;
}

/** Direction tangente en fin de polyligne (radians) ou NaN. */
function endTangent(points) {
  if (points.length < 2) return NaN;
  return angle(points[points.length - 2], points[points.length - 1]);
}

/** Polyligne parallèle décalée de d (d > 0 : à gauche du sens de parcours). */
function offsetPolyline(points, d) {
  var n = points.length;
  if (n === 0) return [];
  if (n === 1) return [copyPt(points[0])];
  var out = [];
  for (var i = 0; i < n; i++) {
    var aIn = i > 0 ? angle(points[i - 1], points[i]) : angle(points[i], points[i + 1]);
    var aOut = i < n - 1 ? angle(points[i], points[i + 1]) : aIn;
    var nx1 = -Math.sin(aIn), ny1 = Math.cos(aIn);
    var nx2 = -Math.sin(aOut), ny2 = Math.cos(aOut);
    var bx = nx1 + nx2, by = ny1 + ny2;
    var bl = Math.sqrt(bx * bx + by * by);
    var x, y;
    if (bl < 1e-6) { x = points[i].x + d * nx1; y = points[i].y + d * ny1; }
    else {
      bx /= bl; by /= bl;
      var cosHalf = bx * nx1 + by * ny1;
      var k = Math.abs(cosHalf) > 0.2 ? d / cosHalf : d; // limite de l'allongement dans les angles aigus
      x = points[i].x + k * bx; y = points[i].y + k * by;
    }
    out.push(pt(x, y, points[i].z));
  }
  return out;
}

/** Carré / rectangle par 2 points (côté p1-p2, placé à gauche du sens de saisie). */
function rectangleFrom2(p1, p2) {
  var a = angle(p1, p2), d = dist2d(p1, p2);
  var p3 = pointAt(p2, a + Math.PI / 2, d, p1.z);
  var p4 = pointAt(p1, a + Math.PI / 2, d, p1.z);
  return [copyPt(p1), pt(p2.x, p2.y, p1.z), p3, p4, copyPt(p1)];
}

/** Rectangle par 3 points : côté p1-p2 puis largeur donnée par la projection de p3. */
function rectangleFrom3(p1, p2, p3) {
  var a = angle(p1, p2);
  var nx = -Math.sin(a), ny = Math.cos(a);
  var w = (p3.x - p2.x) * nx + (p3.y - p2.y) * ny; // distance signée
  var q3 = pt(p2.x + w * nx, p2.y + w * ny, p1.z);
  var q4 = pt(p1.x + w * nx, p1.y + w * ny, p1.z);
  return [copyPt(p1), pt(p2.x, p2.y, p1.z), q3, q4, copyPt(p1)];
}

function circlePolygon(c, r, z) {
  var n = 72, out = [];
  for (var i = 0; i <= n; i++) {
    var a = 2 * Math.PI * i / n;
    out.push(pt(c.x + r * Math.cos(a), c.y + r * Math.sin(a), isNum(z) ? z : c.z));
  }
  return out;
}

function circleFrom3(a, b, c) {
  var ctr = circleCenter(a, b, c);
  if (!ctr) return null;
  return { center: pt(ctr.x, ctr.y, a.z), radius: dist2d(ctr, a) };
}

/** Projection orthogonale de p sur le segment [a,b] (borné). */
function projectOnSegment(p, a, b) {
  var dx = b.x - a.x, dy = b.y - a.y;
  var l2 = dx * dx + dy * dy;
  if (l2 < EPS) return copyPt(a);
  var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2;
  t = Math.max(0, Math.min(1, t));
  return pt(a.x + t * dx, a.y + t * dy, lerpZ(a.z, b.z, t));
}

/** Point le plus proche de p sur une polyligne ; renvoie {point, dist, index}. */
function nearestOnPolyline(p, points) {
  var best = null;
  for (var i = 0; i < points.length - 1; i++) {
    var q = projectOnSegment(p, points[i], points[i + 1]);
    var d = dist2d(p, q);
    if (!best || d < best.dist) best = { point: q, dist: d, index: i };
  }
  if (!best && points.length === 1) best = { point: copyPt(points[0]), dist: dist2d(p, points[0]), index: 0 };
  return best;
}

/** Longueur 2D d'une polyligne. */
function length2d(points) {
  var l = 0;
  for (var i = 1; i < points.length; i++) l += dist2d(points[i - 1], points[i]);
  return l;
}

/* ------------------------------------------------------------------ */
/* WKT                                                                 */
/* ------------------------------------------------------------------ */

function fmtZ(z) { return isNum(z) ? z.toFixed(4) : "0"; }
function coordStr(p) { return p.x.toFixed(4) + " " + p.y.toFixed(4) + " " + fmtZ(p.z); }

function pointWkt(p) { return "POINT Z (" + coordStr(p) + ")"; }
function lineWkt(points) {
  if (points.length < 2) return "";
  return "LINESTRING Z (" + points.map(coordStr).join(", ") + ")";
}
function polygonWkt(points) {
  if (points.length < 3) return "";
  var ring = points.slice();
  if (!samePoint(ring[0], ring[ring.length - 1])) ring.push(copyPt(ring[0]));
  return "POLYGON Z ((" + ring.map(coordStr).join(", ") + "))";
}

/* ------------------------------------------------------------------ */
/* Divers                                                              */
/* ------------------------------------------------------------------ */

function fmt(v, dec) { return isNum(v) ? v.toFixed(dec === undefined ? 3 : dec) : "-"; }
function nowIso() {
  var d = new Date();
  function p(n) { return (n < 10 ? "0" : "") + n; }
  return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" + p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds());
}
function stampFile() {
  var d = new Date();
  function p(n) { return (n < 10 ? "0" : "") + n; }
  return "" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate()) + "_" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds());
}

/** Incrémente la partie numérique finale d'un matricule ("1001" -> "1002", "P12" -> "P13"). */
function nextMatricule(m) {
  var s = String(m || "1000");
  var match = s.match(/^(.*?)(\d+)$/);
  if (!match) return s + "1";
  var num = String(parseInt(match[2], 10) + 1);
  while (num.length < match[2].length) num = "0" + num;
  return match[1] + num;
}

/** Description de la qualité GGA (fix quality NMEA). */
function fixLabel(q) {
  switch (q) {
    case 0: return "Pas de fix";
    case 1: return "Autonome";
    case 2: return "DGPS";
    case 3: return "PPS";
    case 4: return "RTK fixe";
    case 5: return "RTK flottant";
    case 6: return "Estimé";
    default: return "Fix " + q;
  }
}
