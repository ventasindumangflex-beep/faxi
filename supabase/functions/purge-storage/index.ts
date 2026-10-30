// FAXI · Edge Function: borra de Storage los archivos de documentos que ya no tienen fila en la base (migración 020).
// La llama la revisión diaria public.run_storage_purge() (pg_net) con la cabecera x-faxi-secret, la misma del push.
// Deploy:  supabase functions deploy purge-storage --no-verify-jwt
import { createClient } from 'jsr:@supabase/supabase-js@2';

type Row = { id: number; bucket: string; path: string; attempts: number };

Deno.serve(async (req) => {
  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const given = req.headers.get('x-faxi-secret');
  let allowed = false;
  if (given) {
    const { data } = await sb.rpc('check_push_secret', { p_secret: given });
    allowed = data === true;
  }
  if (!allowed) return new Response('forbidden', { status: 403 });

  const { data: rows, error } = await sb.from('storage_purge_queue')
    .select('id, bucket, path, attempts').is('purged_at', null).lt('attempts', 5).order('queued_at').limit(200);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  if (!rows?.length) return Response.json({ purged: 0, failed: 0 });

  const byBucket = new Map<string, Row[]>();
  for (const r of rows as Row[]) byBucket.set(r.bucket, [...(byBucket.get(r.bucket) ?? []), r]);

  let purged = 0, failed = 0;
  for (const [bucket, list] of byBucket) {
    const { error: rmErr } = await sb.storage.from(bucket).remove(list.map((r) => r.path));
    const ids = list.map((r) => r.id);
    if (rmErr) {
      failed += list.length;
      for (const r of list) await sb.from('storage_purge_queue').update({ attempts: r.attempts + 1, last_error: rmErr.message }).eq('id', r.id);
    } else {
      purged += list.length;
      await sb.from('storage_purge_queue').update({ purged_at: new Date().toISOString(), last_error: null }).in('id', ids);
    }
  }
  return Response.json({ purged, failed });
});
