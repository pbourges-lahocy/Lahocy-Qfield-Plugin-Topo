// Lahocy Topo Link : application compagnon Android du plugin QField « Lahocy Topo ».
// Elle ouvre la liaison Bluetooth avec la station totale (GeoCOM), le DISTO (BLE)
// ou le détecteur (SPP) et sert le même contrat HTTP local que bridge/topo_bridge.py.
plugins {
    id("com.android.application") version "8.5.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.20" apply false
}
