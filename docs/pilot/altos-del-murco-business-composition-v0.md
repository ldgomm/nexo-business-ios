# Altos del Murco — Business Composition v0

**Fase:** 20K.3  
**Estado:** composición conceptual validada por package diagnostics read-only  
**Objetivo:** definir cómo Nexo debe entender Altos del Murco como negocio compuesto sin construir verticales completos todavía.

---

## 1. Resumen en cristiano

Altos del Murco no es solo restaurante.

Es un negocio compuesto que hoy opera principalmente como:

```text
Restaurante / comida preparada
```

Pero puede crecer hacia:

```text
Experiencias turísticas
Eventos / catering
Reservas
Alquiler de recursos
Publicación pública
Chat cliente-negocio
```

La decisión correcta no es convertir Nexo en una app gigante de restaurante-aventura-eventos ahora.

La decisión correcta es:

```text
Operar hoy con core sólido.
Diagnosticar paquetes desde Admin.
Documentar composición futura.
Activar verticales profundos solo cuando el piloto lo pida.
```

---

## 2. Estado actual

20K.2C validó que para la organización usada en smoke:

```text
activityTypeCodes = restaurant
recommendedPresetCodes = restaurant
```

Eso significa:

```text
Nexo reconoce a Altos del Murco como restaurante para el diagnóstico v0.
```

No significa todavía:

```text
restaurante activado como vertical persistente
mesas activadas
cocina activada
experiencias activadas
eventos activados
reservas activadas
```

---

## 3. Composición recomendada

```text
Altos del Murco
├── Restaurante actual
│   ├── venta rápida
│   ├── catálogo/menú
│   ├── caja
│   ├── pagos
│   ├── clientes
│   ├── documentos electrónicos
│   └── reportes
│
├── Experiencias futuras
│   ├── cuadrones
│   ├── paintball
│   ├── go karts
│   ├── camping
│   ├── reservas futuras
│   └── alquiler/uso de recursos futuro
│
└── Eventos / catering futuro
    ├── cumpleaños
    ├── grupos
    ├── paquetes
    ├── proformas/cotizaciones
    ├── reservas futuras
    └── conversión a venta/factura futura
```

---

## 4. Presets relacionados

### 4.1 Restaurante

Código:

```text
restaurant
```

Rol en Altos:

```text
preset recomendado actual
```

Capabilities relevantes:

```text
capability.quick_sales
capability.customer_management
capability.menu
capability.receivables optional
capability.table_service_optional future/optional
capability.kitchen_optional future/optional
capability.inventory_basic future
capability.proformas_quotes optional/future
capability.public_offer_future future
capability.chat_future future
```

Decisión:

```text
Usar venta rápida + catálogo + caja + documentos ahora.
No construir mesas/cocina avanzada todavía.
```

---

### 4.2 Experiencias turísticas

Código:

```text
tourism_experiences
```

Rol en Altos:

```text
metadata/future
```

Casos futuros:

```text
cuadrones por tiempo
paintball por sesión
go karts por turno
camping por noche
paquetes combinados
```

Capabilities futuras:

```text
capability.reservations
capability.rentals_resources
capability.events_catering optional
capability.proformas_quotes optional
capability.public_offer_future
capability.chat_future
```

Decisión:

```text
No construir reservas ni alquileres todavía.
Primero validar demanda real y operación manual.
```

---

### 4.3 Eventos / catering

Código:

```text
events_catering
```

Rol en Altos:

```text
metadata/future
```

Casos futuros:

```text
evento familiar
cumpleaños
grupo turístico
catering
salón con consumo mínimo
paquete adulto/niño
```

Capabilities futuras:

```text
capability.events_catering
capability.proformas_quotes
capability.reservations
capability.customer_management
capability.receivables optional
```

Dependencia clave:

```text
21J — Proformas / cotizaciones comerciales
```

Decisión:

```text
Primero implementar proformas en Fase 21J antes de eventos complejos.
```

---

## 5. Qué comparte todo Altos del Murco

Altos debe compartir el core:

```text
clientes
ventas
pagos
caja
documentos electrónicos
catálogo
reportes
usuarios/roles
cuentas por cobrar
auditoría
```

Ejemplo:

```text
Un cliente puede comprar borrego hoy,
reservar cuadrones mañana,
y pedir cotización para un cumpleaños después.
```

Ese cliente debe ser uno solo en Nexo, no tres clientes por vertical.

---

## 6. Catálogo recomendado

No crear tablas distintas para platos, experiencias y eventos si se pueden modelar como catálogo con atributos.

```text
OrganizationCatalogItem
├── prepared_food
├── product
├── service
├── experience_future
├── package_future
└── event_service_future
```

Ejemplos actuales:

```text
Cuy entero
Medio cuy
Borrego
Parrillada individual
Parrillada completa
Costilla BBQ
Yahuarlocro
Consomé
Jarra de jugo
Agua
Cola
Choclo con queso
Habas con queso
```

Ejemplos futuros:

```text
Cuadrón 30 minutos
Paintball sesión
Go kart 10 minutos
Camping por noche
Paquete cumpleaños
Paquete aventura
```

Regla:

```text
La naturaleza del ítem puede cambiar atributos y UX, pero no debe duplicar ventas/caja/documentos.
```

---

## 7. Work modes futuros posibles

No implementar todavía, pero documentar:

```text
restaurant_quick_sale
restaurant_owner
experience_operator_future
event_quote_manager_future
cashier
owner_dashboard
```

Regla:

```text
Work mode define cómo entra a trabajar el usuario.
Permiso define qué puede hacer.
Capability define qué pantallas/habilidades tienen sentido.
```

---

## 8. Riesgos de hacerlo mal

| Riesgo | Qué pasaría | Decisión |
|---|---|---|
| Construir restaurante full ahora | Se retrasa piloto | venta rápida primero |
| Construir reservas ahora | Complejidad sin evidencia | metadata/future |
| Crear módulo cuadrones aislado | Duplica caja/ventas/clientes | usar core + future reservations/rentals |
| Hacer eventos sin proformas | Mala UX comercial | esperar 21J |
| Separar clientes por área | rompe Customer 360 | cliente compartido |
| Mezclar facturación con proforma | riesgo fiscal/UX | proforma no tributaria |

---

## 9. Roadmap recomendado para Altos

### Ahora

```text
Core operativo
venta rápida
caja
pagos
documentos
clientes
reportes
Admin package diagnostics read-only
```

### Fase 21

```text
inventario básico
caja/reportes fuertes
precontabilidad
proformas/cotizaciones
```

### Fase 22

```text
Vertical Foundation
Restaurante v1 simple
menú más claro
tipos de servicio
mesas/cocina solo si el piloto lo pide
```

### Fase 23/24

```text
perfil público
productos/servicios visibles
chat cliente-negocio
búsqueda pública/IA controlada
```

### Futuro con demanda

```text
reservas
experiencias
alquileres/recursos
eventos/catering avanzado
paquetes combinados
```

---

## 10. Criterio para activar algo más que restaurante rápido

No activar reservas, experiencias o eventos fuertes hasta tener al menos:

```text
operación manual repetida
flujo claro
precio claro
responsable operativo
necesidad real en piloto
impacto en caja/pagos/reportes definido
soporte definido
```

La pregunta de corte:

```text
¿Esto ayuda a operar mejor este fin de semana o solo suena grande?
```

Si solo suena grande, espera.
