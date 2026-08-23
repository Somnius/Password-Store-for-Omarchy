.pragma library

var ConfigMaxBytes = 32768
var VaultUrlMaxChars = 4096
var BrowserMaxChars = 4096
var ExecutableNameMaxChars = 255
var ProviderNames = ["bitwarden", "vaultwarden", "1password", "lastpass"]

function ok(value) {
  return { ok: true, value: value, error: "" }
}

function rejected(message) {
  return { ok: false, value: null, error: message }
}

function providerNames() {
  return ProviderNames.slice(0)
}

function validProvider(value) {
  return typeof value === "string" && ProviderNames.indexOf(value) >= 0
}

function normalizeVaultUrl(value) {
  if (typeof value !== "string") return rejected("vaultUrl must be a string")
  if (value.length > VaultUrlMaxChars)
    return rejected("vaultUrl exceeds " + VaultUrlMaxChars + " characters")

  var url = value.trim()
  if (url === "") return ok("")
  if (!/^https?:\/\//i.test(url))
    return rejected("vaultUrl must start with http:// or https://")
  if (/[\s\u0000-\u001f\u007f-\u009f\\]/.test(url))
    return rejected("vaultUrl must not contain controls, whitespace or backslashes")

  var parsed
  try { parsed = new URL(url) }
  catch (error) { return rejected("vaultUrl is malformed") }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:")
    return rejected("vaultUrl must use http or https")
  if (parsed.hostname === "") return rejected("vaultUrl must include a host")
  if (parsed.username !== "" || parsed.password !== "")
    return rejected("vaultUrl must not contain credentials")

  if (parsed.protocol === "http:") {
    var host = parsed.hostname.toLowerCase().replace(/^\[|\]$/g, "")
    var loopback = host === "localhost" || host === "::1"
    var ipv4 = host.match(/^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$/)
    if (ipv4) {
      loopback = Number(ipv4[1]) === 127
      for (var i = 1; i <= 4 && loopback; i++)
        loopback = Number(ipv4[i]) >= 0 && Number(ipv4[i]) <= 255
    }
    if (!loopback) return rejected("vaultUrl must use https unless the host is loopback")
  }

  return ok(url)
}

function safePathComponent(component) {
  return component !== "" && component !== "." && component !== ".."
    && component.length <= ExecutableNameMaxChars
    && /^[A-Za-z0-9._+-]+$/.test(component)
}

function normalizeBrowser(value) {
  if (typeof value !== "string") return rejected("browser must be a string")
  if (value.length > BrowserMaxChars)
    return rejected("browser exceeds " + BrowserMaxChars + " characters")

  var executable = value.trim()
  if (executable === "") return ok("")

  if (executable.indexOf("/") < 0) {
    if (executable.length <= ExecutableNameMaxChars
        && /^[A-Za-z0-9][A-Za-z0-9._+-]*$/.test(executable))
      return ok(executable)
    return rejected("browser must be a safe executable name or absolute path")
  }

  if (executable.charAt(0) !== "/")
    return rejected("browser paths must be absolute")
  var components = executable.split("/")
  for (var i = 1; i < components.length; i++) {
    if (!safePathComponent(components[i]))
      return rejected("browser must be a safe executable name or absolute path")
  }
  return ok(executable)
}

function defaultConfig() {
  return { primaryVault: "bitwarden", vaultUrl: "", browser: "" }
}

function validateConfig(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value))
    return rejected("expected a configuration object")

  var provider = value.primaryVault === undefined
    ? "bitwarden" : value.primaryVault
  if (!validProvider(provider))
    return rejected("primaryVault is not a supported provider")

  var urlResult = normalizeVaultUrl(value.vaultUrl === undefined ? "" : value.vaultUrl)
  if (!urlResult.ok) return urlResult
  var browserResult = normalizeBrowser(value.browser === undefined ? "" : value.browser)
  if (!browserResult.ok) return browserResult

  return ok({
    primaryVault: provider,
    vaultUrl: urlResult.value,
    browser: browserResult.value
  })
}

function parseConfig(text) {
  if (typeof text !== "string") return rejected("expected UTF-8 JSON text")
  // Valid UTF-8 always has at least as many bytes as JavaScript UTF-16 code
  // units, so this is a safe second bound after the producer's byte limit.
  if (text.length > ConfigMaxBytes) return rejected("config exceeds byte limit")
  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (error) {
    return rejected("malformed JSON")
  }
  return validateConfig(parsed)
}
