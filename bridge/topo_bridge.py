# -*- coding: utf-8 -*-
"""
Lahocy Bridge - pont local entre le plugin QField "Topo" et les appareils
topographiques (station totale, disto, détecteur de réseaux).

Le pont n'a AUCUNE logique topographique : il expose des primitives
(mesurer, tourner, chercher le prisme, lire une distance) par HTTP/JSON
sur 127.0.0.1:8765. Le plugin QML l'interroge avec XMLHttpRequest.

Lancement :
    python bridge/topo_bridge.py [--port 8765] [--config bridge/config.ini]

Pilotes disponibles (bridge/drivers) :
    simulateur  : entrée clavier (le plugin envoie hz / v / di)   -> toujours dispo
    geocom      : Leica GeoCOM ASCII (TS13/TS16/TS60, RH17, BT)    -> pyserial
    disto_ble   : Leica DISTO (BLE)                                -> bleak
    detector    : détecteur série Bluetooth (RD8100, vLoc3...)     -> pyserial

Routes (voir docs/SPEC_LahocyTopo.md §14.2) :
    GET  /status                 GET  /events?since=N        GET  /drivers
    POST /tps/connect            POST /tps/disconnect        POST /tps/measure
    POST /tps/angles             POST /tps/search            POST /tps/stop
    POST /tps/joystick           POST /tps/turn              POST /tps/lock
    POST /tps/laser              POST /tps/setup {hr, prism, atr}
    POST /disto/connect          POST /disto/measure         POST /disto/simulate
    POST /detector/connect       GET  /detector/pending      POST /detector/simulate
    POST /detector/ack
"""
import argparse
import configparser
import json
import os
import sys
import threading
import time
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from drivers import base, simulateur  # noqa: E402

try:
    from drivers import geocom  # noqa: E402
except Exception:  # pragma: no cover
    geocom = None
try:
    from drivers import disto_ble  # noqa: E402
except Exception:  # pragma: no cover
    disto_ble = None
try:
    from drivers import detector  # noqa: E402
except Exception:  # pragma: no cover
    detector = None


class EventBus:
    """File d'événements asynchrones consommée par le plugin (long-poll)."""

    def __init__(self):
        self.seq = 0
        self.events = []
        self.cond = threading.Condition()

    def push(self, kind, payload=None):
        with self.cond:
            self.seq += 1
            self.events.append({"seq": self.seq, "kind": kind, "t": time.time(), "data": payload or {}})
            self.events = self.events[-500:]
            self.cond.notify_all()

    def since(self, n, timeout=25.0):
        with self.cond:
            deadline = time.time() + timeout
            while True:
                out = [e for e in self.events if e["seq"] > n]
                if out:
                    return out
                remaining = deadline - time.time()
                if remaining <= 0:
                    return []
                self.cond.wait(remaining)


class Bridge:
    def __init__(self, config):
        self.config = config
        self.events = EventBus()
        self.tps = None        # base.TPSDriver
        self.disto = None      # base.DistoDriver
        self.detector = None   # base.DetectorDriver
        self.lock = threading.Lock()
        self.tps_state = {"hr": 1.5, "prism": "standard", "atr": True}
        self.detector_pending = None
        self._monitor = threading.Thread(target=self._monitor_loop, daemon=True)
        self._monitor.start()

    # ------------------------------------------------------------------ status
    def status(self):
        t = self.tps
        tps = {"connected": bool(t and t.connected), "driver": t.name if t else "", "model": t.model if t else "",
               "locked": bool(t and t.locked), "latency_ms": t.latency_ms if t else None,
               "battery": t.battery if t else None, "hz": t.last_hz if t else None, "v": t.last_v if t else None,
               "sd": t.last_sd if t else None, "tracking": bool(t and t.tracking), "hr": self.tps_state["hr"],
               "busy": bool(t and t.busy), "error": t.last_error if t else ""}
        d = self.disto
        disto = {"connected": bool(d and d.connected), "driver": d.name if d else "", "last_distance": d.last_distance if d else None,
                 "last_key": d.last_key if d else None, "error": d.last_error if d else ""}
        det = self.detector
        detector_st = {"connected": bool(det and det.connected), "driver": det.name if det else "",
                       "pending": self.detector_pending, "error": det.last_error if det else ""}
        return {"ok": True, "time": time.time(), "seq": self.events.seq, "tps": tps, "disto": disto, "detector": detector_st}

    def drivers(self):
        out = {"tps": ["simulateur"], "disto": ["simulateur"], "detector": ["simulateur"]}
        if geocom:
            out["tps"].append("geocom")
        if disto_ble:
            out["disto"].append("disto_ble")
        if detector:
            out["detector"].append("detector")
        return {"ok": True, "drivers": out, "ports": base.list_serial_ports()}

    # ------------------------------------------------------------------ TPS
    def tps_connect(self, body):
        driver = body.get("driver", "simulateur")
        port = body.get("port", "")
        baud = int(body.get("baud", 115200) or 115200)
        with self.lock:
            if self.tps:
                try:
                    self.tps.disconnect()
                except Exception:
                    pass
            if driver == "geocom":
                if not geocom:
                    return {"ok": False, "error": "pilote geocom indisponible (pyserial ?)"}
                self.tps = geocom.GeoComDriver(port, baud, self.events)
            else:
                self.tps = simulateur.SimTPS(self.events)
            try:
                self.tps.connect()
                self.tps.setup(self.tps_state)
            except Exception as e:
                self.tps.last_error = str(e)
                return {"ok": False, "error": str(e)}
        self.events.push("tps_connected", {"driver": driver, "model": self.tps.model})
        return {"ok": True, "model": self.tps.model}

    def tps_disconnect(self):
        with self.lock:
            if self.tps:
                self.tps.disconnect()
                self.tps = None
        self.events.push("tps_disconnected")
        return {"ok": True}

    def need_tps(self):
        if not self.tps or not self.tps.connected:
            raise RuntimeError("Station non connectée")
        return self.tps

    def tps_measure(self, body):
        t = self.need_tps()
        mode = body.get("mode", "prisme")
        face = int(body.get("face", 1))
        sim = body.get("sim")  # {hz, v, sd} pour le simulateur
        obs = t.measure(mode=mode, face=face, sim=sim)
        obs.update({"ok": True, "hr": self.tps_state["hr"], "face": face, "mode": mode, "t": time.time()})
        self.events.push("tps_measure", obs)
        return obs

    def tps_angles(self, body):
        t = self.need_tps()
        obs = t.angles(sim=body.get("sim"))
        obs.update({"ok": True, "t": time.time()})
        return obs

    # ------------------------------------------------------------------ monitor (suivi prisme)
    def _monitor_loop(self):
        was_locked = None
        while True:
            time.sleep(0.5)
            t = self.tps
            if not t or not t.connected:
                continue
            try:
                t.poll()
            except Exception as e:  # pragma: no cover
                t.last_error = str(e)
            if t.locked != was_locked:
                self.events.push("tps_lock", {"locked": bool(t.locked)})
                was_locked = t.locked
            d = self.disto
            if d and d.connected:
                try:
                    d.poll()
                except Exception as e:  # pragma: no cover
                    d.last_error = str(e)
            det = self.detector
            if det and det.connected:
                try:
                    m = det.poll()
                    if m:
                        self.detector_pending = m
                        self.events.push("detector_measure", m)
                except Exception as e:  # pragma: no cover
                    det.last_error = str(e)

    # ------------------------------------------------------------------ disto
    def disto_connect(self, body):
        driver = body.get("driver", "simulateur")
        with self.lock:
            if self.disto:
                try:
                    self.disto.disconnect()
                except Exception:
                    pass
            if driver == "disto_ble":
                if not disto_ble:
                    return {"ok": False, "error": "pilote disto_ble indisponible (bleak ?)"}
                self.disto = disto_ble.DistoBLE(body.get("address", ""), self.events)
            else:
                self.disto = simulateur.SimDisto(self.events)
            try:
                self.disto.connect()
            except Exception as e:
                return {"ok": False, "error": str(e)}
        self.events.push("disto_connected", {"driver": driver})
        return {"ok": True}

    def disto_measure(self, body):
        if not self.disto or not self.disto.connected:
            raise RuntimeError("Disto non connecté")
        d = self.disto.measure(sim=body.get("sim"))
        self.events.push("disto_measure", {"distance": d})
        return {"ok": True, "distance": d}

    # ------------------------------------------------------------------ détecteur
    def detector_connect(self, body):
        driver = body.get("driver", "simulateur")
        with self.lock:
            if self.detector:
                try:
                    self.detector.disconnect()
                except Exception:
                    pass
            if driver == "detector":
                if not detector:
                    return {"ok": False, "error": "pilote detector indisponible (pyserial ?)"}
                self.detector = detector.SerialDetector(body.get("port", ""), int(body.get("baud", 9600) or 9600), body.get("model", "generic"), self.events)
            else:
                self.detector = simulateur.SimDetector(self.events)
            try:
                self.detector.connect()
            except Exception as e:
                return {"ok": False, "error": str(e)}
        self.events.push("detector_connected", {"driver": driver})
        return {"ok": True}

    def detector_simulate(self, body):
        m = {"profondeur": float(body.get("profondeur", 0)), "index": body.get("index", ""), "intensite": body.get("intensite"),
             "frequence": body.get("frequence"), "mode": body.get("mode", "manuel"), "t": time.time()}
        self.detector_pending = m
        self.events.push("detector_measure", m)
        return {"ok": True, "pending": m}

    # ------------------------------------------------------------------ dispatch
    def handle(self, method, path, query, body):
        t = self.tps
        if method == "GET":
            if path == "/status":
                return self.status()
            if path == "/drivers":
                return self.drivers()
            if path == "/events":
                since = int(query.get("since", ["0"])[0])
                timeout = float(query.get("timeout", ["25"])[0])
                return {"ok": True, "seq": self.events.seq, "events": self.events.since(since, timeout)}
            if path == "/detector/pending":
                return {"ok": True, "pending": self.detector_pending}
            raise KeyError(path)
        # POST
        if path == "/tps/connect":
            return self.tps_connect(body)
        if path == "/tps/disconnect":
            return self.tps_disconnect()
        if path == "/tps/measure":
            return self.tps_measure(body)
        if path == "/tps/angles":
            return self.tps_angles(body)
        if path == "/tps/search":
            return self.need_tps().search(body.get("type", "powersearch"), body)
        if path == "/tps/stop":
            return self.need_tps().stop()
        if path == "/tps/joystick":
            return self.need_tps().joystick(body.get("dir", ""), body.get("speed", "lent"))
        if path == "/tps/turn":
            return self.need_tps().turn(float(body.get("hz", 0)), float(body.get("v", 100)), bool(body.get("search", False)))
        if path == "/tps/lock":
            return self.need_tps().set_lock(bool(body.get("on", True)))
        if path == "/tps/laser":
            return self.need_tps().set_laser(bool(body.get("on", True)))
        if path == "/tps/tracking":
            return self.need_tps().set_tracking(bool(body.get("on", True)))
        if path == "/tps/setup":
            for k in ("hr", "prism", "atr"):
                if k in body:
                    self.tps_state[k] = body[k]
            if t and t.connected:
                t.setup(self.tps_state)
            return {"ok": True, "state": self.tps_state}
        if path == "/disto/connect":
            return self.disto_connect(body)
        if path == "/disto/measure":
            return self.disto_measure(body)
        if path == "/disto/simulate":
            self.events.push("disto_key", {"key": body.get("key", "")})
            if "distance" in body:
                self.events.push("disto_measure", {"distance": float(body["distance"])})
            return {"ok": True}
        if path == "/detector/connect":
            return self.detector_connect(body)
        if path == "/detector/simulate":
            return self.detector_simulate(body)
        if path == "/detector/ack":
            self.detector_pending = None
            return {"ok": True}
        raise KeyError(path)


class Handler(BaseHTTPRequestHandler):
    bridge = None  # type: Bridge

    def log_message(self, fmt, *args):  # silence
        if "--verbose" in sys.argv:
            super().log_message(fmt, *args)

    def _send(self, code, obj):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self._send(200, {"ok": True})

    def _dispatch(self, method):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        body = {}
        if method == "POST":
            length = int(self.headers.get("Content-Length", "0") or 0)
            raw = self.rfile.read(length) if length else b""
            if raw:
                try:
                    body = json.loads(raw.decode("utf-8"))
                except Exception:
                    body = {}
        try:
            self._send(200, self.bridge.handle(method, parsed.path, query, body))
        except KeyError:
            self._send(404, {"ok": False, "error": "route inconnue " + parsed.path})
        except Exception as e:
            traceback.print_exc()
            self._send(200, {"ok": False, "error": str(e)})

    def do_GET(self):
        self._dispatch("GET")

    def do_POST(self):
        self._dispatch("POST")


def main():
    ap = argparse.ArgumentParser(description="Lahocy Bridge")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--config", default=os.path.join(os.path.dirname(__file__), "config.ini"))
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    config = configparser.ConfigParser()
    if os.path.exists(args.config):
        config.read(args.config, encoding="utf-8")
    Handler.bridge = Bridge(config)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Lahocy Bridge en écoute sur http://{args.host}:{args.port}  (Ctrl+C pour arrêter)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
