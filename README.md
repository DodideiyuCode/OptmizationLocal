<div align="center">

# Optmization Local

**Otimização completa do Windows 10/11 com um único comando no PowerShell**

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?style=flat-square&logo=windows&logoColor=white)](#requisitos)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)](#requisitos)
[![Version](https://img.shields.io/badge/version-1.2-informational?style=flat-square)](#)
[![Status](https://img.shields.io/badge/status-ativo-success?style=flat-square)](#)
[![License](https://img.shields.io/badge/uso-por%20sua%20conta%20e%20risco-lightgrey?style=flat-square)](#aviso-legal)

</div>

Script de otimização feito para rodar com um único comando no PowerShell, sem precisar instalar nada nem clonar o repositório manualmente.

---

## Índice

- [Como executar](#como-executar)
- [Requisitos](#requisitos)
- [Segurança e reversão](#segurança-e-reversão)
- [Robustez e log de execução](#robustez-e-log-de-execução)
- [O que o script faz](#o-que-o-script-faz-etapa-por-etapa)
- [Tratamento de erros](#tratamento-de-erros)
- [Como reverter](#como-reverter)
- [Aviso legal](#aviso-legal)

---

## Como executar

Abra o **PowerShell como Administrador** e cole o comando abaixo:

```powershell
irm https://raw.githubusercontent.com/DodideiyuCode/OptmizationLocal/main/optimize.ps1 | iex
```

Se o PowerShell não estiver aberto como Administrador, o próprio script detecta isso e abre uma nova janela elevada automaticamente. O Windows vai mostrar o aviso de UAC — basta clicar em "Sim".

---

## Requisitos

| Requisito | Detalhe |
|---|---|
| Sistema operacional | Windows 10 ou Windows 11 |
| PowerShell | 5.1 ou superior (já vem instalado por padrão) |
| Permissão | Executar como Administrador |
| Internet | Necessária para baixar o script via `irm` |

---

## Segurança e reversão

Antes de qualquer alteração, o script cria automaticamente um **Ponto de Restauração do Sistema** (`Checkpoint-Computer`). Caso algo não funcione como esperado após a otimização, use a ferramenta **Restauração do Sistema** do Windows para reverter todas as mudanças com poucos cliques.

O script **não apaga arquivos pessoais**. Nenhum documento, foto, vídeo ou arquivo da pasta Downloads é tocado. As alterações ficam restritas a:

- Configurações do sistema (registro, serviços, energia, aparência)
- Aplicativos padrão do Windows (apps UWP como Xbox, 3D Builder, etc.)
- Arquivos temporários reversíveis (`%TEMP%` e `C:\Windows\Temp`)

### Termo de uso exibido no console

Ao rodar o script, uma tela de termos de uso é exibida no console. Navegue com as setas do teclado até a opção **SIM** e pressione Enter para continuar. Selecionando **NÃO**, o script é encerrado sem nenhuma alteração no sistema.

Ao selecionar **SIM**, você declara estar ciente de que:

- O script é fornecido "como está", sem nenhuma garantia de qualquer tipo.
- O autor e os mantenedores do repositório Optmization Local não se responsabilizam por eventuais danos, perda de dados, instabilidade do sistema, mau funcionamento de hardware/software, ou qualquer prejuízo direto ou indireto decorrente do uso deste script.
- Um ponto de restauração é criado automaticamente antes de qualquer alteração, mas a decisão de usá-lo para reverter mudanças é de responsabilidade do usuário.
- O uso deste script é por sua conta e risco.

---

## Robustez e log de execução

A partir desta versão, o script:

- Grava um log completo de cada execução em `%TEMP%\OptmizationLocal_log_AAAAMMDD_HHmmss.txt`, contendo o detalhe completo de qualquer erro (o console mostra apenas um resumo de uma linha, para não poluir a tela).
- Usa `$ErrorActionPreference = "Stop"` internamente, para que todo erro de cada etapa seja realmente capturado pelo `try/catch` (evitando falsos "OK" quando um comando falha silenciosamente).
- Para gravação no registro do Windows, usa uma estratégia de 3 níveis de fallback:
  1. Cmdlet nativo do PowerShell
  2. `reg.exe`
  3. Assumir a posse (ownership) da chave de registro quando ela estiver protegida por permissões restritas, tentando novamente em seguida

  Isso resolve casos como a chave `TaskbarDa` (Widgets), que em algumas versões do Windows 11 vem com permissões mais restritas mesmo para administradores.
- Exibe uma barra de progresso e um resumo final com quantidade de etapas concluídas com sucesso, quantidade de falhas e tempo total de execução.

### Sobre apps que "falham" na remoção

Alguns aplicativos do Windows (como partes do Xbox ou do People) são pacotes de sistema protegidos pela Microsoft e não podem ser removidos mesmo por scripts administrativos, em algumas builds do Windows. Quando isso acontece, o script registra a etapa como "FALHOU" e segue para a próxima, sem travar a execução. Isso é esperado e não indica um problema com o script.

---

## O que o script faz, etapa por etapa

| # | Etapa | Descrição |
|---|---|---|
| 1 | Verificação de administrador | Confere se o PowerShell está rodando como Administrador; se não estiver, reabre em janela elevada |
| 2 | Tela de termos de uso | Mostra um resumo do que será feito e pede confirmação via menu navegável (SIM/NÃO) |
| 3 | Ponto de restauração do sistema | Habilita a proteção do sistema no disco `C:` e cria o ponto "Optmization Local - Antes da otimização" |
| 4 | Plano de energia de Alto Desempenho | Ativa o plano de alto desempenho e desativa timeouts de monitor, standby e hibernação |
| 5 | Efeitos visuais | Desativa transparência das janelas, ajusta para "melhor desempenho" e reduz animações |
| 6 | Barra de tarefas | Remove Task View, ícone de Widgets, Chat/Teams e o botão do Copilot |
| 7 | Serviços não essenciais | Para e desativa serviços listados abaixo |
| 8 | Apps padrão do Windows (UWP) | Remove aplicativos pré-instalados considerados desnecessários |
| 9 | Telemetria | Define `AllowTelemetry = 0` e desativa experiências personalizadas baseadas em diagnóstico |
| 10 | Processos em execução | Encerra `OneDrive`, `Cortana`, `SearchApp`, `Widgets` e `YourPhone` |
| 11 | Sugestões e anúncios do menu Iniciar | Desativa sugestões, anúncios e conteúdo patrocinado (`ContentDeliveryManager`) |
| 12 | Limpeza de arquivos temporários | Remove conteúdo de `%TEMP%` e `C:\Windows\Temp`, além de esvaziar a Lixeira |
| 13 | Reinício do Explorer | Reinicia `explorer.exe` para aplicar as mudanças imediatamente |
| 14 | Pergunta final | Pergunta se deseja reiniciar o computador agora (S/N) |

### Serviços desativados na etapa 7

`SysMain`, `WSearch`, `DiagTrack`, `dmwappushservice`, `Fax`, `Spooler`, `XblAuthManager`, `XblGameSave`, `XboxGipSvc`, `WbioSrvc`, `RetailDemo`

> **Atenção:** desativar `Spooler` desativa a impressão. Desativar `WSearch` desativa a indexação/busca do Windows. Se você usa essas funções no dia a dia, reative o serviço específico depois pelo comando:
> ```powershell
> Set-Service -Name "NomeDoServico" -StartupType Automatic
> ```

### Apps UWP removidos na etapa 8

3D Builder, Bing Weather/News/Finance, Get Started/Get Help, Office Hub, Solitaire, Xbox, Zune Music/Video, Your Phone, People, Wallet, Skype, Mixed Reality, Print3D, Alarms, Feedback, To Do, Quick Assist

---

## Tratamento de erros

Cada etapa do script roda dentro de um bloco `try/catch` independente. Se algum comando falhar (por exemplo, um serviço que não existe na sua versão do Windows), o script registra a falha no console com a mensagem `FALHOU:` e continua normalmente para a próxima etapa, sem travar a execução.

---

## Como reverter

1. Pesquise por "Restaurar sistema" no menu Iniciar
2. Escolha o ponto de restauração "Optmization Local - Antes da otimização"
3. Siga o assistente do Windows para concluir a restauração

---

## Aviso legal

Use por sua conta e risco. Embora o script tenha sido feito para ser seguro e reversível (com ponto de restauração automático), alterações de sistema sempre envolvem algum risco. Revise o código de `optimize.ps1` antes de executar se quiser entender exatamente o que será feito na sua máquina.

---

<div align="center">

Feito com dedicação. Use com responsabilidade.

</div>
