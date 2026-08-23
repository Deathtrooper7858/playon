# 🎵 PlayOn - Music Player

Reproductor de música local con diseño oscuro/morado, control por notificaciones, carpetas y reproducción aleatoria.

## Características

- 🎵 Reproduce música guardada en el dispositivo
- 🔀 Modo aleatorio (shuffle)
- 🔁 Bucle: ninguno / repetir todo / repetir una canción
- ⏮ ⏯ ⏭ Controles: anterior, pausa/play, siguiente
- 📁 Vista por carpetas + vista "todas las canciones"
- 🔔 **Notificación persistente** con controles de reproducción
- 🎨 Tema oscuro con morado/violeta
- 🎧 Barra inferior mini-player mientras navegas

## Setup

### 1. Instalar Flutter

```bash
# Descargar Flutter SDK de https://flutter.dev
# Agregar al PATH
flutter doctor
```

### 2. Clonar e instalar dependencias

```bash
cd playon
flutter pub get
```

### 3. Configurar ícono de la app

Reemplaza el archivo `assets/icons/playon.png` con el logo provisto.
Luego ejecuta:

```bash
flutter pub add flutter_launcher_icons --dev
```

Agrega al `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/playon.png"
```

Ejecuta:
```bash
flutter pub run flutter_launcher_icons
```

### 4. Ejecutar en dispositivo/emulador

```bash
flutter run --release
```

## Permisos Android

El app solicita automáticamente:
- `READ_MEDIA_AUDIO` (Android 13+)
- `READ_EXTERNAL_STORAGE` (Android 12 y menor)
- `FOREGROUND_SERVICE` (para reproducción en background)

## Estructura del proyecto

```
lib/
├── main.dart                    # Entry point + JustAudioBackground init
├── theme.dart                   # Colores y ThemeData
├── models/
│   └── song_model.dart          # Modelo de canción
├── providers/
│   └── music_provider.dart      # Estado global: reproducción, shuffle, repeat
├── screens/
│   ├── library_screen.dart      # Pantalla principal (canciones + carpetas)
│   └── now_playing_screen.dart  # Reproductor a pantalla completa
└── widgets/
    ├── animated_album_art.dart  # Arte de álbum animado (gira al reproducir)
    ├── control_buttons.dart     # Botones de control (prev/play/next/shuffle/repeat)
    ├── mini_player.dart         # Mini-reproductor inferior
    └── progress_bar_widget.dart # Barra de progreso con seek
```

## Notificación

La notificación de Android aparece automáticamente al reproducir una canción, con:
- Título y artista
- Controles: anterior / pausa / siguiente
- Arte del álbum (si está disponible)
- Funciona desde la pantalla bloqueada

Implementado con `just_audio_background` + `audio_service`.

## Paleta de colores

| Nombre         | Hex       | Uso                          |
|---------------|-----------|------------------------------|
| bgDeep        | `#0A0A12` | Fondo principal              |
| bgCard        | `#12101F` | Tarjetas y mini-player       |
| bgSurface     | `#1A1730` | Superficies secundarias      |
| purplePrimary | `#9B59F5` | Acento principal             |
| purpleGlow    | `#BD7BFF` | Texto activo / glow          |
| purpleDim     | `#5B3A8A` | Iconos inactivos             |
| pinkAccent    | `#E040FB` | Gradientes y énfasis         |
| textPrimary   | `#F0EAFF` | Texto principal              |
| textSecondary | `#9B8EC4` | Texto secundario             |
