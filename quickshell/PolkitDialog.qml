import Quickshell
import QtQuick
import QtQuick.Controls

Item {
    id: root
    
    property bool isOpen: false
    property var polkitAgent: globalPolkitAgent // 👈 Reference persistent agent

    signal openRequested()
    signal closeRequested()

    property string authMessage: (polkitAgent && polkitAgent.flow && polkitAgent.flow.message) ? polkitAgent.flow.message : "Authentication Required"
    property string promptText: (polkitAgent && polkitAgent.flow && polkitAgent.flow.prompt) ? polkitAgent.flow.prompt : "Password:"
    property string errorMessage: ""
    property bool isAuthenticating: false
    property bool isCancelling: false

    // --- AUTH STATE MONITORING ---
    Connections {
        target: polkitAgent
        enabled: polkitAgent !== undefined && polkitAgent !== null

        function onIsActiveChanged() {
            if (polkitAgent.isActive) {
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
    Connections {
        target: polkitAgent ? polkitAgent.flow : null
        enabled: polkitAgent !== undefined && polkitAgent !== null && polkitAgent.flow !== null

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

    function cancelAuth() {
        if (root.isCancelling) return
        root.isCancelling = true
        root.isAuthenticating = false
        passwordField.text = ""
        root.errorMessage = ""

        if (polkitAgent && polkitAgent.flow) {
            polkitAgent.flow.cancelAuthenticationRequest()
        } else {
            root.closeRequested()
        }
    }

    // --- UI LAYOUT ---
    Column {
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 14

        Text {
            text: "🔐  System Authentication"
            color: Colors.text
            font.pixelSize: 16
            font.bold: true
        }

        Text {
            width: parent.width
            text: root.authMessage
            color: Colors.text
            opacity: 0.85
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }

        Text {
            text: root.promptText
            color: Colors.text
            opacity: 0.6
            font.pixelSize: 12
        }

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
                enabled: !root.isAuthenticating && !root.isCancelling && (polkitAgent && polkitAgent.isActive)

                onAccepted: {
                    if (text.length > 0 && !root.isAuthenticating && polkitAgent.flow) {
                        root.isAuthenticating = true
                        polkitAgent.flow.submit(text)
                        text = ""
                    }
                }
            }
        }

        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: "#f38ba8"
            font.pixelSize: 12
        }

        Row {
            anchors.right: parent.right
            spacing: 10

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
                    onClicked: root.cancelAuth()
                }
            }

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
                    enabled: !root.isAuthenticating && !root.isCancelling && passwordField.text.length > 0 && (polkitAgent && polkitAgent.isActive)
                    onClicked: {
                        if (polkitAgent && polkitAgent.flow) {
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