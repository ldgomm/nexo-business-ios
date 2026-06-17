#!/usr/bin/env python3
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    print("Uso: python3 fix_update_customer_placeholders.py /ruta/a/nexo-business-ios")
    sys.exit(2)

root = Path(sys.argv[1]).expanduser().resolve()
if not root.exists():
    print(f"No existe: {root}")
    sys.exit(2)

pattern = re.compile(
    r"(?P<indent>^[ \t]*)"
    r"(?P<header>func\s+updateCustomer\s*\([\s\S]*?\)\s*async\s+throws\s*->\s*(?:Nexo_Business\.)?QuickSaleResponse\s*)"
    r"\{\s*<#code#>\s*\}",
    re.MULTILINE,
)

changed_files = []
changed_methods = 0

for path in root.rglob("*.swift"):
    if any(part in {".build", "DerivedData", "build"} for part in path.parts):
        continue

    original = path.read_text(encoding="utf-8")

    def replace(match: re.Match) -> str:
        indent = match.group("indent")
        header = match.group("header")
        body_indent = indent + "    "
        global changed_methods
        changed_methods += 1
        return (
            f"{indent}{header}{{\n"
            f"{body_indent}lastUpdateCustomerRequest = request\n"
            f"{body_indent}lastUpdateCustomerIdempotencyKey = idempotencyKey\n"
            f"{body_indent}if let updateCustomerError {{\n"
            f"{body_indent}    throw updateCustomerError\n"
            f"{body_indent}}}\n"
            f"{body_indent}return updateCustomerResponse\n"
            f"{indent}}}\n"
            f"{indent}\n"
            f"{indent}var lastUpdateCustomerRequest: UpdateSaleCustomerRequest?\n"
            f"{indent}var lastUpdateCustomerIdempotencyKey: IdempotencyKey?\n"
            f"{indent}var updateCustomerResponse: QuickSaleResponse = PreviewData.quickSaleResponse\n"
            f"{indent}var updateCustomerError: Error?"
        )

    updated = pattern.sub(replace, original)
    if updated != original:
        path.write_text(updated, encoding="utf-8")
        changed_files.append(path)

print(f"Métodos corregidos: {changed_methods}")
for path in changed_files:
    print(f"OK: {path.relative_to(root)}")

if changed_methods == 0:
    print("No encontré placeholders '<#code#>' en updateCustomer(...). Puede que ya esté corregido o que la firma tenga otro formato.")
