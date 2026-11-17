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

## Proyección y recordatorios

En Resumen → Proyección de próximos meses (también en Planificar) se muestran seis o doce meses, con Total / Tu parte / Parte de otra persona y ARS/USD separados. El detalle distingue fijos, cuotas, otros cargos registrados y cuotas históricas estimadas. Una lista indica cuándo finaliza cada plan y desde qué mes se libera ese importe.

Las cuotas nativas distribuyen centavos exactamente. Las estimaciones históricas usan la última cuota de una serie identificable y solo se muestran después de su último cargo importado; no crean gastos, no reemplazan el histórico y no modifican la sincronización. Si ya existe un plan nativo equivalente o la tarjeta está archivada, no se generan estimaciones históricas. Las series indistinguibles quedan advertidas para revisión. Los fijos usan su importe actual; la proyección no infiere aumentos, compras nuevas ni ingresos.

En Ajustes → Recordatorios (también en Planificar y Tarjetas) podés activar avisos de tarjetas y fijos por separado, elegir entre el mismo día y 30 días antes y configurar la hora. Para los fijos se elige el día de vencimiento de cada gasto; un día inexistente se ajusta al último del mes. Se respetan inicio y fin de recurrencia. Los resúmenes conciliados y pagados dejan de generar el aviso de tarjeta.

Los avisos no muestran importes. Las preferencias de recordatorios son locales a cada dispositivo y no cambian el ledger. Se programan hasta 60 avisos dentro de los siguientes doce meses y se actualizan al abrir o guardar. El permiso se pide al activar los avisos; si iOS lo deniega, hay acceso a sus ajustes. Se informa cuántos avisos se programaron y si hubo errores. La entrega real requiere verificar permisos y configuración del iPhone.

## Administrar tarjetas y cuentas

Desde Ajustes → Tarjetas y cuentas, o Tarjetas y resúmenes → Administrar, podés agregar tarjetas o cuentas, editar nombre/titular/extensión y configurar cierre/vencimiento. Para quitar un medio, deslizá su fila o abrilo y tocá Quitar; se solicita confirmación y queda archivado, conservando sus gastos, IDs y resúmenes. Se restaura desde Tarjetas y cuentas quitadas.

Los medios quitados no se ofrecen en cargas nuevas ni en las sugerencias de Atajos. Una automatización que conserve una tarjeta quitada informa que hay que restaurarla o elegir otra. El histórico sigue permitiendo consultar y editar gastos de esa cuenta. Si no quedan medios activos, el formulario permite ir a agregarlos.

La responsabilidad en el formulario se muestra en una sola línea; se trunca con puntos suspensivos cuando no entra. El menú conserva las tres opciones y VoiceOver lee su nombre completo. Las etiquetas de responsabilidad de los listados usan el mismo límite de una línea.

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
