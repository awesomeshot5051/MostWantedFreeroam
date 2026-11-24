<!--
  Most Wanted Freeroam achievements. A game UI page (controller friendly). The list, the unlocked state and the progress text (already in the
  player's unit system) all come from mwf_core.achievementsGet().
-->
<template>
  <div class="mwf-ach" role="dialog" aria-label="Achievements" v-bng-on-ui-nav:back="close" @keydown.esc.stop="close">
    <header class="top">
      <h1>Achievements <span class="count">{{ done }} / {{ total }}</span></h1>
      <div class="actions">
        <button bng-nav-item type="button" class="btn" :class="{ danger: confirming }" @click="resetAll">{{ confirming ? "Really reset? Press again" : "Reset achievements" }}</button>
        <button bng-nav-item type="button" class="btn primary" bng-scoped-nav-autofocus="true" v-bng-ui-nav-focus="1000" @click="close">Close</button>
      </div>
    </header>

    <div class="scroll">
      <article v-for="a in items" :key="a.id" class="ach" :class="{ got: a.got }" bng-nav-item tabindex="0">
        <div class="mark">{{ a.got ? "✓" : "" }}</div>
        <div class="text">
          <b>{{ a.name }}</b>
          <p>{{ a.desc }}</p>
          <div v-if="a.progressText" class="prog">
            <div class="bar"><div class="fill" :style="{ width: Math.round((a.progress || 0) * 100) + '%' }"></div></div>
            <span>{{ a.progressText }}</span>
          </div>
        </div>
      </article>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue"
import { useBridge } from "@/bridge"
// a priority element: when the controller takes over again after the mouse was used, the game focuses this one
import vBngUiNavFocus from "@/common/directives/BngUiNavFocus"
import vBngOnUiNav from "@/common/directives/BngOnUiNav"

const emit = defineEmits(["close"])
const bridge = useBridge()
const done = ref(0)
const total = ref(0)
const items = ref([])
const listOf = v => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.values(v) : [])

const close = () => emit("close")

// two presses: the first one asks, the second one wipes (it goes back to normal after 4 s)
const confirming = ref(false)
let confirmTimer = null
function apply(res) {
  if (!res) return
  done.value = res.done ?? 0
  total.value = res.total ?? 0
  items.value = listOf(res.items)
}
async function resetAll() {
  if (!confirming.value) {
    confirming.value = true
    clearTimeout(confirmTimer)
    confirmTimer = setTimeout(() => (confirming.value = false), 4000)
    return
  }
  clearTimeout(confirmTimer)
  confirming.value = false
  apply(await new Promise(resolve => bridge.api.engineLua("mwf_core.achievementsReset()", resolve)))
}

onMounted(async () => {
  const res = await new Promise(resolve => bridge.api.engineLua("mwf_core.achievementsGet()", resolve))
  if (!res) return
  done.value = res.done ?? 0
  total.value = res.total ?? 0
  items.value = listOf(res.items)
})
</script>

<style scoped>
.mwf-ach {
  --panel: rgba(255, 255, 255, 0.06);
  --muted: rgba(255, 255, 255, 0.72);
  --ok: #4ade80;
  --accent: #ff6600;
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  flex-direction: column;
  gap: 0.8em;
  padding: 2.2em 3em 1.6em;
  box-sizing: border-box;
  background: rgba(21, 21, 23, 0.94);
  color: #fff;
  font-size: 1rem;
  pointer-events: auto;
  overflow: hidden;
}
.mwf-ach *, .mwf-ach *::before, .mwf-ach *::after { box-sizing: border-box; }
.top { display: flex; justify-content: space-between; align-items: center; gap: 1em; flex: none; }
.top h1 { margin: 0; font-size: 1.5em; font-weight: 600; }
.count { margin-left: 0.6em; color: var(--accent); }
.scroll { flex: 1 1 auto; min-height: 0; overflow-y: auto; padding-right: 0.6em; display: flex; flex-direction: column; gap: 0.5em; }
.ach { display: flex; gap: 1em; align-items: flex-start; padding: 0.8em 1em; border-radius: 0.6em; background: var(--panel); }
.ach:focus, .ach:focus-visible { outline: none; box-shadow: inset 0 0 0 2px var(--accent); }
.mark { flex: none; width: 1.6em; height: 1.6em; border-radius: 50%; border: 2px solid rgba(255, 255, 255, 0.3); display: grid; place-items: center; color: #0b2012; font-weight: 700; }
.ach.got .mark { background: var(--ok); border-color: var(--ok); }
.ach.got b { color: var(--ok); }
.text { flex: 1 1 auto; min-width: 0; }
.text p { margin: 0.2em 0 0; color: var(--muted); font-size: 0.9em; }
.prog { display: flex; align-items: center; gap: 0.8em; margin-top: 0.4em; color: var(--muted); font-size: 0.85em; }
.bar { flex: 0 0 14em; height: 0.5em; border-radius: 0.3em; background: rgba(255, 255, 255, 0.12); overflow: hidden; }
.fill { height: 100%; background: #60a5fa; }
.btn { appearance: none; border: 0; border-radius: 0.5em; padding: 0.55em 1.1em; color: #fff; font: inherit; cursor: pointer; background: rgba(255, 255, 255, 0.12); }
.btn:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.btn.primary { background: var(--accent); }
.btn.danger { background: #c62828; }
.actions { display: flex; gap: 0.6em; }
</style>
