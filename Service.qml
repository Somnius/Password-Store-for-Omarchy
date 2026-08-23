import QtQuick
import Quickshell
import Quickshell.Io
import "Config.js" as Config

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy/password-store"
  readonly property string configPath: configDir + "/config.json"
  readonly property string boundedReadScriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("BoundedRead.pl")).replace(/^file:\/\//, ""))
  readonly property string atomicWriteScriptPath: decodeURIComponent(
    String(Qt.resolvedUrl("AtomicWrite.pl")).replace(/^file:\/\//, ""))
  readonly property int configMaxBytes: Config.ConfigMaxBytes
  readonly property string repoUrl: "https://github.com/Somnius/Password-Store-for-Omarchy"

  readonly property var providers: ({
    bitwarden:   "https://vault.bitwarden.com",
    vaultwarden: "",
    "1password": "https://my.1password.com",
    lastpass:    "https://lastpass.com/vault/"
  })
  readonly property var providerNames: Config.providerNames()

  // Config
  property string primaryVault: "bitwarden"
  property string vaultUrl: ""            // required for vaultwarden; optional override otherwise
  property string browser: ""             // empty = auto-detect (chromium -> brave)
  property string detectedBrowser: ""
  property bool loaded: false
  property string lastError: ""
  property bool configReadPending: false
  property var pendingConfigValue: null
  property var writingConfigValue: null
  readonly property bool writingConfig: configWriteProc.running
    || pendingConfigValue !== null

  // Dedicated app-window profile per provider: persistent login, cookies kept
  // out of the daily browser.
  function profileDir() {
    return home + "/.local/share/omarchy/password-store/" + primaryVault + "-profile"
  }

  function activeBrowser() {
    var candidate = root.browser !== "" ? root.browser : root.detectedBrowser
    var checked = Config.normalizeBrowser(candidate)
    return checked.ok ? checked.value : ""
  }

  function effectiveUrl() {
    var candidate = root.vaultUrl !== ""
      ? root.vaultUrl : (root.providers[root.primaryVault] || "")
    var checked = Config.normalizeVaultUrl(candidate)
    return checked.ok ? checked.value : ""
  }

  function statusText() {
    if (root.primaryVault === "vaultwarden" && root.vaultUrl === "")
      return "Vaultwarden needs a server URL in config.json"
    return root.primaryVault
  }

  function currentConfig() {
    return { primaryVault: root.primaryVault, vaultUrl: root.vaultUrl, browser: root.browser }
  }

  function saveConfig(patch) {
    var base = root.pendingConfigValue !== null
      ? root.pendingConfigValue
      : (root.writingConfigValue !== null
          ? root.writingConfigValue : root.currentConfig())
    var config = {
      primaryVault: base.primaryVault,
      vaultUrl: base.vaultUrl,
      browser: base.browser
    }
    if (patch && patch.primaryVault !== undefined) config.primaryVault = patch.primaryVault
    if (patch && patch.vaultUrl !== undefined) config.vaultUrl = patch.vaultUrl
    if (patch && patch.browser !== undefined) config.browser = patch.browser
    var checked = Config.validateConfig(config)
    if (!checked.ok) {
      root.lastError = "Invalid configuration: " + checked.error
      return false
    }

    // Keep accepted in-memory state authoritative until the owned atomic
    // writer confirms persistence. Rapid edits coalesce onto the latest value.
    if (configReadProc.running) root.configReadPending = true
    root.pendingConfigValue = checked.value
    configFile.path = ""
    if (!configWriteProc.running) Qt.callLater(root.startPendingConfigWrite)
    return true
  }

  function startPendingConfigWrite() {
    if (configWriteProc.running || root.pendingConfigValue === null) return
    root.writingConfigValue = root.pendingConfigValue
    root.pendingConfigValue = null
    var payload = JSON.stringify(root.writingConfigValue, null, 2) + "\n"
    configWriteProc.command = ["/usr/bin/perl", root.atomicWriteScriptPath,
      root.configPath, String(root.configMaxBytes), payload]
    configWriteProc.running = true
  }

  function onConfigWriteExited(exitCode) {
    var written = root.writingConfigValue
    root.writingConfigValue = null
    if (exitCode === 0 && written !== null) {
      root.commitConfig(written)
      if (root.lastError.indexOf("Could not write config.json:") === 0)
        root.lastError = ""
    } else {
      root.lastError = "Could not write config.json: "
        + root.readFailure(configWriteError.text)
    }

    if (root.pendingConfigValue !== null) {
      Qt.callLater(root.startPendingConfigWrite)
      return
    }
    Qt.callLater(function () {
      if (configWriteProc.running || root.pendingConfigValue !== null) return
      configFile.path = ""
      configFile.path = root.configPath
      root.requestConfigRead()
    })
  }

  function applyConfig(text) {
    var checked = Config.parseConfig(text)
    if (!checked.ok) {
      root.lastError = "Invalid config.json: " + checked.error
      return false
    }
    root.commitConfig(checked.value)
    return true
  }

  function commitConfig(config) {
    root.primaryVault = config.primaryVault
    root.vaultUrl = config.vaultUrl
    root.browser = config.browser
    root.loaded = true
  }

  function clearConfigReadError() {
    if (root.lastError.indexOf("Invalid config.json:") === 0
        || root.lastError.indexOf("Could not read config.json:") === 0)
      root.lastError = ""
  }

  function requestConfigRead() {
    if (configWriteProc.running || root.pendingConfigValue !== null) {
      root.configReadPending = true
      return
    }
    if (configReadProc.running) {
      root.configReadPending = true
      return
    }
    root.configReadPending = false
    configReadProc.running = true
  }

  function readFailure(stderrText) {
    var detail = String(stderrText || "").trim()
    return detail || "bounded read failed"
  }

  function onConfigReadExited(exitCode) {
    var stale = root.configReadPending
    root.configReadPending = false
    if (stale) {
      Qt.callLater(root.requestConfigRead)
      return
    }

    var hadConfig = root.loaded
    if (exitCode === 0) {
      if (root.applyConfig(configReadOutput.text)) {
        root.clearConfigReadError()
      } else if (!root.loaded) {
        var parseError = root.lastError
        root.commitConfig(Config.defaultConfig())
        root.lastError = parseError
      }
      return
    }

    if (!root.loaded) root.commitConfig(Config.defaultConfig())
    if (exitCode !== 2 || hadConfig) {
      root.lastError = "Could not read config.json: "
        + root.readFailure(configReadError.text)
    }
  }

  function setProvider(name) {
    if (root.providerNames.indexOf(name) < 0) return false
    return saveConfig({ primaryVault: name })
  }

  function setVaultUrl(url) {
    var checked = Config.normalizeVaultUrl(url)
    if (!checked.ok) {
      root.lastError = checked.error
      return false
    }
    root.lastError = ""
    return root.saveConfig({ vaultUrl: checked.value })
  }

  function openVault() {
    var urlResult = Config.normalizeVaultUrl(root.effectiveUrl())
    if (!urlResult.ok || urlResult.value === "") return false
    var url = urlResult.value
    var b = root.activeBrowser()
    if (b !== "") {
      var browserResult = Config.normalizeBrowser(b)
      if (!browserResult.ok || browserResult.value === "") {
        root.lastError = "Invalid browser executable"
        return false
      }
      // Standalone app window, isolated per-provider profile: persistent
      // login, cookies quarantined from the daily browser.
      // The validated executable is passed directly as argv[0]; no shell sees it.
      Quickshell.execDetached([browserResult.value, "--app=" + url,
        "--user-data-dir=" + root.profileDir()])
    } else {
      Quickshell.execDetached(["xdg-open", url])
    }
    root.lastError = ""
    return true
  }

  Process {
    id: detectProc
    command: ["bash", "-c", "command -v chromium || command -v brave || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var checked = Config.normalizeBrowser(String(text || "").trim())
        root.detectedBrowser = checked.ok ? checked.value : ""
      }
    }
  }

  FileView {
    id: configFile
    path: ""
    preload: false
    blockAllReads: true
    watchChanges: true
    printErrors: false
    onFileChanged: root.requestConfigRead()
  }

  Process {
    id: configReadProc
    command: ["/usr/bin/perl", root.boundedReadScriptPath,
      root.configPath, String(root.configMaxBytes)]
    stdout: StdioCollector {
      id: configReadOutput
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: configReadError
      waitForEnd: true
    }
    onExited: function(exitCode) { root.onConfigReadExited(exitCode) }
  }

  Process {
    id: configWriteProc
    stderr: StdioCollector {
      id: configWriteError
      waitForEnd: true
    }
    onExited: function(exitCode) { root.onConfigWriteExited(exitCode) }
  }

  Process {
    id: configDirProc
    command: ["mkdir", "-p", root.configDir]
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (!root.loaded) root.commitConfig(Config.defaultConfig())
        root.lastError = "Could not create password-store config directory"
        return
      }
      configFile.path = root.configPath
      root.requestConfigRead()
    }
  }

  Component.onCompleted: {
    configDirProc.running = true
    if (!detectProc.running) detectProc.running = true
  }
}
