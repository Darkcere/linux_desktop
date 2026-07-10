 import QtQuick

import Quickshell

import Quickshell.Services.SystemTray

import Quickshell.Widgets


Item {

id: trayContainerWrapper

visible: trayRepeater.count > 0

// Dynamically calculate width based on the lightweight Row + 16px of padding (8 left + 8 right)

implicitWidth: trayContentRow.width + 7

implicitHeight: 24


required property var menuHandler

// --- STATE TRACKING FOR OUR SINGLE TOOLTIP ---

property Item hoveredItem: null

property string hoveredTitle: ""


// --- 1. HARDWARE-ACCELERATED BACKGROUND ---

Rectangle {

anchors.fill: parent

color: '#00040e0d'

radius: 5

// This makes sure the left border doesn't poke out of the rounded corners!

clip: true


// The thick left border

Rectangle {

implicitWidth: 2

implicitHeight: 13

anchors.verticalCenter: parent.verticalCenter

color: Colors.border

}

}


// --- 2. LIGHTWEIGHT ROW POSITIONER ---

Row {

id: trayContentRow

anchors.verticalCenter: parent.verticalCenter

anchors.left: parent.left

anchors.leftMargin: 8

spacing: 3


Repeater {

id: trayRepeater

model: SystemTray.items

delegate: MouseArea {

id: trayItemMouseArea

implicitWidth: 15

implicitHeight: 15

hoverEnabled: true

cursorShape: Qt.PointingHandCursor

acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

required property var modelData


// --- 3. DYNAMIC TOOLTIP ROUTING ---

onContainsMouseChanged: {

if (containsMouse) {

trayContainerWrapper.hoveredItem = trayItemMouseArea;

// Use the model's provided tooltipTitle, falling back to its main title

// Remove the hardcoded "Discord" string

var title = modelData.tooltipTitle || modelData.title || "";

trayContainerWrapper.hoveredTitle = title;

} else if (trayContainerWrapper.hoveredItem === trayItemMouseArea) {

trayContainerWrapper.hoveredItem = null;

trayContainerWrapper.hoveredTitle = "";

}

}


IconImage {

id: trayIcon

anchors.fill: parent

source: {

var currentIcon = modelData.icon.toString().toLowerCase();

if (currentIcon.includes("spotify")) {

return Quickshell.iconPath("spotify-client");

}

return modelData.icon;

}

mipmap: true

visible: status === Image.Ready

}


Text {

anchors.centerIn: parent

text: modelData.title ? modelData.title.substring(0, 2).toUpperCase() : "??"

visible: trayIcon.status !== Image.Ready

color: "#ffffff"

font.pixelSize: 10

}


onClicked: (mouse) => {

if (mouse.button === Qt.LeftButton) {

if (modelData.onlyMenu && modelData.hasMenu) {

var screenPos = trayItemMouseArea.mapToItem(null, 0, 0);

trayContainerWrapper.menuHandler.toggleMenu(modelData, screenPos.x);

} else {

modelData.activate();

}

} else if (mouse.button === Qt.RightButton) {

if (modelData.hasMenu) {

var screenPos = trayItemMouseArea.mapToItem(null, 0, 0);

trayContainerWrapper.menuHandler.toggleMenu(modelData, screenPos.x);

}

}

mouse.accepted = true;

}

}

}

}

// --- 4. THE SINGLE REUSABLE TOOLTIP ---

BarToolTip {

// Fall back to the wrapper itself if nothing is hovered to prevent anchor crashes

targetItem: trayContainerWrapper.hoveredItem || trayContainerWrapper

// Active whenever an item is hovered

active: trayContainerWrapper.hoveredItem !== null

text: trayContainerWrapper.hoveredTitle

topMargin: 20

}

} 