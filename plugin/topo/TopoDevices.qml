import QtQuick

/*
 * TopoDevices - client HTTP du pont local « Lahocy Bridge » (station totale,
 * disto, détecteur). Interroge /status périodiquement et /events en long-poll.
 */
Item {
  id: devices

  property string url: "http://127.0.0.1:8765"
  property bool polling: true
  property bool reachable: false
  property var status: ({ "tps": { "connected": false }, "disto": { "connected": false }, "detector": { "connected": false } })
  property int lastSeq: 0
  property int pollInterval: 700

  readonly property bool tpsConnected: !!(status.tps && status.tps.connected)
  readonly property bool tpsLocked: !!(status.tps && status.tps.locked)
  readonly property bool tpsBusy: !!(status.tps && status.tps.busy)
  readonly property string tpsModel: status.tps ? (status.tps.model || "") : ""
  readonly property var tpsLatency: status.tps ? status.tps.latency_ms : null
  readonly property var tpsBattery: status.tps ? status.tps.battery : null
  readonly property real tpsHz: (status.tps && typeof status.tps.hz === "number") ? status.tps.hz : NaN
  readonly property real tpsV: (status.tps && typeof status.tps.v === "number") ? status.tps.v : NaN
  readonly property real tpsSd: (status.tps && typeof status.tps.sd === "number") ? status.tps.sd : NaN
  readonly property bool tpsTracking: !!(status.tps && status.tps.tracking)
  readonly property bool distoConnected: !!(status.disto && status.disto.connected)
  readonly property bool detectorConnected: !!(status.detector && status.detector.connected)
  readonly property var detectorPending: status.detector ? status.detector.pending : null

  // "LEDs" de latence radio (5 = excellent, 0 = pas d'échange)
  readonly property int leds: !tpsConnected ? 0 : (tpsLatency === null ? 0 : tpsLatency < 100 ? 5 : tpsLatency < 200 ? 4 : tpsLatency < 400 ? 3 : tpsLatency < 800 ? 2 : 1)

  signal tpsMeasure(var obs)
  signal tpsLock(bool locked)
  signal searchDone(bool found)
  signal distoMeasure(real distance)
  signal distoKey(string key)
  signal detectorMeasure(var mesure)
  signal error(string message)

  function request(method, path, body, cb) {
    let xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE) return;
      if (xhr.status !== 200) {
        if (cb) cb({ "ok": false, "error": xhr.status === 0 ? "pont injoignable" : ("HTTP " + xhr.status) });
        return;
      }
      let res = null;
      try { res = JSON.parse(xhr.responseText); } catch (e) { res = { "ok": false, "error": "réponse invalide" }; }
      if (cb) cb(res);
    };
    xhr.open(method, url + path);
    if (method === "POST") xhr.setRequestHeader("Content-Type", "application/json");
    xhr.send(method === "POST" ? JSON.stringify(body || {}) : null);
  }

  function get(path, cb) { request("GET", path, null, cb); }
  function post(path, body, cb) { request("POST", path, body, cb); }

  /* ---------------- appels usuels ---------------- */
  function tpsConnect(driver, port, baud, cb) { post("/tps/connect", { "driver": driver, "port": port, "baud": baud }, cb); }
  function tpsDisconnect(cb) { post("/tps/disconnect", {}, cb); }
  function tpsMeasureRequest(mode, face, sim, cb) { post("/tps/measure", { "mode": mode || "prisme", "face": face || 1, "sim": sim || null }, cb); }
  function tpsAngles(sim, cb) { post("/tps/angles", { "sim": sim || null }, cb); }
  function tpsSearch(type, params, cb) { post("/tps/search", Object.assign({ "type": type }, params || {}), cb); }
  function tpsStop(cb) { post("/tps/stop", {}, cb); }
  function tpsJoystick(dir, speed, cb) { post("/tps/joystick", { "dir": dir, "speed": speed }, cb); }
  function tpsTurn(hz, v, search, cb) { post("/tps/turn", { "hz": hz, "v": v, "search": !!search }, cb); }
  function tpsLockRequest(on, cb) { post("/tps/lock", { "on": on }, cb); }
  function tpsLaser(on, cb) { post("/tps/laser", { "on": on }, cb); }
  function tpsTracking(on, cb) { post("/tps/tracking", { "on": on }, cb); }
  function tpsSetup(state, cb) { post("/tps/setup", state, cb); }
  function distoConnect(driver, address, cb) { post("/disto/connect", { "driver": driver, "address": address || "" }, cb); }
  function distoMeasureRequest(sim, cb) { post("/disto/measure", { "sim": sim || null }, cb); }
  function detectorConnect(driver, port, baud, model, cb) { post("/detector/connect", { "driver": driver, "port": port, "baud": baud, "model": model }, cb); }
  function detectorSimulate(values, cb) { post("/detector/simulate", values, cb); }
  function detectorAck(cb) { post("/detector/ack", {}, cb); }

  /* ---------------- statut ---------------- */
  Timer {
    id: statusTimer
    interval: devices.pollInterval
    repeat: true
    running: devices.polling
    triggeredOnStart: true
    onTriggered: {
      devices.get("/status", function (res) {
        if (!res || !res.ok) {
          if (devices.reachable) { devices.reachable = false; devices.status = { "tps": { "connected": false }, "disto": { "connected": false }, "detector": { "connected": false } }; }
          return;
        }
        if (!devices.reachable) devices.lastSeq = res.seq || 0; // ne pas rejouer l'historique du pont
        devices.reachable = true;
        devices.status = res;
        if (!eventsLoop.running) eventsLoop.start();
      });
    }
  }

  /* ---------------- événements (long-poll) ---------------- */
  property bool eventsBusy: false
  Timer {
    id: eventsLoop
    interval: 200
    repeat: true
    running: false
    onTriggered: {
      if (devices.eventsBusy || !devices.reachable) return;
      devices.eventsBusy = true;
      devices.get("/events?since=" + devices.lastSeq + "&timeout=20", function (res) {
        devices.eventsBusy = false;
        if (!res || !res.ok) return;
        for (const ev of (res.events || [])) {
          if (ev.seq > devices.lastSeq) devices.lastSeq = ev.seq;
          devices.dispatch(ev);
        }
      });
    }
  }

  function dispatch(ev) {
    switch (ev.kind) {
      case "tps_measure": tpsMeasure(ev.data); break;
      case "tps_lock": tpsLock(!!ev.data.locked); break;
      case "tps_search_done": searchDone(!!ev.data.found); break;
      case "disto_measure": distoMeasure(Number(ev.data.distance)); break;
      case "disto_key": distoKey(String(ev.data.key || "")); break;
      case "detector_measure": detectorMeasure(ev.data); break;
      default: break;
    }
  }
}
