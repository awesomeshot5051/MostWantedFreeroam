<!--
  Most Wanted Freeroam: Minimap.
  Based on the game's own Navigation app (BeamNG, ui/modules/apps/Navigation/app.vue): the same minimap, drawn the same way, plus a heat
  ring around it (ten segments that fill with your bounty, like the Most Wanted heat meter), the heat number with a flame, and a
  flashing red / blue ring while the police can see you (orange pulse while you are slipping away). Use it INSTEAD of the stock
  Navigation app, not next to it: both ask the game to draw the minimap into their own box.
  The heat data comes from mwf_core.getHeatHud() (lua/ge/extensions/mwf/ui/hud.lua).
-->
<template>
  <div
    v-show="showMinimap"
    ref="minimapContainerRef"
    class="minimap-container-wrapper"
    :class="{ ['police-' + (additionalInfo?.policeMode || 'disabled')]: minimapMode === 'rect', round: minimapMode === 'circle' }"
    @click="updateDrawTransform"
  >
    <div v-if="heat.active" class="heat-badge" :class="ringClass">
      <svg class="flame" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 12c2 -2.96 0 -7 -1 -8c0 3.038 -1.773 4.741 -3 6c-1.226 1.26 -2 3.24 -2 5a6 6 0 1 0 12 0c0 -1.532 -1.056 -3.94 -2 -5c-1.786 3 -2.791 3 -4 2z" />
      </svg>
      <span class="num" :key="heat.heat">{{ heat.heat }}x</span>
    </div>
    <template v-if="additionalInfo">
      <template v-if="minimapMode === 'rect'">
        <div class="minimap-container-additional-info top" v-if="hasTopInfo">
          <span v-if="additionalInfo.locationName">{{ additionalInfo.locationName }}</span>
          <!--
          <BngIcon class="minimap-container-additional-info-icon" type="mapWithEmitter" />
          -->
        </div>
        <div class="minimap-container" :class="{'round-bottom': !hasBottomInfo, 'round-top': !hasTopInfo}" ref="containerRef">
        </div>
        <div class="minimap-container-additional-info bottom" v-if="hasBottomInfo">
          <BngIcon v-if="additionalInfo.policeMode === 'visibleToPolice'" type="eyeSolidOpened" />
          <BngIcon v-if="additionalInfo.policeMode === 'hiddenFromPolice'" type="eyeSolidClosed" />
          <span v-if="additionalInfo.distToTarget">{{ additionalInfo.distToTarget }}</span>
          <BngIcon v-if="additionalInfo.distToTarget" class="" type="mapPoint" />
        </div>
      </template>
      <template v-else-if="minimapMode === 'circle'">
        <div class="minimap-container-additional-info top round" v-if="hasTopInfo" >
          <span v-if="additionalInfo.locationName">{{ additionalInfo.locationName }}</span>
        </div>
        <div class="minimap-container round" :class="{ ['police-' + additionalInfo.policeMode]: true }" ref="containerRef">
          <svg v-if="heat.active" class="heat-ring" :class="ringClass" viewBox="0 0 100 100" aria-hidden="true">
            <path v-for="seg in ringSegments" :key="'b' + seg.i" class="seg-bg" :d="seg.bg" />
            <path v-for="seg in ringSegments" :key="'f' + seg.i" v-show="seg.fill" class="seg-fill" :d="seg.fill" />
          </svg>
        </div>
        <div class="minimap-container-additional-info bottom round" v-if="hasBottomInfo">
          <BngIcon v-if="additionalInfo.policeMode === 'visibleToPolice'" type="eyeSolidOpened" />
          <BngIcon v-if="additionalInfo.policeMode === 'hiddenFromPolice'" type="eyeSolidClosed" />
          <span v-if="additionalInfo.distToTarget">{{ additionalInfo.distToTarget }}</span>
          <BngIcon v-if="additionalInfo.distToTarget" class="" type="mapPoint" />
        </div>
      </template>
    </template>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted, onUnmounted, inject, nextTick } from "vue"
import { useRoute } from "vue-router"
import { useBridge } from "@/bridge"
import { useEvents, useStreams } from "@/services/events"
import { useRouteDataStore } from "@/services/routeData"
import { popupsView } from "@/services/popup"
import { BngIcon } from "@/common/components/base"
// import { vBngOcclusionWatcher } from "@/common/directives"
import { loadingScreen } from "@/services/screenCover"
import logger from "@/services/logger"

const { lua, api } = useBridge()
const events = useEvents()
const route = useRoute()
const routeDataStore = useRouteDataStore()
const routeName = ref("unknown")

const uiVisible = ref(true)
const streamVisible = ref(true)
const initialising = ref(false)
const initialised = ref(false)
const minimapMode = ref("circle")
const minimapContainerRef = ref(null)
const containerRef = ref(null)
// const occlusionTop = ref(null)
// const occlusionBottom = ref(null)
const resizeObserver = ref(null)

const mapMetrics = reactive({
  x: 0,
  y: 0,
  width: 0,
  height: 0,
  xRel: 0,
  yRel: 0,
  widthRel: 0,
  heightRel: 0
})

const resolveRouteName = (data = null) => (
  data?.resolved?.name ||
  data?.request?.name ||
  data?.toRoute?.name ||
  routeDataStore.routeName ||
  route.name ||
  ""
)

const updateRoute = data => {
  routeName.value = resolveRouteName(data)
  queueDrawTransform()
}

events.on("ui_router_routeChange", updateRoute)
events.on("ui_router_routeRefresh", updateRoute)

watch([
  () => route.name,
  () => routeDataStore.routeName,
], () => {
  routeName.value = resolveRouteName()
  queueDrawTransform()
})

const allowedRoutes = ["play", ""]
const showMinimap = computed(() =>
  uiVisible.value && // if UI visible
  streamVisible.value && // if the minimap stream allows rendering
  !loadingScreen.shown && // if loading screen is not shown
  !popupsView.popups && // if no popups are visible
  !popupsView.activities && // if no activity screens are visible
  allowedRoutes.includes(routeName.value) // if current route is in allow-list above
)

// ----- Most Wanted Freeroam heat -----
const heat = reactive({ active: false, heat: 1, maxHeat: 10, progress: 0, pursued: false, cooling: false })
const ringClass = computed(() => ({ chased: heat.pursued, cooling: !heat.pursued && heat.cooling }))
let heatTimer = null
function pollHeat() {
  api.engineLua("mwf_core and mwf_core.getHeatHud and mwf_core.getHeatHud() or nil", data => {
    if (data && typeof data === "object" && data.active) Object.assign(heat, data)
    else heat.active = false
  })
}
onMounted(() => {
  pollHeat()
  heatTimer = setInterval(pollHeat, 250)
})
onUnmounted(() => clearInterval(heatTimer))

// ten segments around the circle, starting at the top and running clockwise; segment i fills as the bounty climbs through heat i + 1
const SEGMENTS = 10
const RING_R = 46
const polar = deg => [50 + RING_R * Math.cos((deg * Math.PI) / 180), 50 + RING_R * Math.sin((deg * Math.PI) / 180)]
const arc = (a0, a1) => {
  const [x0, y0] = polar(a0)
  const [x1, y1] = polar(a1)
  return `M${x0.toFixed(2)} ${y0.toFixed(2)} A${RING_R} ${RING_R} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}`
}
const ringSegments = computed(() => {
  const total = Math.max(0, Math.min(SEGMENTS, heat.heat - 1 + heat.progress)) // segments filled, as a fraction
  const span = 360 / SEGMENTS
  const gap = 5
  const out = []
  for (let i = 0; i < SEGMENTS; i++) {
    const a0 = -90 + i * span + gap / 2
    const a1 = a0 + span - gap
    const f = Math.max(0, Math.min(1, total + (heat.heat >= heat.maxHeat ? 1 : 0) - i)) // the top heat counts as full
    out.push({ i, bg: arc(a0, a1), fill: f > 0.01 ? arc(a0, a0 + (a1 - a0) * f) : "" })
  }
  return out
})

const toggleOptions = () => lua.test_imguiMinimap.toggleOptions()

const additionalInfo = reactive({
  distToTarget: null,
  locationName: null,
  policeMode: "disabled",
})


const hasTopInfo = computed(() => !!additionalInfo.locationName)
const hasBottomInfo = computed(() => !!(additionalInfo.distToTarget || additionalInfo.policeMode === "visibleToPolice" || additionalInfo.policeMode === "hiddenFromPolice"))

watch(hasTopInfo, () => showMinimap.value && queueDrawTransform())
watch(hasBottomInfo, () => showMinimap.value && queueDrawTransform())

const transformUpdateAttempts = 15
let transformUpdateAttempt = 0
const queuedDrawTransformAttempts = 8
let queuedDrawTransformToken = 0

const minimapSize = ref("100%")
const minimapShift = ref("0px")
const squareSize = ref("100%")

function queueDrawTransform(attempt = 0, token = null) {
  if (typeof attempt !== "number") attempt = 0
  if (token === null) {
    transformUpdateAttempt = 0
    token = ++queuedDrawTransformToken
  }
  requestAnimationFrame(async () => {
    if (token !== queuedDrawTransformToken) return
    await updateDrawTransform()
    if (token !== queuedDrawTransformToken || !showMinimap.value || attempt >= queuedDrawTransformAttempts) return
    setTimeout(() => queueDrawTransform(attempt + 1, token), 50)
  })
}

// Function to set screen space coordinates
async function updateDrawTransform() {
  if (minimapMode.value === "circle" && minimapContainerRef.value) {
    const rect = minimapContainerRef.value.getBoundingClientRect()
    const size = Math.min(rect.width, rect.height)
    const sizepx = size + "px"
    if (minimapSize.value !== sizepx) {
      minimapSize.value = sizepx
      if (rect.width > rect.height) {
        minimapShift.value = -(rect.width - size) / 2 + "px"
      } else {
        minimapShift.value = "0px"
      }
      await nextTick()
    }
  }

  // we do this check here to update visuals without waiting for lua to load
  if (!initialised.value || !showMinimap.value || !containerRef.value) return

  const screen = {
    width: window.innerWidth,
    height: window.innerHeight,
    scrollX: window.scrollX,
    scrollY: window.scrollY,
  }
  const rect = containerRef.value.getBoundingClientRect()

  // Add scroll offsets to get absolute screen coordinates
  mapMetrics.x = rect.left + screen.scrollX
  mapMetrics.y = rect.top + screen.scrollY
  mapMetrics.width = rect.width
  mapMetrics.height = rect.height

  // Calculate percentages
  mapMetrics.xRel = mapMetrics.x / screen.width
  mapMetrics.yRel = mapMetrics.y / screen.height
  mapMetrics.widthRel = mapMetrics.width / screen.width
  mapMetrics.heightRel = mapMetrics.height / screen.height

  // logger.debug("Screen metrics:", {
  //   absolute: { x: mapMetrics.x, y: mapMetrics.y, width: mapMetrics.width, height: mapMetrics.height },
  //   relative: { x: mapMetrics.xRel, y: mapMetrics.yRel, width: mapMetrics.widthRel, height: mapMetrics.heightRel }
  // })

  // check for allowed metrics
  const keys = ["xRel", "yRel", "widthRel", "heightRel"]
  if (keys.some(key => mapMetrics[key] < 0 || mapMetrics[key] > 1) || keys.every(key => mapMetrics[key] === 0)) {
    transformUpdateAttempt++
    if (transformUpdateAttempt < transformUpdateAttempts) {
      requestAnimationFrame(updateDrawTransform)
    } else {
      logger.warn(`Failed to update minimap draw transform after ${transformUpdateAttempts} frames`)
    }
    return
  }

  transformUpdateAttempt = 0
  sendTransformToLua(true)
}

async function sendTransformToLua(show = true) {
  if (!await initMinimap()) return
  if (!showMinimap.value || !show) { // force hide in case of race condition
    lua.ui_apps_minimap_minimap.hide()
    return
  }
  // this must go first
  lua.ui_apps_minimap_minimap.setDrawTransform(mapMetrics.xRel, mapMetrics.yRel, mapMetrics.widthRel, mapMetrics.heightRel)
  // then we request the info
  minimapMode.value = await lua.ui_apps_minimap_minimap.getMode()
  lua.ui_apps_minimap_additionalInfo.requestAdditionalInfo()
}

async function initMinimap() {
  if (initialising.value) return false // helps against simultaneous calls
  if (!initialised.value) {
    initialising.value = true
    await Promise.all([
      lua.extensions.load("ui_apps_minimap_minimap"),
      lua.extensions.load("ui_apps_minimap_additionalInfo"),
    ])
    minimapMode.value = await lua.ui_apps_minimap_minimap.getMode()
    initialised.value = true
    initialising.value = false
  }
  return true
}

watch(showMinimap, val => {
  if (val) {
    queueDrawTransform()
  } else if (initialised.value) {
    queuedDrawTransformToken++
    sendTransformToLua(false)
  }
})

watch([initialised, containerRef], () => {
  queueDrawTransform()

  // Set up ResizeObserver when containerRef becomes available
  if (containerRef.value && !resizeObserver.value) {
    resizeObserver.value = new ResizeObserver(() => {
      queueDrawTransform()
    })
    resizeObserver.value.observe(containerRef.value)
  }
}, { immediate: true })

onMounted(() => {
  window.addEventListener("scroll", queueDrawTransform)
  window.addEventListener("resize", queueDrawTransform)
  events.on("onCefVisibilityChanged", visible => {
    // console.log("onCefVisibilityChanged", visible)
    uiVisible.value = visible
    nextTick(queueDrawTransform)
  })
  routeName.value = resolveRouteName()
  initMinimap().then(() => queueDrawTransform())
})

onUnmounted(() => {
  const wasInitialised = initialised.value
  initialised.value = false
  queuedDrawTransformToken++

  //logger.debug("Unmounting MinimapVueSDF")
  window.removeEventListener("scroll", queueDrawTransform)
  window.removeEventListener("resize", queueDrawTransform)

  if (resizeObserver.value) {
    resizeObserver.value.disconnect()
    resizeObserver.value = null
  }

  if (wasInitialised) sendTransformToLua(false)
})

useStreams(["minimap"], (streams) => {
  if(!streams.minimap) return

  streamVisible.value = streams.minimap.visible !== false
  additionalInfo.distToTarget = streams.minimap.distToTarget
  additionalInfo.locationName = streams.minimap.locationName
  additionalInfo.policeMode = streams.minimap.policeMode

})
</script>

<style scoped lang="scss">
.minimap-container-wrapper {
  width: 100%;
  height: 100%;
  color: white;
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;

  // For rect mode, constrain the content to square dimensions
  &:not(.round) {
    max-width: v-bind(squareSize);
    max-height: v-bind(squareSize);
    width: v-bind(squareSize);
    height: v-bind(squareSize);
  }
}

.minimap-container {
  box-shadow: inset 0 0 10px 2px rgba(0, 0, 0, 0.55);
  background-color: rgba(0, 0, 0, 0.55); // Semi-transparent black background

  width: 100%;
  flex: 1 1 auto;
  position: relative;

  &.round {
    border-radius: 50%;
    width: auto;
    height: auto;
    max-width: calc(v-bind(minimapSize) - 1rem);
    max-height: calc(v-bind(minimapSize) - 1rem);
    aspect-ratio: 1 / 1;
  }

  &.round-bottom {
    border-radius: 0 0 0.5rem 0.5rem;
  }
  &.round-top {
    border-radius: 0.5rem 0.5rem 0 0;
  }
  display: flex;
}



.minimap-container-additional-info {
  flex: 0 0 auto;
  background-color: rgba(0, 0, 0, 0.69);
  padding-left: 0.75rem;
  padding-right: 0.75rem;
  text-align: center;
  font-weight: 500;
  z-index: 1;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;

  &.invisible {
    opacity: 0.0;
  }

  &.top {
    border-top: none;
    border-radius: 0.5rem 0.5rem 0 0;
    padding-top: 0.25rem;
    padding-bottom: 0.25rem;
  }
  &.bottom {
    border-radius: 0 0 0.5rem 0.5rem;
    border-bottom: none;
    padding-bottom: 0.5rem;
  }
  &.round {
    background-color: rgba(0, 0, 0, 0.6);
    padding: 0.25rem 0.5rem;
    border-radius: 0.25rem;
    width: fit-content;
    box-shadow: inset 0 0 10px 2px rgba(0, 0, 0, 0.55);

    &.top {
      margin-bottom: 0.1rem;
    }
    &.bottom {
      margin-top: 0.1rem;
    }
  }

}
.minimap-container-additional-info-icon {
  position: absolute;
  top: 0.25rem;
  right: 0.25rem;
  color: white;
  cursor: pointer;
  opacity: 0.33;
  &:hover {
    opacity: 1;
  }
}


.police-visibleToPolice {
  animation: colorCycle 0.7s  infinite alternate ease-in-out;
}

@keyframes colorCycle {
  0% {
    box-shadow: inset 0 0 10px 5px rgba(255, 16, 16, 1);
    background-color: rgba(25, 0, 0, 0.55);
  }
  100% {
    box-shadow: inset 0 0 10px 5px rgba(16, 16, 255, 1);
    background-color: rgba(0, 0, 25, 0.55);
  }
}

.police-hiddenFromPolice {
  animation: colorCycleWeak 1.4s  infinite alternate ease-in-out;
}

@keyframes colorCycleWeak {
  0% {
    box-shadow: inset 0 0 7px 2px rgba(128, 16, 16, 1);
    background-color: rgba(5, 0, 0, 0.55);
  }
  100% {
    box-shadow: inset 0 0 7px 2px rgba(16, 16, 128, 1);
    background-color: rgba(0, 0, 5, 0.55);
  }
}

// ----- Most Wanted Freeroam heat ring and badge -----
.heat-ring {
  position: absolute;
  inset: -0.5rem;
  width: calc(100% + 1rem);
  height: calc(100% + 1rem);
  overflow: visible;
  pointer-events: none;
  z-index: 2;

  .seg-bg, .seg-fill {
    fill: none;
    stroke-linecap: round;
  }
  .seg-bg { stroke: rgba(255, 255, 255, 0.18); stroke-width: 3.2; }
  .seg-fill { stroke: #ff6a1a; stroke-width: 3.2; filter: drop-shadow(0 0 2px rgba(255, 106, 26, 0.9)); }

  // the police can see you: the whole ring flashes red / blue like a light bar
  &.chased .seg-fill, &.chased .seg-bg { animation: heatChased 0.45s infinite alternate ease-in-out; }
  // slipping away (the escape meter is winning): a slow orange pulse
  &.cooling .seg-fill { animation: heatCooling 1.2s infinite alternate ease-in-out; }
}

.heat-badge {
  position: absolute;
  top: 0.2rem;
  left: 0.2rem;
  z-index: 3;
  display: flex;
  align-items: center;
  gap: 0.15rem;
  padding: 0.1rem 0.45rem 0.1rem 0.3rem;
  border-radius: 0.9rem;
  background: rgba(0, 0, 0, 0.65);
  font-weight: 700;
  font-size: 1.1rem;
  pointer-events: none;

  .flame { width: 1.2rem; height: 1.2rem; fill: none; stroke: #ff6a1a; stroke-width: 2; stroke-linecap: round; stroke-linejoin: round; }
  .num { animation: heatPop 0.5s ease-out; }
  &.chased .flame { animation: heatFlame 0.45s infinite alternate ease-in-out; }
  &.cooling .flame { animation: heatCooling 1.2s infinite alternate ease-in-out; }
}

@keyframes heatChased {
  0% { stroke: #ff2020; filter: drop-shadow(0 0 3px #ff2020); }
  100% { stroke: #2a4dff; filter: drop-shadow(0 0 3px #2a4dff); }
}
@keyframes heatCooling {
  0% { opacity: 0.55; }
  100% { opacity: 1; }
}
@keyframes heatFlame {
  0% { stroke: #ff2020; }
  100% { stroke: #2a4dff; }
}
@keyframes heatPop {
  0% { transform: scale(1.7); }
  100% { transform: scale(1); }
}
</style>