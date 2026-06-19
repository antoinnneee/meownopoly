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

// ── Repo actif (multi-repos) ─────────────────────────────────────────────────
// Slug du repo courant, persisté localement. Injecté en `?repo=` sur toutes les
// requêtes /api/* SAUF la gestion du registre (/api/repos*, qui cible par chemin).
function activeRepo() {
  return localStorage.getItem("meowtrack_repo") || "";
}
function setActiveRepo(slug) {
  localStorage.setItem("meowtrack_repo", slug || "");
}
function injectRepo(url) {
  if (!url.startsWith("/api/") || url.startsWith("/api/repos")) return url;
  const r = activeRepo();
  if (!r) return url;
  return url + (url.includes("?") ? "&" : "?") + "repo=" + encodeURIComponent(r);
}

const api = {
  async _do(method, url, body, retried) {
    const r = await fetch(injectRepo(url), {
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

let state = { issues: [], selected: null, editing: null, refs: [], branch: "", branches: [], serverBranch: null, repos: [] };

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

// Charge le registre des repos → sélecteur topbar. Fixe le repo actif (stocké,
// sinon le repo par défaut du serveur). Renvoie la liste.
async function loadRepos() {
  try {
    const repos = await api.get("/api/repos");
    state.repos = repos || [];
    const sel = $("#repoSel");
    if (sel) {
      sel.innerHTML = state.repos.map((r) => `<option value="${esc(r.slug)}">${esc(r.name || r.slug)}</option>`).join("");
      // Repo actif : celui stocké s'il existe encore, sinon le repo par défaut.
      let cur = activeRepo();
      if (!cur || !state.repos.some((r) => r.slug === cur)) {
        const def = state.repos.find((r) => r.isDefault) || state.repos[0];
        cur = def ? def.slug : "";
        setActiveRepo(cur);
      }
      sel.value = cur;
    }
    return state.repos;
  } catch {
    /* serveur injoignable : sélecteur laissé vide, repo par défaut serveur */
    return [];
  }
}

// Bascule de repo actif : persiste + recharge tout (méta, branches, liste, et la
// vue Good Vibes si elle est ouverte — forêt + flux SSE du nouveau repo).
async function onRepoChange(slug) {
  setActiveRepo(slug);
  state.branch = ""; // les branches diffèrent d'un repo à l'autre
  await loadMeta();
  await loadBranches();
  await loadList();
  if (typeof vibes !== "undefined" && vibes.view === "vibes") openVibes();
}

// Ajoute un repo via une petite invite (slug + url) puis bascule dessus.
async function addRepoPrompt() {
  const url = (window.prompt("URL git du repo à suivre (laisser vide pour un clone local géré à la main) :", "") || "").trim();
  const slug = (window.prompt("Slug court (identifiant, ex. 'chatserver'). Vide = dérivé de l'URL :", "") || "").trim();
  if (!slug && !url) return;
  try {
    const r = await api.send("POST", "/api/repos", { slug: slug || undefined, url: url || undefined });
    if (r.sync && r.sync.ok === false) alert("Repo ajouté mais clone échoué :\n" + (r.sync.output || "erreur inconnue"));
    await loadRepos();
    await onRepoChange(r.repo.slug);
  } catch (e) {
    alert("Erreur : " + e.message);
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

// ── Autocomplete partagé (@ description, chat IA, …) ──────────────────────────
// target = textarea où insérer ; menu = <ul> à piloter ; onChoose = callback post-insertion.
let menuState = { items: [], active: 0, target: null, menu: null, onChoose: null };

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
function debouncedSearch(query, cb, branch) {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(async () => {
    try {
      // Scope par branche : celle passée par l'appelant, sinon la branche d'édition.
      const b = branch != null ? branch : ($("#mBranch") ? $("#mBranch").value : "") || "";
      const url =
        "/api/paths?q=" + encodeURIComponent(query) + "&limit=20" + (b ? "&branch=" + encodeURIComponent(b) : "");
      cb(await api.get(url));
    } catch {
      cb([]);
    }
  }, 120);
}

function chooseMenuItem(i) {
  const item = menuState.items[i];
  if (!item) return;
  // Remplace le token @… en cours par le chemin choisi, dans le textarea ciblé.
  const ta = menuState.target;
  if (!ta) return;
  const pos = ta.selectionStart;
  const before = ta.value.slice(0, pos);
  const at = before.lastIndexOf("@");
  ta.value = before.slice(0, at) + "@" + item.path + " " + ta.value.slice(pos);
  const newPos = at + 1 + item.path.length + 1;
  ta.setSelectionRange(newPos, newPos);
  ta.focus();
  if (menuState.menu) hideMenu(menuState.menu);
  if (typeof menuState.onChoose === "function") menuState.onChoose();
}

// Cœur générique : détecte un token @… avant le curseur et pilote le menu donné.
function handleMentionInput(ta, menu, branch, onChoose) {
  const before = ta.value.slice(0, ta.selectionStart);
  const match = before.match(/@([A-Za-z0-9_./-]*)$/);
  if (!match) {
    hideMenu(menu);
    return;
  }
  menuState.target = ta;
  menuState.menu = menu;
  menuState.onChoose = onChoose || null;
  debouncedSearch(match[1], (items) => renderMenu(menu, items), branch);
}

function moveMenu(menu, dir) {
  const lis = menu.querySelectorAll("li");
  if (!lis.length) return;
  lis[menuState.active]?.classList.remove("active");
  menuState.active = (menuState.active + dir + lis.length) % lis.length;
  lis[menuState.active]?.classList.add("active");
  lis[menuState.active]?.scrollIntoView({ block: "nearest" });
}

// Description (modale entrée) : maj des refs + autocomplete @ scopé à la branche éditée.
function onDescInput() {
  syncMentionsFromDesc();
  handleMentionInput($("#mDesc"), $("#mentionMenu"), $("#mBranch").value || "", syncMentionsFromDesc);
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
  // Sélecteur de repo (topbar, multi-repos) + ajout d'un repo.
  $("#repoSel")?.addEventListener("change", (e) => onRepoChange(e.target.value));
  $("#addRepoBtn")?.addEventListener("click", addRepoPrompt);

  const desc = $("#mDesc");
  desc.addEventListener("input", onDescInput);
  desc.addEventListener("keydown", (e) => menuKeydown($("#mentionMenu"), e));
  desc.addEventListener("blur", () => setTimeout(() => hideMenu($("#mentionMenu")), 150));

  // Changer la branche dans la modale ré-cible l'autocomplete @ (rien d'autre à faire).
  $("#improveBtn").addEventListener("click", improveDescription);

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !$("#backdrop").hidden) closeModal();
  });

  // loadRepos d'abord (fixe le repo actif), puis le reste utilise ?repo=.
  loadRepos().then(() => {
    loadMeta();
    loadBranches();
    loadList();
  });
}

document.addEventListener("DOMContentLoaded", init);

// ═══════════════════════════════════════════════════════════════════════════
// Good Vibes v2 — arbre de NŒUDS récursif, graphe organique, chat IA streaming.
// Réutilise les helpers du Suivi ($/esc/api/getToken). N'altère PAS init().
// ═══════════════════════════════════════════════════════════════════════════

const NODE_STATUS_LABEL = { active: "🌱 Actif", paused: "⏸️ En pause", done: "🏆 Atteint", abandoned: "🪦 Abandonné" };
const NODE_COLORS = ["accent", "feature", "task", "bug", "high"];

// Palette « par cascade » : chaque sous-arbre de 1er niveau (tête de cascade =
// nœud de profondeur 1) reçoit une teinte distincte, héritée par ses descendants.
// Couleurs vives lisibles sur le thème sombre. Les nœuds de structure (profondeur 0
// : N0 + légendes) restent neutres pour faire ressortir les cascades.
const CASCADE_PALETTE = ["#4dabf7", "#69db7c", "#ffd43b", "#ff8787", "#da77f2", "#ffa94d", "#3bc9db", "#a9e34b", "#f783ac", "#9775fa"];
const CASCADE_NEUTRAL = "#868e96";

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
  // Effets « waouh » sur l'arbre détail : signature des nœuds au rendu précédent
  // (diff → fx-new / fx-changed / fx-done) et drapeau « premier rendu = cascade ».
  _treeSnap: new Map(),
  _treeInitial: true,
  _fxClear: null,
  _notesEditing: false, // éditeur de notes markdown ouvert (ne pas écraser par les maj live)
  // spawned/pulsed/celebrated : ids de nœuds à animer au prochain rendu (créés /
  // mis à jour / venant d'atteindre « done »). fxFired : éclats déjà tirés (anti-doublon
  // si la forêt re-rend plusieurs fois dans la fenêtre d'animation).
  graph: {
    view: { x: 0, y: 0, w: 1000, h: 700 }, drag: null, userView: false,
    spawned: new Set(), pulsed: new Set(), celebrated: new Set(), fxFired: new Set(),
    posMap: new Map(),      // id → {x,y} résolu au dernier rendu (drag live + arêtes)
    nodeDrag: null,         // déplacement d'un nœud (et de son sous-arbre) en cours
    linking: null,          // id source pendant « tirer un lien »
    edgeDel: null,          // { childId, parentId } de l'arête dont la poubelle est affichée
    pendingCreatePos: null, // position graphe où créer le prochain nœud (menu fond)
    suppressClick: false,   // ignore le prochain click (après un drag)
  },
};

// Respecte la préférence système : pas de particules ni de bursts si réduit.
const REDUCED = typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;

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

// ── Effets « waouh » : éclats de particules + classes d'animation ─────────────
function ensureFxLayer() {
  let l = document.getElementById("fxLayer");
  if (!l) {
    l = document.createElement("div");
    l.id = "fxLayer";
    document.body.appendChild(l);
  }
  return l;
}
// Petit feu d'artifice d'emojis qui jaillit depuis (cx, cy) (coords écran).
// Animé via la Web Animations API → auto-nettoyage à la fin (pas de CSS à gérer).
function sparkleBurst(cx, cy, opts = {}) {
  if (REDUCED || !document.body) return;
  const layer = ensureFxLayer();
  const n = opts.count || 8;
  const emojis = opts.emojis || ["✨", "💫", "⭐"];
  const baseDist = opts.dist || 44;
  for (let i = 0; i < n; i++) {
    const s = document.createElement("span");
    s.className = "fx-spark";
    s.textContent = emojis[i % emojis.length];
    s.style.left = cx + "px";
    s.style.top = cy + "px";
    s.style.fontSize = (opts.size || 16 + Math.random() * 8) + "px";
    layer.appendChild(s);
    const ang = (Math.PI * 2 * i) / n + Math.random() * 0.6 - 0.3;
    const dist = baseDist + Math.random() * baseDist * 0.7;
    const dx = Math.cos(ang) * dist;
    const dy = Math.sin(ang) * dist - dist * 0.35; // léger biais vers le haut
    const dur = 620 + Math.random() * 420;
    const spin = (Math.random() < 0.5 ? -1 : 1) * (140 + Math.random() * 160);
    const a = s.animate(
      [
        { transform: "translate(-50%,-50%) scale(.2) rotate(0deg)", opacity: 0 },
        { transform: `translate(calc(-50% + ${dx * 0.5}px), calc(-50% + ${dy * 0.5}px)) scale(1.15) rotate(${spin * 0.5}deg)`, opacity: 1, offset: 0.35 },
        { transform: `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px)) scale(.35) rotate(${spin}deg)`, opacity: 0 },
      ],
      { duration: dur, easing: "cubic-bezier(.25,.6,.3,1)" }
    );
    a.onfinish = () => s.remove();
    a.oncancel = () => s.remove();
  }
}
// Éclats centrés sur un élément du DOM (lit son rect courant).
function sparkleEl(el, opts = {}) {
  if (!el) return;
  const r = el.getBoundingClientRect();
  if (!r.width && !r.height) return; // élément masqué : on s'abstient
  sparkleBurst(r.left + (opts.ox != null ? opts.ox : r.width / 2), r.top + (opts.oy != null ? opts.oy : r.height / 2), opts);
}
// Classe d'effet à appliquer à une carte/nœud selon les sets transitoires.
function nodeFxClass(id) {
  const g = vibes.graph;
  return (g.spawned.has(id) ? " spawn" : "") + (g.pulsed.has(id) ? " pulse" : "") + (g.celebrated.has(id) ? " celebrate" : "");
}

// ── Rendu Markdown minimal et SÛR (sans dépendance) ───────────────────────────
// Sous-ensemble : titres, gras/italique/barré, code inline + blocs ```, listes
// (puces / numérotées), citations >, règles ---, liens [..](..) + autoliens http.
// Sécurité : on échappe TOUT le HTML d'abord (esc), puis on applique les
// transformations markdown → aucune balise utilisateur n'est jamais injectée.
function mdInline(str) {
  return str
    .replace(/`([^`]+)`/g, (_, c) => `<code class="md-code">${c}</code>`)
    .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>')
    .replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, '$1<a href="$2" target="_blank" rel="noopener noreferrer">$2</a>')
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/\*([^*\n]+)\*/g, "<em>$1</em>")
    .replace(/~~([^~]+)~~/g, "<del>$1</del>");
}
function renderMarkdown(src) {
  const raw = String(src || "");
  if (!raw.trim()) return "";
  // 1) Extraire les blocs de code clôturés (placeholders) pour ne pas les transformer.
  const blocks = [];
  let text = raw.replace(/```[ \t]*[\w-]*\n?([\s\S]*?)```/g, (_, code) => {
    const i = blocks.push(`<pre class="md-pre"><code>${esc(code.replace(/\n+$/, ""))}</code></pre>`) - 1;
    return ` CB${i} `;
  });
  // 2) Échapper le HTML restant (les caractères markdown * _ ` [ ] ( ) > # survivent).
  text = esc(text);

  const lines = text.split("\n");
  const out = [];
  let para = [];
  let listType = null;
  let inQuote = false;
  const flushPara = () => { if (para.length) { out.push(`<p>${mdInline(para.join(" "))}</p>`); para = []; } };
  const closeList = () => { if (listType) { out.push(`</${listType}>`); listType = null; } };
  const closeQuote = () => { if (inQuote) { out.push("</blockquote>"); inQuote = false; } };

  // Découpe une ligne de tableau en cellules (gère les | de bord optionnels).
  const tableCells = (s) => {
    let t = s.trim();
    if (t.startsWith("|")) t = t.slice(1);
    if (t.endsWith("|")) t = t.slice(0, -1);
    return t.split("|").map((c) => c.trim());
  };
  const isTableSep = (s) => /^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$/.test(s) && s.includes("-");

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const cb = line.match(/^ CB(\d+) $/);
    if (cb) { flushPara(); closeList(); closeQuote(); out.push(blocks[Number(cb[1])]); continue; }
    if (!line.trim()) { flushPara(); closeList(); closeQuote(); continue; }

    // Tableau GFM : ligne d'en-tête avec « | » suivie d'une ligne de séparation.
    if (line.includes("|") && i + 1 < lines.length && isTableSep(lines[i + 1])) {
      flushPara(); closeList(); closeQuote();
      const headers = tableCells(line);
      const aligns = tableCells(lines[i + 1]).map((c) => {
        const l = c.startsWith(":"), r = c.endsWith(":");
        return r && l ? "center" : r ? "right" : l ? "left" : "";
      });
      const rows = [];
      let j = i + 2;
      while (j < lines.length && lines[j].trim() && lines[j].includes("|")) { rows.push(tableCells(lines[j])); j++; }
      const al = (k) => (aligns[k] ? ` style="text-align:${aligns[k]}"` : "");
      let html = '<table class="md-table"><thead><tr>';
      headers.forEach((h, k) => (html += `<th${al(k)}>${mdInline(h)}</th>`));
      html += "</tr></thead><tbody>";
      for (const row of rows) {
        html += "<tr>";
        for (let k = 0; k < headers.length; k++) html += `<td${al(k)}>${mdInline(row[k] || "")}</td>`;
        html += "</tr>";
      }
      html += "</tbody></table>";
      out.push(html);
      i = j - 1;
      continue;
    }

    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) { flushPara(); closeList(); closeQuote(); const l = h[1].length; out.push(`<h${l} class="md-h md-h${l}">${mdInline(h[2].trim())}</h${l}>`); continue; }
    if (/^\s*([-*_])(?:\s*\1){2,}\s*$/.test(line)) { flushPara(); closeList(); closeQuote(); out.push('<hr class="md-hr">'); continue; }

    const ul = line.match(/^\s*[-*+]\s+(.*)$/);
    const ol = line.match(/^\s*\d+[.)]\s+(.*)$/);
    if (ul || ol) {
      flushPara(); closeQuote();
      const t = ul ? "ul" : "ol";
      if (listType && listType !== t) closeList();
      if (!listType) { listType = t; out.push(`<${t} class="md-list">`); }
      out.push(`<li>${mdInline((ul ? ul[1] : ol[1]).trim())}</li>`);
      continue;
    }
    closeList();

    // NB : esc() a déjà transformé « > » en « &gt; » → on matche la forme échappée.
    const bq = line.match(/^\s*&gt;\s?(.*)$/);
    if (bq) { flushPara(); if (!inQuote) { inQuote = true; out.push('<blockquote class="md-quote">'); } out.push(`<p>${mdInline(bq[1])}</p>`); continue; }
    closeQuote();

    para.push(line.trim());
  }
  flushPara(); closeList(); closeQuote();
  return out.join("\n");
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
  // Purge différée des marqueurs d'effet (les animations CSS one-shot ont joué).
  const g = vibes.graph;
  if (g.spawned.size || g.pulsed.size || g.celebrated.size || g.fxFired.size) {
    clearTimeout(vibes._fxClear);
    vibes._fxClear = setTimeout(() => {
      g.spawned.clear();
      g.pulsed.clear();
      g.celebrated.clear();
      g.fxFired.clear();
    }, 1000);
  }
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
  return `<div class="goal-card status-${esc(n.status)}${nodeFxClass(n.id)}" data-ref="${esc(n.ref)}" data-id="${n.id}" style="--gc:var(--${esc(n.color || "accent")})">
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
  // Éclats sur les cartes fraîchement nées / atteintes (uniquement si la grille est visible).
  if (!REDUCED && !$("#vibesView").hidden) {
    wrap.querySelectorAll(".goal-card.spawn, .goal-card.celebrate").forEach((c) => {
      const id = Number(c.dataset.id);
      if (vibes.graph.fxFired.has(id)) return;
      vibes.graph.fxFired.add(id);
      const done = c.classList.contains("celebrate");
      sparkleEl(c, { oy: 26, count: done ? 14 : 8, dist: done ? 56 : 42, emojis: done ? ["🎉", "✨", "🏆", "⭐"] : ["✨", "💫"] });
    });
  }
}

// ── Arbre hiérarchique top-down (créé via DOM API : anti-XSS) ─────────────────
// Layout « tidy tree » : Y dérive de la profondeur (N0 en haut), chaque N_k+1 est
// posé sous son parent N_k, les feuilles sont alignées de gauche à droite et chaque
// parent est centré au-dessus de ses enfants. Les racines (N0) démarrent en haut à
// gauche, chaque arbre racine à la suite du précédent.
const NS = "http://www.w3.org/2000/svg";
const G_LEVEL_GAP = 138; // distance verticale entre deux niveaux (N_k → N_k+1)
const G_NODE_GAP = 134;  // largeur horizontale d'un emplacement feuille
function computeGraphLayout() {
  const pos = new Map();
  // Rangée du haut ALIGNÉE : chaque RACINE (N0 + légendes) occupe un emplacement
  // uniforme (G_NODE_GAP), branchée ou non → les N0 forment une ligne nette. Le
  // sous-arbre de chaque racine est calculé tidy (placeSubtree) dans une map locale,
  // puis recentré SOUS sa racine. Une cascade large déborde sous la rangée, mais sans
  // chevauchement de nœuds (profondeurs = lignes différentes).
  let rowX = 0;
  for (const root of rootsOf()) {
    const local = new Map();
    placeSubtree(root, local, { x: 0 });
    const shift = rowX - local.get(root.id).x; // recale la racine sur la rangée
    for (const [id, p] of local) pos.set(id, { x: p.x + shift, y: p.y });
    rowX += G_NODE_GAP;
  }
  // Positions manuelles (drag & drop persistées) : écrasent l'auto-layout.
  for (const n of vibes.forest) {
    if (n.posX != null && n.posY != null) pos.set(n.id, { x: n.posX, y: n.posY });
  }
  return pos;
}
// Post-ordre : pose d'abord les feuilles à la suite, puis centre chaque parent sur
// l'intervalle [1re feuille … dernière feuille] de ses enfants. Y = profondeur.
function placeSubtree(node, pos, cur) {
  const y = (node.depth || 0) * G_LEVEL_GAP;
  const kids = childrenOf(node.id);
  if (!kids.length) {
    pos.set(node.id, { x: cur.x, y });
    cur.x += G_NODE_GAP;
    return;
  }
  for (const k of kids) placeSubtree(k, pos, cur);
  const first = pos.get(kids[0].id).x;
  const last = pos.get(kids[kids.length - 1].id).x;
  pos.set(node.id, { x: (first + last) / 2, y });
}
// ── Couleur par cascade ──────────────────────────────────────────────────────
// Assigne une teinte stable (par id croissant) à chaque tête de cascade (profondeur 1).
function buildCascadeColors() {
  const heads = vibes.forest.filter((n) => n.depth === 1).sort((a, b) => a.id - b.id);
  const m = new Map();
  heads.forEach((h, i) => m.set(h.id, CASCADE_PALETTE[i % CASCADE_PALETTE.length]));
  vibes.graph.cascadeColors = m;
}
// Teinte d'un nœud : neutre si structure (profondeur 0) ; sinon la couleur de sa
// tête de cascade (remontée jusqu'à l'ancêtre de profondeur 1).
function cascadeColorOf(n) {
  if (!n || n.depth === 0) return CASCADE_NEUTRAL;
  let cur = n;
  while (cur && cur.depth > 1) cur = vibes.byId.get(cur.parentId);
  return (cur && vibes.graph.cascadeColors && vibes.graph.cascadeColors.get(cur.id)) || CASCADE_NEUTRAL;
}
// Ids d'un nœud + tout son sous-arbre (pour déplacer/épingler ensemble).
function subtreeIds(id) {
  const out = [id];
  const rec = (pid) => { for (const c of childrenOf(pid)) { out.push(c.id); rec(c.id); } };
  rec(id);
  return out;
}
function svgEl(tag, attrs) {
  const el = document.createElementNS(NS, tag);
  for (const k in attrs) el.setAttribute(k, attrs[k]);
  return el;
}
function edgeD(p, c) {
  // Lien vertical descendant parent (p, en haut) → enfant (c, en bas) : courbe en S
  // avec points de contrôle à mi-hauteur (style organigramme top-down). Reste valide
  // pour des nœuds déplacés à la main dans une position arbitraire.
  const my = (p.y + c.y) / 2;
  return `M ${p.x} ${p.y} C ${p.x} ${my}, ${c.x} ${my}, ${c.x} ${c.y}`;
}
function edgePath(p, c, node) {
  return svgEl("path", {
    d: edgeD(p, c),
    class: "g-edge" + (vibes.graph.spawned.has(node.id) ? " spawn" : ""),
    "data-cid": String(node.id),
    "data-pid": String(node.parentId), // pour la maj live des arêtes pendant le drag
    stroke: cascadeColorOf(node),
  });
}
// Faisceau de rayons (célébration « jalon atteint »), dessiné derrière le nœud.
function raysGroup() {
  const g = svgEl("g", { class: "g-rays" });
  for (let i = 0; i < 8; i++) {
    const a = (Math.PI * 2 * i) / 8;
    g.appendChild(svgEl("line", { x1: Math.cos(a) * 16, y1: Math.sin(a) * 16, x2: Math.cos(a) * 42, y2: Math.sin(a) * 42, class: "g-ray" }));
  }
  return g;
}
function nodeGroup(n, p) {
  const r = n.depth === 0 ? 26 : Math.max(12, 24 - n.depth * 3);
  const spawn = vibes.graph.spawned.has(n.id);
  const pulse = vibes.graph.pulsed.has(n.id);
  const celebrate = vibes.graph.celebrated.has(n.id);
  const fxCls = (spawn ? " spawn" : "") + (pulse ? " pulse" : "") + (celebrate ? " celebrate" : "");
  const g = svgEl("g", { transform: `translate(${p.x},${p.y})`, class: "g-node status-" + n.status + fxCls, "data-ref": n.ref, "data-id": String(n.id) });
  // Tooltip natif : le label étant tronqué, le survol révèle le titre complet.
  const ttl = svgEl("title", {});
  ttl.textContent = n.title;
  g.appendChild(ttl);
  // Onde de choc (naissance) et rayons (jalon atteint) : sous le nœud (peints en premier).
  if (spawn) g.appendChild(svgEl("circle", { r: 10, class: "g-halo", stroke: cascadeColorOf(n) }));
  if (celebrate) g.appendChild(raysGroup());
  // Groupe interne mis à l'échelle pour l'anim d'apparition (le translate reste sur g).
  const inner = svgEl("g", { class: "g-inner" });
  const circ = 2 * Math.PI * (r + 5);
  inner.appendChild(svgEl("circle", { r: r + 5, class: "g-track" }));
  inner.appendChild(svgEl("circle", { r: r + 5, class: "g-ring", "stroke-dasharray": `${(circ * n.progress) / 100} ${circ}`, transform: "rotate(-90)" }));
  inner.appendChild(svgEl("circle", { r, class: "g-disc", fill: cascadeColorOf(n) }));
  const emo = svgEl("text", { class: "g-emoji", "text-anchor": "middle", dy: "0.35em", "font-size": String(Math.round(r)) });
  emo.textContent = n.emoji || "🎯";
  inner.appendChild(emo);
  const lbl = svgEl("text", { class: "g-label", "text-anchor": "middle", y: String(r + 18) });
  lbl.textContent = n.title.length > 18 ? n.title.slice(0, 17) + "…" : n.title;
  inner.appendChild(lbl);
  g.appendChild(inner);
  return g;
}
function renderGraph() {
  const svg = $("#graphSvg");
  if (!svg || $("#graphView").hidden) return;
  buildCascadeColors();         // teintes par cascade, recalculées à chaque rendu
  const pos = computeGraphLayout();
  vibes.graph.posMap = pos;     // réutilisé par le drag live et le recalcul des arêtes
  vibes.graph.edgeDel = null;   // l'overlay poubelle (re)disparaît au rendu
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
  // Feu d'artifice sur les nœuds qui viennent d'apparaître / d'être atteints.
  if (!REDUCED) {
    for (const id of vibes.graph.spawned) sparkleNode(svg, id, false);
    for (const id of vibes.graph.celebrated) sparkleNode(svg, id, true);
  }
}
// Tire un burst d'éclats centré sur le disque d'un nœud du graphe (une fois).
function sparkleNode(svg, id, big) {
  if (vibes.graph.fxFired.has(id)) return;
  const disc = svg.querySelector(`.g-node[data-id="${cssId(id)}"] .g-disc`);
  if (!disc) return;
  vibes.graph.fxFired.add(id);
  sparkleEl(disc, big
    ? { count: 16, dist: 64, size: 20, emojis: ["🎉", "✨", "⭐", "🏆", "💫"] }
    : { count: 10, dist: 46, emojis: ["✨", "💫", "⭐"] });
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
// Zoom clavier (+ / -) : zoom centré sur le milieu de la vue courante.
// factor < 1 = zoom avant ; factor > 1 = zoom arrière.
function zoomGraph(factor) {
  const svg = $("#graphSvg");
  if (!svg || $("#graphView").hidden) return;
  const v = vibes.graph.view;
  const cx = v.x + v.w / 2, cy = v.y + v.h / 2;
  v.w *= factor; v.h *= factor;
  v.x = cx - v.w / 2; v.y = cy - v.h / 2;
  vibes.graph.userView = true;
  applyViewBox(svg);
}
// Convertit des coords écran → coords graphe via la matrice EXACTE de l'élément
// (getScreenCTM). Indispensable avec preserveAspectRatio="meet" : le viewBox est
// mis à l'échelle UNIFORMÉMENT (avec letterbox), donc rect.width/v.w ≠ rect.height/v.h.
// Le calcul manuel par ratios indépendants décalait les coords (drag plus lent que
// le curseur sur l'axe contraint). ctm.a / ctm.d sont les échelles réelles px↔SVG.
function clientToSvg(clientX, clientY) {
  const svg = $("#graphSvg");
  const ctm = svg.getScreenCTM();
  if (ctm) {
    const p = new DOMPoint(clientX, clientY).matrixTransform(ctm.inverse());
    return { x: p.x, y: p.y };
  }
  const rect = svg.getBoundingClientRect();
  const v = vibes.graph.view;
  return { x: v.x + ((clientX - rect.left) / rect.width) * v.w, y: v.y + ((clientY - rect.top) / rect.height) * v.h };
}
// Maj live (sans rebuild) des transforms de nœuds + tracé des arêtes depuis posMap.
function liveUpdateGraphPositions() {
  const svg = $("#graphSvg");
  const pos = vibes.graph.posMap;
  svg.querySelectorAll(".g-node").forEach((g) => {
    const p = pos.get(Number(g.dataset.id));
    if (p) g.setAttribute("transform", `translate(${p.x},${p.y})`);
  });
  svg.querySelectorAll(".g-edge").forEach((ed) => {
    const pp = pos.get(Number(ed.dataset.pid)), pc = pos.get(Number(ed.dataset.cid));
    if (pp && pc) ed.setAttribute("d", edgeD(pp, pc));
  });
  if (vibes.graph.edgeDel) positionEdgeDel();
}
// Persiste les positions manuelles d'un ensemble d'ids (depuis posMap) + maj locale.
async function persistPositions(ids) {
  const positions = [];
  for (const id of ids) {
    const p = vibes.graph.posMap.get(id);
    const n = vibes.byId.get(id);
    if (p && n) { n.posX = p.x; n.posY = p.y; positions.push({ id, x: p.x, y: p.y }); }
  }
  if (!positions.length) return;
  try { await api.send("POST", "/api/nodes/positions", { positions }); }
  catch (e) { toast("Positions non enregistrées : " + e.message); }
}

// ── Menu contextuel générique (clic droit) ───────────────────────────────────
function hideCtxMenu() {
  const m = document.getElementById("ctxMenu");
  if (m) m.remove();
  document.removeEventListener("mousedown", _ctxOutside, true);
}
function _ctxOutside(e) { if (!e.target.closest("#ctxMenu")) hideCtxMenu(); }
function showCtxMenu(clientX, clientY, items) {
  hideCtxMenu();
  const m = document.createElement("div");
  m.id = "ctxMenu";
  m.className = "ctx-menu";
  for (const it of items) {
    const b = document.createElement("button");
    b.className = "ctx-item" + (it.danger ? " danger" : "");
    b.textContent = it.label;
    b.addEventListener("click", () => { hideCtxMenu(); it.onClick(); });
    m.appendChild(b);
  }
  document.body.appendChild(m);
  const r = m.getBoundingClientRect();
  m.style.left = Math.min(clientX, window.innerWidth - r.width - 8) + "px";
  m.style.top = Math.min(clientY, window.innerHeight - r.height - 8) + "px";
  setTimeout(() => document.addEventListener("mousedown", _ctxOutside, true), 0);
}

// ── Mode « tirer un lien » (connecter deux nœuds = reparentage) ───────────────
function startLinkMode(sourceId) {
  cancelLinkMode();
  vibes.graph.linking = sourceId;
  const line = svgEl("path", { class: "g-link-temp", d: "" });
  $("#graphSvg").insertBefore(line, $("#graphSvg").firstChild);
  vibes.graph._linkLine = line;
  toast("Clique le nœud à rattacher comme enfant (Échap pour annuler).");
}
function cancelLinkMode() {
  vibes.graph.linking = null;
  if (vibes.graph._linkLine) { vibes.graph._linkLine.remove(); vibes.graph._linkLine = null; }
}
function updateLinkLine(clientX, clientY) {
  if (!vibes.graph._linkLine) return;
  const src = vibes.graph.posMap.get(vibes.graph.linking);
  if (!src) return;
  const t = clientToSvg(clientX, clientY);
  vibes.graph._linkLine.setAttribute("d", `M ${src.x} ${src.y} L ${t.x} ${t.y}`);
}
async function finishLink(targetId) {
  const sourceId = vibes.graph.linking;
  cancelLinkMode();
  if (!sourceId || targetId == null || targetId === sourceId) return;
  try {
    // « Tirer un lien depuis A vers B » = B devient enfant de A.
    await api.send("POST", `/api/nodes/${encodeURIComponent(targetId)}/move`, { newParentId: sourceId });
    vibes.graph.spawned.add(targetId);
    toast("Lien créé.");
    loadForest();
  } catch (e) {
    toast(/cycle|sous-arbre/i.test(e.message) ? "Impossible : créerait un cycle." : "Échec : " + e.message);
  }
}

// ── Poubelle de suppression d'arête (double-clic sur un lien) ─────────────────
function hideEdgeDel() {
  const el = document.getElementById("gEdgeDel");
  if (el) el.remove();
  vibes.graph.edgeDel = null;
}
function positionEdgeDel() {
  const el = document.getElementById("gEdgeDel");
  const d = vibes.graph.edgeDel;
  if (!el || !d) return;
  const pp = vibes.graph.posMap.get(d.parentId), pc = vibes.graph.posMap.get(d.childId);
  if (pp && pc) el.setAttribute("transform", `translate(${(pp.x + pc.x) / 2},${(pp.y + pc.y) / 2})`);
}
function showEdgeDel(childId, parentId) {
  hideEdgeDel();
  vibes.graph.edgeDel = { childId, parentId };
  const g = svgEl("g", { id: "gEdgeDel", class: "g-edge-del" });
  g.appendChild(svgEl("circle", { r: 13 }));
  const t = svgEl("text", { "text-anchor": "middle", dy: "0.35em", "font-size": "14" });
  t.textContent = "🗑";
  g.appendChild(t);
  g.addEventListener("click", (e) => { e.stopPropagation(); deleteEdge(childId); });
  $("#graphSvg").appendChild(g);
  positionEdgeDel();
}
async function deleteEdge(childId) {
  hideEdgeDel();
  try {
    // Supprimer le lien = détacher l'enfant → il redevient une racine.
    await api.send("POST", `/api/nodes/${encodeURIComponent(childId)}/move`, { newParentId: null });
    toast("Lien supprimé (nœud détaché).");
    loadForest();
  } catch (e) {
    toast("Échec : " + e.message);
  }
}

const NODE_DRAG_THRESHOLD = 4; // px avant de basculer click → drag
function wireGraph() {
  const svg = $("#graphSvg");

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

  // mousedown : démarre soit un drag de nœud (sur un nœud), soit un pan (sur le fond).
  svg.addEventListener("mousedown", (e) => {
    if (e.button !== 0) return; // gauche uniquement (le clic droit → contextmenu)
    if (vibes.graph.linking) return; // en mode lien : la sélection se fait au click
    if (e.target.closest("#gEdgeDel")) return; // clic sur la poubelle : géré par son handler
    hideCtxMenu();
    hideEdgeDel();
    const gNode = e.target.closest(".g-node");
    if (gNode) {
      const id = Number(gNode.dataset.id);
      const ids = subtreeIds(id);
      const start = new Map(ids.map((i) => [i, { ...(vibes.graph.posMap.get(i) || { x: 0, y: 0 }) }]));
      vibes.graph.nodeDrag = { id, ids, start, cx: e.clientX, cy: e.clientY, moved: false, ref: gNode.dataset.ref };
    } else {
      vibes.graph.drag = { x: e.clientX, y: e.clientY, vx: vibes.graph.view.x, vy: vibes.graph.view.y };
    }
  });

  window.addEventListener("mousemove", (e) => {
    if (vibes.graph.linking) { updateLinkLine(e.clientX, e.clientY); return; }
    const nd = vibes.graph.nodeDrag;
    if (nd) {
      if (!nd.moved && Math.hypot(e.clientX - nd.cx, e.clientY - nd.cy) < NODE_DRAG_THRESHOLD) return;
      nd.moved = true;
      svg.style.cursor = "grabbing";
      // Delta écran → SVG via les échelles RÉELLES (ctm.a/ctm.d). Avec un scaling
      // uniforme (preserveAspectRatio="meet"), diviser par rect.width/v.w sur l'axe
      // contraint sous-estimait le déplacement → le nœud « traînait » derrière le curseur.
      const ctm = svg.getScreenCTM();
      const dx = ctm ? (e.clientX - nd.cx) / ctm.a : 0;
      const dy = ctm ? (e.clientY - nd.cy) / ctm.d : 0;
      for (const i of nd.ids) {
        const s = nd.start.get(i);
        vibes.graph.posMap.set(i, { x: s.x + dx, y: s.y + dy });
      }
      liveUpdateGraphPositions();
      return;
    }
    const d = vibes.graph.drag;
    if (!d) return;
    const v = vibes.graph.view;
    // Même correction d'échelle réelle pour le pan du fond (ctm.a/ctm.d).
    const ctm = svg.getScreenCTM();
    v.x = d.vx - (ctm ? (e.clientX - d.x) / ctm.a : 0);
    v.y = d.vy - (ctm ? (e.clientY - d.y) / ctm.d : 0);
    vibes.graph.userView = true;
    applyViewBox(svg);
  });

  window.addEventListener("mouseup", () => {
    const nd = vibes.graph.nodeDrag;
    if (nd && nd.moved) {
      vibes.graph.userView = true;   // on ne re-fit pas la vue après un placement manuel
      vibes.graph.suppressClick = true; // empêche l'ouverture du nœud juste après le drag
      persistPositions(nd.ids);
      svg.style.cursor = "";
    }
    vibes.graph.nodeDrag = null;
    vibes.graph.drag = null;
  });

  // click : ouvre un nœud (sauf juste après un drag) ou finalise un lien.
  svg.addEventListener("click", (e) => {
    if (vibes.graph.suppressClick) { vibes.graph.suppressClick = false; return; }
    const gNode = e.target.closest(".g-node");
    if (vibes.graph.linking) {
      if (gNode) finishLink(Number(gNode.dataset.id));
      else cancelLinkMode();
      return;
    }
    if (gNode) openNode(gNode.dataset.ref);
  });

  // double-clic sur une arête → affiche la poubelle de suppression de lien.
  svg.addEventListener("dblclick", (e) => {
    const edge = e.target.closest(".g-edge");
    if (edge) { e.preventDefault(); showEdgeDel(Number(edge.dataset.cid), Number(edge.dataset.pid)); }
  });

  // clic droit : menu contextuel selon la cible (nœud / arête / fond).
  svg.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    if (vibes.graph.linking) { cancelLinkMode(); return; }
    const gNode = e.target.closest(".g-node");
    if (gNode) {
      const id = Number(gNode.dataset.id);
      const ref = gNode.dataset.ref;
      showCtxMenu(e.clientX, e.clientY, [
        { label: "🔗 Tirer un lien…", onClick: () => startLinkMode(id) },
        { label: "✎ Ouvrir", onClick: () => openNode(ref) },
        { label: "🗑 Supprimer", danger: true, onClick: () => { if (confirm("Supprimer ce nœud et tout son sous-arbre ?")) deleteNodeById(id); } },
      ]);
      return;
    }
    const edge = e.target.closest(".g-edge");
    if (edge) {
      showCtxMenu(e.clientX, e.clientY, [
        { label: "🗑 Supprimer le lien", danger: true, onClick: () => deleteEdge(Number(edge.dataset.cid)) },
      ]);
      return;
    }
    // Fond : créer un nouveau nœud à cet endroit.
    const at = clientToSvg(e.clientX, e.clientY);
    showCtxMenu(e.clientX, e.clientY, [
      { label: "➕ Nouvel objectif ici", onClick: () => { vibes.graph.pendingCreatePos = at; openNodeModal(null, null); } },
    ]);
  });

  $("#graphFit").addEventListener("click", () => {
    vibes.graph.userView = false;
    renderGraph();
  });

  // Zoom au clavier : + (ou =) zoom avant, - (ou _) zoom arrière. Actif seulement
  // en vue graphe et hors saisie dans un champ.
  document.addEventListener("keydown", (e) => {
    if ($("#graphView").hidden) return;
    const t = e.target;
    if (t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)) return;
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === "+" || e.key === "=") { e.preventDefault(); zoomGraph(0.85); }
    else if (e.key === "-" || e.key === "_") { e.preventDefault(); zoomGraph(1 / 0.85); }
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
    // Nouveau contexte d'arbre : snapshot vierge → premier rendu en cascade (sans éclats).
    vibes._treeSnap = new Map();
    vibes._treeInitial = true;
    vibes._notesEditing = false; // pas d'édition de notes héritée d'un autre nœud
    vibes._notesOpen = new Set(); // état plié/déplié des notes propre à ce nœud
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
  renderNotes(n);
}

// ── Notes markdown : liste de sections collapsables (lecture + édition) ────────
// notes = [{title, body}]. Vue : un <details> par note. Édition : liste dynamique.
function notesOf(n) {
  return Array.isArray(n && n.notes) ? n.notes : [];
}
// Mémorise l'état plié/déplié par index (réinitialisé au changement de nœud).
function renderNotes(n) {
  if (vibes._notesEditing) return; // édition en cours : ne pas écraser
  const view = $("#ndNotesView");
  if (!view) return;
  const notes = notesOf(n);
  view.hidden = false;
  $("#ndNotesEditor").hidden = true;
  $("#ndNotesEditBtn").hidden = false;
  if (!notes.length) {
    view.classList.add("empty");
    view.innerHTML = '<span class="hint">Aucune note. Clique « ✎ Éditer » ou demande à Claude d\'en rédiger.</span>';
    return;
  }
  view.classList.remove("empty");
  const open = vibes._notesOpen || new Set();
  view.innerHTML = notes
    .map((note, i) => {
      const title = (note.title || "").trim() || `Note ${i + 1}`;
      const isOpen = open.size ? open.has(i) : true; // tout déplié par défaut
      return `<details class="note-item"${isOpen ? " open" : ""} data-i="${i}">
        <summary class="note-summary"><span class="note-title">${esc(title)}</span></summary>
        <div class="note-body markdown-body">${renderMarkdown(note.body) || '<span class="hint">(vide)</span>'}</div>
      </details>`;
    })
    .join("");
  // Suit l'état plié/déplié (persisté en mémoire le temps de la session du nœud).
  view.querySelectorAll(".note-item").forEach((d) =>
    d.addEventListener("toggle", () => {
      vibes._notesOpen = vibes._notesOpen || new Set();
      const i = Number(d.dataset.i);
      if (d.open) vibes._notesOpen.add(i);
      else vibes._notesOpen.delete(i);
    })
  );
}

// Construit un éditeur pour une note (titre + corps markdown + aperçu live + @).
function buildNoteEditor(note) {
  const row = document.createElement("div");
  row.className = "note-editor";
  row.innerHTML = `
    <div class="note-editor-head">
      <input type="text" class="note-edit-title" placeholder="Titre de la note (optionnel)" />
      <button type="button" class="ghost danger note-edit-del" title="Supprimer cette note">🗑</button>
    </div>
    <div class="ta-wrap">
      <textarea class="note-edit-body" rows="6" placeholder="Markdown : # Titre, **gras**, - listes, | tableaux |, > citation, @chemin/fichier…"></textarea>
      <ul class="mention-menu" hidden></ul>
    </div>
    <details class="note-edit-preview"><summary>👁 Aperçu</summary><div class="markdown-body note-edit-preview-body"></div></details>`;
  const titleEl = row.querySelector(".note-edit-title");
  const bodyEl = row.querySelector(".note-edit-body");
  const menuEl = row.querySelector(".mention-menu");
  const prevEl = row.querySelector(".note-edit-preview-body");
  titleEl.value = (note && note.title) || "";
  bodyEl.value = (note && note.body) || "";
  const preview = () => { prevEl.innerHTML = renderMarkdown(bodyEl.value) || '<span class="hint">(aperçu vide)</span>'; };
  preview();
  bodyEl.addEventListener("input", () => { preview(); handleMentionInput(bodyEl, menuEl, state.branch || "", preview); });
  bodyEl.addEventListener("blur", () => setTimeout(() => hideMenu(menuEl), 150));
  bodyEl.addEventListener("keydown", (e) => {
    if (menuKeydown(menuEl, e)) return;
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") { e.preventDefault(); saveNotes(); }
  });
  row.querySelector(".note-edit-del").addEventListener("click", () => row.remove());
  return row;
}
function addNoteEditor(note) {
  $("#ndNotesList").appendChild(buildNoteEditor(note || { title: "", body: "" }));
}
function collectNotesFromEditor() {
  return [...$("#ndNotesList").querySelectorAll(".note-editor")]
    .map((row) => ({
      title: row.querySelector(".note-edit-title").value.trim(),
      body: row.querySelector(".note-edit-body").value,
    }))
    .filter((n) => n.title || n.body.trim());
}
function openNotesEditor() {
  if (!vibes.currentNode) return;
  vibes._notesEditing = true;
  vibes._notesBaseVersion = vibes.currentNode.version; // pivot CAS figé au début de l'édition
  const list = $("#ndNotesList");
  list.innerHTML = "";
  const notes = notesOf(vibes.currentNode);
  if (notes.length) notes.forEach(addNoteEditor);
  else addNoteEditor({ title: "", body: "" }); // une note vide pour démarrer
  $("#ndNotesView").hidden = true;
  $("#ndNotesEditBtn").hidden = true;
  $("#ndNotesEditor").hidden = false;
  const first = list.querySelector(".note-edit-body");
  if (first) first.focus();
}
function closeNotesEditor() {
  vibes._notesEditing = false;
  renderNotes(vibes.currentNode);
}
async function saveNotes() {
  if (!vibes.current) return;
  const notes = collectNotesFromEditor();
  const payload = { notes };
  if (vibes._notesBaseVersion != null) payload.expectedVersion = vibes._notesBaseVersion;
  try {
    const n = await api.send("PATCH", `/api/nodes/${encodeURIComponent(vibes.current)}`, payload);
    vibes._notesEditing = false;
    applyNodeUpdate(n); // met à jour currentNode + header → renderNotes
    scheduleSubtreeRefetch();
    toast("Notes enregistrées.");
  } catch (e) {
    if (/version_conflict/.test(e.message)) toast("Nœud modifié entre-temps — rouvre-le pour repartir de la version à jour.");
    else toast("Échec : " + e.message);
  }
}
// Petit « waouh » quand les notes changent à distance (ex : le bot vient d'écrire).
function flashNotes() {
  const el = $("#ndNotes");
  if (!el || REDUCED) return;
  el.classList.remove("fx-note");
  void el.offsetWidth; // reflow → rejoue l'animation
  el.classList.add("fx-note");
  sparkleEl($("#ndNotesView"), { oy: 24, count: 8, dist: 36, emojis: ["📝", "✨", "💫"] });
}
// Signature d'un nœud pour le diff visuel (champs qui méritent une animation).
function nodeSig(n) {
  return `${n.status}|${n.progress}|${n.title}|${n.emoji || ""}|${n.color || ""}`;
}
// Compare l'arbre courant au snapshot précédent → Map(id → {cls, si}) :
//   fx-new (apparu), fx-done (vient d'être atteint), fx-changed (autre modif).
// `si` est l'ordre d'apparition (stagger) parmi les seuls nœuds animés.
function computeTreeFx(node) {
  const fx = new Map();
  const next = new Map();
  const prev = vibes._treeSnap || new Map();
  let order = 0;
  const walk = (n) => {
    const sig = nodeSig(n);
    next.set(n.id, sig);
    const before = prev.get(n.id);
    if (before === undefined) fx.set(n.id, { cls: "fx-new", si: order++ });
    else if (before !== sig) {
      const wasDone = before.split("|")[0] === "done";
      fx.set(n.id, { cls: !wasDone && n.status === "done" ? "fx-done" : "fx-changed", si: order++ });
    }
    (n.children || []).forEach(walk);
  };
  (node.children || []).forEach(walk);
  vibes._treeSnap = next;
  return fx;
}
// Arbre récursif des sous-nœuds (chaque ligne ouvre son propre chat).
function treeHtml(n, depth, fx) {
  const kids = n.children || [];
  const childrenHtml = kids.map((k) => treeHtml(k, depth + 1, fx)).join("");
  const f = fx.get(n.id);
  const fxCls = f ? " " + f.cls : "";
  const si = f ? f.si : 0;
  return `<li class="tnode" data-ref="${esc(n.ref)}" data-id="${n.id}" style="--d:${depth}">
    <div class="trow ms-${esc(n.status)}${fxCls}" style="--si:${si}">
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
  const fx = computeTreeFx(node);
  wrap.innerHTML = kids.length
    ? `<ul class="tree-root">${kids.map((k) => treeHtml(k, 0, fx)).join("")}</ul>`
    : `<div class="empty">Aucun sous-jalon. Ajoute-en un, ou demande à Claude.</div>`;
  // Éclats sur les jalons ajoutés / atteints en live (pas au tout premier rendu = cascade silencieuse).
  if (!REDUCED && !vibes._treeInitial) {
    wrap.querySelectorAll(".trow.fx-new, .trow.fx-done").forEach((row) => {
      const done = row.classList.contains("fx-done");
      sparkleEl(row, { ox: 28, count: done ? 12 : 6, dist: done ? 42 : 30, emojis: done ? ["🎉", "✨", "🏆", "⭐"] : ["✨", "💫"] });
    });
  }
  vibes._treeInitial = false;
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
    const notesChanged = !vibes._notesEditing && n.notes != null && JSON.stringify(vibes.currentNode.notes || []) !== JSON.stringify(n.notes || []);
    vibes.currentVersion = n.version;
    Object.assign(vibes.currentNode, n);
    renderNodeHeader(vibes.currentNode);
    if (notesChanged) flashNotes(); // ex : le bot vient d'écrire les notes
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
    // Message finalisé : rendu markdown (tableaux, listes, code…) pour l'IA ;
    // texte simple pour les humains (on n'interprète pas leur frappe comme du markdown).
    if (m.role === "assistant") {
      body.classList.add("markdown-body");
      body.innerHTML = renderMarkdown(m.body || "");
    } else {
      body.innerHTML = esc(m.body || "").replace(/\n/g, "<br>");
    }
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
async function clearChatHistory() {
  if (!vibes.current) return;
  if (!confirm("Vider tout l'historique de la discussion de ce nœud ? (irréversible)")) return;
  try {
    await api.send("DELETE", nodeUrl("/messages"));
    renderChat([]); // vidage local immédiat (l'événement chat:cleared confirmera aux autres)
    toast("Historique vidé.");
  } catch (e) {
    if (/ai_busy/.test(e.message)) toast("Claude répond en ce moment — réessaie après le tour.");
    else toast("Échec : " + e.message);
  }
}

// ── Temps réel (SSE) ─────────────────────────────────────────────────────────
function setLive(on) {
  document.querySelectorAll(".live-dot").forEach((d) => d.classList.toggle("on", !!on));
}
function streamUrl(p) {
  p = injectRepo(p); // SSE forêt/nœud scopés sur le repo actif
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
  const applyNode = (raw, kind) => {
    if (!raw) return;
    const ex = vibes.byId.get(raw.id);
    const wasDone = ex && ex.status === "done";
    if (ex) Object.assign(ex, raw);
    else { vibes.forest.push(raw); vibes.byId.set(raw.id, raw); }
    const node = vibes.byId.get(raw.id);
    if (kind === "created" || !ex) {
      vibes.graph.spawned.add(node.id);
    } else {
      vibes.graph.pulsed.add(node.id);
      if (!wasDone && node.status === "done") vibes.graph.celebrated.add(node.id); // jalon atteint → fête
    }
    renderForestSoon();
  };
  es.addEventListener("node:created", (e) => applyNode(JSON.parse(e.data), "created"));
  es.addEventListener("node:updated", (e) => applyNode(JSON.parse(e.data), "updated"));
  es.addEventListener("node:deleted", () => loadForest());
  es.addEventListener("node:reparented", () => loadForest());
  es.addEventListener("nodes:reordered", () => loadForest());
  // Positions manuelles déplacées ailleurs : maj locale + re-rendu (sauf si on drague).
  es.addEventListener("nodes:moved", (e) => {
    if (vibes.graph.nodeDrag) return;
    const d = JSON.parse(e.data);
    for (const p of d.positions || []) {
      const n = vibes.byId.get(p.id);
      if (n) { n.posX = p.x; n.posY = p.y; }
    }
    renderForestSoon();
  });
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
  es.addEventListener("chat:cleared", () => renderChat([])); // un autre client a vidé l'historique
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
      vibes.graph.spawned.add(n.id); // anime aussi la naissance pour le créateur local
      // Création via le menu contextuel du fond → épingle le nœud à l'endroit cliqué.
      const at = vibes.graph.pendingCreatePos;
      vibes.graph.pendingCreatePos = null;
      if (at) {
        n.posX = at.x; n.posY = at.y;
        vibes.graph.posMap.set(n.id, { x: at.x, y: at.y });
        persistPositions([n.id]);
      }
      if (vibes.current) scheduleSubtreeRefetch();
      else if (at) loadForest(); // créé via le menu fond → rester sur le graphe pour le voir apparaître
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
  // Notes markdown : éditeur multi-notes (chaque éditeur gère son @ / aperçu).
  $("#ndNotesEditBtn").addEventListener("click", openNotesEditor);
  $("#ndNotesCancelBtn").addEventListener("click", closeNotesEditor);
  $("#ndNotesSaveBtn").addEventListener("click", saveNotes);
  $("#ndNotesAddBtn").addEventListener("click", () => addNoteEditor());
  $("#chatSend").addEventListener("click", sendChat);
  $("#chatClearBtn").addEventListener("click", clearChatHistory);
  // Autocomplete @ fichier dans le chat (même UX que la modale d'entrée du tracker).
  const chatInput = $("#chatInput");
  const chatMenu = $("#chatMentionMenu");
  chatInput.addEventListener("input", () => handleMentionInput(chatInput, chatMenu, state.branch || "", null));
  chatInput.addEventListener("blur", () => setTimeout(() => hideMenu(chatMenu), 150));
  chatInput.addEventListener("keydown", (e) => {
    if (menuKeydown(chatMenu, e)) return; // menu ouvert : flèches / Entrée / Tab / Échap pour lui
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendChat(); }
  });
  $("#modelSel").addEventListener("change", (e) => (vibes.model = e.target.value));
  const closeNodeModal = () => { $("#nodeBackdrop").hidden = true; vibes.graph.pendingCreatePos = null; };
  $("#nodeCancelBtn").addEventListener("click", closeNodeModal);
  $("#nodeSaveBtn").addEventListener("click", saveNode);
  $("#nodeBackdrop").addEventListener("mousedown", (e) => { if (e.target === $("#nodeBackdrop")) closeNodeModal(); });
  document.addEventListener("keydown", (e) => {
    if (e.key !== "Escape") return;
    if (vibes.graph.linking) { cancelLinkMode(); return; }
    if (document.getElementById("ctxMenu")) { hideCtxMenu(); return; }
    if (vibes.graph.edgeDel) { hideEdgeDel(); return; }
    if (vibes._notesEditing && !$("#nodeView").hidden) { closeNotesEditor(); return; }
    if (!$("#nodeBackdrop").hidden) { $("#nodeBackdrop").hidden = true; vibes.graph.pendingCreatePos = null; }
  });
  buildColorChips();
  wireGraph();
  setVibesLayout(vibes.layout);
  window.addEventListener("beforeunload", closeStream);
  window.addEventListener("hashchange", () => switchView(location.hash === "#vibes" ? "vibes" : "track"));
  document.body.classList.add("view-track");
  if (location.hash === "#vibes") switchView("vibes");
}
document.addEventListener("DOMContentLoaded", initVibes);
