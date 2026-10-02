import QtQuick
import QtQuick.Effects
import qs.Commons
import "Palette.js" as Palette

// Album art fills the player card; gradients and the playback overlay sit on top.
Item {
  id: root

  property url coverUrl: ""
  property bool hasTrack: false
  property bool playing: false
  property real radius: Style.cornerRadius
  // Keep the icon clear of the card's header and controls.
  property real artTopInset: 0
  property real artBottomInset: 0
  property real pointerX: 0.5
  property real pointerY: 0.5
  property real pointerStrength: 0
  property bool pointerInitialized: false
  property point bubblePosition: Qt.point(0.5, 0.5)
  property point bubbleVelocity: Qt.point(0, 0)
  property point trailPosition: bubblePosition
  property point tailPosition: bubblePosition
  property Item effectHost: null

  HoverHandler {
    onPointChanged: {
      root.pointerX = point.position.x / Math.max(1, root.width)
      root.pointerY = point.position.y / Math.max(1, root.height)
      if (!root.pointerInitialized) {
        root.bubblePosition = Qt.point(root.pointerX, root.pointerY)
        root.trailPosition = root.bubblePosition
        root.tailPosition = root.bubblePosition
        root.pointerInitialized = true
      }
    }
    onHoveredChanged: root.pointerStrength = hovered ? 1 : 0
  }

  // An underdamped spring carries momentum past the cursor and settles back.
  // Small substeps keep the spring stable after a dropped frame.
  function advanceBubble(frameTime) {
    var elapsed = Math.min(frameTime, 0.05)
    var steps = Math.max(1, Math.ceil(elapsed * 120))
    var dt = elapsed / steps
    var x = bubblePosition.x, y = bubblePosition.y
    var vx = bubbleVelocity.x, vy = bubbleVelocity.y
    var tx = trailPosition.x, ty = trailPosition.y
    var ex = tailPosition.x, ey = tailPosition.y
    var trailBlend = 1 - Math.exp(-14 * dt)
    var tailBlend = 1 - Math.exp(-10 * dt)
    for (var i = 0; i < steps; i++) {
      vx += ((pointerX - x) * 360 - vx * 20) * dt
      vy += ((pointerY - y) * 360 - vy * 20) * dt
      x += vx * dt
      y += vy * dt
      tx += (x - tx) * trailBlend
      ty += (y - ty) * trailBlend
      ex += (tx - ex) * tailBlend
      ey += (ty - ey) * tailBlend
    }
    bubblePosition = Qt.point(x, y)
    bubbleVelocity = Qt.point(vx, vy)
    trailPosition = Qt.point(tx, ty)
    tailPosition = Qt.point(ex, ey)
  }

  readonly property var fallbackPalette: Palette.themePalette(themeTokens())
  property var palette: fallbackPalette

  readonly property color accent: colorOf(palette.accent)
  readonly property color metadataInk: colorOf(palette.text)
  readonly property color base: colorOf(palette.base)
  readonly property color deep: colorOf(palette.deep)
  readonly property bool hasCover: root.hasTrack && coverImage.status === Image.Ready

  property string noCoverGlyph: "󰽴"
  property string noMusicGlyph: "󰝛"

  function colorOf(c, alpha) {
    return Qt.rgba(c.r, c.g, c.b, alpha === undefined ? 1 : alpha)
  }

  // Dashboard theme colors — the fallback palette source when a track has
  // no artwork (or the artwork cannot be decoded).
  function themeTokens() {
    return {
      accent: { r: Color.accent.r, g: Color.accent.g, b: Color.accent.b },
      background: { r: Color.background.r, g: Color.background.g, b: Color.background.b },
      foreground: { r: Color.foreground.r, g: Color.foreground.g, b: Color.foreground.b }
    }
  }

  // ------------------------------------------------------- palette cache
  property var paletteCache: ({})
  readonly property bool samplerAvailable: sampler.available
  property string sampledKey: ""
  property string samplerKey: ""

  // Read the decoded artwork directly; item textures may not upload while paused.
  function refreshPalette() {
    var key = root.hasTrack ? String(coverUrl || "") : ""
    if (sampler.available && key !== samplerKey) {
      if (samplerKey) sampler.unloadImage(samplerKey)
      samplerKey = key
    }
    if (!key || (String(coverImage.source) === key && coverImage.status === Image.Error)) {
      palette = root.fallbackPalette
      sampledKey = ""
      return
    }
    if (key === sampledKey) return
    if (paletteCache[key] !== undefined) {
      palette = paletteCache[key]
      sampledKey = key
      return
    }
    if (!sampler.available) return
    if (sampler.isImageLoaded(key)) sampler.requestPaint()
    else if (!sampler.isImageLoading(key) && !sampler.isImageError(key)) sampler.loadImage(key)
  }

  function wake() { refreshPalette() }

  onCoverUrlChanged: refreshPalette()
  onHasTrackChanged: {
    refreshPalette()
    ambientCanvas.requestPaint()
  }
  onVisibleChanged: refreshPalette()
  onFallbackPaletteChanged: refreshPalette()
  onPaletteChanged: ambientCanvas.requestPaint()
  onHasCoverChanged: ambientCanvas.requestPaint()
  Component.onCompleted: refreshPalette()

  Canvas {
    id: sampler
    width: 32
    height: 32
    visible: false
    onAvailableChanged: if (available) root.refreshPalette()
    onImageLoaded: root.refreshPalette()
    onPaint: {
      var key = root.hasTrack ? String(root.coverUrl || "") : ""
      if (!key || !isImageLoaded(key)) return
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, 32, 32)
      ctx.drawImage(key, 0, 0, 32, 32)
      var pixels = ctx.getImageData(0, 0, 32, 32)
      var next = Palette.extract(pixels.data, 32, 32, root.themeTokens())
      if (!next) return
      if (Object.keys(root.paletteCache).length > 24)
        root.paletteCache = ({})
      root.paletteCache[key] = next
      root.palette = next
      root.sampledKey = key
    }
  }

  // --------------------------------------------------- ambient background
  Item {
    id: stage
    anchors.fill: parent
    visible: !root.hasCover
    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: cardMask
      maskThresholdMin: 0.3
      maskSpreadAtMin: 0.3
    }

    Rectangle {
      anchors.fill: parent
      color: root.base
    }

    // Cover-colored light behind the image.
    Canvas {
      id: ambientCanvas
      anchors.fill: parent
      visible: root.playing && root.hasTrack
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        var w = width
        var h = height
        ctx.clearRect(0, 0, w, h)
        bloom(root.palette.primary, root.palette.primaryFocus, 0.95, 0.82)
        bloom(root.palette.secondary, root.palette.secondaryFocus, 0.9, 0.86)
        bloom(root.palette.primary, { x: 0.82, y: 0.78 }, 0.9, 0.75)
        bloom(root.palette.light, root.palette.lightFocus, 0.6, 0.32)

        var cx = w / 2
        var cy = h * 0.45
        var vignette = ctx.createRadialGradient(cx, cy, Math.min(w, h) * 0.2, cx, cy, Math.max(w, h) * 0.8)
        vignette.addColorStop(0, Palette.css(root.palette.deep, 0))
        vignette.addColorStop(0.62, Palette.css(root.palette.deep, 0.1))
        vignette.addColorStop(1, Palette.css(root.palette.deep, 0.48))
        ctx.fillStyle = vignette
        ctx.fillRect(0, 0, w, h)
      }

      function bloom(color, focus, radiusFactor, alpha) {
        if (!color) return
        var ctx = getContext("2d")
        var w = width
        var h = height
        var x = artRegion.x + (focus ? focus.x : 0.5) * artRegion.width
        var y = artRegion.y + (focus ? focus.y : 0.5) * artRegion.height
        var r = Math.max(artRegion.width, Math.min(w, h)) * radiusFactor
        var g = ctx.createRadialGradient(x, y, 0, x, y, Math.max(1, r))
        g.addColorStop(0, Palette.css(color, alpha))
        g.addColorStop(0.5, Palette.css(color, alpha * 0.45))
        g.addColorStop(1, Palette.css(color, 0))
        ctx.fillStyle = g
        ctx.fillRect(0, 0, w, h)
      }
    }
  }

  Item {
    id: cardMask
    anchors.fill: stage
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.radius
      color: "white"
    }
  }

  // ----------------------------------------------------- no-art icon
  Item {
    id: artRegion
    visible: !root.hasCover
    readonly property real regionHeight: Math.max(1, root.height - root.artTopInset - root.artBottomInset)
    height: Math.max(1, Math.min(regionHeight, root.width - Style.space(4)))
    width: height
    x: (root.width - width) / 2
    y: root.artTopInset + (regionHeight - height) / 2

    Text {
      anchors.centerIn: parent
      text: root.hasTrack ? root.noCoverGlyph : root.noMusicGlyph
      color: root.hasTrack ? root.accent : root.colorOf(root.metadataInk, 0.62)
      font.family: Style.font.family
      font.pixelSize: Math.max(28, Math.min(96, artRegion.height * 0.34))
    }
  }

  Item {
    id: coverRegion
    anchors.fill: parent

    Image {
      id: coverImage
      anchors.fill: parent
      source: root.hasTrack ? root.coverUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      smooth: true
      visible: status === Image.Ready
      onStatusChanged: root.refreshPalette()
    }
  }

  ShaderEffectSource {
    id: coverTexture
    anchors.fill: coverRegion
    sourceItem: coverImage
    hideSource: true
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent
    visible: root.hasCover
    fragmentShader: "CoverBlend.frag.qsb"
    property var artwork: coverTexture
    property size cardSize: Qt.size(width, height)
    property real cardRadius: root.radius
    property color primaryColor: root.colorOf(root.palette.primary)
    property color secondaryColor: root.colorOf(root.palette.secondary)
    property color baseColor: root.colorOf(root.palette.base)
  }

  ShaderEffect {
    id: aurora
    parent: root.effectHost || root
    anchors.fill: parent
    fragmentShader: "Aurora.frag.qsb"
    property real phase: Math.random() * 36
    property real waveSeed: Math.random() * 4096
    property real aspect: width / Math.max(1, height)
    property size cardSize: Qt.size(width, height)
    property real cardRadius: root.radius
    property vector2d hoverPosition: Qt.vector2d(root.bubblePosition.x, root.bubblePosition.y)
    property vector2d hoverVelocity: Qt.vector2d(root.bubbleVelocity.x, root.bubbleVelocity.y)
    property vector2d trailPosition: Qt.vector2d(root.trailPosition.x, root.trailPosition.y)
    property vector2d tailPosition: Qt.vector2d(root.tailPosition.x, root.tailPosition.y)
    property real hoverStrength: root.playing && root.hasTrack ? root.pointerStrength : 0
    property color primaryColor: root.colorOf(root.palette.primary)
    property color secondaryColor: root.colorOf(root.palette.secondary)
    property color lightColor: root.colorOf(root.palette.light)
    visible: root.playing && root.hasTrack
  }

  FrameAnimation {
    running: root.playing && root.hasTrack && root.visible
    onTriggered: {
      aurora.phase += frameTime
      root.advanceBubble(frameTime)
    }
  }

}
