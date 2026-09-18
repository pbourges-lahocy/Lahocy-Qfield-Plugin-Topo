# -*- coding: utf-8 -*-
"""
Pilote détecteur de réseaux sur liaison série (Bluetooth SPP) : Radiodetection
RD8100 / RD8200, Vivax vLoc3, etc.

Chaque appareil a sa trame ; le pilote "generic" lit des lignes texte et
extrait des couples clé=valeur ou des champs séparés par ; ou , contenant la
profondeur. Modèles :
  generic : "DEPTH=1.23;CURRENT=12.5;FREQ=8192"  ou "1.23"
  rd      : trame RD8100 (Bluetooth "log" : ...,Depth,...)  -> à adapter sur le terrain
  vloc    : trame Vivax vLoc3 (NMEA-like $VLOC,...)          -> à adapter sur le terrain

Non testé sans appareil.
"""
import re
import time

import serial

from .base import DetectorDriver


class SerialDetector(DetectorDriver):
    name = "detector"

    def __init__(self, port, baud, model, events):
        super().__init__(events)
        self.port = port
        self.baud = baud
        self.model = model or "generic"
        self.ser = None
        self.buffer = ""

    def connect(self):
        self.ser = serial.Serial(self.port, self.baud, timeout=0.1)
        self.connected = True

    def disconnect(self):
        self.connected = False
        if self.ser:
            try:
                self.ser.close()
            except Exception:
                pass
        self.ser = None

    def poll(self):
        if not self.ser:
            return None
        try:
            data = self.ser.read(256).decode("ascii", "ignore")
        except Exception as e:
            self.last_error = str(e)
            return None
        if not data:
            return None
        self.buffer += data
        if "\n" not in self.buffer:
            return None
        line, _, self.buffer = self.buffer.partition("\n")
        return self.parse(line.strip())

    def parse(self, line):
        if not line:
            return None
        m = {"raw": line, "mode": "auto", "t": time.time(), "index": "", "intensite": None, "frequence": None, "profondeur": None}
        kv = dict(re.findall(r"([A-Za-z_]+)\s*[=:]\s*([-+]?\d+(?:\.\d+)?)", line))
        for k, v in kv.items():
            lk = k.lower()
            if lk.startswith("depth") or lk.startswith("prof"):
                m["profondeur"] = float(v)
            elif lk.startswith("curr") or lk.startswith("int") or lk.startswith("sig"):
                m["intensite"] = float(v)
            elif lk.startswith("freq"):
                m["frequence"] = float(v)
            elif lk.startswith("idx") or lk.startswith("index") or lk.startswith("id"):
                m["index"] = v
        if m["profondeur"] is None:
            nums = re.findall(r"[-+]?\d+\.\d+", line)
            if nums:
                m["profondeur"] = float(nums[0])
        if m["profondeur"] is None:
            return None
        # unités en mm ou cm ?
        if m["profondeur"] > 50:
            m["profondeur"] = m["profondeur"] / 100.0 if m["profondeur"] < 1000 else m["profondeur"] / 1000.0
        return m
