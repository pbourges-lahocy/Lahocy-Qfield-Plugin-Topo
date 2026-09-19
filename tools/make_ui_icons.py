# -*- coding: utf-8 -*-
"""Génère les icônes monochromes de l'interface (plugin/theme/ui/*.svg).

Icônes « trait » 24x24 dessinées à la main (pas de dépendance externe), une
variante sombre (boutons clairs) et une variante blanche (boutons colorés).

    python tools/make_ui_icons.py
"""
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "plugin", "theme", "ui")

# nom -> (tracés stroke, tracés remplis)
ICONS = {
    # ---- barre du haut
    "gnss": ("M12 21v-7 M8 21h8 M4 9a8 8 0 0 1 16 0 M7.5 9a4.5 4.5 0 0 1 9 0", "M12 9m-1.6 0a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
    "station": ("M12 6l-5 15 M12 6l5 15 M12 6v15 M7.5 16h9", "M12 4m-2.2 0a2.2 2.2 0 1 0 4.4 0a2.2 2.2 0 1 0 -4.4 0"),
    "hauteur": ("M7 3v18 M5 3h4 M5 21h4 M7 7.5h2 M7 12h2 M7 16.5h2 M16 6v12 M13 9l3-3 3 3 M13 15l3 3 3-3", ""),
    "carnet": ("M6 4h11a1 1 0 0 1 1 1v14a1 1 0 0 1 -1 1H6z M9 4v16 M12 9h3 M12 12h3", ""),
    "implantation": ("M12 12m-8 0a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M12 12m-4 0a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2v3 M12 19v3 M2 12h3 M19 12h3", "M12 12m-1.3 0a1.3 1.3 0 1 0 2.6 0a1.3 1.3 0 1 0 -2.6 0"),
    "detecteur": ("M12 12L18.5 5.5 M5 12a7 7 0 0 0 7 7 M5 12a7 7 0 0 1 7 -7 M2 12a10 10 0 0 0 10 10 M2 12a10 10 0 0 1 10 -10", "M12 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"),
    "parametres": ("M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M12 2.5v3 M12 18.5v3 M2.5 12h3 M18.5 12h3 M5.3 5.3l2.1 2.1 M16.6 16.6l2.1 2.1 M5.3 18.7l2.1-2.1 M16.6 7.4l2.1-2.1", ""),
    "bureau": ("M12 3a5 5 0 0 1 5 5v8a5 5 0 0 1 -10 0v-8a5 5 0 0 1 5 -5z M12 3v6 M7 9h10", ""),
    "terrain": ("M8 13V6a1.5 1.5 0 0 1 3 0v6 M11 5.5v-2a1.5 1.5 0 0 1 3 0v8.5 M14 5.5a1.5 1.5 0 0 1 3 0v6.5 M17 8a1.5 1.5 0 0 1 3 0v6a6 6 0 0 1 -6 6h-2a6 6 0 0 1 -5 -3l-3 -5a1.4 1.4 0 0 1 2.4 -1.4L8 13", ""),
    "batterie": ("M3 8h15v8H3z M18 10h2.5v4H18z", "M5 10h5v4H5z"),
    "verrou": ("M6 11h12v9H6z M9 11V7.5a3 3 0 0 1 6 0V11", "M12 15.5m-1.2 0a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0"),
    "deverrouille": ("M6 11h12v9H6z M9 11V7.5a3 3 0 0 1 6 0", ""),
    # ---- barre du bas
    "continuer": ("M4 20v-7a4 4 0 0 1 4 -4h12 M16 5l4 4-4 4", ""),
    "attente": ("", "M7 5h3.5v14H7z M13.5 5H17v14h-3.5z"),
    "reprendre": ("", "M7 4v16l13-8z"),
    "supprimer": ("M19 20H8l-5-5a1.5 1.5 0 0 1 0 -2.1l9-9a1.5 1.5 0 0 1 2.1 0l6 6a1.5 1.5 0 0 1 0 2.1L12 20 M6 11l7 7", ""),
    "relance": ("M20 11a8 8 0 0 0 -15 -3 M4 4v4h4 M4 13a8 8 0 0 0 15 3 M20 20v-4h-4", ""),
    "position": ("M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0 M12 12m-8 0a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M12 2v2.5 M12 19.5V22 M2 12h2.5 M19.5 12H22", ""),
    "zoom_total": ("M16 4h4v4 M14 10l6-6 M8 20H4v-4 M4 20l6-6 M16 20h4v-4 M14 14l6 6 M8 4H4v4 M4 4l6 6", ""),
    "annuler": ("M9 14l-4-4 4-4 M5 10h11a4 4 0 0 1 0 8h-1", ""),
    "valider": ("M5 12l5 5 9-9", ""),
    "refuser": ("M6 6l12 12 M6 18L18 6", ""),
    "info": ("M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M12 11v5", "M12 8m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"),
    "alerte": ("M12 4l9 16H3z M12 10v4", "M12 17m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"),
    # ---- panneau
    "recherche": ("M10 10m-6 0a6 6 0 1 0 12 0a6 6 0 1 0 -12 0 M21 21l-6-6", ""),
    "retour": ("M15 6l-6 6 6 6", ""),
    "suivant": ("M9 6l6 6-6 6", ""),
    "replier_droite": ("M9 6l6 6-6 6", ""),
    "replier_gauche": ("M15 6l-6 6 6 6", ""),
    "mesurer": ("M12 12m-6 0a6 6 0 1 0 12 0a6 6 0 1 0 -12 0 M12 2.5V7 M12 17v4.5 M2.5 12H7 M17 12h4.5", "M12 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "stop": ("", "M6 6h12v12H6z"),
    "liaison": ("M10 14a3.5 3.5 0 0 0 5 0l4-4a3.5 3.5 0 0 0 -5 -5l-.7 .7 M14 10a3.5 3.5 0 0 0 -5 0l-4 4a3.5 3.5 0 0 0 5 5l.7 -.7", ""),
    "dernier_point": ("M12 8v4l3 2 M3.5 11a8.5 8.5 0 1 0 .8 -4 M3 4v4h4", ""),
    "point_unique": ("M12 12m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0", "M12 12m-2.5 0a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0"),
    "plus": ("M12 5v14 M5 12h14", ""),
    "points": ("", "M6 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M12 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M18 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    # ---- familles de la palette
    "fam_voirie": ("M4 20L8 4 M20 20L16 4 M12 4v3 M12 10.5v3 M12 17v3", ""),
    "fam_bati": ("M4 11l8-7 8 7 M6 10v10h5v-5h2v5h5V10", ""),
    "fam_mobilier": ("M3 10h18v3H3z M5 13v6 M19 13v6 M5 16h14 M6 10V6h12v4", ""),
    "fam_divers": ("", "M6 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M12 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M18 12m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "fam_fleches": ("M4 12h15 M13 6l6 6-6 6", ""),
    "fam_panneaux": ("M12 3v18 M12 5h7l2 2.5-2 2.5h-7 M12 11H5l-2 2.5L5 16h7 M9 21h6", ""),
    "fam_interdit": ("M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M5.6 5.6l12.8 12.8", ""),
    "fam_topo": ("M12 4l8 15H4z", "M12 13m-1.6 0a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
    "fam_vegetation": ("M12 21v-5 M8 16h8l-2-4h1.5l-3-4h1L12 3 8.5 8h1l-3 4H8z", ""),
    "fam_texte": ("M6 5h12 M12 5v15 M9 20h6", ""),
    "fam_eau": ("M12 3s-6 6.5-6 11a6 6 0 0 0 12 0c0-4.5-6-11-6-11z", ""),
    "fam_eclairage": ("M9 18h6 M10 21h4 M8.5 14a5.5 5.5 0 1 1 7 0l-1 2h-5z", ""),
    "fam_elec": ("M13 3L5 14h6l-1 7 8-11h-6z", ""),
    "fam_gaz": ("M12 3c1 3 5 5 5 10a5 5 0 0 1 -10 0c0-2 1-3 2-4 0 2 1 3 2 3 1-2-1-5 1-9z", ""),
    "fam_ptt": ("M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1 -2 2A16 16 0 0 1 3 6a2 2 0 0 1 2 -2", ""),
    "fam_sncf": ("M6 4h12a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2H6a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z M4 10h16 M7 17l-2 3 M17 17l2 3", "M8 14m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M16 14m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"),
    "fam_tv": ("M4 7h16v11H4z M8 3l4 4 4-4 M9 21h6", ""),
    "fam_reseaux": ("M12 5m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M6 19m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M18 19m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M12 7v4 M12 11l-5 6 M12 11l5 6", ""),
    "fam_objet": ("M12 3l8 4.5v9L12 21l-8-4.5v-9z M12 12l8-4.5 M12 12v9 M12 12L4 7.5", ""),
    # familles du standard GéoBretagne
    "fam_eau_pluviale": ("M7 16a4 4 0 0 1 -.5 -8 6 6 0 0 1 11.5 2h1a3 3 0 0 1 0 6H7 M8 19l-1 2.5 M12 19l-1 2.5 M16 19l-1 2.5", ""),
    "fam_eau_usee": ("M12 3s-6 6.5-6 11a6 6 0 0 0 12 0c0-4.5-6-11-6-11z M9 14.5h6", ""),
    "fam_unitaire": ("M8 3s-4 4.5-4 8a4 4 0 0 0 8 0c0-3.5-4-8-4-8z M16 9s-4 4.5-4 8a4 4 0 0 0 8 0c0-3.5-4-8-4-8z", ""),
    "fam_chauffage": ("M10 14V5a2 2 0 0 1 4 0v9a4 4 0 1 1 -4 0z M12 9v9", ""),
    "fam_indetermine": ("M9 9a3 3 0 1 1 4.5 2.6c-1 .6-1.5 1.4-1.5 2.4", "M12 18m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"),
    "fam_marquage": ("M4 4l3 16 M20 4l-3 16 M12 4v3 M12 10.5v3 M12 17v3", ""),
    "fam_nivellement": ("M12 4l8 14H4z M12 18v3 M9 21h6", "M12 13m-1.5 0a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0 -3 0"),
    "fam_transport": ("M5 5h14a2 2 0 0 1 2 2v9H3V7a2 2 0 0 1 2 -2z M3 11h18 M7 16v3 M17 16v3", "M7.5 13.5m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0 M16.5 13.5m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"),
    "fam_cloture": ("M5 20V8l2-3 2 3v12 M15 20V8l2-3 2 3v12 M2 12h20 M2 17h20", ""),
    "fam_sport": ("M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0 M5.5 6c3 3 3 9 0 12 M18.5 6c-3 3-3 9 0 12 M3 12h18", ""),
    "fam_propriete": ("M7 21h10 M9 21V9l3-4 3 4v12 M9 13h6", ""),
    "fam_hydro": ("M3 8c2-2 4-2 6 0s4 2 6 0 4-2 6 0 M3 13c2-2 4-2 6 0s4 2 6 0 4-2 6 0 M3 18c2-2 4-2 6 0s4 2 6 0 4-2 6 0", ""),
    "fam_maritime": ("M12 5m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M12 7v14 M12 21a7 7 0 0 1 -7 -7 M12 21a7 7 0 0 0 7 -7 M8 11h8 M3 14l2-2 2 2 M21 14l-2-2-2 2", ""),
    "fam_sigt": ("M12 21s-6-5.5-6-11a6 6 0 0 1 12 0c0 5.5-6 11-6 11z", "M12 10m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"),
    # ---- dessin
    "ligne": ("M5 19L19 5", "M5 19m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M19 5m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "arc3": ("M4 17a10 10 0 0 1 16 0", "M4 17m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M20 17m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M12 7m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "arc2": ("M4 17a10 10 0 0 1 16 0 M4 17l-2 6", "M4 17m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M20 17m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "courbe": ("M3 16c3-9 6 9 9 0s6-9 9 0", ""),
    "tangent": ("M4 6h16 M12 6v13", ""),
    "fermer": ("M12 4l7.5 5.5-3 8.5h-9l-3-8.5z", "M12 4m-1.6 0a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
    "hachure": ("M4 4h16v16H4z M4 12l8-8 M4 20L20 4 M12 20l8-8", ""),
    "ajust_deb": ("M4 4v16 M4 12h12 M12 8l4 4-4 4", ""),
    "ajust_fin": ("M20 4v16 M20 12H8 M12 8l-4 4 4 4", ""),
    "symetrie": ("M12 3v18 M8 7l-5 5 5 5 M16 7l5 5-5 5", ""),
    "inverser": ("M4 12a8 8 0 1 0 3 -6 M4 4v5h5", ""),
    "decaler": ("M4 12h13 M13 7l5 5-5 5 M4 6v12", ""),
    "modifier": ("M4 20h4L18 10l-4-4L4 16z M13 7l4 4", ""),
    "rect2": ("M4 6h16v12H4z", "M4 6m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M20 18m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "rect3": ("M4 6h16v12H4z", "M4 6m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M20 6m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M20 18m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "cercle": ("M12 12m-8 0a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M12 12h8", "M12 12m-1.6 0a1.6 1.6 0 1 0 3.2 0a1.6 1.6 0 1 0 -3.2 0"),
    "cercle3": ("M12 12m-8 0a8 8 0 1 0 16 0a8 8 0 1 0 -16 0", "M12 4m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M5 16m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0 M19 16m-1.8 0a1.8 1.8 0 1 0 3.6 0a1.8 1.8 0 1 0 -3.6 0"),
    "rayon": ("M12 12m-8 0a8 8 0 1 0 16 0a8 8 0 1 0 -16 0 M12 12l6-5", ""),
    # ---- excentrements
    "exc_point": ("M12 12m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0", "M12 12m-2.5 0a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0"),
    "exc_perp_prec": ("M4 18h16 M8 18V6 M13 8h4l-4 6h4", ""),
    "exc_perp_suiv": ("M4 18h16 M16 18V6 M4 8l3 7 3-7", ""),
    "exc_vertical": ("M12 3v18 M8 7l4-4 4 4 M8 17l4 4 4-4", ""),
    "exc_milieu": ("M3 12h18", "M3 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M21 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0 M12 12m-2.5 0a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0"),
    "exc_deux_dist": ("M4 18L12 6l8 12 M4 18h16", "M12 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"),
    "exc_station": ("M12 5l-5 14 M12 5l5 14 M12 5v14 M5 19h14", "M12 5m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"),
    "exc_dist_rec": ("M4 18h16 M4 18L14 6 M8 18a4 4 0 0 0 -1 -3", ""),
    "exc_vertical_tps": ("M4 19h16 M4 19L15 7 M12 19V9", "M15 7m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"),
    "exc_plus": ("M12 5v14 M5 12h14", ""),
}

SVG = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
       '{stroke}{fill}</svg>\n')


def build(color):
    out = []
    for name, (stroke, fill) in ICONS.items():
        s = ('<path d="%s" fill="none" stroke="%s" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>' % (stroke, color)) if stroke else ""
        f = ('<path d="%s" fill="%s" stroke="none"/>' % (fill, color)) if fill else ""
        out.append((name, SVG.format(stroke=s, fill=f)))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for suffix, color in (("", "#2c2c2a"), ("_w", "#ffffff")):
        for name, svg in build(color):
            with open(os.path.join(OUT, name + suffix + ".svg"), "w", encoding="utf-8", newline="\n") as f:
                f.write(svg)
            n += 1
    print("%d icônes écrites dans %s" % (n, OUT))


if __name__ == "__main__":
    sys.exit(main())
