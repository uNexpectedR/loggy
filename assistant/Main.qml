import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

// The host view's clear color is white unless we set the window color.
// The character is its own frameless window: it stays above Basecamp,
// and only that window takes clicks.
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

    function clearHost() {
        var host = root.Window.window
        if (host)
            host.color = "transparent"
    }

    function settle() {
        clearHost()
        if (userMoved) {
            if (posRight > 0) {
                floater.anchorRight = posRight
                floater.anchorBottom = posBottom
            }
            return
        }
        if (width < 40 || floater.width < 20)
            return
        var pt = mapToGlobal(width, height)
        var sw = Screen.width
        var sh = Screen.height
        var right = pt.x
        var bottom = pt.y
        if (!(right > 40 && bottom > 40 && right < sw + floater.width && bottom < sh + floater.height)) {
            right = sw
            bottom = sh
        }
        floater.anchorRight = right - 16
        floater.anchorBottom = bottom - 16
    }

    Component.onCompleted: settle()
    onWidthChanged: settle()
    onHeightChanged: settle()
    onWindowChanged: clearHost()

    Window {
        id: floater
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.NoDropShadowWindowHint
        color: "transparent"
        title: ""
        visible: true
        property real anchorRight: Screen.width - 16
        property real anchorBottom: Screen.height - 16
        x: anchorRight - width
        y: anchorBottom - height
        width: panel.implicitWidth
        height: panel.implicitHeight
        onWidthChanged: root.settle()

        Row {
            id: panel
            spacing: 8
            layoutDirection: Qt.RightToLeft

            Item {
                width: 150
                height: 196
                Image {
                    id: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 140
                    height: 180
                    source: "lambda.svg"
                    fillMode: Image.PreserveAspectFit
                    MouseArea {
                        id: dragArea
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
                            var g = mapToGlobal(mouse.x, mouse.y)
                            grabX = g.x
                            grabY = g.y
                            originRight = floater.anchorRight
                            originBottom = floater.anchorBottom
                            dragged = false
                        }
                        onPositionChanged: function (mouse) {
                            if (!pressed)
                                return
                            var g = mapToGlobal(mouse.x, mouse.y)
                            var dx = g.x - grabX
                            var dy = g.y - grabY
                            if (Math.abs(dx) > 4 || Math.abs(dy) > 4)
                                dragged = true
                            if (!dragged)
                                return
                            floater.anchorRight = originRight + dx
                            floater.anchorBottom = originBottom + dy
                        }
                        onReleased: {
                            if (!dragged) {
                                root.open = !root.open
                                return
                            }
                            var faceSpan = 72
                            floater.anchorRight = Math.max(faceSpan, Math.min(Screen.width - 8, floater.anchorRight))
                            floater.anchorBottom = Math.max(faceSpan, Math.min(Screen.height - 8, floater.anchorBottom))
                            root.posRight = floater.anchorRight
                            root.posBottom = floater.anchorBottom
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
                width: visible ? 260 : 0
                height: visible ? column.implicitHeight + 28 : 0
                ColumnLayout {
                    id: column
                    x: 14
                    y: 14
                    width: 232
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
