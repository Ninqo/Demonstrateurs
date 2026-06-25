<script setup>
import { ref, onMounted } from 'vue'
import SudokuDemo from './components/SudokuDemo.vue'
import BoidsDemo from './components/BoidsDemo.vue'
import ReseauDemo from './components/ReseauDemo.vue'

/**
 * Thème global de l'application.
 * true  = sombre
 * false = clair
 */
const isDark = ref(true)

/**
 * Onglet actif.
 * Ordre maintenu pour la soutenance.
 */
const activeTab = ref('sudoku')

/**
 * Inverse le thème puis applique les styles de fond/texte globaux.
 */
const toggleTheme = () => {
  isDark.value = !isDark.value
  applyTheme()
}

/**
 * Applique le thème au document entier (html + body).
 * Important pour une lisibilité stable au projecteur.
 */
const applyTheme = () => {
  if (isDark.value) {
    document.documentElement.classList.add('dark')
    document.body.style.backgroundColor = '#0b1329'
    document.body.style.color = '#f8fafc'
  } else {
    document.documentElement.classList.remove('dark')
    document.body.style.backgroundColor = '#ffffff'
    document.body.style.color = '#000000'
  }
}

onMounted(() => {
  applyTheme()
})
</script>

<template>
  <div :class="['min-h-screen transition-colors duration-300', isDark ? 'text-slate-100' : 'text-black']">
    <header :class="['p-6 flex flex-col md:flex-row justify-between items-center gap-4 border-b-4 transition-colors', isDark ? 'bg-[#0f172a] border-slate-800' : 'bg-white border-black']">
      <div>
        <h1 :class="['text-3xl font-black tracking-tighter', isDark ? 'text-cyan-400' : '!text-black']">
          PROJET DEMONSTRATEURS ALGORITHMIQUE ET COMPLEXITÉ
        </h1>
      </div>

      <div class="flex items-center gap-4">
        <div :class="['flex p-1 rounded-xl border-2', isDark ? 'bg-slate-900 border-slate-700' : 'bg-white border-black']">
                    <button
            @click="activeTab = 'sudoku'"
            :class="[
              'px-6 py-2 text-xs uppercase font-black rounded-lg transition-all',
              activeTab === 'sudoku'
                ? (isDark ? 'bg-cyan-900 text-cyan-400 border border-cyan-500' : 'bg-black text-white shadow-lg')
                : (isDark ? 'text-slate-400' : 'text-black')
            ]"
          >
            01_Sudoku
          </button>

          <button
            @click="activeTab = 'boids'"
            :class="[
              'px-6 py-2 text-xs uppercase font-black rounded-lg transition-all',
              activeTab === 'boids'
                ? (isDark ? 'bg-cyan-900 text-cyan-400 border border-cyan-500' : 'bg-black text-white shadow-lg')
                : (isDark ? 'text-slate-400' : 'text-black')
            ]"
          >
            02_Boids
          </button>

                    
          <button
            @click="activeTab = 'reseau'"
            :class="[
              'px-6 py-2 text-xs uppercase font-black rounded-lg transition-all',
              activeTab === 'reseau'
                ? (isDark ? 'bg-cyan-900 text-cyan-400 border border-cyan-500' : 'bg-black text-white shadow-lg')
                : (isDark ? 'text-slate-400' : 'text-black')
            ]"
          >
            03_Réseaux
          </button>
        </div>

        <button
          @click="toggleTheme"
          :class="['px-6 py-2 text-xs uppercase font-black rounded-lg transition-all border-2 shadow-md', isDark ? 'bg-slate-800 border-slate-700 text-yellow-400' : 'bg-black border-black text-white']"
        >
          {{ isDark ? 'Mode Clair' : 'Mode Sombre' }}
        </button>
      </div>
    </header>

    <main class="p-8">
      <SudokuDemo v-if="activeTab === 'sudoku'" :isDark="isDark" />
      <BoidsDemo v-if="activeTab === 'boids'" :isDark="isDark" />
      <ReseauDemo v-if="activeTab === 'reseau'" :isDark="isDark" />
    </main>
  </div>
</template>