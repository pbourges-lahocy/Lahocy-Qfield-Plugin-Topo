# -*- coding: utf-8 -*-
"""
Convertit le standard topographique régional GéoBretagne (nomenclature CSV + DXF
des blocs + images) en catalogue du plugin : plugin/theme/theme.json, theme.js et
icônes plugin/theme/icons/<ID>.png.

    python tools/geobretagne_to_theme.py "<dossier du standard>" plugin/theme [--rules tools/geobretagne_rules.json]

Le dossier du standard est celui de l'archive geobretagne_standard_topographique_x_y_z
(sous-dossier nomenclature/ avec standard_topographique_nomenclature.csv et .dxf, img/).

Règles de dérivation de la méthode de levé (le standard décrit le dessin, pas la saisie) :
  - Polyligne            -> linéaire (ligne / arc)
  - Hachures             -> linéaire fermé avec remplissage (motif = ID du standard)
  - Bloc « texte »       -> texte (1 point)
  - Bloc avec longueur   -> symbole 2 points (orienté)
  - autre Bloc           -> symbole 1 point
  - Dimension            -> ignoré
Le fichier de règles (JSON, {ID: {...}}) surcharge n'importe quel champ d'un objet.
"""
import argparse
import collections
import csv
import io
import json
import os
import re
import shutil
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

META_TAGS = {"ID", "NATURE", "FAMILLE", "CALQUE", "PCRS", "CALQUE_ALT", "CALQUE_MAT", "X=", "Y="}
GROUPES = ["Surface", "Sous-sol", "Information"]

# icône de famille (theme/ui) par lettre du standard
FAM_UI = {
    "A": "fam_eau", "B": "fam_eau_pluviale", "C": "fam_eau_usee", "D": "fam_unitaire", "E": "fam_chauffage",
    "F": "fam_elec", "G": "fam_eclairage", "H": "fam_panneaux", "I": "fam_ptt", "J": "fam_gaz",
    "K": "fam_indetermine", "L": "fam_voirie", "M": "fam_marquage", "N": "fam_mobilier", "O": "fam_nivellement",
    "P": "fam_sncf", "Q": "fam_transport", "R": "fam_bati", "S": "fam_cloture", "T": "fam_vegetation",
    "U": "fam_sport", "V": "fam_propriete", "W": "fam_hydro", "X": "fam_maritime", "Y": "fam_sigt", "Z": "fam_texte",
}

TEXTE_RE = re.compile(r"^(texte|nom |num[ée]ro|symbole texte|libell)", re.I)


def read_rows(csv_path):
    with open(csv_path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def parse_dxf_attributes(dxf_path):
    """Tags ATTDEF de chaque bloc du DXF de nomenclature : {ID: [tags]}."""
    out = {}
    if not os.path.exists(dxf_path):
        return out
    with open(dxf_path, encoding="latin-1") as f:
        lines = f.read().split("\n")
    i, cur = 0, None
    n = len(lines) - 1
    while i < n:
        code, val = lines[i].strip(), lines[i + 1].strip()
        if code == "0" and val == "BLOCK":
            j, cur = i + 2, None
            while j < n and lines[j].strip() != "0":
                if lines[j].strip() == "2":
                    cur = lines[j + 1].strip()
                j += 2
            if cur:
                out.setdefault(cur, [])
        elif code == "0" and val == "ENDBLK":
            cur = None
        elif code == "0" and val == "ATTDEF" and cur:
            j, tag = i + 2, None
            while j < n and lines[j].strip() != "0":
                if lines[j].strip() == "2":
                    tag = lines[j + 1].strip()
                j += 2
            if tag and tag not in META_TAGS and tag not in out[cur]:
                out[cur].append(tag)
        i += 2
    return out


def parse_docx_rules(docx_path):
    """Règles de levé du carnet des objets (docx) : {ID: {plani, alti, points}}.
    Ex. « 2 points: 1er axe, 2ème orientation », « 3 points, 2 premiers sur grand côté »,
    « Segments rectilignes levés en axe », altimétrie « 1er sur trottoir, 2ème fil d'eau »."""
    import zipfile
    out = {}
    if not os.path.exists(docx_path):
        return out
    doc = zipfile.ZipFile(docx_path).read("word/document.xml").decode("utf-8", "replace")
    txt = re.sub(r"<[^>]+>", " ", doc)
    txt = re.sub(r"\s+", " ", txt)
    pat = re.compile(r"([A-Z]{2})_ ?(\d{4})\s*:\s*(.*?)\s*Planimétrie\s*(.*?)\s*Précision XY\s*(.*?)\s*Altimétrie\s*(.*?)\s*Précision Z", re.S)
    for m in pat.finditer(txt):
        oid = m.group(1) + "_" + m.group(2)
        plani = m.group(4).strip().replace(" - ", "")
        alti = m.group(6).strip()
        n = re.search(r"(\d)\s*points?", plani)
        out[oid] = {"plani": plani, "alti": alti, "points": int(n.group(1)) if n else None}
    return out


def make_icon(jpg_path, png_path, size=96):
    """Recadre le dessin (fond blanc) de la vignette du standard en icône carrée."""
    from PIL import Image, ImageOps
    im = Image.open(jpg_path).convert("L")
    bbox = ImageOps.invert(im).point(lambda v: 255 if v > 40 else 0).getbbox()
    if not bbox:
        return False
    x0, y0, x1, y1 = bbox
    w, h = x1 - x0, y1 - y0
    side = int(max(w, h) * 1.15) + 8
    # dessin très allongé (type de ligne, texte) : on garde une portion centrale
    # carrée pour que le motif reste lisible une fois réduit
    if w > 3 * h:
        side = int(h * 3.2) + 16
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    box = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    canvas = Image.new("L", (side, side), 255)
    crop = im.crop(box)
    canvas.paste(crop, (0, 0))
    canvas = canvas.resize((size, size), Image.LANCZOS)
    canvas.convert("RGB").save(png_path, "PNG", optimize=True)
    return True


def main():
    ap = argparse.ArgumentParser(description="GéoBretagne -> catalogue Lahocy Topo")
    ap.add_argument("standard")
    ap.add_argument("theme_dir")
    ap.add_argument("--rules", default=os.path.join(os.path.dirname(__file__), "geobretagne_rules.json"))
    ap.add_argument("--no-icons", action="store_true")
    args = ap.parse_args()

    nom = os.path.join(args.standard, "nomenclature")
    rows = read_rows(os.path.join(nom, "standard_topographique_nomenclature.csv"))
    attrs = parse_dxf_attributes(os.path.join(nom, "standard_topographique_nomenclature.dxf"))
    docx_rules = parse_docx_rules(os.path.join(nom, "standard_topographique_nomenclature.docx"))
    rules = {}
    if os.path.exists(args.rules):
        rules = json.load(open(args.rules, encoding="utf-8"))
    version = re.search(r"(\d+)_(\d+)_(\d+)", os.path.basename(os.path.normpath(args.standard)))
    version_txt = ".".join(version.groups()) if version else ""

    img_dirs = {}
    img_root = os.path.join(nom, "img")
    for d in os.listdir(img_root):
        if os.path.isdir(os.path.join(img_root, d)) and len(d) > 2 and d[1] == "_":
            img_dirs[d[0]] = os.path.join(img_root, d)

    icons_dir = os.path.join(args.theme_dir, "icons")
    if not args.no_icons:
        if os.path.isdir(icons_dir):
            shutil.rmtree(icons_dir)
        os.makedirs(icons_dir, exist_ok=True)

    objets = {}
    familles = collections.OrderedDict()
    stats = collections.Counter()
    for r in rows:
        oid = r["id"].strip()
        if not re.match(r"^[A-Z][A-Z]_\d{4}$", oid):
            continue
        lettre = oid[0]
        nature = r["type d'objet"].strip()
        typ = r["type"].strip()
        placement = r["placement"].strip() or "Surface"
        famille_gb = r["famille"].strip()
        familles.setdefault(lettre, famille_gb)
        if typ == "Dimension":
            stats["ignores"] += 1
            continue

        longueur = (r.get("longueur_block") or "").strip().replace(",", ".")
        has_len = longueur not in ("", "nc")
        alt = [a.strip() for a in (r.get("attributs altitude") or "").split(",") if a.strip()]
        dr = docx_rules.get(oid, {})
        plani = dr.get("plani", "")
        gb = {
            "id": oid, "nature": nature, "famille": famille_gb, "type": typ, "calque": r["calque"].strip(),
            "pcrs": r["pcrs"].strip(), "placement": placement, "attributs": attrs.get(oid, []), "altitudes": alt,
            "longueur": float(longueur) if has_len else None, "plani": plani, "alti": dr.get("alti", ""),
        }

        o = {"code": oid, "nom": nature, "libelle_audio": nature, "calque": gb["calque"], "code_export": oid, "icone": "", "gb": gb}
        lp = plani.lower()
        if typ == "Polyligne":
            o["famille"] = "lineaire"
            o["methode"] = {"type": "ligne_arc", "mode": "ligne", "tangent": False, "ajust_debut": False, "ajust_fin": False, "remplissage": False}
            stats["lineaire"] += 1
        elif typ == "Hachures":
            o["famille"] = "lineaire"
            o["methode"] = {"type": "ligne_arc", "mode": "ligne", "tangent": False, "ajust_debut": False, "ajust_fin": False, "remplissage": True}
            o["hachure"] = {"motif": oid, "echelle": 1.0}
            stats["hachure"] += 1
        elif TEXTE_RE.search(nature) or (placement == "Information" and "texte" in nature.lower()):
            o["famille"] = "texte"
            o["methode"] = {"placement": "1pt", "taille": 2.5, "ancrage": 6, "texte_defaut": "", "liste": ""}
            stats["texte"] += 1
        else:
            pts = dr.get("points") or (2 if has_len else 1)
            if pts == 3 and "escalier" in nature.lower():
                o["famille"] = "escalier"
                o["methode"] = {"points": 3, "calcul_marches": "nombre", "valeur": 0.0, "fleche": True}
                stats["escalier"] += 1
            elif pts == 3 and ("grand c" in lp or "angle" in lp):
                # rectangle levé par 3 points (2 sur le grand côté, le 3e sur le côté opposé)
                o["famille"] = "lineaire"
                o["methode"] = {"type": "rectangle", "points": 3, "mode": "rectangle", "remplissage": False}
                stats["rectangle_3pt"] += 1
            else:
                o["famille"] = "symbole"
                o["symbole"] = {"famille_bloc": "GeoBretagne", "bloc": oid}
                o["methode"] = {"points": pts, "ancrages": [9] if pts == 1 else [10, 11, 12][:pts], "verrou_largeur": False,
                                "verrou_longueur": False, "largeur": 0.0, "longueur": gb["longueur"] or 0.0}
                stats["symbole_%dpt" % pts] += 1

        # icône
        if not args.no_icons and lettre in img_dirs:
            jpg = os.path.join(img_dirs[lettre], oid + ".jpg")
            if os.path.exists(jpg):
                try:
                    if make_icon(jpg, os.path.join(icons_dir, oid + ".png")):
                        o["icone"] = oid + ".png"
                except Exception as e:  # pragma: no cover
                    print("icône", oid, ":", e)
        elif args.no_icons:
            o["icone"] = oid + ".png"

        # surcharges
        for k, v in rules.get(oid, {}).items():
            if isinstance(v, dict) and isinstance(o.get(k), dict):
                o[k].update(v)
            else:
                o[k] = v
        objets[oid] = o

    # palette : une famille par lettre, sous-palette groupée Surface / Sous-sol / Information
    palette = []
    for pos, (lettre, nom_fam) in enumerate(sorted(familles.items())):
        code = "GB_" + lettre
        objets[code] = {"code": code, "nom": nom_fam, "famille": "categorie", "libelle_audio": nom_fam, "calque": "", "code_export": "", "icone": "", "methode": {}}
        items = [o for o in objets.values() if o.get("gb") and o["gb"]["id"][0] == lettre]
        items.sort(key=lambda o: (GROUPES.index(o["gb"]["placement"]) if o["gb"]["placement"] in GROUPES else 9, o["gb"]["id"]))
        sous = [{"pos": i, "objet": o["code"], "icone": o["icone"], "groupe": o["gb"]["placement"]} for i, o in enumerate(items)]
        palette.append({"pos": pos, "code": code, "nom": nom_fam, "icone": "", "ui": FAM_UI.get(lettre, "fam_objet"), "objet": "", "sous_palette": sous})

    theme = {
        "nom": "GéoBretagne – standard topographique " + version_txt,
        "version": 2,
        "source": "https://github.com/geobretagne/standard-topographique (v" + version_txt + ")",
        "colonnes": 4,
        "palette": palette,
        "objets": objets,
        "listes_textes": {},
    }
    os.makedirs(args.theme_dir, exist_ok=True)
    with open(os.path.join(args.theme_dir, "theme.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(theme, f, ensure_ascii=False, indent=1)
    with open(os.path.join(args.theme_dir, "theme.js"), "w", encoding="utf-8", newline="\n") as f:
        f.write(".pragma library\n// Généré par tools/geobretagne_to_theme.py : ne pas modifier à la main.\nvar THEME = ")
        json.dump(theme, f, ensure_ascii=False, separators=(",", ":"))
        f.write(";\n")
    print("familles :", len(palette), " objets :", len([o for o in objets.values() if o.get("gb")]), " ", dict(stats))
    print("règles de levé (docx) :", len(docx_rules), " attributs (dxf) :", len([a for a in attrs.values() if a]))
    print("icônes :", len([o for o in objets.values() if o.get("icone")]))
    print("écrit dans", args.theme_dir)


if __name__ == "__main__":
    main()
