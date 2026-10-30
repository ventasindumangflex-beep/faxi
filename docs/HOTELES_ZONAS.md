# Hoteles y zonas de taxis turísticos (regla de 200 m del INTRANT)

**La regla:** faxi no recoge pasajeros a menos de **200 m** de la puerta principal de un hotel del Gran Santo Domingo ni de una zona de taxis turísticos. Si alguien pide un viaje desde ahí, la app le dice que mueva el punto de recogida. **Dejar** a alguien en un hotel (destino) sí se puede.
La regla se queda. Sin lugares cargados no cambia nada: por eso hay que cargar la lista.

## Para Virgilio: cómo llenar la lista (una vez por hotel)
1. En el teléfono, abre **Google Maps** y busca el hotel.
2. Acércate al mapa y **mantén el dedo apretado sobre la puerta principal** del hotel. Sale un punto rojo.
3. Arriba o abajo salen **dos números** (por ejemplo `18.4719, -69.9406`). **Tócalos** para copiarlos.
4. Abre el panel (http://localhost:3001) → **Zonas**.
5. Llena:
   - **Nombre:** el nombre del hotel.
   - **Tipo:** Hotel (o "Zona de taxis turísticos").
   - **Coordenadas:** pega los dos números tal cual.
   - **Radio:** déjalo en **200**.
6. Toca **Agregar**. Debe salir un aviso verde.
7. Repite con el siguiente hotel.

**Si te equivocas:** en la lista toca **Pausar** en esa fila (no se borra; se puede volver a **Activar**).
**Si el panel dice que las coordenadas no sirven:** pega los dos números como los copia Google Maps, con coma en medio. Deben estar en el Gran Santo Domingo.

## Hoteles que ya tienen nombre (falta la puerta)
`docs/plantilla-hoteles.csv` ya trae 13 hoteles de Piantini, la Zona Colonial y el Malecón (tomados de un listado general, no de Virgilio). Solo falta ponerles la latitud y la longitud de la **puerta principal**, sacadas de Google Maps como arriba. Virgilio debe agregar los que él ve con taxis turísticos y quitar los que no apliquen. No se cargan en producción con coordenadas que no estén comprobadas.

## Para pasarle la lista a Frederick (sin panel)
Llena `docs/plantilla-hoteles.csv` (o `supabase/CARGAR_HOTELES_PLANTILLA.sql`) con una línea por hotel: **nombre, tipo, latitud, longitud**. No inventes coordenadas: sácalas de Google Maps como arriba. Frederick la carga con permiso, **primero en faxi-pruebas**.

## Aeropuerto
La zona de **Aeropuerto** es otra cosa: no prohíbe recoger. Solo sirve para un **recargo fijo opcional** (apagado en RD$0). Solo el SUPER_ADMIN lo cambia, en la misma pantalla Zonas.

## Para comprobar que funciona
En la app del pasajero, pide un viaje con el punto de recogida pegado a la puerta de un hotel ya cargado: debe salir el aviso del INTRANT. A unos 300 m debe dejar pedirlo.
