import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// Corner panel. Empty space has no MouseArea, so a host that composites
// this view can keep the rest of the window live.
Item {
    id: root
    anchors.fill: parent

    property string speech: "Before anything else, run a Logos node."
    property string detail: ""
    property bool busy: false
    property bool done: false
    property bool open: true

    readonly property string peers: "{\"initial_peers\":[\"/ip4/65.109.51.37/udp/3000/quic-v1/p2p/12D3KooWFrouXfmrR4nsLMtE7wu15DoMJ6VtoUtHinREZCvbWHar\",\"/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWJRGau8M1rjT7R5e4YYsgdFhsMX35nRDtMwCDjxQkXAHz\",\"/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWQXJavMDTRscjauFSgVAB1VLB6Rzpy2uY5SU9Tk7927tb\",\"/ip4/65.109.51.37/udp/50001/quic-v1/p2p/12D3KooWSQc7CcGtvWDPF1yCbBthFnQjprfCVHmfmNDUrSmqQsU1\"]}"

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
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
                    anchors.fill: parent
                    onClicked: root.open = !root.open
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
            width: 260
            height: column.implicitHeight + 28
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
