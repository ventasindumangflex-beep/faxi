import type { LatLng } from './types';

/** Decodifica la línea codificada de Google ("encoded polyline", precisión 5 decimales) a una lista de puntos. */
export function decodePolyline(encoded: string): LatLng[] {
  const out: LatLng[] = [];
  let i = 0, lat = 0, lng = 0;
  while (i < encoded.length) {
    for (const axis of ['lat', 'lng'] as const) {
      let shift = 0, result = 0, b: number;
      do {
        if (i >= encoded.length) return out;
        b = encoded.charCodeAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      const delta = result & 1 ? ~(result >> 1) : result >> 1;
      if (axis === 'lat') lat += delta; else lng += delta;
    }
    out.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }
  return out;
}
