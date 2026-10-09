import React, { useState } from 'react';
import { Alert, View } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { CATEGORY_CAPACITY, CATEGORY_LABEL, DOC_LABEL, driver, type Category, type DriverDocType, type VehicleDocType } from '@faxi/core';
import { Banner, Button, Card, Chip, Field, Icon, Row, Screen, StatusPill, T, c, useSession } from '@faxi/ui';
import { REQUIRED_DRIVER_DOCS, REQUIRED_VEHICLE_DOCS, useDriver } from '../src/driverCtx';

const CATEGORIES: Category[] = ['ECONOMICO', 'CONFORT', 'PREMIUM', 'SUV', 'VAN'];

export default function Onboarding() {
  const { me } = useSession();
  const { profile, docs, missingDocs, refresh } = useDriver();
  const v = profile?.vehicle;
  const [editing, setEditing] = useState(!profile?.current_vehicle_id || profile?.status === 'REJECTED' || v?.status === 'REJECTED');
  const [form, setForm] = useState({
    fullName: me?.full_name === 'Usuario' ? '' : me?.full_name ?? '',
    licenseNumber: profile?.license_number ?? '',
    make: v?.make ?? '', model: v?.model ?? '', year: v?.year ? String(v.year) : '', color: v?.color ?? '', plate: v?.plate ?? '',
    category: (v?.category ?? 'ECONOMICO') as Category,
  });
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const set = (k: keyof typeof form) => (val: string) => setForm((f) => ({ ...f, [k]: val }));

  async function submit() {
    setErr(null);
    const year = parseInt(form.year, 10);
    if (!/^[A-Za-z]{1,2}\s?\d{6}$/.test(form.plate.trim())) { setErr('La placa debe tener el formato A123456.'); return; }
    if (!year || year < 1990) { setErr('Escribe el año del vehículo.'); return; }
    setBusy('form');
    try {
      await driver.submitApplication({ ...form, year, capacity: CATEGORY_CAPACITY[form.category] });
      await refresh();
      setEditing(false);
    } catch (e: any) { setErr(e.message); } finally { setBusy(null); }
  }

  async function pick(kind: 'driver' | 'vehicle', type: DriverDocType | VehicleDocType, source: 'camera' | 'library') {
    setErr(null);
    const perm = source === 'camera' ? await ImagePicker.requestCameraPermissionsAsync() : await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) { setErr('Necesitamos permiso para usar la cámara o tus fotos.'); return; }
    const opts: ImagePicker.ImagePickerOptions = { mediaTypes: ['images'], quality: 0.6, allowsEditing: type === 'FOTO_PERFIL', aspect: [1, 1] };
    const res = source === 'camera' ? await ImagePicker.launchCameraAsync(opts) : await ImagePicker.launchImageLibraryAsync(opts);
    if (res.canceled || !res.assets[0]) return;
    setBusy(type);
    try { await driver.uploadDocument(kind, type, res.assets[0].uri, profile?.current_vehicle_id ?? undefined); await refresh(); }
    catch (e: any) { setErr(e.message); } finally { setBusy(null); }
  }

  function choose(kind: 'driver' | 'vehicle', type: DriverDocType | VehicleDocType) {
    Alert.alert(DOC_LABEL[type], 'Asegúrate de que se lea completo y sin reflejos.', [
      { text: 'Tomar foto', onPress: () => pick(kind, type, 'camera') },
      { text: 'Elegir de la galería', onPress: () => pick(kind, type, 'library') },
      { text: 'Cancelar', style: 'cancel' },
    ]);
  }

  const docRow = (kind: 'driver' | 'vehicle', type: DriverDocType | VehicleDocType) => {
    const rows = kind === 'driver' ? docs.driver : docs.vehicle.filter((d: any) => d.vehicle_id === profile?.current_vehicle_id);
    const latest = rows.find((d) => d.type === type);
    const done = !missingDocs.includes(type);
    return (
      <Row key={type} style={{ paddingVertical: 8 }}>
        <Icon name={done ? 'check-circle' : 'radio-button-unchecked'} color={done ? c.primary : c.outline} />
        <View style={{ flex: 1 }}>
          <T v="label">{DOC_LABEL[type]}</T>
          {latest?.status === 'REJECTED' ? <T v="caption" color={c.error}>Rechazado: {latest.rejection_reason ?? 'vuelve a subirlo'}</T> : null}
          {latest && latest.status !== 'REJECTED' ? <StatusPill label={latest.status === 'APPROVED' ? 'Aprobado' : 'En revisión'} tone={latest.status === 'APPROVED' ? 'ok' : 'warn'} /> : null}
        </View>
        <Button compact variant={done ? 'outline' : 'dark'} title={done ? 'Cambiar' : 'Subir'} loading={busy === type} onPress={() => choose(kind, type)} />
      </Row>
    );
  };

  const formDone = !!profile?.current_vehicle_id && !editing;

  return (
    <Screen scroll>
      <View style={{ gap: 6 }}>
        <T v="micro">Registro de conductor · paso {formDone ? 2 : 1} de 2</T>
        <T v="display">{formDone ? 'Sube tus documentos' : 'Tus datos y tu vehículo'}</T>
        <T v="caption">Revisamos cada solicitud a mano. Te avisaremos por notificación cuando estés aprobado.</T>
      </View>
      {profile?.status === 'REJECTED' && profile.rejection_reason ? <Banner text={`Solicitud rechazada: ${profile.rejection_reason}`} /> : null}
      {v?.status === 'REJECTED' && v.rejection_reason ? <Banner text={`Vehículo rechazado: ${v.rejection_reason}`} /> : null}

      {!formDone ? (
        <View style={{ gap: 14 }}>
          <Field label="Nombre completo (como en tu cédula)" value={form.fullName} onChangeText={set('fullName')} autoCapitalize="words" />
          <Field label="Número de licencia" value={form.licenseNumber} onChangeText={set('licenseNumber')} autoCapitalize="characters" />
          <T v="micro" style={{ marginTop: 6 }}>Vehículo</T>
          <Row gap={10}>
            <View style={{ flex: 1 }}><Field label="Marca" value={form.make} onChangeText={set('make')} placeholder="Toyota" /></View>
            <View style={{ flex: 1 }}><Field label="Modelo" value={form.model} onChangeText={set('model')} placeholder="Corolla" /></View>
          </Row>
          <Row gap={10}>
            <View style={{ flex: 1 }}><Field label="Año" value={form.year} onChangeText={set('year')} keyboardType="number-pad" maxLength={4} placeholder="2018" /></View>
            <View style={{ flex: 1 }}><Field label="Color" value={form.color} onChangeText={set('color')} placeholder="Gris" /></View>
          </Row>
          <Field label="Placa" value={form.plate} onChangeText={set('plate')} autoCapitalize="characters" placeholder="A123456" maxLength={9} />
          <T v="caption">Categoría</T>
          <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8 }}>
            {CATEGORIES.map((k) => <Chip key={k} label={CATEGORY_LABEL[k]} selected={form.category === k} onPress={() => set('category')(k)} />)}
          </View>
          {err ? <Banner text={err} /> : null}
          <Button title="Guardar y continuar" onPress={submit} loading={busy === 'form'}
            disabled={form.fullName.trim().length < 3 || form.licenseNumber.trim().length < 5 || !form.make || !form.model || !form.color} />
        </View>
      ) : (
        <View style={{ gap: 14 }}>
          <Card>
            <T v="micro">Tus documentos</T>
            {REQUIRED_DRIVER_DOCS.map((t) => docRow('driver', t))}
          </Card>
          <Card>
            <Row style={{ justifyContent: 'space-between' }}>
              <T v="micro">{v ? `${v.make} ${v.model} · ${v.plate}` : 'Vehículo'}</T>
              <T v="label" color={c.primaryDark} onPress={() => setEditing(true)}>Editar</T>
            </Row>
            {REQUIRED_VEHICLE_DOCS.map((t) => docRow('vehicle', t))}
          </Card>
          {err ? <Banner text={err} /> : null}
          <T v="caption" center>
            {missingDocs.length ? `Faltan ${missingDocs.length} documento(s).` : 'Todo listo. Tu solicitud está en revisión.'}
          </T>
        </View>
      )}
    </Screen>
  );
}
