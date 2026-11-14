<!-- languages:start -->
<div align="center">

<details>
<summary><b>🌐 Language · Idioma · Langue · Sprache · Язык · 语言 · 言語 · 언어 · भाषा · لغة</b></summary>
<br>

<table>
  <tr>
    <td align="center"><a href="../../README.md">English</a></td>
    <td align="center"><a href="README.ar.md">العربية</a></td>
    <td align="center"><a href="README.bn.md">বাংলা</a></td>
    <td align="center"><a href="README.zh-Hans.md">简体中文</a></td>
    <td align="center"><a href="README.fil.md">Filipino</a></td>
  </tr>
  <tr>
    <td align="center"><a href="README.fr.md">Français</a></td>
    <td align="center"><a href="README.de.md">Deutsch</a></td>
    <td align="center"><a href="README.hi.md">हिन्दी</a></td>
    <td align="center"><a href="README.id.md">Bahasa Indonesia</a></td>
    <td align="center"><a href="README.it.md">Italiano</a></td>
  </tr>
  <tr>
    <td align="center"><a href="README.ja.md">日本語</a></td>
    <td align="center"><a href="README.ko.md">한국어</a></td>
    <td align="center"><a href="README.fa.md">فارسی</a></td>
    <td align="center"><a href="README.pt-BR.md">Português (Brasil)</a></td>
    <td align="center"><a href="README.ru.md">Русский</a></td>
  </tr>
  <tr>
    <td align="center"><b>Español</b></td>
    <td align="center"><a href="README.te.md">తెలుగు</a></td>
    <td align="center"><a href="README.th.md">ไทย</a></td>
    <td align="center"><a href="README.tr.md">Türkçe</a></td>
    <td align="center"><a href="README.vi.md">Tiếng Việt</a></td>
  </tr>
</table>

</details>

</div>
<!-- languages:end -->

# HomePad for macOS

> Esta traducción la ha escrito una IA y no ha sido revisada por hablantes nativos. HomePad también está disponible en este idioma; los nombres de botones y menús se dan tal como los muestra la app (el idioma se cambia en Ajustes → General → Idioma). Prevalece el [README en inglés](../../README.md).

**Todo lo que usas, a una tecla de distancia.** HomePad es el launcher que le faltaba a tu Mac: organiza tus apps en categorías, guárdalas en carpetas, ancla tus favoritas, busca todo al instante y ten a la vista las apps abiertas, con una barra de tareas al estilo Windows si quieres.

Un launcher al estilo Windows: pulsas un atajo y aparece un panel en el centro de la pantalla, con una barra de búsqueda arriba (que consulta el mismo índice que usa Spotlight) y una cuadrícula de apps ancladas debajo.

HomePad funciona en tres modos. Elige el que más te convenga en Ajustes → Modo.

**Barra de tareas.** Imita la barra de tareas y el menú Inicio de Windows. Si echas de menos Windows en macOS, te sentirás como en casa.

![Modo Barra de tareas: una barra de tareas al estilo Windows con botón Inicio, apps abiertas y una bandeja, y el panel de HomePad encima](../images/mode-taskbar.webp)

**Dock + HomePad.** Para quienes quieren conservar el «Dock» de macOS, pero necesitan un launcher al estilo del menú Inicio. macOS tiene el launcher Apps, pero no convence: organiza tus apps en categorías automáticamente, sin que puedas elegirlas, y no te deja agrupar apps en carpetas, anclar favoritas ni ordenarlo a tu gusto. HomePad resuelve todo eso.

![Modo Dock + HomePad: el Dock de macOS, con el panel de HomePad abriéndose encima de su icono](../images/mode-dock.webp)

**Independiente.** Para minimalistas que quieren el máximo espacio de pantalla, sin «Dock» ni barra de tareas. Llamas a HomePad con una tecla de atajo, una doble pulsación o un golpe de ratón a una esquina activa cuando lo necesitas. Aparece en el centro y tienes control total sobre tus apps, archivos y carpetas favoritos, la búsqueda y las apps abiertas con sus ventanas. No necesitas ni el «Dock» ni Spotlight: controlas tu Mac desde un único sitio. Al principio puede parecer raro, pero resulta increíblemente potente cuando te acostumbras.

![Modo Independiente: sin «Dock» ni barra de tareas, con el panel de HomePad en el centro de la pantalla](../images/mode-standalone.webp)

## Instalación

HomePad es gratuito y no está firmado por Apple, así que macOS lo bloquea una vez y te pide que confirmes que todo está bien. Lleva unos cinco minutos, una sola vez. Necesitas macOS 13 (Ventura) o posterior; sirven Macs con Apple silicon e Intel. ([INSTALL.md](../../INSTALL.md) recoge los mismos pasos con palabras, también para el zip y la imagen de disco sencilla.)

**1. Abre la imagen de disco del instalador.** Haz doble clic en `HomePad-Installer.dmg` (de quien te haya pasado HomePad, o compílalo tú: `tools/make_installer_dmg.sh`, consulta [Build and run](../../README.md#build-and-run)). Su ventana enumera los pasos.

<p align="center"><img src="../images/install/01-disk-image.webp" width="520" alt="La ventana de la imagen de disco del instalador con los cuatro pasos numerados"></p>

**2. Haz doble clic en Install HomePad.pkg.** El Mac dice que no se puede abrir. Haz clic en **OK**, no en Trasladar a la papelera.

<p align="center"><img src="../images/install/02-not-opened.webp" width="340" alt="macOS dice que «Install HomePad.pkg» no se ha abierto"></p>

**3. Permítelo en Privacidad y seguridad.** Haz doble clic en el botón azul **Abrir Privacidad y seguridad** de la ventana de la imagen de disco (o abre tú mismo Ajustes del Sistema → Privacidad y seguridad), desplázate hasta **Seguridad** y haz clic en **Abrir igualmente** junto al mensaje sobre el instalador.

<p align="center"><img src="../images/install/03-privacy-security.webp" width="480" alt="Ajustes del Sistema, Privacidad y seguridad: «Install HomePad.pkg» bloqueado, con el botón Abrir igualmente"></p>

**4. Confirma.** Haz clic en **Abrir igualmente** en el mensaje siguiente y luego usa Touch ID o escribe la contraseña del Mac.

<table align="center"><tr>
<td align="center"><img src="../images/install/04-open-anyway.webp" width="300" alt="macOS pregunta si abrir «Install HomePad.pkg»: Abrir igualmente"></td>
<td align="center"><img src="../images/install/05-password.webp" width="300" alt="macOS pide Touch ID o la contraseña de un administrador"></td>
</tr></table>

> En macOS 13 Ventura y 14 Sonoma hay un atajo: haz clic derecho en el instalador, elige **Abrir** y luego **Abrir** otra vez.

**5. Recorre el instalador.** Haz clic en **Continuar** en la introducción, en lo que te espera y en el destino (para todos los usuarios de este ordenador) y luego en **Instalar**. El Mac te pide la contraseña una vez. Cuando el instalador diga que HomePad está en tu carpeta Aplicaciones, haz clic en **Cerrar**.

<table align="center">
<tr>
<td align="center"><img src="../images/install/06-installer-welcome.webp" width="380" alt="Instalador: Te damos la bienvenida a HomePad"></td>
<td align="center"><img src="../images/install/07-installer-what-to-expect.webp" width="380" alt="Instalador: Qué esperar, los permisos que pedirá HomePad"></td>
</tr>
<tr>
<td align="center"><img src="../images/install/08-installer-destination.webp" width="380" alt="Instalador: Seleccionar un destino, instalar para todos los usuarios de este ordenador"></td>
<td align="center"><img src="../images/install/09-installer-install.webp" width="380" alt="Instalador: Instalación estándar, con el botón Instalar"></td>
</tr>
<tr>
<td align="center" colspan="2"><img src="../images/install/10-installer-summary.webp" width="380" alt="Instalador: HomePad se ha instalado"></td>
</tr>
</table>

**6. La Guía de configuración.** HomePad se abre solo con una ventana de bienvenida. Permite los tres permisos, elige cómo quieres abrir HomePad (un atajo de teclado, una doble pulsación, las esquinas activas) y haz clic en **Empezar**. Cada permiso es opcional, pero HomePad funciona mejor con los tres.

<p align="center"><img src="../images/install/11-setup-guide.webp" width="440" alt="La ventana de bienvenida de HomePad: tres permisos que permitir y cómo abrir HomePad"></p>

**7. Los permisos.** Haz clic en **Permitir…** junto a cada uno, de arriba abajo.

- **Grabación de pantalla** (vistas previas de las ventanas de una app abierta). Aparece un mensaje con un candado: haz clic en **Abrir Ajustes del Sistema**, activa el interruptor junto a **HomePad** y haz clic en **Salir y volver a abrir**. HomePad se reinicia solo y vuelve la ventana de bienvenida. Es posible que macOS pregunte una vez más si HomePad puede acceder directamente a tu pantalla: haz clic en **Permitir**.

<table align="center">
<tr>
<td align="center" valign="top"><img src="../images/install/12-screen-recording-prompt.webp" width="400" alt="macOS: «HomePad» quiere grabar la pantalla y el audio de este ordenador, con Abrir Ajustes del Sistema"></td>
<td align="center" valign="top"><img src="../images/install/12a-screen-recording-off.webp" width="400" alt="Ajustes del Sistema, Screen & System Audio Recording: el interruptor junto a HomePad, aún desactivado"></td>
</tr>
<tr>
<td align="center" valign="top"><img src="../images/install/13-screen-recording-settings.webp" width="390" alt="Ajustes del Sistema, Screen & System Audio Recording, con el mensaje Salir y volver a abrir"></td>
<td align="center" valign="top"><img src="../images/install/16-window-picker-prompt.webp" width="340" alt="macOS: HomePad pide eludir el selector de ventanas privado del sistema y acceder directamente a tu pantalla y tu audio"></td>
</tr>
</table>

- **Accesibilidad** (saltar a la ventana que elijas y el atajo de doble pulsación). Haz clic en **Permitir…**, luego en **Abrir Ajustes del Sistema** en el mensaje, y activa el interruptor junto a **HomePad** (escribe tu contraseña si te la piden). En las versiones más recientes de macOS, esta página se llama, en la interfaz en inglés, **Device Control and Data Access**.

<p align="center"><img src="../images/install/14-accessibility-settings.webp" width="480" alt="Ajustes del Sistema, Device Control and Data Access: el interruptor junto a HomePad"></p>

- **Acceso total al disco** (encontrar archivos en Documentos, Escritorio y Descargas). Haz clic en **Permitir…**; se abre Ajustes del Sistema con una ventana pequeña de HomePad al lado. Activa el interruptor junto a **HomePad**. Si no está en la lista, arrastra su icono desde la ventana pequeña a la lista.

<p align="center"><img src="../images/install/15-full-disk-access-settings.webp" width="480" alt="Ajustes del Sistema, Full Disk Access: el interruptor junto a HomePad"></p>

**8. Úsalo.** Pulsa **Opción-Espacio** (o el atajo que hayas elegido). Todo lo demás, incluidos los tres modos de arriba, está en los Ajustes: haz clic derecho en el icono de cuadrícula de la barra de menús y luego en **Ajustes…**.

## Cómo usarlo

- **Opción-Espacio** abre y cierra el panel (se cambia en Ajustes), o pulsa dos veces Control, Opción o Comando (Ajustes → Apertura; necesita el permiso de Accesibilidad).
- **Esquinas activas**: Ajustes → Apertura → esquinas activas. Haz clic en cualquiera de las cuatro esquinas de la miniatura (una, varias o todas). Deja el puntero quieto un momento en una esquina elegida y el panel se abre en esa esquina; repítelo para cerrarlo. Rozar la esquina rápidamente, o arrastrar con el botón del ratón pulsado, no hace nada. El atajo y la doble pulsación siguen abriendo en el centro. También está en el segundo paso de la Guía de configuración. Si macOS usa la misma esquina para una acción propia, HomePad te avisa, con un botón **Abrir «Esquinas activas» de macOS…** que abre Ajustes del Sistema → Escritorio y Dock con la hoja Esquinas activas ya a la vista (pulsar ese botón necesita Accesibilidad; sin ella, solo se abre la página).
- **Categorías**: las apps viven en categorías con nombre. **Esenciales** va primero y se rellena desde tu Dock la primera vez que se abre, más una categoría **Archivos** con la Papelera y Descargas, como el extremo derecho del Dock (solo la primerísima vez; si la borras, se queda borrada). Añade las tuyas (Navegadores, Escritura…) con **Añadir categoría** o con clic derecho en el espacio vacío. Una categoría nueva muestra un bloque gris «Añade tu app aquí». Haz clic derecho dentro de una categoría para renombrarla o borrarla (todo lo que contiene también se desancla; las apps y archivos en sí no se tocan).
- **Añadir archivos y carpetas**: **Añadir archivo o carpeta** (enlace de la cabecera, menú del clic derecho o Ajustes), arrástralos desde el Finder, o clic derecho en un resultado de búsqueda → Anclar. Se abren al hacer clic; las carpetas se abren en el Finder. El selector es una ventana de exploración con barra lateral (Inicio, Escritorio, Documentos, Descargas, ..., discos) y una entrada **Papelera** que ancla tu Papelera. Hacer clic en un lugar de la barra lateral (Documentos, Descargas, Papelera ...) lo abre y elige la propia carpeta, de modo que **Añadir** queda listo. Estas ventanas no bloquean el panel: aparta una y arrastra cualquiera de sus bloques al panel. Clic derecho en el bloque de la Papelera para **Vaciar «Papelera»…** (pregunta antes; HomePad le pide al Finder que la vacíe, como el Dock, así que la primera vez macOS pregunta si HomePad puede controlar el Finder).
- **Orden de las categorías**: el nombre de una categoría se pone verde al señalarlo. Púlsalo y se selecciona la fila entera (relleno y contorno verdes); arrastra y la propia fila se mueve contigo mientras las demás se apartan para dejar sitio (el panel se queda donde está). Suelta y se queda ahí. O haz clic derecho dentro de una categoría y elige **Subir** / **Bajar**. Mientras se arrastra algo, los efectos al pasar el puntero y las vistas previas de ventanas se desactivan. «Esenciales» también se puede mover; sigue siendo el lugar predeterminado para elementos nuevos y no se puede borrar. Finas líneas grises separan las categorías.
- **Clic derecho para añadir**: clic derecho en el espacio vacío dentro de una categoría (el título, o los huecos entre los bloques y después de ellos) y el menú añade a *esa* categoría: «Añadir app a Archivos…», «Añadir archivo o carpeta a Archivos…», además de Añadir categoría, Renombrar y Borrar para ella, y **Ordenar alfabéticamente** (pone los bloques de la categoría en orden alfabético por los nombres que muestran; aparece en gris cuando ya lo están; los bloques dentro de sus carpetas conservan el orden). El espacio vacío debajo de la última sección pertenece a esa sección.
- **Añadir apps**: el botón Añadir app (doble clic en una app del selector la añade y cierra el selector), clic derecho en el espacio vacío, arrastrar apps desde el Finder (pulsa el atajo a mitad del arrastre), o clic derecho en un resultado de búsqueda → Anclar app.
- **Carpetas** (como en el menú Inicio de Windows): arrastra un bloque al centro del icono de otro bloque, mantenlo ahí medio segundo hasta que ese icono se ilumine y suelta: los dos se convierten en una carpeta en ese lugar, llamada «Carpeta», cuyo bloque muestra los cuatro primeros elementos. Suelta más bloques sobre una carpeta para añadirlos. Haz clic en una carpeta para abrirla sobre el panel: clic en el nombre para renombrarla, clic en un elemento para abrirlo, arrastra elementos para reordenarlos o sacarlos de la carpeta (se cierra para que puedas soltar el elemento entre los demás bloques). Esc o un clic fuera la cierra. Una carpeta que se queda con un solo elemento vuelve a ser ese elemento. Clic derecho en una carpeta para «Renombrar carpeta…», «Mover a» y «Desagrupar»; clic derecho en un elemento de una carpeta abierta para «Quitar de la carpeta». Arrastrar sobre los bordes de un bloque (no el centro) sigue solo reordenando.
- **Quitar / reordenar**: clic derecho en un bloque → Desfijar app / Mover a, o arrastra los bloques, también entre categorías.
- **Apps abiertas**: una barra roja justo debajo de un icono (encima del nombre) significa que la app está abierta. Señala una app abierta para ver una miniatura de cada una de sus ventanas (una minimizada lleva un signo menos junto a la X de cerrar), en todos los escritorios (Spaces), en el orden de Mission Control y con el título «Space N» cuando una app tiene ventanas en más de uno, y haz clic en una para ir directo a ella (cambiando de escritorio si hace falta), o haz clic en la X de su esquina para cerrar solo esa ventana (también vale para ventanas en otros escritorios) (necesita Grabación de pantalla y Accesibilidad; sin Grabación de pantalla recibes una lista sencilla). Hacer clic en una app abierta da prioridad al escritorio actual: una ventana visible ahí trae la app al frente; si todas sus ventanas de ahí están minimizadas, vuelve la más reciente; solo cuando no hay ninguna ventana ahí te lleva a otro escritorio donde las tenga. La sección **En uso** enumera todas las apps abiertas (ancladas o no, como los indicadores de apertura del Dock); no se puede añadir ni quitar nada, pero sus bloques se pueden **arrastrar dentro de ella para reordenarlos** (por orden alfabético hasta que muevas uno; el orden se recuerda, incluso para una app que sale y vuelve a abrirse; un bloque no se puede soltar en ningún otro sitio, y Esc o soltar en otro lugar lo devuelve; clic derecho en En uso → **Ordenar alfabéticamente** olvida tu orden), y la sección en sí no se puede renombrar, pero se puede arrastrar por el título (o mover con **Subir** / **Bajar** en el menú del clic derecho) a cualquier lugar entre las categorías, y se puede ocultar (clic derecho en ella → Ocultar «En uso»; recupérala con Ajustes → Panel → Mostrar la sección «En uso»). Las **ventanas minimizadas** de cada app abierta pueden seguir a su bloque ahí, como bloques propios: una imagen de la ventana con el icono de la app en la esquina y el título de la ventana (como las muestra el Dock). Haz clic en una para traer esa ventana de vuelta; clic derecho para Restaurar o Cerrar ventana. Vienen desactivadas: actívalas en Ajustes → Panel → Mostrar ventanas minimizadas en «En uso», o con clic derecho en En uso → Mostrar ventanas minimizadas. Se reúnen cada vez que se abre el panel (necesita Accesibilidad; las imágenes necesitan Grabación de pantalla).
- **Menú de una app abierta**: clic derecho en una app abierta para un menú como el del Dock: sus ventanas (la de delante marcada; elige una para traerla al frente), los comandos «Nuevo …» de su menú Archivo (Nueva pestaña, Nueva ventana, Nueva ventana privada en un navegador), luego **Cerrar ventanas** (solo si hay una ventana abierta), **Ocultar** y **Salir** (mantén Opción para forzar la salida; una app que sigue abierta unos segundos después de Salir recibe **Forzar salida** en su lugar; el Finder no tiene Salir, como en el Dock, porque al salir se quitan los iconos del escritorio). Las ventanas y los comandos se leen con Accesibilidad cuando el puntero llega al bloque.
- **Encontrar archivos**: los archivos de Documentos, Escritorio y Descargas solo aparecen en la búsqueda cuando HomePad tiene **Acceso total al disco** (Ajustes del Sistema → Privacidad y seguridad). Hasta entonces, los resultados muestran un aviso con un enlace al interruptor.
- **Calculadora**: escribe una cuenta como `7+3`, `(2+3)*4`, `2^10` o `15%` y la respuesta aparece la primera. ↩ o el botón de copiar la copia.
- **Ventana**: arrastra cualquier borde o esquina del panel para cambiar su tamaño (los bordes tienen franjas anchas para agarrarlos y muestran cursores de cambio de tamaño), o arrastra cualquier parte vacía para moverlo (no la cuadrícula de bloques en sí, donde arrastrar reorganiza los bloques). El campo de búsqueda tiene el foco cada vez que se abre el panel, así que puedes escribir enseguida; tras hacer clic en otro sitio, la siguiente tecla que pulses vuelve a él. Ajustes → Panel tiene **Recordar el tamaño de la ventana** (activado por defecto) y **Recordar la posición de la ventana** (desactivado por defecto). El botón ↺ junto al engranaje de los ajustes devuelve el panel a su tamaño predeterminado, centrado. Las ventanas Añadir app y Añadir archivo o carpeta también se pueden redimensionar (siempre se abren con el tamaño predeterminado).
- **Tu nombre**, en la esquina inferior izquierda del panel, abre Ajustes del Sistema en tu Cuenta de Apple.
- **Búsqueda**: empieza a escribir. Primero las apps, luego documentos y carpetas, luego una búsqueda en la web. ↑ ↓ para elegir, ↩ para abrir, ⌘↩ para mostrar en el Finder, Esc para borrar y luego cerrar. El botón ‹ o un clic en el espacio vacío también te devuelve a tus apps.

## Primer arranque

Una ventana de bienvenida te pide que permitas Grabación de pantalla, Accesibilidad y Acceso total al disco y que elijas cómo abrir HomePad (consulta Instalación). Vuélvela a abrir cuando quieras desde el icono de la barra de menús → Guía de configuración…

## Ajustes

Los Ajustes tienen seis pestañas en la barra de herramientas: **Modo**, **General** (idioma, icono en la barra de menús, abrir al iniciar sesión, Restablecer valores predeterminados, Empezar de nuevo), **Barra de tareas**, **Apertura** (atajo, doble pulsación, esquinas activas), **Panel** (disposición, ventana, elementos) y **Permisos**. Se reabren en la pestaña que usaste por última vez.

- **Atajo**: haz clic en el botón y pulsa una combinación nueva. Para usar ⌘Espacio, primero desactiva el atajo de Spotlight en Ajustes del Sistema → Teclado → Funciones rápidas de teclado → Spotlight.
- **Atajo**: graba uno, elige **Ninguno** si solo quieres la doble pulsación, o **Restablecer** para volver a ⌥Espacio.
- **Icono en la barra de menús**: Ajustes → General puede ocultarlo. Volver a abrir la app abre el panel.
- **Restablecer valores predeterminados**: restaura el atajo, la doble pulsación, la disposición, ocultar el Dock y abrir al iniciar sesión (las apps y categorías se conservan).
- **Doble pulsación**: ábrelo pulsando dos veces Control, Opción o Comando.
- **Iconos por fila** (8 por defecto, 4–10), **altura de fila** (la distancia entre filas de iconos, 101 pt por defecto, 85–125) y **espacio entre iconos** (el hueco horizontal entre los iconos, 10 pt por defecto, 0–40; cuando el panel es demasiado estrecho para el hueco, primero se reduce el hueco y luego los iconos): escribe un número o haz clic en − / +, **mostrar apps abiertas**, **reimportar desde el Dock**.
- **Modo** (la primera pestaña):
  - **Independiente** (predeterminado): el panel flotante, abierto con el atajo, la doble pulsación, las esquinas activas o el icono de la barra de menús. Al pasar a él se oculta el Dock; **Ocultar «Dock»** más abajo lo recupera.
  - **HomePad + «Dock»**: un flujo como el menú Inicio de Windows, con el Dock como barra de tareas. Elegirlo siempre muestra el Dock (desactiva el ocultado automático, el de HomePad o el de Ajustes del Sistema) y añade HomePad si no está (el Dock se reinicia una vez); el Dock se queda donde lo pongas. El panel se abre justo junto al icono de HomePad (encima si el Dock está abajo, al lado si está en un lateral, siempre dentro de la pantalla) tanto si haces clic en el icono como si usas el atajo o la doble pulsación; volver a hacer clic en el icono lo cierra. Las esquinas activas siguen abriendo en su esquina. Los Ajustes explican por qué se abre en el centro cuando HomePad no está en el Dock, el Dock está oculto o falta el permiso de Accesibilidad.
  - **Barra de tareas**: una barra de tareas al estilo Windows a lo largo de la parte inferior de la pantalla principal: un botón Inicio (el icono de HomePad), luego lo que hayas anclado en ella y las apps abiertas, centrados. Las apps abiertas dejan entonces el panel. Ancla apps, archivos y carpetas con clic derecho en el espacio vacío de la barra (**Añadir app…**, **Añadir archivo o carpeta…**) o en un bloque (**Anclar a la barra de tareas**; también en el panel de HomePad). El menú de un icono de la barra también tiene **Anclar a HomePad** (o Desanclar de HomePad), para las categorías del propio HomePad. O arrastra apps, archivos y carpetas a la barra, desde el Finder o desde el panel de HomePad: se anclan antes del icono sobre el que sueltes, o al final, en el espacio vacío (uno ya anclado se mueve allí; el panel conserva los suyos). Los elementos anclados de la barra son una lista aparte, separada de las categorías de HomePad. Arrastra los iconos a lo largo de la barra para reordenarlos. Los **iconos de apps** van en el **Centro** o a la **Izquierda**; mientras están centrados, el **icono de HomePad** puede ir centrado con ellos o a la izquierda (con los iconos de apps a la izquierda siempre está allí, así que la opción aparece en gris). La izquierda es la derecha en árabe y persa, en espejo como en Windows. Con el icono de HomePad a la izquierda, su panel se abre en el borde izquierdo sobre la barra. A la derecha están **red**, **volumen**, **batería** y **reloj**, cada uno con su interruptor: red y batería abren sus páginas en Ajustes del Sistema (los menús de estado de macOS no se pueden abrir desde fuera en las versiones recientes), el volumen abre un control deslizante (desplázate sobre él para cambiar el volumen), el reloj un calendario. Haz clic en un elemento para abrirlo o traerlo al frente (u ocultarlo si ya está delante); señala una app abierta para ver sus ventanas; clic derecho para su menú. Ajustes → Barra de tareas → **Apps abiertas** (plegado al principio) enumera cada app abierta con un interruptor **Mostrar en la barra de tareas**; una app desactivada se queda fuera de la barra mientras esté abierta (también **Ocultar de la barra de tareas** en su menú). Los elementos anclados se muestran siempre. Ocultar una app (Cmd-H) no cambia la barra. El panel se abre centrado sobre la barra. El Dock queda oculto entre tanto. macOS solo deja que el Dock mantenga las ventanas fuera de una parte de la pantalla, así que, con Accesibilidad, HomePad acorta una ventana cuando se abre, cambia de tamaño, se maximiza o se coloca en mosaico de modo que llegue por debajo de la barra (y la sube, en cambio, si quedara demasiado corta). Una ventana simplemente arrastrada hasta allí se deja en paz, como en Windows. (Mantener el Dock de verdad bajo la barra no funcionó: muestra las etiquetas de nombre dondequiera que el puntero pase sobre sus iconos.) **Ocultar automáticamente la barra de tareas** la desliza fuera por la parte inferior de la pantalla hasta que el puntero descansa en el borde inferior durante el **Retraso antes de mostrarla** (0–1000 ms, 300 por defecto, para que un roce rápido del borde no la muestre); se queda visible mientras el panel de HomePad, una ventana emergente, una vista previa de ventana o un menú estén abiertos, y las ventanas usan entonces toda la pantalla. **Abrir HomePad solo desde el botón Inicio** desactiva el atajo, la doble pulsación y las esquinas activas (el icono de la barra de menús sigue funcionando).
- **Ocultar «Dock»** (solo en el modo Independiente): activa el ocultado automático del Dock con un retraso de 1000 segundos, de modo que nunca aparece. Desactivarlo restaura el Dock normal.
- **Abrir al iniciar sesión**.
- **Idioma** (Ajustes → General, o clic derecho en el icono de la barra de menús → Idioma): Igual que el Mac, o uno de los 20 idiomas (alemán, árabe, bengalí, chino (simplificado), coreano, español, filipino, francés, hindi, indonesio, inglés, italiano, japonés, persa, portugués (Brasil), ruso, tailandés, telugu, turco, vietnamita), en orden alfabético en el idioma actual. HomePad se reinicia en el nuevo idioma; el árabe y el persa se disponen de derecha a izquierda. Los nombres de apps, carpetas y secciones de Ajustes del Sistema se quedan como los muestra el Mac.

## Configurar los permisos

Cuando concedes un permiso (en la Guía de configuración, en los Ajustes o en una vista previa de ventana), HomePad vigila si lo has activado en Ajustes del Sistema y vuelve al frente en cuanto lo hagas. Grabación de pantalla y Acceso total al disco suelen necesitar reinicio: cuando Ajustes del Sistema ofrece **Salir y volver a abrir**, HomePad sale, se reinicia solo y reabre la ventana en la que estabas.

La Guía de configuración solo aparece en el primer arranque si falta algún permiso. Para recorrerla de nuevo desde el principio, usa **Ajustes → General → Empezar de nuevo…**: macOS retira los permisos de HomePad, la guía vuelve a aparecer y HomePad se reinicia (marca la casilla para olvidar también tus categorías y ajustes, como en una instalación nueva).


## Desarrollo

Las instrucciones de compilación, el funcionamiento de las traducciones, la lista de archivos y el icono de la app solo están en el [README en inglés](../../README.md#development).

## Licencia

[MIT](../../LICENSE).
