#!/usr/bin/env python3

# Build script for building Orion Kernel's iso.

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent

SOURCE = ROOT / "orion_v0.1.1.asm"
OBJECT = ROOT / "orion_v0.1.1.o"
ELF = ROOT / "orion_v0.1.1.elf"
LINKER = ROOT / "linker.ld"

ISO_ROOT = ROOT / "iso_root"
ISO = ROOT / "orion_v0.1.1.iso"

LIMINE_DATA = Path("/usr/share/limine")


def run(command):
    print(f"\n$ {' '.join(map(str, command))}")
    subprocess.run(command, check=True)


def main():

    # ---------------------------------------------------------
    # 1. Assemble
    # ---------------------------------------------------------

    run([
        "nasm",
        "-f", "elf64",
        str(SOURCE),
        "-o", str(OBJECT)
    ])


    # ---------------------------------------------------------
    # 2. Link
    # ---------------------------------------------------------

    run([
        "ld",
        "-T", str(LINKER),
        "-o", str(ELF),
        str(OBJECT)
    ])


    # ---------------------------------------------------------
    # 3. Prepare ISO directory
    # ---------------------------------------------------------

    (ISO_ROOT / "boot" / "limine").mkdir(
        parents=True,
        exist_ok=True
    )

    (ISO_ROOT / "EFI" / "BOOT").mkdir(
        parents=True,
        exist_ok=True
    )


    # ---------------------------------------------------------
    # 4. Copy Orion ELF
    # ---------------------------------------------------------

    shutil.copy2(
        ELF,
        ISO_ROOT / "boot" / "orion_v0.1.elf"
    )


    # ---------------------------------------------------------
    # 5. Copy Limine boot files
    # ---------------------------------------------------------

    limine_files = [
        "limine-bios.sys",
        "limine-bios-cd.bin",
        "limine-uefi-cd.bin",
    ]

    for filename in limine_files:
        shutil.copy2(
            LIMINE_DATA / filename,
            ISO_ROOT / "boot" / "limine" / filename
        )


    shutil.copy2(
        LIMINE_DATA / "BOOTX64.EFI",
        ISO_ROOT / "EFI" / "BOOT" / "BOOTX64.EFI"
    )


    # ---------------------------------------------------------
    # 6. Build ISO
    # ---------------------------------------------------------

    if ISO.exists():
        ISO.unlink()

    run([
        "xorriso",
        "-as", "mkisofs",
        "-R", "-r", "-J",
        "-b", "boot/limine/limine-bios-cd.bin",
        "-no-emul-boot",
        "-boot-load-size", "4",
        "-boot-info-table",
        "--efi-boot", "boot/limine/limine-uefi-cd.bin",
        "-efi-boot-part",
        "--efi-boot-image",
        "--protective-msdos-label",
        str(ISO_ROOT),
        "-o", str(ISO)
    ])


    # ---------------------------------------------------------
    # 7. Install Limine BIOS stages
    # ---------------------------------------------------------

    run([
        "limine",
        "bios-install",
        str(ISO)
    ])


    print("\nBuild successful!")
    print(f"ELF: {ELF}")
    print(f"ISO: {ISO}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(
            f"\nBuild failed with exit code {error.returncode}.",
            file=sys.stderr
        )
        sys.exit(error.returncode)
