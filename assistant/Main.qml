import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

// The photo is shown as-is. Its gray is #5b5b5b, which does not match
// Basecamp's #171717, so the window clear is the photo's gray. The root item
// is not filled and no pixels are removed from the picture.
Item {
    id: root
    anchors.fill: parent

    property string speech: "Before anything else, run a Logos node."
    property string detail: ""
    property bool busy: false
    property bool done: false
    property bool failed: false
    property bool open: true
    property bool userMoved: false
    property real posRight: 0
    property real posBottom: 0

    readonly property string peers: "{\"initial_peers\":[\"/ip4/65.109.51.37/udp/3000/quic-v1/p2p/12D3KooWFrouXfmrR4nsLMtE7wu15DoMJ6VtoUtHinREZCvbWHar\",\"/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWJRGau8M1rjT7R5e4YYsgdFhsMX35nRDtMwCDjxQkXAHz\",\"/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWQXJavMDTRscjauFSgVAB1VLB6Rzpy2uY5SU9Tk7927tb\",\"/ip4/65.109.51.37/udp/50001/quic-v1/p2p/12D3KooWSQc7CcGtvWDPF1yCbBthFnQjprfCVHmfmNDUrSmqQsU1\"]}"

    function matchShell() {
        var host = root.Window.window
        if (host)
            host.color = "#5b5b5b"
    }

    // Page matches the photo's gray. Do not put a rectangle behind the picture.
    Binding {
        target: root.Window.window
        property: "color"
        value: "#5b5b5b"
        when: root.Window.window !== null
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
                width: 164
                height: 227
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
                    width: 164
                    height: 219
                    source: "lambda-full.jpg"
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
                clip: true
                radius: 16
                color: "#fffaf3"
                border.color: "#e4ddd2"
                border.width: 1
                width: visible ? 248 : 0
                height: visible ? column.implicitHeight + 28 : 0
                Column {
                    id: column
                    x: 14
                    y: 14
                    width: 220
                    spacing: 8
                    Text {
                        width: column.width
                        wrapMode: Text.Wrap
                        text: root.speech
                        color: "#221f1a"
                        font.pixelSize: 15
                    }
                    Text {
                        width: column.width
                        wrapMode: Text.Wrap
                        visible: text !== ""
                        text: root.detail
                        color: "#5c564c"
                        font.pixelSize: 12
                    }
                    Button {
                        visible: !root.done
                        enabled: !root.busy
                        text: root.failed ? "Try again" : "Run a node"
                        onClicked: root.runNode()
                    }
                }
            }
        }
    }

    function quotedValue(text, name) {
        var mark = '"' + name + '"'
        var at = text.indexOf(mark)
        if (at < 0)
            return ""
        var rest = text.slice(at + mark.length)
        var colon = rest.indexOf(":")
        if (colon < 0)
            return ""
        rest = rest.slice(colon + 1)
        var i = 0
        while (i < rest.length && " \n\t\r".indexOf(rest.charAt(i)) !== -1)
            i++
        rest = rest.slice(i)
        if (rest.charAt(0) !== '"')
            return ""
        var end = rest.indexOf('"', 1)
        if (end < 1)
            return ""
        return rest.slice(1, end)
    }

    function numberValue(text, name) {
        var mark = '"' + name + '"'
        var at = text.indexOf(mark)
        if (at < 0)
            return ""
        var rest = text.slice(at + mark.length)
        var colon = rest.indexOf(":")
        if (colon < 0)
            return ""
        rest = rest.slice(colon + 1)
        var i = 0
        while (i < rest.length && " \n\t\r".indexOf(rest.charAt(i)) !== -1)
            i++
        var num = ""
        if (rest.charAt(i) === "-") {
            num = "-"
            i++
        }
        var start = i
        while (i < rest.length && rest.charAt(i) >= "0" && rest.charAt(i) <= "9")
            i++
        if (i === start)
            return ""
        return num + rest.slice(start, i)
    }

    function chainRunning(text) {
        return numberValue(text, "height") !== "" || text.indexOf("Bootstrapping") !== -1 || text.indexOf("Online") !== -1
    }

    function statusSentence(info) {
        var mode = quotedValue(info, "mode").toLowerCase()
        var height = numberValue(info, "height")
        var slot = numberValue(info, "slot")
        var lead = "The node is running."
        if (mode.indexOf("online") !== -1)
            lead = "The node is online."
        else if (mode.indexOf("bootstrap") !== -1)
            lead = "The node is bootstrapping."
        if (height === "" && slot === "")
            return lead
        var tail = ""
        if (height !== "")
            tail = " Block height " + height
        if (slot !== "")
            tail += (height !== "" ? ", slot " : " Slot ") + slot
        return lead + tail + "."
    }

    function plainFailure(text) {
        var lower = String(text).toLowerCase()
        if (lower.indexOf("timeout") !== -1)
            return "The node did not start. The node module took too long to answer."
        if (lower.indexOf("not found") !== -1 || lower.indexOf("unavailable") !== -1)
            return "The node did not start. The blockchain module is not available."
        if (lower.indexOf("config") !== -1)
            return "The node did not start. The node configuration could not be written."
        return "The node did not start. The node module did not report a running chain."
    }

    function finish(info) {
        root.speech = statusSentence(info)
        root.detail = ""
        root.done = true
        root.failed = false
        root.busy = false
    }

    function fail(text) {
        root.speech = plainFailure(text)
        root.detail = ""
        root.done = false
        root.failed = true
        root.busy = false
    }

    function runNode() {
        root.busy = true
        root.failed = false
        root.speech = "Running the node…"
        root.detail = ""
        if (typeof logos === "undefined") {
            root.speech = "The node did not start. This view is not connected to Basecamp."
            root.failed = true
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
            logos.callModule("blockchain_module", "start", ["user_config.yaml", ""])
            info = String(logos.callModule("blockchain_module", "get_cryptarchia_info", []))
            if (chainRunning(info)) {
                finish(info)
                return
            }
            fail(info)
        } catch (error) {
            fail(error)
        }
    }
}
