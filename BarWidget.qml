import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  // The bar only shows a tooltip for a target that reports itself hovered (Omarchy 4.0.4).
  readonly property bool tooltipHovered: visible && mouseArea.containsMouse
  moduleName: "lef.password-store"

  readonly property var service: bar && bar.shell
    ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool ready: service !== null && service.loaded

  implicitWidth: glyph.implicitWidth + Style.space(12)
  implicitHeight: barSize

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = root
    target.hostWidget = root
    target.service = root.service
  }

  onBarChanged: injectPanel()
  onServiceChanged: injectPanel()

  Text {
    id: glyph
    anchors.centerIn: parent
    // nf-fa-key; raw U+26BF renders as a tiny fallback glyph in the bar font.
    text: "\uf084"
    textFormat: Text.PlainText
    color: root.bar ? root.bar.barForeground : Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    opacity: root.ready ? 1 : 0.45
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: function () {
      if (!root.ready) return
      root.toggle()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root,
      root.ready ? "Password Store · " + root.service.statusText() : "Password Store")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function launch(): string {
      if (!root.ready) return "service not ready"
      return root.service.openVault() ? "vault launch requested" : "no valid vault URL configured"
    }
    function status(): string {
      if (!root.ready) return "service not ready"
      return JSON.stringify({
        provider: root.service.primaryVault,
        url: root.service.effectiveUrl(),
        browser: root.service.activeBrowser(),
        error: root.service.lastError
      })
    }
  }
}
