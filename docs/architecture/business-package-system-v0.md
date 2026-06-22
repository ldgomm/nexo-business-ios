# Nexo — Business Package System v0

**Fase:** 20K.3  
**Estado:** foundation read-only cerrada  
**Propósito:** documentar la columna vertebral para que Nexo soporte negocios simples y compuestos sin convertirse en una app distinta por industria.

---

## 1. Resumen en cristiano

Nexo no debe crecer como una colección de pantallas sueltas ni como una app diferente para cada tipo de negocio.

La arquitectura correcta es:

```text
Core común
  + Capability Packages
  + Vertical Presets
  + Activación futura controlada
  + Readiness y diagnóstico
```

En cristiano:

```text
El core vende, cobra, factura, controla caja, maneja clientes, catálogo y reportes.
Las capabilities describen habilidades reutilizables.
Los vertical presets agrupan capabilities para tipos de negocio.
La activación real vendrá después, con evidencia y sin romper el piloto.
```

---

## 2. Decisión ejecutiva

20K no debe construir verticales profundos todavía.

La decisión es:

```text
Arquitectura robusta desde ya.
Implementación liviana ahora.
Verticales profundos solo cuando haya demanda real, piloto real o cliente real.
```

20K.2A, 20K.2B y 20K.2C dejaron lista una foundation read-only:

```text
Backend BusinessPackageCatalog v0
        ↓
Admin endpoint read-only
        ↓
Admin iOS diagnostics read-only
        ↓
Smoke real y evidencia
```

No existe todavía:

```text
activación persistente
BusinessUnit persistente
OrganizationPackageActivation
UI de activar/configurar
cambios en Business iOS
verticales productivos completos
```

---

## 3. Problema que resuelve

Nexo debe servir para negocios como:

```text
restaurante
retail general
servicios con citas
profesionales
ferretería
gimnasio
taller
experiencias turísticas
eventos/catering
```

Pero también debe soportar negocios compuestos:

```text
Altos del Murco = restaurante + experiencias + eventos futuros
Centro médico = consultorio + farmacia + laboratorio futuro
Ferretería = tienda + alquiler + servicio técnico
Gimnasio = membresías + tienda + clases
```

El problema no es crear más verticales. El problema es evitar duplicar el core.

---

## 4. Principios permanentes

### 4.1 Core primero

Todo vertical debe reutilizar:

```text
core.sales
core.payments
core.cash
core.customers
core.catalog
core.receivables
core.documents
core.reports
core.users_roles_permissions
core.audit
```

### 4.2 No duplicar operación

Prohibido crear por vertical:

```text
restaurant_sales
restaurant_cash
restaurant_documents
gym_payments
workshop_customers
pharmacy_invoices
```

Si un vertical vende, usa `core.sales`.  
Si cobra, usa `core.payments` y `core.cash`.  
Si factura, usa `core.electronic_documents`.  
Si tiene clientes, usa `core.customers`.  
Si publica productos o servicios, parte de `core.catalog` y public projection futura.

### 4.3 Capabilities no son permisos

Una capability package no es un permiso suelto.

Es una habilidad de negocio reusable, por ejemplo:

```text
quick_sales
customer_management
receivables
menu
appointments
reservations
work_orders
```

Los permisos siguen controlando seguridad.  
Las capabilities ayudan a ordenar UX, readiness y verticales.

### 4.4 Vertical preset no es app separada

Un preset como `restaurant` no es una app restaurante.

Es una combinación de capabilities:

```text
restaurant
├── quick_sales
├── customer_management
├── menu
├── receivables optional
├── table_service_optional
├── kitchen_optional
└── public_offer_future
```

---

## 5. Modelo conceptual v0

```text
Organization
├── Branch
├── Activity
├── ActiveModules
├── CapabilityPackageDefinitions      read-only v0
├── VerticalPresetDefinitions         read-only v0
├── RecommendedPresetCodes            read-only v0
├── ModuleReadiness                   existente
└── PackageReadiness future
```

En v0 el sistema solo diagnostica. No activa.

Modelo futuro, no implementado todavía:

```text
OrganizationPackageActivation
├── organizationId
├── branchId optional
├── activityId optional
├── presetCode
├── enabledCapabilityCodes
├── disabledCapabilityCodes
├── status
├── readinessState
├── activatedBy
├── activatedAt
└── auditMetadata
```

---

## 6. Capability Packages v0

El catálogo v0 define 19 capabilities:

```text
capability.quick_sales
capability.customer_management
capability.receivables
capability.inventory_basic
capability.menu
capability.table_service_optional
capability.kitchen_optional
capability.appointments
capability.memberships
capability.work_orders
capability.reservations
capability.rentals_resources
capability.events_catering
capability.proformas_quotes
capability.lab_orders_future
capability.pharmacy_retail_future
capability.clinical_records_future
capability.public_offer_future
capability.chat_future
```

### 6.1 Capabilities disponibles ahora

Deben mapearse a capacidades ya cubiertas por core o muy cercanas:

```text
quick_sales
customer_management
receivables
```

### 6.2 Capabilities metadata/future

Sirven para planificar sin activar todavía:

```text
inventory_basic
menu
table_service_optional
kitchen_optional
appointments
memberships
work_orders
reservations
rentals_resources
events_catering
proformas_quotes
public_offer_future
chat_future
```

### 6.3 Capabilities reguladas/futuras

No se implementan productivamente sin revisión normativa, privacidad y seguridad:

```text
lab_orders_future
pharmacy_retail_future
clinical_records_future
```

Regla fuerte:

```text
No implementar datos clínicos, recetas, medicamentos controlados, dosis, resultados clínicos ni consejo médico sin revisión formal.
```

---

## 7. Vertical Presets v0

El catálogo v0 define 13 presets:

```text
restaurant
retail_general
services_appointments
professional_services
tourism_experiences
events_catering
rentals_resources
gym_basic
workshop_repair
hardware_store
health_office_future
pharmacy_basic_future
clinical_lab_future
```

### 7.1 Presets operativos/cercanos

```text
restaurant
retail_general
professional_services
services_appointments
```

### 7.2 Presets metadata/future

```text
tourism_experiences
events_catering
rentals_resources
gym_basic
workshop_repair
hardware_store
```

### 7.3 Presets regulados/futuros

```text
health_office_future
pharmacy_basic_future
clinical_lab_future
```

Estos no se muestran como listos para producción.

---

## 8. API read-only v0

Endpoint implementado:

```http
GET /api/v1/admin/business/packages
```

Respuesta conceptual:

```json
{
  "capabilityPackages": [],
  "verticalPresets": [],
  "recommendedPresetCodes": [],
  "activeModuleCodes": [],
  "activityTypeCodes": [],
  "warnings": []
}
```

Uso actual:

```text
Admin iOS diagnostics read-only
```

Uso prohibido por ahora:

```text
activar paquetes
configurar paquetes
ocultar módulos operativos
cambiar navegación Business iOS
cobrar planes comerciales
publicar storefront
```

---

## 9. Admin iOS diagnostics v0

Admin iOS debe mostrar:

```text
Paquetes del negocio
├── Resumen
├── Recomendados
├── Disponibles ahora
├── Futuros / metadata
└── Regulados
```

Copy base:

```text
Diagnóstico read-only de capabilities y verticales sugeridos. Todavía no activa funciones.
```

No debe mostrar botones:

```text
Activar
Desactivar
Configurar
Contratar
Publicar
```

---

## 10. Reglas para negocios compuestos

Un negocio compuesto no debe ser varias organizaciones separadas si opera bajo la misma entidad y comparte caja, clientes, catálogo o documentos.

Debe modelarse progresivamente así:

```text
Organization: Altos del Murco
├── Branch: Matriz
├── Activity: Restaurante
├── Activity: Experiencias future
└── Activity: Eventos future
```

Y debe compartir:

```text
clientes
catálogo base
ventas
caja
documentos
reportes
cuentas por cobrar
usuarios/roles
```

Cuando haga falta separar operación, se puede usar activity/branch/work mode, no duplicar core.

---

## 11. Riesgos controlados

| Riesgo | Impacto | Regla de control |
|---|---:|---|
| Construir verticales demasiado pronto | Alto | Solo metadata/read-only hasta tener evidencia |
| Duplicar ventas/caja/facturación | Crítico | Core común obligatorio |
| Activar salud/farmacia/lab sin revisión | Crítico | REGULATED_FUTURE |
| Crear roles rígidos por industria | Alto | Templates humanos editables |
| Mezclar capabilities con permisos | Medio | Permisos = seguridad; capabilities = UX/readiness |
| Inflar Admin con configuración pesada | Medio | Diagnostics read-only primero |

---

## 12. Criterio de salida de Business Package System v0

La foundation v0 se considera lista porque:

```text
Backend tiene catálogo read-only.
Admin tiene endpoint read-only.
Admin iOS consume y muestra diagnóstico.
Smoke real pasó con JSON real.
Restaurant se recomienda para Altos del Murco.
Presets regulados quedan marcados como REGULATED_FUTURE.
No hay activación persistente.
No hay Business iOS package context todavía.
No se tocó ventas, caja, documentos ni SRI.
```

---

## 13. Próximo paso recomendado

No construir activación todavía.

Ruta recomendada:

```text
20K.4 — Package activation design note, sin implementación
20N — Smoke piloto Altos del Murco usando core actual
21 — Core operativo fuerte
22 — Vertical Foundation + Restaurante v1, si el piloto ya exige profundidad restaurante
```

La activación real debe esperar a que existan:

```text
readiness claro
dependencias por paquete
UX Admin definida
auditoría
migración segura
criterio comercial real
```
