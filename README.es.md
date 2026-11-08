<h1 align="center">🌀 Vent</h1>
<h3 align="center">Elige una temperatura.<br>Deja que Vent se encargue de los ventiladores.</h3>
<p align="center">Control gratuito y de código abierto de ventiladores para Mac. Justo en la barra de menús.</p>

<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1"><img src="https://img.shields.io/badge/Descargar%20para%20macOS-2563EB?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Descargar Vent"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Free_%26_Open_Source-0D9488?style=for-the-badge&amp;logo=opensourceinitiative&amp;logoColor=white" alt="Gratuito y de código abierto"></a>
</p>
<p align="center">
  <a href="https://github.com/Fallet666/vent/releases/tag/v1.3.7"><img src="https://img.shields.io/github/v/release/Fallet666/vent?style=flat-square&amp;color=7C3AED&amp;label=stable" alt="Última versión"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-64748B?style=flat-square" alt="macOS 13 o posterior">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-0D9488?style=flat-square" alt="Licencia MIT"></a>
</p>
<p align="center">
  <a href="#install">Primeros pasos</a> &nbsp; · &nbsp;
  <a href="docs/images/README.md">Capturas de pantalla</a>
</p>
<p align="center">
  <a href="README.md">English</a> &nbsp; · &nbsp;
  <a href="README.ru.md">Русский</a> &nbsp; · &nbsp;
  <a href="README.de.md">Deutsch</a> &nbsp; · &nbsp;
  <a href="README.es.md"><strong>Español</strong></a> &nbsp; · &nbsp;
  <a href="README.fr.md">Français</a> &nbsp; · &nbsp;
  <a href="README.pt-BR.md">Português (Brasil)</a> &nbsp; · &nbsp;
  <a href="README.zh-CN.md">简体中文</a> &nbsp; · &nbsp;
  <a href="README.ja.md">日本語</a> &nbsp; · &nbsp;
  <a href="README.ko.md">한국어</a>
</p>

> [!NOTE]
> **Compilación preliminar:** los cambios siguientes están en [v1.3.9-beta.1](https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1). La versión estable [v1.3.7](https://github.com/Fallet666/vent/releases/tag/v1.3.7) sigue disponible.
>
> Homebrew instala la versión estable; para probar esta versión preliminar, descarga el DMG desde el enlace anterior.

<p align="center">
  <img src="docs/images/temperature-light.png" width="320" alt="Temperatura objetivo, aspecto claro">
  &nbsp;&nbsp;
  <img src="docs/images/temperature-dark.png" width="320" alt="Temperatura objetivo, aspecto oscuro">
</p>

<table>
  <tr>
    <td align="center" width="33%"><strong>🌡️ Tu temperatura</strong><br><br>Elige un objetivo. Vent ajusta los ventiladores.</td>
    <td align="center" width="33%"><strong>👁️ Avisos visibles</strong><br><br>Detecta velocidades altas sin sonido.</td>
    <td align="center" width="33%"><strong>💚 Todos los modos son gratuitos</strong><br><br>Sin suscripción. Sin cuenta.</td>
  </tr>
</table>

## 🌡️ Tu temperatura. Tu elección.

No deberías tener que averiguar qué RPM usar cada vez que cambia tu carga de trabajo. Elige una **temperatura objetivo** en **Auto Temp**, y Vent ajustará la velocidad de los ventiladores hacia ella. También puedes elegir un perfil integrado y volver a lo que estabas haciendo.

> [!TIP]
> El control de temperatura está incluido. **Sin nivel de pago, suscripción ni cuenta.** Vent es software libre bajo la licencia MIT.

| Lo que quieres | Qué elegir |
|---|---|
| Dejar que macOS gestione la refrigeración | **Auto** |
| Hacer que Vent ajuste los ventiladores hacia una temperatura | **Auto Temp** |
| Establecer tú mismo las RPM exactas | **Manual RPM**, juntas o por ventilador |
| Cambiar rápidamente entre configuraciones guardadas | **Quiet**, **Normal**, **Gaming**, **Lap** o tu propio perfil |

Una temperatura objetivo es una meta, no una garantía: el resultado depende de tu Mac, la carga de trabajo y el entorno. Vent usa las lecturas disponibles de los sensores; la temperatura mostrada no mide la carcasa ni tu piel.

## 👁️ Mira cuándo los ventiladores pueden hacer ruido

**No tienes que oír los ventiladores para saber que están funcionando a gran velocidad.** Vent muestra un aviso visible en su panel cuando las velocidades de los ventiladores son altas. Esto resulta especialmente útil para personas sordas o con dificultades auditivas, y para cualquiera que lleve auriculares.

<p align="center">
  <img src="docs/images/noise-dark.png" width="320" alt="Vent muestra un aviso de texto naranja: ventiladores al 85 % — pueden hacer ruido">
</p>

El aviso estima el posible ruido a partir de las RPM: aparece cuando la velocidad actual más alta de un ventilador alcanza el 70 % de la velocidad máxima más alta comunicada. **No utiliza un micrófono ni mide decibelios.**

También puedes activar **Notify when fans are loud** en Settings y permitir las notificaciones de macOS. Mientras Vent esté en ejecución, las notificaciones también funcionan con el panel cerrado; la opción debe estar activada y las notificaciones de macOS permitidas.

## ✨ Una app pequeña, controles útiles

- Un panel compacto en la barra de menús con apariencia clara y oscura del sistema. Sin icono en el Dock.
- Temperatura y velocidades de los ventiladores en directo, con controles de RPM basados en los límites de hardware comunicados.
- Perfiles integrados, además de guardar, renombrar y eliminar los tuyos.
- Celsius o Fahrenheit, inicio al iniciar sesión y comprobaciones de actualizaciones configurables.
- Al cerrar el panel se conserva el modo seleccionado.
- `ventctl` para scripts y diagnósticos. Consulta la [guía para desarrolladores](docs/DEVELOPMENT.md).

<a id="install"></a>

## 🚀 Primeros pasos

### Homebrew

```sh
brew tap Fallet666/homebrew-tap
brew install --cask vent
```

### Descargar

1. Descarga el DMG de [la última versión](https://github.com/Fallet666/vent/releases/tag/v1.3.9-beta.1).
2. Arrastra **Vent** a **Applications** y ábrelo.
3. Sigue la configuración para instalar el helper. macOS pide una contraseña de administrador porque cambiar las velocidades de los ventiladores requiere privilegios elevados.
4. Elige **Auto Temp** y, después, la temperatura objetivo, o selecciona un perfil.

El empaquetado actual usa firma ad hoc en lugar de notarización de Developer ID, por lo que macOS podría bloquear la app descargada. Revisa el código fuente y la versión antes de decidir si permites su uso en la configuración de seguridad de macOS.

**Requiere macOS 13+ y un Mac con ventiladores controlables.** El proyecto incluye soporte para Intel y Apple Silicon, pero la disponibilidad de sensores y el control de ventiladores varían según el modelo. Un MacBook Air sin ventilador no tiene ningún ventilador que controlar. [Informa sobre la compatibilidad](https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml) en lugar de asumir que todos los modelos son compatibles.

## ↩️ Volver al control de macOS

> [!IMPORTANT]
> **Cerrar el panel conserva la configuración elegida; salir de la app restablece Auto.**

Antes de salir, Vent espera la confirmación del helper de que Auto está activo. Si no puede confirmar Auto, la app permanece abierta y muestra un error. Settings también ofrece **Uninstall Helper**, que devuelve los ventiladores a Auto y elimina el helper. Elimina la app por separado si ya no la necesitas.

## 🔒 Privacidad

Sin cuenta ni analítica. El control de los ventiladores se realiza localmente mediante un socket Unix entre la app y `ventd`.

**Las comprobaciones automáticas de actualizaciones están activadas de forma predeterminada** y contactan con GitHub para obtener información de versiones. Descargar una actualización también usa la red. Desactiva **Automatically check for updates** en Settings si no quieres comprobaciones automáticas.

## 💚 Ayuda a Vent a llegar a más Macs

<p align="center">
  <a href="https://github.com/Fallet666/vent"><img src="https://img.shields.io/badge/Star_Vent-F59E0B?style=for-the-badge&amp;logo=github&amp;logoColor=white" alt="Dar una estrella a Vent en GitHub"></a>
  <a href="https://github.com/Fallet666/vent/issues/new?template=compatibility_report.yml"><img src="https://img.shields.io/badge/Share_your_Mac-7C3AED?style=for-the-badge&amp;logo=apple&amp;logoColor=white" alt="Enviar un informe de compatibilidad"></a>
</p>

Si Vent te resulta útil, da una estrella al repositorio, compártelo con alguien que lo necesite o envía un informe de compatibilidad. Los informes de errores, las traducciones y los pull requests también ayudan.

Al informar de un problema de hardware, incluye el modelo de tu Mac, la versión de macOS, lo que esperabas y la salida de:

```sh
ventctl list
ventctl temps
ventctl daemon status
```

## 🛠️ Compilar y contribuir

Instrucciones de compilación, ejemplos de CLI y arquitectura: [guía para desarrolladores](docs/DEVELOPMENT.md).

## Licencia

[MIT](LICENSE). Úsala, revísala y mejórala.
