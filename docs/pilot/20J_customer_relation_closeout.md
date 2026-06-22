# NEXO 20J — Customer relation closeout

**Fase:** 20J.8 — Customer relation closeout smoke + pilot acceptance  
**Fecha:** 2026-06-22 09:48:27  
**Rama:** main  
**Commit:** 9aae94d  
**Log:** /Users/ldgomm/Desktop/nexo_20j8_customer_relation_closeout_20260622_094757.log  
**Checklist manual:** /Users/ldgomm/Desktop/nexo_20j8_manual_smoke_20260622_094757.md  

---

## 1. Diagnóstico corto

20J se considera candidato a cierre solo si el operador entiende sin explicación técnica:

- Cliente real puede tener ventas, cuentas por cobrar, abonos, documentos y Customer 360.
- Consumidor final puede tener venta normal o venta sin cobrar, pero nunca deuda formal.
- Historial es memoria general de ventas.
- Por cobrar es deuda real con cliente identificado.

## 2. Estado git al cierre

```text
-  M "Nexo Business/features/customers/presentation/CustomerDirectoryView.swift"
-  M "Nexo Business/features/receivables/domain/ReceivableModels.swift"
-  M "Nexo Business/features/sales/domain/SalesModels.swift"
-  M "Nexo BusinessTests/features/customers/CustomerPickerViewModelTests.swift"
-  M "Nexo BusinessTests/features/receivables/ReceivableModelsDecodingTests.swift"
-  M "Nexo BusinessTests/features/sales/SaleDetailViewModelTests.swift"
-  M "Nexo BusinessTests/features/sales/SalesModelsDecodingTests.swift"
- ?? docs/pilot/
```

## 3. Evidencia automática

| Evidencia | Resultado |
|---|---|
| Git status/branch/log | Ver log |
| Copy crítico 20J | Ver log |
| Verificador 20J v3 | Ver log |
| xcodebuild test | Ver log |

## 4. Checklist manual

Completar desde el archivo generado en Desktop:

```text
/Users/ldgomm/Desktop/nexo_20j8_manual_smoke_20260622_094757.md
```

### Casos obligatorios

| Caso | Resultado | Nota |
|---|---|---|
| A — Consumidor final venta sin cobrar | PENDIENTE |  |
| B — Cliente real venta pagada | PENDIENTE |  |
| C — Cliente real cuenta por cobrar | PENDIENTE |  |
| D — Abono parcial | PENDIENTE |  |
| E — Cobro total | PENDIENTE |  |
| F — Documento/comprobante relacionado | PENDIENTE |  |
| G — Duplicate guard | PENDIENTE |  |
| H — Datos incompletos/históricos | PENDIENTE |  |

## 5. Gaps

| Gap | Clasificación | Decisión |
|---|---|---|
| Pendiente de smoke manual | urgente | Ejecutar checklist manual |

## 6. Decisión recomendada

PENDIENTE.

Cerrar 20J si:

- Verificador 20J pasa.
- xcodebuild test termina con TEST SUCCEEDED.
- Smoke manual A-H queda PASS o WARN no bloqueante.
- No hay Consumidor final tratado como deudor.
- No hay confusión entre venta sin cobrar y Por cobrar.

Abrir 20J.9 solo si aparece bug real de merge, reconciliación, Customer 360 incompleto o datos históricos peligrosos.

