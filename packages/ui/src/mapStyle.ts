// Estilos de mapa de Google (Android) para el tema oscuro y el claro. Calles tenues, parques verdosos, sin comercios que distraigan.
// En iOS (Apple Maps) no existen estilos personalizados: allí se usa userInterfaceStyle.
import type { Scheme } from './tokens';

type Rule = { featureType?: string; elementType?: string; stylers: Record<string, string | number>[] };

const pick = (p: { geo: string; road: string; main: string; mainStroke: string; park: string; water: string; text: string; halo: string; admin: string }): Rule[] => [
  { elementType: 'geometry', stylers: [{ color: p.geo }] },
  { elementType: 'labels.icon', stylers: [{ visibility: 'off' }] },
  { elementType: 'labels.text.fill', stylers: [{ color: p.text }] },
  { elementType: 'labels.text.stroke', stylers: [{ color: p.halo }] },
  { featureType: 'administrative', elementType: 'geometry.stroke', stylers: [{ color: p.admin }] },
  { featureType: 'poi', stylers: [{ visibility: 'off' }] },
  { featureType: 'poi.park', stylers: [{ visibility: 'on' }] },
  { featureType: 'poi.park', elementType: 'geometry', stylers: [{ color: p.park }] },
  { featureType: 'poi.park', elementType: 'labels', stylers: [{ visibility: 'off' }] },
  { featureType: 'transit', stylers: [{ visibility: 'off' }] },
  { featureType: 'road', elementType: 'geometry', stylers: [{ color: p.road }] },
  { featureType: 'road', elementType: 'geometry.stroke', stylers: [{ color: p.geo }] },
  { featureType: 'road.arterial', elementType: 'geometry', stylers: [{ color: p.main }] },
  { featureType: 'road.highway', elementType: 'geometry', stylers: [{ color: p.main }] },
  { featureType: 'road.highway', elementType: 'geometry.stroke', stylers: [{ color: p.mainStroke }] },
  { featureType: 'water', elementType: 'geometry', stylers: [{ color: p.water }] },
  { featureType: 'water', elementType: 'labels.text.fill', stylers: [{ color: p.text }] },
];

export const MAP_STYLE: Record<Scheme, Rule[]> = {
  dark: pick({ geo: '#101814', road: '#222C27', main: '#2C3832', mainStroke: '#101814', park: '#12201A', water: '#0A1712', text: '#8A948D', halo: '#0E1411', admin: '#2E3832' }),
  light: pick({ geo: '#E4EBE4', road: '#FFFFFF', main: '#FFFFFF', mainStroke: '#D3DCD4', park: '#CFE6D6', water: '#C7DEE0', text: '#5F6A63', halo: '#F1F5F0', admin: '#D5DDD6' }),
};
