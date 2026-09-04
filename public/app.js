const state = {
  roomId: null,
  latestResponse: null,
  activity: [],
};

const $ = (selector) => document.querySelector(selector);
const els = {
  notice: $("#notice"), roomId: $("#room-id"), roomStatus: $("#room-status"),
  playbackState: $("#playback-state"), startAt: $("#start-at"), createdAt: $("#created-at"),
  statusPill: $("#status-pill"), participants: $("#participants-list"), count: $("#participant-count"),
  response: $("#backend-response code"), activity: $("#activity-list"), copy: $("#copy-room"),
  add: $("#add-receiver"), play: $("#play-room"), pause: $("#pause-room"), flowLabel: $("#flow-label"),
};

function formatDate(value) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("es-CO", { dateStyle: "short", timeStyle: "medium" }).format(new Date(value));
}
function formatStart(value) { return value ? `${value} (${formatDate(value)})` : "—"; }
function setNotice(message, success = false) {
  els.notice.hidden = !message;
  els.notice.textContent = message || "";
  els.notice.className = `notice${success ? " success" : ""}`;
}
function setResponse(data) {
  state.latestResponse = data;
  els.response.textContent = JSON.stringify(data, null, 2);
}
function addActivity(message, success = true) {
  state.activity.unshift({ message, success, time: new Date() });
  state.activity = state.activity.slice(0, 5);
  els.activity.innerHTML = state.activity.map((item) => `<div class="activity-item"><span><strong>${item.success ? "✓" : "✕"}</strong> ${item.message}</span><time>${item.time.toLocaleTimeString("es-CO")}</time></div>`).join("");
}
function setFlow(nodes, label) {
  document.querySelectorAll(".flow-node").forEach((node) => node.classList.toggle("active", nodes.includes(node.dataset.node)));
  els.flowLabel.textContent = label;
}
function setEvidence(id, done, detail) {
  const item = $(`#${id}`);
  item.className = done ? "done" : "pending";
  item.querySelector("span").textContent = done ? "✓" : "○";
  item.querySelector("small").textContent = detail;
}
function renderRoom(room) {
  state.roomId = room.roomId;
  els.roomId.textContent = room.roomId;
  els.roomStatus.textContent = (room.status || "stopped").toUpperCase();
  els.playbackState.textContent = room.playbackState ? JSON.stringify(room.playbackState) : "—";
  els.startAt.textContent = formatStart(room.startAt);
  els.createdAt.textContent = formatDate(room.createdAt);
  els.count.textContent = room.participants?.length || 0;
  const status = room.status || "stopped";
  els.statusPill.textContent = status.toUpperCase();
  els.statusPill.className = `status-pill status-${status}`;
  els.participants.innerHTML = room.participants?.length ? room.participants.map((participant, index) => `<div class="participant"><div class="participant-avatar">${participant.role === "emitter" ? "E" : "R"}${index || ""}</div><div><strong>${participant.role === "emitter" ? "Este dispositivo" : participant.id}</strong><small>${participant.id}</small></div><span class="role-tag">${participant.role.toUpperCase()}</span></div>`).join("") : `<div class="empty-state"><span class="empty-icon">○</span><p>Esperando receptores...</p></div>`;
  els.add.disabled = false; els.play.disabled = false; els.pause.disabled = status !== "playing";
  els.copy.disabled = false;
  setEvidence("evidence-room", true, "Confirmada por GET /rooms/:id");
  setEvidence("evidence-participants", (room.participants?.length || 0) > 1, (room.participants?.length || 0) > 1 ? "Confirmados desde SQLite" : "Esperando receptores");
  setEvidence("evidence-state", status === "playing" || status === "paused", status === "playing" || status === "paused" ? "Confirmado por GET /rooms/:id" : "Esperando PLAY");
  setEvidence("evidence-start", Boolean(room.startAt), room.startAt ? "Confirmado por GET /rooms/:id" : "Esperando referencia temporal");
}
async function api(path, options = {}) {
  const response = await fetch(path, { headers: { "Content-Type": "application/json" }, ...options });
  let data;
  try { data = await response.json(); } catch { data = { error: "El servidor devolvió una respuesta no válida" }; }
  if (!response.ok) { const error = new Error(data.error || `Error HTTP ${response.status}`); error.data = data; throw error; }
  return data;
}
async function refreshRoom(message = "Sala consultada desde el backend") {
  const room = await api(`/rooms/${state.roomId}`);
  renderRoom(room); setResponse(room); addActivity(message); return room;
}
async function runOperation({ action, nodes, success, request }) {
  setFlow(nodes, action.toUpperCase()); setNotice(`Ejecutando ${action}...`);
  try { const data = await request(); if (data.roomId) state.roomId = data.roomId; setResponse(data); await refreshRoom(success); setNotice(success, true); setFlow(nodes, "CONFIRMADO"); }
  catch (error) { setNotice(`Error: ${error.message}. ${error.message.includes("fetch") ? "El servidor no respondió." : "Revisa la sala y vuelve a intentarlo."}`); addActivity(`Error en ${action}`, false); setFlow([], "ERROR"); if (error.data) setResponse(error.data); }
}

$("#create-room").addEventListener("click", () => runOperation({ action: "crear sala", nodes: ["emitter", "http", "session", "usecase", "repository", "sqlite"], success: "Sala creada y persistida correctamente", request: async () => { const emitterId = $("#emitter-id").value.trim(); return api("/rooms", { method: "POST", body: JSON.stringify(emitterId ? { emitterId } : {}) }); } }).then(() => state.roomId && refreshRoom("Sala consultada después de crearla")).catch(() => {}));
$("#add-receiver").addEventListener("click", () => { if (!state.roomId) return; const input = $("#receiver-id"); const receiverId = input.value.trim() || `receiver-${crypto.randomUUID().slice(0, 8)}`; input.value = ""; runOperation({ action: "agregar receptor", nodes: ["http", "session", "usecase", "repository", "sqlite"], success: "Receptor agregado y persistido correctamente", request: () => api(`/rooms/${state.roomId}/receivers`, { method: "POST", body: JSON.stringify({ receiverId }) }) }); });
$("#play-room").addEventListener("click", () => { if (!state.roomId) return; runOperation({ action: "iniciar reproducción", nodes: ["session", "usecase", "sync", "repository", "sqlite", "audio", "receivers"], success: "Reproducción iniciada; estado y startAt persistidos", request: () => api(`/rooms/${state.roomId}/play`, { method: "POST", body: JSON.stringify({ payload: "audio-demo" }) }) }); });
$("#pause-room").addEventListener("click", () => { if (!state.roomId) return; runOperation({ action: "detener reproducción", nodes: ["session", "usecase", "repository", "sqlite", "receivers"], success: "Reproducción detenida y estado persistido", request: () => api(`/rooms/${state.roomId}/pause`, { method: "POST" }) }); });
$("#copy-room").addEventListener("click", async () => { if (!state.roomId) return; await navigator.clipboard.writeText(state.roomId); setNotice("Room ID copiado", true); });
setFlow([], "LISTO");
