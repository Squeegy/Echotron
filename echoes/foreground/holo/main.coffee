module.exports = class Holo extends Echotron.EchoStack

  uniformAttrs:
    size: 'f'
    borderStart: 'f'
    borderEnd:   'f'

  constructor: ->
    super

    @initParams()

    # Vertex attributes used in the vertex shader
    @vertexAttrs =
      whitening:
        type: 'f'
        value: []

      vertexColor:
        type: 'c'
        value: []

    # Create a geometry object and populate it with vertices.
    # No need to position them yet, we do that every frame.
    @geometry = new THREE.Geometry
    for u in [0...@qty.segments]
      for v in [0...@qty.chips]

        # Create vertex and save it's u and v with it.
        vert = new THREE.Vector3
        vert.u = u / @qty.segments
        vert.v = v / @qty.chips

        # Add the vertex to the geometry and set a color for it.
        @geometry.vertices.push vert
        @vertexAttrs.whitening.value.push 0
        @vertexAttrs.vertexColor.value.push(
          if @solidColor
            @solidColor
          else
            new THREE.Color().setHSV(vert.v, 1, 1)
        )

    # Create the particle system with our geometry and a simple material
    @particles = new THREE.ParticleSystem(
      @geometry
      new THREE.ShaderMaterial(
        vertexColors:   THREE.VertexColors  # use the vertex colors set above
        uniforms:       @uniforms
        attributes:     @vertexAttrs
        vertexShader:   assets["vert.glsl"]
        fragmentShader: assets["frag.glsl"]
        transparent:    yes
      )
    )

    # Spawn with a random rotation
    @particles.rotation.set(
      THREE.Math.randFloat 0, 360.degToRad
      THREE.Math.randFloat 0, 360.degToRad
      THREE.Math.randFloat 0, 360.degToRad
    )

    # Tween up the birth animation
    @animateBirth()

    # A rotating, involuting torus covered in particles definately needs to be
    # depth sorted to draw properly.
    @particles.sortParticles = yes

    # add the particle system to the scene
    @add @particles

  initParams: ->
    borderWidth = THREE.Math.randFloat 0.05, 0.4
    console.log borderWidth

    # Pick a snazzy display mode
    [
      # black outline
      =>
        @borderStart = 1.0 - borderWidth
        @borderEnd   = 0.9 - borderWidth

      # colored outline, black center
      =>
        @borderStart = 0.9 - borderWidth
        @borderEnd   = 1.0 - borderWidth

      # no outline
      =>
        @borderStart = 1.1
        @borderEnd   = 1

      # Solid color
      =>
        @borderStart = 1.1
        @borderEnd   = 1
        @solidColor = new THREE.Color().setHSV(
          THREE.Math.randFloat(0, 1)
          THREE.Math.randFloat(0, 0.5)
          1
        )

    ].random()()

    # rotation speeds on all 3 axes
    @rotationSpeedX = THREE.Math.randFloatSpread 60.degToRad
    @rotationSpeedY = THREE.Math.randFloatSpread 60.degToRad
    @rotationSpeedZ = THREE.Math.randFloatSpread 60.degToRad

    # speed of torus involution
    @involutionSpeedOnBar = THREE.Math.randFloat 0.1, 0.3
    @involutionSpeed = @involutionSpeedOnBar
    @involution = 0

    # Size of each particle
    @sizeOnBeat = THREE.Math.randFloat 25, 85
    @size = @sizeOnBeat

    # radius to the center of the ring
    @r1 = 15 + TWEEN.Easing.Quadratic.In(Math.random()) * 25
    console.log @r1

    # radius of the ring
    @r2 = THREE.Math.randFloat @r1/4, @r1

    # do the particles have a border?
    @border = no

    # number of particles
    @qty =

      # number of torus chips
      chips: THREE.Math.randInt 3, 24

      # fidelity of each chip
      segments: THREE.Math.randInt 32, 80

  animateBirth: ->
    # Animate birth
    r1 = @r1
    r2 = @r2
    @r1 = @r2 = 0

    curves = [
      TWEEN.Easing.Sinusoidal
      TWEEN.Easing.Cubic
      TWEEN.Easing.Quadratic
      TWEEN.Easing.Back
    ]

    new TWEEN.Tween(this)
      .to({r1}, (1.5 / stage.song.bps).ms)
      .easing(curves.random().Out)
      .start()

    new TWEEN.Tween(this)
      .to({r2}, (1 / stage.song.bps).ms)
      .easing(curves.random().Out)
      .start()

  update: (elapsed) ->
    # update the particle size
    @size -= @sizeOnBeat * elapsed / 2
    @size = 0 if @size < 0
    @particles.material.size = @size

    # add rotation speeds to to the torus rotation
    @particles.rotation.x += @rotationSpeedX * elapsed
    @particles.rotation.y += @rotationSpeedY * elapsed
    @particles.rotation.z += @rotationSpeedZ * elapsed

    # add involution speed to curent involution amount
    @involutionSpeed -= @involutionSpeedOnBar * elapsed / 3
    @involutionSpeed = 0 if @involutionSpeed < 0
    @involution += @involutionSpeed * elapsed

    # loop through each vertex and update the position according to current torus config
    for vert in @geometry.vertices
      vert.copy @placeVert(
        u: vert.u
        v: vert.v
        r1: @r1
        r2: @r2
        involution: @involution
      )

    for i in [0...@vertexAttrs.whitening.value.length]
      amount = @vertexAttrs.whitening.value[i]
      amount -= elapsed * 4
      amount = 0 if amount < 0
      @vertexAttrs.whitening.value[i] = amount

    # bust vertex cache so the new vertex data is loaded
    @geometry.verticesNeedUpdate = yes
  
  # Given a u, v and involution, it returns a vector that represents the position of point on the torus.
  # Each is key in `options` normalized zero to one, representing how far around the circle the value is.
  #
  #   Required keys: u, v, involution
  placeVert: (options = {}) ->
    r1 = options.r1
    r2 = options.r2

    # convert from 0 to 1 to 0 to 2*PI
    u = options.u * 2 * Math.PI
    v = options.v * 2 * Math.PI

    # update v to make a holochip, instead of a simple ring
    v += u

    # update u with current involution amount
    u += options.involution * 2 * Math.PI

    # convert u, v to torus coordinates according to the standard torus formula
    new THREE.Vector3(
      (r1 + r2 * Math.cos(u)) * Math.cos(v)
      (r1 + r2 * Math.cos(u)) * Math.sin(v)
      r2 * Math.sin(u) * 1.6180339887 # PHI
    )


  onBeat: ->
    @size = @sizeOnBeat

  onBar: ->
    @involutionSpeed = @involutionSpeedOnBar

  onSegment: (segment) ->
    pitches = segment.pitches
    return unless pitches

    for vertIndex in [0...@geometry.vertices.length]
      vertex = @geometry.vertices[vertIndex]
      whitenings = @vertexAttrs.whitening.value

      for i in [0...pitches.length]
        if i == Math.floor(vertex.v * 12)
          whitenings[vertIndex] = pitches[i]

  kill: ->
    super
    @sizeOnBeat *= 4

  alive: ->
    @size > 0