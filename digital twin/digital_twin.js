// digital_twin.js
//
// Three.js 3D Digital Twin: a low-poly wireframe dumper chassis that tilts
// with live pitch/roll telemetry, and a physics-driven trapezoidal braking
// wedge projected onto the ground plane ahead of it.
//
// Scene units are metres throughout (truck, wedge, grid, camera), so the
// real d_stop distance maps directly onto the wedge's length — no fudge
// scale factors.

let scene, camera, renderer, controls, dumperGroup;
let wedgeGeometry, wedgeFill, wedgeGlow, wedgeEdge;
let containerEl;
let hazardPulseStart = null;
let dustParticles;
let envRocks = [];
let groundGrid;

// Vehicle envelope (metres) — 85t dumper.
const HALF_WIDTH = 1.6;
const FRONT_OFFSET = 3.4;
const WEDGE_FLARE = 1.8;

const COLOR_SLATE = 0x1e293b; // dark slate chassis
const COLOR_CYAN = 0x00f0ff; // cyan accent (cab / dump bed)
const COLOR_SAFE = 0x00e6a8; // glowing emerald / cyan wedge
const COLOR_HAZARD = 0xff0033; // flashing neon red wedge

export function init3D(containerId) {
    containerEl = document.getElementById(containerId);
    if (!containerEl) return;

    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x2d1a11); // Dusty reddish-brown mine atmosphere
    scene.fog = new THREE.Fog(0x2d1a11, 15, 70); // Blends the horizon into dust

    let w = containerEl.clientWidth;
    let h = containerEl.clientHeight;
    if (w === 0 || h === 0) {
        w = 800;
        h = 450;
    }

    camera = new THREE.PerspectiveCamera(50, w / h, 0.1, 500);
    camera.position.set(0, 6.5, -11);

    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(w, h);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    containerEl.appendChild(renderer.domElement);

    if (THREE.OrbitControls) {
        controls = new THREE.OrbitControls(camera, renderer.domElement);
        controls.target.set(0, 1.2, 6);
        controls.enableDamping = true;
        controls.dampingFactor = 0.08;
        controls.minDistance = 6;
        controls.maxDistance = 40;
        controls.maxPolarAngle = Math.PI * 0.49;
        controls.update();
    } else {
        camera.lookAt(0, 1.2, 6);
    }

    scene.add(new THREE.AmbientLight(0x405060, 1.2));
    const keyLight = new THREE.DirectionalLight(0xffffff, 1.2);
    keyLight.position.set(10, 15, 10);
    keyLight.castShadow = true;
    keyLight.shadow.mapSize.width = 1024;
    keyLight.shadow.mapSize.height = 1024;
    keyLight.shadow.camera.near = 0.5;
    keyLight.shadow.camera.far = 50;
    keyLight.shadow.camera.left = -15;
    keyLight.shadow.camera.right = 15;
    keyLight.shadow.camera.top = 15;
    keyLight.shadow.camera.bottom = -15;
    scene.add(keyLight);

    // Mine floor (Iron ore dirt color)
    const floorGeo = new THREE.PlaneGeometry(200, 200);
    const floorMat = new THREE.MeshStandardMaterial({
        color: 0x6e3b22, // Rich reddish brown
        roughness: 0.9,
        metalness: 0.05
    });
    const floor = new THREE.Mesh(floorGeo, floorMat);
    floor.rotation.x = -Math.PI / 2;
    floor.receiveShadow = true;
    scene.add(floor);

    // --- Distinct Haul Road Path (Compacted Dirt) ---
    const roadGeo = new THREE.PlaneGeometry(12, 200); // 24m wide path
    const roadMat = new THREE.MeshStandardMaterial({
        color: 0x8a5232, // Lighter, compacted dirt color
        roughness: 1.0,
        metalness: 0.0,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        polygonOffsetUnits: -1
    });
    const road = new THREE.Mesh(roadGeo, roadMat);
    road.rotation.x = -Math.PI / 2;
    road.receiveShadow = true;
    scene.add(road);

    // --- Tire Tracks ---
    const trackGeo = new THREE.PlaneGeometry(1.5, 200);
    const trackMat = new THREE.MeshBasicMaterial({
        color: 0x3d2112, // Dark, crushed dirt for tracks
        transparent: true,
        opacity: 0.5,
        polygonOffset: true,
        polygonOffsetFactor: -2,
        polygonOffsetUnits: -2
    });
    const trackLeft = new THREE.Mesh(trackGeo, trackMat);
    trackLeft.rotation.x = -Math.PI / 2;
    trackLeft.position.set(-1.8, 0, 0);
    scene.add(trackLeft);

    const trackRight = new THREE.Mesh(trackGeo, trackMat);
    trackRight.rotation.x = -Math.PI / 2;
    trackRight.position.set(1.8, 0, 0);
    scene.add(trackRight);
    // ------------------------------------------------

    // Subtle tactical grid over the dirt
    const grid = new THREE.GridHelper(200, 50, 0xffffff, 0xffffff);
    grid.material.opacity = 0.15;
    grid.material.transparent = true;
    grid.position.y = 0.05;
    scene.add(grid);
    groundGrid = grid;

    // Scatter 3D rocks (boulders) to make the terrain look rugged
    const rockGeo = new THREE.DodecahedronGeometry(1.0, 0);
    const rockMat = new THREE.MeshStandardMaterial({
        color: 0x4a2e1b, // Darker rock color
        roughness: 1.0,
        metalness: 0.1
    });
    for (let i = 0; i < 80; i++) {
        const rock = new THREE.Mesh(rockGeo, rockMat);
        const scale = 0.5 + Math.random() * 2.0;
        rock.scale.set(scale, scale * (0.6 + Math.random() * 0.4), scale);

        // Random position, keeping clear of the center where the dumper drives
        let rx = (Math.random() - 0.5) * 150;
        let rz = (Math.random() - 0.5) * 150;
        if (Math.abs(rx) < 7) {
            rx += 10 * Math.sign(rx || 1);

        }

        rock.position.set(rx, scale * 0.4, rz);
        rock.rotation.set(Math.random() * Math.PI, Math.random() * Math.PI, 0);
        rock.castShadow = true;
        rock.receiveShadow = true;
        scene.add(rock);
        envRocks.push(rock);
    }

    // --- Mine Highwall (Cliff Face) ---
    // In open-cast mines, trucks drive on benches with a towering cliff on one side.
    const cliffGeo = new THREE.PlaneGeometry(200, 50, 40, 15);
    const pos = cliffGeo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
        // Jitter the vertices to create jagged, realistic rock formations
        const jitter = (Math.random() - 0.5) * 5.0;
        pos.setZ(i, pos.getZ(i) + jitter);
    }
    cliffGeo.computeVertexNormals(); // Recalculate lighting for the jagged rocks

    const cliffMat = new THREE.MeshStandardMaterial({
        color: 0x3a2318, // Deep rocky brown
        roughness: 1.0,
        metalness: 0.1
    });

    const cliff = new THREE.Mesh(cliffGeo, cliffMat);
    cliff.position.set(-14, 15, 0); // Positioned on the left side, towering high
    cliff.rotation.y = Math.PI / 2; // Face the truck
    cliff.castShadow = true;
    cliff.receiveShadow = true;
    scene.add(cliff);

    // --- Safety Berm (Right side edge mound) ---
    const bermGeo = new THREE.PlaneGeometry(200, 15, 40, 5);
    const bermPos = bermGeo.attributes.position;
    for (let i = 0; i < bermPos.count; i++) {
        const jitter = (Math.random() - 0.5) * 2.5;
        bermPos.setZ(i, bermPos.getZ(i) + jitter);
    }
    bermGeo.computeVertexNormals();
    const bermMat = new THREE.MeshStandardMaterial({
        color: 0x5a2d18, // slightly darker dirt
        roughness: 1.0,
        metalness: 0.05
    });
    const berm = new THREE.Mesh(bermGeo, bermMat);
    berm.position.set(14, 3, 0); // Positioned on the right side
    berm.rotation.y = -Math.PI / 2; // Face the truck
    berm.rotation.x = -Math.PI / 5; // Lean it back like a mound
    berm.castShadow = true;
    berm.receiveShadow = true;
    scene.add(berm);

    // --- Dust Particle System ---
    const dustGeo = new THREE.BufferGeometry();
    const dustCount = 1500;
    const dustPositions = new Float32Array(dustCount * 3);
    for (let i = 0; i < dustCount * 3; i += 3) {
        dustPositions[i] = (Math.random() - 0.5) * 200; // x
        dustPositions[i + 1] = Math.random() * 40;        // y
        dustPositions[i + 2] = (Math.random() - 0.5) * 200; // z
    }
    dustGeo.setAttribute('position', new THREE.BufferAttribute(dustPositions, 3));
    const dustMat = new THREE.PointsMaterial({
        color: 0x886655,
        size: 0.8,
        transparent: true,
        opacity: 0.6,
        blending: THREE.AdditiveBlending
    });
    dustParticles = new THREE.Points(dustGeo, dustMat);
    scene.add(dustParticles);
    // ----------------------------------

    dumperGroup = buildDumper();
    scene.add(dumperGroup);
    buildWedge();

    // Layout can settle a beat after the canvas is inserted (flex panels).
    setTimeout(onResize, 100);
    window.addEventListener('resize', onResize);

    animate();
}

function onResize() {
    if (!containerEl || !camera || !renderer) return;
    const w = containerEl.clientWidth;
    const h = containerEl.clientHeight;
    if (w === 0 || h === 0) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h);
}

function buildDumper() {
    const group = new THREE.Group();
    // Dummy speed for testing animation (varies naturally around 5 m/s)
    group.userData = { speedMs: 5.0, isDummy: true };

    // Colorful Mining Dumper Materials
    const MINING_YELLOW = 0xfab300;
    const DARK_METAL = 0x222222;
    const CAB_WHITE = 0xdddddd;

    const bodyMat = new THREE.MeshStandardMaterial({ color: MINING_YELLOW, roughness: 0.6, metalness: 0.2 });
    const cabMat = new THREE.MeshStandardMaterial({ color: CAB_WHITE, roughness: 0.4, metalness: 0.5 });
    const bedMat = new THREE.MeshStandardMaterial({ color: MINING_YELLOW, roughness: 0.7, metalness: 0.1 });
    const grillMat = new THREE.MeshStandardMaterial({ color: DARK_METAL, roughness: 0.8, metalness: 0.4 });
    const wheelMat = new THREE.MeshStandardMaterial({ color: 0x0f0f0f, roughness: 0.9, metalness: 0.1 });

    // Edge Materials for wireframe contrast
    const yellowEdge = new THREE.LineBasicMaterial({ color: 0xffcc00, transparent: true, opacity: 0.8 });
    const darkEdge = new THREE.LineBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.5 });

    function addPart(w, h, d, cx, cy, cz, solidMat, edgeMat, parent = group) {
        const geo = new THREE.BoxGeometry(w, h, d);
        const mesh = new THREE.Mesh(geo, solidMat);
        mesh.position.set(cx, cy, cz);
        mesh.castShadow = true;
        mesh.receiveShadow = true;
        parent.add(mesh);

        if (edgeMat) {
            const edges = new THREE.EdgesGeometry(geo);
            const line = new THREE.LineSegments(edges, edgeMat);
            line.position.set(cx, cy, cz);
            parent.add(line);
        }
        return mesh;
    }

    // Heavy Mining Dumper Geometry

    // 1. Central Chassis Rail (Dark Metal)
    addPart(2.0, 0.8, 6.0, 0, 1.4, 0.0, grillMat, darkEdge);

    // 2. Engine Block & Front Deck (Yellow)
    addPart(2.0, 1.5, 2.0, 0, 2.2, 2.2, bodyMat, yellowEdge);

    // 3. Front Grill (Dark Metal)
    addPart(1.6, 1.2, 0.2, 0, 2.2, 3.3, grillMat, darkEdge);

    // 4. Small Operator Cab (Offset to the left side, White)
    addPart(1.0, 1.2, 1.5, -1.2, 3.2, 2.5, cabMat, darkEdge);

    // 5. Massive Hollow Dump Bed (Tipper)
    const bedGroup = new THREE.Group();
    bedGroup.position.set(0, 3.5, -0.8);
    bedGroup.rotation.x = -0.05; // Slightly angled back
    group.add(bedGroup);

    // Construct the hollow bed using 5 thin boxes
    const TH = 0.2; // Thickness
    addPart(4.4, TH, 5.5, 0, -1.0, 0, bedMat, yellowEdge, bedGroup); // Floor
    addPart(TH, 2.2, 5.5, -2.1, 0, 0, bedMat, yellowEdge, bedGroup); // Left Wall
    addPart(TH, 2.2, 5.5, 2.1, 0, 0, bedMat, yellowEdge, bedGroup);  // Right Wall
    addPart(4.0, 2.2, TH, 0, 0, 2.65, bedMat, yellowEdge, bedGroup); // Front Wall (near cab)
    addPart(4.0, 2.2, TH, 0, 0, -2.65, bedMat, yellowEdge, bedGroup); // Back Wall (tailgate)

    // 6. Front Canopy (Attached to bed, protecting the cab, Yellow)
    addPart(4.4, 0.4, 2.5, 0, 1.0, 3.6, bedMat, yellowEdge, bedGroup);

    // --- SIH 2026 Logo Decal ---
    const textureLoader = new THREE.TextureLoader();
    const logoTexture = textureLoader.load('assets/img/sih_logo.png');
    // Using MeshStandardMaterial so it reacts to the new lights
    const logoMat = new THREE.MeshStandardMaterial({
        map: logoTexture,
        transparent: true,
        side: THREE.DoubleSide,
        roughness: 0.5,
        color: 0xffffff
    });

    const logoGeo = new THREE.PlaneGeometry(2.5, 1.25);

    // Right side decal (added to bedGroup)
    const logoRight = new THREE.Mesh(logoGeo, logoMat);
    logoRight.position.set(2.22, 0, 0);
    logoRight.rotation.y = Math.PI / 2;
    bedGroup.add(logoRight);

    // Left side decal (added to bedGroup)
    const logoLeft = new THREE.Mesh(logoGeo, logoMat);
    logoLeft.position.set(-2.22, 0, 0);
    logoLeft.rotation.y = -Math.PI / 2;
    bedGroup.add(logoLeft);
    // ---------------------------

    // --- TERRASIGHT Back Decal (Dynamic Canvas) ---
    const textCanvas = document.createElement('canvas');
    textCanvas.width = 1024;
    textCanvas.height = 256;
    const ctx = textCanvas.getContext('2d');

    // Solid yellow background to act like a painted banner
    ctx.fillStyle = '#fab300';
    ctx.fillRect(0, 0, 1024, 256);

    // Draw Text
    ctx.font = 'bold 130px Arial, sans-serif';
    ctx.fillStyle = '#000000'; // Pure black text
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('TERRASIGHT', 512, 138);

    const textTexture = new THREE.CanvasTexture(textCanvas);
    textTexture.needsUpdate = true;

    // Use MeshBasicMaterial so it glows slightly and ignores shadows 
    // (since the back of the truck gets no direct light)
    const textMat = new THREE.MeshBasicMaterial({
        map: textTexture,
        side: THREE.FrontSide,
        color: 0xffffff
    });

    const textGeo = new THREE.PlaneGeometry(3.6, 0.9);
    const textMesh = new THREE.Mesh(textGeo, textMat);
    // Place on the back wall (tailgate)
    textMesh.position.set(0, 0, -2.77);
    textMesh.rotation.y = Math.PI; // Face strictly backwards
    bedGroup.add(textMesh);
    // ----------------------------------------------

    // Big heavy-duty wheels
    const wheelGeo = new THREE.CylinderGeometry(0.9, 0.9, 0.9, 24);
    const wheelEdgesGeo = new THREE.EdgesGeometry(wheelGeo);

    [
        [-2.0, 2.2], // Front left
        [2.0, 2.2], // Front right
        [-2.0, -2.6], // Rear left
        [2.0, -2.6], // Rear right
    ].forEach(([x, z]) => {
        const wheel = new THREE.Mesh(wheelGeo, wheelMat);
        wheel.rotation.z = Math.PI / 2;
        wheel.position.set(x, 0.9, z);
        wheel.castShadow = true;
        wheel.receiveShadow = true;
        group.add(wheel);

        const edges = new THREE.LineSegments(wheelEdgesGeo, darkEdge);
        edges.rotation.z = Math.PI / 2;
        edges.position.set(x, 0.9, z);
        group.add(edges);
    });

    return group;
}

function buildWedge() {
    // 4 verts: nearLeft, nearRight, farLeft, farRight -> 2 triangles.
    wedgeGeometry = new THREE.BufferGeometry();
    wedgeGeometry.setAttribute(
        'position',
        new THREE.BufferAttribute(new Float32Array(4 * 3), 3)
    );
    wedgeGeometry.setIndex([0, 1, 2, 1, 3, 2]);

    const fillMat = new THREE.MeshBasicMaterial({
        color: COLOR_SAFE,
        transparent: true,
        opacity: 0.35,
        side: THREE.DoubleSide,
        depthWrite: false,
    });
    wedgeFill = new THREE.Mesh(wedgeGeometry, fillMat);
    scene.add(wedgeFill);

    // Additive overlay sharing the same geometry — cheap soft-glow trick
    // without a full bloom post-processing pipeline.
    const glowMat = new THREE.MeshBasicMaterial({
        color: COLOR_SAFE,
        transparent: true,
        opacity: 0.18,
        side: THREE.DoubleSide,
        blending: THREE.AdditiveBlending,
        depthWrite: false,
    });
    wedgeGlow = new THREE.Mesh(wedgeGeometry, glowMat);
    scene.add(wedgeGlow);

    const edgeGeo = new THREE.BufferGeometry();
    edgeGeo.setAttribute(
        'position',
        new THREE.BufferAttribute(new Float32Array(5 * 3), 3) // closed loop
    );
    const edgeMat = new THREE.LineBasicMaterial({
        color: COLOR_SAFE,
        transparent: true,
        opacity: 0.9,
    });
    wedgeEdge = new THREE.Line(edgeGeo, edgeMat);
    scene.add(wedgeEdge);
}

/** Rewrites the wedge's 4 corner vertices in place — no per-frame allocation. */
function updateWedge(stoppingDistanceMeters, usableHorizonMeters) {
    const nearZ = FRONT_OFFSET;
    const farZ = FRONT_OFFSET + Math.max(stoppingDistanceMeters, 0.3);
    const halfFar = HALF_WIDTH * WEDGE_FLARE;

    const pos = wedgeGeometry.attributes.position;
    pos.setXYZ(0, -HALF_WIDTH, 0.03, nearZ);
    pos.setXYZ(1, HALF_WIDTH, 0.03, nearZ);
    pos.setXYZ(2, -halfFar, 0.03, farZ);
    pos.setXYZ(3, halfFar, 0.03, farZ);
    pos.needsUpdate = true;
    wedgeGeometry.computeBoundingSphere();

    const edgePos = wedgeEdge.geometry.attributes.position;
    edgePos.setXYZ(0, -HALF_WIDTH, 0.05, nearZ);
    edgePos.setXYZ(1, -halfFar, 0.05, farZ);
    edgePos.setXYZ(2, halfFar, 0.05, farZ);
    edgePos.setXYZ(3, HALF_WIDTH, 0.05, nearZ);
    edgePos.setXYZ(4, -HALF_WIDTH, 0.05, nearZ);
    edgePos.needsUpdate = true;
    wedgeEdge.geometry.computeBoundingSphere();

    const isSafe = stoppingDistanceMeters <= usableHorizonMeters;
    if (isSafe) {
        hazardPulseStart = null;
        setWedgeColor(COLOR_SAFE, 0.35, 0.18, 0.9);
    } else if (hazardPulseStart === null) {
        hazardPulseStart = performance.now();
    }
    return isSafe;
}

function setWedgeColor(hex, fillOpacity, glowOpacity, edgeOpacity) {
    wedgeFill.material.color.setHex(hex);
    wedgeFill.material.opacity = fillOpacity;
    wedgeGlow.material.color.setHex(hex);
    wedgeGlow.material.opacity = glowOpacity;
    wedgeEdge.material.color.setHex(hex);
    wedgeEdge.material.opacity = edgeOpacity;
}

function animate() {
    requestAnimationFrame(animate);

    // Smooth hazard pulse, decoupled from telemetry tick rate.
    if (hazardPulseStart !== null) {
        const t = (performance.now() - hazardPulseStart) / 700;
        const pulse = 0.55 + 0.45 * Math.sin(t * Math.PI * 2);
        wedgeFill.material.color.setHex(COLOR_HAZARD);
        wedgeGlow.material.color.setHex(COLOR_HAZARD);
        wedgeEdge.material.color.setHex(COLOR_HAZARD);
        wedgeFill.material.opacity = 0.25 + 0.35 * pulse;
        wedgeGlow.material.opacity = 0.12 + 0.28 * pulse;
        wedgeEdge.material.opacity = 0.6 + 0.4 * pulse;
    }

    if (controls) controls.update();


    // Speed-based forward movement simulation
    if (dumperGroup && dumperGroup.userData.isDummy) {
        const time = performance.now() / 1000;

        // Simulate driving for 12 seconds, stopping for 3 seconds
        const cycle = time % 15;
        if (cycle < 3) {
            dumperGroup.userData.speedMs = 0; // Truck stopped
        } else {
            // Base 5m/s, fluctuates smoothly between ~3.5 and 6.5 m/s
            dumperGroup.userData.speedMs = 5.0 + Math.sin(time * 1.2) * 0.6 + Math.sin(time * 0.5) * 0.9;
        }

        // Update Dashboard DOM so the Live Telemetry card looks active
        const elSpeed = document.getElementById('val-speed');
        if (elSpeed) {
            const ms = dumperGroup.userData.speedMs;
            elSpeed.innerHTML = ms.toFixed(1) + ' <small>m/s</small>';
        }
    }
    const speedMs = dumperGroup ? (dumperGroup.userData.speedMs || 0) : 0;
    if (speedMs > 0) {
        const deltaZ = speedMs * 0.04; // Adjust scale for visual realism

        // Scroll rocks backwards (negative Z to simulate forward movement)
        for (let rock of envRocks) {
            rock.position.z -= deltaZ;
            if (rock.position.z < -100) rock.position.z += 200;
        }

        // Scroll tactical grid backwards
        if (groundGrid) {
            groundGrid.position.z -= deltaZ;
            if (groundGrid.position.z < -4) groundGrid.position.z += 4; // Reset after 1 cell (200/50=4m)
        }
    }

    // Animate drifting dust particles

    if (dustParticles) {
        const positions = dustParticles.geometry.attributes.position.array;
        for (let i = 1; i < positions.length; i += 3) {
            positions[i] -= 0.04; // fall down slowly
            positions[i - 1] += 0.02; // drift slightly right (wind)
            positions[i + 1] -= speedMs * 0.06; // Wind rushes past faster when driving (negative Z)
            if (positions[i + 1] < -100) positions[i + 1] += 200;
            if (positions[i] < 0) {
                positions[i] = 40; // reset to top
                positions[i - 1] = (Math.random() - 0.5) * 200; // random X
            }
        }
        dustParticles.geometry.attributes.position.needsUpdate = true;
    }

    renderer.render(scene, camera);
}

/**
 * Feeds one telemetry frame into the twin. Returns the derived braking
 * metrics so the caller can drive alert banners/audio off the same
 * single source of truth used to colour the wedge.
 */
export function updateTwin(telemetry) {
    if (!dumperGroup || !wedgeGeometry) return { dStop: 0, isSafe: true };

    // Three.js is right-handed. Pitch rotates about X, roll about Z.
    dumperGroup.rotation.x = -THREE.MathUtils.degToRad(telemetry.pitch || 0);
    dumperGroup.rotation.z = -THREE.MathUtils.degToRad(telemetry.roll || 0);

    const cfg = window.TS_CONFIG || {};
    const reactionS = cfg.reactionS || 1.5;
    const decelMs2 = cfg.decelMs2 || 1.5;

    const speedMs = (telemetry.speed || 0) / 3.6;
    dumperGroup.userData.speedMs = speedMs;
    dumperGroup.userData.isDummy = false; // Real data overrides dummy fluctuation
    const dStop = speedMs * reactionS + (speedMs * speedMs) / (2 * decelMs2);
    const usableHorizonM = (telemetry.tofDistance || 0) / 100;

    const isSafe = updateWedge(dStop, usableHorizonM);

    return { dStop, isSafe };
}
