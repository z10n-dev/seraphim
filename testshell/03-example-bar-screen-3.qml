import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

ShellRoot {
    PanelWindow {
        id: root
        screen: {
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var scr = Quickshell.screens[i]
                var mon = Hyprland.monitorFor(scr)
                if (!mon) continue
                var monWs = Hyprland.workspaces.values.filter(w => w.monitor && w.monitor.name === mon.name && w.id >= 21 && w.id <= 30)
                if (monWs.length > 0) return scr
            }
            return Quickshell.screens.length > 2 ? Quickshell.screens[2] : Quickshell.screens[0]
        }
        visible: Quickshell.screens.length > 2

        property int wsOffset: 21

        // Theme
        property color colBg: "#1a1b26"
        property color colFg: "#a9b1d6"
        property color colMuted: "#444b6a"
        property color colCyan: "#0db9d7"
        property color colBlue: "#7aa2f7"
        property color colYellow: "#e0af68"
        property color colGreen: "#9ece6a"
        property color colRed: "#f7768e"
        property string fontFamily: "JetBrainsMono Nerd Font"
        property int fontSize: 14

        // Notification state
        property int notifCount: 0
        property var notifHistory: []
        property bool notifPanelOpen: false
        property string notifBuffer: ""

        // System data
        property int cpuUsage: 0
        property int memUsage: 0
        property var lastCpuIdle: 0
        property var lastCpuTotal: 0
        property int batCapacity: 100
        property string batStatus: "Full"
        property real batPower: 0
        property int volLevel: 0
        property bool volMuted: false
        property string wifiSsid: ""
        property int wifiSignal: 0
        property bool btPowered: false
        property string btDevice: ""
        property int pacmanUpdates: 0
        property int aurUpdates: 0
        property string powerMode: "balanced"
        property bool powerMenuOpen: false

        // CPU process
        Process {
            id: cpuProc
            command: ["sh", "-c", "head -1 /proc/stat"]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    var p = data.trim().split(/\s+/)
                    var idle = parseInt(p[4]) + parseInt(p[5])
                    var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
                    if (root.lastCpuTotal > 0) {
                        root.cpuUsage = Math.round(100 * (1 - (idle - root.lastCpuIdle) / (total - root.lastCpuTotal)))
                    }
                    root.lastCpuTotal = total
                    root.lastCpuIdle = idle
                }
            }
            Component.onCompleted: running = true
        }

        // Memory process
        Process {
            id: memProc
            command: ["sh", "-c", "free | grep Mem"]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    var parts = data.trim().split(/\s+/)
                    var total = parseInt(parts[1]) || 1
                    var used = parseInt(parts[2]) || 0
                    root.memUsage = Math.round(100 * used / total)
                }
            }
            Component.onCompleted: running = true
        }

        // Power mode process
        Process {
            id: powerModeProc
            command: ["powerprofilesctl", "get"]
            stdout: SplitParser {
                onRead: data => {
                    var mode = data.trim()
                    if (mode !== "") root.powerMode = mode
                }
            }
            onExited: powerModeRestartTimer.start()
            Component.onCompleted: running = true
        }

        Timer {
            id: powerModeRestartTimer
            interval: 2000
            repeat: false
            onTriggered: powerModeProc.running = true
        }

        Process {
            id: powerModeSetProc
            property string targetMode: "balanced"
            command: ["powerprofilesctl", "set", targetMode]
            onExited: {
                root.powerMenuOpen = false
                powerModeProc.running = true
            }
        }

        // Bluetooth process
        Process {
            id: btProc
            command: ["sh", "-c", "P=$(echo show | bluetoothctl 2>/dev/null | grep -c 'Powered: yes'); D=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-); printf '%s|%s\\n' \"${P:-0}\" \"$D\""]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    var sep = data.trim().indexOf("|")
                    root.btPowered = sep >= 0 ? data.trim().slice(0, sep) === "1" : false
                    root.btDevice  = sep >= 0 ? data.trim().slice(sep + 1).trim() : ""
                }
            }
            onExited: btRestartTimer.start()
            Component.onCompleted: running = true
        }

        Timer {
            id: btRestartTimer
            interval: 3000
            repeat: false
            onTriggered: btProc.running = true
        }

        // WiFi process
        Process {
            id: wifiProc
            command: ["sh", "-c", "S=$(iwgetid -r 2>/dev/null); Q=$(awk 'NR==3{q=int($3+0); print (q>70?100:q>0?int(q*100/70):0)}' /proc/net/wireless 2>/dev/null); printf '%s|%s\\n' \"${S}\" \"${Q:-0}\""]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    var sep = data.trim().lastIndexOf("|")
                    root.wifiSsid   = sep >= 0 ? data.trim().slice(0, sep) : ""
                    root.wifiSignal = sep >= 0 ? parseInt(data.trim().slice(sep + 1)) || 0 : 0
                }
            }
            onExited: wifiRestartTimer.start()
            Component.onCompleted: running = true
        }

        Timer {
            id: wifiRestartTimer
            interval: 2000
            repeat: false
            onTriggered: wifiProc.running = true
        }

        // Volume process
        Process {
            id: volProc
            command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    var parts = data.trim().split(/\s+/)
                    root.volLevel = Math.round(parseFloat(parts[1]) * 100)
                    root.volMuted = parts[2] === "[MUTED]"
                }
            }
            Component.onCompleted: running = true
        }

        // Battery process
        Process {
            id: batProc
            command: ["sh", "-c", "paste /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status /sys/class/power_supply/BAT0/power_now"]
            stdout: SplitParser {
                onRead: data => {
                    if (!data) return
                    var parts = data.trim().split(/\s+/)
                    root.batCapacity = parseInt(parts[0]) || 0
                    root.batStatus = parts[1] || "Unknown"
                    var powerMicroW = parseInt(parts[2]) || 0
                    root.batPower = Math.round(powerMicroW / 1000000 * 10) / 10
                }
            }
            Component.onCompleted: running = true
        }

        // Pacman updates process
        Process {
            id: pacmanUpdateProc
            command: ["sh", "-c", "checkupdates 2>/dev/null | wc -l"]
            stdout: SplitParser {
                onRead: data => {
                    var n = parseInt(data.trim())
                    root.pacmanUpdates = isNaN(n) ? 0 : n
                }
            }
        }

        // AUR updates process
        Process {
            id: aurUpdateProc
            command: ["sh", "-c", "paru -Qua 2>/dev/null | wc -l"]
            stdout: SplitParser {
                onRead: data => {
                    var n = parseInt(data.trim())
                    root.aurUpdates = isNaN(n) ? 0 : n
                }
            }
        }

        Timer {
            id: updateCheckTimer
            interval: 60000  // 10 minutes
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: { pacmanUpdateProc.running = true; aurUpdateProc.running = true }
        }

        // Notification count process
        Process {
            id: notifCountProc
            command: ["dunstctl", "count", "history"]
            stdout: SplitParser {
                onRead: data => {
                    var n = parseInt(data.trim())
                    if (!isNaN(n)) root.notifCount = n
                }
            }
        }

        Timer {
            id: notifCountTimer
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: notifCountProc.running = true
        }

        // Notification history process
        Process {
            id: notifHistoryProc
            command: ["dunstctl", "history"]
            stdout: SplitParser {
                onRead: data => {
                    root.notifBuffer += data + "\n"
                }
            }
            onExited: exitCode => {
                if (exitCode === 0) {
                    try {
                        var parsed = JSON.parse(root.notifBuffer.trim())
                        var entries = parsed.data[0] || []
                        var result = []
                        for (var i = 0; i < entries.length; i++) {
                            var e = entries[i]
                            result.push({
                                appname: e.appname ? e.appname.data : "",
                                summary: e.summary ? e.summary.data : "",
                                body: e.body ? e.body.data : ""
                            })
                        }
                        root.notifHistory = result
                    } catch (err) {
                        // Malformed JSON, leave history unchanged
                    }
                }
                root.notifBuffer = ""
            }
        }

        // Clear all notifications process
        Process {
            id: notifClearProc
            command: ["dunstctl", "history-clear"]
            onExited: {
                root.notifHistory = []
                root.notifCount = 0
                notifCountProc.running = true
            }
        }

        // Fetch history when panel opens
        onNotifPanelOpenChanged: {
            if (root.notifPanelOpen) {
                root.notifBuffer = ""
                notifHistoryProc.running = true
            }
        }

        // Update timer to run system processes
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                cpuProc.running = true
                memProc.running = true
                volProc.running = true
                batProc.running = true
            }
        }

        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 30
        color: root.colBg

        Item {
            anchors.fill: parent
            anchors.margins: 5

            // ── Left section ──────────────────────────────────────────
            Row {
                id: leftSection
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                // Arch Linux logo
                Text {
                    text: "\uf303"
                    color: root.colCyan
                    font { family: root.fontFamily; pixelSize: root.fontSize + 2 }
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Workspaces
                Repeater {
                    model: 10
                    delegate: Item {
                        property int wsId: root.wsOffset + index
                        property var ws: Hyprland.workspaces.values.find(w => w.id === wsId)
                        property bool isActive: Hyprland.focusedWorkspace?.id === wsId
                        visible: index < 5 || !!ws

                        implicitWidth: isActive ? activeBox.implicitWidth : wsNum.implicitWidth
                        implicitHeight: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        // Active: filled rounded box
                        Rectangle {
                            id: activeBox
                            visible: isActive
                            anchors.centerIn: parent
                            implicitWidth: 10
                            implicitHeight: 10
                            radius: 2
                            color: root.colCyan
                        }

                        // Inactive: plain number
                        Text {
                            id: wsNum
                            visible: !isActive
                            anchors.centerIn: parent
                            text: wsId - root.wsOffset + 1
                            color: root.colCyan
                            opacity: !ws ? 0.3 : 1
                            font { family: root.fontFamily; pixelSize: 14 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + wsId)
                        }
                    }
                }
            }

            // ── Clock (truly centered, never moves) ───────────────────
            Text {
                id: clock
                anchors.centerIn: parent
                color: root.colBlue
                font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                text: Qt.formatDateTime(new Date(), "dddd, dd. MMM - HH:mm")
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clock.text = Qt.formatDateTime(new Date(), "dddd, dd. MMM - HH:mm")
                }
            }

            // ── Right section ─────────────────────────────────────────
            Row {
                id: rightSection
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Tray
                Item {
                    id: trayContainer
                    implicitHeight: 20
                    implicitWidth: trayHover.containsMouse ? trayFullRow.implicitWidth : trayToggle.implicitWidth
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: trayHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: trayFullRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: SystemTray.items
                            delegate: Item {
                                width: modelData.status !== Status.Passive ? 20 : 0
                                height: 20

                                Image {
                                    anchors.centerIn: parent
                                    source: modelData.icon
                                    width: 16
                                    height: 16
                                    smooth: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton && modelData.hasMenu)
                                            modelData.menu.open()
                                        else
                                            modelData.activate()
                                    }
                                }
                            }
                        }

                        Text {
                            id: trayToggle
                            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                            text: "\uf141"
                            color: trayHover.containsMouse ? root.colFg : root.colMuted
                            font { family: root.fontFamily; pixelSize: root.fontSize }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted; visible: (root.pacmanUpdates + root.aurUpdates) > 0 }


                // Updates
                Item {
                    visible: (root.pacmanUpdates + root.aurUpdates) > 0
                    implicitHeight: 20
                    implicitWidth: updateHover.containsMouse ? updateFullRow.implicitWidth : updateIcon.implicitWidth
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: updateHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: updateFullRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: updateIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\udb80\udd51" + (!updateHover.containsMouse ? " " + root.pacmanUpdates + "/" + root.aurUpdates : "")
                            color: root.pacmanUpdates + root.aurUpdates > 20 ? root.colRed : root.colYellow
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Pacman: " + root.pacmanUpdates + "/" + "AUR: " + root.aurUpdates
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }
                
                // CPU
                Text {
                    text: "\uf4bc " + root.cpuUsage + "%"
                    color: root.colYellow
                    font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // Memory
                Text {
                    text: "\uefc5 " + root.memUsage + "%"
                    color: root.colCyan
                    font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // Power Mode
                Item {
                    implicitHeight: 20
                    implicitWidth: powerModeIcon.implicitWidth
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerMenuOpen = !root.powerMenuOpen
                    }

                    Text {
                        id: powerModeIcon
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.powerMode === "power-saver" ? "\uf06c"
                            : root.powerMode === "performance" ? "\uf135"
                            : "\udb80\udd39"
                        color: root.powerMenuOpen ? root.colCyan
                             : root.powerMode === "power-saver" ? root.colGreen
                             : root.powerMode === "performance" ? root.colRed
                             : root.colYellow
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // Bluetooth
                Item {
                    implicitHeight: btRow.implicitHeight
                    implicitWidth: btRow.implicitWidth

                    MouseArea {
                        id: btHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["alacritty", "-e", "bluetui"])
                    }

                    Row {
                        id: btRow
                        spacing: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.btPowered ? (root.btDevice !== "" ? "\udb80\udcb2" : "\udb80\udcb1") : "\udb80\udcb3"
                            color: root.btDevice !== "" ? root.colCyan : (root.btPowered ? root.colBlue : root.colMuted)
                            font { family: root.fontFamily; pixelSize: root.fontSize }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: btHover.containsMouse && root.btDevice !== ""
                            text: root.btDevice
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // WiFi
                Item {
                    implicitHeight: 20
                    implicitWidth: wifiHover.containsMouse && root.wifiSsid !== "" ? wifiFullRow.implicitWidth : wifiIcon.implicitWidth
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: wifiHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: wifiFullRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: wifiIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wifiSsid === "" ? "\uf05e"
                                : root.wifiSignal >= 75 ? "\uf1eb"
                                : root.wifiSignal >= 50 ? "\udb82\udd2d"
                                : root.wifiSignal >= 25 ? "\udb82\udd2c"
                                : "\udb82\udd2f"
                            color: root.wifiSsid === "" ? root.colMuted
                                 : root.wifiSignal >= 50 ? root.colGreen
                                 : root.wifiSignal >= 25 ? root.colYellow
                                 : root.colRed
                            font { family: root.fontFamily; pixelSize: root.fontSize }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wifiSsid
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // Audio
                Item {
                    implicitHeight: 20
                    implicitWidth: volHover.containsMouse ? volFullRow.implicitWidth : volIcon.implicitWidth
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: volHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: volFullRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: volIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.volMuted ? "\ueee8"
                                : root.volLevel < 40 ? "\uf027"
                                : "\uf028"
                            color: root.volMuted ? root.colMuted : root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.volMuted ? "Muted" : root.volLevel + "%"
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // Battery
                Item {
                    implicitHeight: 20
                    implicitWidth: batHover.containsMouse ? batFullRow.implicitWidth : batIcon.implicitWidth
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: batHover
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Row {
                        id: batFullRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Text {
                            id: batIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batStatus === "Charging" ? "\uf0e7"
                                : root.batCapacity > 80 ? "\uf240"
                                : root.batCapacity > 60 ? "\uf241"
                                : root.batCapacity > 40 ? "\uf242"
                                : root.batCapacity > 20 ? "\uf243"
                                : "\uf244"
                            color: root.batStatus === "Charging" ? root.colGreen
                                 : root.batCapacity <= 20 ? root.colRed
                                 : root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.batCapacity + "% " + (root.batStatus === "Charging" ? root.batPower + "W" : root.batStatus)
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }
                    }
                }

                Rectangle { width: 1; height: 16; color: root.colMuted }

                // Notification bell
                Item {
                    id: notifWidget
                    implicitHeight: 20
                    implicitWidth: notifBellHover.containsMouse ? notifBellRow.implicitWidth : notifBellIcon.implicitWidth
                    clip: true

                    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    MouseArea {
                        id: notifBellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notifPanelOpen = !root.notifPanelOpen
                    }

                    Row {
                        id: notifBellRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Item {
                            width: notifBellIcon.implicitWidth
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                id: notifBellIcon
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.notifCount > 0 ? "\uf0f3" : "\uf1f6"
                                color: root.notifPanelOpen ? root.colCyan : (root.notifCount > 0 ? root.colYellow : root.colMuted)
                                font { family: root.fontFamily; pixelSize: root.fontSize }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Rectangle {
                                visible: root.notifCount > 0 && !root.notifPanelOpen
                                width: 6
                                height: 6
                                radius: 3
                                color: root.colRed
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 1
                                anchors.rightMargin: -1
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.notifCount > 0 ? root.notifCount + " notif" : "No notif"
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                        }
                    }
                }
            }
        }
    }

    // Power mode dropdown
    PanelWindow {
        id: powerMenuPanel
        visible: root.powerMenuOpen
        anchors.top: true
        anchors.right: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "powerMenu"
        exclusionMode: ExclusionMode.Ignore
        margins.top: 40
        margins.right: 10
        width: 180
        color: Qt.rgba(Qt.color(root.colBg).r, Qt.color(root.colBg).g, Qt.color(root.colBg).b, 0.96)

        Column {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Repeater {
                model: [
                    { mode: "power-saver",  label: "Power Saver",  icon: "\uf06c",  col: root.colGreen  },
                    { mode: "balanced",     label: "Balanced",     icon: "\udb80\udd39", col: root.colYellow },
                    { mode: "performance",  label: "Performance",  icon: "\uf135",  col: root.colRed    }
                ]
                delegate: Item {
                    width: parent.width
                    implicitHeight: 30

                    property bool isActive: root.powerMode === modelData.mode

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: isActive
                            ? Qt.rgba(Qt.color(modelData.col).r, Qt.color(modelData.col).g, Qt.color(modelData.col).b, 0.15)
                            : pmHover.containsMouse
                                ? Qt.rgba(Qt.color(root.colFg).r, Qt.color(root.colFg).g, Qt.color(root.colFg).b, 0.08)
                                : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            color: modelData.col
                            font { family: root.fontFamily; pixelSize: root.fontSize }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: isActive ? modelData.col : root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: isActive }
                        }
                    }

                    MouseArea {
                        id: pmHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            powerModeSetProc.targetMode = modelData.mode
                            powerModeSetProc.running = true
                        }
                    }
                }
            }
        }
    }

    // Notification panel
    PanelWindow {
        id: notifPanel
        visible: root.notifPanelOpen
        // Only ONE anchor so it doesn't stretch full height
        anchors.top: true
        anchors.right: true
        anchors.bottom: true
        // REMOVED: anchors.bottom: true

        // Use margin to push it down from the top (e.g. below your bar)
        margins.top: 40  // adjust to your bar height
        margins.right: 10
        margins.bottom: 10

        // Force overlay layer — above everything including fullscreen
        // Replace aboveWindows: true with these two lines
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notifPanel"

        // Tell it to ignore exclusive zones from other panels
        exclusionMode: ExclusionMode.Ignore

        width: 380

        color: Qt.rgba(Qt.color(root.colBg).r, Qt.color(root.colBg).g, Qt.color(root.colBg).b, 0.96)
        

        Item {
            anchors.fill: parent
            anchors.margins: 10
            // Header
            Row {
                id: notifHeader
                width: parent.width
                spacing: 8

                Text {
                    text: "\uf0f3  Notifications"
                    color: root.colFg
                    font { family: root.fontFamily; pixelSize: root.fontSize + 1; bold: true }
                }

                Item { Layout.fillWidth: true }

                Item {
                    id: clearBtn
                    implicitWidth: clearBtnText.implicitWidth + 12
                    implicitHeight: clearBtnText.implicitHeight + 6
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: clearBtnHover.containsMouse ? root.colRed : "transparent"
                        border.color: root.colRed
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Text {
                        id: clearBtnText
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: clearBtnHover.containsMouse ? root.colBg : root.colRed
                        font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: clearBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifClearProc.running = true
                    }
                }
            }

            // Separator
            Rectangle {
                width: parent.width
                height: 1
                color: root.colMuted
                anchors.top: notifHeader.bottom
                anchors.topMargin: 8
            }

            // Notification list
            ListView {
                id: notifList
                anchors.top: parent.top
                anchors.topMargin: notifHeader.implicitHeight + 16
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                clip: true
                model: root.notifHistory
                spacing: 8

                Text {
                    anchors.centerIn: parent
                    visible: root.notifHistory.length === 0
                    text: "No notifications"
                    color: root.colMuted
                    font { family: root.fontFamily; pixelSize: root.fontSize }
                }

                delegate: Rectangle {
                    width: notifList.width
                    implicitHeight: notifCol.implicitHeight + 16
                    radius: 6
                    color: Qt.rgba(Qt.color(root.colMuted).r, Qt.color(root.colMuted).g, Qt.color(root.colMuted).b, 0.2)
                    border.color: root.colMuted
                    border.width: 1

                    Column {
                        id: notifCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 2

                        Text {
                            width: parent.width
                            text: modelData.appname || "Unknown"
                            color: root.colCyan
                            font { family: root.fontFamily; pixelSize: root.fontSize - 2; bold: true }
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: modelData.summary || ""
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                        }

                        Text {
                            width: parent.width
                            text: modelData.body || ""
                            color: root.colMuted
                            font { family: root.fontFamily; pixelSize: root.fontSize - 1 }
                            wrapMode: Text.WordWrap
                            visible: text !== ""
                        }
                    }
                }
            }
        }
    }
}
