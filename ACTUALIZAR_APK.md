# Proceso de actualizacion de APK

## Cuando actualizar la APK
- Cambios en el codigo fuente que afecten a Android
- Nuevas funcionalidades
- Correccion de bugs

## Pasos para actualizar

### 1. Construir la APK
```bash
flutter build apk --release --no-tree-shake-icons
```

### 2. Crear nueva release en GitHub
```bash
# Usar version incremental (v1.0.1, v1.0.2, etc.)
gh release create v1.0.X "build\app\outputs\flutter-apk\app-release.apk" --title "PokeFinanzas v1.0.X" --notes "Descripcion de los cambios"
```

### 3. Actualizar enlace en el codigo
Actualizar la URL del APK en estos archivos:
- `lib/screens/settings/settings_screen.dart` (linea con `apkUrl`)

### 4. Desplegar web (si hay cambios en la UI)
```bash
flutter build web --release --no-tree-shake-icons
# Copiar download.html a build/web/download.html
firebase deploy --only hosting
```

## Enlaces importantes
- **Web**: https://pokefinanzas.web.app
- **Descarga**: https://pokefinanzas.web.app/download.html
- **GitHub**: https://github.com/pokejgameryt-ship-it/pokefinanzas
- **APK**: https://github.com/pokejgameryt-ship-it/pokefinanzas/releases/download/v1.0.0/app-release.apk

## Notas
- La APK se aloja en GitHub Releases (no en Firebase Hosting)
- Firebase Hosting gratis no permite archivos .apk
- El boton "Descargar APK" en la app abre directamente el enlace de GitHub
