const statusEl = document.getElementById('status');
const tableWrap = document.getElementById('tableWrap');
const btnRefresh = document.getElementById('btnRefresh');
const btnToggleLive = document.getElementById('btnToggleLive');
const liveLabel = document.getElementById('liveLabel');

let pollTimer = null;

function setStatus(text, isError) {
  statusEl.textContent = text;
  statusEl.classList.toggle('err', Boolean(isError));
}

function formatDate(iso) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    return d.toLocaleString('es-GT', { hour12: false });
  } catch {
    return String(iso);
  }
}

function pill(success) {
  if (success === true) return '<span class="pill ok">ok</span>';
  if (success === false) return '<span class="pill bad">fallo</span>';
  return '—';
}

function render(events) {
  if (!events.length) {
    tableWrap.innerHTML = '<div class="empty">No hay eventos registrados todavía.</div>';
    return;
  }

  const rows = events
    .map(
      (e) => `
    <tr>
      <td class="mono">${formatDate(e.createdAt)}</td>
      <td>${escapeHtml(e.type || '')}</td>
      <td>${escapeHtml(e.source || '')}</td>
      <td class="mono">${escapeHtml(e.action || '')}</td>
      <td>${pill(e.success)}</td>
      <td class="mono">${escapeHtml(e.detail || '')}</td>
    </tr>
  `,
    )
    .join('');

  tableWrap.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>Fecha</th>
          <th>Tipo</th>
          <th>Origen</th>
          <th>Acción</th>
          <th>Éxito</th>
          <th>Detalle</th>
        </tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

async function loadEvents() {
  btnRefresh.disabled = true;
  setStatus('Cargando eventos…', false);
  try {
    const res = await fetch('/api/events?limit=200');
    const data = await res.json();
    if (!res.ok || !data.ok) {
      throw new Error(data.error || res.statusText);
    }
    render(data.events || []);
    setStatus(`Última actualización: ${new Date().toLocaleTimeString('es-GT')}`, false);
  } catch (err) {
    setStatus(`Error: ${err.message}`, true);
    tableWrap.innerHTML = '';
  } finally {
    btnRefresh.disabled = false;
  }
}

function stopLive() {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = null;
  btnToggleLive.textContent = 'Tiempo real: off';
  liveLabel.textContent = 'Actualización manual';
  liveLabel.classList.remove('on');
}

function startLive() {
  stopLive();
  pollTimer = setInterval(loadEvents, 3000);
  btnToggleLive.textContent = 'Tiempo real: on';
  liveLabel.textContent = 'Actualizando cada 3 s';
  liveLabel.classList.add('on');
}

btnRefresh.addEventListener('click', loadEvents);
btnToggleLive.addEventListener('click', () => {
  if (pollTimer) stopLive();
  else startLive();
});

loadEvents();
