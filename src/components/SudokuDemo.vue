<script setup>
/**
 * =====================================================================================
 * FICHIER : SudokuDemo.vue
 * RÔLE :
 *   Comparer 3 stratégies de résolution d'un Sudoku en parallèle :
 *     1) Backtracking naïf (force brute)
 *     2) MRV (Minimum Remaining Values)
 *     3) Approche de sélection de case type DSATUR
 *
 * IMPORTANT :
 *   - Algorithmes conservés.
 *   - Nommage et commentaires largement francisés.
 * =====================================================================================
 */

import { ref } from 'vue'

/** Prop thème */
defineProps({
  isDark: Boolean
})

/**
 * Paramètres globaux du démonstrateur
 */
const delai = ref(1)                 // délai visuel entre opérations
const enResolution = ref(false)      // true pendant exécution
const signalAnnulation = ref(false)  // permet d'interrompre proprement

/**
 * Compteurs d'opérations (pour comparaison pédagogique)
 */
const essaisBrut = ref(0)
const essaisHeuristique = ref(0)
const essaisGraphe = ref(0)

/**
 * Jeux de grilles prédéfinies (0 = case vide)
 */
const grillesDisponibles = [
  [
    [5,3,0,0,7,0,0,0,0], [6,0,0,1,9,5,0,0,0], [0,9,8,0,0,0,0,6,0],
    [8,0,0,0,6,0,0,0,3], [4,0,0,8,0,3,0,0,1], [7,0,0,0,2,0,0,0,6],
    [0,6,0,0,0,0,2,8,0], [0,0,0,4,1,9,0,0,5], [0,0,0,0,8,0,0,7,9]
  ],
  [
    [0,0,0,0,0,0,0,1,2], [0,0,0,0,0,0,0,0,3], [0,0,2,3,0,0,4,0,0],
    [0,0,1,8,0,0,0,0,5], [0,6,0,0,7,0,8,0,0], [0,0,0,0,0,9,0,0,0],
    [0,0,8,5,0,0,0,0,0], [9,0,0,0,4,0,5,0,0], [4,7,0,0,0,6,0,0,0]
  ]
]

/**
 * Palette de couleurs pour la vue "graphe" :
 * chaque chiffre 1..9 a une couleur dédiée.
 */
const couleursGraphe = [
  { bg: '#ef4444', text: '#ffffff' },
  { bg: '#f97316', text: '#ffffff' },
  { bg: '#eab308', text: '#111111' },
  { bg: '#22c55e', text: '#ffffff' },
  { bg: '#14b8a6', text: '#ffffff' },
  { bg: '#3b82f6', text: '#ffffff' },
  { bg: '#8b5cf6', text: '#ffffff' },
  { bg: '#ec4899', text: '#ffffff' },
  { bg: '#78350f', text: '#ffffff' }
]

/** Retourne la couleur associée à une valeur */
const getCouleur = (valeur) => couleursGraphe[valeur - 1]

/**
 * Grille de référence + 3 copies indépendantes pour les 3 solveurs
 */
const grilleBase = ref(JSON.parse(JSON.stringify(grillesDisponibles[0])))
const grilleBrute = ref(JSON.parse(JSON.stringify(grilleBase.value)))
const grilleHeuristique = ref(JSON.parse(JSON.stringify(grilleBase.value)))
const grilleGraphe = ref(JSON.parse(JSON.stringify(grilleBase.value)))

/**
 * attendre()
 * -------------------------------------------------------------------------------------
 * Pause asynchrone pour ralentir/visualiser la résolution.
 * Si delai = 0 : très rapide avec micro-yield ponctuel pour garder UI fluide.
 */
const attendre = () => new Promise(resolve => {
  if (delai.value === 0) {
    if (Math.random() < 0.1) setTimeout(resolve, 1)
    else resolve()
  } else {
    setTimeout(resolve, delai.value)
  }
})

/**
 * estValide(grille, r, c, val)
 * -------------------------------------------------------------------------------------
 * Vérifie si la valeur "val" est autorisée à la position (r,c) :
 *   - pas de doublon en ligne
 *   - pas de doublon en colonne
 *   - pas de doublon dans le bloc 3x3
 */
const estValide = (grille, r, c, val) => {
  for (let i = 0; i < 9; i++) {
    if (grille[r][i] === val && i !== c) return false
    if (grille[i][c] === val && i !== r) return false
  }

  const debutLigneBloc = Math.floor(r / 3) * 3
  const debutColBloc = Math.floor(c / 3) * 3

  for (let i = 0; i < 3; i++) {
    for (let j = 0; j < 3; j++) {
      if (
        grille[debutLigneBloc + i][debutColBloc + j] === val &&
        (debutLigneBloc + i !== r || debutColBloc + j !== c)
      ) return false
    }
  }

  return true
}

/**
 * resoudreBrut()
 * -------------------------------------------------------------------------------------
 * Solveur 1 : backtracking naïf.
 * Parcours linéaire des cases vides + test 1..9.
 */
const resoudreBrut = async () => {
  const recherche = async () => {
    if (signalAnnulation.value) return false

    for (let r = 0; r < 9; r++) {
      for (let c = 0; c < 9; c++) {
        if (grilleBrute.value[r][c] === 0) {
          for (let num = 1; num <= 9; num++) {
            essaisBrut.value++

            if (estValide(grilleBrute.value, r, c, num)) {
              grilleBrute.value[r][c] = num
              await attendre()

              if (await recherche()) return true

              grilleBrute.value[r][c] = 0
              await attendre()
            }
          }
          return false
        }
      }
    }
    return true
  }

  await recherche()
}

/**
 * getCaseMRV(grille)
 * -------------------------------------------------------------------------------------
 * Choisit la case vide avec le plus petit nombre de valeurs possibles.
 * Principe "Minimum Remaining Values".
 */
const getCaseMRV = (grille) => {
  let minimumChoix = 10
  let meilleureCase = null

  for (let r = 0; r < 9; r++) {
    for (let c = 0; c < 9; c++) {
      if (grille[r][c] === 0) {
        let nbPossibilites = 0

        for (let n = 1; n <= 9; n++) {
          if (estValide(grille, r, c, n)) nbPossibilites++
        }

        if (nbPossibilites < minimumChoix) {
          minimumChoix = nbPossibilites
          meilleureCase = { r, c }
        }
      }
    }
  }

  return meilleureCase
}

/**
 * resoudreMRV()
 * -------------------------------------------------------------------------------------
 * Solveur 2 : backtracking + sélection MRV.
 */
const resoudreMRV = async () => {
  const recherche = async () => {
    if (signalAnnulation.value) return false

    const cellule = getCaseMRV(grilleHeuristique.value)
    if (!cellule) return true

    for (let num = 1; num <= 9; num++) {
      essaisHeuristique.value++

      if (estValide(grilleHeuristique.value, cellule.r, cellule.c, num)) {
        grilleHeuristique.value[cellule.r][cellule.c] = num
        await attendre()

        if (await recherche()) return true

        grilleHeuristique.value[cellule.r][cellule.c] = 0
        await attendre()
      }
    }

    return false
  }

  await recherche()
}

/**
 * getCaseDSATUR(grille)
 * -------------------------------------------------------------------------------------
 * Sélectionne une case vide selon une logique de saturation :
 * - on compte les valeurs distinctes déjà présentes autour (ligne/colonne/bloc)
 * - tie-break : "degré" approximé par nb de voisins non colorés
 */
const getCaseDSATUR = (grille) => {
  let saturationMax = -1
  let degreMax = -1
  let meilleureCase = null

  for (let r = 0; r < 9; r++) {
    for (let c = 0; c < 9; c++) {
      if (grille[r][c] === 0) {
        const valeursUniquesVoisines = new Set()
        let voisinsNonColories = 0

        // Ligne + colonne
        for (let i = 0; i < 9; i++) {
          if (i !== c) {
            grille[r][i] !== 0 ? valeursUniquesVoisines.add(grille[r][i]) : voisinsNonColories++
          }
          if (i !== r) {
            grille[i][c] !== 0 ? valeursUniquesVoisines.add(grille[i][c]) : voisinsNonColories++
          }
        }

        // Bloc 3x3
        const br = Math.floor(r / 3) * 3
        const bc = Math.floor(c / 3) * 3

        for (let i = 0; i < 3; i++) {
          for (let j = 0; j < 3; j++) {
            if (br + i !== r && bc + j !== c) {
              grille[br + i][bc + j] !== 0
                ? valeursUniquesVoisines.add(grille[br + i][bc + j])
                : voisinsNonColories++
            }
          }
        }

        if (
          valeursUniquesVoisines.size > saturationMax ||
          (valeursUniquesVoisines.size === saturationMax && voisinsNonColories > degreMax)
        ) {
          saturationMax = valeursUniquesVoisines.size
          degreMax = voisinsNonColories
          meilleureCase = { r, c }
        }
      }
    }
  }

  return meilleureCase
}

/**
 * resoudreGraphe()
 * -------------------------------------------------------------------------------------
 * Solveur 3 : backtracking avec choix de case type DSATUR.
 */
const resoudreGraphe = async () => {
  const recherche = async () => {
    if (signalAnnulation.value) return false

    const cellule = getCaseDSATUR(grilleGraphe.value)
    if (!cellule) return true

    for (let num = 1; num <= 9; num++) {
      essaisGraphe.value++

      if (estValide(grilleGraphe.value, cellule.r, cellule.c, num)) {
        grilleGraphe.value[cellule.r][cellule.c] = num
        await attendre()

        if (await recherche()) return true

        grilleGraphe.value[cellule.r][cellule.c] = 0
        await attendre()
      }
    }

    return false
  }

  await recherche()
}

/**
 * lancerAnalyseComparative()
 * -------------------------------------------------------------------------------------
 * Lance les 3 solveurs en parallèle via Promise.all.
 */
const lancerAnalyseComparative = async () => {
  if (enResolution.value) return

  enResolution.value = true
  signalAnnulation.value = false

  await Promise.all([
    resoudreBrut(),
    resoudreMRV(),
    resoudreGraphe()
  ])

  enResolution.value = false
}

/**
 * reinitialiserGrilles()
 * -------------------------------------------------------------------------------------
 * Stoppe les recherches en cours et restaure les grilles initiales.
 */
const reinitialiserGrilles = () => {
  signalAnnulation.value = true
  enResolution.value = false

  grilleBrute.value = JSON.parse(JSON.stringify(grilleBase.value))
  grilleHeuristique.value = JSON.parse(JSON.stringify(grilleBase.value))
  grilleGraphe.value = JSON.parse(JSON.stringify(grilleBase.value))

  essaisBrut.value = 0
  essaisHeuristique.value = 0
  essaisGraphe.value = 0
}

/**
 * changerConfiguration()
 * -------------------------------------------------------------------------------------
 * Choisit aléatoirement une grille de base puis réinitialise.
 */
const changerConfiguration = () => {
  signalAnnulation.value = true
  enResolution.value = false

  const index = Math.floor(Math.random() * grillesDisponibles.length)
  grilleBase.value = JSON.parse(JSON.stringify(grillesDisponibles[index]))
  reinitialiserGrilles()
}
</script>

<template>
  <div class="space-y-8 w-full max-w-[1200px] mx-auto pb-12">
    <!-- Panneau intro + commandes -->
    <div :class="['border p-6 rounded-2xl shadow-md transition-colors', isDark ? 'bg-slate-900/60 border-slate-800 text-white' : 'bg-white border-[#cbd5e1] text-[#1e293b]']">
      <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-4">
        <div>
          <h2 class="text-2xl font-black" :class="isDark ? 'text-emerald-400' : '!text-black'">
            DÉMONSTRATEUR COMPARAISON D'ALGORITHMES
          </h2>
          <p class="text-xs font-mono uppercase tracking-wider mt-0.5" :class="isDark ? 'text-slate-400' : 'text-[#1e293b]'">
            Analyse de Complexité Expérimentale
          </p>
        </div>

        <!-- Contrôle du délai -->
        <div :class="['flex items-center gap-4 px-4 py-2 rounded-xl border w-full md:w-auto', isDark ? 'bg-slate-950/50 border-slate-700/30' : 'bg-[#eef2f6] border-[#cbd5e1]']">
          <div class="text-xs font-mono whitespace-nowrap">
            <span :class="isDark ? 'text-slate-400' : 'text-[#1e293b]'">DÉLAI PAR ACTION :</span>
            <span class="font-bold ml-1" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">{{ delai }} ms</span>
          </div>

          <input
            type="range"
            min="0"
            max="100"
            v-model.number="delai"
            class="accent-cyan-600 h-1.5 rounded-lg cursor-pointer w-32"
            :class="isDark ? 'bg-slate-700' : 'bg-slate-300'"
          />
        </div>
      </div>

      <p class="text-sm leading-relaxed mb-4" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
        Comparaison visuelle des approches de résolution du Sudoku.
      </p>

      <div class="flex flex-wrap items-center gap-3 border-t pt-4" :class="isDark ? 'border-slate-700/30' : 'border-[#cbd5e1]'">
        <button
          @click="lancerAnalyseComparative"
          :disabled="enResolution"
          class="px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:bg-emerald-800 text-white font-black text-xs uppercase tracking-wider rounded-lg shadow-md transition-all"
        >
          Lancer l'analyse comparative
        </button>

        <button
          @click="changerConfiguration"
          :class="['px-5 py-2.5 font-bold text-xs uppercase tracking-wider rounded-lg transition-all border-2', isDark ? 'bg-slate-800 hover:bg-slate-700 text-slate-200 border-slate-700' : 'bg-white hover:bg-[#eef2f6] text-[#1e293b] border-[#cbd5e1]']"
        >
          Changer de configuration
        </button>

        <button
          @click="reinitialiserGrilles"
          :class="['px-5 py-2.5 border-2 font-bold text-xs uppercase tracking-wider rounded-lg transition-all', isDark ? 'border-slate-700 text-slate-300 hover:bg-slate-800' : 'border-[#1e293b] text-[#1e293b] hover:bg-[#eef2f6]']"
        >
          Réinitialiser les grilles
        </button>
      </div>
    </div>

    <!-- Bloc 1 : brute force -->
    <div :class="['grid grid-cols-1 md:grid-cols-3 gap-8 p-6 rounded-2xl border transition-colors shadow-sm', isDark ? 'bg-[#0f172a] border-slate-800' : 'bg-white border-[#cbd5e1]']">
      <div class="md:col-span-1 flex flex-col items-center justify-center">
        <div class="font-mono text-xl font-black mb-3" :class="isDark ? 'text-cyan-400' : 'text-[#0e7490]'">
          {{ essaisBrut }} Opérations
        </div>

        <div :class="['sudoku-grid', isDark ? 'border-slate-400 bg-slate-950' : 'border-[#1e293b] bg-white']">
          <template v-for="(row, r) in grilleBrute" :key="'brut-r-'+r">
            <div
              v-for="(cell, c) in row"
              :key="'brut-c-'+c"
              class="sudoku-cell"
              :class="[
                isDark ? 'border-slate-800 text-white' : 'border-slate-300 text-[#1e293b]',
                (c + 1) % 3 === 0 && c !== 8 ? (isDark ? 'border-r-thick-dark' : 'border-r-thick-light') : '',
                (r + 1) % 3 === 0 && r !== 8 ? (isDark ? 'border-b-thick-dark' : 'border-b-thick-light') : '',
                grilleBase[r][c] !== 0
                  ? (isDark ? 'bg-slate-800/80 text-slate-400' : 'bg-slate-200 text-slate-600')
                  : (isDark ? 'text-cyan-400 font-black' : 'text-[#0e7490] font-black')
              ]"
            >
              {{ cell || '' }}
            </div>
          </template>
        </div>
      </div>

      <div class="md:col-span-2 space-y-3 flex flex-col justify-center">
        <h3 class="text-lg font-black uppercase tracking-wide" :class="isDark ? 'text-white' : 'text-[#1e293b]'">
          1. Backtracking Naïf (Force Brute)
        </h3>
        <p class="text-sm leading-relaxed" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
          Parcours séquentiel des cases, tests successifs des valeurs, retours arrière en cas d'impasse.
        </p>
      </div>
    </div>

    <!-- Bloc 2 : MRV -->
    <div :class="['grid grid-cols-1 md:grid-cols-3 gap-8 p-6 rounded-2xl border transition-colors shadow-sm', isDark ? 'bg-[#0f172a] border-slate-800' : 'bg-white border-[#cbd5e1]']">
      <div class="md:col-span-2 space-y-3 flex flex-col justify-center order-2 md:order-1">
        <h3 class="text-lg font-black uppercase tracking-wide" :class="isDark ? 'text-white' : 'text-[#1e293b]'">
          2. Heuristique MRV
        </h3>
        <p class="text-sm leading-relaxed" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
          Sélection prioritaire de la case la plus contrainte pour réduire l'exploration.
        </p>
      </div>

      <div class="md:col-span-1 flex flex-col items-center justify-center order-1 md:order-2">
        <div class="font-mono text-xl font-black mb-3" :class="isDark ? 'text-emerald-400' : 'text-emerald-700'">
          {{ essaisHeuristique }} Opérations
        </div>

        <div :class="['sudoku-grid', isDark ? 'border-slate-400 bg-slate-950' : 'border-[#1e293b] bg-white']">
          <template v-for="(row, r) in grilleHeuristique" :key="'mrv-r-'+r">
            <div
              v-for="(cell, c) in row"
              :key="'mrv-c-'+c"
              class="sudoku-cell"
              :class="[
                isDark ? 'border-slate-800 text-white' : 'border-slate-300 text-[#1e293b]',
                (c + 1) % 3 === 0 && c !== 8 ? (isDark ? 'border-r-thick-dark' : 'border-r-thick-light') : '',
                (r + 1) % 3 === 0 && r !== 8 ? (isDark ? 'border-b-thick-dark' : 'border-b-thick-light') : '',
                grilleBase[r][c] !== 0
                  ? (isDark ? 'bg-slate-800/80 text-slate-400' : 'bg-slate-200 text-slate-600')
                  : (isDark ? 'text-emerald-400 font-black' : 'text-emerald-700 font-black')
              ]"
            >
              {{ cell || '' }}
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- Bloc 3 : graphe -->
    <div :class="['grid grid-cols-1 md:grid-cols-3 gap-8 p-6 rounded-2xl border transition-colors shadow-sm', isDark ? 'bg-[#0f172a] border-slate-800' : 'bg-white border-[#cbd5e1]']">
      <div class="md:col-span-1 flex flex-col items-center justify-center">
        <div class="font-mono text-xl font-black mb-3" :class="isDark ? 'text-purple-400' : 'text-purple-700'">
          {{ essaisGraphe }} Opérations
        </div>

        <div :class="['sudoku-grid', isDark ? 'border-slate-400 bg-slate-950' : 'border-[#1e293b] bg-white']">
          <template v-for="(row, r) in grilleGraphe" :key="'graph-r-'+r">
            <div
              v-for="(cell, c) in row"
              :key="'graph-c-'+c"
              class="sudoku-cell"
              :class="[
                isDark ? 'border-slate-800' : 'border-slate-300',
                (c + 1) % 3 === 0 && c !== 8 ? (isDark ? 'border-r-thick-dark' : 'border-r-thick-light') : '',
                (r + 1) % 3 === 0 && r !== 8 ? (isDark ? 'border-b-thick-dark' : 'border-b-thick-light') : '',
                grilleBase[r][c] !== 0 && cell !== 0 ? 'sudoku-cell--fixed' : ''
              ]"
              :style="cell !== 0 && grilleBase[r][c] === 0
                ? { backgroundColor: getCouleur(cell).bg, color: getCouleur(cell).text }
                : (grilleBase[r][c] !== 0
                  ? { backgroundColor: isDark ? 'rgba(30,41,59,0.8)' : '#e2e8f0', color: isDark ? '#94a3b8' : '#475569' }
                  : {})"
            >
              {{ cell || '' }}
            </div>
          </template>
        </div>

        <div class="flex flex-wrap justify-center gap-1.5 mt-4 max-w-[260px]">
          <div
            v-for="(couleur, i) in couleursGraphe"
            :key="'legend-'+i"
            class="flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-mono font-bold"
            :style="{ backgroundColor: couleur.bg, color: couleur.text }"
          >
            {{ i + 1 }}
          </div>
        </div>

        <p class="text-[11px] font-mono mt-2 text-center" :class="isDark ? 'text-slate-400' : 'text-[#1e293b]'">
          Une couleur = une valeur posée
        </p>
      </div>

      <div class="md:col-span-2 space-y-3 flex flex-col justify-center">
        <h3 class="text-lg font-black uppercase tracking-wide" :class="isDark ? 'text-white' : 'text-[#1e293b]'">
          3. Modélisation par Graphe (DSATUR)
        </h3>
        <p class="text-sm leading-relaxed" :class="isDark ? 'text-slate-300' : 'text-[#1e293b]'">
          Choix prioritaire des cases selon la saturation des contraintes voisines.
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
/**
 * Grille Sudoku fixe :
 * - évite les artefacts d'arrondi des tailles en pourcentage
 * - assure un affichage stable
 */
.sudoku-grid {
  display: grid;
  grid-template-columns: repeat(9, 1fr);
  grid-template-rows: repeat(9, 1fr);
  width: 270px;
  height: 270px;
  border: 2px solid;
  box-sizing: border-box;
  overflow: hidden;
}

/**
 * Cellule standard
 */
.sudoku-cell {
  width: 30px;
  height: 30px;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  justify-content: center;
  font-family: ui-monospace, Consolas, monospace;
  font-weight: 700;
  font-size: 15px;
  border-width: 0.5px;
  border-style: solid;
  user-select: none;
  transition: background-color 0.15s, color 0.15s;
}

/** Bordures épaisses des blocs 3x3 */
.border-r-thick-dark { border-right: 2px solid #94a3b8; }
.border-r-thick-light { border-right: 2px solid #1e293b; }
.border-b-thick-dark { border-bottom: 2px solid #94a3b8; }
.border-b-thick-light { border-bottom: 2px solid #1e293b; }

/** Responsive mobile */
@media (max-width: 768px) {
  .sudoku-grid { width: 234px; height: 234px; }
  .sudoku-cell { width: 26px; height: 26px; font-size: 13px; }
}
</style>