#!/usr/bin/env python3
import argparse
from pathlib import Path

EXCLUDED_DIRS = {
    ".git",
    "Pods",
    ".build",
    "build",
    "DerivedData",
}

def should_skip(path: Path) -> bool:
    return any(part in EXCLUDED_DIRS for part in path.parts)

def remove_public_tokens(text: str) -> tuple[str, int]:
    """
    Elimina el modificador de acceso 'public' cuando aparece como token Swift:
    - public struct
    - public final class
    - public protocol
    - public enum
    - public let
    - public var
    - public init
    - public func
    - public static
    - public private(set) var
    """
    targets = [
        "public final ",
        "public private(set) ",
        "public static ",
        "public let ",
        "public var ",
        "public func ",
        "public init",
        "public struct ",
        "public enum ",
        "public protocol ",
        "public class ",
        "public actor ",
        "public extension ",
        "public typealias ",
        "public subscript",
    ]

    count = 0
    updated = text

    for target in targets:
        occurrences = updated.count(target)
        if occurrences:
            updated = updated.replace(target, target.replace("public ", "", 1))
            count += occurrences

    # Caso genérico final: cualquier "public " restante como palabra completa.
    # Evita tocar "republic", "publico", etc.
    import re
    updated, generic_count = re.subn(r"\bpublic\s+", "", updated)
    count += generic_count

    return updated, count

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".", help="Ruta raíz del proyecto")
    parser.add_argument("--apply", action="store_true", help="Aplica cambios reales")
    parser.add_argument("--no-backup", action="store_true", help="No crear .bak")
    args = parser.parse_args()

    root = Path(args.root).resolve()

    if not root.exists():
        print(f"❌ La ruta no existe: {root}")
        return

    swift_files = [
        path for path in root.rglob("*.swift")
        if path.is_file() and not should_skip(path)
    ]

    affected_files = 0
    total_removed = 0

    print(f"Root: {root}")
    print(f"Modo: {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"Archivos Swift encontrados: {len(swift_files)}")
    print()

    for path in swift_files:
        original = path.read_text(encoding="utf-8")
        updated, removed = remove_public_tokens(original)

        if removed == 0:
            continue

        affected_files += 1
        total_removed += removed

        rel = path.relative_to(root)
        print(f"[{removed}] {rel}")

        if args.apply:
            if not args.no_backup:
                backup_path = path.with_suffix(path.suffix + ".bak")
                backup_path.write_text(original, encoding="utf-8")

            path.write_text(updated, encoding="utf-8")

    print()
    print(f"Archivos afectados: {affected_files}")
    print(f"'public' eliminados: {total_removed}")

    if not args.apply:
        print()
        print("No se modificó nada.")
        print("Para aplicar:")
        print(f"  python3 remove_public_swift.py \"{root}\" --apply")
    else:
        print()
        print("Listo. Cambios aplicados.")
        if not args.no_backup:
            print("Se crearon backups .swift.bak.")

if __name__ == "__main__":
    main()
