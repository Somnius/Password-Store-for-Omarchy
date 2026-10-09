import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "lef.password-store"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() { controller.show() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: Style.space(12)

        PanelHero {
          Layout.fillWidth: true
          title: "Password Store"
          meta: root.service ? root.service.statusText() : "Service unavailable"
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "\uf084"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        PanelSectionHeader {
          Layout.fillWidth: true
          text: "VAULT"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Dropdown {
          Layout.fillWidth: true
          label: "Provider"
          value: root.service ? root.service.primaryVault : "bitwarden"
          options: root.service ? root.service.providerNames : []
          foreground: root.foreground
          fontFamily: root.fontFamily
          enabled: root.service !== null
          onChanged: function (value) { if (root.service) root.service.setProvider(value) }
        }

        Text {
          Layout.fillWidth: true
          text: root.service && root.service.effectiveUrl() !== ""
            ? root.service.effectiveUrl()
            : "Vaultwarden needs its server URL in ~/.config/omarchy/password-store/config.json"
          textFormat: Text.PlainText
          color: root.service && root.service.effectiveUrl() !== "" ? root.dim : root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Button {
          Layout.fillWidth: true
          text: "Open vault window"
          iconText: "󰖟"
          bordered: true
          focusable: true
          enabled: root.service !== null && root.service.effectiveUrl() !== ""
          foreground: root.foreground
          accent: Commons.Color.accent
          fontFamily: root.fontFamily
          onClicked: if (root.service) root.service.openVault()
        }

        Text {
          Layout.fillWidth: true
          text: root.service && root.service.activeBrowser() !== ""
            ? "Opens in a dedicated chromium app window with its own profile — sign in once and it stays signed in, separate from your daily browser."
            : "No chromium-family browser found; falls back to your default browser."
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        PanelSectionHeader {
          Layout.fillWidth: true
          text: "SECURITY MODEL"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Text {
          Layout.fillWidth: true
          text: "This plugin stores no credentials, no master password and no secrets — not encrypted, not cached, nowhere. Unlocking, search and autofill happen inside your browser session, protected by your vault's own 2FA and device approvals."
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          Layout.fillWidth: true
          text: "The only file written is config.json: your provider choice and an optional self-hosted URL."
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }

        Button {
          Layout.fillWidth: true
          text: "Source code · MIT license"
          bordered: true
          focusable: true
          enabled: root.service !== null
          foreground: root.foreground
          accent: Commons.Color.accent
          fontFamily: root.fontFamily
          onClicked: if (root.service) Qt.openUrlExternally(root.service.repoUrl)
        }
      }
    }
  }
}
