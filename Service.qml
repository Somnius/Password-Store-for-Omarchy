import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/password-store"
  readonly property string configPath: configDir + "/config.json"
  readonly property string repoUrl: "https://github.com/Somnius/Omarchy-Password-Store"

  readonly property var providers: ({
    bitwarden:   "https://vault.bitwarden.com",
    vaultwarden: "",
    "1password": "https://my.1password.com",
    lastpass:    "https://lastpass.com/vault/"
  })
  readonly property var providerNames: ["bitwarden", "vaultwarden", "1password", "lastpass"]

  // Config
  property string primaryVault: "bitwarden"
  property string vaultUrl: ""            // required for vaultwarden; optional override otherwise
  property string browser: ""             // empty = auto-detect (chromium -> brave)
  property string detectedBrowser: ""
  property bool loaded: false
  property string lastError: ""

  // Dedicated app-window profile per provider: persistent login, cookies kept
  // out of the daily browser.
  function profileDir() {
    return home + "/.local/share/omarchy/password-store/" + primaryVault + "-profile"
  }

  function activeBrowser() {
    return root.browser !== "" ? root.browser : root.detectedBrowser
  }

  function effectiveUrl() {
    if (root.vaultUrl !== "") return root.vaultUrl
    return root.providers[root.primaryVault] || ""
  }

  function statusText() {
    if (root.primaryVault === "vaultwarden" && root.vaultUrl === "")
      return "Vaultwarden needs a server URL in config.json"
    return root.primaryVault
  }

  function normalize(c) {
    c = c || {}
    var out = {}
    out.primaryVault = root.providerNames.indexOf(c.primaryVault) >= 0 ? c.primaryVault : "bitwarden"
    out.vaultUrl = typeof c.vaultUrl === "string" ? c.vaultUrl.trim() : ""
    out.browser = typeof c.browser === "string" ? c.browser.trim() : ""
    return out
  }

  function currentConfig() {
    return { primaryVault: root.primaryVault, vaultUrl: root.vaultUrl, browser: root.browser }
  }

  function saveConfig(patch) {
    var config = root.currentConfig()
    for (var key in patch) config[key] = patch[key]
    config = root.normalize(config)
    configFile.setText(JSON.stringify(config, null, 2) + "\n")
    root.applyConfig(JSON.stringify(config))
  }

  function applyConfig(text) {
    var parsed = {}
    try { parsed = text && text.trim() ? JSON.parse(text) : {} }
    catch (error) { root.lastError = "Invalid config.json: " + error }
    var config = root.normalize(parsed)
    root.primaryVault = config.primaryVault
    root.vaultUrl = config.vaultUrl
    root.loaded = true
  }

  function setProvider(name) {
    if (root.providerNames.indexOf(name) < 0) return
    saveConfig({ primaryVault: name })
  }

  function setVaultUrl(url) {
    var u = String(url || "").trim()
    if (u !== "" && u.indexOf("http://") !== 0 && u.indexOf("https://") !== 0) {
      root.lastError = "URL must start with http:// or https://"
      return
    }
    root.lastError = ""
    saveConfig({ vaultUrl: u })
  }

  function openVault() {
    var url = root.effectiveUrl()
    if (url === "") return false
    var b = root.activeBrowser()
    if (b !== "") {
      // Standalone app window, isolated per-provider profile: persistent
      // login, cookies quarantined from the daily browser.
      openProc.command = [b, "--app=" + url, "--user-data-dir=" + root.profileDir()]
    } else {
      openProc.command = ["xdg-open", url]
    }
    openProc.running = true
    return true
  }

  Process {
    id: detectProc
    command: ["bash", "-c", "command -v chromium || command -v brave || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.detectedBrowser = String(text || "").trim()
    }
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onLoaded: root.applyConfig(text())
    onLoadFailed: root.applyConfig("")
    onFileChanged: reload()
  }

  Process {
    id: openProc
  }

  Process {
    id: configDirProc
    command: ["mkdir", "-p", root.configDir]
  }

  Component.onCompleted: {
    configDirProc.running = true
    if (!detectProc.running) detectProc.running = true
  }
}
