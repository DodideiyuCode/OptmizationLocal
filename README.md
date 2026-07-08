# Optmization Local

Script de otimizacao para **Windows 10 e Windows 11**, feito para rodar com
um unico comando no PowerShell, sem precisar instalar nada nem clonar o
repositorio manualmente.

## Como executar

Abra o **PowerShell como Administrador** e cole o comando abaixo:

```powershell
irm https://raw.githubusercontent.com/BeniCode634/OptmizationLocal/main/optimize.ps1 | iex
```

Se o PowerShell nao estiver aberto como Administrador, o proprio script
detecta isso e abre uma nova janela elevada automaticamente (o Windows vai
mostrar o aviso de UAC, basta clicar em "Sim").

## Requisitos

- Windows 10 ou Windows 11
- PowerShell 5.1 ou superior (ja vem instalado por padrao)
- Executar como Administrador
- Conexao com a internet (para baixar o script via `irm`)

## Aviso de seguranca

Antes de qualquer alteracao, o script cria automaticamente um **Ponto de
Restauracao do Sistema** (`Checkpoint-Computer`). Caso algo nao funcione
como esperado apos a otimizacao, use a ferramenta **Restauracao do Sistema**
do Windows para reverter todas as mudancas com poucos cliques.

O script **nao apaga arquivos pessoais**. Nenhum documento, foto, video ou
arquivo da pasta Downloads e tocado. As alteracoes ficam restritas a:

- Configuracoes do sistema (registro, servicos, energia, aparencia)
- Aplicativos padrao do Windows (apps UWP como Xbox, 3D Builder, etc.)
- Arquivos temporarios reversiveis (`%TEMP%` e `C:\Windows\Temp`)

Ao rodar o script, uma tela de termos de uso e exibida no console. Voce
precisa navegar com as setas do teclado ate a opcao **SIM** e pressionar
Enter para continuar. Selecionando **NAO**, o script e encerrado sem
nenhuma alteracao no sistema.

## O que o script faz, etapa por etapa

1. **Verificacao de administrador**
   Confere se o PowerShell esta rodando como Administrador. Se nao
   estiver, reabre o proprio script em uma janela elevada.

2. **Tela de termos de uso**
   Mostra um resumo do que sera feito e pede confirmacao do usuario
   atraves de um menu navegavel por setas (SIM / NAO).

3. **Ponto de restauracao do sistema**
   Habilita a protecao do sistema no disco `C:` e cria um ponto de
   restauracao chamado "Optmization Local - Antes da otimizacao".

4. **Plano de energia de Alto Desempenho**
   Cria (se necessario) e ativa o plano de energia de alto desempenho do
   Windows, alem de desativar os timeouts de monitor, standby e
   hibernacao, mantendo o PC sempre ligado e responsivo durante o uso.

5. **Efeitos visuais**
   Desativa a transparencia das janelas, ajusta o "Desempenho Visual" do
   Windows para a opcao "Ajustar para obter melhor desempenho" e reduz
   animacoes de janelas e menus.

6. **Barra de tarefas**
   Remove o botao de Task View, o icone de Widgets, o icone de Chat/Teams
   e o botao do Copilot da barra de tarefas.

7. **Servicos nao essenciais**
   Para e desativa os servicos: `SysMain`, `WSearch`, `DiagTrack`,
   `dmwappushservice`, `Fax`, `Spooler`, `XblAuthManager`, `XblGameSave`,
   `XboxGipSvc`, `WbioSrvc` e `RetailDemo`.

   > Atencao: desativar `Spooler` desativa a impressao. Desativar
   > `WSearch` desativa a indexacao/busca do Windows. Se voce usa essas
   > funcoes no dia a dia, reative o servico especifico depois pelo
   > comando `Set-Service -Name "NomeDoServico" -StartupType Automatic`.

8. **Apps padrao do Windows (UWP)**
   Remove aplicativos pre-instalados considerados desnecessarios, como
   3D Builder, Bing Weather/News/Finance, Get Started/Get Help, Office
   Hub, Solitaire, Xbox, Zune Music/Video, Your Phone, People, Wallet,
   Skype, Mixed Reality, Print3D, Alarms, Feedback, To Do e Quick
   Assist.

9. **Telemetria**
   Define a chave de registro `AllowTelemetry` como `0` (nivel minimo
   permitido pela edicao do Windows) e desativa experiencias
   personalizadas baseadas em dados de diagnostico.

10. **Processos em execucao**
    Encerra processos que costumam consumir recursos em segundo plano,
    como `OneDrive`, `Cortana`, `SearchApp`, `Widgets` e `YourPhone`.

11. **Sugestoes e anuncios do menu Iniciar**
    Desativa as sugestoes de aplicativos, anuncios e conteudo
    patrocinado que aparecem no menu Iniciar (`ContentDeliveryManager`).

12. **Limpeza de arquivos temporarios**
    Remove o conteudo das pastas `%TEMP%` e `C:\Windows\Temp`, alem de
    esvaziar a Lixeira. Nenhum arquivo pessoal e afetado.

13. **Reinicio do Explorer**
    Reinicia o processo `explorer.exe` para aplicar as mudancas visuais
    e da barra de tarefas imediatamente, sem precisar reiniciar o PC.

14. **Pergunta final**
    Ao final, o script pergunta se voce deseja reiniciar o computador
    agora (`S` ou `N`) para garantir que todas as alteracoes sejam
    aplicadas por completo.

## Tratamento de erros

Cada etapa do script roda dentro de um bloco `try/catch` independente.
Se algum comando falhar (por exemplo, um servico que nao existe na sua
versao do Windows), o script registra a falha no console com a mensagem
`FALHOU:` e continua normalmente para a proxima etapa, sem travar a
execucao.

## Reversao

Se quiser desfazer as alteracoes:

1. Pesquise por "Restaurar sistema" no menu Iniciar
2. Escolha o ponto de restauracao "Optmization Local - Antes da
   otimizacao"
3. Siga o assistente do Windows para concluir a restauracao

## Aviso legal

Use por sua conta e risco. Embora o script tenha sido feito para ser
seguro e reversivel (com ponto de restauracao automatico), alteracoes de
sistema sempre envolvem algum risco. Revise o codigo de `optimize.ps1`
antes de executar se quiser entender exatamente o que sera feito na sua
maquina.
