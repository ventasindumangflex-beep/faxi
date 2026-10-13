import React from 'react';

// Renderizador mínimo para los textos legales (títulos, párrafos, listas, tablas, citas, **negrita** y [enlaces](url)).
function inline(text: string, key: string): React.ReactNode[] {
  const out: React.ReactNode[] = [];
  const re = /\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)/g;
  let last = 0; let m: RegExpExecArray | null; let i = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(text.slice(last, m.index));
    if (m[1]) out.push(<strong key={`${key}-${i++}`}>{m[1]}</strong>);
    else out.push(<a key={`${key}-${i++}`} href={m[3]}>{m[2]}</a>);
    last = m.index + m[0].length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

export function Markdown({ source }: { source: string }) {
  const lines = source.replace(/\r/g, '').split('\n');
  const blocks: React.ReactNode[] = [];
  let i = 0; let k = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    const h = /^(#{1,3})\s+(.*)$/.exec(line);
    if (h) {
      const Tag = (`h${h[1].length}`) as 'h1' | 'h2' | 'h3';
      blocks.push(<Tag key={k++}>{inline(h[2], `h${k}`)}</Tag>); i++; continue;
    }
    if (line.startsWith('>')) {
      const buf: string[] = [];
      while (i < lines.length && lines[i].startsWith('>')) buf.push(lines[i++].replace(/^>\s?/, ''));
      blocks.push(<blockquote key={k++}>{inline(buf.join(' '), `q${k}`)}</blockquote>); continue;
    }
    if (/^\s*[-*]\s+/.test(line) || /^\s*\d+\.\s+/.test(line)) {
      const ordered = /^\s*\d+\./.test(line);
      const items: string[] = [];
      while (i < lines.length && (/^\s*[-*]\s+/.test(lines[i]) || /^\s*\d+\.\s+/.test(lines[i]))) {
        items.push(lines[i++].replace(/^\s*([-*]|\d+\.)\s+/, ''));
      }
      const List = ordered ? 'ol' : 'ul';
      blocks.push(<List key={k++}>{items.map((t, j) => <li key={j}>{inline(t, `l${k}-${j}`)}</li>)}</List>); continue;
    }
    if (line.startsWith('|')) {
      const rows: string[][] = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        const cells = lines[i++].split('|').slice(1, -1).map((c) => c.trim());
        if (!cells.every((c) => /^-+$/.test(c))) rows.push(cells);
      }
      const [head, ...body] = rows;
      blocks.push(
        <div className="legal-table" key={k++}><table>
          <thead><tr>{head.map((c, j) => <th key={j}>{inline(c, `th${j}`)}</th>)}</tr></thead>
          <tbody>{body.map((r, ri) => <tr key={ri}>{r.map((c, j) => <td key={j}>{inline(c, `td${ri}-${j}`)}</td>)}</tr>)}</tbody>
        </table></div>,
      ); continue;
    }
    const buf: string[] = [];
    while (i < lines.length && lines[i].trim() && !/^(#|>|\||\s*[-*]\s|\s*\d+\.\s)/.test(lines[i])) buf.push(lines[i++]);
    blocks.push(<p key={k++}>{inline(buf.join(' '), `p${k}`)}</p>);
  }
  return <>{blocks}</>;
}

export function LegalPage({ source }: { source: string }) {
  return (
    <main className="legal">
      <a className="brand" href="/privacidad">faxi<i /></a>
      <article><Markdown source={source} /></article>
      <footer className="muted small">
        <a href="/privacidad">Privacidad</a> · <a href="/terminos">Términos para pasajeros</a> · <a href="/terminos-conductores">Términos para conductores</a> · <a href="/eliminar-cuenta">Eliminar cuenta</a>
      </footer>
    </main>
  );
}
