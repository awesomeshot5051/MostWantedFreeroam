<!--
  Most Wanted Freeroam garage shop. Laid out like the RLS computer: a hub, a vehicle shop (search / brand / sort, listing rows with
  key specs, a detail page) and a parts shop (categories > slots > parts, with a cart on the right). Everything is bought at the
  listed price, there is no negotiating. All data comes from mwf_core (lua/ge/extensions/mwf/ui/garage_window.lua).
-->
<template>
  <div class="mwf-shop" role="dialog" aria-label="Garage" v-bng-on-ui-nav:back="back" @keydown.esc.stop="back">
    <header class="top">
      <div class="crumbs">
        <button bng-nav-item v-if="screen !== 'hub'" type="button" class="btn quiet" @click="back">&larr; Back</button>
        <h1>{{ title }}</h1>
      </div>
      <div class="status">
        <span class="pill pause">CHASE PAUSED</span>
        <span class="wallet" title="Your bounty wallet">Wallet <b>{{ money(wallet) }}</b></span>
        <button bng-nav-item type="button" class="btn" @click="leave">Leave garage</button>
      </div>
    </header>

    <p v-if="notice" class="notice" :class="{ bad: !noticeOk }">{{ notice }}</p>

    <!-- ===== hub ===== -->
    <main v-if="screen === 'hub'" class="hub">
      <button bng-nav-item type="button" class="tile" bng-scoped-nav-autofocus="true" v-bng-ui-nav-focus="1000" @click="openCars">
        <span class="tile-title">Vehicle Shop</span>
        <span class="tile-sub">Swap into any car at {{ factor }}% of its value. Pay the listed price, no haggling.</span>
        <span class="tile-foot">Browse vehicles &rarr;</span>
      </button>
      <button bng-nav-item type="button" class="tile" @click="openParts">
        <span class="tile-title">Parts Shop</span>
        <span class="tile-sub">Upgrade {{ vehicleName || "your car" }} part by part. Add parts to the cart, then buy them together.</span>
        <span class="tile-foot">Browse parts &rarr;</span>
      </button>
      <button bng-nav-item type="button" class="tile" @click="openTuning">
        <span class="tile-title">Tuning</span>
        <span class="tile-sub">Tune {{ vehicleName || "your car" }}: suspension, tyres, gearing, boost and more. Free. Save tunes per car.</span>
        <span class="tile-foot">Open tuning &rarr;</span>
      </button>
      <p class="hint">Heat follows what you earned, so spending bounty never cools you down.</p>
    </main>

    <!-- ===== vehicle shop: listing ===== -->
    <main v-else-if="screen === 'cars'" class="cars">
      <div class="toolbar">
        <BngInput class="mwf-search" v-model="search" placeholder="Search for a vehicle" />
        <!-- the game's own dropdown: a native <select> opens its list in a separate OS window, which the game's UI never shows -->
        <BngDropdown v-model="brandPick" class="select" :items="brandItems" show-search />
        <BngDropdown v-model="sort" class="select" :items="sortItems" />
        <label class="check"><input v-model="affordable" type="checkbox" /> Affordable only</label>
      </div>
      <div class="pager">
        <p class="count">{{ carTotal }} vehicle{{ carTotal === 1 ? "" : "s" }}<template v-if="carTotal"> &middot; showing {{ pageFrom }}&ndash;{{ pageTo }}</template></p>
        <div v-if="pageCount > 1" class="pager-btns">
          <button bng-nav-item type="button" class="btn" :disabled="page <= 0" @click="goPage(0)">&laquo;</button>
          <button bng-nav-item type="button" class="btn" :disabled="page <= 0" @click="goPage(page - 1)">&lsaquo; Prev</button>
          <span class="pager-info">Page {{ page + 1 }} / {{ pageCount }}</span>
          <button bng-nav-item type="button" class="btn" :disabled="page >= pageCount - 1" @click="goPage(page + 1)">Next &rsaquo;</button>
          <button bng-nav-item type="button" class="btn" :disabled="page >= pageCount - 1" @click="goPage(pageCount - 1)">&raquo;</button>
        </div>
      </div>

      <div class="scroll">
        <p v-if="!cars.length && !loading" class="empty">No vehicles match. Try clearing the filters{{ affordable ? " or turning off Affordable only" : "" }}.</p>
        <article v-for="(c, i) in cars" :key="c.model + c.key" class="card" bng-nav-item tabindex="0" :bng-scoped-nav-autofocus="i === 0 ? 'true' : null" v-bng-ui-nav-focus="i === 0 ? 1000 : undefined" @click="openCar(c)" @keydown.enter="openCar(c)">
          <div class="photo">
            <img v-if="c.preview && !broken[c.model + c.key]" :src="c.preview" alt="" loading="lazy" @error="broken[c.model + c.key] = true" />
            <span v-else class="nophoto">No photo</span>
          </div>
          <div class="body">
            <div class="head">
              <div>
                <h3>{{ c.year ? c.year + " " : "" }}{{ c.name }}</h3>
                <div class="brand">{{ c.brand }}</div>
              </div>
              <div class="price" :class="{ bad: !c.afford }">{{ money(c.price) }}
                <span v-if="!c.afford" class="flag">Not enough bounty</span>
              </div>
            </div>
            <dl class="specs">
              <div v-for="s in specsOf(c)" :key="s.k" class="spec"><dt>{{ s.k }}</dt><dd>{{ s.v }}</dd></div>
            </dl>
          </div>
        </article>
        <div v-if="pageCount > 1" class="more pager-btns">
          <button bng-nav-item type="button" class="btn" :disabled="page <= 0" @click="goPage(page - 1)">&lsaquo; Prev</button>
          <span class="pager-info">Page {{ page + 1 }} / {{ pageCount }}</span>
          <button bng-nav-item type="button" class="btn" :disabled="page >= pageCount - 1" @click="goPage(page + 1)">Next &rsaquo;</button>
        </div>
      </div>
    </main>

    <!-- ===== vehicle shop: detail ===== -->
    <main v-else-if="screen === 'car' && car" class="detail">
      <div class="big-photo">
        <img v-if="car.preview && !broken[car.model + car.key]" :src="car.preview" alt="" @error="broken[car.model + car.key] = true" />
        <span v-else class="nophoto">No photo</span>
      </div>
      <section class="info">
        <h2>{{ car.year ? car.year + " " : "" }}{{ car.name }}</h2>
        <div class="brand">{{ car.brand }}</div>
        <dl class="specs grid">
          <div v-for="s in specsOf(car, true)" :key="s.k" class="spec"><dt>{{ s.k }}</dt><dd>{{ s.v }}</dd></div>
        </dl>
        <div class="receipt">
          <div class="row"><span>Listed price</span><b class="gold">{{ money(car.price) }}</b></div>
          <div class="row"><span>Your wallet</span><span>{{ money(wallet) }}</span></div>
          <div class="row total"><span>Wallet after purchase</span><b :class="{ badtxt: wallet < car.price }">{{ money(wallet - car.price) }}</b></div>
        </div>
        <p class="hint">Your current car is swapped for this one. Heat follows what you earned, not what you spend.</p>
        <div class="actions">
          <button bng-nav-item v-if="!confirming" type="button" class="btn primary big" bng-scoped-nav-autofocus="true" v-bng-ui-nav-focus="1000" :disabled="wallet < car.price || busy" @click="confirming = true">
            {{ wallet < car.price ? "Not enough bounty" : "Buy for " + money(car.price) }}
          </button>
          <template v-else>
            <button bng-nav-item type="button" class="btn primary big" bng-scoped-nav-autofocus="true" v-bng-ui-nav-focus="1000" :disabled="busy" @click="buyCar">Confirm purchase</button>
            <button bng-nav-item type="button" class="btn quiet" @click="confirming = false">Cancel</button>
          </template>
        </div>
      </section>
    </main>

    <!-- ===== tuning ===== -->
    <main v-else-if="screen === 'tuning'" class="parts tuning">
      <section class="panel">
        <nav class="path">
          <button bng-nav-item type="button" class="link" :class="{ here: !tCat }" @click="tCat = null">Categories</button>
          <template v-if="tCat"><span>/</span><span class="link here">{{ tCat.name }}</span></template>
        </nav>

        <BngInput v-if="!tuneError" class="mwf-search" v-model="tuneSearch" placeholder="Search all settings (e.g. camber, boost, gear)" />

        <p v-if="tuneError" class="empty">{{ tuneError }}</p>
        <p v-else-if="loading" class="empty">Loading...</p>

        <div v-else-if="!tCat && !tuneSearch.trim()" class="scroll">
          <p v-if="!tuneCats.length" class="empty">This car has nothing to tune.</p>
          <button bng-nav-item v-for="(cat, i) in tuneCats" :key="cat.name" type="button" class="row-btn" :bng-scoped-nav-autofocus="i === 0 ? 'true' : null" v-bng-ui-nav-focus="i === 0 ? 1000 : undefined" @click="tCat = cat">
            <span class="rb-name">{{ cat.name }}</span>
            <span class="rb-sub">{{ catCount(cat) }} setting{{ catCount(cat) === 1 ? "" : "s" }}</span>
            <span class="rb-tag" v-if="catEdited(cat)">{{ catEdited(cat) }} changed</span>
            <span class="rb-go">&rsaquo;</span>
          </button>
        </div>

        <div v-else class="scroll">
          <template v-for="grp in shownTuneGroups" :key="grp.name">
            <h4 class="sub-head">{{ grp.name }}</h4>
            <article v-for="v in grp.vars" :key="v.name" class="tvar" :class="{ changed: isEdited(v) }">
              <div class="tvar-text">
                <b>{{ v.title }}</b>
                <span v-if="v.desc" class="tvar-desc">{{ v.desc }}</span>
              </div>
              <div class="tvar-ctl">
                <button bng-nav-item type="button" class="btn step" :disabled="valueOf(v) <= v.minDis" @click="nudgeVar(v, -1)">&minus;</button>
                <input class="range" type="range" :min="v.minDis" :max="v.maxDis" :step="v.stepDis" :value="valueOf(v)" @input="setVar(v, Number($event.target.value))" />
                <button bng-nav-item type="button" class="btn step" :disabled="valueOf(v) >= v.maxDis" @click="nudgeVar(v, 1)">+</button>
                <span class="tvar-val">{{ valueOf(v).toFixed(v.decimals) }} {{ v.unit }}</span>
                <button bng-nav-item type="button" class="btn quiet step" title="Back to the car's default" :disabled="valueOf(v) === v.defDis" @click="setVar(v, v.defDis)">&#8634;</button>
              </div>
            </article>
          </template>
          <p v-if="!shownTuneGroups.length" class="empty">No setting matches "{{ tuneSearch }}".</p>
        </div>
      </section>

      <aside class="cart panel">
        <h3>Tune</h3>
        <p class="empty small">{{ editCount ? editCount + " change" + (editCount === 1 ? "" : "s") + " not applied yet." : "Change a setting, then press Apply. The car is rebuilt with the new tune." }}</p>
        <button bng-nav-item type="button" class="btn primary big" :disabled="!editCount || busy" @click="applyTune">Apply tune</button>
        <button bng-nav-item type="button" class="btn quiet" :disabled="!editCount" @click="clearEdits">Undo changes</button>
        <button bng-nav-item type="button" class="btn quiet" :disabled="busy" @click="tuneDefaults">Reset to the car's defaults</button>

        <h3>Saved tunes</h3>
        <BngInput class="mwf-search" v-model="tuneName" placeholder="Name for this tune" />
        <button bng-nav-item type="button" class="btn" :disabled="!tuneName.trim() || busy" @click="saveTune">Save current settings</button>
        <p v-if="!tunes.length" class="empty small">No saved tunes for this car.</p>
        <ul v-else class="cart-list">
          <li v-for="t in tunes" :key="t.id">
            <div class="ci-text"><b>{{ t.name }}</b><span>{{ t.count }} setting{{ t.count === 1 ? "" : "s" }}</span></div>
            <button bng-nav-item type="button" class="btn" @click="loadTune(t)">Load</button>
            <button bng-nav-item type="button" class="x" title="Delete" @click="deleteTune(t)">&times;</button>
          </li>
        </ul>
      </aside>
    </main>

    <!-- ===== parts shop ===== -->
    <main v-else-if="screen === 'parts'" class="parts">
      <section class="panel">
        <nav class="path">
          <button bng-nav-item type="button" class="link" :class="{ here: !category }" @click="category = null; curSlot = null">Categories</button>
          <template v-if="category"><span>/</span><button bng-nav-item type="button" class="link" :class="{ here: !curSlot }" @click="curSlot = null">{{ category.name }}</button></template>
          <template v-if="curSlot"><span>/</span><span class="link here">{{ curSlot.name }}</span></template>
        </nav>

        <BngInput v-if="!partsError" class="mwf-search" v-model="partSearch" :placeholder="partSearchHint" />

        <p v-if="partsError" class="empty">{{ partsError }}</p>

        <!-- typing at the top level searches every slot of every category at once -->
        <div v-else-if="!category && partSearch.trim()" class="scroll">
          <p v-if="!searchedSlots.length" class="empty">No slot matches "{{ partSearch }}".</p>
          <button bng-nav-item v-for="(s, i) in searchedSlots" :key="s.path" type="button" class="row-btn" @click="openFound(s)">
            <span class="rb-name">{{ s.name }}</span>
            <span class="rb-sub">{{ s.categoryName }} - installed: {{ s.installed }}</span>
            <span class="rb-tag" v-if="inCart[s.path]">In cart</span>
            <span class="rb-count">{{ s.count }} option{{ s.count === 1 ? "" : "s" }}</span>
            <span class="rb-go">&rsaquo;</span>
          </button>
        </div>

        <div v-else-if="!category" class="scroll">
          <p v-if="!categories.length && !loading" class="empty">Nothing to buy for this car.</p>
          <button bng-nav-item v-for="(cat, i) in categories" :key="cat.name" type="button" class="row-btn" :bng-scoped-nav-autofocus="i === 0 ? 'true' : null" v-bng-ui-nav-focus="i === 0 ? 1000 : undefined" @click="category = cat">
            <span class="rb-name">{{ cat.name }}</span>
            <span class="rb-sub">{{ cat.slots.length }} slot{{ cat.slots.length === 1 ? "" : "s" }} with upgrades</span>
            <span class="rb-go">&rsaquo;</span>
          </button>
        </div>

        <div v-else-if="!curSlot" class="scroll">
          <p v-if="!shownSlots.length" class="empty">No slot matches "{{ partSearch }}".</p>
          <button bng-nav-item v-for="(s, i) in shownSlots" :key="s.path" type="button" class="row-btn" :bng-scoped-nav-autofocus="i === 0 ? 'true' : null" v-bng-ui-nav-focus="i === 0 ? 1000 : undefined" @click="openSlot(s)">
            <span class="rb-name">{{ s.name }}</span>
            <span class="rb-sub">Installed: {{ s.installed }}</span>
            <span class="rb-tag" v-if="inCart[s.path]">In cart</span>
            <span class="rb-count">{{ s.count }} option{{ s.count === 1 ? "" : "s" }}</span>
            <span class="rb-go">&rsaquo;</span>
          </button>
        </div>

        <div v-else class="scroll">
          <p v-if="loading" class="empty">Loading...</p>
          <p v-if="!loading && !shownParts.length" class="empty">No part matches "{{ partSearch }}".</p>
          <article v-for="p in shownParts" :key="p.name" class="part" :class="{ picked: cartPart(curSlot.path) === p.name }">
            <div class="part-name">
              <b>{{ p.label }}</b>
              <span v-if="p.installed" class="tag">Installed</span>
              <span v-else-if="p.owned" class="tag">Owned</span>
            </div>
            <div class="part-price" :class="{ bad: !p.installed && !p.owned && p.price > wallet }">{{ p.installed ? "—" : p.owned ? "Owned" : money(p.price) }}</div>
            <!-- one button for add / remove, so it is never destroyed and re-created (and focus never jumps) when the cart changes -->
            <button
              bng-nav-item
              type="button"
              class="btn"
              :class="p.installed ? 'quiet' : cartPart(curSlot.path) === p.name ? '' : 'primary'"
              :disabled="p.installed"
              :bng-scoped-nav-autofocus="p === shownParts[0] ? 'true' : null" v-bng-ui-nav-focus="p === shownParts[0] ? 1000 : undefined"
              @click.stop.prevent="toggleCart(p)"
            >{{ p.installed ? "Installed" : cartPart(curSlot.path) === p.name ? "Remove" : "Add to cart" }}</button>
          </article>
        </div>
      </section>

      <aside class="cart panel">
        <h3>Cart</h3>
        <p v-if="!cartItems.length" class="empty small">Pick a part and add it to the cart.</p>
        <ul v-else class="cart-list">
          <li v-for="it in cartItems" :key="it.path">
            <div class="ci-text"><b>{{ it.partLabel }}</b><span>{{ it.slotName }}</span></div>
            <div class="ci-price">{{ money(it.price) }}</div>
            <button bng-nav-item type="button" class="x" title="Remove" @click="removeFromCart(it.path)">&times;</button>
          </li>
        </ul>
        <div class="receipt">
          <div class="row"><span>Total</span><b class="gold">{{ money(cartTotal) }}</b></div>
          <div class="row"><span>Your wallet</span><span>{{ money(wallet) }}</span></div>
          <div class="row total"><span>Wallet after</span><b :class="{ badtxt: wallet < cartTotal }">{{ money(wallet - cartTotal) }}</b></div>
        </div>
        <button bng-nav-item type="button" class="btn primary big" :disabled="!cartItems.length || wallet < cartTotal || busy" @click="confirmParts = true">
          {{ wallet < cartTotal ? "Not enough bounty" : cartTotal === 0 ? "Install parts" : "Buy parts" }}
        </button>
        <button bng-nav-item type="button" class="btn quiet" :disabled="!cartItems.length" @click="clearCart">Clear cart</button>
      </aside>

      <!-- confirm screen: nothing is bought until Confirm is pressed -->
      <div v-if="confirmParts" class="modal" role="alertdialog" aria-label="Confirm purchase">
        <div class="modal-box">
          <h3>{{ cartTotal === 0 ? "Confirm install" : "Confirm purchase" }}</h3>
          <ul class="cart-list">
            <li v-for="it in cartItems" :key="it.path">
              <div class="ci-text"><b>{{ it.partLabel }}</b><span>{{ it.slotName }}</span></div>
              <div class="ci-price">{{ money(it.price) }}</div>
            </li>
          </ul>
          <div class="receipt">
            <div class="row"><span>Total</span><b class="gold">{{ money(cartTotal) }}</b></div>
            <div class="row"><span>Your wallet</span><span>{{ money(wallet) }}</span></div>
            <div class="row total"><span>Wallet after</span><b :class="{ badtxt: wallet < cartTotal }">{{ money(wallet - cartTotal) }}</b></div>
          </div>
          <div class="actions">
            <button bng-nav-item type="button" class="btn primary big" :disabled="busy || wallet < cartTotal" @click="buyParts">{{ cartTotal === 0 ? "Confirm install" : "Confirm purchase" }}</button>
            <button bng-nav-item type="button" class="btn quiet big" bng-scoped-nav-autofocus="true" v-bng-ui-nav-focus="1000" @click="confirmParts = false">Cancel</button>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount, watch } from "vue"
import { useBridge } from "@/bridge"
// a priority element: when the controller takes over again after the mouse was used, the game focuses this one
import vBngUiNavFocus from "@/common/directives/BngUiNavFocus"
import { BngDropdown, BngInput } from "@/common/components/base"
// controller: the game's "back" button (B / circle) steps back through the shop like Esc does
import vBngOnUiNav from "@/common/directives/BngOnUiNav"

const emit = defineEmits(["close"])
const bridge = useBridge()

// ----- Lua calls: mwf_core.<fn>(args) -> promise of the returned table -----
function callLua(fn, ...args) {
  const api = bridge.api
  const code = `mwf_core.${fn}(${args.map(a => api.serializeToLua(a)).join(",")})`
  return new Promise(resolve => api.engineLua(code, resolve))
}
const listOf = v => (Array.isArray(v) ? v : v && typeof v === "object" ? Object.values(v) : [])

// ----- state -----
const screen = ref("hub") // hub | cars | car | parts
const wallet = ref(0)
const factor = ref(50)
const brands = ref([])
const vehicleName = ref("")
const notice = ref("")
const noticeOk = ref(true)
const loading = ref(false)
const busy = ref(false)
let noticeTimer = null

const money = n => "$" + Math.round(Number(n) || 0).toLocaleString("en-US")
function say(text, ok = true) {
  notice.value = text
  noticeOk.value = ok
  clearTimeout(noticeTimer)
  noticeTimer = setTimeout(() => (notice.value = ""), 5000)
}

// cars
const search = ref("")
const brand = ref("")
const sort = ref("priceDesc")
const affordable = ref(false) // off: every car is listed, the ones you cannot afford are flagged
const ALL_BRANDS = "__all__"
const brandPick = computed({
  get: () => brand.value || ALL_BRANDS,
  set: v => { brand.value = v === ALL_BRANDS ? "" : v },
})
const brandItems = computed(() => [{ label: "All brands", value: ALL_BRANDS }, ...(carBrands.value.length ? carBrands.value : brands.value).map(b => ({ label: b, value: b }))])
const sortItems = [
  { label: "Price: high to low", value: "priceDesc" },
  { label: "Price: low to high", value: "priceAsc" },
  { label: "Power", value: "power" },
  { label: "Name", value: "name" },
]
const car = ref(null)
const confirming = ref(false)
const broken = reactive({})

// parts
const categories = ref([])
const category = ref(null)
const curSlot = ref(null)
const slotParts = ref([])
const partsError = ref("")
const cart = reactive({}) // slot path -> {path, part, partLabel, slotName, price}
const partSearch = ref("")
const confirmParts = ref(false)

// tuning
const tuneCats = ref([])
const tCat = ref(null)
const tuneError = ref("")
const tuneSearch = ref("")
const tuneName = ref("")
const tunes = ref([])
const edits = reactive({}) // variable name -> display value not applied yet
const valueOf = v => (edits[v.name] !== undefined ? edits[v.name] : v.valDis)
const isEdited = v => edits[v.name] !== undefined
const editCount = computed(() => Object.keys(edits).length)
const catCount = cat => cat.subs.reduce((n, sc) => n + sc.vars.length, 0)
const catEdited = cat => cat.subs.reduce((n, sc) => n + sc.vars.filter(isEdited).length, 0)
const shownTuneGroups = computed(() => {
  const q = tuneSearch.value.trim().toLowerCase()
  const cats = q ? tuneCats.value : tCat.value ? [tCat.value] : []
  const out = []
  for (const cat of cats) {
    for (const sc of cat.subs) {
      const vars = q ? sc.vars.filter(v => `${v.title} ${v.desc} ${v.name} ${sc.name} ${cat.name}`.toLowerCase().includes(q)) : sc.vars
      if (vars.length) out.push({ name: q ? `${cat.name} / ${sc.name}` : sc.name, vars })
    }
  }
  return out
})
function setVar(v, dis) {
  const step = v.stepDis || 1
  let d = Math.max(v.minDis, Math.min(v.maxDis, Math.round((dis - v.minDis) / step) * step + v.minDis))
  d = Number(d.toFixed(v.decimals))
  if (d === v.valDis) delete edits[v.name]
  else edits[v.name] = d
}
const nudgeVar = (v, dir) => setVar(v, valueOf(v) + dir * (v.stepDis || 1))
function clearEdits() {
  for (const k of Object.keys(edits)) delete edits[k]
}
const everyVar = () => tuneCats.value.flatMap(c => c.subs.flatMap(sc => sc.vars))
async function loadTuning() {
  loading.value = true
  tuneError.value = ""
  const res = await callLua("shopTuning")
  loading.value = false
  if (!res) return (tuneError.value = "The garage did not answer.")
  if (res.error) tuneError.value = res.error
  if (res.vehicle) vehicleName.value = res.vehicle
  tuneCats.value = listOf(res.categories).map(c => ({ ...c, subs: listOf(c.subs).map(sc => ({ ...sc, vars: listOf(sc.vars) })) }))
  if (tCat.value) tCat.value = tuneCats.value.find(c => c.name === tCat.value.name) || null
}
async function loadTunes() {
  const res = await callLua("shopTunes")
  tunes.value = listOf(res && res.tunes)
}
async function openTuning() {
  screen.value = "tuning"
  tCat.value = null
  tuneSearch.value = ""
  clearEdits()
  await Promise.all([loadTuning(), loadTunes()])
}
async function applyTune() {
  if (busy.value || !editCount.value) return
  busy.value = true
  const res = await callLua("shopTuneApply", Object.entries(edits).map(([name, v]) => ({ name, v })))
  busy.value = false
  if (!res) return say("The garage did not answer.", false)
  say(res.msg || (res.ok ? "Tune applied." : "Could not apply the tune."), !!res.ok)
  if (res.ok) {
    clearEdits()
    setTimeout(loadTuning, 800) // the car is rebuilt: read the settings again once it has settled
  }
}
async function tuneDefaults() {
  if (busy.value) return
  busy.value = true
  const res = await callLua("shopTuneDefaults")
  busy.value = false
  if (!res) return say("The garage did not answer.", false)
  say(res.msg || "Done.", !!res.ok)
  if (res.ok) {
    clearEdits()
    setTimeout(loadTuning, 800)
  }
}
async function saveTune() {
  const name = tuneName.value.trim()
  if (!name || busy.value) return
  busy.value = true
  const res = await callLua("shopSaveTune", name, everyVar().map(v => ({ name: v.name, v: valueOf(v) })))
  busy.value = false
  if (!res) return say("The garage did not answer.", false)
  say(res.msg || "Saved.", !!res.ok)
  if (res.ok) {
    tunes.value = listOf(res.tunes)
    tuneName.value = ""
  }
}
async function loadTune(t) {
  const res = await callLua("shopLoadTune", t.id)
  if (!res) return say("The garage did not answer.", false)
  say(res.msg || "", !!res.ok)
  if (!res.ok) return
  clearEdits()
  const values = res.values || {}
  for (const v of everyVar()) {
    if (values[v.name] !== undefined) setVar(v, Number(values[v.name]))
  }
}
async function deleteTune(t) {
  const res = await callLua("shopDeleteTune", t.id)
  if (res) tunes.value = listOf(res.tunes)
}

// search: the box filters whatever list is showing (categories search every slot at once; slots; parts)
const norm = v => String(v || "").toLowerCase()
const matches = (q, ...fields) => !q || fields.some(f => norm(f).includes(q))
const partSearchHint = computed(() =>
  curSlot.value ? "Search the parts of this slot" : category.value ? "Search the slots of this category" : "Search all parts and slots (e.g. turbo, tire, spoiler)")
const searchedSlots = computed(() => {
  const q = norm(partSearch.value).trim()
  const out = []
  for (const cat of categories.value) {
    for (const s of cat.slots) {
      if (matches(q, s.name, s.installed, cat.name, s.path)) out.push({ ...s, categoryName: cat.name })
    }
  }
  return out
})
const shownSlots = computed(() => {
  const q = norm(partSearch.value).trim()
  return category.value ? category.value.slots.filter(s => matches(q, s.name, s.installed, s.path)) : []
})
const shownParts = computed(() => {
  const q = norm(partSearch.value).trim()
  return slotParts.value.filter(p => matches(q, p.label, p.name))
})
function openFound(s) {
  category.value = categories.value.find(c => c.name === s.categoryName) || null
  partSearch.value = ""
  openSlot(s)
}
watch([category, curSlot], () => (partSearch.value = ""))

const title = computed(() => {
  if (screen.value === "tuning") return "Garage Computer / Tuning" + (vehicleName.value ? " - " + vehicleName.value : "")
  if (screen.value === "cars") return "Garage Computer / Vehicle Shop"
  if (screen.value === "car") return car.value ? car.value.label : "Vehicle"
  if (screen.value === "parts") return "Garage Computer / Parts Shop" + (vehicleName.value ? " - " + vehicleName.value : "")
  return "Garage Computer"
})

// ----- navigation -----
function leave() {
  emit("close")
}
function back() {
  // a "back" that arrives right after a cart change is the same button press echoing, not a request to go back
  if (Date.now() - lastCartAction < 600) return
  if (confirmParts.value) return void (confirmParts.value = false)
  confirming.value = false
  if (screen.value === "car") screen.value = "cars"
  else if (screen.value === "tuning" && tCat.value) tCat.value = null
  else if (screen.value === "parts" && curSlot.value) curSlot.value = null
  else if (screen.value === "parts" && category.value) category.value = null
  else if (screen.value === "hub") leave()
  else screen.value = "hub"
}

// ----- vehicle shop -----
function specsOf(c, all) {
  const out = []
  if (c.power) out.push({ k: "Power", v: Math.round(c.power) + " hp" })
  if (c.accel && c.accel > 0 && c.accel < 100) out.push({ k: "0-100 km/h", v: Number(c.accel).toFixed(1) + " s" })
  if (c.topSpeed) out.push({ k: "Top speed", v: Math.round(c.topSpeed > 120 ? c.topSpeed : c.topSpeed * 3.6) + " km/h" })
  if (c.drivetrain) out.push({ k: "Drivetrain", v: String(c.drivetrain) })
  if (all) {
    if (c.transmission) out.push({ k: "Transmission", v: String(c.transmission) })
    if (c.weight) out.push({ k: "Weight", v: Math.round(c.weight) + " kg" })
    if (c.bodyStyle) out.push({ k: "Body", v: String(c.bodyStyle) })
    out.push({ k: "Value", v: money(c.value) })
  }
  return all ? out : out.slice(0, 4)
}

// the whole catalog is fetched once; search, brand, sort and "affordable only" then work locally (no round trip per keystroke)
const allCars = ref([])
const PAGE_SIZE = 12
const page = ref(0)
const filtered = computed(() => {
  const q = search.value.trim().toLowerCase()
  let rows = allCars.value.filter(c => {
    if (brand.value && c.brand !== brand.value) return false
    if (affordable.value && c.price > wallet.value) return false
    if (q && !(c.search || `${c.brand} ${c.name} ${c.label || ""}`.toLowerCase()).includes(q)) return false
    return true
  })
  const by = {
    priceDesc: (x, y) => y.price - x.price,
    priceAsc: (x, y) => x.price - y.price,
    power: (x, y) => (y.power || 0) - (x.power || 0),
    name: (x, y) => String(x.name).localeCompare(String(y.name)),
  }[sort.value]
  return by ? rows.sort(by) : rows
})
const carTotal = computed(() => filtered.value.length)
const pageCount = computed(() => Math.max(1, Math.ceil(carTotal.value / PAGE_SIZE)))
const cars = computed(() => filtered.value.slice(page.value * PAGE_SIZE, (page.value + 1) * PAGE_SIZE))
const pageFrom = computed(() => page.value * PAGE_SIZE + 1)
const pageTo = computed(() => Math.min(carTotal.value, (page.value + 1) * PAGE_SIZE))
function goPage(n) {
  page.value = Math.max(0, Math.min(pageCount.value - 1, n))
}
watch([search, brand, sort, affordable], () => (page.value = 0))
watch(pageCount, n => { if (page.value >= n) page.value = n - 1 })
// the brand list comes from the cars themselves, so it is always complete (the list sent when the page opened can be stale)
const carBrands = computed(() => [...new Set(allCars.value.map(c => c.brand).filter(Boolean))].sort((a, b) => a.localeCompare(b)))

async function loadCars(tries = 0) {
  loading.value = true
  const res = await callLua("shopAllCars")
  loading.value = false
  if (!res) return
  wallet.value = res.wallet ?? wallet.value
  allCars.value = listOf(res.items)
  // a tiny list means the game had not finished building its vehicle list: ask again a moment later
  if (allCars.value.length < 20 && tries < 3 && screen.value === "cars") setTimeout(() => loadCars(tries + 1), 1500)
}
function openCars() {
  screen.value = "cars"
  loadCars()
}
function openCar(c) {
  car.value = c
  confirming.value = false
  screen.value = "car"
}
async function buyCar() {
  if (!car.value || busy.value) return
  busy.value = true
  const res = await callLua("shopBuyCar", car.value.model, car.value.key)
  busy.value = false
  confirming.value = false
  if (!res) return say("The garage did not answer.", false)
  say(res.msg || (res.ok ? "Purchased." : "Could not buy it."), !!res.ok)
  if (res.wallet !== undefined) wallet.value = res.wallet
  if (res.ok) {
    if (res.vehicle) vehicleName.value = res.vehicle
    screen.value = "cars"
    loadCars()
  }
}

// ----- parts shop -----
async function openParts() {
  screen.value = "parts"
  category.value = null
  curSlot.value = null
  await loadParts()
}
async function loadParts() {
  loading.value = true
  partsError.value = ""
  const res = await callLua("shopParts")
  loading.value = false
  if (!res) return (partsError.value = "The garage did not answer.")
  if (res.error) partsError.value = res.error
  wallet.value = res.wallet ?? wallet.value
  if (res.vehicle) vehicleName.value = res.vehicle
  categories.value = listOf(res.categories).map(c => ({ ...c, slots: listOf(c.slots) }))
  // keep the open category in sync after a purchase
  if (category.value) category.value = categories.value.find(c => c.name === category.value.name) || null
}
async function openSlot(s) {
  curSlot.value = s
  slotParts.value = []
  loading.value = true
  const res = await callLua("shopSlotParts", s.path)
  loading.value = false
  slotParts.value = listOf(res && res.parts)
}

const inCart = computed(() => {
  const m = {}
  for (const k in cart) m[k] = true
  return m
})
const cartItems = computed(() => Object.values(cart))
const cartLocalTotal = computed(() => cartItems.value.reduce((n, it) => n + it.price, 0))
const quoted = ref(null) // authoritative total from Lua (also counts parts that come with the new ones)
const cartTotal = computed(() => (quoted.value !== null ? quoted.value : cartLocalTotal.value))
const cartPart = path => (cart[path] ? cart[path].part : "")

let lastCartAction = 0
function toggleCart(p) {
  if (p.installed) return
  lastCartAction = Date.now()
  if (cartPart(curSlot.value.path) === p.name) removeFromCart(curSlot.value.path)
  else addToCart(p)
}
function addToCart(p) {
  cart[curSlot.value.path] = { path: curSlot.value.path, part: p.name, partLabel: p.label, slotName: curSlot.value.name, price: p.price }
}
function removeFromCart(path) {
  delete cart[path]
}
function clearCart() {
  for (const k of Object.keys(cart)) delete cart[k]
}
const cartPayload = () => cartItems.value.map(it => ({ path: it.path, part: it.part }))

let quoteSeq = 0
watch(
  () => cartItems.value.map(it => it.path + "=" + it.part).join("|"),
  async () => {
    quoted.value = null
    if (!cartItems.value.length) return
    const mine = ++quoteSeq
    const res = await callLua("shopQuote", cartPayload())
    if (mine === quoteSeq && res && typeof res.cost === "number") quoted.value = res.cost
  }
)

async function buyParts() {
  confirmParts.value = false
  if (busy.value || !cartItems.value.length) return
  busy.value = true
  const res = await callLua("shopBuyParts", cartPayload())
  busy.value = false
  if (!res) return say("The garage did not answer.", false)
  say(res.msg || (res.ok ? "Parts installed." : "Could not buy the parts."), !!res.ok)
  if (res.wallet !== undefined) wallet.value = res.wallet
  if (res.ok) {
    clearCart()
    curSlot.value = null
    // the car is rebuilt, so read the slots again once it has settled
    setTimeout(loadParts, 600)
  }
}

// ----- lifecycle -----
onMounted(async () => {
  const init = await callLua("shopInit")
  if (!init) return
  wallet.value = init.wallet ?? 0
  factor.value = init.factor ?? 50
  brands.value = listOf(init.brands)
  vehicleName.value = init.vehicle || ""
})
onBeforeUnmount(() => clearTimeout(noticeTimer))
</script>

<style scoped>
/* palette and radii follow the RLS "house" style: dark panels, soft white tints, gold prices */
.mwf-shop {
  --page: #151517;
  --panel: rgba(255, 255, 255, 0.06);
  --panel-2: rgba(255, 255, 255, 0.1);
  --line: rgba(255, 255, 255, 0.1);
  --muted: rgba(255, 255, 255, 0.72);
  --faint: rgba(255, 255, 255, 0.55);
  --money: #fde68a;
  --ok: #4ade80;
  --bad: #fca5a5;
  --accent: #ff6600;
  --photo: rgba(0, 0, 0, 0.35);
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
.mwf-shop *, .mwf-shop *::before, .mwf-shop *::after { box-sizing: border-box; }

.top { display: flex; justify-content: space-between; align-items: center; gap: 1em; flex: none; }
.crumbs { display: flex; align-items: center; gap: 0.8em; min-width: 0; }
h1 { margin: 0; font-size: 1.5em; font-weight: 800; }
.status { display: flex; align-items: center; gap: 1em; }
.wallet { color: var(--muted); }
.wallet b { color: var(--money); font-size: 1.15em; font-variant-numeric: tabular-nums; }
.pill { padding: 0.3em 0.6em; border-radius: 0.3em; font-size: 0.72em; font-weight: 800; letter-spacing: 0.06em; }
.pause { background: rgba(155, 48, 255, 0.25); color: #d8b4fe; }

.btn {
  padding: 0.55em 1.1em;
  border: 0;
  border-radius: 0.6em;
  background: var(--panel-2);
  color: #fff;
  font: inherit;
  font-weight: 700;
  cursor: pointer;
  transition: background-color 0.12s;
}
.btn:hover:not(:disabled) { background: rgba(255, 255, 255, 0.18); }
.btn:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.btn:disabled { opacity: 0.45; cursor: default; }
.btn.primary { background: var(--accent); }
.btn.primary:hover:not(:disabled) { background: #ff7a1f; }
.btn.quiet { background: transparent; box-shadow: inset 0 0 0 1px var(--line); }
.btn.big { padding: 0.8em 1.6em; font-size: 1.05em; }

.notice { margin: 0; padding: 0.6em 1em; border-radius: 0.5em; background: rgba(74, 222, 128, 0.14); color: var(--ok); font-weight: 700; flex: none; }
.notice.bad { background: rgba(252, 165, 165, 0.14); color: var(--bad); }
.hint { margin: 0; color: var(--faint); font-size: 0.9em; }
.empty { color: var(--muted); padding: 1.5em 0.5em; margin: 0; }
.empty.small { padding: 0.5em 0; font-size: 0.9em; }

/* hub */
.hub { display: grid; grid-template-columns: repeat(2, minmax(0, 22em)); gap: 1.2em; align-content: start; margin-top: 1em; }
.hub .hint { grid-column: 1 / -1; }
.tile {
  display: flex; flex-direction: column; gap: 0.6em; padding: 1.4em; min-height: 11em; text-align: left;
  border: 0; border-radius: 0.5em; background: var(--panel); color: #fff; font: inherit; cursor: pointer;
  transition: background-color 0.12s;
}
.tile:hover, .tile:focus-visible { background: var(--panel-2); outline: none; box-shadow: inset 0 0 0 2px var(--accent); }
.tile-title { font-size: 1.5em; font-weight: 800; }
.tile-sub { color: var(--muted); flex: 1; }
.tile-foot { color: var(--accent); font-weight: 700; }

/* vehicle listing */
.cars, .parts { display: flex; flex-direction: column; gap: 0.7em; min-height: 0; flex: 1; }
.toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 0.6em; flex: none; }
.search { position: relative; flex: 1 1 16em; max-width: 26em; }
.search input, .select {
  width: 100%; padding: 0.6em 0.9em; border: 0; border-radius: 0.6em; background: var(--panel-2); color: #fff; font: inherit;
}
.select { width: auto; }
.select option { background: #222; color: #fff; }
.search input:focus, .select:focus { outline: 2px solid var(--accent); }
.clear { position: absolute; right: 0.4em; top: 50%; transform: translateY(-50%); border: 0; background: transparent; color: var(--muted); font-size: 1.3em; cursor: pointer; }
.check { display: flex; align-items: center; gap: 0.4em; color: var(--muted); cursor: pointer; }
.count { margin: 0; color: var(--faint); font-size: 0.9em; flex: none; }
.scroll { overflow-y: auto; min-height: 0; flex: 1; display: flex; flex-direction: column; gap: 0.6em; padding-right: 0.4em; }
.more { text-align: center; padding: 0.6em; }
.pager { display: flex; align-items: center; justify-content: space-between; gap: 1em; flex: none; flex-wrap: wrap; }
.pager-btns { display: flex; align-items: center; gap: 0.5em; justify-content: center; }
.pager-info { color: var(--muted); font-size: 0.9em; min-width: 6.5em; text-align: center; }

.card {
  display: grid; grid-template-columns: 17em minmax(0, 1fr); gap: 1.1em; padding: 0.6em 0.75em 0.6em 0.6em;
  border-radius: 0.5em; background: var(--panel); cursor: pointer; transition: background-color 0.12s; flex: none;
}
.card:hover { background: var(--panel-2); }
.photo, .big-photo { display: grid; place-items: center; aspect-ratio: 16 / 9; border-radius: 0.35em; overflow: hidden; background: var(--photo); align-self: start; }
.photo img, .big-photo img { width: 100%; height: 100%; object-fit: contain; display: block; }
.nophoto { color: rgba(255, 255, 255, 0.25); font-weight: 700; }
.body { display: flex; flex-direction: column; gap: 0.5em; min-width: 0; }
.head { display: flex; justify-content: space-between; gap: 1em; align-items: start; }
.head h3 { margin: 0; font-size: 1.3em; font-weight: 800; line-height: 1.15; }
.brand { color: var(--faint); font-size: 0.85em; font-weight: 600; }
.price { color: var(--money); font-size: 1.3em; font-weight: 800; text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; display: grid; }
.price.bad { color: var(--bad); }
.flag { font-size: 0.6em; font-weight: 700; }
.specs { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); margin: 0; padding: 0.5em 0; border-radius: 0.4em; background: rgba(0, 0, 0, 0.22); box-shadow: inset 0 0 0 1px var(--line); }
.specs.grid { grid-template-columns: repeat(3, minmax(0, 1fr)); row-gap: 0.8em; padding: 0.8em 0; }
.spec { display: grid; gap: 0.2em; padding: 0 0.8em; min-width: 0; }
.spec + .spec { box-shadow: -1px 0 0 var(--line); }
.specs.grid .spec:nth-child(3n + 1) { box-shadow: none; }
.spec dt { color: var(--faint); font-size: 0.7em; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; }
.spec dd { margin: 0; font-weight: 600; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }

/* detail */
.detail { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr); gap: 2em; align-items: start; overflow-y: auto; min-height: 0; }
.info { display: flex; flex-direction: column; gap: 0.9em; }
.info h2 { margin: 0; font-size: 1.8em; font-weight: 800; }
.receipt { display: grid; gap: 0.4em; padding: 0.9em 1em; border-radius: 0.5em; background: var(--panel); }
.row { display: flex; justify-content: space-between; gap: 1em; color: var(--muted); font-variant-numeric: tabular-nums; }
.row.total { padding-top: 0.5em; border-top: 1px solid var(--line); color: #fff; }
.gold { color: var(--money); }
.badtxt { color: var(--bad); }
.actions { display: flex; gap: 0.6em; flex-wrap: wrap; }

/* parts shop */
.parts { flex-direction: row; gap: 1.2em; }
.panel { display: flex; flex-direction: column; gap: 0.7em; padding: 1em; border-radius: 0.5em; background: var(--panel); min-height: 0; }
.parts > .panel:first-child { flex: 1; }
.cart { width: 24em; flex: none; }
.cart h3 { margin: 0; font-size: 1.2em; }
.path { display: flex; align-items: center; gap: 0.5em; color: var(--faint); flex: none; }
.link { border: 0; background: transparent; color: var(--muted); font: inherit; font-weight: 700; cursor: pointer; padding: 0.2em 0.3em; }
.link:hover { color: #fff; }
.link.here { color: #fff; cursor: default; }
.row-btn {
  display: flex; align-items: center; gap: 0.9em; padding: 0.9em 1em; border: 0; border-radius: 0.5em; background: rgba(255, 255, 255, 0.05);
  color: #fff; font: inherit; text-align: left; cursor: pointer; flex: none;
}
.row-btn:hover, .row-btn:focus-visible { background: var(--panel-2); outline: none; box-shadow: inset 0 0 0 2px var(--accent); }
.rb-name { font-weight: 800; min-width: 14em; }
.rb-sub { color: var(--muted); flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rb-count { color: var(--faint); font-size: 0.9em; }
.rb-go { color: var(--accent); font-size: 1.4em; }
.rb-tag, .tag { padding: 0.2em 0.5em; border-radius: 0.3em; background: rgba(74, 222, 128, 0.18); color: var(--ok); font-size: 0.75em; font-weight: 800; }
.part { display: grid; grid-template-columns: minmax(0, 1fr) 7em 8em; gap: 1em; align-items: center; padding: 0.7em 1em; border-radius: 0.5em; background: rgba(255, 255, 255, 0.05); flex: none; }
.part.picked { box-shadow: inset 0 0 0 2px var(--ok); }
.part-name { display: flex; align-items: center; gap: 0.6em; min-width: 0; }
.part-price { color: var(--money); font-weight: 800; text-align: right; font-variant-numeric: tabular-nums; }
.part-price.bad { color: var(--bad); }
.cart-list { list-style: none; margin: 0; padding: 0; overflow-y: auto; display: grid; gap: 0.4em; min-height: 0; flex: 1; align-content: start; }
.cart-list li { display: grid; grid-template-columns: minmax(0, 1fr) auto auto; gap: 0.6em; align-items: center; padding: 0.5em 0.7em; border-radius: 0.4em; background: rgba(255, 255, 255, 0.05); }
.ci-text { display: grid; min-width: 0; }
.ci-text span { color: var(--faint); font-size: 0.8em; }
.ci-price { color: var(--money); font-weight: 800; font-variant-numeric: tabular-nums; }
.x { border: 0; background: transparent; color: var(--muted); font-size: 1.3em; cursor: pointer; }
.x:hover { color: var(--bad); }

@media (max-width: 1100px) {
  .card { grid-template-columns: 11em minmax(0, 1fr); }
  .detail { grid-template-columns: 1fr; }
  .cart { width: 19em; }
}
/* .search is a flex item that grows: inside the parts panel (a column) that stretched it into a huge gap, so it must not grow */
.parts-search { display: block; flex: none; max-width: none; margin: 0 0 0.6em; }
/* the controller's focus frame on a car card (same look as the tiles and rows) */
.card:focus-visible, .card:focus { outline: none; box-shadow: inset 0 0 0 2px var(--accent); }
.tuning .sub-head { margin: 0.9em 0 0.3em; font-size: 0.95em; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
.tvar { display: flex; justify-content: space-between; align-items: center; gap: 1em; padding: 0.6em 0.9em; border-radius: 0.5em; background: var(--panel); margin-bottom: 0.4em; }
.tvar.changed { box-shadow: inset 0 0 0 2px var(--accent); }
.tvar-text { flex: 1 1 14em; min-width: 0; display: flex; flex-direction: column; gap: 0.15em; }
.tvar-desc { color: var(--muted); font-size: 0.85em; line-height: 1.3; }
.tvar-ctl { flex: 0 1 28em; display: flex; align-items: center; gap: 0.5em; }
.tvar-ctl .range { flex: 1 1 8em; min-width: 6em; accent-color: var(--accent); }
.tvar-val { min-width: 6.5em; text-align: right; font-variant-numeric: tabular-nums; }
.btn.step { min-width: 2.2em; padding: 0.35em 0.5em; }
.modal { position: fixed; inset: 0; z-index: 60; display: grid; place-items: center; background: rgba(0, 0, 0, 0.6); }
.modal-box { width: min(32em, 90vw); max-height: 85vh; overflow: auto; display: flex; flex-direction: column; gap: 0.8em; padding: 1.4em 1.6em; border-radius: 0.8em; background: #1c1c20; box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.12); }
.modal-box h3 { margin: 0; }
.modal-box .actions { justify-content: flex-end; }
/* the game's own text box (BngInput) used for every search / name field */
.mwf-search { flex: 0 0 auto; width: min(26em, 100%); margin: 0 0 0.6em; }
.toolbar .mwf-search { flex: 1 1 16em; max-width: 26em; margin: 0; }
</style>
