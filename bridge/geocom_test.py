# -*- coding: utf-8 -*-
"""
Test autonome de la liaison GeoCOM avec une station totale Leica (TS13 / TS16 / TS60...),
SANS QField ni pont : à passer en premier pour valider le câblage, le port COM, la
vitesse et la licence GeoCOM.

    pip install pyserial
    python bridge/geocom_test.py --list                 # liste des ports COM
    python bridge/geocom_test.py COM5                   # test complet (115200 bauds)
    python bridge/geocom_test.py COM5 --baud 19200
    python bridge/geocom_test.py COM5 --measure         # + une mesure de distance sur le prisme

Étapes : ouverture du port, COM_NullProc (ping), nom de l'instrument, niveau de
batterie, lecture des angles, état du verrouillage prisme, puis (option) une mesure.

Rappels TS13 : bouton COM > 5 s pour passer en mode GeoCOM (sinon mode CS20 = carnet),
LED verte = Bluetooth interne longue portée, LED rouge = poignée radio RH17. Le port COM
« sortant » du couplage Bluetooth Windows est celui à utiliser.
"""
import argparse
import sys
import time


def list_ports():
    try:
        from serial.tools import list_ports
    except ImportError:
        print("pyserial manquant : pip install pyserial")
        return
    ports = list(list_ports.comports())
    if not ports:
        print("Aucun port COM détecté.")
    for p in ports:
        print(f"  {p.device:8} {p.description}")


def main():
    ap = argparse.ArgumentParser(description="Test de liaison GeoCOM")
    ap.add_argument("port", nargs="?", help="port COM (ex. COM5)")
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--list", action="store_true", help="lister les ports COM")
    ap.add_argument("--measure", action="store_true", help="déclencher une mesure de distance")
    ap.add_argument("--reflectorless", action="store_true", help="mesure sans prisme")
    args = ap.parse_args()

    if args.list or not args.port:
        list_ports()
        if not args.port:
            return

    try:
        import serial  # noqa: F401
    except ImportError:
        sys.exit("pyserial manquant : pip install pyserial")
    sys.path.insert(0, __import__("os").path.dirname(__file__))
    from drivers import geocom

    class Events:
        def push(self, kind, payload=None):
            print(f"   [événement] {kind} {payload or ''}")

    print(f"1. Ouverture de {args.port} à {args.baud} bauds…")
    d = geocom.GeoComDriver(args.port, args.baud, Events())
    try:
        d.connect()
    except Exception as e:
        sys.exit(f"   ÉCHEC : {e}\n   Vérifier : port COM (sortant), vitesse, interface GeoCOM affectée au bon port sur la station (Instrument > Connexions), appairage Bluetooth.")
    print(f"   OK, latence {d.latency_ms} ms")
    print(f"2. Instrument : {d.model}")
    try:
        rc, vals = d.request(geocom.CSV_CheckPower, [], timeout=3)
        print(f"3. Batterie : {vals[0]} %  (rc={rc})" if rc == 0 else f"3. Batterie : rc={rc}")
    except Exception as e:
        print(f"3. Batterie : erreur {e}")
    try:
        a = d.angles()
        print(f"4. Angles : Hz {a['hz']:.4f} gr   V {a['v']:.4f} gr" + (f"   (avertissement : {a['warn']})" if a.get('warn') else ""))
    except Exception as e:
        print(f"4. Angles : erreur {e}")
    try:
        rc, vals = d.request(geocom.MOT_ReadLockStatus, [], timeout=3)
        etat = {0: "non verrouillé", 1: "verrouillé sur le prisme", 2: "prédiction"}.get(int(vals[0]) if vals else -1, "?")
        print(f"5. Verrouillage prisme : {etat}  (rc={rc})")
    except Exception as e:
        print(f"5. Verrouillage : erreur {e}")
    if args.measure:
        print("6. Mesure de distance… (viser le prisme)")
        t = time.time()
        try:
            m = d.measure("sans_prisme" if args.reflectorless else "prisme")
            print(f"   Hz {m['hz']:.4f} gr   V {m['v']:.4f} gr   Di {m['sd']:.3f} m   ({time.time() - t:.1f} s)")
        except Exception as e:
            print(f"   ÉCHEC : {e}")
    d.disconnect()
    print("Terminé.")


if __name__ == "__main__":
    main()
