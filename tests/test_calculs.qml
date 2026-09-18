import QtQuick 2.12
import "../plugin/topo/TopoCore.js" as Core
import "../plugin/topo/TopoCalc.js" as Topo

// Tests unitaires des bibliothèques de calcul (sans QField) :
//   cd C:\OSGeo4W\apps\Qt5\bin && qmlscene.exe <chemin>\tests\test_calculs.qml
Item {
  id: root
  property int failures: 0
  function check(name, cond, detail) { console.log((cond ? "OK   " : "FAIL ") + name + (detail !== undefined ? "  (" + detail + ")" : "")); if (!cond) failures++; }
  function near(a, b, tol) { return Math.abs(a - b) <= (tol || 1e-3); }

  Timer { running: true; interval: 10; onTriggered: root.run() }
  function run() {
    // --- Core : excentrements
    var ref = Core.pt(0, 0, 10), appui = Core.pt(0, 10, 12);
    var g = Core.excentParRapportAPoint(ref, appui, "gauche", 2);
    check("excent gauche", near(g.x, -2) && near(g.y, 10) && near(g.z, 12), g.x + "," + g.y);
    var d = Core.excentParRapportAPoint(ref, appui, "droite", 2);
    check("excent droite", near(d.x, 2) && near(d.y, 10));
    var av = Core.excentParRapportAPoint(ref, appui, "avant", 3);
    check("excent avant", near(av.x, 0) && near(av.y, 13));
    var pp = Core.excentPerpendiculaire(Core.pt(0, 0, 0), Core.pt(10, 0, 0), "gauche", 1.5);
    check("perpendiculaire gauche", near(pp.x, 10) && near(pp.y, 1.5));
    var dd = Core.excentDeuxDistances(Core.pt(0, 0, 0), Core.pt(10, 0, 0), 5 * Math.SQRT2, 5 * Math.SQRT2, "gauche");
    check("deux distances", dd && near(dd.x, 5) && near(dd.y, 5), dd ? dd.x + "," + dd.y : "null");
    var mi = Core.excentMilieu(Core.pt(0, 0, 10), Core.pt(2, 2, 12));
    check("milieu", near(mi.x, 1) && near(mi.y, 1) && near(mi.z, 11));

    // --- Core : arcs / courbes / polyligne
    var arc = Core.arc3Points(Core.pt(0, 0, 0), Core.pt(1, 1, 0), Core.pt(2, 0, 0));
    var last = arc[arc.length - 1];
    var mid = arc[Math.floor(arc.length / 2)];
    check("arc3 fin", near(last.x, 2) && near(last.y, 0));
    check("arc3 passe par le sommet", near(Core.dist2d(mid, Core.pt(1, 0, 0)), 1, 0.02), Core.dist2d(mid, Core.pt(1, 0, 0)));
    var arc2 = Core.arc2Points(Core.pt(0, 0, 0), Core.pt(2, 2, 0), 0);
    var l2 = arc2[arc2.length - 1];
    check("arc2 fin", near(l2.x, 2) && near(l2.y, 2));
    check("arc2 rayon 2 (centre 0,2)", arc2.every(function (p) { return near(Core.dist2d(p, Core.pt(0, 2, 0)), 2, 0.01); }));
    var poly = Core.buildPolyline([{ m: "1", x: 0, y: 0, z: 0, seg: "L" }, { m: "2", x: 1, y: 1, z: 0, seg: "A3m" }, { m: "3", x: 2, y: 0, z: 0, seg: "A3" }, { m: "4", x: 4, y: 0, z: 0, seg: "L" }], false);
    check("buildPolyline arc3 + ligne", poly.length > 6 && near(poly[poly.length - 1].x, 4), poly.length);
    var closed = Core.buildPolyline([{ x: 0, y: 0, z: 0 }, { x: 1, y: 0, z: 0 }, { x: 1, y: 1, z: 0 }], true);
    check("fermeture", closed.length === 4 && near(closed[3].x, 0));
    var off = Core.offsetPolyline([Core.pt(0, 0, 0), Core.pt(10, 0, 0)], 1);
    check("parallèle gauche", near(off[0].y, 1) && near(off[1].y, 1));
    var rect = Core.rectangleFrom2(Core.pt(0, 0, 0), Core.pt(4, 0, 0));
    check("rectangle 2 pts (carré à gauche)", near(rect[2].y, 4) && near(rect[3].x, 0));
    check("WKT ligne", Core.lineWkt([Core.pt(0, 0, 1), Core.pt(1, 1, 2)]).indexOf("LINESTRING Z (0.0000 0.0000 1.0000, 1.0000 1.0000 2.0000)") === 0);
    check("matricule suivant", Core.nextMatricule("1009") === "1010" && Core.nextMatricule("S.9") === "S.10" && Core.nextMatricule("P099") === "P100");

    // --- Topo : réduction polaire
    var st = { x: 1000, y: 2000, z: 100, hi: 1.5 };
    var p1 = Topo.polarToXYZ(st, 0, { hz: 0, v: 100, sd: 10, hr: 1.5 }, { courbure: false });
    check("polaire nord", near(p1.x, 1000) && near(p1.y, 2010) && near(p1.z, 100));
    var p2 = Topo.polarToXYZ(st, 0, { hz: 100, v: 100, sd: 10, hr: 2.0 }, { courbure: false });
    check("polaire est + hr", near(p2.x, 1010) && near(p2.y, 2000) && near(p2.z, 99.5));
    var p3 = Topo.polarToXYZ(st, 50, { hz: 50, v: 50, sd: 10, hr: 0 }, { courbure: false });
    check("polaire V0 + angle V", near(p3.x, 1010 * 0 + 1000 + 10 * Math.sin(Math.PI / 4)) && near(p3.z, 100 + 1.5 + 10 * Math.cos(Math.PI / 4)), p3.x + "," + p3.z);
    var back = Topo.xyzToPolar(st, 0, Core.pt(1010, 2000, 99.5), 1.5, 2.0);
    check("inverse polaire", near(back.hz, 100) && near(back.sd, 10) && near(back.v, 100), back.hz + "," + back.v + "," + back.sd);
    check("V0 depuis référence", near(Topo.v0FromReference(st, { x: 1000, y: 2010 }, 350), 50));
    check("moyenne V0 circulaire", near(Topo.meanV0([399, 1]), 0, 1e-6) || near(Topo.meanV0([399, 1]), 400, 1e-6));
    var dr = Topo.doubleRetournement({ hz: 10, v: 98, sd: 10, hr: 1 }, { hz: 210.002, v: 302.004, sd: 10.002 });
    check("double retournement", near(dr.hz, 10.001, 1e-4) && near(dr.v, 97.998, 1e-4) && near(dr.sd, 10.001, 1e-4), dr.hz + "," + dr.v);

    // --- Topo : station libre (résection) sur 3 références connues, station vraie (500, 500, 50), V0 vrai 30 gr, hi 1.6
    var truth = { x: 500, y: 500, z: 50, hi: 1.6 };
    var cibles = [{ matricule: "A", x: 600, y: 520, z: 52 }, { matricule: "B", x: 480, y: 650, z: 48 }, { matricule: "C", x: 380, y: 430, z: 51 }];
    var refs = cibles.map(function (c) { var o = Topo.xyzToPolar(truth, 30, c, 1.6, 1.3); return { cible: c, hz: o.hz, v: o.v, sd: o.sd, hr: 1.3 }; });
    var res = Topo.stationLibre(refs, 1.6, { courbure: false });
    check("station libre ok", res.ok, res.message);
    check("station libre X/Y", res.ok && near(res.x, 500, 0.002) && near(res.y, 500, 0.002), res.x + "," + res.y);
    check("station libre Z", res.ok && near(res.z, 50, 0.002), res.z);
    check("station libre V0", res.ok && near(res.v0, 30, 1e-4), res.v0);
    check("station libre EMQ ~0", res.ok && res.emq_plani < 0.002, res.emq_plani);
    // relèvement (angles seuls) sur 3 points
    var refsA = refs.map(function (r) { return { cible: r.cible, hz: r.hz, v: r.v, sd: NaN, hr: r.hr, useDist: false }; });
    var resA = Topo.stationLibre(refsA, 1.6, {});
    check("relèvement angles seuls", resA.ok && near(resA.x, 500, 0.01) && near(resA.y, 500, 0.01), resA.ok ? resA.x + "," + resA.y : resA.message);
    // GSI
    var gsi = Topo.gsi16("101", 123.4567, 98.7654, 45.678, 1.5, NaN);
    check("GSI16", gsi.indexOf("*11....+0000000000000101 21..1+0000000012345670 22..1+0000000009876540 31..1+0000000000045678 87..1+0000000000001500") === 0, gsi);

    console.log(failures === 0 ? "TOUS LES TESTS PASSENT" : (failures + " ÉCHEC(S)"));
    Qt.quit();
  }
}
