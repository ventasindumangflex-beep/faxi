export class FaxiError extends Error {
  code?: string;
  constructor(message: string, code?: string) { super(message); this.code = code; }
}

/** Traduce errores de Postgres/Supabase a mensajes de UI sin exponer detalles internos. */
export function toFaxiError(err: any): FaxiError {
  if (err instanceof FaxiError) return err;
  const code: string = err?.code ?? '';
  const msg: string = err?.message ?? '';
  let text = 'Algo salió mal. Inténtalo de nuevo.';
  if (code === '42501') text = /[a-záéíóúñ]/i.test(msg) && !/permission denied/i.test(msg) ? msg : 'No tienes permiso para esta acción.';
  else if (['FX409', '23505', '22023', '23514', 'P0002'].includes(code)) text = msg || text;
  else if (/fetch|network|timeout/i.test(msg)) text = 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  else if (/otp|token has expired|invalid.*token/i.test(msg)) text = 'Código incorrecto o vencido.';
  else if (/rate limit|security purposes/i.test(msg)) text = 'Demasiados intentos. Espera un minuto e inténtalo otra vez.';
  else if (/sms|phone/i.test(msg)) text = 'No pudimos enviar el SMS a ese número.';
  else if (/invalid login credentials/i.test(msg)) text = 'Correo o contraseña incorrectos.';
  else console.warn('[faxi] error no controlado', err);
  return new FaxiError(text, code);
}
