#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"

mkdir -p build

testbenches=(tb/tb_*.v)
sources=(rtl/*.v)

failed=0
passed=0

if [ "${#testbenches[@]}" -eq 0 ]; then
    echo "ERROR: No se encontraron testbenches"
    exit 1
fi

if [ "${#sources[@]}" -eq 0 ]; then
    echo "ERROR: No se encontraron fuentes RTL"
    exit 1
fi

for tb in "${testbenches[@]}"; do
    name=$(basename "$tb" .v)

    echo "========================================"
    echo "Ejecutando: $name"
    echo "========================================"

    if ! iverilog -g2012 -Wall \
        -s "$name" \
        -o "build/$name.vvp" \
        "${sources[@]}" "$tb"; then

        echo "[FAIL] $name: Error de compilacion"
        failed=$((failed + 1))
        continue
    fi

    if (cd build && timeout 60s vvp -N "$name.vvp"); then
        echo "[PASS] $name"
        passed=$((passed + 1))
    else
        echo "[FAIL] $name"
        failed=$((failed + 1))
    fi
done

echo "========================================"
echo "RESUMEN DE TESTBENCHES"
echo "========================================"
echo "Total:    ${#testbenches[@]}"
echo "Exitosos: $passed"
echo "Fallidos: $failed"

if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "TODOS LOS TESTBENCHES PASARON"
exit 0