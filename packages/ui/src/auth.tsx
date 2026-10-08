import React, { useEffect, useState } from 'react';
import { Linking, View } from 'react-native';
import { auth, normalizePhoneDO } from '@faxi/core';
import { Banner, Brand, Button, Field, Header, Row, Screen, T } from './components';
import { c, f, r } from './tokens';

export function PhoneLogin({ role, title, subtitle, brandSuffix, termsUrl, privacyUrl, onSent }: {
  role: 'PASSENGER' | 'DRIVER'; title: string; subtitle: string; brandSuffix?: string;
  termsUrl: string; privacyUrl: string; onSent: (phone: string) => void;
}) {
  const [raw, setRaw] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function send() {
    const phone = normalizePhoneDO(raw);
    if (!phone) { setErr('Escribe un número válido, por ejemplo 809 555 1234.'); return; }
    setBusy(true); setErr(null);
    try { await auth.sendOtp(phone, role); onSent(phone); }
    catch (e: any) { setErr(e.message); }
    finally { setBusy(false); }
  }

  return (
    <Screen scroll>
      <View style={{ flex: 1, justifyContent: 'center', gap: 22 }}>
        <Brand suffix={brandSuffix} />
        <View style={{ gap: 6 }}>
          <T v="display">{title}</T>
          <T v="caption">{subtitle}</T>
        </View>
        <Row gap={10}>
          <View style={{ height: 56, paddingHorizontal: 16, borderRadius: r.md, backgroundColor: c.surface2, justifyContent: 'center' }}>
            <T v="label">RD +1</T>
          </View>
          <View style={{ flex: 1 }}>
            <Field value={raw} onChangeText={setRaw} keyboardType="phone-pad" placeholder="809 555 1234" autoFocus
              textContentType="telephoneNumber" autoComplete="tel" maxLength={16} onSubmitEditing={send} accessibilityLabel="Número de teléfono" />
          </View>
        </Row>
        {err ? <Banner text={err} /> : null}
        <Button title="Recibir código por SMS" onPress={send} loading={busy} />
        <T v="caption">Al continuar aceptas los términos y la política de privacidad de faxi. Pueden aplicar cargos de SMS de tu operador.</T>
        <LegalLinks termsUrl={termsUrl} privacyUrl={privacyUrl} />
      </View>
    </Screen>
  );
}

export function LegalLinks({ termsUrl, privacyUrl }: { termsUrl: string; privacyUrl: string }) {
  return (
    <Row gap={18} style={{ flexWrap: 'wrap' }}>
      <T v="caption" color={c.primaryDark} style={{ fontFamily: f.bold, textDecorationLine: 'underline' }}
        onPress={() => Linking.openURL(termsUrl)}>Términos y condiciones</T>
      <T v="caption" color={c.primaryDark} style={{ fontFamily: f.bold, textDecorationLine: 'underline' }}
        onPress={() => Linking.openURL(privacyUrl)}>Política de privacidad</T>
    </Row>
  );
}

export function OtpVerify({ phone, role, onBack }: { phone: string; role: 'PASSENGER' | 'DRIVER'; onBack: () => void }) {
  const [code, setCode] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [wait, setWait] = useState(30);

  useEffect(() => {
    if (wait <= 0) return;
    const h = setTimeout(() => setWait((w) => w - 1), 1000);
    return () => clearTimeout(h);
  }, [wait]);

  async function verify(value = code) {
    if (value.length !== 6) return;
    setBusy(true); setErr(null);
    try { await auth.verifyOtp(phone, value); } // la sesión nueva redirige desde el layout
    catch (e: any) { setErr(e.message); setBusy(false); }
  }
  useEffect(() => { if (code.length === 6) verify(code); }, [code]);

  async function resend() {
    setErr(null);
    try { await auth.sendOtp(phone, role); setWait(30); } catch (e: any) { setErr(e.message); }
  }

  return (
    <Screen scroll>
      <Header onBack={onBack} />
      <View style={{ gap: 6 }}>
        <T v="display">Escribe el código</T>
        <T v="caption">Lo enviamos por SMS al {phone}.</T>
      </View>
      <Field value={code} onChangeText={(t) => setCode(t.replace(/\D/g, '').slice(0, 6))} keyboardType="number-pad" autoFocus
        textContentType="oneTimeCode" autoComplete="sms-otp" maxLength={6} placeholder="••••••" accessibilityLabel="Código de 6 dígitos"
        style={{ fontSize: 28, letterSpacing: 10, textAlign: 'center', fontFamily: f.black, height: 64 }} />
      {err ? <Banner text={err} /> : null}
      <Button title="Verificar" onPress={() => verify()} loading={busy} disabled={code.length !== 6} />
      <Button title={wait > 0 ? `Reenviar código en ${wait} s` : 'Reenviar código'} variant="outline" disabled={wait > 0} onPress={resend} />
    </Screen>
  );
}

export function NameForm({ onDone }: { onDone: () => void }) {
  const [name, setName] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function save() {
    setBusy(true); setErr(null);
    try { await auth.setName(name); onDone(); } catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }
  return (
    <Screen scroll>
      <View style={{ flex: 1, justifyContent: 'center', gap: 20 }}>
        <View style={{ gap: 6 }}>
          <T v="display">¿Cómo te llamas?</T>
          <T v="caption">Tu conductor verá tu nombre al recogerte.</T>
        </View>
        <Field value={name} onChangeText={setName} placeholder="Nombre y apellido" autoFocus autoCapitalize="words"
          textContentType="name" autoComplete="name" onSubmitEditing={save} />
        {err ? <Banner text={err} /> : null}
        <Button title="Continuar" onPress={save} loading={busy} disabled={name.trim().length < 2} />
      </View>
    </Screen>
  );
}

export function WrongRole({ message }: { message: string }) {
  return (
    <Screen>
      <View style={{ flex: 1, justifyContent: 'center', gap: 16 }}>
        <Brand />
        <T v="title">Esta cuenta no es compatible con esta app</T>
        <T v="body" color={c.ink2}>{message}</T>
        <Button title="Usar otro número" variant="dark" onPress={() => auth.signOut()} />
      </View>
    </Screen>
  );
}

export function ConfigMissing({ missing }: { missing: string[] }) {
  return (
    <Screen>
      <View style={{ flex: 1, justifyContent: 'center', gap: 12 }}>
        <Brand />
        <T v="title">Falta configurar la app</T>
        <T v="body" color={c.ink2}>Crea el archivo .env de esta app a partir de .env.example y reinicia con `npx expo start -c`.</T>
        <Banner tone="warn" text={'Faltan: ' + missing.join(', ')} />
      </View>
    </Screen>
  );
}
