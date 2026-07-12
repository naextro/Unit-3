import QtQuick

// WipeCurtain — NieR curtain identical to HTML player v4
// Content placed INSIDE this component is clipped by the animation
// Usage: WipeCurtain { id: wipe; anchors.fill: parent; Rectangle { ... } }

Item {
    id: root

    property color curtainColor:   "#c8b89a"
    property int   revealDuration: 650
    property int   hideDuration:   600

    signal revealFinished
    signal hideFinished

    // Clip on the entire component
    clip: true

    // ── CONTENT (what is placed inside) ──
    default property alias contentData: contentItem.data

    Item {
        id:           contentItem
        anchors.fill: parent
        // The content is always there, it is the parent's clip that hides it
    }

    // ── CURTAIN (sepia rectangle that sweeps) ──
    Rectangle {
        id:     curtain
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        color:  root.curtainColor
        width:  2
        x:      root.width - 2   // starts on the right
        z:      10
    }

    // ── REVEAL: curtain starts from the right, covers everything, retracts to the left ──
    SequentialAnimation {
        id: revealAnim

        // Phase 1 — the curtain extends to the left (covers)
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: root.width - 2; to: 0
                duration: Math.round(root.revealDuration * 0.35)
                easing.type: Easing.InOutQuart
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: 2; to: root.width
                duration: Math.round(root.revealDuration * 0.35)
                easing.type: Easing.InOutQuart
            }
        }

        // Phase 2 — the curtain retracts to the left (reveals)
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: 0; to: 0
                duration: Math.round(root.revealDuration * 0.65)
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: root.width; to: 0
                duration: Math.round(root.revealDuration * 0.65)
                easing.type: Easing.InOutQuart
            }
        }

        onFinished: {
            curtain.x     = 0
            curtain.width = 0
            root.revealFinished()
        }
    }

    // ── HIDE: curtain starts from the left, covers everything, leaves a line on the right ──
    SequentialAnimation {
        id: hideAnim

        // Phase 1 — the curtain extends from the left (covers)
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: 0; to: 0
                duration: Math.round(root.hideDuration * 0.4)
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: 0; to: root.width
                duration: Math.round(root.hideDuration * 0.4)
                easing.type: Easing.InOutQuart
            }
        }

        // Phase 2 — the curtain retracts to the right (hides)
        ParallelAnimation {
            NumberAnimation {
                target: curtain; property: "x"
                from: 0; to: root.width - 2
                duration: Math.round(root.hideDuration * 0.6)
                easing.type: Easing.InOutQuart
            }
            NumberAnimation {
                target: curtain; property: "width"
                from: root.width; to: 2
                duration: Math.round(root.hideDuration * 0.6)
                easing.type: Easing.InOutQuart
            }
        }

        onFinished: {
            curtain.x     = root.width - 2
            curtain.width = 2
            root.hideFinished()
        }
    }

    function reveal() {
        hideAnim.stop()
        curtain.x     = root.width - 2
        curtain.width = 2
        revealAnim.start()
    }

    function hide() {
        revealAnim.stop()
        curtain.x     = 0
        curtain.width = 0
        hideAnim.start()
    }
}
