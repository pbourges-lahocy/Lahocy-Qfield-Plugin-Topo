# -*- coding: utf-8 -*-
"""
Pilote Leica GeoCOM (protocole ASCII) : TS13 / TS16 / TS60 / TPS1200 / Viva.

Liaison série (COM Bluetooth interne, poignée radio RH16/RH17/RH32 ou câble LEMO).
L'instrument doit être en mode GeoCOM (bouton COM > 5 s sur TS13, licence GeoCOM
robotique nécessaire pour ATR / PowerSearch / moteurs).

Format : requête  "%R1Q,<rpc>:<p1>,<p2>...\\r\\n"
         réponse  "%R1P,0,<tr>:<rc>,<v1>,<v2>...\\r\\n"   (rc = 0 : OK)
Angles GeoCOM en radians -> convertis en grades ; distances en mètres.

Ce pilote n'a pas pu être testé sans instrument : les codes RPC proviennent du
manuel de référence GeoCOM Leica (TPS1200 / Viva / Captivate).
"""
import math
import threading
import time

import serial

from .base import TPSDriver, gr2rad, rad2gr

# Codes RPC GeoCOM
COM_NullProc = 0
CSV_GetInstrumentName = 5004
CSV_CheckPower = 5039
TMC_GetAngle5 = 2107
TMC_GetSimpleMea = 2108
TMC_DoMeasure = 2008
TMC_SetOrientation = 2113
TMC_SetInclineSwitch = 2006
BAP_MeasDistanceAngle = 17017
BAP_SetTargetType = 17021
BAP_SetPrismType = 17008
BAP_SearchTarget = 17020
AUT_MakePositioning = 9037
AUT_Search = 9029
AUT_LockIn = 9013
AUT_PS_EnableRange = 9048
AUT_PS_SetRange = 9047
AUT_PS_SearchNext = 9051
AUT_PS_SearchWindow = 9052
AUS_SetUserAtrState = 18005
AUS_SetUserLockState = 18007
MOT_ReadLockStatus = 6021
MOT_StartController = 6001
MOT_SetVelocity = 6004
MOT_StopController = 6002
EDM_Laserpointer = 1004

# BAP_MEASURE_PRG
BAP_NO_MEAS, BAP_NO_DIST, BAP_DEF_DIST, BAP_CLEAR_DIST, BAP_STOP_TRK = 0, 1, 2, 3, 4
# BAP_TARGET_TYPE
BAP_REFL_USE, BAP_REFL_LESS = 0, 1
# TMC_INCLINE_PRG
TMC_MEA_INC, TMC_AUTO_INC, TMC_PLANE_INC = 0, 1, 2

# Codes retour TMC qui sont des avertissements : les valeurs renvoyées restent utilisables.
TMC_WARNINGS = {
    1280: "mesure sans correction complète",
    1281: "précision non garantie",
    1282: "angles seuls valides (pas de distance)",
    1283: "angles seuls valides, sans correction complète (instrument calé ?)",
    1284: "angles seuls valides, précision non garantie",
}
TMC_ANGLE_ONLY = {1282, 1283, 1284}
ERRORS = {
    2: "paramètre invalide", 5: "fonction non implémentée sur cet instrument", 6: "délai dépassé",
    9: "commande interrompue", 12: "fonction indisponible (licence GeoCOM ?)",
    1285: "pas de mesure d'angle (instrument calé, compensateur ?)", 1286: "PPM erroné",
    1287: "distance non mesurée", 1288: "instrument occupé", 1289: "pas de signal (prisme visé ?)",
    8704: "délai ATR dépassé", 8710: "aucune cible trouvée", 8711: "plusieurs cibles",
    8712: "environnement défavorable (lumière, reflets)", 8714: "ATR / verrouillage non activé",
    8716: "précision ATR insuffisante", 8720: "hors zone de travail",
    1792: "moteur non prêt", 1793: "moteur occupé", 1794: "contrôleur moteur non démarré",
}

PRISM_TYPES = {"round": 0, "mini": 1, "tape": 2, "360": 3, "user1": 4, "user2": 5, "user3": 6, "mini360": 7, "miniZero": 8, "user": 9, "ndsTape": 10, "grz121": 11, "maMPR122": 12, "standard": 0}


class GeoComError(RuntimeError):
    pass


class GeoComDriver(TPSDriver):
    name = "geocom"

    def __init__(self, port, baud, events):
        super().__init__(events)
        self.port = port
        self.baud = baud
        self.ser = None
        self.tr = 0
        self.io_lock = threading.Lock()
        self.laser = False
        self.reflectorless = False
        self._joystick_running = False
        self.last_warning = ""

    # ------------------------------------------------------------------ bas niveau
    def connect(self):
        self.ser = serial.Serial(self.port, self.baud, timeout=8, write_timeout=2)
        time.sleep(0.2)
        self.ser.reset_input_buffer()
        rc, vals = self.request(COM_NullProc, [])
        try:
            rc, vals = self.request(CSV_GetInstrumentName, [])
            self.model = vals[0].strip('"') if vals else "Leica GeoCOM"
        except Exception:
            self.model = "Leica GeoCOM"
        self.connected = True
        self.last_error = ""
        self.poll()

    def disconnect(self):
        self.connected = False
        if self.ser:
            try:
                self.ser.close()
            except Exception:
                pass
        self.ser = None

    def request(self, rpc, params, timeout=None):
        """Envoie une requête GeoCOM et renvoie (rc, [valeurs])."""
        if not self.ser:
            raise GeoComError("port fermé")
        line = "%%R1Q,%d:%s\r\n" % (rpc, ",".join(str(p) for p in params))
        with self.io_lock:
            t0 = time.time()
            old_timeout = self.ser.timeout
            if timeout:
                self.ser.timeout = timeout
            try:
                self.ser.reset_input_buffer()
                self.ser.write(line.encode("ascii"))
                raw = self.ser.readline().decode("ascii", "ignore").strip()
            finally:
                self.ser.timeout = old_timeout
            self.latency_ms = int((time.time() - t0) * 1000)
        if not raw.startswith("%R1P"):
            raise GeoComError("réponse invalide : %r" % raw)
        head, _, tail = raw.partition(":")
        parts = tail.split(",")
        rc = int(parts[0])
        return rc, parts[1:]

    def check(self, rc, what):
        if rc != 0:
            label = ERRORS.get(rc) or TMC_WARNINGS.get(rc)
            self.last_error = "%s : code GeoCOM %d%s" % (what, rc, " (%s)" % label if label else "")
            raise GeoComError(self.last_error)

    def check_tmc(self, rc, what, need_distance):
        """Comme check(), mais accepte les avertissements TMC (valeurs utilisables)."""
        if rc == 0:
            self.last_warning = ""
            return
        warn = TMC_WARNINGS.get(rc)
        if warn and not (need_distance and rc in TMC_ANGLE_ONLY):
            self.last_warning = warn
            return
        self.check(rc, what)

    # ------------------------------------------------------------------ configuration
    def setup(self, state):
        prism = PRISM_TYPES.get(str(state.get("prism", "standard")), 0)
        try:
            self.request(BAP_SetPrismType, [prism])
            self.request(AUS_SetUserAtrState, [1 if state.get("atr", True) else 0])
            self.request(TMC_SetInclineSwitch, [1])
        except GeoComError as e:
            self.last_error = str(e)

    # ------------------------------------------------------------------ mesures
    def measure(self, mode="prisme", face=1, sim=None):
        self.busy = True
        try:
            target = BAP_REFL_LESS if mode == "sans_prisme" else BAP_REFL_USE
            if target != (BAP_REFL_LESS if self.reflectorless else BAP_REFL_USE):
                rc, _ = self.request(BAP_SetTargetType, [target])
                self.check(rc, "type de cible")
                self.reflectorless = (target == BAP_REFL_LESS)
            rc, vals = self.request(BAP_MeasDistanceAngle, [BAP_DEF_DIST], timeout=30)
            self.check_tmc(rc, "mesure", need_distance=True)
            hz, v, sd = float(vals[0]), float(vals[1]), float(vals[2])
            if sd <= 0:
                raise GeoComError("distance non mesurée (prisme visé ?)")
            self.last_hz, self.last_v, self.last_sd = rad2gr(hz), rad2gr(v), sd
            obs = {"hz": rad2gr(hz), "v": rad2gr(v), "sd": sd}
            if self.last_warning:
                obs["warn"] = self.last_warning
            return obs
        finally:
            self.busy = False

    def angles(self, sim=None):
        rc, vals = self.request(TMC_GetAngle5, [TMC_AUTO_INC])
        self.check_tmc(rc, "lecture des angles", need_distance=False)
        hz, v = float(vals[0]), float(vals[1])
        self.last_hz, self.last_v = rad2gr(hz), rad2gr(v)
        obs = {"hz": rad2gr(hz), "v": rad2gr(v)}
        if self.last_warning:
            obs["warn"] = self.last_warning
        return obs

    def poll(self):
        if not self.connected or self.busy:
            return
        try:
            rc, vals = self.request(MOT_ReadLockStatus, [], timeout=2)
            if rc == 0 and vals:
                self.locked = int(vals[0]) == 1
            if self.tracking:
                self.angles()
        except Exception as e:
            self.last_error = str(e)
        # batterie (toutes les 30 s environ)
        if not hasattr(self, "_bat_t") or time.time() - self._bat_t > 30:
            self._bat_t = time.time()
            try:
                rc, vals = self.request(CSV_CheckPower, [], timeout=2)
                if rc == 0 and vals:
                    self.battery = int(vals[0])
            except Exception:
                pass

    # ------------------------------------------------------------------ pilotage
    def search(self, kind, params):
        self.busy = True
        try:
            if kind.startswith("powersearch"):
                rc, _ = self.request(AUT_PS_EnableRange, [1 if kind == "powersearch" else 0])
                if kind == "powersearch":
                    self.request(AUT_PS_SetRange, [float(params.get("min", 1)), float(params.get("max", 300))])
                rc, _ = self.request(AUT_PS_SearchNext, [1, 1], timeout=60)
            else:  # spirale
                hz = gr2rad(float(params.get("hz", 10)))
                v = gr2rad(float(params.get("v", 10)))
                rc, _ = self.request(AUT_Search, [hz, v, 0], timeout=60)
            found = rc == 0
            if found:
                self.request(AUT_LockIn, [], timeout=10)
                self.locked = True
            self.events.push("tps_search_done", {"found": found, "type": kind, "rc": rc})
            return {"ok": True, "found": found, "rc": rc}
        finally:
            self.busy = False

    def stop(self):
        try:
            self.request(MOT_StopController, [0], timeout=2)
        except Exception:
            pass
        self._joystick_running = False
        return {"ok": True}

    def joystick(self, direction, speed):
        w = 0.6 if speed == "rapide" else 0.05  # rad/s
        hz = -w if direction == "gauche" else (w if direction == "droite" else 0.0)
        v = -w if direction == "haut" else (w if direction == "bas" else 0.0)
        if not self._joystick_running:
            rc, _ = self.request(MOT_StartController, [1])  # MOT_OCONST : vitesse constante
            self._joystick_running = True
        rc, _ = self.request(MOT_SetVelocity, [hz, v])
        return {"ok": rc == 0}

    def turn(self, hz, v, search=False):
        self.busy = True
        try:
            rc, _ = self.request(AUT_MakePositioning, [gr2rad(hz), gr2rad(v), 0, 1 if search else 0, 0], timeout=60)
            self.check(rc, "positionnement")
            if search:
                rc2, _ = self.request(AUT_LockIn, [], timeout=10)
                self.locked = rc2 == 0
            return {"ok": True, "locked": self.locked}
        finally:
            self.busy = False

    def set_lock(self, on):
        rc, _ = self.request(AUS_SetUserLockState, [1 if on else 0])
        if on:
            rc2, _ = self.request(AUT_LockIn, [], timeout=10)
            self.locked = rc2 == 0
        return {"ok": rc == 0, "locked": self.locked}

    def set_laser(self, on):
        rc, _ = self.request(EDM_Laserpointer, [1 if on else 0])
        self.laser = bool(on)
        return {"ok": rc == 0, "laser": self.laser}

    def set_orientation(self, hz_gr):
        rc, _ = self.request(TMC_SetOrientation, [gr2rad(hz_gr)])
        return {"ok": rc == 0}
