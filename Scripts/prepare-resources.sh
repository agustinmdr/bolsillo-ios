#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p Importacion
for file in historico-revisar.csv complemento-planilla.json private-setup.json; do
    if [ ! -e "Importacion/$file" ]; then
        cp "Resources/Examples/$file" "Importacion/$file"
    fi
done
printf '%s\n' 'Recursos listos. Se conservaron los archivos locales existentes.'
