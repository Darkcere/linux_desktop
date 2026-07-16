import QtQuick

Item {
    id: root
    property Item targetItem: null
    signal destroyFinished

    ParallelAnimation {
        id: destroyAnimation
        running: false

        NumberAnimation { 
            target: root.targetItem
            property: "scale"
            to: 0.8
            duration: 200
            easing.type: Easing.OutQuad 
        }

        NumberAnimation { 
            target: root.targetItem
            property: "opacity"
            to: 0.0
            duration: 200
            easing.type: Easing.OutQuad 
        }

        onFinished: {
            root.destroyFinished();
        }
    }

    function startDestroy() {
        destroyAnimation.running = true;
    }
}