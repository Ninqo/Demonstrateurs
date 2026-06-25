<script setup>
import { ref, onMounted, onUnmounted, watch, computed } from 'vue'

const props = defineProps({
  isDark: Boolean
})

/**
 * =====================================================================================
 * DÉMONSTRATEUR : RÉSEAU SOCIAL
 * -------------------------------------------------------------------------------------
 * Ce module simule la diffusion d'une information dans un réseau social, avec :
 *  - des influenceurs (portée élevée)
 *  - des utilisateurs lambda
 *  - des utilisateurs peu actifs / hors-ligne
 *
 * En plus, on introduit :
 *  - des MODES de simulation (normal / viral / prudent)
 *  - une PROBABILITÉ d'erreur (désinformation)
 *  - une inactivité prolongée (utilisateurs absents plusieurs jours)
 * =====================================================================================
 */

const canvasRef = ref(null)
const canvasWrapperRef = ref(null)

let animationFrameId = null
let resizeObserver = null

/**
 * Paramètres de base de propagation
 */
const transmissionDelay = ref(40)      // Latence entre deux étapes (ms base)
const mutationRate = ref(8)            // Ancien concept "altération" -> désinformation (%)
const inactiveNodeRate = ref(18)       // Utilisateurs hors-ligne au départ (%)

/**
 * NOUVEAU : jours d'absence simulés
 * Plus cette valeur est grande, plus la part de comptes temporairement inactifs augmente.
 */
const offlineDays = ref(0)             // 0..14 jours

/**
 * NOUVEAU : modes de simulation
 * - normal  : usage standard
 * - viral   : partage facilité (buzz)
 * - prudent : utilisateurs plus sceptiques (vérification)
 */
const mode = ref('normal')

/**
 * Structure réseau
 */
const nodes = ref([])
const edges = ref([])

/**
 * Logs explicatifs
 */
const logs = ref([
  '> Simulateur réseau social initialisé.',
  '> En attente d’une injection d’information...'
])

/**
 * État de la boucle de propagation
 */
let propagationRunning = false

/**
 * Nœud survolé
 */
const hoveredNode = ref(null)

/**
 * =====================================================================================
 * PARAMÈTRES DÉRIVÉS SELON LE MODE
 * =====================================================================================
 */

/**
 * Probabilité de partage de base selon le mode
 */
const baseShareProb = computed(() => {
  if (mode.value === 'viral') return 0.88
  if (mode.value === 'prudent') return 0.52
  return 0.72 // normal
})

/**
 * Facteur de "vérification" (réduit les erreurs partagées)
 */
const verificationFactor = computed(() => {
  if (mode.value === 'prudent') return 0.55
  if (mode.value === 'viral') return 0.9
  return 0.75
})

/**
 * Bonus d'activité des influenceurs selon le mode
 */
const influencerBoost = computed(() => {
  if (mode.value === 'viral') return 1.2
  if (mode.value === 'prudent') return 0.9
  return 1.0
})

/**
 * =====================================================================================
 * OUTILS CANVAS
 * =====================================================================================
 */

const resizeCanvas = () => {
  const canvas = canvasRef.value
  const wrapper = canvasWrapperRef.value
  if (!canvas || !wrapper) return

  const targetWidth = Math.floor(wrapper.clientWidth)
  const targetHeight = Math.floor(wrapper.clientHeight)

  const sizeChanged =
    (targetWidth > 0 && canvas.width !== targetWidth) ||
    (targetHeight > 0 && canvas.height !== targetHeight)

  if (targetWidth > 0) canvas.width = targetWidth
  if (targetHeight > 0) canvas.height = targetHeight

  // Si la taille change et que le graphe existe déjà -> régénération
  if (sizeChanged && nodes.value.length > 0) {
    generateTopology()
  }
}

/**
 * =====================================================================================
 * GÉNÉRATION DU RÉSEAU SOCIAL
 * =====================================================================================
 */

const generateTopology = () => {
  const canvas = canvasRef.value
  if (!canvas) return

  const width = canvas.width
  const height = canvas.height

  const newNodes = []
  const newEdges = []
  const numNodes = 85

  /**
   * Proportion de types :
   * - influenceurs : ~10%
   * - lambda       : ~70%
   * - lowActivity  : ~20% (peu suivis / peu actifs)
   */
  const influencerRate = 0.10
  const lowActivityRate = 0.20

  // Impact des jours hors réseau (absences prolongées)
  // plus de jours => plus de comptes marqués offline
  const extraOffline = Math.min(offlineDays.value * 1.2, 20) // max +20%
  const effectiveOfflineRate = Math.min(inactiveNodeRate.value + extraOffline, 75)

  for (let i = 0; i < numNodes; i++) {
    const r = Math.random()
    let userClass = 'lambda'
    if (r < influencerRate) userClass = 'influencer'
    else if (r < influencerRate + lowActivityRate) userClass = 'lowActivity'

    const isOffline = Math.random() < (effectiveOfflineRate / 100)

    newNodes.push({
      id: i,
      x: Math.random() * (width - 50) + 25,
      y: Math.random() * (height - 50) + 25,
      state: isOffline ? 'offline' : 'idle',  // idle / shared / misinformed / offline
      class: userClass,                       // influencer / lambda / lowActivity
      linksCount: 0
    })
  }

  /**
   * Connexions sociales :
   * - Influenceur : portée large
   * - Lambda      : portée moyenne
   * - LowActivity : portée réduite
   */
  for (let i = 0; i < numNodes; i++) {
    if (newNodes[i].state === 'offline') continue

    for (let j = i + 1; j < numNodes; j++) {
      if (newNodes[j].state === 'offline') continue

      const dist = Math.hypot(newNodes[i].x - newNodes[j].x, newNodes[i].y - newNodes[j].y)

      const typeA = newNodes[i].class
      const typeB = newNodes[j].class

      let maxDist = 58 // base lambda-lambda
      if (typeA === 'influencer' || typeB === 'influencer') maxDist = 125
      else if (typeA === 'lowActivity' || typeB === 'lowActivity') maxDist = 48

      if (dist < maxDist) {
        newEdges.push({ source: i, target: j, active: false })
        newNodes[i].linksCount++
        newNodes[j].linksCount++
      }
    }
  }

  nodes.value = newNodes
  edges.value = newEdges
  propagationRunning = false

  logs.value.push(`> Réseau social généré : ${numNodes} comptes (mode: ${mode.value}).`)
  logs.value.push(`> Comptes hors-ligne estimés : ${Math.round(effectiveOfflineRate)}% (absences simulées: ${offlineDays.value} jour(s)).`)
}

/**
 * =====================================================================================
 * INJECTION ET PROPAGATION
 * =====================================================================================
 */

const injectFlux = () => {
  if (nodes.value.length === 0) return

  // Priorité à un influenceur actif si possible
  const root =
    nodes.value.find(n => n.state === 'idle' && n.class === 'influencer') ||
    nodes.value.find(n => n.state === 'idle' && n.linksCount > 2) ||
    nodes.value.find(n => n.state === 'idle')

  if (!root) return

  root.state = 'shared'
  logs.value.push(`> Information injectée sur le compte #${root.id} (${root.class}).`)
  startPropagationLoop()
}

const injectFluxFromNode = (nodeId) => {
  const target = nodes.value[nodeId]
  if (!target || target.state === 'offline') return
  if (target.state === 'shared' || target.state === 'misinformed') return

  target.state = 'shared'
  logs.value.push(`> Injection manuelle sur #${target.id} (${target.class}).`)
  startPropagationLoop()
}

const startPropagationLoop = () => {
  if (propagationRunning) return
  propagationRunning = true
  propagateStep()
}

/**
 * Probabilité effective de partage pour une cible donnée
 */
const getShareProbability = (targetNode) => {
  let p = baseShareProb.value

  // Influence de la classe sociale
  if (targetNode.class === 'influencer') p *= influencerBoost.value
  if (targetNode.class === 'lowActivity') p *= 0.62

  // Plus il y a de jours hors-ligne, plus la réactivité baisse
  p *= Math.max(0.45, 1 - offlineDays.value * 0.04)

  return Math.max(0.05, Math.min(0.98, p))
}

/**
 * Probabilité effective d'erreur (désinformation) après partage
 */
const getErrorProbability = () => {
  // mutationRate = base d’erreur
  let p = mutationRate.value / 100

  // Mode prudent -> plus de vérification
  p *= verificationFactor.value

  // Plus d'absence -> plus de partage sans contexte, donc risque un peu accru
  p *= (1 + offlineDays.value * 0.025)

  return Math.max(0.0, Math.min(0.95, p))
}

const propagateStep = () => {
  let changed = false
  const currentStates = nodes.value.map(n => n.state)

  const shareErrorProbability = getErrorProbability()

  edges.value.forEach(edge => {
    const sNode = nodes.value[edge.source]
    const tNode = nodes.value[edge.target]

    // source -> target
    if ((currentStates[edge.source] === 'shared' || currentStates[edge.source] === 'misinformed') && tNode.state === 'idle') {
      const shareP = getShareProbability(tNode)

      if (Math.random() < shareP) {
        // Cas d’erreur : l’info devient déformée / fausse
        tNode.state = Math.random() < shareErrorProbability ? 'misinformed' : 'shared'
        edge.active = true
        changed = true
      }
    }

    // target -> source
    if ((currentStates[edge.target] === 'shared' || currentStates[edge.target] === 'misinformed') && sNode.state === 'idle') {
      const shareP = getShareProbability(sNode)

      if (Math.random() < shareP) {
        sNode.state = Math.random() < shareErrorProbability ? 'misinformed' : 'shared'
        edge.active = true
        changed = true
      }
    }
  })

  if (changed) {
    setTimeout(propagateStep, transmissionDelay.value * 4)
  } else {
    propagationRunning = false

    // Petit bilan statistique de fin de propagation
    const shared = nodes.value.filter(n => n.state === 'shared').length
    const misinfo = nodes.value.filter(n => n.state === 'misinformed').length
    const offline = nodes.value.filter(n => n.state === 'offline').length

    logs.value.push(`> Stabilisation atteinte : partagés=${shared}, erreurs=${misinfo}, hors-ligne=${offline}.`)
  }
}

/**
 * =====================================================================================
 * INTERACTIONS SOURIS
 * =====================================================================================
 */

const getNodeAtPosition = (canvasX, canvasY) => {
  let closest = null
  let closestDist = Infinity

  nodes.value.forEach(node => {
    const dist = Math.hypot(node.x - canvasX, node.y - canvasY)
    const baseRadius = node.class === 'influencer' ? 8 : (node.class === 'lambda' ? 5 : 4)
    const hitRadius = baseRadius + 6

    if (dist < hitRadius && dist < closestDist) {
      closest = node
      closestDist = dist
    }
  })

  return closest
}

const onCanvasClick = (event) => {
  const canvas = canvasRef.value
  if (!canvas) return

  const rect = canvas.getBoundingClientRect()
  const scaleX = canvas.width / rect.width
  const scaleY = canvas.height / rect.height
  const x = (event.clientX - rect.left) * scaleX
  const y = (event.clientY - rect.top) * scaleY

  const clicked = getNodeAtPosition(x, y)
  if (clicked) {
    injectFluxFromNode(clicked.id)
  }
}

const onCanvasMove = (event) => {
  const canvas = canvasRef.value
  if (!canvas) return

  const rect = canvas.getBoundingClientRect()
  const scaleX = canvas.width / rect.width
  const scaleY = canvas.height / rect.height
  const x = (event.clientX - rect.left) * scaleX
  const y = (event.clientY - rect.top) * scaleY

  const node = getNodeAtPosition(x, y)
  hoveredNode.value = node ? node.id : null
  canvas.style.cursor = node && node.state !== 'offline' ? 'pointer' : 'default'
}

/**
 * =====================================================================================
 * RENDU
 * =====================================================================================
 */

const draw = () => {
  const canvas = canvasRef.value
  if (!canvas) return

  const ctx = canvas.getContext('2d')
  ctx.clearRect(0, 0, canvas.width, canvas.height)

  // Arêtes
  edges.value.forEach(edge => {
    const s = nodes.value[edge.source]
    const t = nodes.value[edge.target]

    ctx.beginPath()
    ctx.moveTo(s.x, s.y)
    ctx.lineTo(t.x, t.y)

    if (edge.active) {
      ctx.strokeStyle = props.isDark ? 'rgba(34, 211, 238, 0.72)' : 'rgba(14, 116, 144, 0.85)'
      ctx.lineWidth = 2
    } else {
      ctx.strokeStyle = props.isDark ? 'rgba(71, 85, 105, 0.22)' : 'rgba(148, 163, 184, 0.35)'
      ctx.lineWidth = 1
    }
    ctx.stroke()
  })

  // Nœuds
  nodes.value.forEach(node => {
    ctx.beginPath()

    const isHovered = hoveredNode.value === node.id && node.state !== 'offline'
    const baseRadius = node.class === 'influencer' ? 8 : (node.class === 'lambda' ? 5 : 4)
    const radius = baseRadius + (isHovered ? 3 : 0)

    ctx.arc(node.x, node.y, radius, 0, Math.PI * 2)

    if (node.state === 'shared') {
      ctx.fillStyle = '#22d3ee'
    } else if (node.state === 'misinformed') {
      ctx.fillStyle = '#f43f5e'
    } else if (node.state === 'offline') {
      ctx.fillStyle = props.isDark ? '#334155' : '#cbd5e1'
    } else {
      // idle
      if (node.class === 'influencer') {
        ctx.fillStyle = props.isDark ? '#eab308' : '#b45309'
      } else if (node.class === 'lambda') {
        ctx.fillStyle = props.isDark ? '#64748b' : '#475569'
      } else {
        ctx.fillStyle = props.isDark ? '#94a3b8' : '#64748b'
      }
    }

    ctx.fill()

    if (isHovered) {
      ctx.lineWidth = 2
      ctx.strokeStyle = props.isDark ? '#f8fafc' : '#1e293b'
      ctx.stroke()
    }
  })

  animationFrameId = requestAnimationFrame(draw)
}

/**
 * =====================================================================================
 * WATCHERS ET CYCLE DE VIE
 * =====================================================================================
 */

// Re-génération si paramètres structurels changent
watch([mutationRate, inactiveNodeRate, offlineDays, mode], () => {
  generateTopology()
})

watch(canvasRef, (newVal) => {
  if (newVal) {
    resizeCanvas()
    generateTopology()
    draw()
  }
})

onMounted(() => {
  if (canvasRef.value) {
    resizeCanvas()
    generateTopology()
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
    <!-- INTRO PÉDAGOGIQUE -->
    <div :class="['border p-6 rounded-2xl shadow-md transition-colors', isDark ? 'bg-slate-900/60 border-slate-800 text-white' : 'bg-white border-[#cbd5e1] text-[#1e293b]']">
      <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-4">
        <div>
          <h2 class="text-2xl font-black" :class="isDark ? 'text-cyan-400' : '!text-black'">
            DÉMONSTRATEUR RÉSEAU SOCIAL : DIFFUSION D'INFORMATIONS
          </h2>
          <p class="text-xs font-mono uppercase tracking-wider mt-0.5" :class="isDark ? 'text-slate-400' : 'text-[#1e293b]'">
            Simulation de propagation (influence, activité, erreur de transmission)
          </p>
        </div>
        <div class="text-xs font-mono px-3 py-1.5 rounded-lg border" :class="isDark ? 'bg-slate-950 border-slate-800' : 'bg-[#eef2f6] border-[#cbd5e1]'">
          Latence globale :
          <span class="font-bold" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">{{ transmissionDelay * 4 }} ms</span>
        </div>
      </div>

      <p class="text-sm leading-relaxed" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
        Ici, chaque nœud représente un compte de réseau social. Les connexions représentent des relations d’audience.
        Une information injectée se diffuse de proche en proche, avec des probabilités qui dépendent du type d’utilisateur
        (influenceur, utilisateur lambda, peu actif/hors-ligne).
      </p>

      <p class="text-sm leading-relaxed mt-3" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
        L’objectif pédagogique est de montrer qu’une diffusion virale n’est pas uniquement liée au message :
        la <strong>structure du graphe</strong>, le <strong>niveau d’activité</strong> et la
        <strong>probabilité d’erreur</strong> changent fortement le résultat final.
      </p>

      <p class="text-sm leading-relaxed mt-2 font-bold" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">
        💡 Cliquez sur un nœud pour lancer la propagation depuis ce compte précis.
      </p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- VISUALISATION -->
      <div :class="['lg:col-span-2 border p-4 rounded-2xl flex flex-col justify-between', isDark ? 'bg-[#0f172a] border-slate-800' : 'bg-white border-[#cbd5e1]']">
        <div class="text-xs font-mono mb-2" :class="isDark ? 'text-slate-400' : 'text-[#1e293b]'">
          // VISUALISATION_RÉSEAU_SOCIAL_2D — clic pour injecter une information
        </div>

        <div ref="canvasWrapperRef" class="reseau-canvas-wrapper flex-grow flex items-center justify-center rounded-xl p-2 border" :class="isDark ? 'bg-slate-950 border-slate-800' : 'bg-[#eef2f6] border-[#cbd5e1]'">
          <canvas
            ref="canvasRef"
            class="block w-full h-full"
            @click="onCanvasClick"
            @mousemove="onCanvasMove"
            @mouseleave="hoveredNode = null"
          ></canvas>
        </div>
      </div>

      <div class="space-y-4 flex flex-col justify-between">
        <!-- LÉGENDE -->
        <div :class="['border p-5 rounded-2xl space-y-4', isDark ? 'bg-slate-900/40 border-slate-800' : 'bg-white border-[#cbd5e1]']">
          <span class="text-xs font-mono font-bold block" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
            LÉGENDE DU RÉSEAU SOCIAL
          </span>

          <div class="space-y-2 text-xs">
            <div class="font-bold" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">Types d’utilisateurs</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">🟡 Influenceur : forte portée (beaucoup d’abonnés)</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">🔵 Utilisateur lambda : activité moyenne</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">⚪ Peu actif : faible diffusion potentielle</div>
          </div>

          <div class="space-y-2 text-xs pt-2 border-t" :class="isDark ? 'border-slate-700/30' : 'border-[#cbd5e1]'">
            <div class="font-bold" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">États de diffusion</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">🟦 shared : information relayée</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">🟥 misinformed : relayée avec erreur</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">◻ offline : compte inactif/hors-ligne</div>
          </div>

          <div class="space-y-2 text-xs pt-2 border-t" :class="isDark ? 'border-slate-700/30' : 'border-[#cbd5e1]'">
            <div class="font-bold" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">Connexions</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Trait fin : relation existante mais non utilisée</div>
            <div :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">Trait lumineux : relation ayant servi à transmettre</div>
          </div>
        </div>

        <!-- PARAMÈTRES -->
        <div :class="['border p-5 rounded-2xl space-y-4 flex-grow', isDark ? 'bg-slate-900/40 border-slate-800' : 'bg-white border-[#cbd5e1]']">
          <span class="text-xs font-mono font-bold block mb-2" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
            Paramètres de simulation
          </span>

          <!-- Mode -->
          <div>
            <div class="text-[11px] font-mono mb-1" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
              Mode de propagation :
            </div>
            <select v-model="mode" class="w-full text-xs rounded-lg px-2 py-1.5 border"
              :class="isDark ? 'bg-slate-950 border-slate-700 text-slate-200' : 'bg-white border-[#cbd5e1] text-[#1e293b]'">
              <option value="normal">Normal (réseau courant)</option>
              <option value="viral">Viral (forte amplification)</option>
              <option value="prudent">Prudent (vérification renforcée)</option>
            </select>
          </div>

          <div>
            <div class="flex justify-between text-[11px] font-mono mb-1" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
              <span>Probabilité d’erreur (base) :</span>
              <span class="font-bold" :class="isDark ? 'text-rose-400' : 'text-rose-700'">{{ mutationRate }}%</span>
            </div>
            <input type="range" min="0" max="40" v-model.number="mutationRate" class="w-full accent-rose-600" />
          </div>

          <div>
            <div class="flex justify-between text-[11px] font-mono mb-1" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
              <span>Comptes peu actifs/hors-ligne :</span>
              <span class="font-bold" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">{{ inactiveNodeRate }}%</span>
            </div>
            <input type="range" min="0" max="60" v-model.number="inactiveNodeRate" class="w-full accent-slate-600" />
          </div>

          <div>
            <div class="flex justify-between text-[11px] font-mono mb-1" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
              <span>Absence simulée (jours hors réseau) :</span>
              <span class="font-bold" :class="isDark ? 'text-amber-400' : 'text-amber-700'">{{ offlineDays }} jour(s)</span>
            </div>
            <input type="range" min="0" max="14" step="1" v-model.number="offlineDays" class="w-full accent-amber-600" />
          </div>

          <div :class="['p-2 rounded text-[11px] leading-relaxed', isDark ? 'bg-slate-950 text-slate-300' : 'bg-[#f8fafc] text-[#1e293b]']">
            <strong>Lecture “probabilité d’erreur” :</strong><br>
            chaque partage peut transformer l’information correcte en version altérée.  
            En mode prudent, la vérification réduit ce risque. En mode viral, la vitesse augmente,
            mais les erreurs peuvent se propager plus loin.
          </div>
        </div>

        <!-- ACTIONS + LOGS -->
        <div :class="['border p-4 rounded-2xl space-y-3', isDark ? 'bg-slate-950 border-slate-800' : 'bg-[#eef2f6] border-[#cbd5e1]']">
          <div class="flex gap-2">
            <button @click="injectFlux" class="flex-1 py-2 bg-cyan-600 hover:bg-cyan-500 text-white font-bold text-xs uppercase rounded-lg shadow-md">
              Injecter une information
            </button>
            <button @click="generateTopology" :class="['px-3 py-2 border-2 font-bold text-xs uppercase rounded-lg transition-all', isDark ? 'border-slate-700 text-slate-300 hover:bg-slate-800' : 'border-[#1e293b] bg-white text-[#1e293b] hover:bg-[#eef2f6]']">
              Régénérer
            </button>
          </div>

          <div class="bg-black text-[11px] font-mono p-3 rounded-lg h-24 overflow-y-auto text-emerald-400 border border-emerald-900">
            <div v-for="(log, i) in logs.slice(-4)" :key="i">{{ log }}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.reseau-canvas-wrapper {
  width: 100%;
  height: 420px;
  box-sizing: border-box;
  overflow: hidden;
}

@media (max-width: 1024px) {
  .reseau-canvas-wrapper {
    height: 320px;
  }
}
</style>