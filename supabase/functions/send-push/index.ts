// FAXI · Edge Function: envía una notificación push (Expo) por cada fila nueva en public.notifications.
// La llama el trigger notifications_push (migración 005, pg_net) con la cabecera x-faxi-secret.
// El secreto vive en el Vault de la base (faxi_push_secret) y se comprueba con check_push_secret();
// PUSH_WEBHOOK_SECRET como variable de entorno también vale (opcional).
// Deploy:  supabase functions deploy send-push --no-verify-jwt   ·   Opcional: EXPO_ACCESS_TOKEN
import { createClient } from 'jsr:@supabase/supabase-js@2';

type NotificationRow = { id: string; user_id: string; type: string; title: string; body: string | null; data: Record<string, unknown> };

Deno.serve(async (req) => {
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const given = req.headers.get('x-faxi-secret');
  const envSecret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  let allowed = !!given && !!envSecret && given === envSecret;
  if (!allowed && given) {
    const { data } = await sb.rpc('check_push_secret', { p_secret: given });
    allowed = data === true;
  }
  if (!allowed) return new Response('forbidden', { status: 403 });

  const { record } = (await req.json()) as { record: NotificationRow };
  if (!record?.user_id) return Response.json({ sent: 0 });
  const { data: tokens, error } = await sb.from('push_tokens').select('token').eq('user_id', record.user_id);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  if (!tokens?.length) return Response.json({ sent: 0 });

  const messages = tokens.map((t) => ({
    to: t.token,
    title: record.title,
    body: record.body ?? undefined,
    data: { ...record.data, type: record.type },
    sound: 'default',
    priority: 'high',
    channelId: 'trips',
  }));

  const headers: Record<string, string> = { 'content-type': 'application/json', accept: 'application/json' };
  const expoToken = Deno.env.get('EXPO_ACCESS_TOKEN');
  if (expoToken) headers.authorization = `Bearer ${expoToken}`;

  const res = await fetch('https://exp.host/--/api/v2/push/send', { method: 'POST', headers, body: JSON.stringify(messages) });
  const out = await res.json();

  // Limpia tokens de dispositivos que desinstalaron la app
  const dead = (out?.data ?? [])
    .map((d: { details?: { error?: string } }, i: number) => (d?.details?.error === 'DeviceNotRegistered' ? messages[i].to : null))
    .filter(Boolean);
  if (dead.length) await sb.from('push_tokens').delete().in('token', dead);

  return Response.json({ sent: messages.length, removed: dead.length });
});
