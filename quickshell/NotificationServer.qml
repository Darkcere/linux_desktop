import QtQuick
import Quickshell
import Quickshell.Services.Notifications

NotificationServer {
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    imageSupported: true
    inlineReplySupported: true
    persistenceSupported: true
    keepOnReload: true
    
    onNotification: (notification) => {
        notification.tracked = true
    }
}