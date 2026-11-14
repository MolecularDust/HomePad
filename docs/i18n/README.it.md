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
    <td align="center"><b>Italiano</b></td>
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

> Questa traduzione è stata scritta da un’IA e non è stata rivista da madrelingua. HomePad esiste anche in questa lingua; i nomi di pulsanti e menu sono indicati qui come li mostra l’app (la lingua si cambia in Impostazioni → Generali → Lingua). Fa fede il [README inglese](../../README.md).

**Tutto ciò che usi, a un tasto di distanza.** HomePad è il launcher che mancava al tuo Mac: ordina le app in categorie, mettile in cartelle, aggiungi i preferiti, cerca tutto all’istante e tieni sott’occhio le app aperte, con una barra delle applicazioni in stile Windows se la vuoi.

Un launcher in stile Windows: premi un’abbreviazione e al centro dello schermo compare un pannello con una barra di ricerca in alto (che cerca nello stesso indice usato da Spotlight) e una griglia di app aggiunte in basso.

HomePad funziona in tre modalità. Scegli quella che fa per te in Impostazioni → Modalità.

**Barra delle applicazioni.** Imita la barra delle applicazioni e il menu Start di Windows. Se ti manca l’esperienza di Windows su macOS, ti sentirai a casa.

![Modalità Barra delle applicazioni: una barra in stile Windows con pulsante Start, app aperte e area di notifica, con il pannello di HomePad sopra](../images/mode-taskbar.webp)

**Dock + HomePad.** Per chi vuole tenere il “Dock” di macOS ma ha bisogno di un launcher in stile menu Start. macOS ha il launcher App, ma è poco stimolante: ordina le tue app in categorie in automatico, e non puoi sceglierle, né raggruppare le app in cartelle, né aggiungere i preferiti, né organizzarlo a modo tuo. HomePad risolve tutto questo.

![Modalità Dock + HomePad: il Dock di macOS, con il pannello di HomePad che si apre sopra la sua icona](../images/mode-dock.webp)

**Autonoma.** Per i minimalisti che vogliono il massimo spazio sullo schermo, senza “Dock” né barra delle applicazioni a ingombrarlo. Richiami HomePad con un’abbreviazione da tastiera, un doppio tocco o un colpo di mouse verso un angolo attivo, ogni volta che ti serve. Compare al centro, e hai il pieno controllo delle tue app, file e cartelle preferiti, della ricerca, e delle app aperte e delle loro finestre. Non ti servono il “Dock” né Spotlight: controlli il tuo Mac da un unico posto. All’inizio può sembrare strano, ma diventa incredibilmente potente una volta presa la mano.

![Modalità Autonoma: niente “Dock” né barra delle applicazioni, il pannello di HomePad al centro dello schermo](../images/mode-standalone.webp)

## Installazione

HomePad è gratuito e non è firmato da Apple, quindi macOS lo blocca una volta e ti chiede di confermare che va bene. Richiede circa cinque minuti, una sola volta. Ti serve macOS 13 (Ventura) o successivo; funzionano sia i Mac con Apple silicon sia quelli Intel. ([INSTALL.md](../../INSTALL.md) ha gli stessi passaggi a parole, anche per lo zip e per la semplice immagine disco.)

**1. Apri l’immagine disco del programma di installazione.** Fai doppio clic su `HomePad-Installer.dmg` (da chi ti ha condiviso HomePad, oppure compilalo tu: `tools/make_installer_dmg.sh`, vedi [Build and run](../../README.md#build-and-run)). La sua finestra elenca i passaggi.

<p align="center"><img src="../images/install/01-disk-image.webp" width="520" alt="La finestra dell’immagine disco del programma di installazione con i quattro passaggi numerati"></p>

**2. Fai doppio clic su Install HomePad.pkg.** Il Mac dice che non può aprirlo. Fai clic su **Fine**, non su Sposta nel Cestino.

<p align="center"><img src="../images/install/02-not-opened.webp" width="340" alt="macOS dice che “Install HomePad.pkg” non è stato aperto"></p>

**3. Consentilo in Privacy e sicurezza.** Fai doppio clic sul riquadro blu **Apri Privacy e sicurezza** nella finestra dell’immagine disco (oppure apri tu stesso Impostazioni di Sistema → Privacy e sicurezza), scorri fino a **Sicurezza** e fai clic su **Apri comunque** accanto al messaggio sul programma di installazione.

<p align="center"><img src="../images/install/03-privacy-security.webp" width="480" alt="Impostazioni di Sistema, Privacy e sicurezza: “Install HomePad.pkg” è stato bloccato, con il pulsante Apri comunque"></p>

**4. Conferma.** Fai clic su **Apri comunque** nel messaggio successivo, poi usa Touch ID o inserisci la password del Mac.

<table align="center"><tr>
<td align="center"><img src="../images/install/04-open-anyway.webp" width="300" alt="macOS chiede se aprire “Install HomePad.pkg”: Apri comunque"></td>
<td align="center"><img src="../images/install/05-password.webp" width="300" alt="macOS chiede Touch ID o la password di un amministratore"></td>
</tr></table>

> Su macOS 13 Ventura e 14 Sonoma c’è una scorciatoia: clic destro sul programma di installazione, scegli **Apri**, poi di nuovo **Apri**.

**5. Percorri il programma di installazione.** Fai clic su **Continua** all’introduzione, a “Cosa aspettarsi” e alla destinazione (per tutti gli utenti di questo computer), poi su **Installa**. Il Mac ti chiede la password una volta. Quando il programma dice che HomePad è nella cartella Applicazioni, fai clic su **Chiudi**.

<table align="center">
<tr>
<td align="center"><img src="../images/install/06-installer-welcome.webp" width="380" alt="Programma di installazione: Benvenuto in HomePad"></td>
<td align="center"><img src="../images/install/07-installer-what-to-expect.webp" width="380" alt="Programma di installazione: Cosa aspettarsi, i permessi che HomePad chiederà"></td>
</tr>
<tr>
<td align="center"><img src="../images/install/08-installer-destination.webp" width="380" alt="Programma di installazione: Seleziona destinazione, installa per tutti gli utenti di questo computer"></td>
<td align="center"><img src="../images/install/09-installer-install.webp" width="380" alt="Programma di installazione: Installazione standard, con il pulsante Installa"></td>
</tr>
<tr>
<td align="center" colspan="2"><img src="../images/install/10-installer-summary.webp" width="380" alt="Programma di installazione: HomePad è installato"></td>
</tr>
</table>

**6. La Guida alla configurazione.** HomePad si apre da solo con una finestra di benvenuto. Consenti i tre permessi, scegli come vuoi aprire HomePad (un’abbreviazione da tastiera, un doppio tocco, gli angoli attivi) e fai clic su **Inizia**. Ogni permesso è facoltativo, ma HomePad funziona al meglio con tutti e tre.

<p align="center"><img src="../images/install/11-setup-guide.webp" width="440" alt="La finestra di benvenuto di HomePad: tre permessi da consentire, e come aprire HomePad"></p>

**7. I permessi.** Fai clic su **Consenti…** accanto a ciascuno, dall’alto in basso.

- **Registrazione schermo** (anteprime delle finestre di un’app aperta). Compare un messaggio con un lucchetto: fai clic su **Apri Impostazioni di Sistema**, attiva l’interruttore accanto a **HomePad**, poi fai clic su **Esci e riapri**. HomePad si riavvia da solo e la finestra di benvenuto torna. macOS può chiedere ancora una volta se consentire a HomePad di accedere direttamente allo schermo: fai clic su **Consenti**.

<table align="center">
<tr>
<td align="center" valign="top"><img src="../images/install/12-screen-recording-prompt.webp" width="400" alt="macOS: “HomePad” vorrebbe registrare lo schermo e l’audio di questo computer, con Apri Impostazioni di Sistema"></td>
<td align="center" valign="top"><img src="../images/install/12a-screen-recording-off.webp" width="400" alt="Impostazioni di Sistema, Screen & System Audio Recording: l’interruttore accanto a HomePad, ancora disattivato"></td>
</tr>
<tr>
<td align="center" valign="top"><img src="../images/install/13-screen-recording-settings.webp" width="390" alt="Impostazioni di Sistema, Screen & System Audio Recording, con il messaggio Esci e riapri"></td>
<td align="center" valign="top"><img src="../images/install/16-window-picker-prompt.webp" width="340" alt="macOS: HomePad chiede di aggirare il selettore privato di finestre del sistema e di accedere direttamente a schermo e audio"></td>
</tr>
</table>

- **Accessibilità** (saltare alla finestra che scegli, e l’abbreviazione a doppio tocco). Fai clic su **Consenti…**, poi su **Apri Impostazioni di Sistema** nel messaggio, e attiva l’interruttore accanto a **HomePad** (inserisci la password se richiesta). Nei macOS recenti questa pagina si chiama, nell’interfaccia in inglese, **Device Control and Data Access**.

<p align="center"><img src="../images/install/14-accessibility-settings.webp" width="480" alt="Impostazioni di Sistema, Device Control and Data Access: l’interruttore accanto a HomePad"></p>

- **Accesso completo al disco** (trovare file in Documenti, Scrivania e Download). Fai clic su **Consenti…**; si aprono le Impostazioni di Sistema con una piccola finestra di HomePad accanto. Attiva l’interruttore accanto a **HomePad**. Se non è nell’elenco, trascina la sua icona dalla piccola finestra nell’elenco.

<p align="center"><img src="../images/install/15-full-disk-access-settings.webp" width="480" alt="Impostazioni di Sistema, Full Disk Access: l’interruttore accanto a HomePad"></p>

**8. Usalo.** Premi **Opzione-Spazio** (o l’abbreviazione che hai scelto). Tutto il resto, comprese le tre modalità qui sopra, è nelle Impostazioni: fai clic destro sull’icona a griglia nella barra dei menu, poi su **Impostazioni…**.

## Come si usa

- **Opzione-Spazio** apre e chiude il pannello (cambiala nelle Impostazioni), oppure tocca due volte Control, Opzione o Comando (Impostazioni → Apertura; richiede il permesso Accessibilità).
- **Angoli attivi**: Impostazioni → Apertura → angoli attivi. Fai clic su uno qualsiasi dei quattro angoli del piccolo schermo (uno, più d’uno o tutti). Tieni fermo il puntatore per un attimo in un angolo scelto e il pannello si apre in quell’angolo; rifallo per chiuderlo. Sfiorare l’angolo al volo, o trascinare tenendo premuto il pulsante del mouse, non fa nulla. L’abbreviazione e il doppio tocco lo aprono ancora al centro. C’è anche nel secondo passaggio della Guida alla configurazione. Se macOS usa lo stesso angolo per una sua azione, HomePad lo segnala, con un pulsante **Apri “Angoli attivi” di macOS…** che apre Impostazioni di Sistema → Scrivania e Dock con il pannello Angoli attivi già visibile (premere quel pulsante richiede Accessibilità; senza, si apre solo la pagina).
- **Categorie**: le app stanno in categorie con un nome. **Essenziali** viene per prima ed è riempita dal tuo Dock al primo avvio, più una categoria **File** con il Cestino e Download, come l’estremità destra del Dock (solo al primissimo avvio; se la elimini, resta eliminata). Aggiungi le tue (Browser, Scrittura…) con **Aggiungi categoria** o con un clic destro sullo spazio vuoto. Una nuova categoria mostra un riquadro grigio “Aggiungi qui la tua app”. Fai clic destro dentro una categoria per rinominarla o eliminarla (anche tutto ciò che contiene viene staccato; le app e i file in sé non vengono toccati).
- **Aggiungere file e cartelle**: **Aggiungi file o cartella** (link nell’intestazione, menu del clic destro o Impostazioni), trascinali dal Finder, oppure fai clic destro su un risultato di ricerca → Aggiungi. Si aprono con un clic; le cartelle si aprono nel Finder. Il selettore è una finestra di navigazione con una barra laterale (Home, Scrivania, Documenti, Download, ..., dischi) e una voce **Cestino** che aggiunge il tuo Cestino. Fare clic su un luogo nella barra laterale (Documenti, Download, Cestino ...) lo apre e sceglie la cartella da sé, così **Aggiungi** è pronto. Queste finestre non bloccano il pannello: spostane una da parte e trascina un riquadro qualsiasi al suo interno nel pannello. Fai clic destro sul riquadro del Cestino per **Svuota “Cestino”…** (chiede prima; HomePad fa svuotare il Cestino al Finder, come il Dock, quindi la prima volta macOS chiede se HomePad può controllare il Finder).
- **Ordine delle categorie**: il nome di una categoria diventa verde quando ci punti sopra. Premilo e l’intera riga è selezionata (riempimento e contorno verdi); trascina e la riga stessa si muove mentre le altre righe si spostano di lato per fare spazio (il pannello resta dov’è). Rilascia e resta dove si trova. Oppure fai clic destro dentro una categoria e scegli **Sposta su** / **Sposta giù**. Mentre si trascina qualcosa, gli effetti al passaggio e le anteprime delle finestre restano spenti. Anche “Essenziali” si può spostare; resta il posto predefinito per i nuovi elementi e non si può eliminare. Sottili linee grigie separano le categorie.
- **Clic destro per aggiungere**: fai clic destro sullo spazio vuoto dentro una categoria (il suo titolo, o gli spazi tra i riquadri e dopo di essi) e il menu aggiunge a *quella* categoria: “Aggiungi app a File…”, “Aggiungi file o cartella a File…”, più Aggiungi categoria, Rinomina ed Elimina per essa, e **Ordina alfabeticamente** (mette i riquadri di quella categoria in ordine alfabetico secondo i nomi che mostrano; in grigio quando lo sono già; i riquadri nelle sue cartelle mantengono il loro ordine). Lo spazio vuoto sotto l’ultima sezione appartiene a quella sezione.
- **Aggiungere app**: il pulsante Aggiungi app (fai doppio clic su un’app nel selettore per aggiungerla e chiuderlo), clic destro sullo spazio vuoto, trascinare le app dal Finder (premi l’abbreviazione a metà trascinamento), oppure clic destro su un risultato di ricerca → Aggiungi app.
- **Cartelle** (come nel menu Start di Windows): trascina un riquadro sul centro dell’icona di un altro riquadro, tienilo lì per mezzo secondo finché quell’icona si illumina, poi rilascia: i due diventano una cartella in quel punto, chiamata “Cartella”, il cui riquadro mostra i primi quattro elementi. Lascia cadere altri riquadri su una cartella per aggiungerli. Fai clic su una cartella per aprirla sopra il pannello: fai clic sul suo nome per rinominarla, su un elemento per aprirlo, trascina gli elementi per riordinarli o fuori dalla cartella (si chiude così puoi lasciare l’elemento tra gli altri riquadri). Esc o un clic fuori la chiude. Una cartella rimasta con un solo elemento torna a essere quell’elemento. Fai clic destro su una cartella per “Rinomina cartella…”, “Sposta in” e “Separa”; fai clic destro su un elemento in una cartella aperta per “Rimuovi dalla cartella”. Trascinare sui bordi di un riquadro (non sul centro) riordina soltanto.
- **Rimuovere / riordinare**: clic destro su un riquadro → Stacca app / Sposta in, oppure trascina i riquadri, anche tra le categorie.
- **App aperte**: una barra rossa subito sotto un’icona (sopra il suo nome) significa che l’app è aperta. Punta un’app aperta per vedere una miniatura di ciascuna delle sue finestre (una ridotta ha un meno accanto alla croce di chiusura), su ogni scrivania (Space), elencate nell’ordine di Mission Control con il titolo “Space N” quando un’app ha finestre su più di una, e fai clic su una per andarci direttamente (cambiando scrivania se serve), oppure fai clic sulla croce nel suo angolo per chiudere solo quella finestra (vale anche per le finestre su altre scrivanie) (richiede Registrazione schermo e Accessibilità; senza Registrazione schermo ottieni un elenco semplice). Fare clic su un’app aperta mette prima la scrivania attuale: una finestra visibile lì porta l’app in primo piano; se le sue finestre lì sono tutte ridotte, torna la più recente; solo se lì non c’è alcuna finestra ti porta su un’altra scrivania dove ne ha. La sezione **In uso** elenca ogni app aperta (aggiunta o no, come gli indicatori di apertura del Dock); non si può aggiungere né togliere nulla, ma i suoi riquadri si possono **trascinare al suo interno per riordinarli** (in ordine alfabetico finché non ne sposti uno; l’ordine viene ricordato, anche per un’app che esce e riparte; un riquadro non si può lasciare altrove, ed Esc o rilasciare altrove lo rimette a posto; clic destro su In uso → **Ordina alfabeticamente** dimentica il tuo ordine), e la sezione stessa non si può rinominare ma si può trascinare dal titolo (o spostare con **Sposta su** / **Sposta giù** nel suo menu del clic destro) in qualsiasi punto tra le categorie, e si può nascondere (clic destro → Nascondi “In uso”; riportala con Impostazioni → Pannello → Mostra la sezione “In uso”). Le **finestre ridotte** di ogni app aperta possono seguire il suo riquadro lì, come riquadri a sé: un’immagine della finestra con l’icona dell’app nell’angolo e il titolo della finestra (come li mostra il Dock). Fai clic su una per riportare quella finestra; clic destro per Ripristina o Chiudi finestra. Sono disattivate per impostazione predefinita: attiva Impostazioni → Pannello → Mostra le finestre ridotte in “In uso”, oppure clic destro su In uso → Mostra finestre ridotte. Vengono raccolte ogni volta che il pannello si apre (richiede Accessibilità; le immagini richiedono Registrazione schermo).
- **Menu di un’app aperta**: fai clic destro su un’app aperta per un menu simile a quello del Dock: le sue finestre (quella in primo piano spuntata; sceglierne una la porta in primo piano), i comandi “Nuovo …” del suo menu File (Nuova scheda, Nuova finestra, Nuova finestra privata in un browser), poi **Chiudi finestre** (solo se ha una finestra aperta), **Nascondi** ed **Esci** (tieni premuto Opzione per forzare l’uscita; un’app ancora aperta alcuni secondi dopo Esci riceve **Forza uscita** al suo posto; il Finder non ha Esci, come nel Dock, perché chiuderlo rimuove le icone della scrivania). Finestre e comandi vengono letti tramite Accessibilità quando il puntatore raggiunge il riquadro.
- **Trovare file**: i file in Documenti, Scrivania e Download compaiono nella ricerca solo quando HomePad ha l’**Accesso completo al disco** (Impostazioni di Sistema → Privacy e sicurezza). Fino ad allora i risultati mostrano un avviso con un link all’interruttore.
- **Calcolatrice**: scrivi un calcolo come `7+3`, `(2+3)*4`, `2^10` o `15%` e la risposta compare per prima. ↩ o il pulsante di copia la copia.
- **Finestra**: trascina un bordo o un angolo qualsiasi del pannello per ridimensionarlo (i bordi hanno ampie fasce di presa e mostrano i cursori di ridimensionamento), oppure trascina una qualsiasi parte vuota per spostarlo (non la griglia dei riquadri stessa, dove trascinare riordina i riquadri). Il campo di ricerca ha il focus ogni volta che il pannello si apre, quindi puoi scrivere subito; dopo che hai fatto clic altrove, il tasto successivo che digiti torna lì. In Impostazioni → Pannello ci sono **Ricorda le dimensioni della finestra** (attivo per impostazione predefinita) e **Ricorda la posizione della finestra** (disattivo per impostazione predefinita). Il pulsante ↺ accanto all’ingranaggio delle impostazioni riporta il pannello alle dimensioni standard, centrato. Anche le finestre Aggiungi app e Aggiungi file o cartella si possono ridimensionare (si aprono sempre alle dimensioni standard).
- Il **tuo nome** nell’angolo in basso a sinistra del pannello apre Impostazioni di Sistema sul tuo Account Apple.
- **Ricerca**: inizia semplicemente a scrivere. Prima le app, poi documenti e cartelle, poi una ricerca sul web. ↑ ↓ per scegliere, ↩ per aprire, ⌘↩ per mostrare nel Finder, Esc per cancellare e poi chiudere. Anche il pulsante ‹ o un clic sullo spazio vuoto riporta alle tue app.

## Primo avvio

Una finestra di benvenuto ti chiede di consentire Registrazione schermo, Accessibilità e Accesso completo al disco e di scegliere come aprire HomePad (vedi Installazione). Riaprila in qualsiasi momento dall’icona nella barra dei menu → Guida alla configurazione…

## Impostazioni

Le Impostazioni hanno sei schede nella barra degli strumenti: **Modalità**, **Generali** (lingua, icona nella barra dei menu, apri al login, Ripristina impostazioni predefinite, Ricomincia), **Barra delle applicazioni**, **Apertura** (abbreviazione, doppio tocco, angoli attivi), **Pannello** (layout, finestra, elementi) e **Permessi**. Si riaprono sulla scheda usata per ultima.

- **Abbreviazione**: fai clic sul pulsante e premi una nuova combinazione. Per usare ⌘Spazio, disattiva prima l’abbreviazione di Spotlight in Impostazioni di Sistema → Tastiera → Abbreviazioni da tastiera → Spotlight.
- **Abbreviazione**: registrane una, scegli **Nessuna** se vuoi solo il doppio tocco, oppure **Ripristina** per riportarla a ⌥Spazio.
- **Icona nella barra dei menu**: Impostazioni → Generali può nasconderla. Riavviare l’app apre il pannello.
- **Ripristina impostazioni predefinite**: ripristina abbreviazione, doppio tocco, layout, nascondere il Dock e apri al login (app e categorie vengono mantenute).
- **Doppio tocco**: apri toccando due volte Control, Opzione o Comando.
- **Icone per riga** (8 per impostazione predefinita, 4–10) e **altezza riga** (la distanza tra le righe di icone, 101 pt per impostazione predefinita, 85–125) e **spaziatura icone** (lo spazio orizzontale tra le icone, 10 pt per impostazione predefinita, 0–40; quando il pannello è troppo stretto per lo spazio, si riduce prima lo spazio, poi le icone): digita un numero o fai clic su − / +, **mostra le app aperte**, **reimporta dal Dock**.
- **Modalità** (la prima scheda):
  - **Autonoma** (predefinita): il pannello fluttuante, aperto dall’abbreviazione, dal doppio tocco, dagli angoli attivi o dall’icona nella barra dei menu. Passare a essa nasconde il Dock; **Nascondi “Dock”** qui sotto lo riporta.
  - **HomePad + “Dock”**: un flusso come il menu Start di Windows con il Dock come barra delle applicazioni. Sceglierla mostra sempre il Dock (disattiva l’auto-nascondimento, di HomePad o di Impostazioni di Sistema) e vi aggiunge HomePad se non c’è (il Dock si riavvia una volta); il Dock resta dove l’hai messo. Il pannello si apre proprio accanto all’icona di HomePad (sopra per un Dock in basso, a fianco per un Dock laterale, mantenuto sullo schermo) sia che tu faccia clic sull’icona sia che usi l’abbreviazione o il doppio tocco; fare di nuovo clic sull’icona lo chiude. Gli angoli attivi lo aprono ancora nel loro angolo. Le Impostazioni dicono perché si apre al centro quando HomePad non è nel Dock, il Dock è nascosto o manca il permesso Accessibilità.
  - **Barra delle applicazioni**: una barra in stile Windows lungo il fondo dello schermo principale: un pulsante Start (l’icona di HomePad), poi ciò che vi hai aggiunto e le app aperte, al centro. Le app aperte lasciano allora il pannello. Aggiungi app, file e cartelle con un clic destro sullo spazio vuoto della barra (**Aggiungi app…**, **Aggiungi file o cartella…**) o su un riquadro (**Aggiungi alla barra delle applicazioni**; anche nel pannello di HomePad). Il menu di un’icona della barra ha anche **Aggiungi a HomePad** (o Rimuovi da HomePad), per le categorie di HomePad. Oppure trascina app, file e cartelle sulla barra, dal Finder o dal pannello di HomePad: vengono aggiunti prima dell’icona su cui rilasci, o in fondo sullo spazio vuoto (uno già aggiunto si sposta lì; il pannello tiene i suoi). Gli elementi della barra sono un elenco a sé, distinto dalle categorie di HomePad. Trascina le icone lungo la barra per riordinarle. Le **icone delle app** vanno al **Centro** o a **Sinistra**; finché sono centrate, l’**icona di HomePad** può essere centrata con esse o a sinistra (con le icone delle app a sinistra è sempre lì, quindi la scelta è in grigio). Sinistra è destra in arabo e persiano, speculare come in Windows. Con l’icona di HomePad a sinistra, il suo pannello si apre al bordo sinistro sopra la barra. A destra ci sono **rete**, **volume**, **batteria** e **orologio**, ciascuno con un interruttore: rete e batteria aprono le loro pagine in Impostazioni di Sistema (i menu di stato di macOS non si possono aprire dall’esterno sui macOS recenti), il volume apre un cursore (scorri sopra per cambiarlo), l’orologio un calendario. Fai clic su un elemento per aprirlo o portarlo in primo piano (o nasconderlo se è già davanti); punta un’app aperta per le sue finestre; clic destro per il suo menu. Impostazioni → Barra delle applicazioni → **App aperte** (chiusa all’inizio) elenca ogni app aperta con un interruttore **Mostra nella barra delle applicazioni**; un’app disattivata resta fuori dalla barra finché è aperta (anche **Nascondi dalla barra delle applicazioni** nel suo menu). Gli elementi aggiunti sono sempre mostrati. Nascondere un’app (Cmd-H) non cambia la barra. Il pannello si apre centrato sopra la barra. Il Dock è nascosto nel frattempo. macOS lascia solo al Dock tenere le finestre fuori da una parte dello schermo, quindi con Accessibilità HomePad accorcia una finestra quando viene aperta, ridimensionata, ingrandita o affiancata in modo da arrivare sotto la barra (spostata in su invece se diventerebbe troppo corta). Una finestra solo trascinata lì viene lasciata stare, come in Windows. (Tenere il vero Dock sotto la barra non ha funzionato: mostra le etichette dei nomi ovunque il puntatore passi sulle sue icone.) **Nascondi automaticamente la barra delle applicazioni** la fa scorrere fuori dal fondo dello schermo finché il puntatore non resta sul bordo inferiore per il **Ritardo prima di mostrarla** (0–1000 ms, 300 per impostazione predefinita, così un rapido passaggio lungo il bordo non la mostra); resta visibile finché il pannello di HomePad, un pop-up, un’anteprima di finestra o un menu è aperto, e le finestre usano allora l’intero schermo. **Apri HomePad solo dal pulsante Start** disattiva abbreviazione, doppio tocco e angoli attivi (l’icona nella barra dei menu funziona ancora).
- **Nascondi “Dock”** (solo Autonoma): attiva l’auto-nascondimento del Dock con un ritardo di 1000 secondi così non compare mai. Disattivarlo ripristina il Dock normale.
- **Apri al login**.
- **Lingua** (Impostazioni → Generali, o clic destro sull’icona nella barra dei menu → Lingua): Come il Mac, o una delle 20 lingue (arabo, bengalese, cinese (semplificato), inglese, filippino, francese, tedesco, hindi, indonesiano, italiano, giapponese, coreano, persiano, portoghese (Brasile), russo, spagnolo, telugu, thailandese, turco, vietnamita), elencate in ordine alfabetico nella lingua attuale. HomePad si riavvia nella nuova lingua; arabo e persiano si dispongono da destra a sinistra. I nomi di app, cartelle e sezioni di Impostazioni di Sistema restano come li mostra il Mac.

## Configurare i permessi

Quando consenti un permesso (nella Guida alla configurazione, nelle Impostazioni o in un’anteprima di finestra), HomePad controlla che venga attivato in Impostazioni di Sistema e torna in primo piano appena lo è. Registrazione schermo e Accesso completo al disco di solito richiedono un riavvio: quando Impostazioni di Sistema offre **Esci e riapri**, HomePad esce, riparte da solo e riapre la finestra in cui eri.

La Guida alla configurazione compare al primo avvio solo se manca un permesso. Per ripercorrerla da zero, usa **Impostazioni → Generali → Ricomincia…**: macOS riprende i permessi di HomePad, la guida compare di nuovo e HomePad si riavvia (spunta la casella per dimenticare anche le tue categorie e impostazioni, come su un’installazione nuova).


## Sviluppo

Le istruzioni per compilare l’app, il funzionamento delle traduzioni, l’elenco dei file e l’icona dell’app si trovano solo nel [README inglese](../../README.md#development).

## Licenza

[MIT](../../LICENSE).
