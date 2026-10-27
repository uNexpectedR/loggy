import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

// The photo is the character. Nothing is drawn behind it.
// This view is a QQuickWidget inside the Basecamp dock, not a cocoa window.
// FramelessWindowHint + NoDropShadowWindowHint + a clear color is what makes a
// real NSWindow translucent. On this widget a clear color composites as black
// (0.1.2) and Qt.Tool hid the child window. A solid clear is the full page, so
// the page matches the shell (#171717) and the root item is not filled.
Item {
    id: root
    anchors.fill: parent

    property string speech: "Before anything else, run a Logos node."
    property string detail: ""
    property bool busy: false
    property bool done: false
    property bool open: true
    property bool userMoved: false
    property real posRight: 0
    property real posBottom: 0

    readonly property string peers: "{\"initial_peers\":[\"/ip4/65.109.51.37/udp/3000/quic-v1/p2p/12D3KooWFrouXfmrR4nsLMtE7wu15DoMJ6VtoUtHinREZCvbWHar\",\"/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWJRGau8M1rjT7R5e4YYsgdFhsMX35nRDtMwCDjxQkXAHz\",\"/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWQXJavMDTRscjauFSgVAB1VLB6Rzpy2uY5SU9Tk7927tb\",\"/ip4/65.109.51.37/udp/50001/quic-v1/p2p/12D3KooWSQc7CcGtvWDPF1yCbBthFnQjprfCVHmfmNDUrSmqQsU1\"]}"

    function matchShell() {
        var host = root.Window.window
        if (!host)
            return
        // Opaque shell color. A clear color on this widget is a black page.
        host.color = "#171717"
    }

    function place() {
        if (width < 40 || height < 40)
            return
        if (!userMoved) {
            assistant.anchorRight = width - 16
            assistant.anchorBottom = height - 16
            return
        }
        assistant.anchorRight = Math.max(64, Math.min(width - 8, posRight))
        assistant.anchorBottom = Math.max(64, Math.min(height - 8, posBottom))
    }

    Component.onCompleted: {
        matchShell()
        place()
    }
    onWidthChanged: place()
    onHeightChanged: place()
    onWindowChanged: matchShell()

    Item {
        id: assistant
        z: 1
        property real anchorRight: 16
        property real anchorBottom: 16
        width: row.implicitWidth
        height: row.implicitHeight
        x: anchorRight - width
        y: anchorBottom - height

        Row {
            id: row
            spacing: 8
            layoutDirection: Qt.RightToLeft

            Item {
                id: faceBox
                width: 168
                height: 214
                property real hop: 0

                SequentialAnimation on hop {
                    loops: Animation.Infinite
                    running: !drag.pressed
                    NumberAnimation {
                        to: 6
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0
                        duration: 800
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation { duration: 1800 }
                }

                Image {
                    id: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: faceBox.hop
                    width: 168
                    height: 198
                    source: "lambda.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property real grabX: 0
                        property real grabY: 0
                        property real originRight: 0
                        property real originBottom: 0
                        property bool dragged: false
                        onPressed: function (mouse) {
                            var p = mapToItem(root, mouse.x, mouse.y)
                            grabX = p.x
                            grabY = p.y
                            originRight = assistant.anchorRight
                            originBottom = assistant.anchorBottom
                            dragged = false
                        }
                        onPositionChanged: function (mouse) {
                            if (!pressed)
                                return
                            var p = mapToItem(root, mouse.x, mouse.y)
                            var dx = p.x - grabX
                            var dy = p.y - grabY
                            if (Math.abs(dx) > 4 || Math.abs(dy) > 4)
                                dragged = true
                            if (!dragged)
                                return
                            assistant.anchorRight = originRight + dx
                            assistant.anchorBottom = originBottom + dy
                        }
                        onReleased: {
                            if (!dragged) {
                                root.open = !root.open
                                return
                            }
                            assistant.anchorRight = Math.max(64, Math.min(root.width - 8, assistant.anchorRight))
                            assistant.anchorBottom = Math.max(64, Math.min(root.height - 8, assistant.anchorBottom))
                            root.posRight = assistant.anchorRight
                            root.posBottom = assistant.anchorBottom
                            root.userMoved = true
                        }
                        onCanceled: dragged = false
                    }
                }
            }

            Rectangle {
                id: bubble
                visible: root.open
                radius: 16
                color: "#fffaf3"
                border.color: "#e4ddd2"
                border.width: 1
                width: visible ? 248 : 0
                height: visible ? column.implicitHeight + 28 : 0
                ColumnLayout {
                    id: column
                    x: 14
                    y: 14
                    width: 220
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: root.speech
                        color: "#221f1a"
                        font.pixelSize: 15
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        visible: text !== ""
                        text: root.detail
                        color: "#5c564c"
                        font.pixelSize: 12
                    }
                    Button {
                        visible: !root.done
                        enabled: !root.busy
                        text: root.detail === "" ? "Run a node" : "Try again"
                        onClicked: root.runNode()
                    }
                }
            }
        }
    }

    function chainRunning(text) {
        return text.indexOf("height") !== -1 || text.indexOf("Bootstrapping") !== -1 || text.indexOf("Online") !== -1
    }

    function finish(info) {
        root.detail = info.slice(0, 600)
        root.speech = "The node is running. Later tasks will be added."
        root.done = true
        root.busy = false
    }

    function runNode() {
        root.busy = true
        root.speech = "Running the node…"
        root.detail = ""
        if (typeof logos === "undefined") {
            root.speech = "The node did not start."
            root.detail = "No logos bridge. Load this module in Basecamp, or use the preview server."
            root.busy = false
            return
        }
        try {
            var info = String(logos.callModule("blockchain_module", "get_cryptarchia_info", []))
            if (chainRunning(info)) {
                finish(info)
                return
            }
            logos.callModule("blockchain_module", "generate_user_config", [peers])
            var started = String(logos.callModule("blockchain_module", "start", ["user_config.yaml", ""]))
            info = String(logos.callModule("blockchain_module", "get_cryptarchia_info", []))
            if (chainRunning(info)) {
                finish(info)
                return
            }
            root.speech = "The node did not start."
            root.detail = (started + "\n" + info).slice(0, 600)
        } catch (error) {
            root.speech = "The node did not start."
            root.detail = String(error).slice(0, 600)
        }
        root.busy = false
    }
}
