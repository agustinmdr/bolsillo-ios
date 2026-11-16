# Bolsillo

Aplicación nativa de control de gastos para iPhone, construida con SwiftUI y Observation. Incluye cuotas, gastos recurrentes, ingresos, categorías, gráficos mensuales, reparto entre personas, resúmenes de tarjetas, respaldos, exportación Excel y widget de carga rápida.

## Abrir el proyecto

Requiere macOS y Xcode con SDK de iOS 17 o posterior.

```sh
sh Scripts/prepare-resources.sh
open Bolsillo.xcodeproj
```

El primer comando crea archivos locales vacíos de importación solo cuando faltan. Nunca sobrescribe los archivos existentes. Una copia nueva inicia sin gastos personales.

Para simulador, seleccioná el esquema Bolsillo y un iPhone. Para dispositivo real, configurá tu equipo de firma e identificadores propios en ambos targets. El identificador de App Group debe coincidir en los entitlements, Store y widget. La firma local existente se conserva en este proyecto; su identificador de equipo no es una contraseña.

## Organización

```text
App/
  Application/        Entrada, apariencia y navegación raíz
  State/              Store observable de la aplicación
  Services/           Coordinación de nube y recordatorios
  Integrations/Wallet/ Acciones de App Intents y Atajos
  Features/
    Overview/         Resumen y gráficos
    Expenses/         Movimientos, formulario y edición masiva
    Categories/       Catálogo y editor de categorías
    Wallets/          Medios de pago y cierre/vencimiento
    Statements/       Resúmenes y conciliación
    Sharing/          Reparto y liquidaciones
    Planning/         Presupuestos, ingresos y recurrentes
    Reports/          Exportación y hoja de compartir
    Rules/            Reglas por comercio
    Import/           Revisión de importaciones
    Settings/         Preferencias, respaldos y conexión
  Preview/            Entradas de comprobación, solo DEBUG
Core/
  Models/             Entidades financieras compatibles con JSON
  Domain/             Operaciones y reglas financieras
  Services/           Almacenamiento, nube, Excel y captura de pagos
DesignSystem/
  Theme.swift         Paleta adaptable a claro y oscuro
  Components/         Componentes reutilizables
Widget/               Extensión WidgetKit
Tests/                Pruebas con datos sintéticos
Resources/Examples/   Plantillas vacías para una copia nueva
Scripts/              Preparación y verificación reproducibles
Docs/                 Arquitectura y configuración
```

Los grupos de Xcode siguen estas carpetas. El proyecto mantiene la misma app, extensión e identificadores de persistencia.

## Arquitectura

Se organiza por funcionalidades, con estado observable y servicios separados. Las vistas leen `Store` con `@Environment`, mantienen el estado temporal del formulario en `@State` y solicitan cambios al Store. El motor financiero usa Foundation y se prueba sin iniciar SwiftUI. El almacenamiento, la exportación y el cliente de nube están separados de las pantallas.

Es una aplicación de los principios de MVVM adecuada para el tamaño actual: responsabilidades separadas y estado observable. No hay un ViewModel vacío por pantalla. Ver [decisiones y dependencias](Docs/ARCHITECTURE.md).

## Funcionalidades

- Gastos propios, compartidos o de otra persona; pagador y porcentajes independientes.
- Cuotas con distribución exacta de centavos y cargos históricos que no crean proyecciones duplicadas.
- Gastos recurrentes, ingresos y presupuestos mensuales; ARS y USD separados.
- Categorías con íconos, búsqueda y gráficos por mes.
- Tarjetas activas, cuentas, archivo de medios y conciliación de resúmenes.
- Responsabilidad en un desplegable sobre categorías; selector mensual y tema claro/oscuro propios.
- Guardado local atómico en `Application Support/Bolsillo/ledger.json`, respaldos y restauración.
- Reportes `.xlsx` con detalle, resúmenes por moneda y gráficos nativos.
- Widget que abre la carga de gastos. Captura opcional de Apple Pay mediante una automatización de Atajos configurada por el usuario; no lee Wallet ni bancos directamente.
- Sincronización opcional con una API compatible, revisión de conflictos y credencial en Keychain.

## Datos privados y nube

Este repositorio contiene código, ícono, documentación y ejemplos sintéticos. No contiene gastos reales, archivos de conexión, credenciales ni strings de conexión a bases de datos.

`Importacion/`, `Private/`, `Verificacion/`, `Backend/`, archivos `.env` y configuraciones locales están excluidos. La API se desarrolla y despliega por separado; la app no se conecta directamente a PostgreSQL. El endpoint y la clave se ingresan en Ajustes → Sincronización y se almacenan en Keychain, no en el código.

Ver [configuración local](Docs/LOCAL_CONFIGURATION.md). Los valores históricos de algunos enums se conservan para leer respaldos anteriores; la interfaz usa términos genéricos.

## Verificación

```sh
sh Scripts/test.sh
xcodebuild -project Bolsillo.xcodeproj -scheme Bolsillo \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath /tmp/BolsilloBuild CODE_SIGNING_ALLOWED=NO build
```

Las pruebas cubren cuotas, centavos, reparto, recurrentes, monedas, importación idempotente, migraciones, conciliación, respaldos y conflictos de nube. La suite de Excel tiene su [guía independiente](Tests/ExcelReport/README.md). La comprobación de firma, widget instalado y automatizaciones de Wallet requiere un dispositivo real.
