# Configuración local

Ejecutá `sh Scripts/prepare-resources.sh` después de clonar. Crea, si faltan, tres recursos dentro de `Importacion/`:

- `historico-revisar.csv`: formato de migración con encabezado, inicialmente sin filas.
- `complemento-planilla.json`: candidatos adicionales de importación, inicialmente `[]`.
- `private-setup.json`: configuraciones confirmadas opcionales, inicialmente `[]`.

Toda esa carpeta está ignorada por Git. En una instalación personal los recursos existentes se conservan al ejecutar el script. La app guarda sus gastos en su contenedor de datos, separado del proyecto y del repositorio.

No guardes respaldos, reportes personales, capturas de movimientos ni archivos de conexión dentro de carpetas versionadas. `.gitignore` excluye las rutas de trabajo privadas y los formatos de credenciales habituales; antes de publicar cambios nuevos, revisá siempre los archivos que vas a incluir.

La sincronización requiere una API compatible con `GET /v1/ledger` y `PUT /v1/ledger`, autenticación bearer, revisiones y rechazo de conflictos. Configurá su URL HTTPS y credencial desde la app. No agregues una URL PostgreSQL ni una contraseña de la base al cliente iOS.

El backend existente se mantiene fuera de este repositorio, con sus variables de entorno y configuración de despliegue propias. La reorganización de iOS no redepliega ni altera sus servicios.
