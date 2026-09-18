# -*- coding: utf-8 -*-
"""Interfaces des pilotes du pont. Angles en GRADES, distances en mètres."""
import math
import time


def rad2gr(r):
    return r * 200.0 / math.pi


def gr2rad(g):
    return g * math.pi / 200.0


def list_serial_ports():
    try:
        from serial.tools import list_ports
        return [{"port": p.device, "description": p.description} for p in list_ports.comports()]
    except Exception:
        return []


class Driver:
    name = "base"

    def __init__(self, events):
        self.events = events
        self.connected = False
        self.model = ""
        self.last_error = ""

    def connect(self):
        self.connected = True

    def disconnect(self):
        self.connected = False

    def poll(self):
        """Appelé toutes les 0,5 s par le pont (suivi, événements)."""
        return None


class TPSDriver(Driver):
    """Station totale."""
    name = "tps"

    def __init__(self, events):
        super().__init__(events)
        self.locked = False
        self.tracking = False
        self.busy = False
        self.latency_ms = None
        self.battery = None
        self.last_hz = None
        self.last_v = None
        self.last_sd = None

    def setup(self, state):
        """state : {hr, prism, atr}"""

    def measure(self, mode="prisme", face=1, sim=None):
        """Renvoie {hz, v, sd} (grades, mètres)."""
        raise NotImplementedError

    def angles(self, sim=None):
        raise NotImplementedError

    def search(self, kind, params):
        return {"ok": False, "error": "recherche non supportée"}

    def stop(self):
        return {"ok": True}

    def joystick(self, direction, speed):
        return {"ok": False, "error": "joystick non supporté"}

    def turn(self, hz, v, search=False):
        return {"ok": False, "error": "positionnement non supporté"}

    def set_lock(self, on):
        return {"ok": False, "error": "verrouillage non supporté"}

    def set_laser(self, on):
        return {"ok": False, "error": "laser non supporté"}

    def set_tracking(self, on):
        self.tracking = on
        return {"ok": True}


class DistoDriver(Driver):
    name = "disto"

    def __init__(self, events):
        super().__init__(events)
        self.last_distance = None
        self.last_key = None

    def measure(self, sim=None):
        raise NotImplementedError


class DetectorDriver(Driver):
    name = "detector"

    def poll(self):
        """Renvoie une mesure {profondeur, index, intensite, frequence, mode, t} ou None."""
        return None


def now():
    return time.time()
