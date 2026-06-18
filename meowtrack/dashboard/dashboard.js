// dashboard.js — front du suivi Meowtrack. Vanilla JS, aucune dépendance.
"use strict";

const $ = (sel) => document.querySelector(sel);

// Token d'accès (serveur déployé protégé par MEOWTRACK_TOKEN). Stocké localement,
// envoyé en Bearer. Sur 401 on (re)demande le token et on réessaie une fois.
function getToken() {
  return localStorage.getItem("meowtrack_token") || "";
}
function promptToken() {
  const t = window.prompt("Token d'accès Meowtrack (MEOWTRACK_TOKEN du serveur) :", getToken());
  if (t === null) return null;
  localStorage.setItem("meowtrack_token", t.trim());
  return t.trim();
}
function authHeaders(extra = {}) {
  const t = getToken();
  return t ? { ...extra, Authorization: "Bearer " + t } : extra;
}

const api = {
  async _do(method, url, body, retried) {
    const r = await fetch(url, {
      method,
      headers: authHeaders(body ? { "Content-Type": "application/json" } : {}),
      body: body ? JSON.stringify(body) : undefined,
    });
    if (r.status === 401 && !retried) {
      if (promptToken() !== null) return api._do(method, url, body, true);
    }
    if (!r.ok) throw new Error((await r.json().catch(() => ({}))).error || r.statusText);
    return r.json();
  },
  get(url) {
    return api._do("GET", url, undefined, false);
  },
  send(method, url, body) {
    return api._do(method, url, body, false);
  },
};

const TYPE_ICON = { bug: "🐞", feature: "✨", task: "✅", chore: "🧹" };
const STATUS_LABEL = { open: "Ouvert", in_progress: "En cours", done: "Fait", wontfix: "Abandonné" };
const PRIO_LABEL = { critical: "Critique", high: "Haute", medium: "Moyenne", low: "Basse" };

let state = { issues: [], selected: null, editing: null, refs: [], branch: "", branches: [], serverBranch: null };

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// ── Chargement & liste ───────────────────────────────────────────────────────
async function loadMeta() {
  try {
    const m = await api.get("/api/meta");
    const g = m.git || {};
    $("#meta").innerHTML =
      `repo <b>${esc((m.repoRoot || "").split(/[\\/]/).pop())}</b> · ` +
      `branche <b>${esc(g.branch || "?")}</b> @ <b>${esc(g.commit || "?")}</b> · ` +
      `<b>${m.total || 0}</b> entrées (${m.byStatus?.in_progress || 0} en cours, ${m.byStatus?.open || 0} ouvertes)`;
  } catch (e) {
    $("#meta").textContent = "⚠ serveur injoignable : " + e.message;
  }
}

// Charge la liste des branches du repo serveur → sélecteur topbar.
async function loadBranches() {
  try {
    const b = await api.get("/api/branches");
    state.branches = b.branches || [];
    state.serverBranch = b.current || null;
    const sel = $("#branchSel");
    const keep = state.branch;
    sel.innerHTML =
      `<option value="">Toutes branches</option>` +
      state.branches.map((n) => `<option value="${esc(n)}">${esc(n)}</option>`).join("");
    sel.value = keep && state.branches.includes(keep) ? keep : "";
    state.branch = sel.value;
  } catch {
    /* serveur injoignable : on garde le sélecteur vide */
  }
}

// Options du select branche de la modale (valeur "" = défaut serveur / HEAD).
function branchOptions(selected) {
  const def = `(défaut${state.serverBranch ? " · " + state.serverBranch : ""})`;
  const opts = [`<option value="">${esc(def)}</option>`];
  for (const n of state.branches) opts.push(`<option value="${esc(n)}">${esc(n)}</option>`);
  if (selected && !state.branches.includes(selected))
    opts.push(`<option value="${esc(selected)}">${esc(selected)}</option>`);
  return opts.join("");
}

// Clone / met à jour le repo (git fetch + pull côté serveur) puis recharge.
async function updateRepo(btn) {
  const old = btn.textContent;
  btn.disabled = true;
  btn.textContent = "⟳ Maj…";
  try {
    const r = await api.send("POST", "/api/repo/update");
    if (r.skipped) {
      alert("Aucune URL de repo configurée (MEOWTRACK_REPO_URL).");
    } else if (r.ok) {
      await loadMeta();
      await loadList();
    } else {
      alert("Mise à jour échouée :\n" + (r.output || "erreur inconnue"));
    }
  } catch (e) {
    alert("Erreur : " + e.message);
  } finally {
    btn.textContent = old;
    btn.disabled = false;
  }
}

async function loadList() {
  const params = new URLSearchParams();
  const text = $("#search").value.trim();
  if (text) params.set("text", text);
  if ($("#fType").value) params.set("type", $("#fType").value);
  const st = $("#fStatus").value;
  if (st === "__all") params.set("includeClosed", "true");
  else if (st) params.set("status", st);
  if ($("#fPriority").value) params.set("priority", $("#fPriority").value);
  if (state.branch) params.set("branch", state.branch);
  try {
    state.issues = await api.get("/api/issues?" + params.toString());
    renderList();
  } catch (e) {
    $("#issueList").innerHTML = `<li class="empty">Erreur : ${esc(e.message)}</li>`;
  }
}

function renderList() {
  const ul = $("#issueList");
  if (!state.issues.length) {
    ul.innerHTML = `<li class="empty">Aucune entrée.</li>`;
    return;
  }
  ul.innerHTML = state.issues
    .map((it) => {
      const sel = state.selected?.ref === it.ref ? "selected" : "";
      const tags = it.tags.map((t) => `<span class="badge tag">${esc(t)}</span>`).join("");
      const refBadge = it.references.length ? `<span class="badge refcount">📎 ${it.references.length}</span>` : "";
      // Badge branche affiché seulement hors filtre branche (sinon redondant).
      const brBadge = it.branch && !state.branch ? `<span class="badge">⎇ ${esc(it.branch)}</span>` : "";
      const stBadge =
        it.status !== "open" ? `<span class="badge status-${it.status}">${STATUS_LABEL[it.status]}</span>` : "";
      return `<li class="issue-card prio-${it.priority} ${it.status} ${sel}" data-ref="${esc(it.ref)}">
        <div class="row1">
          <span class="code">${esc(it.ref)}</span>
          <span class="title">${esc(it.title)}</span>
        </div>
        <div class="row2">
          <span class="badge type-${it.type}">${TYPE_ICON[it.type]} ${it.type}</span>
          ${stBadge}${brBadge}${refBadge}${tags}
        </div>
      </li>`;
    })
    .join("");
  ul.querySelectorAll(".issue-card").forEach((el) =>
    el.addEventListener("click", () => selectIssue(el.dataset.ref))
  );
}

// ── Détail ───────────────────────────────────────────────────────────────────
async function selectIssue(ref) {
  try {
    state.selected = await api.get("/api/issues/" + encodeURIComponent(ref));
    renderList();
    renderDetail();
  } catch (e) {
    $("#detail").innerHTML = `<div class="empty">Erreur : ${esc(e.message)}</div>`;
  }
}

function descToHtml(desc) {
  return esc(desc).replace(/@([A-Za-z0-9_./-]+(?::\d+(?:-\d+)?)?)/g, '<span class="mention">@$1</span>');
}

function renderDetail() {
  const it = state.selected;
  if (!it) return;
  const refsHtml = it.references.length
    ? it.references
        .map(
          (r) => `<li class="${r.existed ? "" : "missing"}">
            <span class="kind">${r.kind === "dir" ? "📁" : "📄"}</span>
            <span class="path">${esc(r.path)}</span>
            ${r.lineStart ? `<span class="lines">:${r.lineStart}${r.lineEnd ? "-" + r.lineEnd : ""}</span>` : ""}
            ${r.existed ? "" : '<span class="badge type-bug">absent</span>'}
          </li>`
        )
        .join("")
    : '<li class="empty">Aucune référence.</li>';

  const commentsHtml = (it.comments || []).length
    ? it.comments
        .map((c) => `<li>${esc(c.body)}<time>${esc(c.createdAt)}</time></li>`)
        .join("")
    : '<li class="empty">Aucun commentaire.</li>';

  const statusBtns = Object.keys(STATUS_LABEL)
    .map(
      (s) => `<button data-status="${s}" class="${it.status === s ? "active" : ""}">${STATUS_LABEL[s]}</button>`
    )
    .join("");

  $("#detail").innerHTML = `
    <div class="detail-head">
      <div style="flex:1">
        <h1>${esc(it.title)}</h1>
        <div class="detail-sub">
          <span class="code">${esc(it.ref)}</span>
          <span class="badge type-${it.type}">${TYPE_ICON[it.type]} ${it.type}</span>
          <span class="badge">priorité : ${PRIO_LABEL[it.priority]}</span>
          ${it.branch ? `<span class="badge">${esc(it.branch)} @ ${esc(it.commit || "?")}</span>` : ""}
          ${it.tags.map((t) => `<span class="badge tag">${esc(t)}</span>`).join("")}
        </div>
      </div>
      <button id="editBtn" class="ghost">✎ Éditer</button>
      <button id="delBtn" class="danger">🗑</button>
    </div>

    <div class="detail-section">
      <h3>Statut</h3>
      <div class="status-buttons">${statusBtns}</div>
    </div>

    <div class="detail-section">
      <h3>Description</h3>
      <div class="desc-body">${it.description ? descToHtml(it.description) : '<span class="hint">—</span>'}</div>
    </div>

    <div class="detail-section">
      <h3>Fichiers / dossiers (${it.references.length})</h3>
      <ul class="ref-list">${refsHtml}</ul>
    </div>

    <div class="detail-section">
      <h3>Commentaires</h3>
      <ul class="comment-list">${commentsHtml}</ul>
      <div class="add-comment">
        <input id="commentInput" type="text" placeholder="Ajouter une note…" />
        <button id="commentBtn">Ajouter</button>
      </div>
    </div>`;

  $("#editBtn").addEventListener("click", () => openModal(it));
  $("#delBtn").addEventListener("click", () => deleteIssue(it.ref));
  $("#detail").querySelectorAll(".status-buttons button").forEach((b) =>
    b.addEventListener("click", () => setStatus(it.ref, b.dataset.status))
  );
  const ci = $("#commentInput");
  const submitComment = async () => {
    if (!ci.value.trim()) return;
    await api.send("POST", `/api/issues/${encodeURIComponent(it.ref)}/comments`, { body: ci.value.trim() });
    await selectIssue(it.ref);
  };
  $("#commentBtn").addEventListener("click", submitComment);
  ci.addEventListener("keydown", (e) => e.key === "Enter" && submitComment());
}

async function setStatus(ref, status) {
  await api.send("PATCH", "/api/issues/" + encodeURIComponent(ref), { status });
  await Promise.all([selectIssue(ref), loadMeta()]);
  await loadList();
}

async function deleteIssue(ref) {
  if (!confirm(`Supprimer ${ref} ?`)) return;
  await api.send("DELETE", "/api/issues/" + encodeURIComponent(ref));
  state.selected = null;
  $("#detail").innerHTML = '<div class="empty">Entrée supprimée.</div>';
  await Promise.all([loadList(), loadMeta()]);
}

// ── Modale création / édition ────────────────────────────────────────────────
function openModal(issue) {
  state.editing = issue || null;
  state.refs = issue ? issue.references.map((r) => ({ path: r.path, lineStart: r.lineStart, lineEnd: r.lineEnd })) : [];
  $("#modalTitle").textContent = issue ? `Éditer ${issue.ref}` : "Nouvelle entrée";
  $("#mType").value = issue?.type || "bug";
  $("#mPriority").value = issue?.priority || "medium";
  $("#mStatus").value = issue?.status || "open";
  $("#mTitle").value = issue?.title || "";
  $("#mDesc").value = issue?.description || "";
  $("#mTags").value = (issue?.tags || []).join(", ");
  // Branche : celle de l'entrée éditée, sinon la branche de contexte (topbar).
  const branch = issue ? issue.branch || "" : state.branch || "";
  $("#mBranch").innerHTML = branchOptions(branch);
  $("#mBranch").value = branch;
  renderRefEditor();
  $("#backdrop").hidden = false;
  $("#mTitle").focus();
}

function closeModal() {
  $("#backdrop").hidden = true;
  hideMenu($("#mentionMenu"));
}

// Synchronise la liste de refs : on conserve les ajouts manuels + les @mentions.
function syncMentionsFromDesc() {
  const desc = $("#mDesc").value;
  const re = /@([A-Za-z0-9_./-]+(?::\d+(?:-\d+)?)?)/g;
  const mentioned = new Set();
  let m;
  while ((m = re.exec(desc)) !== null) {
    const spec = m[1];
    const mm = spec.match(/^(.*?):(\d+)(?:-(\d+))?$/);
    const path = mm ? mm[1] : spec;
    const lineStart = mm ? Number(mm[2]) : null;
    const lineEnd = mm && mm[3] ? Number(mm[3]) : null;
    const key = `${path}:${lineStart ?? ""}:${lineEnd ?? ""}`;
    mentioned.add(key);
    if (!state.refs.some((r) => `${r.path}:${r.lineStart ?? ""}:${r.lineEnd ?? ""}` === key))
      state.refs.push({ path, lineStart, lineEnd, fromMention: true });
  }
  // Retire les anciennes refs issues de mentions qui ne sont plus dans le texte.
  state.refs = state.refs.filter(
    (r) => !r.fromMention || mentioned.has(`${r.path}:${r.lineStart ?? ""}:${r.lineEnd ?? ""}`)
  );
  renderRefEditor();
}

// Affichage seul : les références sont entièrement dérivées des @mentions de la
// description (pour en retirer une, supprimer le @ correspondant dans le texte).
function renderRefEditor() {
  const ul = $("#refList");
  if (!state.refs.length) {
    ul.innerHTML = '<li class="empty" style="font-family:inherit">Aucun fichier associé (tape <kbd>@</kbd> dans la description).</li>';
    return;
  }
  ul.innerHTML = state.refs
    .map(
      (r) => `<li>
        <span class="path">${esc(r.path)}${r.lineStart ? `<span class="lines">:${r.lineStart}${r.lineEnd ? "-" + r.lineEnd : ""}</span>` : ""}</span>
      </li>`
    )
    .join("");
}

// Améliore la description courante via Claude (Sonnet), côté serveur (claude -p).
async function improveDescription() {
  const btn = $("#improveBtn");
  const desc = $("#mDesc");
  const base = desc.value.trim();
  if (!base) {
    alert("Écris d'abord une description à améliorer.");
    return;
  }
  const old = btn.textContent;
  btn.disabled = true;
  btn.textContent = "✨ Amélioration…";
  try {
    const r = await api.send("POST", "/api/improve-description", {
      title: $("#mTitle").value,
      description: base,
    });
    if (r.description) {
      desc.value = r.description;
      syncMentionsFromDesc(); // re-détecte les @chemin après réécriture
    }
  } catch (e) {
    alert("Échec de l'amélioration IA : " + e.message);
  } finally {
    btn.textContent = old;
    btn.disabled = false;
  }
}

async function saveIssue() {
  const payload = {
    type: $("#mType").value,
    priority: $("#mPriority").value,
    status: $("#mStatus").value,
    branch: $("#mBranch").value || undefined,
    title: $("#mTitle").value.trim(),
    description: $("#mDesc").value,
    tags: $("#mTags").value.split(",").map((s) => s.trim()).filter(Boolean),
    // On envoie la liste de refs explicite (remplace tout) + on désactive
    // l'auto-mention serveur pour ne pas dédoubler (la liste contient déjà les @).
    paths: state.refs.map((r) => (r.lineStart ? `${r.path}:${r.lineStart}${r.lineEnd ? "-" + r.lineEnd : ""}` : r.path)),
    autoMention: false,
  };
  if (!payload.title) {
    alert("Titre requis.");
    return;
  }
  try {
    const saved = state.editing
      ? await api.send("PATCH", "/api/issues/" + encodeURIComponent(state.editing.ref), payload)
      : await api.send("POST", "/api/issues", payload);
    closeModal();
    await Promise.all([loadList(), loadMeta()]);
    await selectIssue(saved.ref);
  } catch (e) {
    alert("Échec : " + e.message);
  }
}

// ── Autocomplete partagé (@ description + champ refs) ─────────────────────────
let menuState = { items: [], active: 0, target: null, kind: null };

function hideMenu(menu) {
  menu.hidden = true;
  menu.innerHTML = "";
}

function renderMenu(menu, items) {
  menuState.items = items;
  menuState.active = 0;
  if (!items.length) {
    hideMenu(menu);
    return;
  }
  menu.innerHTML = items
    .map((it, i) => {
      const slash = it.path.lastIndexOf("/");
      const dir = slash >= 0 ? it.path.slice(0, slash + 1) : "";
      const base = slash >= 0 ? it.path.slice(slash + 1) : it.path;
      return `<li class="${i === 0 ? "active" : ""}" data-i="${i}">
        <span class="kind">${it.kind === "dir" ? "📁" : "📄"}</span>
        <span><span class="dir">${esc(dir)}</span><span class="base">${esc(base)}</span></span>
      </li>`;
    })
    .join("");
  menu.hidden = false;
  menu.querySelectorAll("li").forEach((li) =>
    li.addEventListener("mousedown", (e) => {
      e.preventDefault();
      chooseMenuItem(Number(li.dataset.i));
    })
  );
}

let searchTimer = null;
function debouncedSearch(query, cb) {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(async () => {
    try {
      // L'autocomplete cible l'arbre de la branche de l'entrée en cours d'édition.
      const branch = $("#mBranch").value || "";
      const url =
        "/api/paths?q=" + encodeURIComponent(query) + "&limit=20" + (branch ? "&branch=" + encodeURIComponent(branch) : "");
      cb(await api.get(url));
    } catch {
      cb([]);
    }
  }, 120);
}

function chooseMenuItem(i) {
  const item = menuState.items[i];
  if (!item) return;
  // Remplace le token @… en cours par le chemin choisi (seule source de refs).
  const ta = $("#mDesc");
  const pos = ta.selectionStart;
  const before = ta.value.slice(0, pos);
  const at = before.lastIndexOf("@");
  ta.value = before.slice(0, at) + "@" + item.path + " " + ta.value.slice(pos);
  const newPos = at + 1 + item.path.length + 1;
  ta.setSelectionRange(newPos, newPos);
  ta.focus();
  hideMenu($("#mentionMenu"));
  syncMentionsFromDesc();
}

function moveMenu(menu, dir) {
  const lis = menu.querySelectorAll("li");
  if (!lis.length) return;
  lis[menuState.active]?.classList.remove("active");
  menuState.active = (menuState.active + dir + lis.length) % lis.length;
  lis[menuState.active]?.classList.add("active");
  lis[menuState.active]?.scrollIntoView({ block: "nearest" });
}

// Description : détecte un token @… juste avant le curseur.
function onDescInput() {
  syncMentionsFromDesc();
  const ta = $("#mDesc");
  const before = ta.value.slice(0, ta.selectionStart);
  const match = before.match(/@([A-Za-z0-9_./-]*)$/);
  const menu = $("#mentionMenu");
  if (!match) {
    hideMenu(menu);
    return;
  }
  menuState.kind = "desc";
  debouncedSearch(match[1], (items) => renderMenu(menu, items));
}

function menuKeydown(menu, e) {
  if (menu.hidden) return false;
  if (e.key === "ArrowDown") { e.preventDefault(); moveMenu(menu, 1); return true; }
  if (e.key === "ArrowUp") { e.preventDefault(); moveMenu(menu, -1); return true; }
  if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); chooseMenuItem(menuState.active); return true; }
  if (e.key === "Escape") { hideMenu(menu); return true; }
  return false;
}

// ── Wiring ───────────────────────────────────────────────────────────────────
function init() {
  $("#newBtn").addEventListener("click", () => openModal(null));
  $("#updateBtn").addEventListener("click", (e) => updateRepo(e.currentTarget));
  $("#cancelBtn").addEventListener("click", closeModal);
  $("#saveBtn").addEventListener("click", saveIssue);
  $("#backdrop").addEventListener("mousedown", (e) => {
    if (e.target === $("#backdrop")) closeModal();
  });

  let filterTimer = null;
  const onFilter = () => {
    clearTimeout(filterTimer);
    filterTimer = setTimeout(loadList, 180);
  };
  $("#search").addEventListener("input", onFilter);
  ["#fType", "#fStatus", "#fPriority"].forEach((s) => $(s).addEventListener("change", loadList));
  // Sélecteur de branche (topbar) : filtre la liste + défaut des nouvelles entrées.
  $("#branchSel").addEventListener("change", (e) => {
    state.branch = e.target.value;
    loadList();
  });

  const desc = $("#mDesc");
  desc.addEventListener("input", onDescInput);
  desc.addEventListener("keydown", (e) => menuKeydown($("#mentionMenu"), e));
  desc.addEventListener("blur", () => setTimeout(() => hideMenu($("#mentionMenu")), 150));

  // Changer la branche dans la modale ré-cible l'autocomplete @ (rien d'autre à faire).
  $("#improveBtn").addEventListener("click", improveDescription);

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !$("#backdrop").hidden) closeModal();
  });

  loadMeta();
  loadBranches();
  loadList();
}

document.addEventListener("DOMContentLoaded", init);

// ═══════════════════════════════════════════════════════════════════════════
// Good Vibes v2 — arbre de NŒUDS récursif, graphe organique, chat IA streaming.
// Réutilise les helpers du Suivi ($/esc/api/getToken). N'altère PAS init().
// ═══════════════════════════════════════════════════════════════════════════

const NODE_STATUS_LABEL = { active: "🌱 Actif", paused: "⏸️ En pause", done: "🏆 Atteint", abandoned: "🪦 Abandonné" };
const NODE_COLORS = ["accent", "feature", "task", "bug", "high"];

const vibes = {
  view: "track",
  layout: localStorage.getItem("meowtrack_layout") || "graph", // graph | grid
  es: null,
  current: null, // ref du nœud ouvert (détail)
  currentNode: null,
  currentVersion: null,
  forest: [],
  byId: new Map(),
  seen: new Set(), // ids de messages rendus
  streams: new Map(), // turnId → { reasoning, text, reasoningEl, bodyEl }
  dirtyTimer: null,
  forestTimer: null,
  model: "sonnet",
  user: "",
  wasDown: false,
  _editing: null,
  _color: "accent",
  graph: { view: { x: 0, y: 0, w: 1000, h: 700 }, drag: null, userView: false, spawned: new Set() },
};

// ── Identité / utilitaires ───────────────────────────────────────────────────
function userName() {
  let u = localStorage.getItem("meowtrack_user");
  if (!u) {
    u = (window.prompt("Ton pseudo (visible dans les chats) :", "") || "anon").trim() || "anon";
    localStorage.setItem("meowtrack_user", u);
  }
  return u;
}
function changeUser() {
  const u = (window.prompt("Ton pseudo :", vibes.user) || "").trim();
  if (u) {
    vibes.user = u;
    localStorage.setItem("meowtrack_user", u);
    $("#userName").textContent = u;
  }
}
function authorColor(n) {
  let h = 0;
  for (const c of String(n)) h = (h * 31 + c.charCodeAt(0)) % 360;
  return `hsl(${h} 60% 66%)`;
}
const cssId = (s) => (window.CSS && CSS.escape ? CSS.escape(String(s)) : String(s).replace(/[^A-Za-z0-9_-]/g, "\\$&"));

let toastTimer = null;
function toast(msg) {
  let t = $("#gvToast");
  if (!t) {
    t = document.createElement("div");
    t.id = "gvToast";
    t.className = "toast";
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 4000);
}

// ── Index de forêt ───────────────────────────────────────────────────────────
function indexForest(list) {
  vibes.forest = list || [];
  vibes.byId = new Map(vibes.forest.map((n) => [n.id, n]));
}
function childrenOf(id) {
  return vibes.forest.filter((n) => n.parentId === id).sort((a, b) => a.position - b.position || a.id - b.id);
}
function rootsOf() {
  return vibes.forest.filter((n) => n.parentId == null).sort((a, b) => a.position - b.position || a.id - b.id);
}
function leafCount(n) {
  const k = childrenOf(n.id);
  return k.length ? k.reduce((s, c) => s + leafCount(c), 0) : 1;
}
function subtreeMaxDepth(n) {
  const k = childrenOf(n.id);
  return k.length ? 1 + Math.max(...k.map(subtreeMaxDepth)) : 0;
}

// ── Navigation entre vues ────────────────────────────────────────────────────
function switchView(v) {
  vibes.view = v;
  document.body.classList.toggle("view-vibes", v === "vibes");
  document.body.classList.toggle("view-track", v !== "vibes");
  document.querySelectorAll(".nav-tabs .tab").forEach((t) => t.classList.toggle("active", t.dataset.view === v));
  $("#trackView").hidden = v !== "track";
  if (v === "vibes") {
    if (location.hash !== "#vibes") location.hash = "#vibes";
    openVibes();
  } else {
    if (location.hash === "#vibes") location.hash = "";
    $("#vibesBar").hidden = true;
    $("#vibesView").hidden = true;
    $("#graphView").hidden = true;
    $("#nodeView").hidden = true;
    closeStream();
  }
}

async function openVibes() {
  $("#nodeView").hidden = true;
  $("#vibesBar").hidden = false;
  vibes.current = null;
  vibes.currentNode = null;
  applyLayoutToggle();
  await loadForest();
  subscribeForest();
}

function setVibesLayout(l) {
  vibes.layout = l;
  localStorage.setItem("meowtrack_layout", l);
  document.querySelectorAll(".seg-toggle .seg").forEach((b) => b.classList.toggle("active", b.dataset.layout === l));
  if (!vibes.current) applyLayoutToggle();
}
function applyLayoutToggle() {
  if (vibes.current) return; // en détail
  const graph = vibes.layout === "graph";
  $("#graphView").hidden = !graph;
  $("#vibesView").hidden = graph;
  document.querySelectorAll(".seg-toggle .seg").forEach((b) => b.classList.toggle("active", b.dataset.layout === vibes.layout));
}

// ── Chargement forêt + rendu des deux vues ───────────────────────────────────
async function loadForest() {
  try {
    indexForest(await api.get("/api/nodes?view=forest"));
    renderForestViews();
  } catch (e) {
    $("#graphSvg") && ($("#vibesSummary").textContent = "Erreur : " + e.message);
  }
}
function renderForestViews() {
  renderGrid();
  renderGraph();
  const roots = rootsOf().length;
  $("#vibesSummary").textContent = `· ${roots} objectif${roots > 1 ? "s" : ""} · ${vibes.forest.length} nœud${vibes.forest.length > 1 ? "s" : ""}`;
}
let _forestRaf = null;
function renderForestSoon() {
  if (_forestRaf) return;
  _forestRaf = requestAnimationFrame(() => {
    _forestRaf = null;
    if (!vibes.current) renderForestViews();
  });
}

// ── Grille (racines) ─────────────────────────────────────────────────────────
function nodeCardHtml(n) {
  return `<div class="goal-card status-${esc(n.status)}" data-ref="${esc(n.ref)}" style="--gc:var(--${esc(n.color || "accent")})">
    <div class="gc-top"><span class="gc-emoji">${esc(n.emoji || "🎯")}</span><span class="gc-title">${esc(n.title)}</span></div>
    <div class="gc-ref">${esc(n.ref)}${n.targetDate ? ` · 📅 ${esc(n.targetDate)}` : ""}</div>
    <div class="gc-bar"><div class="gc-fill" style="width:${n.progress}%"></div></div>
    <div class="gc-foot"><span>${n.progress}%</span><span>${n.childCount} sous-nœud${n.childCount > 1 ? "s" : ""}</span><span>${esc(NODE_STATUS_LABEL[n.status] || n.status)}</span></div>
  </div>`;
}
function renderGrid() {
  const wrap = $("#goalCards");
  if (!wrap) return;
  wrap.innerHTML = rootsOf().map(nodeCardHtml).join("") + `<div class="goal-card ghost-card" id="ghostAddNode">＋ Nouvel objectif</div>`;
  wrap.querySelectorAll(".goal-card[data-ref]").forEach((c) => c.addEventListener("click", () => openNode(c.dataset.ref)));
  $("#ghostAddNode").addEventListener("click", () => openNodeModal(null, null));
}

// ── Graphe organique (SVG radial, créé via DOM API : anti-XSS) ───────────────
const NS = "http://www.w3.org/2000/svg";
const G_STEP = 140; // rayon par niveau de profondeur
const G_ROOT_GAP = 160;

function computeGraphLayout() {
  const pos = new Map();
  let cursorX = 0;
  for (const root of rootsOf()) {
    const r = Math.max(1, subtreeMaxDepth(root)) * G_STEP;
    assignAngles(root, 0, Math.PI * 2, pos, cursorX + r, 0);
    cursorX += r * 2 + G_ROOT_GAP;
  }
  return pos;
}
function assignAngles(node, a0, a1, pos, cx, cy) {
  const ang = (a0 + a1) / 2;
  pos.set(node.id, { x: cx + Math.cos(ang) * node.depth * G_STEP, y: cy + Math.sin(ang) * node.depth * G_STEP });
  const kids = childrenOf(node.id);
  if (!kids.length) return;
  const tot = kids.reduce((s, k) => s + leafCount(k), 0) || kids.length;
  let a = a0;
  for (const k of kids) {
    const f = (leafCount(k) || 1) / tot;
    const na = a + (a1 - a0) * f;
    assignAngles(k, a, na, pos, cx, cy);
    a = na;
  }
}
function svgEl(tag, attrs) {
  const el = document.createElementNS(NS, tag);
  for (const k in attrs) el.setAttribute(k, attrs[k]);
  return el;
}
function edgePath(p, c, node) {
  const dx = c.x - p.x, dy = c.y - p.y;
  const len = Math.hypot(dx, dy) || 1;
  const nx = -dy / len, ny = dx / len;
  const off = Math.min(45, len * 0.18);
  const c1x = p.x + dx * 0.35 + nx * off, c1y = p.y + dy * 0.35 + ny * off;
  const c2x = p.x + dx * 0.65 + nx * off, c2y = p.y + dy * 0.65 + ny * off;
  const el = svgEl("path", {
    d: `M ${p.x} ${p.y} C ${c1x} ${c1y}, ${c2x} ${c2y}, ${c.x} ${c.y}`,
    class: "g-edge" + (vibes.graph.spawned.has(node.id) ? " spawn" : ""),
    "data-cid": String(node.id),
    stroke: `var(--${node.color || "accent"})`,
  });
  return el;
}
function nodeGroup(n, p) {
  const r = n.depth === 0 ? 26 : Math.max(12, 24 - n.depth * 3);
  const spawn = vibes.graph.spawned.has(n.id);
  const g = svgEl("g", { transform: `translate(${p.x},${p.y})`, class: "g-node status-" + n.status + (spawn ? " spawn" : ""), "data-ref": n.ref, "data-id": String(n.id) });
  // Groupe interne mis à l'échelle pour l'anim d'apparition (le translate reste sur g).
  const inner = svgEl("g", { class: "g-inner" });
  const circ = 2 * Math.PI * (r + 5);
  inner.appendChild(svgEl("circle", { r: r + 5, class: "g-track" }));
  inner.appendChild(svgEl("circle", { r: r + 5, class: "g-ring", "stroke-dasharray": `${(circ * n.progress) / 100} ${circ}`, transform: "rotate(-90)" }));
  inner.appendChild(svgEl("circle", { r, class: "g-disc", fill: `var(--${n.color || "accent"})` }));
  const emo = svgEl("text", { class: "g-emoji", "text-anchor": "middle", dy: "0.35em", "font-size": String(Math.round(r)) });
  emo.textContent = n.emoji || "🎯";
  inner.appendChild(emo);
  const lbl = svgEl("text", { class: "g-label", "text-anchor": "middle", y: String(r + 18) });
  lbl.textContent = n.title.length > 22 ? n.title.slice(0, 21) + "…" : n.title;
  inner.appendChild(lbl);
  g.appendChild(inner);
  return g;
}
function renderGraph() {
  const svg = $("#graphSvg");
  if (!svg || $("#graphView").hidden) return;
  const pos = computeGraphLayout();
  while (svg.firstChild) svg.removeChild(svg.firstChild);
  const gEdges = svgEl("g", { class: "g-edges" });
  const gNodes = svgEl("g", { class: "g-nodes" });
  svg.appendChild(gEdges);
  svg.appendChild(gNodes);
  for (const n of vibes.forest) {
    if (n.parentId == null) continue;
    const pp = pos.get(n.parentId), pc = pos.get(n.id);
    if (pp && pc) gEdges.appendChild(edgePath(pp, pc, n));
  }
  for (const n of vibes.forest) {
    const pp = pos.get(n.id);
    if (pp) gNodes.appendChild(nodeGroup(n, pp));
  }
  if (!rootsOf().length) {
    const t = svgEl("text", { x: "0", y: "0", "text-anchor": "middle", class: "g-empty" });
    t.textContent = "Aucun objectif — clique « + Nouvel objectif »";
    gNodes.appendChild(t);
  }
  if (!vibes.graph.userView) fitView(pos, svg);
  else applyViewBox(svg);
  if (vibes.graph.spawned.size) setTimeout(() => vibes.graph.spawned.clear(), 800);
}
function fitView(pos, svg) {
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  for (const p of pos.values()) {
    minX = Math.min(minX, p.x); minY = Math.min(minY, p.y);
    maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y);
  }
  if (!isFinite(minX)) { minX = -200; minY = -150; maxX = 200; maxY = 150; }
  const pad = 90;
  vibes.graph.view = { x: minX - pad, y: minY - pad, w: maxX - minX + pad * 2, h: maxY - minY + pad * 2 };
  applyViewBox(svg);
}
function applyViewBox(svg) {
  const v = vibes.graph.view;
  svg.setAttribute("viewBox", `${v.x} ${v.y} ${v.w} ${v.h}`);
}
function wireGraph() {
  const svg = $("#graphSvg");
  svg.addEventListener("click", (e) => {
    const g = e.target.closest(".g-node");
    if (g) openNode(g.dataset.ref);
  });
  svg.addEventListener("wheel", (e) => {
    e.preventDefault();
    const v = vibes.graph.view;
    const rect = svg.getBoundingClientRect();
    const mx = v.x + ((e.clientX - rect.left) / rect.width) * v.w;
    const my = v.y + ((e.clientY - rect.top) / rect.height) * v.h;
    const f = e.deltaY < 0 ? 0.88 : 1.14;
    v.w *= f; v.h *= f;
    v.x = mx - ((e.clientX - rect.left) / rect.width) * v.w;
    v.y = my - ((e.clientY - rect.top) / rect.height) * v.h;
    vibes.graph.userView = true;
    applyViewBox(svg);
  }, { passive: false });
  svg.addEventListener("mousedown", (e) => {
    if (e.target.closest(".g-node")) return;
    vibes.graph.drag = { x: e.clientX, y: e.clientY, vx: vibes.graph.view.x, vy: vibes.graph.view.y };
  });
  window.addEventListener("mousemove", (e) => {
    const d = vibes.graph.drag;
    if (!d) return;
    const svg2 = $("#graphSvg");
    const rect = svg2.getBoundingClientRect();
    const v = vibes.graph.view;
    v.x = d.vx - ((e.clientX - d.x) / rect.width) * v.w;
    v.y = d.vy - ((e.clientY - d.y) / rect.height) * v.h;
    vibes.graph.userView = true;
    applyViewBox(svg2);
  });
  window.addEventListener("mouseup", () => (vibes.graph.drag = null));
  $("#graphFit").addEventListener("click", () => {
    vibes.graph.userView = false;
    renderGraph();
  });
}

// ── Vue détail d'un nœud ─────────────────────────────────────────────────────
function nodeUrl(suffix) {
  return `/api/nodes/${encodeURIComponent(vibes.current)}${suffix || ""}`;
}
async function openNode(ref) {
  try {
    closeStream();
    const node = await api.get(`/api/nodes/${encodeURIComponent(ref)}?tree=true&messages=true`);
    vibes.current = ref;
    vibes.currentNode = node;
    vibes.currentVersion = node.version;
    $("#vibesBar").hidden = true;
    $("#vibesView").hidden = true;
    $("#graphView").hidden = true;
    $("#nodeView").hidden = false;
    $("#modelSel").value = vibes.model;
    renderNodeHeader(node);
    renderTree(node);
    renderChat(node.messages || []);
    subscribeNode(ref);
  } catch (e) {
    toast("Erreur : " + e.message);
  }
}
function renderNodeHeader(n) {
  $("#ndEmoji").textContent = n.emoji || "🎯";
  $("#ndTitle").textContent = n.title;
  $("#ndRef").textContent = n.ref;
  $("#ndStatus").textContent = NODE_STATUS_LABEL[n.status] || n.status;
  $("#ndBar").style.width = n.progress + "%";
  $("#ndPct").textContent = n.progress + "%";
  const tgt = $("#ndTarget");
  if (n.targetDate) { tgt.textContent = "📅 " + n.targetDate; tgt.hidden = false; } else tgt.hidden = true;
  const desc = $("#ndDesc");
  desc.textContent = n.description || "";
  desc.hidden = !n.description;
}
// Arbre récursif des sous-nœuds (chaque ligne ouvre son propre chat).
function treeHtml(n, depth) {
  const kids = n.children || [];
  const childrenHtml = kids.map((k) => treeHtml(k, depth + 1)).join("");
  return `<li class="tnode" data-ref="${esc(n.ref)}" data-id="${n.id}" style="--d:${depth}">
    <div class="trow ms-${esc(n.status)}">
      <span class="tdot" style="background:var(--${esc(n.color || "accent")})"></span>
      <span class="temoji">${esc(n.emoji || "🎯")}</span>
      <span class="ttitle" title="Ouvrir le chat de ce nœud">${esc(n.title)}</span>
      <span class="tpct">${n.progress}%</span>
      <select class="tstatus" title="Statut">${["active", "paused", "done", "abandoned"].map((s) => `<option value="${s}" ${s === n.status ? "selected" : ""}>${esc(NODE_STATUS_LABEL[s])}</option>`).join("")}</select>
      <button class="tadd" title="Ajouter un sous-jalon">＋</button>
      <button class="tdel danger" title="Supprimer">🗑</button>
    </div>
    ${childrenHtml ? `<ul class="tchildren">${childrenHtml}</ul>` : ""}
  </li>`;
}
function renderTree(node) {
  const wrap = $("#nodeTree");
  const kids = node.children || [];
  wrap.innerHTML = kids.length
    ? `<ul class="tree-root">${kids.map((k) => treeHtml(k, 0)).join("")}</ul>`
    : `<div class="empty">Aucun sous-jalon. Ajoute-en un, ou demande à Claude.</div>`;
  wrap.querySelectorAll(".tnode").forEach((li) => {
    const ref = li.dataset.ref;
    const id = Number(li.dataset.id);
    const row = li.querySelector(":scope > .trow");
    row.querySelector(".ttitle").addEventListener("click", () => openNode(ref));
    row.querySelector(".tstatus").addEventListener("change", (e) => patchNode(id, { status: e.target.value }));
    row.querySelector(".tadd").addEventListener("click", () => openNodeModal(null, id));
    row.querySelector(".tdel").addEventListener("click", () => {
      if (confirm("Supprimer ce nœud et tout son sous-arbre ?")) deleteNodeById(id);
    });
  });
}

// Réconcilie le nœud courant reçu en live (par version monotone) + re-fetch arbre.
function applyNodeUpdate(n) {
  if (!n || !vibes.current) return;
  if (vibes.currentNode && n.id === vibes.currentNode.id) {
    if (vibes.currentVersion != null && n.version != null && n.version < vibes.currentVersion) return;
    vibes.currentVersion = n.version;
    Object.assign(vibes.currentNode, n);
    renderNodeHeader(vibes.currentNode);
  }
}
function scheduleSubtreeRefetch() {
  clearTimeout(vibes.dirtyTimer);
  vibes.dirtyTimer = setTimeout(async () => {
    if (!vibes.current) return;
    try {
      const node = await api.get(nodeUrl("?tree=true"));
      vibes.currentNode = node;
      vibes.currentVersion = node.version;
      renderNodeHeader(node);
      renderTree(node);
    } catch {
      /* ignore */
    }
  }, 250);
}

async function patchNode(id, fields) {
  try {
    const ref = (vibes.byId.get(id) || {}).ref || id;
    const n = await api.send("PATCH", `/api/nodes/${encodeURIComponent(ref)}`, fields);
    applyNodeUpdate(n);
    scheduleSubtreeRefetch();
  } catch (e) {
    toast(e.message);
  }
}
async function deleteNodeById(id) {
  try {
    const ref = (vibes.byId.get(id) || {}).ref || id;
    await api.send("DELETE", `/api/nodes/${encodeURIComponent(ref)}`);
    if (vibes.currentNode && id === vibes.currentNode.id) {
      // on a supprimé le nœud courant → remonter à la forêt
      backToForest();
    } else scheduleSubtreeRefetch();
  } catch (e) {
    toast(e.message);
  }
}
async function deleteCurrentNode() {
  if (!vibes.currentNode) return;
  if (!confirm(`Supprimer ${vibes.currentNode.ref} et tout son sous-arbre ?`)) return;
  await deleteNodeById(vibes.currentNode.id);
}
function backToForest() {
  closeStream();
  vibes.current = null;
  vibes.currentNode = null;
  $("#nodeView").hidden = true;
  $("#vibesBar").hidden = false;
  applyLayoutToggle();
  loadForest();
  subscribeForest();
}

// ── Chat streaming ───────────────────────────────────────────────────────────
function opLabel(o) {
  switch (o.op) {
    case "set_node_fields":
    case "update_node": return "✎ nœud" + (o.id ? " #" + o.id : "");
    case "add_node": return "➕ " + (o.title || "nœud");
    case "delete_node": return "🗑 nœud supprimé";
    case "move_node": return "↦ déplacé";
    case "reorder_children": return "↕ réordonné";
    default: return o.op || "action";
  }
}
function actionChipsHtml(m) {
  if (!Array.isArray(m.actions) || !m.actions.length) return "";
  const entry = m.actions[0] || {};
  const ops = entry.ops || [];
  if (!ops.length && !entry.proposed) return "";
  const chips = ops.map((o) => `<span class="action-chip${o.op === "delete_node" ? " danger" : ""}">${esc(opLabel(o))}</span>`).join("");
  const confirm = entry.proposed ? `<button class="confirm-actions" type="button">Confirmer</button>` : "";
  return `<div class="action-chips">${chips}${confirm}</div>`;
}
function messageEl(m) {
  const div = document.createElement("div");
  const mine = m.role !== "assistant" && m.author === vibes.user;
  const streaming = m.state === "pending" || m.state === "streaming";
  div.className = "msg" + (m.role === "assistant" ? " ai" : mine ? " mine" : "") + (streaming ? " streaming" : "") + (m.state === "error" ? " error" : "");
  if (m.id) div.dataset.mid = String(m.id);
  if (m.clientNonce) div.dataset.nonce = m.clientNonce;
  const who = m.role === "assistant" ? `🤖 Claude${m.model ? " · " + esc(m.model) : ""}` : esc(m.author || "anon");
  const color = m.role === "assistant" ? "var(--accent)" : authorColor(m.author || "anon");

  const head = document.createElement("div");
  head.className = "msg-head";
  head.style.color = color;
  head.textContent = "";
  head.innerHTML = who;
  div.appendChild(head);

  // Zone réflexion repliable (repliée par défaut) — pour l'IA.
  let reasoningBody = null;
  if (m.role === "assistant") {
    const det = document.createElement("details");
    det.className = "msg-reasoning";
    const sum = document.createElement("summary");
    sum.textContent = "💭 Réflexion";
    det.appendChild(sum);
    reasoningBody = document.createElement("div");
    reasoningBody.className = "reasoning-body";
    reasoningBody.textContent = m.reasoning || "";
    det.appendChild(reasoningBody);
    if (!m.reasoning && !streaming) det.hidden = true; // pas de réflexion → masqué
    div.appendChild(det);
  }

  const body = document.createElement("div");
  body.className = "msg-body";
  if (streaming) {
    body.textContent = m.body || "";
    if (!m.body) {
      const dots = document.createElement("span");
      dots.className = "dots";
      dots.textContent = "Claude rédige";
      body.appendChild(dots);
    }
    if (m.id) vibes.streams.set(m.id, { reasoning: m.reasoning || "", text: m.body || "", reasoningEl: reasoningBody, bodyEl: body });
  } else {
    body.innerHTML = esc(m.body || "").replace(/\n/g, "<br>");
    if (m.id) vibes.streams.delete(m.id);
  }
  div.appendChild(body);

  if (!streaming) {
    const chips = actionChipsHtml(m);
    if (chips) {
      const c = document.createElement("div");
      c.innerHTML = chips;
      const node = c.firstElementChild;
      const btn = node.querySelector(".confirm-actions");
      if (btn && m.id) btn.addEventListener("click", () => confirmActions(m.id));
      div.appendChild(node);
    }
  }
  return div;
}
function appendMessage(m) {
  const feed = $("#chatFeed");
  if (!feed) return;
  const emptyEl = feed.querySelector(".empty");
  if (emptyEl) emptyEl.remove();
  if (m.id) {
    const existing = feed.querySelector(`[data-mid="${cssId(m.id)}"]`);
    if (existing) {
      existing.replaceWith(messageEl(m));
      scrollFeed();
      return;
    }
  }
  if (m.clientNonce) {
    const pend = feed.querySelector(`[data-nonce="${cssId(m.clientNonce)}"]`);
    if (pend) {
      pend.replaceWith(messageEl(m));
      if (m.id) vibes.seen.add(m.id);
      scrollFeed();
      return;
    }
  }
  if (m.id && vibes.seen.has(m.id)) return;
  if (m.id) vibes.seen.add(m.id);
  feed.appendChild(messageEl(m));
  scrollFeed();
}
function onStreamDelta(d) {
  const s = vibes.streams.get(d.turnId);
  if (!s) return;
  if (d.kind === "thinking") {
    s.reasoning += d.delta;
    if (s.reasoningEl) {
      s.reasoningEl.textContent = s.reasoning;
      const det = s.reasoningEl.closest("details");
      if (det) det.hidden = false;
    }
  } else if (d.kind === "text") {
    s.text += d.delta;
    if (s.bodyEl) s.bodyEl.textContent = s.text;
  }
  scrollFeed();
}
function renderChat(messages) {
  const feed = $("#chatFeed");
  feed.innerHTML = "";
  vibes.seen.clear();
  vibes.streams.clear();
  if (!messages.length) feed.innerHTML = `<div class="empty">Discute de ce nœud : décris-le, demande des sous-jalons…</div>`;
  for (const m of messages) appendMessage(m);
  scrollFeed();
}
function scrollFeed() {
  const feed = $("#chatFeed");
  if (feed) feed.scrollTop = feed.scrollHeight;
}
async function sendChat() {
  const ta = $("#chatInput");
  const text = ta.value.trim();
  if (!text || !vibes.current) return;
  const nonce = crypto.randomUUID ? crypto.randomUUID() : "n" + Date.now() + Math.floor(Math.random() * 1e6);
  appendMessage({ id: 0, role: "user", author: vibes.user, body: text, state: "complete", clientNonce: nonce });
  ta.value = "";
  try {
    await api.send("POST", nodeUrl("/chat"), { author: vibes.user, model: vibes.model, body: text, clientNonce: nonce });
  } catch (e) {
    if (/ai_busy/.test(e.message)) toast("Claude répond déjà sur ce nœud — attends la fin du tour.");
    else if (/ai_overloaded/.test(e.message)) toast("Trop de discussions IA en cours, réessaie dans un instant.");
    else toast("Échec : " + e.message);
    const feed = $("#chatFeed");
    feed?.querySelector(`[data-nonce="${cssId(nonce)}"]`)?.remove();
    ta.value = text;
  }
}
async function confirmActions(messageId) {
  try {
    await api.send("POST", nodeUrl("/chat/confirm"), { messageId });
  } catch (e) {
    toast(e.message);
  }
}

// ── Temps réel (SSE) ─────────────────────────────────────────────────────────
function setLive(on) {
  document.querySelectorAll(".live-dot").forEach((d) => d.classList.toggle("on", !!on));
}
function streamUrl(p) {
  return p + (getToken() ? (p.includes("?") ? "&" : "?") + "token=" + encodeURIComponent(getToken()) : "");
}
function closeStream() {
  if (vibes.es) {
    try { vibes.es.close(); } catch { /* ignore */ }
    vibes.es = null;
  }
  setLive(false);
}
function subscribeForest() {
  closeStream();
  const es = new EventSource(streamUrl("/api/nodes/stream"));
  vibes.es = es;
  es.onopen = () => { setLive(true); if (vibes.wasDown) loadForest(); vibes.wasDown = false; };
  es.onerror = () => { setLive(false); vibes.wasDown = true; };
  const upsert = (n, spawn) => {
    if (!n) return;
    const ex = vibes.byId.get(n.id);
    if (ex) Object.assign(ex, n);
    else { vibes.forest.push(n); vibes.byId.set(n.id, n); }
    if (spawn) vibes.graph.spawned.add(n.id);
    renderForestSoon();
  };
  es.addEventListener("node:created", (e) => upsert(JSON.parse(e.data), true));
  es.addEventListener("node:updated", (e) => upsert(JSON.parse(e.data), false));
  es.addEventListener("node:deleted", () => loadForest());
  es.addEventListener("node:reparented", () => loadForest());
  es.addEventListener("nodes:reordered", () => loadForest());
}
function subscribeNode(ref) {
  closeStream();
  const es = new EventSource(streamUrl(`/api/nodes/${encodeURIComponent(ref)}/stream`));
  vibes.es = es;
  es.onopen = () => { setLive(true); if (vibes.wasDown && vibes.current === ref) openNode(ref); vibes.wasDown = false; };
  es.onerror = () => { setLive(false); vibes.wasDown = true; };
  es.addEventListener("message", (e) => appendMessage(JSON.parse(e.data)));
  es.addEventListener("ai:stream", (e) => onStreamDelta(JSON.parse(e.data)));
  es.addEventListener("ai:turn", (e) => { const d = JSON.parse(e.data); $("#typingRow").hidden = d.state !== "start"; if (d.state === "start") $("#typingRow").textContent = `✨ ${d.actor ? d.actor + " — " : ""}Claude travaille…`; });
  es.addEventListener("node:updated", (e) => applyNodeUpdate(JSON.parse(e.data)));
  es.addEventListener("subtree:dirty", () => scheduleSubtreeRefetch());
  es.addEventListener("node:deleted", (e) => {
    const d = JSON.parse(e.data);
    if (vibes.currentNode && d.id === vibes.currentNode.id) { toast("Ce nœud a été supprimé."); backToForest(); }
    else scheduleSubtreeRefetch();
  });
}

// ── Modale nœud (création / édition) ─────────────────────────────────────────
function buildColorChips() {
  const wrap = $("#nColors");
  wrap.innerHTML = NODE_COLORS.map((c) => `<button type="button" class="color-chip" data-color="${c}" style="background:var(--${c})" title="${c}"></button>`).join("");
  wrap.querySelectorAll(".color-chip").forEach((chip) =>
    chip.addEventListener("click", () => {
      vibes._color = chip.dataset.color;
      wrap.querySelectorAll(".color-chip").forEach((c) => c.classList.toggle("sel", c === chip));
    })
  );
}
function selectColorChip(color) {
  vibes._color = NODE_COLORS.includes(color) ? color : "accent";
  $("#nColors").querySelectorAll(".color-chip").forEach((c) => c.classList.toggle("sel", c.dataset.color === vibes._color));
}
// node=édition ; parentId=création d'un enfant ; les deux null = nouvelle racine.
function openNodeModal(node, parentId) {
  vibes._editing = node || null;
  vibes._parentId = node ? null : parentId != null ? parentId : null;
  $("#nodeModalTitle").textContent = node ? `Éditer ${node.ref}` : parentId != null ? "Nouveau sous-jalon" : "Nouvel objectif";
  $("#nEmoji").value = node?.emoji || "🎯";
  $("#nStatus").value = node?.status || "active";
  $("#nTarget").value = node?.targetDate || "";
  $("#nTitle").value = node?.title || "";
  $("#nDesc").value = node?.description || "";
  selectColorChip(node?.color || "accent");
  $("#nodeBackdrop").hidden = false;
  $("#nTitle").focus();
}
async function saveNode() {
  const payload = {
    emoji: $("#nEmoji").value.trim() || "🎯",
    status: $("#nStatus").value,
    targetDate: $("#nTarget").value || null,
    title: $("#nTitle").value.trim(),
    description: $("#nDesc").value,
    color: vibes._color,
  };
  if (!payload.title) { toast("Titre requis."); return; }
  try {
    if (vibes._editing) {
      payload.expectedVersion = vibes._editing.version;
      const n = await api.send("PATCH", `/api/nodes/${encodeURIComponent(vibes._editing.ref)}`, payload);
      $("#nodeBackdrop").hidden = true;
      applyNodeUpdate(n);
      scheduleSubtreeRefetch();
      if (!vibes.current) loadForest();
    } else {
      if (vibes._parentId != null) payload.parentId = vibes._parentId;
      const n = await api.send("POST", "/api/nodes", payload);
      $("#nodeBackdrop").hidden = true;
      if (vibes.current) scheduleSubtreeRefetch();
      else { vibes.layout === "graph" ? openNode(n.ref) : loadForest(); }
    }
  } catch (e) {
    if (/version_conflict/.test(e.message)) toast("Nœud modifié entre-temps — rouvre-le.");
    else toast("Échec : " + e.message);
  }
}

// ── Wiring ───────────────────────────────────────────────────────────────────
function initVibes() {
  vibes.user = userName();
  $("#userName").textContent = vibes.user;
  $("#userBtn").addEventListener("click", changeUser);
  document.querySelectorAll(".nav-tabs .tab").forEach((t) => t.addEventListener("click", () => switchView(t.dataset.view)));
  document.querySelectorAll(".seg-toggle .seg").forEach((b) => b.addEventListener("click", () => setVibesLayout(b.dataset.layout)));
  $("#newNodeBtn").addEventListener("click", () => openNodeModal(null, null));
  $("#ndBack").addEventListener("click", backToForest);
  $("#ndEdit").addEventListener("click", () => openNodeModal(vibes.currentNode, null));
  $("#ndDel").addEventListener("click", deleteCurrentNode);
  $("#ndAddChild").addEventListener("click", () => openNodeModal(null, vibes.currentNode ? vibes.currentNode.id : null));
  $("#chatSend").addEventListener("click", sendChat);
  $("#chatInput").addEventListener("keydown", (e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendChat(); } });
  $("#modelSel").addEventListener("change", (e) => (vibes.model = e.target.value));
  $("#nodeCancelBtn").addEventListener("click", () => ($("#nodeBackdrop").hidden = true));
  $("#nodeSaveBtn").addEventListener("click", saveNode);
  $("#nodeBackdrop").addEventListener("mousedown", (e) => { if (e.target === $("#nodeBackdrop")) $("#nodeBackdrop").hidden = true; });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !$("#nodeBackdrop").hidden) $("#nodeBackdrop").hidden = true; });
  buildColorChips();
  wireGraph();
  setVibesLayout(vibes.layout);
  window.addEventListener("beforeunload", closeStream);
  window.addEventListener("hashchange", () => switchView(location.hash === "#vibes" ? "vibes" : "track"));
  document.body.classList.add("view-track");
  if (location.hash === "#vibes") switchView("vibes");
}
document.addEventListener("DOMContentLoaded", initVibes);
