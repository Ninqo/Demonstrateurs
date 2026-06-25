<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'

const props = defineProps({
  isDark: Boolean
})

const canvasRef = ref(null)
const canvasWrapperRef = ref(null)
const boids = ref([])
const numBoids = 120

const separationDist = ref(25)
const alignmentDist = ref(50)
const cohesionDist = ref(50)

const separationFactor = ref(1.5)
const alignmentFactor = ref(1.0)
const cohesionFactor = ref(1.0)
const maxSpeed = ref(2.5)
const boidSize = ref(20)

let animationFrameId = null
let resizeObserver = null

const resizeCanvas = () => {
  const canvas = canvasRef.value
  const wrapper = canvasWrapperRef.value
  if (!canvas || !wrapper) return
  const targetWidth = Math.floor(wrapper.clientWidth)
  const targetHeight = Math.floor(wrapper.clientHeight)
  if (targetWidth > 0 && canvas.width !== targetWidth) canvas.width = targetWidth
  if (targetHeight > 0 && canvas.height !== targetHeight) canvas.height = targetHeight
}

const initBoids = () => {
  const canvas = canvasRef.value
  if (!canvas) return
  const arr = []
  for (let i = 0; i < numBoids; i++) {
    arr.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      vx: (Math.random() - 0.5) * maxSpeed.value * 2,
      vy: (Math.random() - 0.5) * maxSpeed.value * 2
    })
  }
  boids.value = arr
}

const updateBoids = () => {
  const canvas = canvasRef.value
  if (!canvas) return
  const w = canvas.width
  const h = canvas.height

  boids.value.forEach(b => {
    let closeDx = 0, closeDy = 0
    let avgVx = 0, avgVy = 0, alignmentNeighbors = 0
    let avgX = 0, avgY = 0, cohesionNeighbors = 0

    boids.value.forEach(other => {
      if (b === other) return
      const dx = b.x - other.x
      const dy = b.y - other.y
      const dist = Math.hypot(dx, dy)

      if (dist < separationDist.value) {
        closeDx += dx
        closeDy += dy
      }
      if (dist < alignmentDist.value) {
        avgVx += other.vx
        avgVy += other.vy
        alignmentNeighbors++
      }
      if (dist < cohesionDist.value) {
        avgX += other.x
        avgY += other.y
        cohesionNeighbors++
      }
    })

    b.vx += closeDx * separationFactor.value * 0.05
    b.vy += closeDy * separationFactor.value * 0.05

    if (alignmentNeighbors > 0) {
      avgVx /= alignmentNeighbors
      avgVy /= alignmentNeighbors
      b.vx += (avgVx - b.vx) * alignmentFactor.value * 0.05
      b.vy += (avgVy - b.vy) * alignmentFactor.value * 0.05
    }

    if (cohesionNeighbors > 0) {
      avgX /= cohesionNeighbors
      avgY /= cohesionNeighbors
      b.vx += (avgX - b.x) * cohesionFactor.value * 0.01
      b.vy += (avgY - b.y) * cohesionFactor.value * 0.01
    }

    const speed = Math.hypot(b.vx, b.vy)
    if (speed > maxSpeed.value) {
      b.vx = (b.vx / speed) * maxSpeed.value
      b.vy = (b.vy / speed) * maxSpeed.value
    }

    b.x += b.vx
    b.y += b.vy

    if (b.x < 0) b.x = w
    if (b.x > w) b.x = 0
    if (b.y < 0) b.y = h
    if (b.y > h) b.y = 0
  })
}

const draw = () => {
  const canvas = canvasRef.value
  if (!canvas) return
  const ctx = canvas.getContext('2d')
  ctx.clearRect(0, 0, canvas.width, canvas.height)

  ctx.fillStyle = props.isDark ? '#22d3ee' : '#0e7490'

  boids.value.forEach(b => {
    ctx.beginPath()
    const angle = Math.atan2(b.vy, b.vx)
    const s = boidSize.value
    ctx.moveTo(b.x + Math.cos(angle) * s, b.y + Math.sin(angle) * s)
    ctx.lineTo(b.x + Math.cos(angle + 2.5) * s * 0.55, b.y + Math.sin(angle + 2.5) * s * 0.55)
    ctx.lineTo(b.x + Math.cos(angle - 2.5) * s * 0.55, b.y + Math.sin(angle - 2.5) * s * 0.55)
    ctx.closePath()
    ctx.fill()
  })

  updateBoids()
  animationFrameId = requestAnimationFrame(draw)
}

watch(canvasRef, (newVal) => {
  if (newVal) {
    resizeCanvas()
    initBoids()
    draw()
  }
})

onMounted(() => {
  if (canvasRef.value) {
    resizeCanvas()
    initBoids()
    draw()
  }
  if (canvasWrapperRef.value) {
    resizeObserver = new ResizeObserver(() => {
      resizeCanvas()
    })
    resizeObserver.observe(canvasWrapperRef.value)
  }
})

onUnmounted(() => {
  cancelAnimationFrame(animationFrameId)
  if (resizeObserver) resizeObserver.disconnect()
})
</script>

<template>
  <div class="space-y-6 w-full max-w-[1200px] mx-auto pb-12">
    <div :class="['border p-6 rounded-2xl shadow-md transition-colors', isDark ? 'bg-slate-900/60 border-slate-800 text-white' : 'bg-white border-[#cbd5e1] text-[#1e293b]']">
      <h2 class="text-2xl font-black mb-2" :class="isDark ? 'text-cyan-400' : '!text-black'">02. SYSTÈMES COMPLEXES ET ÉMERGENCE</h2>

      <p class="text-sm leading-relaxed" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
        Ce démonstrateur montre comment un comportement collectif réaliste peut émerger à partir de règles très simples.
        Chaque boid ne connaît que son voisinage local (pas de chef, pas de vision globale), et pourtant le groupe
        forme des trajectoires cohérentes.
      </p>

      <p class="text-sm leading-relaxed mt-2" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
        Pour le public : imaginez des oiseaux ou des poissons. Ils n’obéissent pas à un leader unique.
        Ils appliquent localement 3 règles : éviter la collision, s’aligner, rester groupés.
      </p>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4 pt-4 border-t text-xs" :class="isDark ? 'border-slate-700/30' : 'border-[#cbd5e1]'">
        <div>
          <span class="font-black uppercase" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">1. Séparation</span>
          <p :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Évite les collisions entre voisins proches.</p>
        </div>
        <div>
          <span class="font-black uppercase" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">2. Alignement</span>
          <p :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Converge vers la direction moyenne locale.</p>
        </div>
        <div>
          <span class="font-black uppercase" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">3. Cohésion</span>
          <p :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Reste proche du centre de masse des voisins.</p>
        </div>
      </div>
    </div>

    <div :class="['border p-4 rounded-2xl space-y-4', isDark ? 'bg-[#0f172a] border-slate-800' : 'bg-white border-[#cbd5e1]']">
      <div class="grid grid-cols-2 md:grid-cols-5 gap-4 text-xs font-mono">
        <div>
          <label class="block mb-1 font-bold" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Force Séparation ({{ separationFactor.toFixed(2) }})</label>
          <input type="range" min="0" max="3" step="0.1" v-model.number="separationFactor" class="w-full accent-cyan-600" />
        </div>
        <div>
          <label class="block mb-1 font-bold" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Force Alignement ({{ alignmentFactor.toFixed(2) }})</label>
          <input type="range" min="0" max="3" step="0.1" v-model.number="alignmentFactor" class="w-full accent-cyan-600" />
        </div>
        <div>
          <label class="block mb-1 font-bold" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Force Cohésion ({{ cohesionFactor.toFixed(2) }})</label>
          <input type="range" min="0" max="3" step="0.1" v-model.number="cohesionFactor" class="w-full accent-cyan-600" />
        </div>
        <div>
          <label class="block mb-1 font-bold" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Vitesse Limite ({{ maxSpeed.toFixed(1) }})</label>
          <input type="range" min="1" max="6" step="0.5" v-model.number="maxSpeed" class="w-full accent-cyan-600" />
        </div>
        <div>
          <label class="block mb-1 font-bold" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Taille des Boids ({{ boidSize }} px)</label>
          <input type="range" min="8" max="36" step="1" v-model.number="boidSize" class="w-full accent-cyan-600" />
        </div>
      </div>

      <div ref="canvasWrapperRef" class="boids-canvas-wrapper flex items-center justify-center rounded-xl p-2 border" :class="isDark ? 'bg-slate-950 border-slate-800' : 'bg-[#eef2f6] border-[#cbd5e1]'">
        <canvas ref="canvasRef" class="block w-full h-full"></canvas>
      </div>
    </div>
  </div>
</template>

<style scoped>
.boids-canvas-wrapper {
  width: 100%;
  height: 420px;
  box-sizing: border-box;
  overflow: hidden;
}

@media (max-width: 768px) {
  .boids-canvas-wrapper {
    height: 320px;
  }
}
</style>