// Hearthguard playtest dashboard. Reads plays from Supabase through the two
// read-only functions in supabase/migrations/20261108080000_dashboard_reads.sql
// and refreshes while you watch.
//
// Routes: #/ lists players and their plays, #/play/<id> shows one play.

const SUPABASE_URL = "https://rtmxrfiykgxqgyxnnrnx.supabase.co";
const PUBLISHABLE_KEY = "sb_publishable_vKdCg9wL5Cw8xC5aN5qo_w_oHDztQzl";
const LIST_REFRESH_S = 10;
const LIVE_REFRESH_S = 5;
// A play with no end that hasn't advanced for this long is treated as abandoned.
const STALE_S = 120;

const app = document.getElementById("app");
const status = document.getElementById("status");
let timer = null;

async function rpc(name, args = {}) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: PUBLISHABLE_KEY, "Content-Type": "application/json" },
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`${name}: ${r.status} ${await r.text()}`);
  return r.json();
}

// Formatting. Anything that came from a player goes through esc() or num().
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const num = (n) => (Number.isFinite(+n) ? +n : 0);
const f = (n) => Math.round(num(n)).toLocaleString();
const pc = (x) => Math.round(num(x) * 100) + "%";
const ts = (s) => { s = Math.round(num(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); };
const nm = (s) => esc(String(s ?? "").replace(/^zone:([^:]+):(.+)$/, "$1 → $2").replace(/_/g, " "));
const when = (iso) => new Date(iso).toLocaleString([], { dateStyle: "medium", timeStyle: "short" });
const ago = (iso) => {
  const s = (Date.now() - new Date(iso)) / 1000;
  if (s < 90) return "just now";
  if (s < 5400) return Math.round(s / 60) + " min ago";
  if (s < 129600) return Math.round(s / 3600) + " h ago";
  return Math.round(s / 86400) + " days ago";
};

function playState(p) {
  if (p.ended_at) return p.outcome || "ended";
  const lastSeen = new Date(p.started_at).getTime() / 1000 + num(p.duration_s);
  return Date.now() / 1000 - lastSeen < STALE_S ? "live" : "no end logged";
}
function stateTag(p) {
  const s = playState(p);
  const cls = s === "victory" ? "good" : s === "live" ? "live" : s === "defeat" ? "bad" : "";
  return `<span class="tag ${cls}">${esc(s)}</span>`;
}

// ---------- List of players and plays ----------

async function showList() {
  const plays = await rpc("dashboard_plays", { lim: 1000 });
  const players = new Map();
  for (const p of plays) {
    if (!players.has(p.user_id)) players.set(p.user_id, { id: p.user_id, guest: p.guest, plays: [] });
    players.get(p.user_id).plays.push(p);
  }
  const list = [...players.values()];
  const live = plays.filter((p) => playState(p) === "live").length;

  let h = `<h1>Playtests</h1><div class="sub">${plays.length} plays by ${list.length} players${live ? ` · <span class="tag live">${live} live now</span>` : ""}</div>`;
  for (const pl of list) {
    const names = [...new Set(pl.plays.map((p) => p.hero_name).filter(Boolean))];
    const best = Math.max(...pl.plays.map((p) => num(p.chapter) * 10 + num(p.wave)));
    const time = pl.plays.reduce((a, p) => a + num(p.duration_s), 0);
    const wins = pl.plays.filter((p) => p.outcome === "victory").length;
    h += `<div class="card player"><h2>${esc(names[0] || "Unnamed")}
      ${names.length > 1 ? `<span class="mute">also ${names.slice(1).map(esc).join(", ")}</span>` : ""}
      <span class="tag">${pl.guest ? "guest" : "account"}</span>
      <span class="mute">${esc(pl.id.slice(0, 8))} · ${pl.plays.length} plays · ${wins} wins · ${ts(time)} played · best ch ${Math.floor(best / 10) + 1} wave ${(best % 10) + 1} · last ${ago(pl.plays[0].started_at)}</span></h2>
      <table><tr><th class="l">Started</th><th class="l">Hero</th><th class="l">Class</th><th class="l">Mode</th><th>Length</th><th>Reached</th><th>Level</th><th>Kills</th><th>Deaths</th><th>Dmg done</th><th>Dmg taken</th><th>Hearth</th><th class="l">Result</th><th class="l">Build</th></tr>
      ${pl.plays.map((p) => `<tr class="go" data-play="${esc(p.id)}">
        <td class="l"><a href="#/play/${esc(p.id)}">${when(p.started_at)}</a></td><td class="l">${esc(p.hero_name)}</td><td class="l">${esc(p.hero_class)}</td>
        <td class="l">${esc(p.mode)}${num(p.party_size) > 1 ? ` ×${num(p.party_size)}` : ""}</td><td>${ts(p.duration_s)}</td>
        <td>ch ${num(p.chapter) + 1} · w ${num(p.wave) + 1}</td><td>${num(p.level)}</td><td>${f(p.kills)}</td><td>${num(p.deaths)}</td>
        <td>${f(p.damage_done)}</td><td>${f(p.damage_taken)}</td><td>${p.hearth_frac == null ? "–" : pc(p.hearth_frac)}</td>
        <td class="l">${stateTag(p)}</td><td class="l mute">${esc(p.platform)} ${esc(p.build)}</td></tr>`).join("")}
      </table></div>`;
  }
  if (!plays.length) h += `<p class="mute">No plays yet.</p>`;
  app.innerHTML = h;
  app.querySelectorAll("tr.go").forEach((tr) => tr.addEventListener("click", () => (location.hash = "#/play/" + tr.dataset.play)));
  return LIST_REFRESH_S;
}

// ---------- One play ----------

async function showPlay(id) {
  const D = await rpc("dashboard_play", { play: id });
  const p = D.play;
  if (!p) { app.innerHTML = `<p><a href="#/">← All plays</a></p><p>No play with that id.</p>`; return null; }
  const ev = D.events;
  const N = NAMES[p.hero_class] || { skills: ["Q", "W", "E", "R"], talents: {} };
  const tal = (t) => esc(N.talents[t] || t);
  const by = (k) => ev.filter((e) => e.kind === k);
  const starts = by("wave_start"), ends = by("wave_end"), deaths = by("death").filter((e) => e.slot === 0);
  const hw = by("hero_wave").filter((e) => e.slot === 0);
  const state = playState(p);

  // One row per finished wave, plus the wave being played now.
  const waves = ends.map((e, i) => ({ n: num(e.wave) + 1, ch: num(e.chapter) + 1, s: starts[i]?.data || {}, start: starts[i]?.t ?? 0, end: e, h: hw[i]?.data || null }));
  const current = !p.ended_at && starts.length > ends.length ? starts[ends.length] : null;

  let h = `<p><a href="#/">← All plays</a></p>
  <h1>${esc(p.hero_name || "Unnamed")} <span class="tag">${esc(p.hero_class)}</span> ${stateTag(p)}</h1>
  <div class="sub">${when(p.started_at)} · ${esc(p.mode)}, party of ${num(p.party_size)} · ${esc(p.platform)} build ${esc(p.build)} · seed ${esc(p.match_seed)} · play ${esc(p.id.slice(0, 8))}${state === "live" ? " · refreshes every " + LIVE_REFRESH_S + " s" : ""}</div>
  <div class="grid kpis">${[["Duration", ts(p.duration_s)], ["Reached", `Ch ${num(p.chapter) + 1} · wave ${num(p.wave) + 1}`], ["Level", num(p.level)], ["Kills", f(p.kills)], ["Deaths", num(p.deaths)], ["Damage done", f(p.damage_done)], ["Damage taken", f(p.damage_taken)], ["DPS", f(num(p.damage_done) / Math.max(1, num(p.duration_s)))], ["Gold", f(p.gold)], ["Hearth", p.hearth_frac == null ? "–" : pc(p.hearth_frac)]].map(([l, v]) => `<div class="card kpi"><div class="v">${v}</div><div class="l">${l}</div></div>`).join("")}</div>`;

  // Waves table
  h += `<div class="card"><h2>Waves</h2><table><tr><th>Ch</th><th>#</th><th class="l">Wave</th><th>Start</th><th>Length</th><th>Mobs</th><th>Carried in</th><th>HP mult</th><th>Kills</th><th>Dmg done</th><th>Dmg taken</th><th>Deaths</th><th>Potions</th><th>Gold Δ</th><th>Hero HP</th><th>Hearth hits</th><th>Hearth end</th><th class="l">Result</th></tr>
  ${waves.map((w) => `<tr><td>${w.ch}</td><td>${w.n}</td><td class="l">${esc(w.s.title)}</td><td>${ts(w.start)}</td><td>${ts(w.end.data.dur_s)}</td><td>${num(w.s.mobs)}</td><td>${num(w.s.mobs_carried)}</td><td>×${num(w.s.hp_mult)}</td>
    ${w.h ? `<td>${f(w.h.kills)}</td><td>${f(w.h.dmg_done)}</td><td>${f(w.h.dmg_taken)}</td><td>${num(w.h.deaths)}</td><td>${num(w.h.drinks)}</td><td>${num(w.h.gold_earned) > 0 ? "+" : ""}${f(w.h.gold_earned)}</td><td>${pc(w.h.hp_frac)}</td>` : `<td colspan="7"></td>`}
    <td>${f(w.end.data.hearth_hits)}</td><td>${pc(w.end.data.hearth_frac)}</td><td class="l"><span class="tag ${w.end.data.how === "cleared" ? "good" : "bad"}">${esc(w.end.data.how)}</span></td></tr>`).join("")}
  ${current ? `<tr><td>${num(current.chapter) + 1}</td><td>${num(current.wave) + 1}</td><td class="l">${esc(current.data.title)}</td><td>${ts(current.t)}</td><td>${ts(num(p.duration_s) - num(current.t))}</td><td>${num(current.data.mobs)}</td><td>${num(current.data.mobs_carried)}</td><td>×${num(current.data.hp_mult)}</td><td colspan="9"></td><td class="l"><span class="tag live">in progress</span></td></tr>` : ""}
  </table><p class="mute">Gold Δ is gold earned minus potions bought that wave.</p></div>`;

  // Charts
  if (waves.length) {
    const W = 480, H = 200, pad = 34, bw = (W - pad - 10) / waves.length;
    const mx = Math.max(1, ...waves.map((w) => Math.max(num(w.h?.dmg_done), num(w.h?.dmg_taken))));
    let s1 = `<svg viewBox="0 0 ${W} ${H + 24}" width="100%">`;
    [0, 0.5, 1].forEach((g) => (s1 += `<line x1="${pad}" x2="${W}" y1="${H - g * (H - 10)}" y2="${H - g * (H - 10)}" stroke="var(--line)"/><text x="${pad - 4}" y="${H - g * (H - 10) + 4}" text-anchor="end">${(mx * g / 1000).toFixed(1)}k</text>`));
    waves.forEach((w, i) => {
      const x = pad + i * bw + bw * 0.15, b = bw * 0.33, y1 = (H - 10) * num(w.h?.dmg_done) / mx, y2 = (H - 10) * num(w.h?.dmg_taken) / mx;
      s1 += `<rect x="${x}" y="${H - y1}" width="${b}" height="${y1}" fill="var(--a)" rx="2"><title>Done ${f(w.h?.dmg_done)}</title></rect><rect x="${x + b + 2}" y="${H - y2}" width="${b}" height="${y2}" fill="var(--b)" rx="2"><title>Taken ${f(w.h?.dmg_taken)}</title></rect><text x="${x + b}" y="${H + 16}" text-anchor="middle">W${w.n}</text>`;
    });
    s1 += "</svg>";
    const pts = [[0, 1], ...waves.map((w) => [num(w.end.t), num(w.end.data.hearth_frac)])], T = Math.max(1, num(p.duration_s));
    const X = (t) => pad + (W - pad - 10) * Math.min(t, T) / T, Y = (v) => H - (H - 10) * v;
    let s2 = `<svg viewBox="0 0 ${W} ${H + 24}" width="100%">`;
    [0, 0.5, 1].forEach((g) => (s2 += `<line x1="${pad}" x2="${W}" y1="${Y(g)}" y2="${Y(g)}" stroke="var(--line)"/><text x="${pad - 4}" y="${Y(g) + 4}" text-anchor="end">${g * 100}%</text>`));
    waves.forEach((w) => (s2 += `<line x1="${X(w.start)}" x2="${X(w.start)}" y1="10" y2="${H}" stroke="var(--line)" stroke-dasharray="3 3"/><text x="${X(w.start) + 3}" y="${H + 16}">W${w.n}</text>`));
    s2 += `<polyline fill="none" stroke="var(--d)" stroke-width="2.5" points="${pts.map(([t, v]) => X(t) + "," + Y(v)).join(" ")}"/>`;
    pts.forEach(([t, v]) => (s2 += `<circle cx="${X(t)}" cy="${Y(v)}" r="3.5" fill="var(--d)"><title>${ts(t)}: ${pc(v)}</title></circle>`));
    deaths.forEach((d) => (s2 += `<text x="${X(num(d.t))}" y="22" text-anchor="middle" style="fill:var(--b);font-size:14px">✕</text>`));
    s2 += "</svg>";
    h += `<div class="grid two"><div class="card"><h2>Damage per wave</h2><div class="legend"><span><i style="background:var(--a)"></i>Done</span><span><i style="background:var(--b)"></i>Taken</span></div>${s1}</div>
    <div class="card"><h2>Hearth health at each wave end</h2><div class="legend"><span><i style="background:var(--d)"></i>Hearth</span><span style="color:var(--b)">✕ hero death</span></div>${s2}</div></div>`;
  }

  // Damage by source and final build
  const src = {};
  hw.forEach((e) => Object.entries(e.data.taken_by || {}).forEach(([k, v]) => (src[k] = (src[k] || 0) + num(v))));
  const ss = Object.entries(src).sort((a, b) => b[1] - a[1]), sm = ss[0]?.[1] || 1, tot = ss.reduce((a, b) => a + b[1], 0) || 1;
  const hero = by("game_over").at(-1)?.data?.heroes?.["0"] || deaths.at(-1)?.data?.hero || null;
  const fin = hero || p.final || {};
  const ranks = fin.ranks || [], talents = (fin.talents || []).filter(Boolean), belt = (fin.belt || []).filter((b) => b[0]);
  const st = hero?.stats;
  h += `<div class="grid two"><div class="card"><h2>Damage taken by source</h2>${ss.length ? `<table>${ss.map(([k, v]) => `<tr><td class="l" style="width:40%">${nm(k)}</td><td style="width:45%"><div class="bar" style="width:${100 * v / sm}%"></div></td><td>${f(v)}</td><td class="mute">${pc(v / tot)}</td></tr>`).join("")}</table>` : `<p class="mute">No finished waves yet.</p>`}</div>
  <div class="card"><h2>${hero ? "Final build" : "Build so far"}</h2><table>
  ${N.skills.map((s, i) => `<tr><td class="l">${esc(s)}</td><td>rank ${num(ranks[i])}</td><td class="mute">${hw.reduce((a, e) => a + num(e.data.casts?.[i]), 0)} casts</td></tr>`).join("")}
  <tr><td class="l">Talents</td><td colspan="2" class="l" style="white-space:normal">${talents.map(tal).join("<br>") || "none"}</td></tr>
  <tr><td class="l">Potion belt</td><td colspan="2" class="l">${belt.map((b) => `${esc(b[0])} ×${num(b[1])}`).join(", ") || "empty"}</td></tr></table>
  ${st ? `<table style="margin-top:10px">${[["Max HP", f(st.max_hp)], ["Damage", num(st.dmg).toFixed(1)], ["Attack speed", num(st.aspd).toFixed(2)], ["Crit", pc(st.crit) + " ×" + num(st.crit_dmg)], ["Armor", num(st.armor)], ["Regen", num(st.regen) + "/s"], ["Range", f(st.range)], ["Move speed", f(st.speed)]].map(([a, b]) => `<tr><td class="l">${a}</td><td>${b}</td></tr>`).join("")}</table>` : ""}</div></div>`;

  // Deaths
  if (deaths.length) {
    h += `<div class="card"><h2>Deaths (${deaths.length})</h2>${deaths.map((d, i) => {
      const x = d.data, k = x.killer || {}, hr = x.hero || {}, boss = x.boss || {};
      const r = Object.entries(x.recent_by_src || {}).sort((a, b) => b[1] - a[1]);
      return `<div class="death"><b>${i + 1}. ${ts(d.t)}, wave ${num(d.wave) + 1}</b>, killed by <b>${nm(x.src)}</b> (${esc(k.rank)}, ${f(k.dist)} px away) with a ${f(x.blow)} hit after ${ts(x.life_s)} alive.
      <div class="mute">${num(x.mobs_300)} mobs within 300 px, ${num(x.mobs_600)} within 600 · slowed ${pc(hr.debuffs?.slow)} · ${num(x.drinks_this_life)} potions drunk this life, ${num(x.potions_left)} left · ${f(x.dist_hearth)} px from the Hearth (Hearth at ${pc(x.hearth_frac)})${boss.kind ? ` · boss ${nm(boss.kind)} at ${pc(boss.hp_frac)}, phase ${num(boss.phase)}` : ""}${(x.elites_near || []).length ? ` · near ${x.elites_near.map((e) => nm(e.kind) + " " + pc(e.hp_frac)).join(", ")}` : ""}</div>
      <div style="margin-top:4px">Last 6 s: ${f(r.reduce((a, b) => a + num(b[1]), 0))} damage from ${(x.recent || []).length} hits. ${r.map(([s, v]) => `${nm(s)} ${f(v)}`).join(" · ")}</div></div>`;
    }).join("")}</div>`;
  }

  // Event log, newest first so live plays read from the top.
  const desc = (e) => {
    const x = e.data || {};
    switch (e.kind) {
      case "wave_start": return `<b>${esc(x.title)}</b> starts, ${num(x.mobs)} mobs${num(x.mobs_carried) ? `, ${num(x.mobs_carried)} carried over` : ""}`;
      case "wave_end": return `Wave ${num(e.wave) + 1} ${esc(x.how)} in ${ts(x.dur_s)}, Hearth ${pc(x.hearth_frac)}`;
      case "learn": return `Learned ${esc(N.skills[x.skill] || "skill " + x.skill)} rank ${num(x.rank)}`;
      case "level": return `Reached level ${num(x.level)}`;
      case "talent": return `Took talent ${tal(x.id)}`;
      case "loot": return `Looted ${esc(x.potion)} potion`;
      case "buy": return `Bought ${esc(x.potion)} potion for ${num(x.price)} gold (${num(x.gold_left)} left)`;
      case "drink": return `Drank ${esc(x.potion)} at ${pc(x.hp_frac)} HP, ${num(x.mobs_near)} mobs near`;
      case "death": return `<b style="color:var(--b)">Died</b> to ${nm(x.src)}`;
      case "respawn": return `Respawned after ${num(x.dead_s).toFixed(1)} s`;
      case "game_over": return `<b>Game over</b>, ${esc(x.outcome)}`;
      case "hero_wave": return null;
      default: return esc(e.kind);
    }
  };
  const rows = ev.map((e) => [e, desc(e)]).filter(([, d]) => d).reverse();
  h += `<div class="card"><h2>Event log (${ev.length} events)</h2><table>${rows.map(([e, d]) => `<tr><td class="mute">${ts(e.t)}</td><td class="l mute">W${num(e.wave) + 1}</td><td class="l"><span class="tag">${esc(e.kind)}</span></td><td class="l" style="white-space:normal;width:70%">${d}</td></tr>`).join("")}</table></div>`;

  app.innerHTML = h;
  return state === "live" ? LIVE_REFRESH_S : null;
}

// ---------- Routing and refresh ----------

async function render() {
  clearTimeout(timer);
  const m = location.hash.match(/^#\/play\/([0-9a-f-]{36})$/i);
  try {
    const every = m ? await showPlay(m[1]) : await showList();
    status.textContent = `Updated ${new Date().toLocaleTimeString()}`;
    // A hidden tab stops polling; coming back to it renders again.
    if (every) timer = setTimeout(() => { if (!document.hidden) render(); }, every * 1000);
  } catch (err) {
    status.textContent = "Couldn't reach Supabase, retrying";
    console.error(err);
    timer = setTimeout(render, 15000);
  }
}

let lastHash = location.hash;
window.addEventListener("hashchange", () => { if (location.hash !== lastHash) { lastHash = location.hash; scrollTo(0, 0); } render(); });
document.addEventListener("visibilitychange", () => { if (!document.hidden) render(); });
render();
