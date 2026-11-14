import QtQuick
import Quickshell
import Quickshell.Io

// One template request to Home Assistant every few seconds while the tile can be seen, plus service calls.
// The address and token live in ~/.config/omarchy-widgets/home-assistant.json: { "url": "...", "token": "..." }
Item {
  id: hass

  property bool live: false
  property string template: ""
  property int every: 5000
  property var result: null
  // "" fine, "token" none or refused, "offline" no answer, "template" Home Assistant could not render it
  property string problem: "token"

  property string url: "http://localhost:8123"
  property string token: ""
  property bool asking: false
  property int misses: 0
  readonly property string secrets: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy-widgets/home-assistant.json"

  property var asked: []

  // an answer must not arrive for a tile that is already gone
  Component.onDestruction: asked.forEach(function(request) { request.abort() })

  function post(path, body, done) {
    var request = new XMLHttpRequest()
    asked = asked.filter(function(old) { return old.readyState !== XMLHttpRequest.DONE }).concat([request])
    request.onreadystatechange = function() {
      if (request.readyState === XMLHttpRequest.DONE) done(request.status, request.responseText)
    }
    request.open("POST", url.replace(/\/+$/, "") + path)
    request.setRequestHeader("Authorization", "Bearer " + token)
    request.setRequestHeader("Content-Type", "application/json")
    request.send(JSON.stringify(body))
  }

  function refresh() {
    if (token === "" || template === "" || asking) return
    asking = true
    post("/api/template", { template: template }, function(status, text) {
      asking = false
      if (status === 200) {
        try {
          result = JSON.parse(text)
          problem = ""
          misses = 0
        } catch (error) {
          problem = "template"
        }
        return
      }
      misses++
      problem = status === 401 || status === 403 ? "token" : status === 0 ? "offline" : "template"
    })
  }

  function call(domain, service, target) {
    if (token === "") return
    post("/api/services/" + domain + "/" + service, target, function() { settle.restart() })
  }

  onTemplateChanged: if (live) refresh()

  FileView {
    path: hass.secrets
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var file = JSON.parse(text())
        hass.url = file.url || "http://localhost:8123"
        hass.token = String(file.token || "").trim()
      } catch (error) {
        hass.token = ""
      }
      hass.problem = hass.token === "" ? "token" : hass.problem
      if (hass.live) hass.refresh()
    }
    onLoadFailed: { hass.token = ""; hass.problem = "token" }
  }

  // an unreachable Home Assistant is asked less and less often, down to once a minute
  Timer {
    interval: Math.min(60000, hass.every * Math.pow(2, Math.min(4, hass.misses)))
    repeat: true
    running: hass.live && hass.token !== ""
    triggeredOnStart: true
    onTriggered: hass.refresh()
  }

  Timer { id: settle; interval: 500; onTriggered: hass.refresh() }
}
