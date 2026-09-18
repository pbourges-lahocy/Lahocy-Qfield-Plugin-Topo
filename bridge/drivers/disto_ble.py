# -*- coding: utf-8 -*-
"""
Pilote Leica DISTO Bluetooth Smart (D110 / D2 / D510 / D810...) via BLE (bleak).

Service DISTO  : 3ab10100-f831-4395-b29d-570977d5bf94
  distance     : 3ab10101-...  (float32 little endian, mètres, notification)
  commande     : 3ab10109-...  ("g" = déclencher une mesure, "o" = éteindre)
Les mesures déclenchées sur l'appareil arrivent par notification = usage
« télécommande » du logiciel de référence (une mesure disto = validation / distance).

Non testé sans appareil ; les UUID proviennent de la documentation Leica.
"""
import asyncio
import struct
import threading

from .base import DistoDriver

SERVICE = "3ab10100-f831-4395-b29d-570977d5bf94"
CHAR_DISTANCE = "3ab10101-f831-4395-b29d-570977d5bf94"
CHAR_COMMAND = "3ab10109-f831-4395-b29d-570977d5bf94"


class DistoBLE(DistoDriver):
    name = "disto_ble"

    def __init__(self, address, events):
        super().__init__(events)
        self.address = address
        self.loop = None
        self.client = None
        self.thread = None
        self._measure_event = None
        self.model = "Leica DISTO"

    def connect(self):
        from bleak import BleakClient, BleakScanner  # import tardif

        self.loop = asyncio.new_event_loop()
        self.thread = threading.Thread(target=self.loop.run_forever, daemon=True)
        self.thread.start()

        async def _connect():
            address = self.address
            if not address:
                devices = await BleakScanner.discover(timeout=6.0)
                for d in devices:
                    if d.name and "DISTO" in d.name.upper():
                        address = d.address
                        self.model = d.name
                        break
            if not address:
                raise RuntimeError("Aucun DISTO trouvé en BLE")
            self.client = BleakClient(address)
            await self.client.connect()
            await self.client.start_notify(CHAR_DISTANCE, self._on_distance)

        fut = asyncio.run_coroutine_threadsafe(_connect(), self.loop)
        fut.result(timeout=30)
        self.connected = True

    def _on_distance(self, _handle, data):
        try:
            d = struct.unpack("<f", bytes(data[:4]))[0]
        except Exception:
            return
        self.last_distance = round(float(d), 4)
        self.last_key = "measure"
        # une mesure déclenchée sur l'appareil vaut aussi "touche" (télécommande)
        self.events.push("disto_measure", {"distance": self.last_distance})
        self.events.push("disto_key", {"key": "measure"})
        if self._measure_event:
            self._measure_event.set()

    def measure(self, sim=None):
        if not self.client:
            raise RuntimeError("DISTO non connecté")
        self._measure_event = threading.Event()

        async def _trigger():
            await self.client.write_gatt_char(CHAR_COMMAND, b"g")

        asyncio.run_coroutine_threadsafe(_trigger(), self.loop).result(timeout=5)
        if not self._measure_event.wait(10):
            raise RuntimeError("Pas de mesure DISTO reçue")
        return self.last_distance

    def disconnect(self):
        self.connected = False
        if self.client and self.loop:
            async def _dc():
                try:
                    await self.client.disconnect()
                except Exception:
                    pass
            try:
                asyncio.run_coroutine_threadsafe(_dc(), self.loop).result(timeout=5)
            except Exception:
                pass
        if self.loop:
            self.loop.call_soon_threadsafe(self.loop.stop)
