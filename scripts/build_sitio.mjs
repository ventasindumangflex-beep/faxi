// Genera el sitio público de faxi en sitio/ (inicio, soporte y páginas legales) a partir de apps/admin/src/legal/*.md.
// Uso: node scripts/build_sitio.mjs   · Sin dependencias. La carpeta sitio/ se publica tal cual (Netlify lee netlify.toml).
// No edites sitio/ a mano: cambia los .md (o este archivo) y vuelve a correr el script.
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'sitio');
const legal = (name) => readFileSync(join(root, 'apps/admin/src/legal', name + '.md'), 'utf8');

const SITIO = 'https://faxi.netlify.app';   // cambiar por el dominio propio cuando exista (y en apps/*/src/faxi.ts)
const SOPORTE = '';    // p. ej. 'soporte@midominio.com' cuando exista el correo; vacío = no se muestra
const WHATSAPP = '';   // p. ej. '18095550000' cuando exista el número de soporte; vacío = no se muestra

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// Mismo subconjunto de Markdown que apps/admin/src/legal/Markdown.tsx (títulos, párrafos, listas, tablas, citas, **negrita**, [enlaces](url)).
function inline(text) {
  return esc(text).replace(/\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)/g, (_, b, label, href) => (b ? `<strong>${b}</strong>` : `<a href="${href}">${label}</a>`));
}

function markdown(source) {
  const lines = source.replace(/\r/g, '').split('\n');
  const html = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    const h = /^(#{1,3})\s+(.*)$/.exec(line);
    if (h) { html.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`); i++; continue; }
    if (line.startsWith('>')) {
      const buf = [];
      while (i < lines.length && lines[i].startsWith('>')) buf.push(lines[i++].replace(/^>\s?/, ''));
      html.push(`<blockquote>${inline(buf.join(' '))}</blockquote>`); continue;
    }
    if (/^\s*[-*]\s+/.test(line) || /^\s*\d+\.\s+/.test(line)) {
      const tag = /^\s*\d+\./.test(line) ? 'ol' : 'ul';
      const items = [];
      while (i < lines.length && (/^\s*[-*]\s+/.test(lines[i]) || /^\s*\d+\.\s+/.test(lines[i]))) {
        items.push(`<li>${inline(lines[i++].replace(/^\s*([-*]|\d+\.)\s+/, ''))}</li>`);
      }
      html.push(`<${tag}>${items.join('')}</${tag}>`); continue;
    }
    if (line.startsWith('|')) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        const cells = lines[i++].split('|').slice(1, -1).map((c) => c.trim());
        if (!cells.every((c) => /^-+$/.test(c))) rows.push(cells);
      }
      const [head, ...body] = rows;
      html.push(`<div class="tabla"><table><thead><tr>${head.map((c) => `<th>${inline(c)}</th>`).join('')}</tr></thead><tbody>`
        + body.map((r) => `<tr>${r.map((c) => `<td>${inline(c)}</td>`).join('')}</tr>`).join('') + '</tbody></table></div>');
      continue;
    }
    const buf = [];
    while (i < lines.length && lines[i].trim() && !/^(#|>|\||\s*[-*]\s|\s*\d+\.\s)/.test(lines[i])) buf.push(lines[i++]);
    html.push(`<p>${inline(buf.join(' '))}</p>`);
  }
  return html.join('\n');
}

const firstHeading = (md) => /^#\s+(.*)$/m.exec(md)?.[1] ?? 'faxi';

function page({ path, title, description, body }) {
  return `<!doctype html>
<html lang="es-DO">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${SITIO}${path}">
<link rel="icon" href="/icon.png" type="image/png">
<link rel="apple-touch-icon" href="/apple-icon.png">
<meta name="theme-color" content="#1B7A57">
<link rel="stylesheet" href="/estilos.css">
</head>
<body>
<header class="barra"><a class="marca" href="/" aria-label="faxi, inicio">faxi<i></i></a><a class="enlace-barra" href="/soporte/">Ayuda</a></header>
<main>
${body}
</main>
<footer class="pie">
<nav><a href="/privacidad/">Privacidad</a><a href="/terminos/">Términos para pasajeros</a><a href="/terminos-conductores/">Términos para conductores</a><a href="/eliminar-cuenta/">Eliminar cuenta</a><a href="/soporte/">Soporte</a></nav>
<p>faxi · Santo Domingo, República Dominicana${SOPORTE ? ` · <a href="mailto:${SOPORTE}">${SOPORTE}</a>` : ''}</p>
</footer>
</body>
</html>
`;
}

const contacto = `<ul class="contacto">
${SOPORTE ? `<li><strong>Correo:</strong> <a href="mailto:${SOPORTE}">${SOPORTE}</a></li>\n` : ''}${WHATSAPP ? `<li><strong>WhatsApp:</strong> <a href="https://wa.me/${WHATSAPP}">+${WHATSAPP}</a></li>\n` : ''}<li>Desde la app: <strong>Cuenta → Reportar un problema</strong>.</li>
</ul>`;

const pages = [
  {
    path: '/', title: 'faxi · Viajes en el Gran Santo Domingo',
    description: 'Pide un viaje en el Gran Santo Domingo, ve la tarifa antes de pedir y paga en efectivo.',
    body: `<section class="portada">
<h1>Viajes seguros en el Gran Santo Domingo</h1>
<p class="entrada">Ve la tarifa antes de pedir, sigue a tu conductor en el mapa y paga en efectivo al llegar.</p>
<p class="pronto">Muy pronto en Android</p>
</section>
<section class="columnas">
<div class="tarjeta"><h2>Para pasajeros</h2><ul>
<li>Entras con tu número de teléfono, sin contraseñas.</li>
<li>Precio claro antes de confirmar el viaje.</li>
<li>Comparte tu viaje y llama al 911 desde la app.</li>
</ul></div>
<div class="tarjeta"><h2>Para conductores</h2><ul>
<li>Tú decides cuándo conectarte.</li>
<li>Ves el origen, el destino y la tarifa antes de aceptar.</li>
<li>Consulta tus ganancias viaje por viaje.</li>
</ul></div>
</section>
<section class="tarjeta"><h2>¿Tienes preguntas?</h2>${contacto}</section>`,
  },
  {
    path: '/soporte/', title: 'faxi · Soporte',
    description: 'Cómo contactar al equipo de faxi y resolver problemas con un viaje o tu cuenta.',
    body: `<article class="texto">
<h1>Soporte</h1>
<p>Estamos para ayudarte con tus viajes, cobros, objetos perdidos o tu cuenta.</p>
<h2>Desde la app</h2>
<ol><li>Abre faxi o faxi Conductor.</li><li>Ve a <strong>Cuenta</strong>.</li><li>Toca <strong>Reportar un problema</strong>. Si es sobre un viaje, lo vinculamos automáticamente.</li></ol>
${SOPORTE || WHATSAPP ? `<h2>Escríbenos</h2>\n${contacto}\n` : ''}<p>Si tienes una emergencia durante un viaje, llama al <strong>911</strong> (en la app, botón <strong>Emergencia 911</strong>).</p>
<h2>Tu cuenta</h2>
<p>Para borrar tu cuenta y tus datos, sigue los pasos de <a href="/eliminar-cuenta/">Eliminar cuenta</a>.</p>
</article>`,
  },
  ...['privacidad', 'terminos', 'terminos-conductores', 'eliminar-cuenta'].map((name) => {
    const md = legal(name);
    return { path: `/${name}/`, title: `faxi · ${firstHeading(md).replace(/ de faxi$/, '')}`, description: firstHeading(md), body: `<article class="texto">\n${markdown(md)}\n</article>` };
  }),
];

const css = `@font-face { font-family: 'Plus Jakarta Sans'; font-weight: 500; font-display: swap; src: url(/fuentes/PlusJakartaSans_500Medium.ttf) format('truetype'); }
@font-face { font-family: 'Plus Jakarta Sans'; font-weight: 800; font-display: swap; src: url(/fuentes/PlusJakartaSans_800ExtraBold.ttf) format('truetype'); }
:root {
  --primary: #1B7A57; --primary-dark: #0F5A3F; --primary-soft: #D6EDE1; --on-primary: #FFFFFF;
  --ink: #181C1A; --ink2: #414943; --outline-soft: #DDE3DD;
  --surface: #F8FAF6; --surface2: #E6EBE4; --white: #FFFFFF; --warn: #7A5900; --warn-soft: #FFF1CC;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --primary: #7FD3AE; --primary-dark: #A6E4C8; --primary-soft: #1E3A2E; --on-primary: #0B1F16;
    --ink: #E6EBE4; --ink2: #B9C2BA; --outline-soft: #2C332E;
    --surface: #111412; --surface2: #1B201C; --white: #181C1A; --warn: #FFD873; --warn-soft: #3A2F0E;
  }
}
:root[data-theme="dark"] {
  --primary: #7FD3AE; --primary-dark: #A6E4C8; --primary-soft: #1E3A2E; --on-primary: #0B1F16;
  --ink: #E6EBE4; --ink2: #B9C2BA; --outline-soft: #2C332E;
  --surface: #111412; --surface2: #1B201C; --white: #181C1A; --warn: #FFD873; --warn-soft: #3A2F0E;
}
* { box-sizing: border-box; }
html, body { margin: 0; }
body { background: var(--surface); color: var(--ink); font: 500 16px/1.6 'Plus Jakarta Sans', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif; -webkit-font-smoothing: antialiased; overflow-wrap: anywhere; }
a { color: var(--primary); }
a:hover { color: var(--primary-dark); }
.barra { max-width: 820px; margin: 0 auto; padding: 20px 16px; display: flex; align-items: center; justify-content: space-between; }
.marca { display: inline-flex; align-items: baseline; gap: 3px; font-weight: 800; font-size: 28px; letter-spacing: -0.05em; color: var(--ink); text-decoration: none; min-height: 44px; }
.marca i { width: 8px; height: 8px; border-radius: 9px; background: var(--primary); display: inline-block; }
.enlace-barra { font-weight: 800; text-decoration: none; padding: 10px 4px; }
main { max-width: 820px; margin: 0 auto; padding: 8px 16px 48px; display: flex; flex-direction: column; gap: 24px; }
h1 { font-weight: 800; font-size: clamp(28px, 6vw, 44px); line-height: 1.15; letter-spacing: -0.02em; margin: 0 0 12px; }
h2 { font-weight: 800; font-size: 20px; line-height: 1.3; margin: 28px 0 8px; }
h3 { font-weight: 800; font-size: 17px; margin: 20px 0 6px; }
strong { font-weight: 800; }
.portada { padding: 24px 0 8px; }
.entrada { font-size: 19px; color: var(--ink2); max-width: 36em; margin: 0 0 20px; }
.pronto { display: inline-block; margin: 0; padding: 10px 18px; border-radius: 999px; background: var(--primary); color: var(--on-primary); font-weight: 800; }
.columnas { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
.tarjeta { background: var(--white); border: 1px solid var(--outline-soft); border-radius: 20px; padding: 4px 20px 16px; }
.tarjeta ul { padding-left: 20px; margin: 0; }
.contacto, .tarjeta .contacto { list-style: none; padding: 0; margin: 8px 0; }
.contacto a { display: inline-block; padding: 10px 0; }
.texto blockquote { margin: 16px 0; padding: 12px 16px; background: var(--warn-soft); color: var(--warn); border-radius: 12px; }
.tabla { overflow-x: auto; margin: 12px 0; }
table { border-collapse: collapse; width: 100%; font-size: 14px; }
th, td { text-align: left; vertical-align: top; padding: 8px 10px; border-bottom: 1px solid var(--outline-soft); }
th { background: var(--surface2); }
.pie { max-width: 820px; margin: 0 auto; padding: 24px 16px 40px; border-top: 1px solid var(--outline-soft); color: var(--ink2); font-size: 14px; }
.pie nav { display: flex; flex-wrap: wrap; gap: 4px 18px; }
.pie nav a { padding: 10px 0; }
`;

const headers = `/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
`;

rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, 'fuentes'), { recursive: true });
for (const p of pages) {
  const dir = join(out, p.path);
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'index.html'), page(p));
}
writeFileSync(join(out, '404.html'), page({
  path: '/404.html', title: 'faxi · Página no encontrada', description: 'Página no encontrada',
  body: '<article class="texto"><h1>No encontramos esta página</h1><p><a href="/">Volver al inicio</a></p></article>',
}));
writeFileSync(join(out, 'estilos.css'), css);
writeFileSync(join(out, '_headers'), headers);
copyFileSync(join(root, 'apps/admin/src/app/icon.png'), join(out, 'icon.png'));
copyFileSync(join(root, 'apps/admin/src/app/apple-icon.png'), join(out, 'apple-icon.png'));
for (const f of ['PlusJakartaSans_500Medium.ttf', 'PlusJakartaSans_800ExtraBold.ttf']) {
  copyFileSync(join(root, 'apps/admin/src/app/fonts', f), join(out, 'fuentes', f));
}
console.log(`sitio/ listo: ${pages.length} páginas + 404`);
