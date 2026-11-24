// Most Wanted Freeroam: the garage shop, the options page and the achievements page. Each is dormant until the Lua side says
// "<Name> visible" (mwf_core opens the shop in a garage during a chase, and the options / achievements pages when you press their key
// or the button you bound to them), and hides it again when you leave.
import { markRaw, h, withDirectives, computed, watch, onBeforeUnmount } from "vue"
import { useBridge } from "@/bridge"
import { addPopup } from "@/services/popup"
import { uniqueId } from "@/services/uniqueId"
import { useUINavBlocker } from "@/services/uiNavTracker"
import vBngScopedNav from "@/common/directives/BngScopedNav"
import MwfShop from "./MwfShop.vue"
import MwfOptions from "./MwfOptions.vue"
import MwfAchievements from "./MwfAchievements.vue"

// A popup base component. The stock popup host passes it popupActive and expects it to be a navigation scope, like the game's own
// popups (Confirmation.vue, Prompt.vue): the scope is what lets the controller move focus, press A and use B. Without it only the mouse
// and keyboard reach the page.
const makePopupBase = (name, view) =>
  markRaw({
    __name: name,
    position: "fullscreen",
    animated: false,
    props: { view: Object, popupActive: Boolean },
    emits: ["return"],
    setup(props, { emit }) {
      const scopeId = uniqueId("_mwfPage_" + name, "_")
      const binding = computed(() => ({
        scopeId,
        activated: props.popupActive,
        activateOnMount: props.popupActive,
        canDeactivate: () => false,
        preferAutoFocus: true,
        trapPolicy: "always",
      }))
      // while the page is the active popup the controller only navigates it (the same as the game's confirmation popups do)
      const navBlocker = useUINavBlocker()
      watch(() => props.popupActive, active => (active ? navBlocker.allowNavigationOnly() : navBlocker.clear()), { immediate: true })
      onBeforeUnmount(() => navBlocker.clear())
      return () =>
        withDirectives(h("div", { class: "mwf-scope" }, [h(view, { onClose: () => emit("return", true) })]), [[vBngScopedNav, binding.value]])
    },
  })

// one page: opens/closes on the Lua event, and tells Lua when the player closed it (Esc / B / its own Close button)
function makePage(event, view, luaClosed) {
  const Base = makePopupBase("Mwf" + event, view)
  let popup = null
  const notifyClosed = () => useBridge().api.engineLua(`if mwf_core then mwf_core.${luaClosed}() end`)
  const open = () => {
    if (popup) return
    const opened = addPopup(Base, { view: markRaw(view) })
    popup = opened
    const done = byUser => {
      if (popup !== opened) return
      popup = null
      if (byUser) notifyClosed()
    }
    opened.promise.then(() => done(true), () => done(true))
  }
  const close = () => {
    const closing = popup
    popup = null
    if (closing) closing.return(true)
  }
  const onEvent = payload => {
    const data = Array.isArray(payload) ? payload[0] : payload
    if (!data || typeof data !== "object") return
    if (data.visible) open()
    else close()
  }
  return { event, onEvent, close }
}

const pages = [
  makePage("MwfShop", MwfShop, "shopClose"),
  makePage("MwfOptions", MwfOptions, "optionsClose"),
  makePage("MwfAchievements", MwfAchievements, "achievementsClose"),
]
let events = null

export function onLoad() {
  events = useBridge().events
  for (const p of pages) events.on(p.event, p.onEvent)
}

export function onUnload() {
  if (events) for (const p of pages) events.off(p.event, p.onEvent)
  events = null
  for (const p of pages) p.close()
}
