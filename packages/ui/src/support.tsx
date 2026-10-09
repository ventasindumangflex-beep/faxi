import React, { useState } from 'react';
import { View } from 'react-native';
import { support, TICKET_LABEL, type TicketCategory } from '@faxi/core';
import { Banner, Button, Chip, Field, Header, Screen, T } from './components';

export function SupportForm({ categories, tripId, onBack, onDone }: {
  categories: TicketCategory[]; tripId?: string | null; onBack: () => void; onDone: () => void;
}) {
  const [cat, setCat] = useState<TicketCategory>(categories[0]);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);

  async function send() {
    setBusy(true); setErr(null);
    try { await support.create({ category: cat, subject, body, tripId }); setSent(true); }
    catch (e: any) { setErr(e.message); } finally { setBusy(false); }
  }

  if (sent) {
    return (
      <Screen>
        <View style={{ flex: 1, justifyContent: 'center', gap: 14 }}>
          <T v="title">Recibimos tu reporte</T>
          <T v="body">Nuestro equipo lo revisará y te contactará por teléfono o WhatsApp.</T>
          <Button title="Listo" onPress={onDone} />
        </View>
      </Screen>
    );
  }
  return (
    <Screen scroll>
      <Header title="Reportar un problema" onBack={onBack} />
      <T v="micro">Tipo</T>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
        {categories.map((k) => <Chip key={k} label={TICKET_LABEL[k]} selected={k === cat} onPress={() => setCat(k)} />)}
      </View>
      <Field label="Asunto" value={subject} onChangeText={setSubject} maxLength={120} placeholder="Ej. Me cobraron de más" />
      <Field label="Cuéntanos qué pasó" value={body} onChangeText={setBody} maxLength={2000} multiline
        style={{ height: 140, paddingTop: 14, textAlignVertical: 'top' }} />
      {tripId ? <T v="caption">Se adjuntará tu último viaje.</T> : null}
      {err ? <Banner text={err} /> : null}
      <Button title="Enviar" onPress={send} loading={busy} disabled={subject.trim().length < 3 || body.trim().length < 3} />
    </Screen>
  );
}
