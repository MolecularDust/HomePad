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
    <td align="center"><b>Português (Brasil)</b></td>
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

> Esta tradução foi escrita por uma IA e não foi revisada por falantes nativos. O HomePad também existe neste idioma; os nomes de botões e menus são dados aqui como o app os mostra (o idioma pode ser mudado em Ajustes → Geral → Idioma). Vale o [README em inglês](../../README.md).

**Tudo o que você usa, a uma tecla de distância.** O HomePad é o launcher que faltava no seu Mac: organize seus apps em categorias, guarde-os em pastas, fixe seus favoritos, pesquise tudo na hora e mantenha os apps abertos à vista, com uma barra de tarefas no estilo Windows, se você quiser.

Um launcher no estilo Windows: você pressiona um atalho e um painel aparece no meio da tela, com uma barra de pesquisa no alto (que pesquisa o mesmo índice usado pelo Spotlight) e uma grade de apps fixados embaixo.

O HomePad funciona em três modos. Escolha o que combina com você em Ajustes → Modo.

**Barra de tarefas.** Imita a barra de tarefas e o menu Iniciar do Windows. Se você sente falta da experiência do Windows no macOS, vai se sentir em casa.

![Modo Barra de tarefas: uma barra de tarefas no estilo Windows com botão Iniciar, apps abertos e uma bandeja, e o painel do HomePad acima dela](../images/mode-taskbar.webp)

**Dock + HomePad.** Para quem quer manter o “Dock” do macOS, mas precisa de um launcher no estilo do menu Iniciar. O macOS tem o launcher Apps, mas ele não empolga: organiza seus apps em categorias automaticamente, e você não pode escolhê-las, agrupar apps em pastas, fixar favoritos nem arrumá-lo do seu jeito. O HomePad resolve tudo isso.

![Modo Dock + HomePad: o Dock do macOS, com o painel do HomePad abrindo acima do seu ícone](../images/mode-dock.webp)

**Independente.** Para minimalistas que querem o máximo de espaço de tela, sem “Dock” nem barra de tarefas ocupando a tela. Você chama o HomePad com uma tecla de atalho, um toque duplo ou um golpe do mouse num canto ativo sempre que precisar. Ele aparece no centro, e você tem controle total sobre seus apps, arquivos e pastas favoritos, a pesquisa e os apps abertos com suas janelas. Você não precisa do “Dock” nem do Spotlight: controla seu Mac de um único lugar. Pode parecer estranho no começo, mas fica incrivelmente poderoso quando você se acostuma.

![Modo Independente: sem “Dock” nem barra de tarefas, com o painel do HomePad no meio da tela](../images/mode-standalone.webp)

## Instalação

O HomePad é gratuito e não é assinado pela Apple, então o macOS o bloqueia uma vez e pede que você confirme que está tudo bem. Leva cerca de cinco minutos, uma única vez. Você precisa do macOS 13 (Ventura) ou posterior; Macs com Apple silicon e Intel funcionam. ([INSTALL.md](../../INSTALL.md) traz os mesmos passos em palavras, inclusive para o zip e a imagem de disco simples.)

**1. Abra a imagem de disco do instalador.** Clique duas vezes em `HomePad-Installer.dmg` (de quem compartilhou o HomePad com você, ou compile você mesmo: `tools/make_installer_dmg.sh`, veja [Build and run](../../README.md#build-and-run)). A janela dela lista os passos.

<p align="center"><img src="../images/install/01-disk-image.webp" width="520" alt="A janela da imagem de disco do instalador com os quatro passos numerados"></p>

**2. Clique duas vezes em Install HomePad.pkg.** O Mac diz que não pode abri-lo. Clique em **OK**, não em Mover para o Lixo.

<p align="center"><img src="../images/install/02-not-opened.webp" width="340" alt="O macOS diz que “Install HomePad.pkg” não foi aberto"></p>

**3. Permita em Privacidade e Segurança.** Clique duas vezes no bloco azul **Abrir Privacidade e Segurança** na janela da imagem de disco (ou abra você mesmo Ajustes do Sistema → Privacidade e Segurança), role até **Segurança** e clique em **Abrir Mesmo Assim** ao lado da mensagem sobre o instalador.

<p align="center"><img src="../images/install/03-privacy-security.webp" width="480" alt="Ajustes do Sistema, Privacidade e Segurança: “Install HomePad.pkg” foi bloqueado, com o botão Abrir Mesmo Assim"></p>

**4. Confirme.** Clique em **Abrir Mesmo Assim** na mensagem seguinte e depois use o Touch ID ou digite a senha do Mac.

<table align="center"><tr>
<td align="center"><img src="../images/install/04-open-anyway.webp" width="300" alt="O macOS pergunta se deve abrir “Install HomePad.pkg”: Abrir Mesmo Assim"></td>
<td align="center"><img src="../images/install/05-password.webp" width="300" alt="O macOS pede Touch ID ou a senha de um administrador"></td>
</tr></table>

> No macOS 13 Ventura e no 14 Sonoma há um atalho: clique com o botão direito no instalador, escolha **Abrir** e depois **Abrir** de novo.

**5. Percorra o instalador.** Clique em **Continuar** na introdução, no que esperar e no destino (para todos os usuários deste computador) e depois em **Instalar**. O Mac pede sua senha uma vez. Quando o instalador disser que o HomePad está na sua pasta Aplicativos, clique em **Fechar**.

<table align="center">
<tr>
<td align="center"><img src="../images/install/06-installer-welcome.webp" width="380" alt="Instalador: Boas-vindas ao HomePad"></td>
<td align="center"><img src="../images/install/07-installer-what-to-expect.webp" width="380" alt="Instalador: O que esperar, as permissões que o HomePad vai pedir"></td>
</tr>
<tr>
<td align="center"><img src="../images/install/08-installer-destination.webp" width="380" alt="Instalador: Selecionar um destino, instalar para todos os usuários deste computador"></td>
<td align="center"><img src="../images/install/09-installer-install.webp" width="380" alt="Instalador: Instalação padrão, com o botão Instalar"></td>
</tr>
<tr>
<td align="center" colspan="2"><img src="../images/install/10-installer-summary.webp" width="380" alt="Instalador: o HomePad foi instalado"></td>
</tr>
</table>

**6. O Guia de configuração.** O HomePad abre sozinho com uma janela de boas-vindas. Permita as três permissões, escolha como você quer abrir o HomePad (um atalho de teclado, um toque duplo, os cantos ativos) e clique em **Começar**. Cada permissão é opcional, mas o HomePad funciona melhor com as três.

<p align="center"><img src="../images/install/11-setup-guide.webp" width="440" alt="A janela de boas-vindas do HomePad: três permissões para permitir e como abrir o HomePad"></p>

**7. As permissões.** Clique em **Permitir…** ao lado de cada uma, de cima para baixo.

- **Gravação de Tela** (pré-visualizações das janelas de um app aberto). Aparece uma mensagem com um cadeado: clique em **Abrir Ajustes do Sistema**, ative a chave ao lado de **HomePad** e clique em **Encerrar e Reabrir**. O HomePad reinicia sozinho e a janela de boas-vindas volta. O macOS pode perguntar mais uma vez se o HomePad pode acessar sua tela diretamente: clique em **Permitir**.

<table align="center">
<tr>
<td align="center" valign="top"><img src="../images/install/12-screen-recording-prompt.webp" width="400" alt="macOS: “HomePad” gostaria de gravar a tela e o áudio deste computador, com Abrir Ajustes do Sistema"></td>
<td align="center" valign="top"><img src="../images/install/12a-screen-recording-off.webp" width="400" alt="Ajustes do Sistema, Screen & System Audio Recording: a chave ao lado de HomePad, ainda desativada"></td>
</tr>
<tr>
<td align="center" valign="top"><img src="../images/install/13-screen-recording-settings.webp" width="390" alt="Ajustes do Sistema, Screen & System Audio Recording, com a mensagem Encerrar e Reabrir"></td>
<td align="center" valign="top"><img src="../images/install/16-window-picker-prompt.webp" width="340" alt="macOS: o HomePad pede para contornar o seletor de janelas privado do sistema e acessar diretamente sua tela e seu áudio"></td>
</tr>
</table>

- **Acessibilidade** (pular para a janela que você escolher, e o atalho de toque duplo). Clique em **Permitir…**, depois em **Abrir Ajustes do Sistema** na mensagem, e ative a chave ao lado de **HomePad** (digite sua senha, se pedida). Nos macOS mais recentes, esta página se chama, na interface em inglês, **Device Control and Data Access**.

<p align="center"><img src="../images/install/14-accessibility-settings.webp" width="480" alt="Ajustes do Sistema, Device Control and Data Access: a chave ao lado de HomePad"></p>

- **Acesso Total ao Disco** (encontrar arquivos em Documentos, Mesa e Downloads). Clique em **Permitir…**; os Ajustes do Sistema abrem com uma pequena janela do HomePad ao lado. Ative a chave ao lado de **HomePad**. Se ele não estiver na lista, arraste o ícone dele da janela pequena para a lista.

<p align="center"><img src="../images/install/15-full-disk-access-settings.webp" width="480" alt="Ajustes do Sistema, Full Disk Access: a chave ao lado de HomePad"></p>

**8. Use.** Pressione **Option-Espaço** (ou o atalho que você escolheu). Todo o resto, inclusive os três modos acima, está nos Ajustes: clique com o botão direito no ícone de grade na barra de menus e depois em **Ajustes…**.

## Como usar

- **Option-Espaço** abre e fecha o painel (mude em Ajustes), ou toque duas vezes em Control, Option ou Comando (Ajustes → Abertura; precisa da permissão de Acessibilidade).
- **Cantos ativos**: Ajustes → Abertura → cantos ativos. Clique em qualquer um dos quatro cantos da telinha (um, vários ou todos). Deixe o ponteiro parado por um instante num canto escolhido e o painel abre nesse canto; faça de novo para fechá-lo. Roçar o canto rapidamente, ou arrastar com o botão do mouse pressionado, não faz nada. O atalho e o toque duplo continuam abrindo no meio. Também está no segundo passo do Guia de configuração. Se o macOS usar o mesmo canto para uma ação própria, o HomePad avisa, com um botão **Abrir “Cantos Ativos” do macOS…** que abre Ajustes do Sistema → Mesa e Dock com a folha Cantos Ativos já à mostra (apertar esse botão precisa de Acessibilidade; sem ela, só a página abre).
- **Categorias**: os apps ficam em categorias com nome. **Essenciais** vem primeiro e é preenchida a partir do seu Dock na primeira abertura, mais uma categoria **Arquivos** com o Lixo e os Downloads, como a ponta direita do Dock (só na primeiríssima vez; se você a apagar, ela continua apagada). Adicione as suas (Navegadores, Escrita…) com **Adicionar categoria** ou clicando com o botão direito no espaço vazio. Uma categoria nova mostra um bloco cinza “Adicione seu app aqui”. Clique com o botão direito dentro de uma categoria para renomeá-la ou apagá-la (tudo o que há nela também é desafixado; os apps e arquivos em si não são tocados).
- **Adicionar arquivos e pastas**: **Adicionar arquivo ou pasta** (link no cabeçalho, menu do botão direito ou Ajustes), arraste-os do Finder, ou clique com o botão direito num resultado de pesquisa → Fixar. Abrem ao clicar; as pastas abrem no Finder. O seletor é uma janela de navegação com uma barra lateral (Início, Mesa, Documentos, Downloads, ..., discos) e uma entrada **Lixo** que fixa o seu Lixo. Clicar num lugar da barra lateral (Documentos, Downloads, Lixo ...) abre esse lugar e escolhe a própria pasta, de modo que **Adicionar** já fica pronto. Essas janelas não bloqueiam o painel: afaste uma delas e arraste qualquer bloco dela para o painel. Clique com o botão direito no bloco do Lixo para **Esvaziar “Lixo”…** (pergunta antes; o HomePad pede ao Finder que esvazie, como o Dock, então na primeira vez o macOS pergunta se o HomePad pode controlar o Finder).
- **Ordem das categorias**: o nome de uma categoria fica verde quando você aponta para ele. Pressione-o e a linha inteira é selecionada (preenchimento e contorno verdes); arraste e a própria linha vai junto enquanto as outras se afastam para abrir espaço (o painel fica onde está). Solte e ela fica onde está. Ou clique com o botão direito dentro de uma categoria e escolha **Mover para cima** / **Mover para baixo**. Enquanto algo é arrastado, os efeitos de passar o mouse e as pré-visualizações de janelas ficam desligados. “Essenciais” também pode ser movida; continua sendo o lugar padrão para novos itens e não pode ser apagada. Linhas cinza finas separam as categorias.
- **Botão direito para adicionar**: clique com o botão direito no espaço vazio dentro de uma categoria (o título, ou os vãos entre os blocos e depois deles) e o menu adiciona a *essa* categoria: “Adicionar app a Arquivos…”, “Adicionar arquivo ou pasta a Arquivos…”, além de Adicionar categoria, Renomear e Apagar para ela, e **Ordenar alfabeticamente** (põe os blocos da categoria em ordem alfabética pelos nomes que mostram; fica cinza quando já estão; os blocos dentro das pastas dela mantêm a ordem). O espaço vazio abaixo da última seção pertence a essa seção.
- **Adicionar apps**: o botão Adicionar app (clique duas vezes num app no seletor para adicioná-lo e fechar o seletor), botão direito no espaço vazio, arrastar apps do Finder (pressione o atalho no meio do arrasto), ou botão direito num resultado de pesquisa → Fixar app.
- **Pastas** (como no menu Iniciar do Windows): arraste um bloco para o meio do ícone de outro bloco, segure ali por meio segundo até esse ícone se acender e solte: os dois viram uma pasta nesse lugar, chamada “Pasta”, cujo bloco mostra os quatro primeiros itens. Solte mais blocos sobre uma pasta para adicioná-los. Clique numa pasta para abri-la sobre o painel: clique no nome para renomeá-la, clique num item para abri-lo, arraste itens para reorganizá-los ou para fora da pasta (ela fecha para você soltar o item entre os outros blocos). Esc ou um clique fora a fecha. Uma pasta que ficou com um só item volta a ser esse item. Clique com o botão direito numa pasta para “Renomear pasta…”, “Mover para” e “Desagrupar”; clique com o botão direito num item de uma pasta aberta para “Remover da pasta”. Arrastar sobre as bordas de um bloco (não o meio) continua só reordenando.
- **Remover / reordenar**: botão direito num bloco → Desafixar app / Mover para, ou arraste os blocos, inclusive entre categorias.
- **Apps abertos**: uma barra vermelha logo abaixo de um ícone (acima do nome) significa que o app está aberto. Aponte para um app aberto para ver uma miniatura de cada janela dele (uma minimizada tem um sinal de menos ao lado do X de fechar), em todas as mesas (Spaces), listadas na ordem do Mission Control com o título “Space N” quando um app tem janelas em mais de uma, e clique numa para ir direto a ela (trocando de mesa, se preciso), ou clique no X no canto dela para fechar só essa janela (funciona também para janelas em outras mesas) (precisa de Gravação de Tela e Acessibilidade; sem Gravação de Tela você recebe uma lista simples). Clicar num app aberto põe a mesa atual em primeiro lugar: uma janela visível ali traz o app para a frente; se todas as janelas dele ali estiverem minimizadas, a mais recente volta; só quando não houver nenhuma janela ali é que ele leva você a outra mesa onde tenha janelas. A seção **Em uso** lista todo app que está aberto (fixado ou não, como os indicadores de abertura do Dock); nada pode ser adicionado a ela nem removido, mas os blocos dela podem ser **arrastados dentro dela para reordená-los** (em ordem alfabética até você mover um; a ordem é lembrada, inclusive para um app que sai e abre de novo; um bloco não pode ser solto em nenhum outro lugar, e Esc ou soltar em outro lugar o devolve; botão direito em Em uso → **Ordenar alfabeticamente** esquece a sua ordem), e a seção em si não pode ser renomeada, mas pode ser arrastada pelo título (ou movida com **Mover para cima** / **Mover para baixo** no menu do botão direito) para qualquer lugar entre as categorias, e pode ser ocultada (botão direito nela → Ocultar “Em uso”; traga-a de volta com Ajustes → Painel → Mostrar a seção “Em uso”). As **janelas minimizadas** de cada app aberto podem acompanhar o bloco dele ali, como blocos próprios: uma imagem da janela com o ícone do app no canto e o título da janela (como o Dock as mostra). Clique numa para trazer essa janela de volta; botão direito para Restaurar ou Fechar janela. Vêm desligadas: ative Ajustes → Painel → Mostrar janelas minimizadas em “Em uso”, ou clique com o botão direito em Em uso → Mostrar janelas minimizadas. São reunidas cada vez que o painel abre (precisa de Acessibilidade; as imagens precisam de Gravação de Tela).
- **Menu de um app aberto**: clique com o botão direito num app aberto para um menu como o do Dock: as janelas dele (a da frente marcada; escolha uma para trazê-la para a frente), os comandos “Novo …” do menu Arquivo dele (Nova aba, Nova janela, Nova janela privada num navegador), depois **Fechar janelas** (só se houver janela aberta), **Ocultar** e **Encerrar** (segure Option para forçar o encerramento; um app ainda aberto alguns segundos depois de Encerrar recebe **Forçar encerramento** no lugar; o Finder não tem Encerrar, como no Dock, porque encerrá-lo remove os ícones da mesa). As janelas e os comandos são lidos pela Acessibilidade quando o ponteiro chega ao bloco.
- **Encontrar arquivos**: os arquivos em Documentos, Mesa e Downloads só aparecem na pesquisa depois que o HomePad tem **Acesso Total ao Disco** (Ajustes do Sistema → Privacidade e Segurança). Até lá, os resultados mostram um aviso com um link para a chave.
- **Calculadora**: digite uma conta como `7+3`, `(2+3)*4`, `2^10` ou `15%` e a resposta aparece primeiro. ↩ ou o botão de copiar a copia.
- **Janela**: arraste qualquer borda ou canto do painel para redimensioná-lo (as bordas têm faixas largas para agarrar e mostram cursores de redimensionamento), ou arraste qualquer parte vazia para movê-lo (não a grade de blocos em si, onde arrastar reorganiza os blocos). O campo de pesquisa tem o foco sempre que o painel abre, então você pode digitar na hora; depois de clicar em outro lugar, a próxima tecla que você digitar volta para ele. Ajustes → Painel tem **Lembrar o tamanho da janela** (ligado por padrão) e **Lembrar a posição da janela** (desligado por padrão). O botão ↺ ao lado da engrenagem dos ajustes devolve o painel ao tamanho padrão, centralizado. As janelas Adicionar app e Adicionar arquivo ou pasta também podem ser redimensionadas (elas sempre abrem no tamanho padrão).
- **Seu nome**, no canto inferior esquerdo do painel, abre os Ajustes do Sistema na sua Conta Apple.
- **Pesquisa**: é só começar a digitar. Primeiro vêm os apps, depois documentos e pastas, depois uma busca na web. ↑ ↓ para escolher, ↩ para abrir, ⌘↩ para mostrar no Finder, Esc para limpar e depois fechar. O botão ‹ ou um clique no espaço vazio também volta para os seus apps.

## Primeira abertura

Uma janela de boas-vindas pede que você permita Gravação de Tela, Acessibilidade e Acesso Total ao Disco e escolha como abrir o HomePad (veja Instalação). Reabra-a quando quiser pelo ícone na barra de menus → Guia de configuração…

## Ajustes

Os Ajustes têm seis abas na barra de ferramentas: **Modo**, **Geral** (idioma, ícone na barra de menus, abrir ao iniciar sessão, Restaurar padrões, Recomeçar), **Barra de tarefas**, **Abertura** (atalho, toque duplo, cantos ativos), **Painel** (layout, janela, itens) e **Permissões**. Eles reabrem na aba que você usou por último.

- **Atalho**: clique no botão e pressione uma nova combinação. Para usar ⌘Espaço, primeiro desligue o atalho do Spotlight em Ajustes do Sistema → Teclado → Atalhos do Teclado → Spotlight.
- **Atalho**: grave um, escolha **Nenhum** se você só quiser o toque duplo, ou **Redefinir** para voltar a ⌥Espaço.
- **Ícone na barra de menus**: Ajustes → Geral pode ocultá-lo. Abrir o app de novo abre o painel.
- **Restaurar padrões**: restaura atalho, toque duplo, layout, ocultar o Dock e abrir ao iniciar sessão (apps e categorias são mantidos).
- **Toque duplo**: abra tocando duas vezes em Control, Option ou Comando.
- **Ícones por linha** (8 por padrão, 4–10) e **altura da linha** (a distância entre as linhas de ícones, 101 pt por padrão, 85–125) e **espaçamento dos ícones** (o vão horizontal entre os ícones, 10 pt por padrão, 0–40; quando o painel é estreito demais para o vão, o vão diminui primeiro, depois os ícones): digite um número ou clique em − / +, **mostrar apps abertos**, **reimportar do Dock**.
- **Modo** (a primeira aba):
  - **Independente** (padrão): o painel flutuante, aberto pelo atalho, toque duplo, cantos ativos ou ícone na barra de menus. Passar para ele oculta o Dock; **Ocultar o “Dock”** abaixo o traz de volta.
  - **HomePad + “Dock”**: um fluxo como o menu Iniciar do Windows, com o Dock como barra de tarefas. Escolhê-lo sempre mostra o Dock (desliga a ocultação automática, a do HomePad ou a dos Ajustes do Sistema) e adiciona o HomePad a ele se não estiver lá (o Dock reinicia uma vez); o Dock fica onde você o puser. O painel abre bem ao lado do ícone do HomePad (acima dele para um Dock embaixo, ao lado para um Dock lateral, mantido na tela) quer você clique no ícone ou use o atalho ou o toque duplo; clicar no ícone de novo o fecha. Os cantos ativos continuam abrindo no canto deles. Os Ajustes dizem por que ele abre no meio quando o HomePad não está no Dock, o Dock está oculto ou falta a permissão de Acessibilidade.
  - **Barra de tarefas**: uma barra de tarefas no estilo Windows ao longo da parte de baixo da tela principal: um botão Iniciar (o ícone do HomePad), depois o que você fixou nela e os apps abertos, centralizados. Os apps abertos então saem do painel. Fixe apps, arquivos e pastas clicando com o botão direito no espaço vazio da barra (**Adicionar app…**, **Adicionar arquivo ou pasta…**) ou num bloco (**Fixar na barra de tarefas**; no painel do HomePad também). O menu de um ícone da barra também tem **Fixar no HomePad** (ou Desafixar do HomePad), para as categorias do próprio HomePad. Ou arraste apps, arquivos e pastas para a barra, do Finder ou do painel do HomePad: eles são fixados antes do ícone em que você soltar, ou no fim, no espaço vazio (um já fixado se move para lá; o painel mantém os seus). Os itens fixados da barra são uma lista à parte, separada das categorias do HomePad. Arraste os ícones ao longo da barra para reordená-los. Os **ícones dos apps** ficam no **Centro** ou à **Esquerda**; enquanto estão centralizados, o **ícone do HomePad** pode ficar centralizado com eles ou à esquerda (com os ícones dos apps à esquerda ele sempre fica lá, então a escolha fica cinza). A esquerda é a direita em árabe e persa, espelhada como no Windows. Com o ícone do HomePad à esquerda, o painel dele abre na borda esquerda acima da barra. À direita ficam **rede**, **volume**, **bateria** e **relógio**, cada um com uma chave: rede e bateria abrem suas páginas nos Ajustes do Sistema (os menus de status do próprio macOS não podem ser abertos de fora nos macOS recentes), o volume abre um controle deslizante (role sobre ele para mudar o volume), o relógio um calendário. Clique num item para abri-lo ou trazê-lo para a frente (ou ocultá-lo se já estiver na frente); aponte para um app aberto para ver as janelas dele; botão direito para o menu dele. Ajustes → Barra de tarefas → **Apps abertos** (recolhido no início) lista todo app aberto com uma chave **Mostrar na barra de tarefas**; um app desligado fica fora da barra enquanto estiver aberto (também **Ocultar da barra de tarefas** no menu dele). Itens fixados são sempre mostrados. Ocultar um app (Cmd-H) não muda a barra. O painel abre centralizado acima da barra. O Dock fica oculto nesse meio-tempo. O macOS só deixa o Dock manter as janelas fora de uma parte da tela, então, com a Acessibilidade, o HomePad encurta uma janela quando ela é aberta, redimensionada, maximizada ou lado a lado de modo a chegar por baixo da barra (movida para cima, em vez disso, se ficasse curta demais). Uma janela apenas arrastada para lá é deixada em paz, como no Windows. (Manter o Dock de verdade sob a barra não funcionou: ele mostra os rótulos de nome onde quer que o ponteiro passe sobre os ícones.) **Ocultar automaticamente a barra de tarefas** a desliza para fora da parte de baixo da tela até o ponteiro ficar parado na borda inferior pelo **Atraso antes de mostrar** (0–1000 ms, 300 por padrão, para que uma passada rápida pela borda não a mostre); ela fica à mostra enquanto o painel do HomePad, um pop-up, uma pré-visualização de janela ou um menu estiver aberto, e as janelas então usam a tela toda. **Abrir o HomePad só pelo botão Iniciar** desliga o atalho, o toque duplo e os cantos ativos (o ícone na barra de menus continua funcionando).
- **Ocultar o “Dock”** (só no modo Independente): liga a ocultação automática do Dock com um atraso de 1000 segundos, de modo que ele nunca apareça. Desligar restaura o Dock normal.
- **Abrir ao iniciar sessão**.
- **Idioma** (Ajustes → Geral, ou botão direito no ícone da barra de menus → Idioma): Igual ao Mac, ou um dos 20 idiomas (árabe, bengali, chinês (simplificado), inglês, filipino, francês, alemão, híndi, indonésio, italiano, japonês, coreano, persa, português (Brasil), russo, espanhol, telugo, tailandês, turco, vietnamita), listados em ordem alfabética no idioma atual. O HomePad reinicia no novo idioma; árabe e persa são dispostos da direita para a esquerda. Os nomes de apps, pastas e seções dos Ajustes do Sistema continuam como o Mac os mostra.

## Configurar as permissões

Quando você permite uma permissão (no Guia de configuração, nos Ajustes ou numa pré-visualização de janela), o HomePad observa se ela foi ligada nos Ajustes do Sistema e volta para a frente assim que for. Gravação de Tela e Acesso Total ao Disco costumam precisar de reinício: quando os Ajustes do Sistema oferecem **Encerrar e Reabrir**, o HomePad encerra, recomeça sozinho e reabre a janela em que você estava.

O Guia de configuração só aparece na primeira abertura se faltar alguma permissão. Para percorrê-lo de novo desde o início, use **Ajustes → Geral → Recomeçar…**: o macOS retira as permissões do HomePad, o guia aparece de novo e o HomePad reinicia (marque a caixa para esquecer também suas categorias e ajustes, como numa instalação nova).


## Desenvolvimento

As instruções para compilar o app, o funcionamento das traduções, a lista de arquivos e o ícone do app estão apenas no [README em inglês](../../README.md#development).

## Licença

[MIT](../../LICENSE).
