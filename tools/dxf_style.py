# -*- coding: utf-8 -*-
"""
Styles du standard GéoBretagne : couleur et épaisseur par calque (table LAYER du DXF),
types de ligne (table LTYPE : tirets, textes intégrés « aep »), motifs de hachures
(fichiers .pat), nuancier des familles (.acb).
"""
import glob
import os
import re


# ------------------------------------------------------------------ couleurs AutoCAD (ACI)

def aci_rgb(i):
    """Index de couleur AutoCAD -> (r, g, b). 7 (blanc/noir) est rendu noir (plan sur fond blanc)."""
    base = {1: (255, 0, 0), 2: (255, 255, 0), 3: (0, 255, 0), 4: (0, 255, 255), 5: (0, 0, 255),
            6: (255, 0, 255), 7: (0, 0, 0), 8: (128, 128, 128), 9: (192, 192, 192)}
    if i in base:
        return base[i]
    if 10 <= i <= 249:
        hue = ((i - 10) // 10) * 15
        k = (i % 10) // 2
        pale = i % 2 == 1
        val = [1.0, 0.65, 0.5, 0.3, 0.15][k]
        h = hue / 60.0
        x = 1 - abs(h % 2 - 1)
        r, g, b = [(1, x, 0), (x, 1, 0), (0, 1, x), (0, x, 1), (x, 0, 1), (1, 0, x)][int(h) % 6]
        if pale:
            r, g, b = (0.5 + 0.5 * r, 0.5 + 0.5 * g, 0.5 + 0.5 * b)
        return tuple(int(round(v * val * 255)) for v in (r, g, b))
    if 250 <= i <= 255:
        g = [51, 80, 105, 130, 190, 255][i - 250]
        return (g, g, g)
    return (0, 0, 0)


def hexcolor(rgb):
    return "#%02x%02x%02x" % rgb


def fix_text(s):
    """Le DXF est lu en latin-1 mais ses textes sont encodés en UTF-8 (« Â» » -> « » »)."""
    try:
        return s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s


# ------------------------------------------------------------------ tables du DXF

def _tables(lines, name):
    """Entrées (listes de couples) d'une table du DXF (LAYER, LTYPE)."""
    out = []
    n = len(lines) - 1
    i = 0
    while i < n:
        if lines[i].strip() == "0" and lines[i + 1].strip() == "TABLE":
            j = i + 2
            tname = None
            while j < n and lines[j].strip() != "0":
                if lines[j].strip() == "2":
                    tname = lines[j + 1].strip()
                j += 2
            if tname == name:
                m = j
                while m < n and not (lines[m].strip() == "0" and lines[m + 1].strip() == "ENDTAB"):
                    if lines[m].strip() == "0" and lines[m + 1].strip() == name:
                        pairs = []
                        q = m + 2
                        while q < n and lines[q].strip() != "0":
                            pairs.append((lines[q].strip(), lines[q + 1].strip()))
                            q += 2
                        out.append(pairs)
                        m = q
                        continue
                    m += 2
                return out
            i = j
            continue
        i += 2
    return out


def read_layers(lines):
    """{calque: {couleur: '#rrggbb', epaisseur_mm: float, ltype: str}}"""
    out = {}
    for pairs in _tables(lines, "LAYER"):
        d = dict(pairs)
        name = d.get("2", "")
        if "420" in d:
            v = int(d["420"])
            rgb = ((v >> 16) & 255, (v >> 8) & 255, v & 255)
        else:
            rgb = aci_rgb(abs(int(d.get("62", "7"))))
        lw = int(d.get("370", "25"))
        out[name] = {"couleur": hexcolor(rgb), "epaisseur_mm": (lw / 100.0) if lw > 0 else 0.25, "ltype": d.get("6", "Continuous")}
    return out


def read_linetypes(lines):
    """{nom: {longueur, elements: [{len, type: 'dash'|'text', text, echelle, rot, x, y}]}} (lecture séquentielle)."""
    out = {}
    for pairs in _tables(lines, "LTYPE"):
        name = next((v for c, v in pairs if c == "2"), "")
        total = float(next((v for c, v in pairs if c == "40"), "0") or 0)
        elems = []
        cur = None
        for c, v in pairs:
            if c == "49":
                cur = {"len": float(v), "type": "dash", "text": "", "echelle": 1.0, "rot": 0.0, "x": 0.0, "y": 0.0}
                elems.append(cur)
            elif cur is not None:
                if c == "74":
                    t = int(v)
                    cur["type"] = "text" if t & 2 else ("shape" if t & 4 else "dash")
                elif c == "46":
                    cur["echelle"] = float(v)
                elif c == "50":
                    cur["rot"] = float(v)
                elif c == "44":
                    cur["x"] = float(v)
                elif c == "45":
                    cur["y"] = float(v)
                elif c == "9":
                    cur["text"] = fix_text(v)
        continu = all(e["len"] >= 0 and e["type"] == "dash" for e in elems)
        out[name] = {"longueur": total, "elements": elems, "continu": continu}
    return out


# ------------------------------------------------------------------ hachures (.pat)

def read_patterns(style_dir):
    """Motifs de hachures de tous les .pat du dossier : {NOM: [[angle, x0, y0, dx, dy, tirets...], ...]}."""
    out = {}
    for path in sorted(glob.glob(os.path.join(style_dir, "*.pat"))):
        try:
            txt = open(path, encoding="latin-1").read()
        except OSError:
            continue
        name = None
        for raw in txt.splitlines():
            s = raw.strip()
            if not s or s.startswith(";"):
                continue
            if s.startswith("*"):
                name = s[1:].split(",")[0].strip()
                out[name] = []
                continue
            if name is None:
                continue
            try:
                vals = [float(v) for v in re.split(r"[,\s]+", s) if v]
            except ValueError:
                continue
            if len(vals) >= 5:
                out[name].append(vals)
    return {k: v for k, v in out.items() if v}


def read_hatch_scales(lines):
    """Échelle et angle des hachures du dessin d'exemple : {motif: (echelle, angle)}."""
    n = len(lines) - 1
    i = 0
    while i < n and not (lines[i].strip() == "2" and lines[i + 1].strip() == "ENTITIES"):
        i += 2
    out = {}
    j = i + 2
    while j < n and not (lines[j].strip() == "0" and lines[j + 1].strip() == "ENDSEC"):
        if lines[j].strip() == "0":
            typ = lines[j + 1].strip()
            d = {}
            q = j + 2
            while q < n and lines[q].strip() != "0":
                d.setdefault(lines[q].strip(), lines[q + 1].strip())
                q += 2
            if typ == "HATCH" and d.get("2"):
                out.setdefault(d["2"], (float(d.get("41", "1") or 1), float(d.get("52", "0") or 0)))
            j = q
            continue
        j += 2
    return out


# ------------------------------------------------------------------ nuancier (.acb)

def read_colorbook(path):
    """{lettre de famille: '#rrggbb'} d'après les noms « A_Eau potable_140 »."""
    out = {}
    if not os.path.exists(path):
        return out
    txt = open(path, encoding="utf-8-sig", errors="replace").read()
    for name, r, g, b in re.findall(r"<colorName>([^<]+)</colorName>\s*<RGB8>\s*<red>(\d+)</red>\s*<green>(\d+)</green>\s*<blue>(\d+)</blue>", txt):
        m = re.match(r"^([A-Z])_", name)
        if m:
            out[m.group(1)] = hexcolor((int(r), int(g), int(b)))
    return out


def load_all(dxf_path, style_dir):
    lines = open(dxf_path, encoding="latin-1").read().split("\n")
    return {
        "layers": read_layers(lines),
        "ltypes": read_linetypes(lines),
        "patterns": read_patterns(style_dir),
        "hatch_scales": read_hatch_scales(lines),
        "families": read_colorbook(os.path.join(style_dir, "couleurs_standard.acb")),
    }


if __name__ == "__main__":
    import io
    import json
    import sys
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    s = load_all(sys.argv[1], sys.argv[2])
    print("calques", len(s["layers"]), "types de ligne", len(s["ltypes"]), "motifs", len(s["patterns"]), "familles", len(s["families"]))
    print(json.dumps(s["layers"].get("EAUPO_SCS"), ensure_ascii=False), json.dumps(s["ltypes"].get("AL_0021"), ensure_ascii=False)[:300])
