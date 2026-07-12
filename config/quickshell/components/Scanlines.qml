import QtQuick

// NieR scanlines overlay — to be placed on top of any widget
// Usage:
//   Scanlines { anchors.fill: parent }

Item {
    id:              root
    anchors.fill:    parent
    property real   lineOpacity: 0.06
    property int    lineSpacing: 3    // px between each line
    property bool   grain:       true // additional texture grain

    // Does not capture any events
    enabled:         false

    // Scanlines via Canvas (lighter than a Repeater of rectangles)
    Canvas {
        id:           cv
        anchors.fill: parent
        opacity:      1

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "rgba(0,0,0," + root.lineOpacity + ")"
            for (var y = 0; y < height; y += root.lineSpacing + 1) {
                ctx.fillRect(0, y, width, 1)
            }
        }

        // Redraws if size changes
        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()

        Component.onCompleted: requestPaint()
    }

    // Subtle grain (random semi-transparent points)
    Canvas {
        id:           grainCv
        anchors.fill: parent
        visible:      root.grain
        opacity:      0.35

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            // Light grain: 1 pixel every ~8px²
            var density = Math.floor(width * height / 8)
            for (var i = 0; i < density; i++) {
                var x = Math.floor(Math.random() * width)
                var y = Math.floor(Math.random() * height)
                var a = Math.random() * 0.12
                ctx.fillStyle = "rgba(200,184,154," + a + ")"
                ctx.fillRect(x, y, 1, 1)
            }
        }

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
