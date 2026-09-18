# -*- coding: utf-8 -*-
"""Pilotes "simulateur" : équivalent de l'« Entrée clavier » du logiciel de référence.

Le plugin fournit les valeurs (hz, v, sd) dans la requête (champ "sim").
Sans valeurs, une mesure aléatoire cohérente est générée (formation / démo).
"""
import random
import time

from .base import DetectorDriver, DistoDriver, TPSDriver


class SimTPS(TPSDriver):
    name = "simulateur"

    def __init__(self, events):
        super().__init__(events)
        self.model = "Simulateur (entrée clavier)"
        self.hz = 0.0
        self.v = 100.0
        self.laser = False

    def connect(self):
        self.connected = True
        self.locked = True
        self.latency_ms = 5
        self.battery = 100

    def measure(self, mode="prisme", face=1, sim=None):
        self.busy = True
        try:
            if sim and "hz" in sim:
                self.hz = float(sim.get("hz", self.hz))
                self.v = float(sim.get("v", self.v))
                sd = float(sim.get("sd", 0.0))
            else:
                self.hz = (self.hz + random.uniform(-15, 15)) % 400
                self.v = 100.0 + random.uniform(-3, 3)
                sd = random.uniform(5, 60)
            if face == 2:
                hz = (self.hz + 200) % 400
                v = 400 - self.v
            else:
                hz, v = self.hz, self.v
            self.last_hz, self.last_v, self.last_sd = hz, v, sd
            time.sleep(0.2)
            return {"hz": hz, "v": v, "sd": sd}
        finally:
            self.busy = False

    def angles(self, sim=None):
        if sim and "hz" in sim:
            self.hz = float(sim["hz"])
            self.v = float(sim.get("v", self.v))
        self.last_hz, self.last_v = self.hz, self.v
        return {"hz": self.hz, "v": self.v}

    def search(self, kind, params):
        time.sleep(0.5)
        self.locked = True
        self.events.push("tps_search_done", {"found": True, "type": kind})
        return {"ok": True, "found": True}

    def joystick(self, direction, speed):
        step = 5.0 if speed == "rapide" else 0.5
        if direction == "gauche":
            self.hz = (self.hz - step) % 400
        elif direction == "droite":
            self.hz = (self.hz + step) % 400
        elif direction == "haut":
            self.v = max(0.0, self.v - step)
        elif direction == "bas":
            self.v = min(200.0, self.v + step)
        self.last_hz, self.last_v = self.hz, self.v
        return {"ok": True, "hz": self.hz, "v": self.v}

    def turn(self, hz, v, search=False):
        self.hz, self.v = hz % 400, v
        self.last_hz, self.last_v = self.hz, self.v
        if search:
            self.locked = True
        return {"ok": True, "hz": self.hz, "v": self.v, "locked": self.locked}

    def set_lock(self, on):
        self.locked = bool(on)
        return {"ok": True, "locked": self.locked}

    def set_laser(self, on):
        self.laser = bool(on)
        return {"ok": True, "laser": self.laser}


class SimDisto(DistoDriver):
    name = "simulateur"

    def __init__(self, events):
        super().__init__(events)
        self.model = "Disto simulé"

    def measure(self, sim=None):
        d = float(sim["distance"]) if sim and "distance" in sim else round(random.uniform(0.3, 8.0), 3)
        self.last_distance = d
        return d


class SimDetector(DetectorDriver):
    name = "simulateur"

    def __init__(self, events):
        super().__init__(events)
        self.model = "Détecteur simulé (saisie manuelle)"
