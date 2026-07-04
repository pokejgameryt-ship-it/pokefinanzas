<p align="center">
  <img src="logo.png" width="128" alt="PokeFinanzas Logo">
</p>

<h1 align="center">PokeFinanzas</h1>

<p align="center">
  App de finanzas personales multiplataforma (Android + Web)
</p>

<p align="center">
  <a href="https://pokefinanzas.web.app">Web App</a> · 
  <a href="https://github.com/pokejgameryt-ship-it/pokefinanzas/releases/latest">Descargar APK</a> · 
  <a href="https://github.com/pokejgameryt-ship-it/pokefinanzas/issues">Reportar Bug</a>
</p>

---

## Que es PokeFinanzas?

PokeFinanzas es una aplicacion gratuita para controlar tus finanzas personales. Registra tus ingresos y gastos, establece presupuestos mensuales, crea metas de ahorro y visualiza tu evolucion financiera con graficos y estadisticas.

**Disponible en:**
- **Android**: APK autoactualizable
- **Web**: PWA instalable desde el navegador

---

## Funcionalidades

### Control de Ingresos y Gastos

| Caracteristica | Descripcion |
|----------------|-------------|
| Registro diario | Aniade ingresos y gastos con fecha, cantidad y categoria |
| Efectivo vs Banco | Indica si el movimiento es en efectivo o cuenta bancaria |
| Balance en tiempo real | Muestra tu saldo actual, balance mensual y semanal |
| Busqueda global | Encuentra movimientos por descripcion, categoria o etiquetas |
| Etiquetas | Organiza tus gastos con tags personalizados |
| Categorias | 36 iconos y 20 colores para personalizar tus categorias |
| Importar CSV | Importa datos desde archivos o pegando contenido directamente |

### Presupuesto Mensual

| Caracteristica | Descripcion |
|----------------|-------------|
| Porcentaje o fijo | Define presupuesto como % del ingreso o cantidad fija |
| Redistribucion | El dinero no gastado se reparte automaticamente entre otras categorias |
| Bloqueo inteligente | Si los gastos superan el ingreso, la redistribucion se desactiva |
| Tope proporcional | Nunca se excede el ahorro neto (ingreso - gasto total) |
| Presets | Guarda y carga configuraciones de redistribucion |

### Metas de Ahorro

| Caracteristica | Descripcion |
|----------------|-------------|
| Objetivos | Establece una cantidad a alcanzar con fecha limite |
| Pagos fijos | Configura pagos periodicos (diario, semanal, mensual, trimestral, anual) |
| Recordatorios | Recibe una notificacion 2 dias antes de cada pago |
| Progreso | Sigue el avance con barra porcentual |

### Estadisticas e Informes

| Caracteristica | Descripcion |
|----------------|-------------|
| Resumen mensual | Ingresos, gastos, ahorro y balance del mes |
| Comparativa | Compara el mes actual con el anterior |
| Graficos | Barras, lineas y circular para visualizar tendencias |
| Informes PDF | Genera PDFs con graficos y valores exactos |
| Exportar CSV | Copia datos al portapapeles |

### Notificaciones

| Caracteristica | Descripcion |
|----------------|-------------|
| Informe mensual | Resumen automatico el dia 1 de cada mes |
| Alertas de presupuesto | Aviso al 90% y 100% del limite |
| Recordatorios | Notificacion antes de gastos recurrentes |
| Configuracion | Activa o desactiva cada tipo individualmente |

---

## Capturas

<p align="center">
  <img src="web/icons/Icon-512.png" width="200" alt="PokeFinanzas">
</p>

---

## Descarga

### Android
1. Descarga la APK desde [Releases](https://github.com/pokejgameryt-ship-it/pokefinanzas/releases/latest)
2. Abre el archivo descargado
3. Si es la primera vez, activa "Fuentes desconocidas" en la configuracion
4. Pulsa "Instalar"

**O desde la app:**
- Ve a Ajustes > Aplicacion > Descargar APK Android

### Web
1. Accede a [pokefinanzas.web.app](https://pokefinanzas.web.app)
2. Inicia sesion o crea una cuenta
3. Para instalar como PWA: pulsa "Instalar" en la barra de direccion del navegador

---

## Desarrollo

### Requisitos
- Flutter 3.44.4+
- Node.js (para Firebase CLI)
- Cuenta de Firebase

### Instalacion

```bash
# Clonar el repositorio
git clone https://github.com/pokejgameryt-ship-it/pokefinanzas.git
cd pokefinanzas

# Instalar dependencias
flutter pub get

# Ejecutar en web
flutter run -d chrome

# Ejecutar en Android
flutter run -d <device_id>
```

### Build

```bash
# APK Android
flutter build apk --release

# Web
flutter build web --release
```

### Estructura

```
lib/
├── main.dart                    # Entry point + sincronizacion
├── models/                      # Modelos de datos
│   ├── expense.dart            # Gastos
│   ├── daily_income.dart       # Ingresos
│   ├── goal.dart               # Metas de ahorro
│   ├── product.dart            # Productos de tienda
│   ├── category_model.dart     # Categorias personalizadas
│   └── ...
├── services/                    # Logica de negocio
│   ├── firebase_service.dart   # CRUD con Firebase
│   ├── database_service.dart   # Estado local
│   ├── auth_service.dart       # Autenticacion
│   ├── update_service.dart     # Auto-update
│   └── ...
├── screens/                     # Pantallas
│   ├── home/                   # Dashboard principal
│   ├── movimientos/            # Lista de movimientos
│   ├── stats/                  # Estadisticas
│   ├── savings/                # Distribucion y metas
│   ├── settings/               # Configuracion
│   └── ...
├── widgets/                     # Componentes reutilizables
└── utils/                       # Utilidades y temas
```

---

## Tecnologias

- **Flutter** - Framework UI multiplataforma
- **Firebase** - Backend (Auth + Realtime Database + Hosting)
- **Material Design 3** - Sistema de diseno

---

## Changelog

### v1.0.3
- Fixes criticos de parsing de datos
- Botones de Ajustes funcionando en web
- Actualizacion automatica desde la app (APK)
- Ayuda completa actualizada

### v1.0.2
- Restablecer contraseña desde el login

### v1.0.1
- Permiso INTERNET para Android
- Nombre y icono de la app

### v1.0.0
- Lanzamiento inicial con todas las funcionalidades

---

## Licencia

MIT

---

## Contacto

- **GitHub**: [pokejgameryt-ship-it](https://github.com/pokejgameryt-ship-it)
- **Issues**: [Reportar problema](https://github.com/pokejgameryt-ship-it/pokefinanzas/issues)
