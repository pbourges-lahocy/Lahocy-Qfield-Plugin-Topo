# -*- coding: utf-8 -*-
"""
Convertit un thème du logiciel de référence (fichier <Theme>.mdb + dossiers Icone / Symb2d)
en catalogue d'objets générique pour le plugin QField "Topo" :

    theme/theme.json   (palettes, sous-palettes, objets, méthodes de placement)
    theme/icons/*.png  (icônes des boutons)

Usage (Windows, pilote ODBC Access requis) :
    python tools/topo_theme_to_json.py "<dossier du thème>" plugin/theme

Le thème produit est volontairement "générique" : aucune information de rendu
DWG (couleur, style de trait, épaisseur) n'est conservée, seul le nom du calque
le logiciel de référence est gardé dans "calque" pour faciliter la correspondance au bureau.
"""
import json
import os
import re
import shutil
import sys

import pyodbc

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    Image = None

# Type (PA_Objet.Type) -> famille
FAMILLES = {
    0: "lineaire",
    1: "talus",
    2: "symbole",
    3: "fonction",
    4: "cotation",
    5: "cadre",
    6: "texte",
    7: "entree",
    8: "escalier",
    9: "batiment",
}

# PA_MetLinArc.Mode -> primitive de départ
MODES_LINARC = {-1: "ligne", 0: "ligne", 1: "arc3", 2: "arc2", 3: "courbe"}

# PA_Methode.TypeObjetLineaire -> type de linéaire
TYPES_LINEAIRE = {
    0: "ligne_arc",
    1: "polyligne3d",
    2: "multiligne_triple",
    3: "multiligne_double",
    4: "rectangle",
    5: "cercle",
    6: "courbe3d",
}

# PA_Texte.Methode
METHODES_TEXTE = {0: "1pt", 1: "2pt", 2: "parallele"}


def safe_name(name):
    name = re.sub(r"[^A-Za-z0-9_\-]+", "_", name.strip())
    return name.strip("_") or "objet"


def connect(mdb_path):
    return pyodbc.connect(
        r"DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};DBQ=" + os.path.abspath(mdb_path)
    )


def rows(cur, sql):
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def placeholder_icon(path, label):
    """Icône de secours (initiales sur fond gris) si l'icône est absente."""
    if Image is None:
        return False
    im = Image.new("RGBA", (40, 40), (220, 220, 220, 255))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 39, 39], outline=(120, 120, 120, 255))
    txt = "".join(w[0] for w in re.split(r"[\s_]+", label) if w)[:3].upper() or "?"
    d.text((6, 13), txt, fill=(40, 40, 40, 255))
    im.save(path)
    return True


def main(theme_dir, out_dir):
    theme_name = os.path.basename(os.path.normpath(theme_dir))
    mdb = os.path.join(theme_dir, theme_name + ".mdb")
    if not os.path.exists(mdb):
        cands = [f for f in os.listdir(theme_dir) if f.lower().endswith(".mdb")]
        if not cands:
            sys.exit("Aucun fichier .mdb dans " + theme_dir)
        mdb = os.path.join(theme_dir, cands[0])

    icons_out = os.path.join(out_dir, "icons")
    os.makedirs(icons_out, exist_ok=True)

    cn = connect(mdb)
    cur = cn.cursor()

    objets = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Objet")}
    by_code = {r["CodeObjet"]: r for r in objets.values()}
    methode = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Methode")}
    lineaire = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Lineaire")}
    linarc = {r["IdObjet"]: r for r in rows(cur, "select * from PA_MetLinArc")}
    multil = {r["IdObjet"]: r for r in rows(cur, "select * from PA_MetMultiline")}
    symbole = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Symbole")}
    metsymb = {r["IdObjet"]: r for r in rows(cur, "select * from PA_MetSymbole")}
    texte = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Texte")}
    listes = {r["IdListe"]: r["NomListe"] for r in rows(cur, "select * from PA_ListeTxt")}
    liste_items = {}
    for r in rows(cur, "select * from PA_TexteAssoLst order by IdListe, NumOrdre"):
        liste_items.setdefault(r["IdListe"], []).append(r["Texte"])
    talus = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Talus")}
    mettalus = {r["IdObjet"]: r for r in rows(cur, "select * from PA_MetTalus")}
    entree = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Entree")}
    hachure = {r["IdObjet"]: r for r in rows(cur, "select * from PA_Hachurage")}
    try:
        escalier = {r["IdObjet"]: r for r in rows(cur, "select * from PA_MetEscalier")}
    except Exception:
        escalier = {}
    try:
        batiment = {r["IdObjet"]: r for r in rows(cur, "select * from PA_MetBatiment")}
    except Exception:
        batiment = {}
    palettes = {r["IdPalette"]: r for r in rows(cur, "select * from PA_Palette")}
    items = rows(cur, "select * from PA_PaletteItem order by IdPalette, Pos")

    used_icons = {}

    def copy_icon(chemin, nom, label):
        """Copie l'icône vers icons/ et renvoie son nom de fichier."""
        if not nom:
            return ""
        key = (chemin or "Icone", nom)
        if key in used_icons:
            return used_icons[key]
        if (chemin or "Icone") == "Icone":
            src = os.path.join(theme_dir, "Icone", nom + ".png")
        else:
            src = os.path.join(theme_dir, "Symb2d", chemin, "Icone", nom + ".png")
        dest_name = safe_name(((chemin + "_") if chemin and chemin != "Icone" else "") + nom) + ".png"
        dest = os.path.join(icons_out, dest_name)
        if os.path.exists(src):
            shutil.copyfile(src, dest)
        elif not placeholder_icon(dest, label):
            dest_name = ""
        used_icons[key] = dest_name
        return dest_name

    out_objets = {}
    for oid, o in objets.items():
        code = o["CodeObjet"]
        fam = FAMILLES.get(o["Type"], "lineaire")
        entry = {
            "code": code,
            "nom": o["NomObjet"] or code,
            "famille": fam,
            "libelle_audio": o["LibAudio"] or o["NomObjet"] or code,
            "calque": (o["Calque"] or "").strip() if (o["Calque"] or "") not in ("0", "") else "",
            "code_export": o["CodeExport"] or "",
            "icone": copy_icon(o["CheminIcone"], o["NomIcone"], o["NomObjet"] or code),
        }
        m = methode.get(oid, {})
        if fam == "lineaire":
            typ = TYPES_LINEAIRE.get(m.get("TypeObjetLineaire", 0), "ligne_arc")
            la = linarc.get(oid, {})
            li = lineaire.get(oid, {})
            meth = {
                "type": typ,
                "mode": MODES_LINARC.get(la.get("Mode", 0), "ligne"),
                "tangent": bool(la.get("FlagTangent", 0)),
                "ajust_debut": bool(li.get("FlagAjustDeb", 0)),
                "ajust_fin": bool(li.get("FlagAjustFin", 0)),
                "remplissage": bool(li.get("Remplissage", 0)),
            }
            if la.get("FlagDecalage"):
                meth["decalage"] = float(la.get("Decalage") or 0)
            ml = multil.get(oid)
            if ml:
                meth["type"] = "multiligne_triple" if ml.get("FlagTriple") else "multiligne_double"
                meth["largeur"] = float(ml.get("Ecart") or 0)
                meth["largeur_12"] = float(ml.get("Ecart12") or 0)
                meth["ligne_directrice"] = int(ml.get("PosLinDir") or 4)
                meth["fermeture_debut"] = bool(ml.get("FlagCloseStart", 0))
                meth["fermeture_fin"] = bool(ml.get("FlagCloseEnd", 0))
            entry["methode"] = meth
            # Si l'objet est un "chapeau" de catégorie (calque vide) il est
            # utilisé seulement comme bouton de palette principale.
            if not entry["calque"] and code.lower().startswith("cat"):
                entry["famille"] = "categorie"
        elif fam == "symbole":
            s = symbole.get(oid, {})
            ms = metsymb.get(oid, {})
            anc = [ms.get("Ancrage1", 9), ms.get("Ancrage2", -1), ms.get("Ancrage3", -1)]
            nb = 1 + (1 if anc[1] not in (None, -1) else 0) + (1 if anc[2] not in (None, -1) else 0)
            entry["symbole"] = {"famille_bloc": s.get("FamilleSymb", ""), "bloc": s.get("NomSymb", "")}
            entry["methode"] = {
                "points": nb,
                "ancrages": [a for a in anc if a not in (None, -1)],
                "verrou_largeur": bool(ms.get("FlagLargeur", 0)),
                "verrou_longueur": bool(ms.get("FlagLongueur", 0)),
                "largeur": float(ms.get("Largeur") or 0),
                "longueur": float(ms.get("Longueur") or 0),
            }
            if not entry["icone"] and s.get("NomSymb"):
                entry["icone"] = copy_icon(s.get("FamilleSymb"), s.get("NomSymb"), entry["nom"])
        elif fam == "texte":
            t = texte.get(oid, {})
            entry["methode"] = {
                "placement": METHODES_TEXTE.get(t.get("Methode", 0), "1pt"),
                "taille": float(t.get("Taille") or 1.0),
                "ancrage": int(t.get("PositionAncrage") or 6),
                "texte_defaut": t.get("Texte") or "",
                "liste": listes.get(t.get("IdListe"), "") if t.get("IdListe") else "",
            }
        elif fam == "talus":
            mt = mettalus.get(oid, {})
            entry["methode"] = {
                "mode": int(mt.get("Mode") or 0),
                "espace": float(mt.get("Espace") or 0.4),
                "nb_lignes": int(mt.get("NbrLignes") or 4),
                "pct_court": float(mt.get("PourCourt") or 35),
                "pct_long": float(mt.get("PourLong") or 90),
                "pct_inter": float(mt.get("PourInter") or 30),
            }
        elif fam == "entree":
            e = entree.get(oid, {})
            entry["methode"] = {
                "verrou": bool(e.get("FlagVerrou", 1)),
                "delimiteur_1": int(e.get("ModePot1") or 0),
                "delimiteur_2": int(e.get("ModePot2") or 0),
                "seuil": bool(e.get("FlagSeuil", 1)),
                "sens": int(e.get("SensFleche") or 0),
                "texte": e.get("Txt") or "",
            }
        elif fam == "escalier":
            es = escalier.get(oid, {})
            entry["methode"] = {
                "points": int(es.get("NbPoints") or 3) if es else 3,
                "calcul_marches": "nombre" if (es.get("Mode") or 0) == 0 else "profondeur",
                "valeur": float(es.get("Valeur") or 0) if es else 0,
                "fleche": True,
            }
        elif fam == "batiment":
            entry["methode"] = {"fuyante": "perpendiculaire", "longueur_fuyante": 1.0, "hachure": True}
        if oid in hachure:
            h = hachure[oid]
            entry["hachure"] = {"motif": h.get("Motif") or "", "echelle": float(h.get("Echelle") or 1)}
        out_objets[code] = entry

    # Listes de textes
    out_listes = {listes[k]: v for k, v in liste_items.items() if k in listes}

    # Palettes
    principale = [pid for pid, p in palettes.items() if p["Type"] == 1]
    principale_id = principale[0] if principale else min(palettes)
    items_by_pal = {}
    for it in items:
        items_by_pal.setdefault(it["IdPalette"], []).append(it)

    def build_sub(pid):
        out = []
        for it in items_by_pal.get(pid, []):
            code = it["CodeObjet"]
            o = by_code.get(code)
            if o is None:
                continue
            icone = copy_icon(it["CheminIcone"], it["NomIcone"], o["NomObjet"] or code)
            out.append({"pos": int(it["Pos"]), "objet": code, "icone": icone or out_objets[code]["icone"]})
        return out

    out_palette = []
    for it in items_by_pal.get(principale_id, []):
        code = it["CodeObjet"]
        o = by_code.get(code)
        if o is None:
            continue
        icone = copy_icon(it["CheminIcone"], it["NomIcone"], o["NomObjet"] or code)
        sub_id = it["IdSubPalette"] or 0
        bouton = {
            "pos": int(it["Pos"]),
            "code": code,
            "nom": o["NomObjet"] or code,
            "icone": icone or out_objets[code]["icone"],
            # appui long = exécution directe de l'objet si ce n'est pas un chapeau
            "objet": code if out_objets[code]["famille"] != "categorie" else "",
            "sous_palette": build_sub(sub_id) if sub_id else [],
        }
        out_palette.append(bouton)

    theme = {
        "nom": theme_name,
        "version": 1,
        "source": os.path.basename(mdb),
        "colonnes": 2,
        "palette": out_palette,
        "objets": out_objets,
        "listes_textes": out_listes,
    }
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "theme.json"), "w", encoding="utf-8") as f:
        json.dump(theme, f, ensure_ascii=False, indent=2)
    # Module JavaScript importé statiquement par le plugin (QField interdit la
    # lecture de fichiers locaux par XMLHttpRequest en dehors du projet).
    with open(os.path.join(out_dir, "theme.js"), "w", encoding="utf-8", newline="
") as f:
        f.write(".pragma library
// Généré par tools/topo_theme_to_json.py à partir de theme.json - ne pas éditer à la main.
")
        f.write("var THEME = " + json.dumps(theme, ensure_ascii=False, indent=1) + ";
")
    n_sub = sum(len(b["sous_palette"]) for b in out_palette)
    print(f"theme.json : {len(out_palette)} boutons principaux, {n_sub} boutons de sous-palettes, "
          f"{len(out_objets)} objets, {len(os.listdir(icons_out))} icônes -> {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
