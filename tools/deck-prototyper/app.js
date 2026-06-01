let appData = { slides: [], media: [], manifest: {} };
let filteredMedia = [];
let activePhase = "view-script";

let gridFocusIndex = -1;
let lightboxActiveIndex = -1;
let lbSelectedSlideIdx = 0;
let targetCurationSlide = null;
let currentFilter = "all";
let searchQuery = "";
let activeAssemblySlide = null;
let activeControlLayer = "media";
let activeExportFolder = null;
let activeMediaSlotIndex = 0;
let scriptSyncTimer = null;
let draggedSlideNum = null;
let pointerSlideDrag = null;

let availableFolders = new Set();
let selectedFolder = "All";
let selectedType = "All";
let cmActiveMediaIndex = -1;

const contextMenu = document.getElementById("context-menu");
const CONTEXT_MENU_MARGIN = 12;
const saveStatus = document.getElementById("save-status");
const searchInput = document.getElementById("search-input");
const filterBtns = document.querySelectorAll(".filter-btn");
const folderSelect = document.getElementById("folder-filter");
const typeSelect = document.getElementById("type-filter");
const mediaCountEl = document.getElementById("media-count");
const thumbSliderElement = document.getElementById("thumb-slider");

const assemblyCanvas = document.getElementById("assembly-canvas");
const ctx = assemblyCanvas ? assemblyCanvas.getContext("2d") : null;
let loadedImages = {};
let isDragging = false;
let dragStartX = 0;
let dragStartY = 0;
let dragInitX = 0;
let dragInitY = 0;
let canvasRenderLoop;

function escapeHTML(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function ensureManifestShape() {
  if (!appData.manifest.mediaTags) appData.manifest.mediaTags = {};
  if (!appData.manifest.slideSlots) appData.manifest.slideSlots = {};
  if (!appData.manifest.customText) appData.manifest.customText = {};
  if (!appData.manifest.slideSettings) appData.manifest.slideSettings = {};
  if (!appData.manifest.slideLayouts) appData.manifest.slideLayouts = {};
  if (!appData.manifest.slideNotes) appData.manifest.slideNotes = {};
}

function defaultSlideSettings() {
  return {
    scale: 100,
    flip: false,
    imgX: 0,
    imgY: 0,
    textX: 0,
    textY: 0,
    textWidth: 1600,
    slotTransforms: [],
  };
}

function ensureSlideSettings(slideNum) {
  if (!appData.manifest.slideSettings[slideNum]) {
    appData.manifest.slideSettings[slideNum] = defaultSlideSettings();
  }
  const settings = appData.manifest.slideSettings[slideNum];
  if (!Array.isArray(settings.slotTransforms)) {
    settings.slotTransforms = [];
  }
  if (!settings.slotTransforms[0]) {
    settings.slotTransforms[0] = {
      x: settings.imgX || 0,
      y: settings.imgY || 0,
      scale: settings.scale || 100,
      flip: settings.flip || false,
    };
  }
  return settings;
}

function renderAllViews() {
  renderScriptTab();
  renderCurationSidebar();
  renderAssemblyNav();
  updateInspectorUI();
  applyFiltersAndRenderGrid();
  preloadAndRenderCanvas();
}

function scrubText(text) {
  if (!text) return "";
  const lower = text.trim().toLowerCase();
  if (
    [
      "head:",
      "sub:",
      "body:",
      "body",
      "_body_",
      "_subheadline_",
      "_headline_",
    ].includes(lower)
  )
    return "";
  return text;
}

async function saveManifest() {
  saveStatus.textContent = "Saving...";
  try {
    await fetch("/api/save", {
      method: "POST",
      body: JSON.stringify(appData.manifest),
    });
    setTimeout(() => (saveStatus.textContent = "All changes saved"), 500);
  } catch (e) {
    saveStatus.textContent = "Save Failed!";
    saveStatus.style.color = "var(--accent)";
  }
}

async function syncScriptToFile() {
  saveStatus.textContent = "Syncing...";
  try {
    const payload = appData.slides.map((s) => {
      const custom = appData.manifest.customText[s.slide] || {};
      return {
        slide: s.slide,
        head: scrubText(custom.head !== undefined ? custom.head : s.head),
        sub: scrubText(custom.sub !== undefined ? custom.sub : s.sub),
        body: scrubText(custom.body !== undefined ? custom.body : s.body),
      };
    });
    await fetch("/api/sync", { method: "POST", body: JSON.stringify(payload) });
    setTimeout(() => (saveStatus.textContent = "deck-copy.txt updated"), 1500);
  } catch (e) {
    saveStatus.textContent = "Sync Failed!";
    saveStatus.style.color = "var(--accent)";
  }
}

function scheduleScriptFileSync() {
  if (scriptSyncTimer) clearTimeout(scriptSyncTimer);
  scriptSyncTimer = setTimeout(syncScriptToFile, 700);
}

async function reloadScriptFromFile() {
  saveStatus.textContent = "Reloading deck-copy.txt...";
  try {
    const response = await fetch(`/api/data?ts=${Date.now()}`);
    const freshData = await response.json();
    appData.slides = freshData.slides;
    appData.manifest.customText = {};
    if (appData.slides.length > 0) {
      activeAssemblySlide = String(appData.slides[0].slide);
      targetCurationSlide = String(appData.slides[0].slide);
    } else {
      activeAssemblySlide = null;
      targetCurationSlide = null;
    }
    await saveManifest();
    renderAllViews();
    saveStatus.textContent = "Loaded from deck-copy.txt";
  } catch (e) {
    saveStatus.textContent = "Reload Failed!";
    saveStatus.style.color = "var(--accent)";
  }
}

document
  .getElementById("btn-sync-script")
  ?.addEventListener("click", syncScriptToFile);
document
  .getElementById("btn-reload-script")
  ?.addEventListener("click", reloadScriptFromFile);

document.getElementById("btn-reset-project")?.addEventListener("click", async () => {
  const ok = window.confirm(
    "Reset this prototyper project to one blank slide? Current deck-copy.txt and manifest.json will be backed up first.",
  );
  if (!ok) return;
  if (scriptSyncTimer) clearTimeout(scriptSyncTimer);
  saveStatus.textContent = "Resetting project...";
  try {
    const response = await fetch("/api/reset-project", { method: "POST" });
    const resetData = await response.json();
    appData.slides = resetData.slides;
    appData.manifest = resetData.manifest || {};
    ensureManifestShape();
    loadedImages = {};
    activeAssemblySlide = appData.slides[0] ? String(appData.slides[0].slide) : null;
    targetCurationSlide = activeAssemblySlide;
    renderAllViews();
    saveStatus.textContent = `Reset complete. Backup: ${resetData.backup}`;
  } catch (e) {
    saveStatus.textContent = "Reset Failed!";
    saveStatus.style.color = "var(--accent)";
  }
});

async function init() {
  try {
    const response = await fetch("/api/data");
    appData = await response.json();
    ensureManifestShape();
    document.getElementById("app-version").textContent =
      `v${appData.appVersion || "0.4.0"}`;

    for (const slide in appData.manifest.slideSlots) {
      const slot = appData.manifest.slideSlots[slide];
      if (!slot.mains) slot.mains = [];
      if (slot.main && !slot.mains.includes(slot.main)) {
        slot.mains.push(slot.main);
        delete slot.main;
      }
    }
    const normalized = normalizeSlideSlots();
    appData.media.forEach((m) => {
      const parts = m.path.split("/");
      m._folder = parts.length > 2 ? parts[1] : "Root";
      availableFolders.add(m._folder);
    });

    populateDropdowns();
    filteredMedia = [...appData.media];

    if (appData.slides.length > 0) {
      activeAssemblySlide = String(appData.slides[0].slide);
      targetCurationSlide = String(appData.slides[0].slide);
    }

    renderScriptTab();
    renderCurationSidebar();
    renderAssemblyNav();
    updateInspectorUI();
    applyFiltersAndRenderGrid();

    setupCanvasEngine();
    preloadAndRenderCanvas();
    if (normalized) saveManifest();
  } catch (error) {
    console.error("Deck prototyper failed to initialize", error);
    saveStatus.textContent = "Connection Error";
  }
}

function autoResizeTextarea(el) {
  el.style.height = "auto";
  el.style.height = el.scrollHeight + "px";
}

function populateDropdowns() {
  if (!folderSelect || !typeSelect) return;
  folderSelect.innerHTML =
    `<option value="All">All Folders</option>` +
    Array.from(availableFolders)
      .sort()
      .map((f) => `<option value="${f}">${f}</option>`)
      .join("");
  typeSelect.innerHTML = `<option value="All">All Types</option><option value="images">Images</option><option value="gif">GIFs</option><option value="video">Videos</option>`;
  folderSelect.addEventListener("change", (e) => {
    selectedFolder = e.target.value;
    applyFiltersAndRenderGrid();
  });
  typeSelect.addEventListener("change", (e) => {
    selectedType = e.target.value;
    applyFiltersAndRenderGrid();
  });
}

function renderScriptTab() {
  const scriptContainer = document.getElementById("text-editor-grid");
  if (!scriptContainer) return;
  scriptContainer.innerHTML = appData.slides
    .map((s, idx) => {
      const custom = appData.manifest.customText[s.slide] || {};
      const layout = appData.manifest.slideLayouts[s.slide] || "full-bleed";
      const head = scrubText(custom.head !== undefined ? custom.head : s.head);
      const sub = scrubText(custom.sub !== undefined ? custom.sub : s.sub);
      const body = scrubText(custom.body !== undefined ? custom.body : s.body);
      const isFirst = idx === 0;
      const isLast = idx === appData.slides.length - 1;

      return `
            <div class="outline-slide" draggable="true" data-slide="${s.slide}">
                <div class="slide-num-container">
                    <span class="slide-num"><span class="drag-handle">::</span> Slide ${s.slide}</span>
                    <div class="slide-card-tools">
                        <button class="mini-btn" onclick="moveSlide('${s.slide}', -1)" ${isFirst ? "disabled" : ""}>Up</button>
                        <button class="mini-btn" onclick="moveSlide('${s.slide}', 1)" ${isLast ? "disabled" : ""}>Down</button>
                        <button class="mini-btn" onclick="addSlideAfter('${s.slide}')">Add After</button>
                    </div>
                    <select class="layout-select custom-select" onchange="saveScriptLayout('${s.slide}', this.value)">
                        <option value="full-bleed" ${layout === "full-bleed" ? "selected" : ""}>Full Bleed (1 Img)</option>
                        <option value="split" ${layout === "split" ? "selected" : ""}>Split (2 Img)</option>
                        <option value="grid" ${layout === "grid" ? "selected" : ""}>Grid (12+ Img)</option>
                        <option value="text-only" ${layout === "text-only" ? "selected" : ""}>Text Only (0 Img)</option>
                    </select>
                </div>
                <input type="text" class="edit-input" placeholder="Headline..." value="${escapeHTML(head)}" onblur="saveScriptEdit('${s.slide}', 'head', this.value)">
                <input type="text" class="edit-input sub" placeholder="Subhead..." value="${escapeHTML(sub)}" onblur="saveScriptEdit('${s.slide}', 'sub', this.value)">
                <textarea class="edit-textarea" placeholder="Body copy..." oninput="autoResizeTextarea(this)" onblur="saveScriptEdit('${s.slide}', 'body', this.value)">${escapeHTML(body)}</textarea>
            </div>
        `;
    })
    .join("");
  document.querySelectorAll(".edit-textarea").forEach(autoResizeTextarea);
  attachSlideDragHandlers("#text-editor-grid .outline-slide");
}

window.saveScriptLayout = function (slideNum, layout) {
  appData.manifest.slideLayouts[slideNum] = layout;
  normalizeSlideSlots();
  clampActiveMediaSlot(slideNum);
  saveManifest();
  updateInspectorUI();
  if (String(activeAssemblySlide) === String(slideNum)) {
    preloadAndRenderCanvas();
  }
};

function renderCurationSidebar() {
  const container = document.getElementById("curation-sidebar-script");
  if (!container) return;
  container.innerHTML = appData.slides
    .map((s) => {
      const custom = appData.manifest.customText[s.slide] || {};
      const head =
        scrubText(custom.head !== undefined ? custom.head : s.head) ||
        "Untitled";
      const body =
        scrubText(custom.body !== undefined ? custom.body : s.body) || "";
      const isActive = String(s.slide) === targetCurationSlide;
      return `
            <div class="curation-sidebar-item ${isActive ? "active-target" : ""}" onclick="setTargetCurationSlide('${s.slide}')">
                <div style="font-size:10px; color:var(--accent); font-weight:700; margin-bottom:4px; letter-spacing:0.05em;">SLIDE ${s.slide}</div>
                <div style="font-size:13px; font-weight:600; color:var(--text-main); margin-bottom:4px; line-height:1.2;">${head}</div>
                <div style="font-size:11px; color:var(--text-muted); line-height:1.4; white-space:pre-wrap;">${body}</div>
            </div>
        `;
    })
    .join("");
}

window.setTargetCurationSlide = function (slideNum) {
  targetCurationSlide = String(slideNum);
  renderCurationSidebar();
};

window.saveScriptEdit = function (slideNum, field, value) {
  if (!appData.manifest.customText[slideNum])
    appData.manifest.customText[slideNum] = {};
  appData.manifest.customText[slideNum][field] = value;
  const slide = appData.slides.find(
    (s) => String(s.slide) === String(slideNum),
  );
  if (slide) slide[field] = value;
  saveManifest();
  scheduleScriptFileSync();
  renderCurationSidebar();
  if (
    activePhase === "view-assembly" &&
    String(activeAssemblySlide) === String(slideNum)
  )
    triggerCanvasRender();
};

function nextSlideNumber() {
  const nums = appData.slides.map((s) => parseInt(s.slide, 10) || 0);
  return String(Math.max(0, ...nums) + 1);
}

function remapManifestSlideKeys(mapping) {
  ["customText", "slideSlots", "slideSettings", "slideLayouts", "slideNotes"].forEach(
    (key) => {
      const source = appData.manifest[key] || {};
      const next = {};
      Object.keys(source).forEach((oldSlide) => {
        next[mapping[oldSlide] || oldSlide] = source[oldSlide];
      });
      appData.manifest[key] = next;
    },
  );
}

function renumberSlides() {
  const mapping = {};
  appData.slides.forEach((slide, idx) => {
    const oldSlide = String(slide.slide);
    const newSlide = String(idx + 1);
    mapping[oldSlide] = newSlide;
    slide.slide = newSlide;
  });
  remapManifestSlideKeys(mapping);
  if (activeAssemblySlide) activeAssemblySlide = mapping[activeAssemblySlide];
  if (targetCurationSlide) targetCurationSlide = mapping[targetCurationSlide];
}

function reorderSlide(sourceSlideNum, targetSlideNum) {
  if (String(sourceSlideNum) === String(targetSlideNum)) return;
  const sourceIdx = appData.slides.findIndex(
    (s) => String(s.slide) === String(sourceSlideNum),
  );
  const targetIdx = appData.slides.findIndex(
    (s) => String(s.slide) === String(targetSlideNum),
  );
  if (sourceIdx < 0 || targetIdx < 0) return;
  const [slide] = appData.slides.splice(sourceIdx, 1);
  appData.slides.splice(targetIdx, 0, slide);
  activeAssemblySlide = String(slide.slide);
  targetCurationSlide = String(slide.slide);
  renumberSlides();
  saveManifest();
  syncScriptToFile();
  renderAllViews();
}

function attachSlideDragHandlers(containerSelector) {
  document.querySelectorAll(containerSelector).forEach((el) => {
    const handle = el.querySelector(".drag-handle");
    handle?.addEventListener("pointerdown", (e) => {
      pointerSlideDrag = {
        source: el.dataset.slide,
        pointerId: e.pointerId,
      };
      draggedSlideNum = el.dataset.slide;
      el.classList.add("is-dragging");
      handle.setPointerCapture(e.pointerId);
      e.preventDefault();
      e.stopPropagation();
    });
    handle?.addEventListener("pointermove", (e) => {
      if (!pointerSlideDrag) return;
      document
        .querySelectorAll(".is-drop-target")
        .forEach((node) => node.classList.remove("is-drop-target"));
      const target = document
        .elementFromPoint(e.clientX, e.clientY)
        ?.closest(".outline-slide, .nav-slide-card");
      if (target?.dataset.slide && target.dataset.slide !== pointerSlideDrag.source) {
        target.classList.add("is-drop-target");
      }
    });
    handle?.addEventListener("pointerup", (e) => {
      if (!pointerSlideDrag) return;
      const target = document
        .elementFromPoint(e.clientX, e.clientY)
        ?.closest(".outline-slide, .nav-slide-card");
      const sourceSlide = pointerSlideDrag.source;
      pointerSlideDrag = null;
      draggedSlideNum = null;
      document
        .querySelectorAll(".is-drop-target, .is-dragging")
        .forEach((node) => node.classList.remove("is-drop-target", "is-dragging"));
      if (target?.dataset.slide && target.dataset.slide !== sourceSlide) {
        reorderSlide(sourceSlide, target.dataset.slide);
      }
    });
    el.addEventListener("dragstart", (e) => {
      draggedSlideNum = el.dataset.slide;
      el.classList.add("is-dragging");
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", draggedSlideNum);
    });
    el.addEventListener("dragover", (e) => {
      e.preventDefault();
      if (draggedSlideNum && draggedSlideNum !== el.dataset.slide) {
        el.classList.add("is-drop-target");
      }
    });
    el.addEventListener("dragleave", () => {
      el.classList.remove("is-drop-target");
    });
    el.addEventListener("drop", (e) => {
      e.preventDefault();
      const sourceSlide = e.dataTransfer.getData("text/plain") || draggedSlideNum;
      const targetSlide = el.dataset.slide;
      document
        .querySelectorAll(".is-drop-target, .is-dragging")
        .forEach((node) => node.classList.remove("is-drop-target", "is-dragging"));
      reorderSlide(sourceSlide, targetSlide);
      draggedSlideNum = null;
    });
    el.addEventListener("dragend", () => {
      draggedSlideNum = null;
      document
        .querySelectorAll(".is-drop-target, .is-dragging")
        .forEach((node) => node.classList.remove("is-drop-target", "is-dragging"));
    });
  });
}

window.addSlideAfter = function (slideNum = null) {
  const insertAt = slideNum
    ? appData.slides.findIndex((s) => String(s.slide) === String(slideNum)) + 1
    : appData.slides.length;
  const newSlide = {
    slide: nextSlideNumber(),
    head: "Untitled Slide",
    sub: "",
    body: "",
  };
  appData.slides.splice(insertAt < 1 ? appData.slides.length : insertAt, 0, newSlide);
  activeAssemblySlide = String(newSlide.slide);
  targetCurationSlide = String(newSlide.slide);
  renumberSlides();
  appData.manifest.slideLayouts[activeAssemblySlide] = "full-bleed";
  saveManifest();
  syncScriptToFile();
  renderAllViews();
};

window.moveSlide = function (slideNum, direction) {
  const idx = appData.slides.findIndex((s) => String(s.slide) === String(slideNum));
  const newIdx = idx + direction;
  if (idx < 0 || newIdx < 0 || newIdx >= appData.slides.length) return;
  const [slide] = appData.slides.splice(idx, 1);
  appData.slides.splice(newIdx, 0, slide);
  activeAssemblySlide = String(slide.slide);
  targetCurationSlide = String(slide.slide);
  renumberSlides();
  saveManifest();
  syncScriptToFile();
  renderAllViews();
};

document
  .getElementById("btn-add-slide")
  ?.addEventListener("click", () => window.addSlideAfter());

if (searchInput)
  searchInput.addEventListener("input", (e) => {
    searchQuery = e.target.value.toLowerCase();
    applyFiltersAndRenderGrid();
  });
thumbSliderElement?.addEventListener("input", (e) => {
  document
    .getElementById("media-grid")
    ?.style.setProperty("--thumb-size", `${e.target.value}px`);
});
filterBtns.forEach((btn) => {
  btn.addEventListener("click", (e) => {
    filterBtns.forEach((b) => b.classList.remove("active"));
    e.target.classList.add("active");
    currentFilter = e.target.dataset.filter;
    applyFiltersAndRenderGrid();
  });
});

function isMediaSlotted(filename) {
  const slots = appData.manifest.slideSlots;
  for (const slide in slots) {
    if (slots[slide].mains && slots[slide].mains.includes(filename))
      return true;
    if (slots[slide].backups && slots[slide].backups.includes(filename))
      return true;
  }
  return false;
}
function isMediaMainAnywhere(filename) {
  const slots = appData.manifest.slideSlots;
  for (const slide in slots) {
    if (slots[slide].mains && slots[slide].mains.includes(filename))
      return true;
  }
  return false;
}

function applyFiltersAndRenderGrid() {
  filteredMedia = appData.media.filter((m) => {
    const tags = appData.manifest.mediaTags[m.filename] || {};
    if (searchQuery && !m.filename.toLowerCase().includes(searchQuery))
      return false;
    if (currentFilter === "shortlist" && !tags.shortlist) return false;
    if (currentFilter === "starred" && !tags.star) return false;
    if (currentFilter === "slotted" && !isMediaSlotted(m.filename))
      return false;
    if (currentFilter === "unused" && isMediaSlotted(m.filename)) return false;
    if (selectedFolder !== "All" && m._folder !== selectedFolder) return false;
    const isImage = ["jpg", "jpeg", "png", "webp"].includes(m.type);
    const isVideo = ["mp4", "mov", "webm"].includes(m.type);
    if (selectedType === "images" && !isImage) return false;
    if (selectedType === "gif" && m.type !== "gif") return false;
    if (selectedType === "video" && !isVideo) return false;
    return true;
  });
  gridFocusIndex = -1;
  renderMediaGrid();
}

function renderMediaGrid() {
  const mediaGrid = document.getElementById("media-grid");
  if (!mediaGrid) return;
  if (mediaCountEl)
    mediaCountEl.textContent = `${filteredMedia.length} ${filteredMedia.length === 1 ? "file" : "files"}`;
  if (filteredMedia.length === 0) {
    mediaGrid.innerHTML = `<div class="media-grid-empty">No media matches these filters.</div>`;
    return;
  }

  mediaGrid.innerHTML = filteredMedia
    .map((m, idx) => {
      const tags = appData.manifest.mediaTags[m.filename] || {};
      let badges = "";
      if (tags.shortlist) badges += `<span class="badge">Shortlist</span>`;
      if (tags.star) badges += `<span class="badge">★ ${tags.star}</span>`;

      const slots = appData.manifest.slideSlots;
      for (const slide in slots) {
        if (slots[slide].mains && slots[slide].mains.includes(m.filename))
          badges += `<span class="badge main-badge">Main: S${slide}</span>`;
        if (slots[slide].backups && slots[slide].backups.includes(m.filename))
          badges += `<span class="badge backup-badge">Backup: S${slide}</span>`;
      }

      const isGif = m.type === "gif";
      const isVideo = ["mp4", "mov", "webm"].includes(m.type);
      const thumbUrl = `/api/thumb?file=${encodeURIComponent(m.path)}`;
      const fullUrl = `/${m.path}`;
      const mainClass = isMediaMainAnywhere(m.filename)
        ? "is-main-slotted"
        : "";
      let indicator = "";
      if (isGif) indicator = `<div class="type-indicator">GIF</div>`;
      if (isVideo) indicator = `<div class="type-indicator">VIDEO</div>`;

      return `
            <div class="media-card ${mainClass} ${idx === gridFocusIndex ? "focused" : ""}" data-idx="${idx}" data-full="${fullUrl}" data-thumb="${thumbUrl}">
                ${indicator}
                <img src="${thumbUrl}" loading="lazy" alt="media">
                <div class="card-badges">${badges}</div>
            </div>
        `;
    })
    .join("");

  document.querySelectorAll(".media-card").forEach((card) => {
    card.addEventListener("mousemove", () => {
      if (!document.body.classList.contains("keyboard-nav")) {
        const idx = parseInt(card.dataset.idx);
        if (gridFocusIndex !== idx) {
          gridFocusIndex = idx;
          document
            .querySelectorAll(".media-card")
            .forEach((c) => c.classList.remove("focused"));
          card.classList.add("focused");
        }
      }
    });

    card.addEventListener("click", () => {
      gridFocusIndex = parseInt(card.dataset.idx);
      openLightbox(gridFocusIndex);
    });

    card.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      cmActiveMediaIndex = parseInt(card.dataset.idx);
      const media = filteredMedia[cmActiveMediaIndex];
      updateContextMenuForMedia(media);
      positionContextMenu(e.clientX, e.clientY);
    });

    const img = card.querySelector("img");
    if (card.querySelector(".type-indicator")?.textContent === "GIF") {
      card.addEventListener("mouseenter", () => (img.src = card.dataset.full));
      card.addEventListener("mouseleave", () => (img.src = card.dataset.thumb));
    }
  });
}

function closeContextMenu() {
  if (!contextMenu) return;
  contextMenu.classList.remove("active");
  contextMenu.setAttribute("aria-hidden", "true");
}

function updateContextMenuForMedia(media) {
  if (!contextMenu || !media) return;
  const tags = appData.manifest.mediaTags?.[media.filename] || {};
  const title = document.getElementById("cm-media-title");
  const shortlistBtn = document.getElementById("cm-shortlist");
  const mainBtn = document.getElementById("cm-set-main");
  const backupBtn = document.getElementById("cm-set-backup");
  const targetLabel = targetCurationSlide
    ? `Slide ${targetCurationSlide}`
    : "target slide";

  if (title) title.textContent = media.filename;
  if (shortlistBtn) {
    shortlistBtn.innerHTML = tags.shortlist
      ? "Remove from Shortlist <span>S</span>"
      : "Add to Shortlist <span>S</span>";
  }

  document.querySelectorAll(".cm-chip").forEach((chip) => {
    chip.classList.toggle("active-chip", tags.star === chip.dataset.star);
  });

  if (mainBtn) {
    mainBtn.textContent = targetCurationSlide
      ? `Set as main for ${targetLabel}`
      : "Pick a target slide first";
    mainBtn.disabled =
      !targetCurationSlide || getLayoutLimit(targetCurationSlide) === 0;
  }
  if (backupBtn) {
    backupBtn.textContent = targetCurationSlide
      ? `Add as alternate for ${targetLabel}`
      : "Pick a target slide first";
    backupBtn.disabled = !targetCurationSlide;
  }
}

function positionContextMenu(clientX, clientY) {
  if (!contextMenu) return;
  const margin = CONTEXT_MENU_MARGIN;
  const viewportW = window.innerWidth;
  const viewportH = window.innerHeight;

  contextMenu.classList.remove("active");
  contextMenu.style.visibility = "hidden";
  contextMenu.style.display = "block";
  contextMenu.style.maxHeight = "none";
  contextMenu.style.overflowY = "visible";

  const naturalRect = contextMenu.getBoundingClientRect();
  const menuW = Math.min(naturalRect.width, viewportW - margin * 2);
  const menuH = Math.min(naturalRect.height, viewportH - margin * 2);
  let left = clientX;
  let top = clientY;
  let xSide = "right";
  let ySide = "down";

  if (clientX + menuW + margin > viewportW && clientX - menuW > margin) {
    left = clientX - menuW;
    xSide = "left";
  }
  if (clientY + menuH + margin > viewportH && clientY - menuH > margin) {
    top = clientY - menuH;
    ySide = "up";
  }

  left = Math.max(margin, Math.min(left, viewportW - menuW - margin));
  top = Math.max(margin, Math.min(top, viewportH - menuH - margin));

  contextMenu.dataset.xSide = xSide;
  contextMenu.dataset.ySide = ySide;
  contextMenu.style.setProperty(
    "--menu-origin",
    `${ySide === "up" ? "bottom" : "top"} ${
      xSide === "left" ? "right" : "left"
    }`,
  );
  contextMenu.style.maxHeight = `${Math.max(120, viewportH - margin * 2)}px`;
  contextMenu.style.overflowY =
    naturalRect.height > viewportH - margin * 2 ? "auto" : "visible";
  contextMenu.style.left = `${left}px`;
  contextMenu.style.top = `${top}px`;
  void contextMenu.offsetWidth;
  contextMenu.style.visibility = "visible";
  contextMenu.setAttribute("aria-hidden", "false");
  contextMenu.classList.add("active");
}

document.addEventListener("click", (e) => {
  if (!e.target.closest(".context-menu")) closeContextMenu();
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") closeContextMenu();
});
document
  .getElementById("cm-shortlist")
  ?.addEventListener("click", () => handleCMAction("shortlist"));
document.getElementById("cm-open-preview")?.addEventListener("click", () => {
  if (cmActiveMediaIndex === -1) return;
  gridFocusIndex = cmActiveMediaIndex;
  closeContextMenu();
  openLightbox(cmActiveMediaIndex);
});
document.getElementById("cm-set-main")?.addEventListener("click", () => {
  if (!targetCurationSlide) return;
  handleCMAction("main", targetCurationSlide);
});
document.getElementById("cm-set-backup")?.addEventListener("click", () => {
  if (!targetCurationSlide) return;
  handleCMAction("backup", targetCurationSlide);
});
document
  .querySelectorAll(".cm-chip")
  .forEach((el) => {
    el.addEventListener("click", (e) => {
      if (e.target.dataset.star) handleCMAction("star", e.target.dataset.star);
    });
  });
window.addEventListener("resize", closeContextMenu);
window.addEventListener("scroll", closeContextMenu, true);

function getLayoutLimit(slideNum) {
  const layout = appData.manifest.slideLayouts[slideNum] || "full-bleed";
  if (layout === "split") return 2;
  if (layout === "grid") return 100;
  if (layout === "text-only") return 0;
  return 1;
}

function getVisibleSlotCount(slideNum) {
  const layout = appData.manifest.slideLayouts[slideNum] || "full-bleed";
  const slot = appData.manifest.slideSlots[slideNum] || { mains: [] };
  if (layout === "text-only") return 0;
  if (layout === "full-bleed") return 1;
  if (layout === "split") return 2;
  return Math.max(1, slot.mains?.length || 0);
}

function ensureSlotTransform(slideNum, idx) {
  const settings = ensureSlideSettings(slideNum);
  if (!settings.slotTransforms[idx]) {
    settings.slotTransforms[idx] = { x: 0, y: 0, scale: 100, flip: false };
  }
  return settings.slotTransforms[idx];
}

function clampActiveMediaSlot(slideNum) {
  const visibleSlots = getVisibleSlotCount(slideNum);
  activeMediaSlotIndex = Math.max(
    0,
    Math.min(activeMediaSlotIndex, Math.max(0, visibleSlots - 1)),
  );
}

function normalizeSlideSlots() {
  let changed = false;
  Object.keys(appData.manifest.slideSlots).forEach((slideNum) => {
    const slot = appData.manifest.slideSlots[slideNum] || {};
    const mains = Array.isArray(slot.mains) ? slot.mains : [];
    const backups = Array.isArray(slot.backups) ? slot.backups : [];
    const limit = getLayoutLimit(slideNum);
    const allowedMains = mains.slice(0, limit);
    const extraMains = mains.slice(limit);
    const backupSet = new Set([...extraMains, ...backups]);

    allowedMains.forEach((filename) => backupSet.delete(filename));
    slot.mains = allowedMains;
    slot.backups = Array.from(backupSet);
    appData.manifest.slideSlots[slideNum] = slot;
    const settings = ensureSlideSettings(slideNum);
    if (settings.slotTransforms.length > allowedMains.length) {
      settings.slotTransforms = settings.slotTransforms.slice(
        0,
        allowedMains.length,
      );
    }

    if (
      slot.mains.length !== mains.length ||
      slot.backups.length !== backups.length ||
      extraMains.length > 0
    ) {
      changed = true;
    }
  });
  return changed;
}

function executeTaggingAction(filename, action, val = null) {
  if (!appData.manifest.mediaTags[filename])
    appData.manifest.mediaTags[filename] = {};
  const tags = appData.manifest.mediaTags[filename];

  if (action === "shortlist") tags.shortlist = !tags.shortlist;
  if (action === "star") tags.star = tags.star === val ? null : val;

  if (action === "main" || action === "backup") {
    const slideNum = val;
    if (!slideNum) return;
    if (!appData.manifest.slideSlots[slideNum])
      appData.manifest.slideSlots[slideNum] = { mains: [], backups: [] };
    const slot = appData.manifest.slideSlots[slideNum];
    const limit = getLayoutLimit(slideNum);
    const settings = ensureSlideSettings(slideNum);

    if (action === "main" && limit > 0) {
      if (slot.mains.includes(filename)) {
        const idx = slot.mains.indexOf(filename);
        slot.mains = slot.mains.filter((f) => f !== filename);
        if (idx > -1) settings.slotTransforms.splice(idx, 1);
      } else {
        if (slot.mains.length >= limit) {
          const oldest = slot.mains.shift();
          if (!slot.backups.includes(oldest)) slot.backups.push(oldest);
          settings.slotTransforms.shift();
        }
        slot.mains.push(filename);
        activeMediaSlotIndex = slot.mains.length - 1;
        ensureSlotTransform(slideNum, activeMediaSlotIndex);
        slot.backups = slot.backups.filter((f) => f !== filename);
      }
    }
    if (action === "backup") {
      if (slot.backups.includes(filename)) {
        slot.backups = slot.backups.filter((f) => f !== filename);
      } else {
        slot.backups.push(filename);
        const mainIdx = slot.mains.indexOf(filename);
        slot.mains = slot.mains.filter((f) => f !== filename);
        if (mainIdx > -1) settings.slotTransforms.splice(mainIdx, 1);
      }
    }
  }
  closeContextMenu();
  saveManifest();
  renderMediaGrid();
}

function handleCMAction(action, val = null) {
  if (cmActiveMediaIndex === -1) return;
  executeTaggingAction(filteredMedia[cmActiveMediaIndex].filename, action, val);
}

const lightbox = document.getElementById("lightbox");
const lbImg = document.getElementById("lb-img");
const lbBadges = document.getElementById("lb-badge-container");
const lbMeta = document.getElementById("lb-meta");
const lbSlotsArea = document.getElementById("lb-slots");

function openLightbox(idx) {
  if (idx < 0 || idx >= filteredMedia.length) return;
  lightboxActiveIndex = idx;
  lbSelectedSlideIdx = appData.slides.findIndex(
    (s) => String(s.slide) === targetCurationSlide,
  );
  if (lbSelectedSlideIdx === -1) lbSelectedSlideIdx = 0;
  updateLightboxUI();
  lightbox.classList.add("active");
}

function closeLightbox() {
  lightbox.classList.remove("active");
  gridFocusIndex = lightboxActiveIndex;
  lightboxActiveIndex = -1;
  renderMediaGrid();
  setTimeout(() => {
    document
      .querySelector(".media-card.focused")
      ?.scrollIntoView({ behavior: "smooth", block: "center" });
  }, 10);
}
document.getElementById("lb-close")?.addEventListener("click", closeLightbox);

window.assignSlotFromClick = function (slideNum, action, e) {
  e.stopPropagation();
  executeTaggingAction(
    filteredMedia[lightboxActiveIndex].filename,
    action,
    slideNum,
  );
  updateLightboxUI();
};

function updateLightboxUI() {
  if (lightboxActiveIndex === -1) return;
  const media = filteredMedia[lightboxActiveIndex];
  lbImg.src = `/${media.path}`;

  const tags = appData.manifest.mediaTags[media.filename] || {};
  let html = "";
  if (tags.shortlist) html += `<div class="lb-badge">Shortlisted</div>`;
  if (tags.star)
    html += `<div class="lb-badge" style="background: var(--accent); color: #fff;">★ ${tags.star}</div>`;
  lbBadges.innerHTML = html;
  lbMeta.innerHTML = `<strong>${media.filename}</strong><span>Folder: ${media._folder}</span><span>Type: ${media.type.toUpperCase()}</span>`;

  lbSlotsArea.innerHTML = appData.slides
    .map((s, idx) => {
      const slideNum = s.slide;
      const slotData = appData.manifest.slideSlots[slideNum] || {
        mains: [],
        backups: [],
      };
      const layout = appData.manifest.slideLayouts[slideNum] || "full-bleed";
      const limit = getLayoutLimit(slideNum);

      const head = scrubText(s.head);
      const sub = scrubText(s.sub);
      const body = scrubText(s.body);

      let statusHtml = "Empty";
      let isMain = slotData.mains && slotData.mains.includes(media.filename);
      let isBackup =
        slotData.backups && slotData.backups.includes(media.filename);

      if (layout === "text-only") statusHtml = `Text Only`;
      else if (isMain)
        statusHtml = `Main (${slotData.mains.indexOf(media.filename) + 1}/${limit})`;
      else if (isBackup) statusHtml = `Backup`;
      else if (slotData.mains && slotData.mains.length > 0)
        statusHtml = `Has ${slotData.mains.length}/${limit === 100 ? "∞" : limit} Mains`;

      const dis = layout === "text-only" ? "disabled" : "";
      return `
            <div class="slot-row ${idx === lbSelectedSlideIdx ? "focused-slot" : ""} ${isMain ? "active-main" : ""}">
                <div class="slot-header">
                    <span class="slot-number">Slide ${slideNum}</span>
                    <div class="slot-status-pill">${statusHtml}</div>
                </div>
                <div class="slot-text-preview">
                    ${head ? `<div class="slot-head">${head}</div>` : ""}
                    ${sub ? `<div class="slot-sub">${sub}</div>` : ""}
                    ${body ? `<div class="slot-body">${body}</div>` : ""}
                </div>
                <div class="slot-action-bar">
                    <button class="slot-action-btn btn-main" onclick="assignSlotFromClick('${slideNum}', 'main', event)" ${dis}>${isMain ? "★ MAIN" : "SET MAIN"}</button>
                    <button class="slot-action-btn btn-backup" onclick="assignSlotFromClick('${slideNum}', 'backup', event)">${isBackup ? "✓ BACKUP" : "SET BACKUP"}</button>
                </div>
            </div>
        `;
    })
    .join("");
  document
    .querySelector(".slot-row.focused-slot")
    ?.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

function renderAssemblyNav() {
  const navContainer = document.getElementById("slide-nav");
  if (!navContainer) return;
  if (appData.slides.length > 10) {
    let html = "";
    for (let i = 0; i < appData.slides.length; i += 10) {
      const chunk = appData.slides.slice(i, i + 10);
      html += `<div class="nav-group-header">Slides ${chunk[0].slide}-${chunk[chunk.length - 1].slide}</div>`;
      html += chunk
        .map(
          (s) => `
                <div class="nav-slide-card ${String(activeAssemblySlide) === String(s.slide) ? "active-nav" : ""}" draggable="true" data-slide="${s.slide}" onclick="switchAssemblySlide('${s.slide}')">
                    <div class="slide-num" style="margin-bottom: 4px;"><span class="drag-handle">::</span> Slide ${s.slide}</div>
                    <div style="font-size: 13px; font-weight: 600; color:var(--text-main);">${scrubText(s.head) || "Untitled"}</div>
                </div>
            `,
        )
        .join("");
    }
    navContainer.innerHTML = html;
  } else {
    navContainer.innerHTML = appData.slides
      .map(
        (s) => `
            <div class="nav-slide-card ${String(activeAssemblySlide) === String(s.slide) ? "active-nav" : ""}" draggable="true" data-slide="${s.slide}" onclick="switchAssemblySlide('${s.slide}')">
                <div class="slide-num" style="margin-bottom: 4px;"><span class="drag-handle">::</span> Slide ${s.slide}</div>
                <div style="font-size: 13px; font-weight: 600; color:var(--text-main);">${scrubText(s.head) || "Untitled"}</div>
            </div>
        `,
      )
      .join("");
  }
  attachSlideDragHandlers("#slide-nav .nav-slide-card");
}

window.switchAssemblySlide = function (slideNum) {
  activeAssemblySlide = String(slideNum);
  clampActiveMediaSlot(activeAssemblySlide);
  renderAssemblyNav();
  updateInspectorUI();
  preloadAndRenderCanvas();
};

document.getElementById("btn-layer-media")?.addEventListener("click", () => {
  activeControlLayer = "media";
  document.getElementById("btn-layer-media").classList.add("active-btn");
  document.getElementById("btn-layer-text").classList.remove("active-btn");
  document.getElementById("panel-media").style.display = "block";
  document.getElementById("panel-text").style.display = "none";
});

document.getElementById("btn-layer-text")?.addEventListener("click", () => {
  activeControlLayer = "text";
  document.getElementById("btn-layer-text").classList.add("active-btn");
  document.getElementById("btn-layer-media").classList.remove("active-btn");
  document.getElementById("panel-text").style.display = "block";
  document.getElementById("panel-media").style.display = "none";
});

document.getElementById("slide-notes")?.addEventListener("blur", (e) => {
  if (!activeAssemblySlide) return;
  if (!appData.manifest.slideNotes) appData.manifest.slideNotes = {};
  appData.manifest.slideNotes[activeAssemblySlide] = e.target.value;
  saveManifest();
});

document.getElementById("tab-mains")?.addEventListener("click", () => {
  document.getElementById("tab-mains").style.color = "var(--accent)";
  document.getElementById("tab-mains").style.borderBottom =
    "2px solid var(--accent)";
  document.getElementById("tab-backups").style.color = "var(--text-muted)";
  document.getElementById("tab-backups").style.borderBottom = "none";
  document.getElementById("inspector-mains-area").style.display = "flex";
  document.getElementById("inspector-backups-area").style.display = "none";
});

document.getElementById("tab-backups")?.addEventListener("click", () => {
  document.getElementById("tab-backups").style.color = "var(--accent)";
  document.getElementById("tab-backups").style.borderBottom =
    "2px solid var(--accent)";
  document.getElementById("tab-mains").style.color = "var(--text-muted)";
  document.getElementById("tab-mains").style.borderBottom = "none";
  document.getElementById("inspector-backups-area").style.display = "flex";
  document.getElementById("inspector-mains-area").style.display = "none";
});

window.shiftMain = function (slideNum, idx, dir) {
  if (!appData.manifest.slideSlots[slideNum]) return;
  const mains = appData.manifest.slideSlots[slideNum].mains;
  const newIdx = idx + dir;
  if (newIdx < 0 || newIdx >= mains.length) return;
  const settings = ensureSlideSettings(slideNum);
  [mains[idx], mains[newIdx]] = [mains[newIdx], mains[idx]];
  [settings.slotTransforms[idx], settings.slotTransforms[newIdx]] = [
    settings.slotTransforms[newIdx] || { x: 0, y: 0, scale: 100, flip: false },
    settings.slotTransforms[idx] || { x: 0, y: 0, scale: 100, flip: false },
  ];
  activeMediaSlotIndex = newIdx;
  saveManifest();
  updateInspectorUI();
  preloadAndRenderCanvas();
};

window.selectMediaSlot = function (slideNum, idx) {
  activeAssemblySlide = String(slideNum);
  activeMediaSlotIndex = idx;
  ensureSlotTransform(slideNum, idx);
  updateInspectorUI();
  triggerCanvasRender();
};

function updateInspectorUI() {
  const slide = appData.slides.find(
    (s) => String(s.slide) === String(activeAssemblySlide),
  );
  if (!slide) return;

  const settings = ensureSlideSettings(slide.slide);
  const layout = appData.manifest.slideLayouts[slide.slide] || "full-bleed";
  if (!appData.manifest.slideSlots[slide.slide]) {
    appData.manifest.slideSlots[slide.slide] = { mains: [], backups: [] };
  }
  const slotData = appData.manifest.slideSlots[slide.slide];
  if (!Array.isArray(slotData.mains)) slotData.mains = [];
  if (!Array.isArray(slotData.backups)) slotData.backups = [];
  clampActiveMediaSlot(slide.slide);
  const activeSlotTransform = ensureSlotTransform(slide.slide, activeMediaSlotIndex);
  const notes = appData.manifest.slideNotes?.[slide.slide] || "";

  document.getElementById("ctrl-scale").value = activeSlotTransform.scale || 100;
  document.getElementById("lbl-scale").textContent =
    `${activeSlotTransform.scale || 100}%`;
  document.getElementById("ctrl-flip").checked = activeSlotTransform.flip || false;
  document.getElementById("ctrl-text-width").value = settings.textWidth || 1600;
  document.getElementById("lbl-text-width").textContent =
    `${settings.textWidth || 1600}px`;
  document.getElementById("slide-notes").value = notes;

  const hasEditableMedia =
    layout !== "text-only" && Boolean(slotData.mains[activeMediaSlotIndex]);
  document.getElementById("ctrl-scale").disabled = !hasEditableMedia;
  document.getElementById("ctrl-flip").disabled = !hasEditableMedia;
  const framingLabel = document.getElementById("media-framing-label");
  if (framingLabel) {
    framingLabel.textContent = hasEditableMedia
      ? `Image Framing - Slot ${activeMediaSlotIndex + 1}`
      : "Image Framing";
  }

  const summaryArea = document.getElementById("slide-media-summary");
  const limitText = layout === "grid" ? "many" : String(getLayoutLimit(slide.slide));
  if (summaryArea) {
    summaryArea.innerHTML = `
      <span>${layout.replace("-", " ")}</span>
      <strong>${slotData.mains?.length || 0}/${limitText} main</strong>
      <span>${slotData.backups?.length || 0} alternate</span>
    `;
  }

  const visibleSlots = getVisibleSlotCount(slide.slide);
  const slotRailHtml =
    visibleSlots > 0
      ? `<div class="media-slot-rail">${Array.from({ length: visibleSlots })
          .map((_, idx) => {
            const filename = slotData.mains[idx];
            const media = appData.media.find((x) => x.filename === filename);
            const thumb = media
              ? `<img src="/api/thumb?file=${encodeURIComponent(media.path)}" alt="${escapeHTML(filename)}" />`
              : `<span>Empty</span>`;
            return `
              <button class="media-slot-card ${idx === activeMediaSlotIndex ? "active-slot" : ""} ${filename ? "filled-slot" : "empty-slot"}" onclick="selectMediaSlot('${slide.slide}', ${idx})">
                <strong>Slot ${idx + 1}</strong>
                ${thumb}
              </button>
            `;
          })
          .join("")}</div>`
      : `<div class="slide-media-empty">This slide is text-only.</div>`;

  const renderMediaItem = (filename, role, idx) => {
    const m = appData.media.find((x) => x.filename === filename);
    const isGif = m?.type === "gif";
    const encodedFilename = encodeURIComponent(filename);
    if (!m) {
      return `
        <div class="slide-media-item missing">
          <div class="slide-media-thumb missing-media-chip">${escapeHTML(filename)}</div>
          <div class="slide-media-copy">
            <strong>Missing media</strong>
            <span>${escapeHTML(filename)}</span>
          </div>
          <button class="mini-btn" onclick="removeSlideMedia('${slide.slide}', '${encodedFilename}', '${role}')">Remove</button>
        </div>
      `;
    }
    return `
      <div class="slide-media-item ${role === "main" && idx === activeMediaSlotIndex ? "active-media-item" : ""}">
        <img class="slide-media-thumb" src="/api/thumb?file=${encodeURIComponent(m.path)}" alt="${escapeHTML(filename)}" />
        <div class="slide-media-copy">
          <strong>${role === "main" ? `Slot ${idx + 1}` : "Alternate"}</strong>
          <span>${escapeHTML(filename)}</span>
          ${isGif ? `<em>GIF - canvas uses a static preview frame</em>` : ""}
        </div>
        <div class="slide-media-actions">
          ${
            role === "main"
              ? `<button class="mini-btn" onclick="selectMediaSlot('${slide.slide}', ${idx})">Edit</button>
                 <button class="mini-btn" onclick="shiftMain('${slide.slide}', ${idx}, -1)">Left</button>
                 <button class="mini-btn" onclick="shiftMain('${slide.slide}', ${idx}, 1)">Right</button>`
              : `<button class="mini-btn" onclick="promoteBackupToMain('${slide.slide}', '${encodedFilename}')">Use next slot</button>`
          }
          <button class="mini-btn" onclick="removeSlideMedia('${slide.slide}', '${encodedFilename}', '${role}')">Remove</button>
        </div>
      </div>
    `;
  };

  const mainsArea = document.getElementById("inspector-mains-area");
  if (slotData.mains && slotData.mains.length > 0) {
    mainsArea.innerHTML = slotRailHtml + slotData.mains
      .map((filename, idx) => renderMediaItem(filename, "main", idx))
      .join("");
  } else {
    mainsArea.innerHTML =
      slotRailHtml +
      `<div class="slide-media-empty">No main media assigned. Add from Curation or promote an alternate.</div>`;
  }

  const backupsArea = document.getElementById("inspector-backups-area");
  if (slotData.backups && slotData.backups.length > 0) {
    backupsArea.innerHTML = slotData.backups
      .map((filename) => renderMediaItem(filename, "backup", 0))
      .join("");
  } else {
    backupsArea.innerHTML = `<div class="slide-media-empty">No alternates assigned.</div>`;
  }
}

async function ensureImagesLoaded(slideNum) {
  const slotData = appData.manifest.slideSlots[slideNum] || { mains: [] };
  const mains = Array.isArray(slotData.mains) ? slotData.mains : [];
  const promises = mains.map((filename) => {
    return new Promise((resolve) => {
      if (loadedImages[filename]) resolve();
      else {
        const media = appData.media.find((m) => m.filename === filename);
        if (!media) {
          resolve();
          return;
        }
        const img = new Image();
        img.onload = () => {
          loadedImages[filename] = img;
          resolve();
        };
        img.onerror = () => resolve();
        img.src = `/${media.path}`;
      }
    });
  });
  await Promise.all(promises);
}

function preloadAndRenderCanvas() {
  if (!activeAssemblySlide) return;
  ensureImagesLoaded(activeAssemblySlide).then(() => triggerCanvasRender());
}

function triggerCanvasRender() {
  if (canvasRenderLoop) cancelAnimationFrame(canvasRenderLoop);
  canvasRenderLoop = requestAnimationFrame(() => {
    if (!ctx || !activeAssemblySlide) return;
    drawSlideToContext(activeAssemblySlide, ctx, false);
  });
}

function drawCheckerboard(context, w, h) {
  const size = 32;
  context.fillStyle = "#111111";
  context.fillRect(0, 0, w, h);
  context.fillStyle = "#181818";
  for (let y = 0; y < h; y += size) {
    for (let x = 0; x < w; x += size) {
      if ((Math.floor(x / size) + Math.floor(y / size)) % 2 === 0) {
        context.fillRect(x, y, size, size);
      }
    }
  }
}

function wrapText(context, text, x, y, maxWidth, lineHeight) {
  const paragraphs = text.split("\n");
  let currentY = y;
  context.textAlign = "center";
  context.textBaseline = "top";
  for (let p of paragraphs) {
    if (p.trim() === "") {
      currentY += lineHeight;
      continue;
    }
    const words = p.split(" ");
    let line = "";
    for (let n = 0; n < words.length; n++) {
      const testLine = line + words[n] + " ";
      if (context.measureText(testLine).width > maxWidth && n > 0) {
        context.fillText(line, x, currentY);
        line = words[n] + " ";
        currentY += lineHeight;
      } else {
        line = testLine;
      }
    }
    context.fillText(line, x, currentY);
    currentY += lineHeight;
  }
  return currentY;
}

function drawImageCoverInRect(context, img, rect, transform = {}) {
  const scale = (transform.scale || 100) / 100;
  const imgRatio = img.width / img.height;
  const rectRatio = rect.w / rect.h;
  let drawW = rect.w;
  let drawH = rect.h;

  if (imgRatio > rectRatio) {
    drawW = rect.h * imgRatio;
  } else {
    drawH = rect.w / imgRatio;
  }

  context.save();
  context.beginPath();
  context.rect(rect.x, rect.y, rect.w, rect.h);
  context.clip();
  context.translate(
    rect.x + rect.w / 2 + (transform.x || 0),
    rect.y + rect.h / 2 + (transform.y || 0),
  );
  context.scale(transform.flip ? -scale : scale, scale);
  context.drawImage(img, -drawW / 2, -drawH / 2, drawW, drawH);
  context.restore();
}

function getCanvasSlotAtPoint(slideNum, canvasX, canvasY) {
  const layout = appData.manifest.slideLayouts[slideNum] || "full-bleed";
  const slot = appData.manifest.slideSlots[slideNum] || { mains: [] };
  const mains = Array.isArray(slot.mains) ? slot.mains : [];
  if (layout === "text-only" || mains.length === 0) return -1;
  if (layout === "full-bleed") return 0;

  const count = layout === "split" ? 2 : Math.max(1, mains.length);
  const cols = layout === "split" ? 2 : Math.ceil(Math.sqrt(count));
  const rows = layout === "split" ? 1 : Math.ceil(count / cols);
  const col = Math.floor(canvasX / (2576 / cols));
  const row = Math.floor(canvasY / (1080 / rows));
  const idx = row * cols + col;
  return idx < mains.length ? idx : -1;
}

function drawSlideToContext(slideNum, targetCtx, forceGrid = false) {
  const slide = appData.slides.find(
    (s) => String(s.slide) === String(slideNum),
  );
  if (!slide) return;

  const custom = appData.manifest.customText[slideNum] || {};
  const settings = ensureSlideSettings(slideNum);
  const layout = appData.manifest.slideLayouts[slideNum] || "full-bleed";
  const slotData = appData.manifest.slideSlots[slideNum] || { mains: [] };
  if (!Array.isArray(slotData.mains)) slotData.mains = [];

  targetCtx.clearRect(0, 0, 2576, 1080);
  drawCheckerboard(targetCtx, 2576, 1080);

  if (layout !== "text-only" && slotData.mains.length > 0) {
    if (layout === "full-bleed") {
      const img = loadedImages[slotData.mains[0]];
      if (img) {
        drawImageCoverInRect(targetCtx, img, { x: 0, y: 0, w: 2576, h: 1080 }, ensureSlotTransform(slideNum, 0));
      }
    } else {
      const count = layout === "split" ? 2 : slotData.mains.length;
      let cols = layout === "split" ? 2 : Math.ceil(Math.sqrt(count));
      let rows = layout === "split" ? 1 : Math.ceil(count / cols);
      let cellW = 2576 / cols;
      let cellH = 1080 / rows;

      slotData.mains.forEach((filename, i) => {
        const img = loadedImages[filename];
        if (img) {
          let r = Math.floor(i / cols);
          let c = i % cols;
          drawImageCoverInRect(
            targetCtx,
            img,
            { x: c * cellW, y: r * cellH, w: cellW, h: cellH },
            ensureSlotTransform(slideNum, i),
          );
        }
      });
      targetCtx.strokeStyle = "#000";
      targetCtx.lineWidth = 12;
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          targetCtx.strokeRect(c * cellW, r * cellH, cellW, cellH);
        }
      }
    }
  }

  const head = scrubText(custom.head !== undefined ? custom.head : slide.head);
  const sub = scrubText(custom.sub !== undefined ? custom.sub : slide.sub);
  const body = scrubText(custom.body !== undefined ? custom.body : slide.body);

  targetCtx.save();
  targetCtx.translate(
    2576 / 2 + (settings.textX || 0),
    1080 / 2 + (settings.textY || 0),
  );
  targetCtx.shadowColor = "rgba(0, 0, 0, 0.8)";
  targetCtx.shadowOffsetY = 4;
  targetCtx.fillStyle = "#ffffff";

  let currentY = -300;
  const textWidth = settings.textWidth || 1600;

  if (head) {
    targetCtx.font = "600 156px -apple-system, sans-serif";
    targetCtx.shadowBlur = 24;
    currentY = wrapText(targetCtx, head, 0, currentY, textWidth, 124);
    currentY += 16;
  }
  if (sub) {
    targetCtx.font = "600 80px -apple-system, sans-serif";
    targetCtx.shadowBlur = 16;
    currentY = wrapText(targetCtx, sub, 0, currentY, textWidth, 72, true);
    currentY += 16;
  }
  if (body) {
    targetCtx.font = "32px Georgia, serif";
    targetCtx.shadowBlur = 16;
    currentY = wrapText(targetCtx, body, 0, currentY, textWidth, 46);
  }
  targetCtx.restore();

  if (forceGrid || document.getElementById("ctrl-show-grid")?.checked) {
    targetCtx.save();
    targetCtx.strokeStyle = "rgba(255, 71, 126, 0.3)";
    targetCtx.fillStyle = "rgba(255, 71, 126, 0.15)";
    targetCtx.lineWidth = 1;
    const cols = 24,
      rows = 12,
      marginX = 96,
      marginY = 64,
      gutterX = 16,
      gutterY = 8;
    const cellW = (2576 - 2 * marginX - (cols - 1) * gutterX) / cols;
    const cellH = (1080 - 2 * marginY - (rows - 1) * gutterY) / rows;
    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        targetCtx.fillRect(
          marginX + c * (cellW + gutterX),
          marginY + r * (cellH + gutterY),
          cellW,
          cellH,
        );
        targetCtx.strokeRect(
          marginX + c * (cellW + gutterX),
          marginY + r * (cellH + gutterY),
          cellW,
          cellH,
        );
      }
    }
    targetCtx.restore();
  }
}

function setupCanvasEngine() {
  if (!assemblyCanvas) return;
  assemblyCanvas.addEventListener("pointerdown", (e) => {
    if (!activeAssemblySlide || activePhase !== "view-assembly") return;
    const settings = ensureSlideSettings(activeAssemblySlide);
    const rect = assemblyCanvas.getBoundingClientRect();
    const canvasX = ((e.clientX - rect.left) / rect.width) * 2576;
    const canvasY = ((e.clientY - rect.top) / rect.height) * 1080;

    isDragging = true;
    dragStartX = e.clientX;
    dragStartY = e.clientY;

    if (activeControlLayer === "media") {
      const clickedSlot = getCanvasSlotAtPoint(
        activeAssemblySlide,
        canvasX,
        canvasY,
      );
      if (clickedSlot === -1) {
        isDragging = false;
        return;
      }
      activeMediaSlotIndex = clickedSlot;
      const slotTransform = ensureSlotTransform(
        activeAssemblySlide,
        activeMediaSlotIndex,
      );
      dragInitX = slotTransform.x || 0;
      dragInitY = slotTransform.y || 0;
      updateInspectorUI();
      return;
    }

    dragInitX = settings.textX || 0;
    dragInitY = settings.textY || 0;
  });

  window.addEventListener("pointermove", (e) => {
    if (!isDragging) return;
    const scaleX = assemblyCanvas.getBoundingClientRect().width / 2576;
    let dx = (e.clientX - dragStartX) / scaleX;
    let dy = (e.clientY - dragStartY) / scaleX;

    if (document.getElementById("ctrl-snap-grid")?.checked) {
      dx = Math.round(dx / 32) * 32;
      dy = Math.round(dy / 32) * 32;
    }

    const settings = ensureSlideSettings(activeAssemblySlide);
    if (activeControlLayer === "media") {
      const slotTransform = ensureSlotTransform(
        activeAssemblySlide,
        activeMediaSlotIndex,
      );
      slotTransform.x = dragInitX + dx;
      slotTransform.y = dragInitY + dy;
      if (activeMediaSlotIndex === 0) {
        settings.imgX = slotTransform.x;
        settings.imgY = slotTransform.y;
      }
    } else {
      settings.textX = dragInitX + dx;
      settings.textY = dragInitY + dy;
    }
    triggerCanvasRender();
  });

  window.addEventListener("pointerup", () => {
    if (isDragging) {
      isDragging = false;
      saveManifest();
    }
  });
}

function updateCanvasSettingsLive(key, value) {
  if (!activeAssemblySlide) return;
  const settings = ensureSlideSettings(activeAssemblySlide);
  if (key === "scale" || key === "flip") {
    const slotTransform = ensureSlotTransform(
      activeAssemblySlide,
      activeMediaSlotIndex,
    );
    slotTransform[key] = value;
    if (activeMediaSlotIndex === 0) settings[key] = value;
    if (key === "scale") document.getElementById("lbl-scale").textContent = `${value}%`;
  } else {
    settings[key] = value;
  }
  if (key === "textWidth") {
    document.getElementById("lbl-text-width").textContent = `${value}px`;
  }
  triggerCanvasRender();
}

document
  .getElementById("ctrl-scale")
  ?.addEventListener("input", (e) =>
    updateCanvasSettingsLive("scale", parseFloat(e.target.value)),
  );
document.getElementById("ctrl-scale")?.addEventListener("change", saveManifest);
document
  .getElementById("ctrl-text-width")
  ?.addEventListener("input", (e) =>
    updateCanvasSettingsLive("textWidth", parseFloat(e.target.value)),
  );
document
  .getElementById("ctrl-text-width")
  ?.addEventListener("change", saveManifest);
document.getElementById("ctrl-flip")?.addEventListener("change", (e) => {
  updateCanvasSettingsLive("flip", e.target.checked);
  saveManifest();
});
document
  .getElementById("ctrl-show-grid")
  ?.addEventListener("change", triggerCanvasRender);

document.getElementById("btn-reset-pos")?.addEventListener("click", () => {
  if (!activeAssemblySlide) return;
  const settings = ensureSlideSettings(activeAssemblySlide);
  if (activeControlLayer === "media") {
    const slotTransform = ensureSlotTransform(
      activeAssemblySlide,
      activeMediaSlotIndex,
    );
    slotTransform.x = 0;
    slotTransform.y = 0;
    slotTransform.scale = 100;
    slotTransform.flip = false;
    if (activeMediaSlotIndex === 0) {
      settings.imgX = 0;
      settings.imgY = 0;
      settings.scale = 100;
      settings.flip = false;
    }
  } else {
    settings.textX = 0;
    settings.textY = 0;
  }
  saveManifest();
  updateInspectorUI();
  triggerCanvasRender();
});

window.promoteBackupToMain = function (slideNum, filename) {
  filename = decodeURIComponent(filename);
  const slot = appData.manifest.slideSlots[slideNum];
  const settings = ensureSlideSettings(slideNum);
  const limit = getLayoutLimit(slideNum);
  if (limit > 0) {
    if (slot.mains.length >= limit) {
      const oldest = slot.mains.shift();
      if (!slot.backups.includes(oldest)) slot.backups.push(oldest);
      settings.slotTransforms.shift();
    }
    slot.mains.push(filename);
    activeMediaSlotIndex = slot.mains.length - 1;
    ensureSlotTransform(slideNum, activeMediaSlotIndex);
  }
  slot.backups = slot.backups.filter((f) => f !== filename);
  saveManifest();
  updateInspectorUI();
  preloadAndRenderCanvas();
};

window.removeSlideMedia = function (slideNum, filename, role) {
  filename = decodeURIComponent(filename);
  const slot = appData.manifest.slideSlots[slideNum];
  if (!slot) return;
  if (role === "main") {
    const idx = (slot.mains || []).indexOf(filename);
    slot.mains = (slot.mains || []).filter((f) => f !== filename);
    if (idx > -1) ensureSlideSettings(slideNum).slotTransforms.splice(idx, 1);
  }
  if (role === "backup") {
    slot.backups = (slot.backups || []).filter((f) => f !== filename);
  }
  clampActiveMediaSlot(slideNum);
  saveManifest();
  updateInspectorUI();
  preloadAndRenderCanvas();
};

document.querySelectorAll(".phase-btn").forEach((btn) => {
  btn.addEventListener("click", (e) => {
    document
      .querySelectorAll(".phase-btn")
      .forEach((b) => b.classList.remove("active"));
    document
      .querySelectorAll(".view-layer")
      .forEach((v) => v.classList.remove("active"));
    e.target.classList.add("active");
    activePhase = e.target.dataset.target;
    document.getElementById(activePhase).classList.add("active");
    if (activePhase === "view-curation") applyFiltersAndRenderGrid();
    if (activePhase === "view-assembly" && activeAssemblySlide)
      preloadAndRenderCanvas();
  });
});

window.addEventListener("mousemove", () => {
  document.body.classList.remove("keyboard-nav");
});

document.addEventListener("keydown", (e) => {
  if (
    e.target.tagName === "INPUT" ||
    e.target.tagName === "TEXTAREA" ||
    e.target.tagName === "SELECT"
  ) {
    if (e.key === "Escape") e.target.blur();
    return;
  }

  if (e.key === "?") {
    const modal = document.getElementById("help-modal");
    modal.open ? modal.close() : modal.showModal();
    return;
  }

  if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key))
    document.body.classList.add("keyboard-nav");

  if (
    activePhase === "view-curation" &&
    (e.key === "+" || e.key === "=" || e.key === "-" || e.key === "_")
  ) {
    let val = parseInt(thumbSliderElement.value);
    if (e.key === "+" || e.key === "=") val = Math.min(600, val + 40);
    if (e.key === "-" || e.key === "_") val = Math.max(150, val - 40);
    thumbSliderElement.value = val;
    document
      .getElementById("media-grid")
      ?.style.setProperty("--thumb-size", `${val}px`);
    return;
  }

  if (activePhase === "view-assembly") {
    if (e.key.toLowerCase() === "t")
      document.getElementById("btn-layer-text")?.click();
    if (e.key.toLowerCase() === "i")
      document.getElementById("btn-layer-media")?.click();
    if (e.key.toLowerCase() === "r")
      document.getElementById("btn-reset-pos")?.click();
  }

  if (lightbox.classList.contains("active")) {
    e.preventDefault();
    if (e.key === "Escape") closeLightbox();
    if (
      e.key === "ArrowRight" &&
      lightboxActiveIndex < filteredMedia.length - 1
    )
      openLightbox(lightboxActiveIndex + 1);
    if (e.key === "ArrowLeft" && lightboxActiveIndex > 0)
      openLightbox(lightboxActiveIndex - 1);
    if (e.key === "ArrowDown") {
      lbSelectedSlideIdx = Math.min(
        lbSelectedSlideIdx + 1,
        appData.slides.length - 1,
      );
      updateLightboxUI();
    }
    if (e.key === "ArrowUp") {
      lbSelectedSlideIdx = Math.max(lbSelectedSlideIdx - 1, 0);
      updateLightboxUI();
    }

    const media = filteredMedia[lightboxActiveIndex];
    const slideNum = appData.slides[lbSelectedSlideIdx].slide;

    if (e.key.toLowerCase() === "s")
      executeTaggingAction(media.filename, "shortlist");
    if (["1", "2", "3", "4", "5"].includes(e.key))
      executeTaggingAction(media.filename, "star", e.key);
    if (e.key.toLowerCase() === "m") {
      executeTaggingAction(media.filename, "main", slideNum);
      updateLightboxUI();
    }
    if (e.key.toLowerCase() === "b") {
      executeTaggingAction(media.filename, "backup", slideNum);
      updateLightboxUI();
    }
    return;
  }

  if (
    activePhase === "view-curation" &&
    !document.getElementById("help-modal").open
  ) {
    if (e.key === "Escape") searchInput.blur();
    const cards = document.querySelectorAll(".media-card");
    if (cards.length === 0) return;

    if (gridFocusIndex !== -1) {
      const media = filteredMedia[gridFocusIndex];
      if (e.key === " ") {
        e.preventDefault();
        openLightbox(gridFocusIndex);
        return;
      }
      if (e.key.toLowerCase() === "s")
        executeTaggingAction(media.filename, "shortlist");
      if (["1", "2", "3", "4", "5"].includes(e.key))
        executeTaggingAction(media.filename, "star", e.key);
      if (e.key.toLowerCase() === "m" && targetCurationSlide)
        executeTaggingAction(media.filename, "main", targetCurationSlide);
      if (e.key.toLowerCase() === "b" && targetCurationSlide)
        executeTaggingAction(media.filename, "backup", targetCurationSlide);
    }

    if (["ArrowRight", "ArrowLeft", "ArrowDown", "ArrowUp"].includes(e.key)) {
      e.preventDefault();
      const grid = document.getElementById("media-grid");
      const cols =
        Math.floor(grid.offsetWidth / (cards[0].offsetWidth + 16)) || 1;
      if (e.key === "ArrowRight")
        gridFocusIndex = Math.min(gridFocusIndex + 1, cards.length - 1);
      if (e.key === "ArrowLeft")
        gridFocusIndex = Math.max(gridFocusIndex - 1, 0);
      if (e.key === "ArrowDown")
        gridFocusIndex = Math.min(gridFocusIndex + cols, cards.length - 1);
      if (e.key === "ArrowUp")
        gridFocusIndex = Math.max(gridFocusIndex - cols, 0);
      renderMediaGrid();
      document
        .querySelector(".media-card.focused")
        ?.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }
});

// --- EXPORT PIPELINES ---
document
  .getElementById("btn-export-media")
  ?.addEventListener("click", async (e) => {
    const btn = e.target;
    btn.textContent = "Packaging Folder Assets...";
    btn.disabled = true;
    const project = document.getElementById("project-input").value;
    const version = document.getElementById("version-input").value;

    try {
      const res = await fetch("/api/export-media", {
        method: "POST",
        body: JSON.stringify({
          project,
          version,
          manifest: appData.manifest,
          media: appData.media,
        }),
      });
      const json = await res.json();
      activeExportFolder = json.folder;
      btn.textContent = "1. Package Media Files (Done!)";
    } catch (err) {
      btn.textContent = "Export Failed";
      btn.style.backgroundColor = "var(--accent)";
    }
    btn.disabled = false;
  });

document
  .getElementById("btn-export-visuals")
  ?.addEventListener("click", async (e) => {
    const btn = e.target;
    btn.textContent = "Rendering Canvases...";
    btn.disabled = true;

    let targetFolder = activeExportFolder;
    if (!targetFolder) {
      const project = document
        .getElementById("project-input")
        .value.replace(/[^a-zA-Z0-9\.]/g, "-");
      const version = document
        .getElementById("version-input")
        .value.replace(/[^a-zA-Z0-9\.]/g, "-");
      targetFolder = `${project}_${version}`;
    }

    try {
      let exportImages = [];
      for (const slide of appData.slides) {
        await ensureImagesLoaded(slide.slide);
        const tempCanvas = document.createElement("canvas");
        tempCanvas.width = 2576;
        tempCanvas.height = 1080;
        drawSlideToContext(slide.slide, tempCanvas.getContext("2d"), false);
        exportImages.push({
          slide: slide.slide,
          data: tempCanvas.toDataURL("image/jpeg", 0.95),
        });
      }

      btn.textContent = "Sending JPGs to Python...";
      await fetch("/api/export-visuals", {
        method: "POST",
        body: JSON.stringify({ folder: targetFolder, images: exportImages }),
      });

      btn.textContent = "2. Export Visual Frames (Done!)";
    } catch (err) {
      btn.textContent = "Export Failed";
      btn.style.backgroundColor = "var(--accent)";
    }
    btn.disabled = false;
  });

document
  .getElementById("btn-export-specs")
  ?.addEventListener("click", async (e) => {
    const btn = e.target;
    btn.textContent = "Generating Details...";
    btn.disabled = true;

    const printContainer = document.getElementById("print-container");
    printContainer.innerHTML = "";
    document.body.className = "print-specs";

    for (const slide of appData.slides) {
      await ensureImagesLoaded(slide.slide);
      const tempCanvas = document.createElement("canvas");
      tempCanvas.width = 2576;
      tempCanvas.height = 1080;

      drawSlideToContext(slide.slide, tempCanvas.getContext("2d"), true);

      const img = new Image();
      img.src = tempCanvas.toDataURL("image/jpeg", 0.85);

      const settings = appData.manifest.slideSettings[slide.slide] || {
        scale: 100,
        flip: false,
        textWidth: 1600,
      };
      const notes = appData.manifest.slideNotes?.[slide.slide] || "No notes.";
      const slotData = appData.manifest.slideSlots[slide.slide] || {
        mains: [],
        backups: [],
      };

      let pathsHtml = slotData.mains
        .map((filename) => {
          const m = appData.media.find((x) => x.filename === filename);
          return m ? `<li>${m.path}</li>` : `<li>${filename}</li>`;
        })
        .join("");

      const pageDiv = document.createElement("div");
      pageDiv.className = "spec-page";
      pageDiv.innerHTML = `
            <div class="spec-data-block">
                <h1>Slide ${slide.slide} Specs</h1>
                <p><strong>Scale:</strong> ${settings.scale}% | <strong>Mirrored:</strong> ${settings.flip} | <strong>Text Width:</strong> ${settings.textWidth}px</p>
                <p style="margin-top:16px;"><strong>Main Media Assigned:</strong></p>
                <ul style="margin-left: 20px; font-family: monospace; font-size: 12px; margin-bottom: 16px;">${pathsHtml || "<li>No Mains Assigned</li>"}</ul>
                <p><strong>Backups Reserved:</strong> ${slotData.backups.length}</p>
                <p style="margin-top:24px;"><strong>Designer Notes:</strong></p>
                <p style="white-space: pre-wrap; font-style: italic;">${notes}</p>
            </div>
        `;
      pageDiv.insertBefore(img, pageDiv.firstChild);
      printContainer.appendChild(pageDiv);
    }

    btn.textContent = "Done! Opening Print Dialog...";
    setTimeout(() => {
      window.print();
      btn.textContent = "3. Print Spec Sheet";
      btn.disabled = false;
    }, 1500);
  });

init();
