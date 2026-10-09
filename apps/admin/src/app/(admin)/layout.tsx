'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { auth, isConfigured } from '@faxi/core';
import { sb } from '@/lib/faxi';

const NAV = [
  { href: '/', label: 'Panel' },
  { href: '/drivers', label: 'Conductores' },
  { href: '/trips', label: 'Viajes' },
  { href: '/pricing', label: 'Tarifas y ajustes' },
  { href: '/tickets', label: 'Soporte' },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const path = usePathname();
  const [ok, setOk] = useState<boolean | null>(null);
  const [email, setEmail] = useState('');

  useEffect(() => {
    if (!isConfigured()) { router.replace('/login'); return; }
    (async () => {
      const { data } = await sb().auth.getSession();
      if (!data.session) { router.replace('/login'); return; }
      setEmail(data.session.user.email ?? '');
      const { data: admin } = await sb().rpc('is_admin');
      if (!admin) { await auth.signOut(); router.replace('/login'); return; }
      setOk(true);
    })();
    const { data: sub } = sb().auth.onAuthStateChange((_e, s) => { if (!s) router.replace('/login'); });
    return () => sub.subscription.unsubscribe();
  }, []);

  if (!ok) return <div className="login muted">Cargando…</div>;
  return (
    <div className="shell">
      <aside className="side">
        <div className="brand">faxi<i /><small>Admin</small></div>
        {NAV.map((n) => (
          <Link key={n.href} href={n.href} className={'nav' + ((n.href === '/' ? path === '/' : path.startsWith(n.href)) ? ' on' : '')}>{n.label}</Link>
        ))}
        <div className="spacer" />
        <div className="muted small" style={{ padding: '0 12px' }}>{email}</div>
        <button className="btn" onClick={() => auth.signOut()}>Cerrar sesión</button>
      </aside>
      <main className="main">{children}</main>
    </div>
  );
}
