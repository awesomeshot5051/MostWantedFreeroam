<!--
  Most Wanted Freeroam options. A game UI page (so it works with a controller): each option is a row you move to with the D-pad / stick
  and change with A. On/off options toggle; number options have - and + buttons; the RLS reset payment is a two-way choice.
  Every change is sent to mwf_core at once (mwf_core.optionsSet) and saved there.
-->
<template>
  <div class="mwf-opt" role="dialog" aria-label="Most Wanted Freeroam options" v-bng-on-ui-nav:back="close" @keydown.esc.stop="close">
    <header class="top">
      <h1>Most Wanted Freeroam - Options</h1>
      <div class="status">
        <button bng-nav-item type="button" class="btn" @click="openAchievements">Achievements</button>
        <button bng-nav-item type="button" class="btn" :class="{ danger: confirming }" @click="resetAchievements">{{ confirming ? "Really reset? Press again" : "Reset achievements" }}</button>
        <button bng-nav-item type="button" class="btn primary" bng-scoped-nav-autofocus="true" v-bng-ui-nav-focus="1000" @click="close">Close</button>
      </div>
    </header>

    <div class="scroll">
      <template v-for="(group, gi) in groups" :key="gi">
        <h2 v-if="group.title">{{ group.title }}</h2>
        <div v-for="o in group.items" :key="o.key" class="opt">
          <div class="opt-text">
            <b>{{ o.label }}</b>
            <p>{{ o.desc }}</p>
          </div>
          <div class="opt-control">
            <button bng-nav-item v-if="o.type === 'bool'" type="button" class="switch" :class="{ on: values[o.key] }" role="switch" :aria-checked="!!values[o.key]" @click="set(o.key, !values[o.key])">
              {{ values[o.key] ? "On" : "Off" }}
            </button>
            <template v-else-if="o.type === 'num'">
              <button bng-nav-item type="button" class="btn step" :disabled="atMin(o)" @click="nudge(o, -1)">&minus;</button>
              <span class="num">{{ fmt(o) }}</span>
              <button bng-nav-item type="button" class="btn step" :disabled="atMax(o)" @click="nudge(o, 1)">+</button>
            </template>
            <template v-else>
              <button bng-nav-item v-for="c in o.choices" :key="c.value" type="button" class="btn choice" :class="{ picked: values[o.key] === c.value }" @click="set(o.key, c.value)">{{ c.label }}</button>
            </template>
          </div>
        </div>
      </template>
      <p class="foot">Changes are saved as you make them. {{ values.rlsActive ? "You are in an RLS career: the RLS options below apply." : "" }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from "vue"
import { useBridge } from "@/bridge"
// a priority element: when the controller takes over again after the mouse was used, the game focuses this one
import vBngUiNavFocus from "@/common/directives/BngUiNavFocus"
// controller: the game's "back" button (B / circle) closes the page, like Esc
import vBngOnUiNav from "@/common/directives/BngOnUiNav"

const emit = defineEmits(["close"])
const bridge = useBridge()
function callLua(fn, ...args) {
  const api = bridge.api
  const code = `mwf_core.${fn}(${args.map(a => api.serializeToLua(a)).join(",")})`
  return new Promise(resolve => api.engineLua(code, resolve))
}

const values = reactive({})

// limits and step sizes (the limits are enforced again in Lua)
const B = (key, label, desc) => ({ key, label, desc, type: "bool" })
const N = (key, label, desc, min, max, step, digits, suffix = "") => ({ key, label, desc, type: "num", min, max, step, digits, suffix })
const groups = [
  { title: "Traffic and performance", items: [
    B("hideCivilians", "Hide civilian traffic during chases", "Civilians are hidden while you are being chased and return when it ends. Police are not affected. Less load, fewer hitches."),
    B("thinTraffic", "Thin out civilian traffic as police increase", "The more police are on the road, the fewer civilian cars stay around (none at 16 police). Far-away cars go first. Fewer cars = fewer dropped frames."),
    B("smooth", "Smooth spawning", "Wait for a steady frame rate before spawning the next police unit."),
    N("spawnInterval", "Seconds between unit spawns", "Raise it if new waves make the game stutter.", 0.5, 6, 0.5, 1, " s"),
    N("waveScale", "Wave size", "Scales how many units and props each wave brings. Lower it if new waves make the game stutter.", 0.25, 1, 0.05, 2),
  ] },
  { title: "Gameplay", items: [
    B("weaponChase", "Weapons can start a chase", "Using a weapon (Weapon Panel or Universal Weapons) on a police car or a civilian car counts as an offense, but only if a police car can see you do it."),
    B("onFoot", "Get out of your car on foot (chases only)", "Stop, press the walking-mode key to get out, and run to another car. Sprinting uses stamina, and police can still bust you on foot if they surround you. Costs nothing. Takes effect from the next chase."),
    B("stealCars", "Steal traffic cars while on foot", "Walk up to a civilian car and press the walking-mode key to carjack it. Not used in an RLS career (RLS and its carjacking add-on handle that)."),
    N("sensitivity", "Police sensitivity", "How easily police start a chase. 1.00 is the game's default. Lower: speeding alone stops triggering chases. Higher: even minor offenses start one. Only affects starting a chase.", 0.25, 2, 0.05, 2),
  ] },
  { title: "Pit stops and prices", items: [
    B("pitCosts", "Pit stop costs", "In a garage during a chase (the chase pauses while it is open), a shop lists cars and parts at their listed price and charges you bounty. Off = free, with the game's own selector. Gas stations only repair."),
    B("fallbackPits", "Generate pit stops from map POIs when a map has none", "Maps that define no gas stations and/or no garages get some made from their points of interest, so both are always available. Maps that define their own are never changed."),
    N("priceFactor", "Price factor", "The share of the real price that cars and parts cost.", 0.1, 1, 0.05, 2),
  ] },
  { title: "RLS career", items: [
    { key: "rlsResetPayment", label: "How a Crash Breaker reset is paid", desc: "Only used in an RLS Career Overhaul career. There, resets cost real money, escaping pays a small capped reward, and pit stops are off.", type: "choice",
      choices: [{ value: "insurance", label: "Insurance claim" }, { value: "private", label: "Private" }] },
  ] },
]

const round = (v, digits) => Number(Number(v).toFixed(digits))
const fmt = o => Number(values[o.key] ?? 0).toFixed(o.digits) + o.suffix
const atMin = o => Number(values[o.key]) <= o.min + 1e-9
const atMax = o => Number(values[o.key]) >= o.max - 1e-9

async function set(key, value) {
  values[key] = value // show it at once; Lua answers with the real value
  const res = await callLua("optionsSet", key, value)
  if (res && typeof res === "object") Object.assign(values, res)
}
function nudge(o, dir) {
  const next = Math.max(o.min, Math.min(o.max, round(Number(values[o.key]) + dir * o.step, 3)))
  set(o.key, next)
}
function openAchievements() {
  callLua("openAchievements")
  emit("close")
}
// two presses: the first one asks, the second one wipes all achievement progress (it goes back to normal after 4 s)
const confirming = ref(false)
let confirmTimer = null
async function resetAchievements() {
  if (!confirming.value) {
    confirming.value = true
    clearTimeout(confirmTimer)
    confirmTimer = setTimeout(() => (confirming.value = false), 4000)
    return
  }
  clearTimeout(confirmTimer)
  confirming.value = false
  await callLua("achievementsReset")
}
function close() {
  emit("close")
}

onMounted(async () => {
  const init = await callLua("optionsInit")
  if (init && typeof init === "object") Object.assign(values, init)
})
</script>

<style scoped>
.mwf-opt {
  --panel: rgba(255, 255, 255, 0.06);
  --panel-2: rgba(255, 255, 255, 0.1);
  --line: rgba(255, 255, 255, 0.1);
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
.mwf-opt *, .mwf-opt *::before, .mwf-opt *::after { box-sizing: border-box; }
.top { display: flex; justify-content: space-between; align-items: center; gap: 1em; flex: none; }
.top h1 { margin: 0; font-size: 1.5em; font-weight: 600; }
.status { display: flex; gap: 0.6em; align-items: center; }
.scroll { flex: 1 1 auto; min-height: 0; overflow-y: auto; padding-right: 0.6em; display: flex; flex-direction: column; gap: 0.5em; }
h2 { margin: 0.9em 0 0.2em; font-size: 1.05em; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; }
.opt { display: flex; justify-content: space-between; align-items: center; gap: 1.5em; padding: 0.8em 1em; border-radius: 0.6em; background: var(--panel); }
.opt-text { flex: 1 1 auto; min-width: 0; }
.opt-text p { margin: 0.25em 0 0; color: var(--muted); font-size: 0.9em; line-height: 1.35; }
.opt-control { flex: none; display: flex; align-items: center; gap: 0.5em; }
.num { min-width: 4.5em; text-align: center; font-variant-numeric: tabular-nums; }
.foot { margin: 0.6em 0; color: var(--muted); font-size: 0.9em; }

.btn {
  appearance: none; border: 0; border-radius: 0.5em; padding: 0.55em 1.1em; color: #fff; font: inherit; cursor: pointer;
  background: rgba(255, 255, 255, 0.12);
}
.btn:hover:not(:disabled) { background: rgba(255, 255, 255, 0.18); }
.btn:focus-visible, .switch:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.btn:disabled { opacity: 0.4; cursor: default; }
.btn.primary { background: var(--accent); }
.btn.danger { background: #c62828; }
.btn.step { min-width: 2.4em; padding: 0.45em 0.6em; font-size: 1.1em; }
.btn.choice.picked { background: var(--accent); }
.switch {
  appearance: none; border: 0; border-radius: 1em; min-width: 5em; padding: 0.5em 1.2em; color: #fff; font: inherit; cursor: pointer;
  background: rgba(255, 255, 255, 0.12);
}
.switch.on { background: var(--ok); color: #0b2012; font-weight: 600; }
</style>
