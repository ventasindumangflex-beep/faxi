'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { auth, isConfigured, missingConfig } from '@faxi/core';
import { sb } from '@/lib/faxi';

export default function Login() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setErr(null);
    try {
      await auth.signInWithPassword(email.trim(), password);
      const { data } = await sb().rpc('is_admin');
      if (!data) { await auth.signOut(); throw new Error('Esta cuenta no tiene acceso al panel.'); }
      router.replace('/');
    } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }

  if (!isConfigured()) {
    return <div className="login"><div className="banner">Falta configurar apps/admin/.env.local: {missingConfig().join(', ')}</div></div>;
  }
  return (
    <div className="login">
      <form onSubmit={submit}>
        <div className="brand">faxi<i /><small>Admin</small></div>
        <h1>Entrar al panel</h1>
        <input className="input" type="email" placeholder="Correo" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="username" required />
        <input className="input" type="password" placeholder="Contraseña" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" required />
        {err ? <div className="banner">{err}</div> : null}
        <button className="btn primary" disabled={busy}>{busy ? 'Entrando…' : 'Entrar'}</button>
        <p className="muted small">Las cuentas de administrador las crea un SUPER_ADMIN desde Supabase.</p>
      </form>
    </div>
  );
}
