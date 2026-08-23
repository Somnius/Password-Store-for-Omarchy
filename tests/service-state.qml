import QtQuick
import Quickshell
import Quickshell.Io
import "." as PasswordStore

ShellRoot {
  id: testRoot

  property int phase: 0
  property int attempts: 0

  function fail(message) {
    console.error("service state test failed: " + message)
    Qt.quit()
  }

  PasswordStore.Service {
    id: service
  }

  Process {
    id: replacement
    onExited: function(exitCode) {
      if (exitCode !== 0) testRoot.fail("external replacement failed")
    }
  }

  Timer {
    interval: 25
    repeat: true
    running: true
    onTriggered: {
      testRoot.attempts++
      if (testRoot.attempts >= 300) testRoot.fail("state transition timed out in phase " + testRoot.phase)

      if (!service.loaded) {
        return
      }

      if (testRoot.phase === 0) {
        if (!service.applyConfig(JSON.stringify({
          primaryVault: "vaultwarden",
          vaultUrl: "https://vault.example.com/base",
          browser: "/usr/bin/chromium"
        }))) return testRoot.fail("valid config was rejected")

        if (service.applyConfig('{"primaryVault":"lastpass","browser":"bad arg"}'))
          return testRoot.fail("unsafe browser was accepted")
        if (service.applyConfig("{")) return testRoot.fail("malformed JSON was accepted")
        if (service.primaryVault !== "vaultwarden"
            || service.vaultUrl !== "https://vault.example.com/base"
            || service.browser !== "/usr/bin/chromium")
          return testRoot.fail("rejected input replaced last-good state")

        service.clearConfigReadError()
        if (!service.saveConfig({ primaryVault: "lastpass", vaultUrl: "", browser: "" }))
          return testRoot.fail("first save was rejected")
        if (!service.saveConfig({ primaryVault: "1password" }))
          return testRoot.fail("coalesced save was rejected")
        if (service.primaryVault !== "vaultwarden")
          return testRoot.fail("state committed before persistence confirmation")
        testRoot.phase = 1
        return
      }

      if (testRoot.phase === 1 && !service.writingConfig) {
        if (service.primaryVault !== "1password")
          return testRoot.fail("latest persisted config was not committed")
        replacement.command = ["/usr/bin/perl", service.atomicWriteScriptPath,
          service.configPath, String(service.configMaxBytes), "{"]
        replacement.running = true
        testRoot.phase = 2
        return
      }

      if (testRoot.phase === 2
          && service.lastError.indexOf("Invalid config.json:") === 0) {
        if (service.primaryVault !== "1password")
          return testRoot.fail("malformed replacement displaced last-good state")
        var valid = JSON.stringify({
          primaryVault: "vaultwarden",
          vaultUrl: "https://vault.recovered.example",
          browser: ""
        }) + "\n"
        replacement.command = ["/usr/bin/perl", service.atomicWriteScriptPath,
          service.configPath, String(service.configMaxBytes), valid]
        replacement.running = true
        testRoot.phase = 3
        return
      }

      if (testRoot.phase === 3
          && service.primaryVault === "vaultwarden"
          && service.vaultUrl === "https://vault.recovered.example") {
        console.log("service state transition checks passed")
        stop()
        Qt.quit()
      }
    }
  }
}
