// faxi-core — shared domain layer for Pasajero / Conductor / Admin.
// Replace each section with real services (REST/GraphQL, WebSocket, Maps SDK) keeping the same API.
(function () {
  if (window.FaxiCore) return;
  const KEY = 'faxi.config.v1';
  const clone = o => JSON.parse(JSON.stringify(o));

  // ───────── config (admin-editable, persisted) ─────────
  const DEFAULT = {
    fare: { base: 60, perKm: 22, perMin: 6, minimum: 150, surgePct: .15, commission: .2, cancelFee: 75, waitPerMin: 8, promo: { code: 'FAXI20', pct: .2, cap: 150 } },
    surge: false,
    cats: [
      { id: 'eco', name: 'Económico', mult: 1, enabled: true, icon: 'directions_car' },
      { id: 'comfort', name: 'Confort', mult: 1.3, enabled: true, icon: 'airline_seat_recline_extra' },
      { id: 'premium', name: 'Premium', mult: 1.9, enabled: true, icon: 'diamond' },
      { id: 'suv', name: 'SUV', mult: 1.65, enabled: true, icon: 'airport_shuttle' },
      { id: 'van', name: 'Van', mult: 2.2, enabled: true, icon: 'directions_bus' },
    ],
  };
  function load() {
    try { const s = JSON.parse(localStorage.getItem(KEY)); if (s && s.fare && s.cats) return Object.assign(clone(DEFAULT), s, { fare: Object.assign(clone(DEFAULT.fare), s.fare) }); } catch (e) {}
    return clone(DEFAULT);
  }
  let cfg = load();
  const save = () => { try { localStorage.setItem(KEY, JSON.stringify(cfg)); } catch (e) {} };

  // ───────── realtime bus ─────────
  const subs = new Set();
  let version = 0;
  const emit = () => { version++; subs.forEach(f => { try { f(); } catch (e) {} }); };
  try { window.addEventListener('storage', e => { if (e.key === KEY) { cfg = load(); emit(); } }); } catch (e) {}
  const fmt = n => 'RD$ ' + Math.round(n).toLocaleString('en-US');
  const now = () => { const d = new Date(); let h = d.getHours(); const ap = h >= 12 ? 'p. m.' : 'a. m.'; h = h % 12 || 12; return h + ':' + String(d.getMinutes()).padStart(2, '0') + ' ' + ap; };

  // ───────── seed data (mock — replace with API) ─────────
  const DRIVERS = [
    { id: 'D-1042', name: 'Rafael Peña', phone: '809 555 0198', car: 'Toyota Corolla 2021 · A482915', cat: 'eco', rating: 4.92, trips: 2184, status: 'En viaje', docs: 'ok', joined: 'Mar 2022' },
    { id: 'D-1043', name: 'Carolina Méndez', phone: '829 555 0311', car: 'Honda Accord 2022 · A611208', cat: 'comfort', rating: 4.97, trips: 3410, status: 'Disponible', docs: 'ok', joined: 'Ene 2021' },
    { id: 'D-1051', name: 'Luis Almonte', phone: '849 555 0127', car: 'Hyundai Elantra 2020 · A220871', cat: 'eco', rating: 4.81, trips: 1290, status: 'Disponible', docs: 'expiring', joined: 'Jun 2023' },
    { id: 'D-1063', name: 'José Taveras', phone: '809 555 0450', car: 'Toyota Highlander 2022 · G277541', cat: 'suv', rating: 4.88, trips: 980, status: 'Desconectado', docs: 'ok', joined: 'Sep 2023' },
    { id: 'D-1077', name: 'Héctor Guzmán', phone: '829 555 0782', car: 'Mercedes-Benz Clase E 2023 · A905374', cat: 'premium', rating: 4.99, trips: 640, status: 'En viaje', docs: 'ok', joined: 'Feb 2024' },
    { id: 'D-1090', name: 'Yokasta Ureña', phone: '809 555 0913', car: 'Kia K5 2023 · A118340', cat: 'comfort', rating: 4.93, trips: 455, status: 'Disponible', docs: 'ok', joined: 'May 2024' },
    { id: 'D-1101', name: 'Miguel Ángel Reyes', phone: '849 555 0066', car: 'Hyundai H-1 2021 · I038162', cat: 'van', rating: 4.76, trips: 312, status: 'Suspendido', docs: 'expired', joined: 'Ago 2024' },
    { id: 'P-2201', name: 'Pedro Marte', phone: '809 555 0741', car: 'Toyota Yaris 2022 · A773190', cat: 'eco', rating: 0, trips: 0, status: 'Pendiente', docs: 'review', joined: 'Hoy' },
    { id: 'P-2202', name: 'Ramona Castillo', phone: '829 555 0288', car: 'Honda CR-V 2021 · G509213', cat: 'suv', rating: 0, trips: 0, status: 'Pendiente', docs: 'review', joined: 'Ayer' },
    { id: 'P-2203', name: 'Wilson Abreu', phone: '849 555 0532', car: 'Nissan Sentra 2019 · A330457', cat: 'eco', rating: 0, trips: 0, status: 'Pendiente', docs: 'missing', joined: 'Hace 3 días' },
  ];
  const PASSENGERS = [
    { id: 'U-55012', name: 'María Fernández', phone: '809 555 0142', trips: 48, rating: 4.95, spent: 18420, status: 'Activa', since: '2024' },
    { id: 'U-55188', name: 'Ana Rodríguez', phone: '829 555 0619', trips: 112, rating: 4.87, spent: 41230, status: 'Activa', since: '2023' },
    { id: 'U-55203', name: 'Carlos Batista', phone: '809 555 0377', trips: 23, rating: 4.95, spent: 9810, status: 'Activa', since: '2025' },
    { id: 'U-55247', name: 'Lucía Santana', phone: '849 555 0904', trips: 7, rating: 5.0, spent: 4120, status: 'Activa', since: '2026' },
    { id: 'U-55310', name: 'Frank Polanco', phone: '809 555 0233', trips: 61, rating: 4.42, spent: 22790, status: 'Bloqueada', since: '2023' },
    { id: 'U-55402', name: 'Gabriela Ortiz', phone: '829 555 0158', trips: 34, rating: 4.9, spent: 12600, status: 'Activa', since: '2024' },
  ];
  let trips = [
    { id: 'FX-312840', rider: 'Gabriela Ortiz', driver: 'Héctor Guzmán', from: 'Piantini', to: 'Aeropuerto SDQ', cat: 'premium', total: 2140, method: 'Visa', status: 'En curso', time: '7:31 p. m.', source: 'Sistema' },
    { id: 'FX-312836', rider: 'Ana Rodríguez', driver: 'Rafael Peña', from: 'Naco', to: 'Zona Colonial', cat: 'eco', total: 412, method: 'Efectivo', status: 'En curso', time: '7:28 p. m.', source: 'Sistema' },
    { id: 'FX-312829', rider: 'Carlos Batista', driver: 'Carolina Méndez', from: 'Ágora Mall', to: 'Malecón', cat: 'comfort', total: 538, method: 'Mastercard', status: 'Completado', time: '7:12 p. m.', source: 'Sistema' },
    { id: 'FX-312811', rider: 'Frank Polanco', driver: '—', from: 'Bella Vista', to: 'Blue Mall', cat: 'eco', total: 0, method: 'Efectivo', status: 'Cancelado', time: '6:58 p. m.', source: 'Sistema' },
    { id: 'FX-312790', rider: 'Lucía Santana', driver: 'Yokasta Ureña', from: 'Galería 360', to: 'Blue Mall', cat: 'comfort', total: 291, method: 'Google Pay', status: 'Completado', time: '6:41 p. m.', source: 'Sistema' },
    { id: 'FX-312772', rider: 'María Fernández', driver: 'Luis Almonte', from: 'Piantini', to: 'Estadio Quisqueya', cat: 'eco', total: 187, method: 'Visa', status: 'Completado', time: '6:20 p. m.', source: 'Sistema' },
    { id: 'FX-312755', rider: 'Gabriela Ortiz', driver: 'José Taveras', from: 'Los Prados', to: 'Mirador Sur', cat: 'suv', total: 694, method: 'Transferencia', status: 'Completado', time: '5:57 p. m.', source: 'Sistema' },
  ];
  let claims = [
    { id: 'R-0912', trip: 'FX-312772', who: 'María Fernández', type: 'Cobro', text: 'Me cobraron recargo de hora pico fuera de horario.', status: 'Abierta', time: 'Hace 12 min', prio: 'Media' },
    { id: 'R-0911', trip: 'FX-312755', who: 'José Taveras', type: 'Pasajero', text: 'El pasajero dejó una mochila negra en el asiento trasero.', status: 'Abierta', time: 'Hace 40 min', prio: 'Alta' },
    { id: 'R-0907', trip: 'FX-312690', who: 'Ana Rodríguez', type: 'Ruta', text: 'El conductor tomó una ruta más larga por la Kennedy.', status: 'En revisión', time: 'Hace 2 h', prio: 'Baja' },
    { id: 'R-0899', trip: 'FX-312511', who: 'Carlos Batista', type: 'Seguridad', text: 'Conducción brusca en la 27 de Febrero.', status: 'Resuelta', time: 'Ayer', prio: 'Alta' },
  ];
  let events = [
    { icon: 'person_add', text: 'Nuevo conductor en revisión: Pedro Marte', time: '7:20 p. m.' },
    { icon: 'bolt', text: 'Demanda alta en Piantini y Naco', time: '7:05 p. m.' },
    { icon: 'report', text: 'Reclamación R-0912 abierta', time: '7:30 p. m.' },
  ];
  const live = { passenger: null, driver: null };

  const PHASE_TEXT = {
    searching: ['travel_explore', 'Pasajero solicita viaje'], assigned: ['check_circle', 'Conductor asignado'], enroute: ['directions_car', 'Conductor en camino'],
    arrived: ['hail', 'Conductor llegó al punto'], started: ['navigation', 'Viaje iniciado'], finished: ['sports_score', 'Viaje finalizado'],
    online: ['wifi_tethering', 'Conductor en línea'], request: ['notifications_active', 'Solicitud enviada a conductor'], toPickup: ['near_me', 'Conductor acepta y va al pasajero'],
    onTrip: ['navigation', 'Viaje iniciado (conductor)'], summary: ['payments', 'Ganancia registrada'],
  };

  // ───────── geo + map engine (simulated; swap for Google Maps / Mapbox) ─────────
  const XS = [50, 150, 250, 350, 450, 550, 650, 750, 850, 950], YS = [60, 150, 240, 330, 420, 510, 600, 690, 780, 870], SEA_Y = 886;
  const MAJOR_X = { 350: 'Av. Winston Churchill', 650: 'Av. Abraham Lincoln', 850: 'Av. Máximo Gómez' };
  const MAJOR_Y = { 240: 'Av. John F. Kennedy', 510: 'Av. 27 de Febrero', 870: 'Av. George Washington' };
  const STREET_X = { 50: 'Av. Núñez de Cáceres', 150: 'C/ Héroes de Luperón', 250: 'C/ Manuel de J. Troncoso', 350: 'Av. Winston Churchill', 450: 'Av. Lope de Vega', 550: 'Av. Tiradentes', 650: 'Av. Abraham Lincoln', 750: 'C/ Federico Henríquez', 850: 'Av. Máximo Gómez', 950: 'Av. Duarte' };
  const STREET_Y = { 60: 'Av. Los Próceres', 150: 'C/ Fantino Falco', 240: 'Av. John F. Kennedy', 330: 'C/ Rafael A. Sánchez', 420: 'C/ Roberto Pastoriza', 510: 'Av. 27 de Febrero', 600: 'Av. Gustavo Mejía Ricart', 690: 'Av. Sarasota', 780: 'Av. Independencia', 870: 'Av. George Washington' };
  const PARKS = [[50, 780, 350, 870], [750, 690, 850, 780], [550, 60, 750, 150]];
  const HOODS = [['PIANTINI', 505, 565], ['NACO', 560, 380], ['BELLA VISTA', 200, 735], ['CIUDAD COLONIAL', 900, 830], ['LA FE', 700, 200], ['LOS PRADOS', 150, 200], ['GAZCUE', 700, 735]];
  const M_PER_UNIT = 12;

  const pathLen = p => { let L = 0; for (let i = 1; i < p.length; i++) L += Math.hypot(p[i][0] - p[i - 1][0], p[i][1] - p[i - 1][1]); return L; };
  function pointAt(p, t) {
    const L = pathLen(p) * Math.min(1, Math.max(0, t)); let acc = 0;
    for (let i = 1; i < p.length; i++) {
      const a = p[i - 1], b = p[i], d = Math.hypot(b[0] - a[0], b[1] - a[1]);
      if (acc + d >= L || i === p.length - 1) { const k = d ? Math.min(1, (L - acc) / d) : 0; return { x: a[0] + (b[0] - a[0]) * k, y: a[1] + (b[1] - a[1]) * k, ang: Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI + 90, i, left: acc + d - L }; }
      acc += d;
    }
    return { x: p[0][0], y: p[0][1], ang: 0, i: 1, left: 0 };
  }
  const remaining = (p, t) => { const q = pointAt(p, t); return [[q.x, q.y], ...p.slice(q.i)]; };
  const dPath = p => 'M' + p.map(q => q[0].toFixed(1) + ' ' + q[1].toFixed(1)).join(' L');
  const ease = t => { t = Math.min(1, Math.max(0, t)); return t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; };
  const lpath = (a, b) => (a.x === b.x || a.y === b.y) ? [[a.x, a.y], [b.x, b.y]] : [[a.x, a.y], [b.x, a.y], [b.x, b.y]];
  const streetOf = (a, b) => a[0] === b[0] ? STREET_X[a[0]] : STREET_Y[a[1]];
  function nav(p, t) {
    const q = pointAt(p, t), i = q.i, dist = Math.max(0, Math.round(q.left * M_PER_UNIT / 10) * 10);
    if (i >= p.length - 1) return { icon: 'flag', dist, text: 'Llegas a tu destino', street: streetOf(p[i - 1], p[i]) };
    const a = p[i - 1], b = p[i], c = p[i + 1];
    const cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
    return { icon: cross > 0 ? 'turn_right' : 'turn_left', dist, text: 'Gira a la ' + (cross > 0 ? 'derecha' : 'izquierda'), street: streetOf(b, c) };
  }
  function camera(pts, o) {
    const W = o.W, H = o.H, top = o.top || 84, bottom = o.bottom || 300;
    const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
    const minX = Math.min(...xs), maxX = Math.max(...xs), minY = Math.min(...ys), maxY = Math.max(...ys);
    const bw = Math.max(maxX - minX, 120), bh = Math.max(maxY - minY, 120), visH = H - bottom - top;
    let s = Math.min((W - 80) / bw, (visH - 70) / bh); s = Math.min(o.maxS || 1.9, Math.max(o.minS || .3, s));
    return { s, tx: W / 2 - (minX + maxX) / 2 * s, ty: top + visH / 2 - (minY + maxY) / 2 * s };
  }
  let baseCache = null;
  function baseLayer(h) {
    if (baseCache) return baseCache;
    const k = [];
    k.push(h('rect', { key: 'bg', x: -800, y: -800, width: 2600, height: 2600, fill: '#E3E7E0' }));
    for (let x = 0; x <= 1000; x += 100) k.push(h('line', { key: 'ax' + x, x1: x, y1: -800, x2: x, y2: SEA_Y, stroke: '#EEF1EB', strokeWidth: 3 }));
    for (let y = 105; y <= 1000; y += 90) k.push(h('line', { key: 'ay' + y, x1: -800, y1: y, x2: 1800, y2: y, stroke: '#EEF1EB', strokeWidth: 3 }));
    XS.forEach(x => { if (!MAJOR_X[x]) k.push(h('line', { key: 'vx' + x, x1: x, y1: -800, x2: x, y2: SEA_Y, stroke: '#FFFFFF', strokeWidth: 7 })); });
    YS.forEach(y => { if (!MAJOR_Y[y]) k.push(h('line', { key: 'hy' + y, x1: -800, y1: y, x2: 1800, y2: y, stroke: '#FFFFFF', strokeWidth: 7 })); });
    PARKS.forEach((p, i) => k.push(h('rect', { key: 'pk' + i, x: p[0] + 7, y: p[1] + 7, width: p[2] - p[0] - 14, height: p[3] - p[1] - 14, rx: 6, fill: '#CFE3CB' })));
    Object.keys(MAJOR_X).forEach(x => k.push(h('line', { key: 'mxo' + x, x1: x, y1: -800, x2: x, y2: SEA_Y, stroke: '#D2D8CF', strokeWidth: 17 })));
    Object.keys(MAJOR_Y).forEach(y => k.push(h('line', { key: 'myo' + y, x1: -800, y1: y, x2: 1800, y2: y, stroke: '#D2D8CF', strokeWidth: 17 })));
    Object.keys(MAJOR_X).forEach(x => k.push(h('line', { key: 'mx' + x, x1: x, y1: -800, x2: x, y2: SEA_Y, stroke: '#FFFFFF', strokeWidth: 13 })));
    Object.keys(MAJOR_Y).forEach(y => k.push(h('line', { key: 'my' + y, x1: -800, y1: y, x2: 1800, y2: y, stroke: '#FFFFFF', strokeWidth: 13 })));
    k.push(h('rect', { key: 'sea', x: -800, y: SEA_Y, width: 2600, height: 1000, fill: '#C5DBE3' }));
    k.push(h('text', { key: 'seat', x: 520, y: 960, fill: '#8FAFBC', fontSize: 15, fontStyle: 'italic', letterSpacing: 3, textAnchor: 'middle' }, 'Mar Caribe'));
    const lab = { fill: '#8A938C', fontSize: 8.5, fontWeight: 600, stroke: '#FFFFFF', strokeWidth: 3, paintOrder: 'stroke', textAnchor: 'middle' };
    Object.entries(MAJOR_X).forEach(([x, n]) => k.push(h('text', Object.assign({ key: 'lx' + x, transform: `translate(${+x + 3} 300) rotate(-90)` }, lab), n)));
    Object.entries(MAJOR_Y).forEach(([y, n]) => k.push(h('text', Object.assign({ key: 'ly' + y, x: 200, y: +y + 3 }, lab), n)));
    HOODS.forEach(([n, x, y]) => k.push(h('text', { key: 'hd' + n, x, y, fill: '#A0A89F', fontSize: 9, fontWeight: 700, letterSpacing: 2.4, textAnchor: 'middle' }, n)));
    baseCache = h('g', { key: 'base' }, k);
    return baseCache;
  }
  function carShape(h, fill, key) {
    return h('g', { key }, [
      h('rect', { key: 's', x: -8, y: -12, width: 16, height: 26, rx: 5, fill: 'rgba(0,0,0,.18)', transform: 'translate(1.5 2)' }),
      h('rect', { key: 'b', x: -8, y: -13, width: 16, height: 26, rx: 5, fill }),
      h('rect', { key: 'w', x: -6, y: -6, width: 12, height: 6, rx: 2, fill: '#A9BDB5' }),
      h('rect', { key: 'r', x: -6, y: 6, width: 12, height: 3.5, rx: 1.5, fill: '#A9BDB5', opacity: .7 })]);
  }

  window.FaxiCore = {
    version: () => version,
    subscribe(fn) { subs.add(fn); return () => subs.delete(fn); },
    fmt, now,
    // config / pricing
    config: () => cfg,
    defaults: () => clone(DEFAULT),
    setFare(k, v) { cfg = Object.assign({}, cfg, { fare: Object.assign({}, cfg.fare, { [k]: v }) }); save(); emit(); },
    setPromo(k, v) { cfg = Object.assign({}, cfg, { fare: Object.assign({}, cfg.fare, { promo: Object.assign({}, cfg.fare.promo, { [k]: v }) }) }); save(); emit(); },
    setCat(id, k, v) { cfg = Object.assign({}, cfg, { cats: cfg.cats.map(c => c.id === id ? Object.assign({}, c, { [k]: v }) : c) }); save(); emit(); },
    setSurge(b) { cfg = Object.assign({}, cfg, { surge: !!b }); save(); this.event('bolt', b ? 'Recargo de hora pico activado' : 'Recargo de hora pico desactivado'); },
    reset() { cfg = clone(DEFAULT); save(); this.event('restart_alt', 'Tarifas restablecidas a valores por defecto'); },
    cat: id => cfg.cats.find(c => c.id === id) || cfg.cats[0],
    quote(catId, km, min, o) {
      o = o || {}; const F = cfg.fare, m = this.cat(catId).mult;
      const base = F.base * m, dist = km * F.perKm * m, time = min * F.perMin * m;
      let sub = base + dist + time; const minAdj = Math.max(0, F.minimum * m - sub); sub += minAdj;
      const sur = (o.surge ?? cfg.surge) ? sub * F.surgePct : 0;
      const disc = o.promo && F.promo.active !== false ? Math.min(F.promo.cap, (sub + sur) * F.promo.pct) : 0;
      const total = Math.round(sub + sur - disc);
      return { base: Math.round(base), dist: Math.round(dist), time: Math.round(time), minAdj: Math.round(minAdj), surge: Math.round(sur), disc: Math.round(disc), total, commission: Math.round(total * F.commission), driverNet: Math.round(total * (1 - F.commission)) };
    },
    // realtime state
    live,
    setLive(app, obj) {
      const prev = live[app]; live[app] = obj;
      if (obj && (!prev || prev.phase !== obj.phase) && PHASE_TEXT[obj.phase]) { const [icon, t] = PHASE_TEXT[obj.phase]; this.event(icon, t + (obj.label ? ' · ' + obj.label : '')); }
      else emit();
    },
    events: () => events,
    event(icon, text) { events = [{ icon, text, time: now() }, ...events].slice(0, 30); emit(); },
    trips: () => trips,
    logTrip(t) { trips = [Object.assign({ time: now() }, t), ...trips.filter(x => x.id !== t.id)]; this.event(t.status === 'Cancelado' ? 'cancel' : 'receipt_long', 'Viaje ' + t.id + ' · ' + t.status + (t.total ? ' · ' + fmt(t.total) : '')); },
    drivers: () => DRIVERS,
    setDriver(id, patch) { const d = DRIVERS.find(x => x.id === id); if (!d) return; Object.assign(d, patch); this.event(patch.status === 'Disponible' ? 'how_to_reg' : 'block', d.name + ' · ' + (patch.status === 'Disponible' ? 'aprobado' : patch.status.toLowerCase())); },
    passengers: () => PASSENGERS,
    setPassenger(id, patch) { const p = PASSENGERS.find(x => x.id === id); if (p) { Object.assign(p, patch); this.event('person', p.name + ' · ' + patch.status.toLowerCase()); } },
    claims: () => claims,
    setClaim(id, patch) { claims = claims.map(c => c.id === id ? Object.assign({}, c, patch) : c); this.event('task_alt', 'Reclamación ' + id + ' · ' + patch.status.toLowerCase()); },
    geo: { XS, YS, SEA_Y, MAJOR_X, MAJOR_Y, STREET_X, STREET_Y, M_PER_UNIT, pathLen, pointAt, remaining, dPath, ease, lpath, nav, camera, baseLayer, carShape },
  };
})();
