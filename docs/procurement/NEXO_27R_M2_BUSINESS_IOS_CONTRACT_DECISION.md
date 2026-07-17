# NEXO 27R.M.2 — Business iOS procurement contract decision

## Decision

`PASS_CLIENT_FOUNDATION` — the accepted 27R backend exposes the Business routes, DTOs, lifecycle actions, idempotency and permission gates required to begin Business iOS procurement. No server file is changed by 27R.M.2.

The Business app currently has no procurement feature directory. Its existing architecture is suitable: filesystem-synchronized Xcode groups, `APIClient`, `APIRequest`, `IdempotencyKey`, `BusinessHeaders`, `activeModules` and `effectivePermissions` are already present.

## Exact entry gate

- Required active module: `module.purchases`.
- Surface visibility is derived from the exact procurement permissions in `effectivePermissions`.
- The existing typed `BusinessCapabilities` response has no procurement member. 27R.M must not invent one or depend on preview-only vertical flags.
- Wildcard permission does not bypass the active-module requirement.

## Business endpoint families

| Surface | Business route |
|---|---|
| Suppliers | `/api/v1/business/procurement/suppliers` |
| Purchase orders | `/api/v1/business/procurement/purchase-orders` |
| Purchase receipts | `/api/v1/business/procurement/purchase-receipts` |
| Supplier documents | `/api/v1/business/procurement/supplier-documents` |
| Payables / aging | `/api/v1/business/procurement/payables`, `/aging` |
| Supplier payments | `/api/v1/business/procurement/supplier-payments` |
| Supplier statement | `/suppliers/{supplierId}/statement` |
| Attachments | `/api/v1/business/procurement/attachments` |

Create and lifecycle mutations use `Idempotency-Key`. Updates and state transitions carry the backend `expectedVersion`. Purchase mutations also carry the selected organization and branch through the existing Business headers/body contract.

## Non-negotiable client rules

1. Display backend money, quantities, received amounts, payable balances and running balances. Do not recompute authoritative truth in Swift.
2. Keep document date, due date, received instant and payment date as separate facts.
3. Purchase-order actions follow backend state: edit/send in `DRAFT`, cancel in `DRAFT` or `SENT`, receive in `SENT` or `PARTIALLY_RECEIVED`, close in `PARTIALLY_RECEIVED` or `RECEIVED`.
4. Receipt and supplier-document update/confirm/cancel actions are available only from `DRAFT` and only with the exact permission.
5. A payment can allocate only an `OPEN`, `PARTIALLY_PAID` or `OVERDUE` payable. A supplier payment can be voided only from `RECORDED`.
6. `supplier_payments.create`, `supplier_payments.void` and `supplier_statements.export` are server step-up actions. Business iOS must not invent a new step-up endpoint. It will submit through the existing authenticated client and present the server envelope if the session is insufficient.

## Proven gaps and safe treatment

- There is no attachment collection/list endpoint. Upload returns metadata; source resources retain attachment IDs; download/delete are by attachment ID. The client must not call a fabricated list route.
- Attachment upload is multipart (`sourceType`, `sourceId`, `expectedSourceVersion`, one `file`) and accepts PDF/JPEG/PNG up to 10 MiB. This belongs in the repository implementation substep.
- The backend may omit sensitive supplier/payment fields when the corresponding sensitive-view permission is absent. Swift response models must keep those properties optional.
- Costs can be omitted from purchase orders and receipts without `purchase_orders.cost_view`. Swift models must keep cost/totals optional and the UI must not substitute zero.

## Precise continuation

`27R.M.3_procurement_models_repository_mapping`

Implement exact Codable request/response models plus the JSON/binary/multipart repository boundary, with mapping tests. Navigation and operational forms remain out of M.2/M.3 until those contracts pass.
