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
    <td align="center"><b>Deutsch</b></td>
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
    <td align="center"><a href="README.es.md">Español</a></td>
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

> Diese Übersetzung wurde von einer KI geschrieben und nicht von Muttersprachlern geprüft. HomePad gibt es auch in dieser Sprache; die Namen von Schaltflächen und Menüs sind hier so angegeben, wie die App sie anzeigt (die Sprache lässt sich unter Einstellungen → Allgemein → Sprache ändern). Maßgeblich ist die [englische README](../../README.md).

**Alles, was du brauchst, nur einen Tastendruck entfernt.** HomePad ist der Launcher, der deinem Mac gefehlt hat: Sortiere deine Apps in Kategorien, lege sie in Ordnern ab, hefte deine Favoriten an, durchsuche alles sofort und behalte die laufenden Apps im Blick, auf Wunsch mit einer Taskleiste im Windows-Stil.

Ein Launcher im Windows-Stil: Du drückst ein Tastenkürzel, und mitten auf dem Bildschirm erscheint ein Feld mit einer Suchleiste oben (sie durchsucht denselben Index wie Spotlight) und darunter einem Raster aus angehefteten Apps.

HomePad arbeitet in drei Modi. Wähle den passenden unter Einstellungen → Modus.

**Taskleiste.** Bildet die Windows-Taskleiste und das Startmenü nach. Wenn du das Windows-Gefühl auf dem Mac vermisst, fühlst du dich hier sofort zu Hause.

![Taskleisten-Modus: eine Taskleiste im Windows-Stil mit Start-Taste, laufenden Apps und Infobereich, darüber das Feld von HomePad](../images/mode-taskbar.webp)

**Dock + HomePad.** Für alle, die das macOS-„Dock“ behalten wollen, aber einen Launcher im Stil des Startmenüs brauchen. macOS hat zwar den Apps-Launcher, doch der ist uninspirierend: Er sortiert deine Apps automatisch in Kategorien, du kannst diese nicht selbst wählen, Apps nicht in Ordnern gruppieren, Favoriten nicht anheften und nichts nach deinen Vorstellungen anordnen. HomePad löst das alles.

![Dock-+-HomePad-Modus: das macOS-Dock, über dessen Symbol sich das Feld von HomePad öffnet](../images/mode-dock.webp)

**Eigenständig.** Für Minimalisten, die möglichst viel Bildschirmfläche wollen, ohne „Dock“ oder Taskleiste, die den Bildschirm füllen. Du rufst HomePad mit einem Tastenkürzel, einem Doppeltipp oder einem Wisch mit der Maus in eine aktive Ecke auf, sobald du es brauchst. Es erscheint in der Mitte, und du hast die volle Kontrolle über deine Lieblings-Apps, Dateien und Ordner, die Suche sowie deine laufenden Apps und ihre Fenster. Du brauchst das „Dock“ nicht, und du brauchst Spotlight nicht: Du steuerst deinen Mac von einem Ort aus. Am Anfang fühlt sich das vielleicht ungewohnt an, aber wenn du dich daran gewöhnt hast, ist es unglaublich mächtig.

![Eigenständiger Modus: kein „Dock“ und keine Taskleiste, das Feld von HomePad mitten auf dem Bildschirm](../images/mode-standalone.webp)

## Installation

HomePad ist kostenlos und nicht von Apple signiert. Deshalb hält macOS es einmal an und bittet dich zu bestätigen, dass es in Ordnung ist. Das dauert etwa fünf Minuten, und du musst es nur einmal tun. Du brauchst macOS 13 (Ventura) oder neuer; Macs mit Apple Silicon und Intel funktionieren beide. ([INSTALL.md](../../INSTALL.md) beschreibt dieselben Schritte in Worten, auch für die ZIP-Datei und das einfache Disk-Image.)

**1. Öffne das Installer-Disk-Image.** Doppelklicke auf `HomePad-Installer.dmg` (von der Person, die dir HomePad gegeben hat, oder baue es selbst: `tools/make_installer_dmg.sh`, siehe [Build and run](../../README.md#build-and-run)). Im Fenster stehen die Schritte.

<p align="center"><img src="../images/install/01-disk-image.webp" width="520" alt="Das Fenster des Installer-Disk-Images mit den vier nummerierten Schritten"></p>

**2. Doppelklicke auf Install HomePad.pkg.** Dein Mac meldet, dass es sich nicht öffnen lässt. Klicke auf **Fertig**, nicht auf „In den Papierkorb legen“.

<p align="center"><img src="../images/install/02-not-opened.webp" width="340" alt="macOS meldet: „Install HomePad.pkg“ wurde nicht geöffnet"></p>

**3. Erlaube es unter Datenschutz & Sicherheit.** Doppelklicke im Fenster des Disk-Images auf die blaue Kachel **Datenschutz & Sicherheit öffnen** (oder öffne selbst Systemeinstellungen → Datenschutz & Sicherheit), scrolle nach unten zu **Sicherheit** und klicke neben der Meldung zum Installationsprogramm auf **Dennoch öffnen**.

<p align="center"><img src="../images/install/03-privacy-security.webp" width="480" alt="Systemeinstellungen, Datenschutz & Sicherheit: „Install HomePad.pkg“ wurde blockiert, mit der Taste „Dennoch öffnen“"></p>

**4. Bestätige.** Klicke in der folgenden Meldung auf **Dennoch öffnen** und verwende dann Touch ID oder gib das Passwort deines Macs ein.

<table align="center"><tr>
<td align="center"><img src="../images/install/04-open-anyway.webp" width="300" alt="macOS fragt, ob „Install HomePad.pkg“ geöffnet werden soll: Dennoch öffnen"></td>
<td align="center"><img src="../images/install/05-password.webp" width="300" alt="macOS fragt nach Touch ID oder dem Passwort eines Administrators"></td>
</tr></table>

> Unter macOS 13 Ventura und 14 Sonoma gibt es eine Abkürzung: Klicke mit der rechten Maustaste auf das Installationsprogramm, wähle **Öffnen** und dann noch einmal **Öffnen**.

**5. Gehe den Installer durch.** Klicke auf **Fortfahren** bei der Einführung, bei „Was dich erwartet“ und beim Zielort (für alle Benutzer dieses Computers), dann auf **Installieren**. Dein Mac fragt einmal nach deinem Passwort. Wenn der Installer meldet, dass HomePad in deinem Ordner „Programme“ liegt, klicke auf **Schließen**.

<table align="center">
<tr>
<td align="center"><img src="../images/install/06-installer-welcome.webp" width="380" alt="Installer: Willkommen bei HomePad"></td>
<td align="center"><img src="../images/install/07-installer-what-to-expect.webp" width="380" alt="Installer: Was dich erwartet, die Berechtigungen, die HomePad anfordern wird"></td>
</tr>
<tr>
<td align="center"><img src="../images/install/08-installer-destination.webp" width="380" alt="Installer: Zielvolume auswählen, für alle Benutzer dieses Computers installieren"></td>
<td align="center"><img src="../images/install/09-installer-install.webp" width="380" alt="Installer: Standardinstallation, mit der Taste „Installieren“"></td>
</tr>
<tr>
<td align="center" colspan="2"><img src="../images/install/10-installer-summary.webp" width="380" alt="Installer: HomePad ist installiert"></td>
</tr>
</table>

**6. Die Einrichtungshilfe.** HomePad öffnet sich von selbst mit einem Willkommensfenster. Erlaube die drei Berechtigungen, wähle, wie du HomePad öffnen willst (Tastenkürzel, Doppeltipp, aktive Ecken), und klicke auf **Los geht’s**. Jede Berechtigung ist optional, aber HomePad funktioniert mit allen dreien am besten.

<p align="center"><img src="../images/install/11-setup-guide.webp" width="440" alt="Das Willkommensfenster von HomePad: drei Berechtigungen und die Wahl, wie HomePad geöffnet wird"></p>

**7. Die Berechtigungen.** Klicke bei jeder auf **Erlauben …**, von oben nach unten.

- **Bildschirmaufnahme** (Vorschauen der Fenster einer laufenden App). Eine Meldung mit einem Vorhängeschloss erscheint: Klicke auf **Systemeinstellungen öffnen**, schalte den Schalter neben **HomePad** ein und klicke dann auf **Beenden & erneut öffnen**. HomePad startet von selbst neu, und das Willkommensfenster kommt zurück. macOS fragt eventuell noch einmal, ob HomePad direkt auf deinen Bildschirm zugreifen darf: Klicke auf **Erlauben**.

<table align="center">
<tr>
<td align="center" valign="top"><img src="../images/install/12-screen-recording-prompt.webp" width="400" alt="macOS: „HomePad“ möchte den Bildschirm und das Audio dieses Computers aufnehmen, mit „Systemeinstellungen öffnen“"></td>
<td align="center" valign="top"><img src="../images/install/12a-screen-recording-off.webp" width="400" alt="Systemeinstellungen, Screen & System Audio Recording: der Schalter neben HomePad, noch ausgeschaltet"></td>
</tr>
<tr>
<td align="center" valign="top"><img src="../images/install/13-screen-recording-settings.webp" width="390" alt="Systemeinstellungen, Screen & System Audio Recording, mit der Meldung „Beenden & erneut öffnen“"></td>
<td align="center" valign="top"><img src="../images/install/16-window-picker-prompt.webp" width="340" alt="macOS: HomePad möchte die private Fensterauswahl des Systems umgehen und direkt auf deinen Bildschirm und das Audio zugreifen"></td>
</tr>
</table>

- **Bedienungshilfen** (Sprung zum gewählten Fenster und das Doppeltipp-Kürzel). Klicke auf **Erlauben …**, dann in der Meldung auf **Systemeinstellungen öffnen** und schalte den Schalter neben **HomePad** ein (gib dein Passwort ein, falls du danach gefragt wirst). Unter neueren macOS-Versionen heißt diese Seite in der englischen Anzeige **Device Control and Data Access**.

<p align="center"><img src="../images/install/14-accessibility-settings.webp" width="480" alt="Systemeinstellungen, Device Control and Data Access: der Schalter neben HomePad"></p>

- **Festplattenvollzugriff** (Dateien in Dokumenten, auf dem Schreibtisch und in Downloads finden). Klicke auf **Erlauben …**; die Systemeinstellungen öffnen sich mit einem kleinen HomePad-Fenster daneben. Schalte den Schalter neben **HomePad** ein. Steht es nicht in der Liste, ziehe sein Symbol aus dem kleinen Fenster in die Liste.

<p align="center"><img src="../images/install/15-full-disk-access-settings.webp" width="480" alt="Systemeinstellungen, Festplattenvollzugriff: der Schalter neben HomePad"></p>

**8. Benutze es.** Drücke **Wahl-Leertaste** (oder das Tastenkürzel, das du gewählt hast). Alles Weitere, auch die drei Modi oben, findest du in den Einstellungen: Klicke mit der rechten Maustaste auf das Rastersymbol in der Menüleiste und wähle **Einstellungen …**.

## So wird es benutzt

- **Wahl-Leertaste** öffnet und schließt das Feld (änderbar in den Einstellungen), oder tippe doppelt auf Control, Wahltaste oder Befehlstaste (Einstellungen → Öffnen; braucht die Berechtigung „Bedienungshilfen“).
- **Aktive Ecken**: Einstellungen → Öffnen → aktive Ecken. Klicke auf eine der vier Ecken des kleinen Bildschirms (eine, mehrere oder alle). Lass den Zeiger kurz in einer gewählten Ecke ruhen, und das Feld öffnet sich in dieser Ecke; tu es noch einmal, um es zu schließen. Ein kurzes Streifen der Ecke oder ein Ziehen mit gedrückter Maustaste bewirkt nichts. Tastenkürzel und Doppeltipp öffnen es weiterhin in der Mitte. Auch im zweiten Schritt der Einrichtungshilfe. Verwendet macOS dieselbe Ecke für eine eigene Aktion, weist HomePad darauf hin, mit einer Taste **„Aktive Ecken“ von macOS öffnen …**, die die Systemeinstellungen → Schreibtisch & Dock mit dem schon geöffneten Blatt „Aktive Ecken“ öffnet (für das Drücken dieser Taste sind „Bedienungshilfen“ nötig; ohne sie öffnet sich nur die Seite).
- **Kategorien**: Apps liegen in benannten Kategorien. **Wichtigste** steht an erster Stelle und wird beim ersten Start aus deinem Dock gefüllt, dazu eine Kategorie **Dateien** mit Papierkorb und Downloads, wie am rechten Ende des Docks (nur beim allerersten Start; wenn du sie löschst, bleibt sie gelöscht). Füge eigene hinzu (Browser, Schreiben …) mit **Kategorie hinzufügen** oder per Rechtsklick auf freie Fläche. Eine neue Kategorie zeigt eine ausgegraute Kachel „Leg deine App hier ab“. Klicke mit der rechten Maustaste in eine Kategorie, um sie umzubenennen oder zu löschen (alles darin wird ebenfalls gelöst; die Apps und Dateien selbst bleiben unberührt).
- **Dateien und Ordner hinzufügen**: **Datei oder Ordner hinzufügen** (Link in der Kopfzeile, Kontextmenü oder Einstellungen), ziehe sie aus dem Finder hinein oder klicke mit der rechten Maustaste auf ein Suchergebnis → Anheften. Sie öffnen sich per Klick; Ordner öffnen sich im Finder. Die Auswahl ist ein Browserfenster mit einer Seitenleiste (Benutzerordner, Schreibtisch, Dokumente, Downloads, …, Laufwerke) und einem Eintrag **Papierkorb**, der deinen Papierkorb anheftet. Ein Klick auf einen Ort in der Seitenleiste (Dokumente, Downloads, Papierkorb …) öffnet ihn und wählt den Ordner selbst, sodass **Hinzufügen** bereit ist. Diese Fenster blockieren das Feld nicht: Schiebe eines beiseite und ziehe eine beliebige Kachel daraus in das Feld. Klicke mit der rechten Maustaste auf die Papierkorb-Kachel für **„Papierkorb“ entleeren …** (es fragt vorher nach; HomePad lässt den Finder ihn entleeren, wie das Dock, deshalb fragt macOS beim ersten Mal, ob HomePad den Finder steuern darf).
- **Reihenfolge der Kategorien**: Der Name einer Kategorie wird grün, wenn du mit dem Zeiger darauf zeigst. Drücke darauf, und die ganze Reihe ist ausgewählt (grüne Füllung und Umriss); ziehe, und die Reihe selbst kommt mit, während die anderen Reihen zur Seite rutschen, um Platz zu machen (das Feld bleibt, wo es ist). Lass los, und sie bleibt dort. Oder klicke mit der rechten Maustaste in eine Kategorie und wähle **Nach oben** / **Nach unten**. Solange etwas gezogen wird, bleiben Hover-Effekte und Fenstervorschauen aus. Auch „Wichtigste“ lässt sich verschieben; sie bleibt der Standardort für neue Objekte und lässt sich nicht löschen. Dünne graue Linien trennen die Kategorien.
- **Rechtsklick zum Hinzufügen**: Klicke mit der rechten Maustaste auf freie Fläche in einer Kategorie (ihren Titel oder die Lücken zwischen und hinter ihren Kacheln), und das Menü fügt zu *dieser* Kategorie hinzu: „App hinzufügen zu Dateien …“, „Datei oder Ordner hinzufügen zu Dateien …“, dazu Kategorie hinzufügen, Umbenennen und Löschen für sie und **Alphabetisch sortieren** (ordnet die Kacheln der Kategorie alphabetisch nach den angezeigten Namen; ausgegraut, wenn sie es schon sind; die Kacheln in ihren Ordnern behalten ihre Reihenfolge). Die freie Fläche unter dem letzten Bereich gehört zu diesem Bereich.
- **Apps hinzufügen**: die Taste „App hinzufügen“ (Doppelklick auf eine App in der Auswahl fügt sie hinzu und schließt die Auswahl), Rechtsklick auf freie Fläche, Apps aus dem Finder hineinziehen (das Tastenkürzel mitten im Ziehen drücken) oder Rechtsklick auf ein Suchergebnis → App anheften.
- **Ordner** (wie im Windows-Startmenü): Ziehe eine Kachel auf die Mitte des Symbols einer anderen Kachel, halte sie eine halbe Sekunde dort, bis das Symbol aufleuchtet, und lass los: Die beiden werden an dieser Stelle zu einem Ordner namens „Ordner“, dessen Kachel die ersten vier Objekte zeigt. Lege weitere Kacheln auf einen Ordner, um sie hinzuzufügen. Klicke auf einen Ordner, um ihn über dem Feld zu öffnen: Klicke auf seinen Namen, um ihn umzubenennen, auf ein Objekt, um es zu öffnen, ziehe Objekte, um sie umzuordnen oder aus dem Ordner heraus (er schließt sich, damit du das Objekt zwischen den anderen Kacheln ablegen kannst). Esc oder ein Klick außerhalb schließt ihn. Ein Ordner mit nur einem Objekt wird wieder zu diesem Objekt. Klicke mit der rechten Maustaste auf einen Ordner für „Ordner umbenennen …“, „Bewegen nach“ und „Gruppierung aufheben“; auf ein Objekt in einem geöffneten Ordner für „Aus Ordner entfernen“. Das Ziehen über die Ränder einer Kachel (nicht ihre Mitte) ordnet weiterhin nur um.
- **Entfernen / umordnen**: Rechtsklick auf eine Kachel → App lösen / Bewegen nach, oder ziehe Kacheln umher, auch zwischen Kategorien.
- **Laufende Apps**: Ein roter Balken direkt unter einem Symbol (über seinem Namen) bedeutet, dass die App läuft. Zeige auf eine laufende App, um eine Vorschau jedes ihrer Fenster zu sehen (ein minimiertes hat ein Minus neben dem Schließkreuz), auf jedem Schreibtisch (Space), in der Reihenfolge von Mission Control und mit dem Titel „Space N“, wenn eine App Fenster auf mehr als einem hat; klicke auf eines, um direkt dorthin zu springen (bei Bedarf mit Wechsel des Schreibtischs), oder auf das Kreuz in seiner Ecke, um nur dieses Fenster zu schließen (das geht auch für Fenster auf anderen Schreibtischen) (braucht „Bildschirmaufnahme“ und „Bedienungshilfen“; ohne „Bildschirmaufnahme“ gibt es eine einfache Liste). Ein Klick auf eine laufende App stellt den aktuellen Schreibtisch an die erste Stelle: Ein dort sichtbares Fenster bringt die App nach vorn; sind ihre Fenster dort alle minimiert, kommt das jüngste zurück; nur wenn dort gar kein Fenster ist, gelangst du zu einem anderen Schreibtisch, auf dem sie Fenster hat. Der Bereich **Aktiv** listet jede App, die läuft (angeheftet oder nicht, wie die Laufanzeigen des Docks); nichts lässt sich hinzufügen oder entfernen, aber seine Kacheln lassen sich **darin umherziehen, um sie umzuordnen** (alphabetisch, bis du eine verschiebst; die Reihenfolge wird gemerkt, auch für eine App, die sich beendet und neu startet; eine Kachel lässt sich nirgendwo sonst ablegen, und Esc oder Loslassen anderswo stellt sie zurück; Rechtsklick auf „Aktiv“ → **Alphabetisch sortieren** vergisst deine Reihenfolge), und der Bereich selbst lässt sich nicht umbenennen, aber an seinem Titel an eine beliebige Stelle zwischen den Kategorien ziehen (oder mit **Nach oben** / **Nach unten** in seinem Kontextmenü verschieben) und ausblenden (Rechtsklick darauf → „Aktiv“ ausblenden; zurückholen mit Einstellungen → Feld → Bereich „Aktiv“ zeigen). Die **minimierten Fenster** jeder laufenden App können ihrer Kachel dort folgen, als eigene Kacheln: ein Bild des Fensters mit dem Symbol der App in der Ecke und dem Titel des Fensters (wie das Dock sie zeigt). Klicke auf eine, um dieses Fenster zurückzuholen; Rechtsklick für „Wiederherstellen“ oder „Fenster schließen“. Sie sind standardmäßig aus: aktiviere Einstellungen → Feld → Minimierte Fenster unter „Aktiv“ zeigen, oder Rechtsklick auf „Aktiv“ → Minimierte Fenster zeigen. Sie werden bei jedem Öffnen des Feldes gesammelt (braucht „Bedienungshilfen“; die Bilder brauchen „Bildschirmaufnahme“).
- **Menü einer laufenden App**: Klicke mit der rechten Maustaste auf eine laufende App für ein Menü wie das des Docks: ihre Fenster (das vorderste abgehakt; wähle eines, um es nach vorn zu holen), die „Neu …“-Befehle aus ihrem Menü „Ablage“ (Neuer Tab, Neues Fenster, Neues privates Fenster in einem Browser), dann **Fenster schließen** (nur wenn ein Fenster offen ist), **Ausblenden** und **Beenden** (mit gehaltener Wahltaste erzwingst du das Beenden; eine App, die einige Sekunden nach „Beenden“ noch läuft, bekommt stattdessen **Sofort beenden**; der Finder hat kein „Beenden“, wie im Dock, da sein Beenden die Schreibtischsymbole entfernt). Fenster und Befehle werden über „Bedienungshilfen“ gelesen, sobald der Zeiger die Kachel erreicht.
- **Dateien finden**: Dateien in Dokumente, auf dem Schreibtisch und in Downloads erscheinen in der Suche erst, wenn HomePad den **Festplattenvollzugriff** hat (Systemeinstellungen → Datenschutz & Sicherheit). Bis dahin zeigen die Ergebnisse einen Hinweis mit einem Link zum Schalter.
- **Rechner**: Gib eine Rechnung wie `7+3`, `(2+3)*4`, `2^10` oder `15%` ein, und die Antwort erscheint zuerst. ↩ oder die Kopieren-Taste kopiert sie.
- **Fenster**: Ziehe an einem beliebigen Rand oder einer Ecke des Feldes, um die Größe zu ändern (die Ränder haben breite Greifstreifen und zeigen Größenänderungs-Zeiger), oder ziehe an einer beliebigen freien Stelle, um es zu verschieben (nicht am Kachelraster selbst, wo Ziehen Kacheln umordnet). Das Suchfeld hat den Fokus, sobald sich das Feld öffnet, sodass du sofort tippen kannst; nachdem du anderswo geklickt hast, geht die nächste Taste, die du tippst, wieder dorthin. Einstellungen → Feld hat **Fenstergröße merken** (standardmäßig an) und **Fensterposition merken** (standardmäßig aus). Die Taste ↺ neben dem Zahnrad der Einstellungen stellt die Standardgröße des Feldes wieder her, zentriert. Auch die Fenster „App hinzufügen“ und „Datei oder Ordner hinzufügen“ lassen sich in der Größe ändern (sie öffnen sich immer in ihrer Standardgröße).
- **Dein Name** unten links im Feld öffnet die Systemeinstellungen bei deinem Apple Account.
- **Suche**: Fang einfach an zu tippen. Zuerst kommen Apps, dann Dokumente und Ordner, dann eine Websuche. ↑ ↓ zum Auswählen, ↩ zum Öffnen, ⌘↩ zum Anzeigen im Finder, Esc zum Leeren und dann Schließen. Auch die Taste ‹ oder ein Klick auf freie Fläche führt zurück zu deinen Apps.

## Erster Start

Ein Willkommensfenster bittet dich, „Bildschirmaufnahme“, „Bedienungshilfen“ und „Festplattenvollzugriff“ zu erlauben und zu wählen, wie HomePad geöffnet wird (siehe Installation). Öffne es jederzeit wieder über das Menüleistensymbol → Einrichtungshilfe …

## Einstellungen

Die Einstellungen haben sechs Tabs in der Symbolleiste: **Modus**, **Allgemein** (Sprache, Symbol in der Menüleiste, Bei Anmeldung starten, Auf Standard zurücksetzen, Neu beginnen), **Taskleiste**, **Öffnen** (Tastenkürzel, Doppeltipp, aktive Ecken), **Feld** (Layout, Fenster, Objekte) und **Berechtigungen**. Sie öffnen sich auf dem zuletzt benutzten Tab.

- **Tastenkürzel**: Klicke auf die Taste und drücke eine neue Kombination. Um ⌘Leertaste zu verwenden, schalte zuerst das Spotlight-Kürzel in Systemeinstellungen → Tastatur → Tastaturkurzbefehle → Spotlight aus.
- **Tastenkürzel**: Zeichne eines auf, wähle **Keins**, wenn du nur den Doppeltipp willst, oder setze es mit **Zurücksetzen** auf ⌥Leertaste zurück.
- **Symbol in der Menüleiste**: Einstellungen → Allgemein kann es ausblenden. Ein erneuter Start der App öffnet das Feld.
- **Auf Standard zurücksetzen**: stellt Tastenkürzel, Doppeltipp, Layout, das Ausblenden des Docks und „Bei Anmeldung starten“ wieder her (Apps und Kategorien bleiben erhalten).
- **Doppeltipp**: öffnen durch zweimaliges Tippen auf Control, Wahltaste oder Befehlstaste.
- **Symbole pro Reihe** (standardmäßig 8, 4–10), **Zeilenhöhe** (der Abstand zwischen den Symbolreihen, standardmäßig 101 pt, 85–125) und **Symbolabstand** (der waagerechte Abstand zwischen Symbolen, standardmäßig 10 pt, 0–40; ist das Feld für den Abstand zu schmal, schrumpft zuerst der Abstand, dann die Symbole): gib eine Zahl ein oder klicke auf − / +, **laufende Apps zeigen**, **Dock neu importieren**.
- **Modus** (der erste Tab):
  - **Eigenständig** (Standard): das schwebende Feld, geöffnet per Tastenkürzel, Doppeltipp, aktive Ecken oder das Menüleistensymbol. Beim Wechsel dorthin wird das Dock ausgeblendet; **„Dock“ ausblenden** weiter unten bringt es zurück.
  - **HomePad + „Dock“**: ein Startmenü-Ablauf wie unter Windows mit dem Dock als Taskleiste. Wählst du ihn, wird das Dock immer angezeigt (er schaltet das automatische Ausblenden aus, das von HomePad oder das der Systemeinstellungen) und HomePad wird hinzugefügt, falls es dort fehlt (das Dock startet einmal neu); das Dock bleibt, wo du es hingestellt hast. Das Feld öffnet sich direkt am Symbol von HomePad (darüber bei einem Dock unten, daneben bei einem Dock an der Seite, auf dem Bildschirm gehalten), egal ob du auf das Symbol klickst oder Tastenkürzel oder Doppeltipp benutzt; ein erneuter Klick auf das Symbol schließt es. Aktive Ecken öffnen es weiterhin in ihrer Ecke. Die Einstellungen sagen, warum es in der Mitte öffnet, wenn HomePad nicht im Dock ist, das Dock ausgeblendet ist oder die Berechtigung „Bedienungshilfen“ fehlt.
  - **Taskleiste**: eine Taskleiste im Windows-Stil am unteren Rand des Hauptbildschirms: eine Start-Taste (das Symbol von HomePad), dann das, was du daran angeheftet hast, und die laufenden Apps, zentriert. Die laufenden Apps verlassen dann das Feld. Hefte Apps, Dateien und Ordner an, indem du mit der rechten Maustaste auf die freie Fläche der Taskleiste klickst (**App hinzufügen …**, **Datei oder Ordner hinzufügen …**) oder auf eine Kachel (**An Taskleiste anheften**; auch im Feld von HomePad). Das Menü eines Taskleistensymbols hat außerdem **An HomePad anheften** (oder Von HomePad lösen) für die eigenen Kategorien von HomePad. Oder ziehe Apps, Dateien und Ordner auf die Taskleiste, aus dem Finder oder aus dem Feld von HomePad: Sie werden vor dem Symbol angeheftet, auf dem du loslässt, oder auf freier Fläche am Ende (eine schon angeheftete wandert dorthin; das Feld behält seine eigenen). Die Anheftungen der Taskleiste sind eine eigene Liste, getrennt von den Kategorien von HomePad. Ziehe Symbole an der Taskleiste entlang, um sie umzuordnen. **App-Symbole** stehen in der **Mitte** oder **Links**; solange sie zentriert sind, kann das **HomePad-Symbol** mit ihnen zentriert oder links stehen (stehen die App-Symbole links, ist es immer dort, daher ist die Auswahl ausgegraut). Links ist rechts auf Arabisch und Persisch, gespiegelt wie unter Windows. Steht das Symbol von HomePad links, öffnet sich sein Feld am linken Rand über der Taskleiste. Rechts sind **Netzwerk**, **Lautstärke**, **Batterie** und **Uhr**, jeweils mit einem Schalter: Netzwerk und Batterie öffnen ihre Seiten in den Systemeinstellungen (die eigenen Statusmenüs von macOS lassen sich unter neueren macOS-Versionen von außen nicht öffnen), die Lautstärke öffnet einen Regler (scrolle darüber, um sie zu ändern), die Uhr einen Kalender. Klicke auf ein Objekt, um es zu öffnen oder nach vorn zu holen (oder auszublenden, wenn es schon vorn ist); zeige auf eine laufende App für ihre Fenster; Rechtsklick für ihr Menü. Einstellungen → Taskleiste → **Laufende Apps** (anfangs eingeklappt) listet jede laufende App mit einem Schalter **In Taskleiste zeigen**; eine ausgeschaltete App bleibt von der Taskleiste fern, solange sie läuft (auch **In Taskleiste ausblenden** in ihrem Menü). Angeheftete Objekte werden immer gezeigt. Das Ausblenden einer App (Cmd-H) ändert die Taskleiste nicht. Das Feld öffnet sich zentriert über der Taskleiste. Das Dock ist währenddessen ausgeblendet. macOS lässt nur das Dock einen Teil des Bildschirms für Fenster freihalten, deshalb macht HomePad mit „Bedienungshilfen“ ein Fenster kürzer, wenn es geöffnet, in der Größe geändert, maximiert oder gekachelt wird und unter die Taskleiste reicht (stattdessen nach oben verschoben, wenn es zu kurz würde). Ein Fenster, das nur dorthin gezogen wird, bleibt wie unter Windows unangetastet. (Das echte Dock unter der Taskleiste zu behalten, ging nicht: Es zeigt seine Namensschilder, wo immer der Zeiger über seine Symbole fährt.) **Taskleiste automatisch ausblenden** schiebt sie unten vom Bildschirm weg, bis der Zeiger für die **Verzögerung bis zum Einblenden** am unteren Rand ruht (0–1000 ms, standardmäßig 300, damit ein kurzes Vorbeifahren am Rand sie nicht zeigt); sie bleibt oben, solange das Feld von HomePad, ein Pop-up, eine Fenstervorschau oder ein Menü offen ist, und Fenster nutzen dann den ganzen Bildschirm. **HomePad nur über die Start-Taste öffnen** schaltet Tastenkürzel, Doppeltipp und aktive Ecken aus (das Menüleistensymbol funktioniert weiter).
- **„Dock“ ausblenden** (nur im Modus „Eigenständig“): schaltet das automatische Ausblenden des Docks mit einer Verzögerung von 1000 Sekunden ein, sodass es nie erscheint. Ausschalten stellt das normale Dock wieder her.
- **Bei Anmeldung starten**.
- **Sprache** (Einstellungen → Allgemein oder Rechtsklick auf das Menüleistensymbol → Sprache): Wie auf dem Mac oder eine von 20 Sprachen (Arabisch, Bengalisch, Chinesisch (vereinfacht), Englisch, Filipino, Französisch, Deutsch, Hindi, Indonesisch, Italienisch, Japanisch, Koreanisch, Persisch, Portugiesisch (Brasilien), Russisch, Spanisch, Telugu, Thai, Türkisch, Vietnamesisch), alphabetisch in der aktuellen Sprache aufgelistet. HomePad startet in der neuen neu; Arabisch und Persisch werden von rechts nach links gesetzt. Namen von Apps, Ordnern und Bereichen der Systemeinstellungen bleiben so, wie der Mac sie zeigt.

## Berechtigungen einrichten

Wenn du eine Berechtigung erlaubst (in der Einrichtungshilfe, den Einstellungen oder einer Fenstervorschau), wartet HomePad darauf, dass sie in den Systemeinstellungen eingeschaltet wird, und kommt wieder nach vorn, sobald das geschehen ist. „Bildschirmaufnahme“ und „Festplattenvollzugriff“ brauchen meist einen Neustart: Bietet dir die Systemeinstellungen **Beenden & erneut öffnen** an, beendet sich HomePad, startet von selbst wieder und öffnet das Fenster, in dem du warst.

Die Einrichtungshilfe erscheint beim ersten Start nur, wenn eine Berechtigung fehlt. Um sie noch einmal ganz von vorn zu durchlaufen, wähle **Einstellungen → Allgemein → Neu beginnen …**: macOS nimmt die Berechtigungen von HomePad zurück, die Hilfe erscheint wieder, und HomePad startet neu (hake das Kästchen an, um auch deine Kategorien und Einstellungen zu vergessen, wie bei einer frischen Installation).


## Entwicklung

Hinweise zum Bauen der App, zur Funktionsweise der Übersetzungen, die Dateiliste und das App-Symbol stehen nur in der [englischen README](../../README.md#development).

## Lizenz

[MIT](../../LICENSE).
