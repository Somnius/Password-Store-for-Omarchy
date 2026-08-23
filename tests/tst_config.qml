import QtQuick
import QtTest
import "../Config.js" as Config

TestCase {
  name: "PasswordStoreConfig"

  function expectRejected(json) {
    var result = Config.parseConfig(json)
    verify(!result.ok, "config unexpectedly accepted: " + json)
  }

  function test_supportedProvidersAndSelfHostedUrls() {
    var providers = ["bitwarden", "vaultwarden", "1password", "lastpass"]
    for (var i = 0; i < providers.length; i++) {
      var result = Config.parseConfig(JSON.stringify({ primaryVault: providers[i] }))
      verify(result.ok)
      compare(result.value.primaryVault, providers[i])
    }

    var urls = [
      "https://vault.example.com",
      "https://vault.example.com/base/path?client=web#login",
      "http://localhost:8080",
      "https://192.168.1.5:8443",
      "http://[::1]:8080"
    ]
    for (var j = 0; j < urls.length; j++) {
      var urlResult = Config.normalizeVaultUrl(urls[j])
      verify(urlResult.ok, urlResult.error)
      compare(urlResult.value, urls[j])
    }
  }

  function test_unsafeConfigShapesAndFieldsAreRejected() {
    expectRejected("")
    expectRejected("{")
    expectRejected("null")
    expectRejected("[]")
    expectRejected('{"primaryVault":7}')
    expectRejected('{"primaryVault":"other"}')
    expectRejected('{"vaultUrl":7}')
    expectRejected('{"browser":false}')
    expectRejected('{"vaultUrl":"ftp://vault.example.com"}')
    expectRejected('{"vaultUrl":"https://:"}')
    expectRejected('{"vaultUrl":"https://[]"}')
    expectRejected('{"vaultUrl":"http://vault.example.com"}')
    expectRejected('{"vaultUrl":"http://192.168.1.5:8080"}')
    expectRejected('{"vaultUrl":"http://127.256.0.1"}')
    expectRejected('{"vaultUrl":"http://127.999.999.999"}')
    expectRejected('{"vaultUrl":"https://user:secret@vault.example.com"}')
    expectRejected('{"vaultUrl":"https://vault.example.com\\n--other-option"}')
    expectRejected('{"vaultUrl":"https://vault.example.com/\\u0000tail"}')
    expectRejected('{"vaultUrl":"https://vault.example.com/\\u001btail"}')
    expectRejected('{"browser":"chromium --incognito"}')
    expectRejected('{"browser":"../bin/chromium"}')
    expectRejected('{"browser":"/usr/bin/../bin/chromium"}')
    expectRejected('{"browser":"$(touch /tmp/not-run)"}')
  }

  function test_stringBoundsAreEnforced() {
    var tooLongUrl = "https://vault.example/" + "a".repeat(Config.VaultUrlMaxChars)
    var tooLongBrowser = "a".repeat(Config.BrowserMaxChars + 1)
    verify(!Config.normalizeVaultUrl(tooLongUrl).ok)
    verify(!Config.normalizeBrowser(tooLongBrowser).ok)
    verify(!Config.parseConfig(" ".repeat(Config.ConfigMaxBytes + 1)).ok)
  }

  function test_browserExecutableContract() {
    var accepted = [
      "chromium",
      "brave-browser",
      "google-chrome-stable",
      "/usr/bin/chromium",
      "/home/user/.local/bin/chromium",
      "/nix/store/abc123-chromium/bin/chromium"
    ]
    for (var i = 0; i < accepted.length; i++) {
      var result = Config.normalizeBrowser(accepted[i])
      verify(result.ok, result.error)
      compare(result.value, accepted[i])
    }
  }
}
