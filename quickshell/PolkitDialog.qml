import Quickshell
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    property bool isOpen: false
    signal openRequested()
    signal closeRequested()

    property string authMessage: (polkitAgent.flow && polkitAgent.flow.message) ? polkitAgent.flow.message : "Authentication Required"
    property string promptText: (polkitAgent.flow && polkitAgent.flow.prompt) ? polkitAgent.flow.prompt : "Password:"
    property string errorMessage: ""
    property bool isAuthenticating: false
    property bool isCancelling: false

    // --- POLKIT AGENT SERVICE ---
    PolkitAgent {
        id: polkitAgent

        onIsRegisteredChanged: {
            if (!isRegistered) {
                console.warn("[PolkitDialog] Failed to register PolkitAgent! Another polkit agent is likely already running.")
            } else {
                console.info("[PolkitDialog] Successfully registered as system Polkit agent.")
            }
        }

        onIsActiveChanged: {
            if (isActive) {
                if (!root.isCancelling) {
                    root.errorMessage = ""
                    root.isAuthenticating = false
                    passwordField.text = ""
                    root.openRequested()
                }
            } else {
                root.isCancelling = false
                root.isAuthenticating = false
                passwordField.text = ""
                root.closeRequested()
            }
        }
    }

    // --- AUTH FLOW SIGNALS ---
    // 💡 THE FIX: Listen to authentication lifecycle signals on the active flow object
    Connections {
        target: polkitAgent.flow
        enabled: polkitAgent.flow !== null

        function onAuthenticationFailed() {
            root.errorMessage = "Authentication failed. Please try again."
            root.isAuthenticating = false
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }

        function onAuthenticationSucceeded() {
            root.errorMessage = ""
            root.isAuthenticating = false
            root.closeRequested()
        }

        function onAuthenticationRequestCancelled() {
            root.isCancelling = false
            root.closeRequested()
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            root.isCancelling = false
            passwordField.forceActiveFocus()
        } else {
            errorMessage = ""
            passwordField.text = ""
        }
    }

    // Global Escape shortcut to cancel authentication
    Shortcut {
        sequence: "Escape"
        enabled: root.isOpen
        onActivated: {
            root.cancelAuth()
        }
    }

    // 💡 THE FIX: Uses cancelAuthenticationRequest() to properly terminate the D-Bus/PAM session
    function cancelAuth() {
        if (root.isCancelling) return
        root.isCancelling = true
        root.isAuthenticating = false
        passwordField.text = ""
        root.errorMessage = ""

        if (polkitAgent.flow) {
            polkitAgent.flow.cancelAuthenticationRequest()
        } else {
            root.closeRequested()
        }
    }

    // --- UI LAYOUT (Matched to Apps.qml color theme) ---
    Column {
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 14

        // Title Header
        Text {
            text: "🔐  System Authentication"
            color: Colors.text
            font.pixelSize: 16
            font.bold: true
        }

        // Polkit System Message
        Text {
            width: parent.width
            text: root.authMessage
            color: Colors.text
            opacity: 0.85
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        // PAM Prompt Label (e.g. "Password:")
        Text {
            text: root.promptText
            color: Colors.text
            opacity: 0.6
            font.pixelSize: 12
        }

        // Password Input Field
        Rectangle {
            width: parent.width
            height: 45
            radius: 8
            color: Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.1)
            border.color: passwordField.activeFocus ? Colors.workspaceactive : Colors.border
            border.width: 2

            TextInput {
                id: passwordField
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Colors.workspaceactive
                font.pixelSize: 15
                echoMode: TextInput.Password
                clip: true
                enabled: !root.isAuthenticating && !root.isCancelling && polkitAgent.isActive

                Keys.onEscapePressed: (event) => {
                    event.accepted = true
                    root.cancelAuth()
                }

                onAccepted: {
                    if (text.length > 0 && !root.isAuthenticating && polkitAgent.flow) {
                        root.isAuthenticating = true
                        polkitAgent.flow.submit(text)
                        text = ""
                    }
                }
            }
        }

        // Error Feedback Label
        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: "#f38ba8"
            font.pixelSize: 12
        }

        // Action Buttons
        Row {
            anchors.right: parent.right
            spacing: 10

            // Cancel Button
            Rectangle {
                width: 90
                height: 38
                radius: 8
                color: cancelArea.containsMouse ? Colors.workspaceactive : "transparent"
                border.color: Colors.border
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: cancelArea.containsMouse ? Colors.background : Colors.text
                    font.pixelSize: 14
                    font.bold: cancelArea.containsMouse
                }

                MouseArea {
                    id: cancelArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.cancelAuth()
                    }
                }
            }

            // Authenticate Button
            Rectangle {
                width: 115
                height: 38
                radius: 8
                color: authArea.containsMouse ? Colors.workspaceactive : Qt.rgba(Colors.workspaceempty.r, Colors.workspaceempty.g, Colors.workspaceempty.b, 0.15)
                border.color: authArea.containsMouse ? Colors.workspaceactive : Colors.border
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: root.isAuthenticating ? "Verifying..." : "Authenticate"
                    color: authArea.containsMouse ? Colors.background : Colors.text
                    font.bold: true
                    font.pixelSize: 14
                }

                MouseArea {
                    id: authArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.isAuthenticating && !root.isCancelling && passwordField.text.length > 0 && polkitAgent.isActive
                    onClicked: {
                        if (polkitAgent.flow) {
                            root.isAuthenticating = true
                            polkitAgent.flow.submit(passwordField.text)
                            passwordField.text = ""
                        }
                    }
                }
            }
        }
    }
}