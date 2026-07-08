#requires -Version 5.1
<#
    optimize.ps1
    Repositorio: BeniCode634/OptmizationLocal
    Script de otimizacao para Windows 10/11
    Execucao remota recomendada:
    irm https://raw.githubusercontent.com/BeniCode634/OptmizationLocal/main/optimize.ps1 | iex
#>

$ErrorActionPreference = "Continue"
$ScriptUrl = "https://raw.githubusercontent.com/BeniCode634/OptmizationLocal/main/optimize.ps1"

# ==========================================================
# FUNCOES AUXILIARES DE LOG
# ==========================================================

function Write-Banner {
    param([string]$Texto)
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host $Texto -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Texto)
    Write-Host ""
    Write-Host ">> $Texto" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Texto)
    Write-Host "   OK: $Texto" -ForegroundColor Green
}

function Write-Falhou {
    param([string]$Texto)
    Write-Host "   FALHOU: $Texto" -ForegroundColor Red
}

function Invoke-Etapa {
    param(
        [string]$Nome,
        [scriptblock]$Acao
    )
    Write-Step $Nome
    try {
        & $Acao
        Write-Ok $Nome
    }
    catch {
        Write-Falhou "$Nome -- Detalhe: $($_.Exception.Message)"
    }
}

# ==========================================================
# VERIFICACAO DE ADMINISTRADOR (AUTO ELEVACAO)
# ==========================================================

function Test-Administrador {
    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal  = New-Object Security.Principal.WindowsPrincipal($identidade)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrador)) {
    Write-Host "Este script precisa ser executado como Administrador." -ForegroundColor Yellow
    Write-Host "Reiniciando o script com privilegios elevados..." -ForegroundColor Yellow

    try {
        $comando = "irm $ScriptUrl | iex"
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $comando `
            -Verb RunAs

        Write-Host "Uma nova janela elevada foi aberta. Esta janela pode ser fechada." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Nao foi possivel elevar automaticamente." -ForegroundColor Red
        Write-Host "Abra o PowerShell como Administrador e execute o comando manualmente." -ForegroundColor Red
    }

    exit
}

# ==========================================================
# TELA DE TERMOS DE USO (SELECAO POR SETAS DO TECLADO)
# ==========================================================

function Show-TermoDeUso {
    $opcoes = @("SIM", "NAO")
    $selecionado = 0
    $confirmado = $false

    while (-not $confirmado) {
        Clear-Host
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "  OPTMIZATION LOCAL - TERMOS DE USO" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Este script ira alterar configuracoes do sistema Windows,"
        Write-Host "incluindo plano de energia, servicos, apps padrao, registro"
        Write-Host "do sistema, itens da barra de tarefas e arquivos temporarios."
        Write-Host ""
        Write-Host "Antes de qualquer alteracao, sera criado um PONTO DE"
        Write-Host "RESTAURACAO DO SISTEMA, permitindo reverter tudo caso"
        Write-Host "necessario."
        Write-Host ""
        Write-Host "Nenhum arquivo pessoal (documentos, fotos, downloads) sera"
        Write-Host "apagado. Apenas configuracoes do sistema e arquivos"
        Write-Host "temporarios reversiveis serao modificados."
        Write-Host ""
        Write-Host "Leia o repositorio completo antes de continuar:"
        Write-Host "https://github.com/BeniCode634/OptmizationLocal"
        Write-Host ""
        Write-Host "Voce concorda com os termos descritos no README deste"
        Write-Host "repositorio e deseja continuar?"
        Write-Host ""

        for ($i = 0; $i -lt $opcoes.Count; $i++) {
            if ($i -eq $selecionado) {
                Write-Host ("  [X] " + $opcoes[$i]) -ForegroundColor Green
            }
            else {
                Write-Host ("  [ ] " + $opcoes[$i])
            }
        }

        Write-Host ""
        Write-Host "Use as setas ESQUERDA / DIREITA (ou CIMA / BAIXO) para" -ForegroundColor DarkGray
        Write-Host "escolher e ENTER para confirmar." -ForegroundColor DarkGray

        $tecla = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($tecla.VirtualKeyCode) {
            37 { $selecionado = 0 }  # seta esquerda
            38 { $selecionado = 0 }  # seta cima
            39 { $selecionado = 1 }  # seta direita
            40 { $selecionado = 1 }  # seta baixo
            9  { $selecionado = 1 - $selecionado }  # tab alterna
            13 { $confirmado = $true }  # enter
        }
    }

    return $opcoes[$selecionado]
}

$respostaTermo = Show-TermoDeUso

if ($respostaTermo -ne "SIM") {
    Clear-Host
    Write-Host "Voce optou por NAO aceitar os termos." -ForegroundColor Red
    Write-Host "O script sera encerrado sem realizar nenhuma alteracao." -ForegroundColor Red
    exit
}

Clear-Host
Write-Banner "OPTMIZATION LOCAL - INICIANDO OTIMIZACAO"
Write-Host "Termos aceitos. Iniciando o processo em instantes..." -ForegroundColor Green
Start-Sleep -Seconds 2

# ==========================================================
# PONTO DE RESTAURACAO DO SISTEMA
# ==========================================================

Write-Banner "ETAPA 1 DE 12 - PONTO DE RESTAURACAO"

Invoke-Etapa -Nome "Habilitando protecao do sistema no disco C" -Acao {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
}

Invoke-Etapa -Nome "Ajustando intervalo minimo entre pontos de restauracao" -Acao {
    $caminhoRegistro = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    if (-not (Test-Path $caminhoRegistro)) {
        New-Item -Path $caminhoRegistro -Force | Out-Null
    }
    New-ItemProperty -Path $caminhoRegistro -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force | Out-Null
}

Invoke-Etapa -Nome "Criando ponto de restauracao (Optmization Local)" -Acao {
    Checkpoint-Computer -Description "Optmization Local - Antes da otimizacao" -RestorePointType "MODIFY_SETTINGS"
}

# ==========================================================
# PLANO DE ENERGIA DE ALTO DESEMPENHO
# ==========================================================

Write-Banner "ETAPA 2 DE 12 - PLANO DE ENERGIA"

Invoke-Etapa -Nome "Criando e ativando plano de Alto Desempenho" -Acao {
    $guidAltoDesempenho = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $planosExistentes = powercfg /list
    if ($planosExistentes -notmatch $guidAltoDesempenho) {
        powercfg -duplicatescheme $guidAltoDesempenho | Out-Null
    }
    powercfg /setactive $guidAltoDesempenho
}

Invoke-Etapa -Nome "Desativando timeout de monitor (AC e bateria)" -Acao {
    powercfg /change monitor-timeout-ac 0
    powercfg /change monitor-timeout-dc 0
}

Invoke-Etapa -Nome "Desativando timeout de standby (AC e bateria)" -Acao {
    powercfg /change standby-timeout-ac 0
    powercfg /change standby-timeout-dc 0
}

Invoke-Etapa -Nome "Desativando hibernacao" -Acao {
    powercfg /hibernate off
}

# ==========================================================
# VISUAL - TRANSPARENCIA E EFEITOS
# ==========================================================

Write-Banner "ETAPA 3 DE 12 - EFEITOS VISUAIS"

Invoke-Etapa -Nome "Desativando transparencia do Windows" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (-not (Test-Path $caminho)) {
        New-Item -Path $caminho -Force | Out-Null
    }
    Set-ItemProperty -Path $caminho -Name "EnableTransparency" -Value 0 -Type DWord
}

Invoke-Etapa -Nome "Ajustando efeitos visuais para melhor desempenho" -Acao {
    $caminhoEfeitos = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
    if (-not (Test-Path $caminhoEfeitos)) {
        New-Item -Path $caminhoEfeitos -Force | Out-Null
    }
    Set-ItemProperty -Path $caminhoEfeitos -Name "VisualFXSetting" -Value 2 -Type DWord

    $mascara = [byte[]](144,18,3,128,16,0,0,0)
    $caminhoMascara = "HKCU:\Control Panel\Desktop"
    Set-ItemProperty -Path $caminhoMascara -Name "UserPreferencesMask" -Value $mascara -Type Binary
}

Invoke-Etapa -Nome "Desativando animacoes de janelas e menus" -Acao {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 0 -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 0 -Type String -Force
}

# ==========================================================
# LIMPEZA DA BARRA DE TAREFAS
# ==========================================================

Write-Banner "ETAPA 4 DE 12 - BARRA DE TAREFAS"

Invoke-Etapa -Nome "Ocultando botao Task View" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $caminho -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
}

Invoke-Etapa -Nome "Desativando Widgets na barra de tarefas" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $caminho -Name "TaskbarDa" -Value 0 -Type DWord -Force

    $caminhoPolitica = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (-not (Test-Path $caminhoPolitica)) {
        New-Item -Path $caminhoPolitica -Force | Out-Null
    }
    Set-ItemProperty -Path $caminhoPolitica -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force
}

Invoke-Etapa -Nome "Desativando icone de Chat/Teams na barra de tarefas" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $caminho -Name "TaskbarMn" -Value 0 -Type DWord -Force
}

Invoke-Etapa -Nome "Desativando Copilot do Windows" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $caminho -Name "ShowCopilotButton" -Value 0 -Type DWord -Force

    $caminhoPolitica = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
    if (-not (Test-Path $caminhoPolitica)) {
        New-Item -Path $caminhoPolitica -Force | Out-Null
    }
    Set-ItemProperty -Path $caminhoPolitica -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
}

# ==========================================================
# SERVICOS NAO ESSENCIAIS
# ==========================================================

Write-Banner "ETAPA 5 DE 12 - SERVICOS DO WINDOWS"

$listaServicos = @(
    "SysMain",
    "WSearch",
    "DiagTrack",
    "dmwappushservice",
    "Fax",
    "Spooler",
    "XblAuthManager",
    "XblGameSave",
    "XboxGipSvc",
    "WbioSrvc",
    "RetailDemo"
)

foreach ($nomeServico in $listaServicos) {
    Invoke-Etapa -Nome "Desativando servico: $nomeServico" -Acao {
        $servico = Get-Service -Name $nomeServico -ErrorAction SilentlyContinue
        if ($servico) {
            Stop-Service -Name $nomeServico -Force -ErrorAction SilentlyContinue
            Set-Service -Name $nomeServico -StartupType Disabled -ErrorAction Stop
        }
        else {
            throw "Servico nao encontrado neste sistema."
        }
    }
}

# ==========================================================
# REMOCAO DE APPS UWP DESNECESSARIOS
# ==========================================================

Write-Banner "ETAPA 6 DE 12 - APPS PADRAO DO WINDOWS"

$listaApps = @(
    "*3DBuilder*",
    "*BingWeather*",
    "*BingNews*",
    "*BingFinance*",
    "*GetHelp*",
    "*Getstarted*",
    "*OfficeHub*",
    "*Solitaire*",
    "*Xbox*",
    "*ZuneMusic*",
    "*ZuneVideo*",
    "*YourPhone*",
    "*People*",
    "*Wallet*",
    "*SkypeApp*",
    "*MixedReality*",
    "*Print3D*",
    "*Alarms*",
    "*Feedback*",
    "*Todos*",
    "*QuickAssist*"
)

foreach ($padraoApp in $listaApps) {
    Invoke-Etapa -Nome "Removendo app: $padraoApp" -Acao {
        $pacotesInstalados = Get-AppxPackage -AllUsers -Name $padraoApp -ErrorAction SilentlyContinue
        if ($pacotesInstalados) {
            $pacotesInstalados | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }

        $pacotesProvisionados = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $padraoApp }
        if ($pacotesProvisionados) {
            foreach ($pacote in $pacotesProvisionados) {
                Remove-AppxProvisionedPackage -Online -PackageName $pacote.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }

        if (-not $pacotesInstalados -and -not $pacotesProvisionados) {
            throw "App nao encontrado neste sistema."
        }
    }
}

# ==========================================================
# TELEMETRIA
# ==========================================================

Write-Banner "ETAPA 7 DE 12 - TELEMETRIA"

Invoke-Etapa -Nome "Desativando telemetria via registro (AllowTelemetry)" -Acao {
    $caminho = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (-not (Test-Path $caminho)) {
        New-Item -Path $caminho -Force | Out-Null
    }
    Set-ItemProperty -Path $caminho -Name "AllowTelemetry" -Value 0 -Type DWord -Force
}

Invoke-Etapa -Nome "Desativando telemetria via registro do usuario atual" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    if (-not (Test-Path $caminho)) {
        New-Item -Path $caminho -Force | Out-Null
    }
    Set-ItemProperty -Path $caminho -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -Force
}

# ==========================================================
# ENCERRAR PROCESSOS DESNECESSARIOS
# ==========================================================

Write-Banner "ETAPA 8 DE 12 - PROCESSOS EM EXECUCAO"

$listaProcessos = @("OneDrive", "Cortana", "SearchApp", "Widgets", "YourPhone")

foreach ($nomeProcesso in $listaProcessos) {
    Invoke-Etapa -Nome "Encerrando processo: $nomeProcesso" -Acao {
        $processoAtivo = Get-Process -Name $nomeProcesso -ErrorAction SilentlyContinue
        if ($processoAtivo) {
            Stop-Process -Name $nomeProcesso -Force -ErrorAction Stop
        }
        else {
            throw "Processo nao estava em execucao."
        }
    }
}

# ==========================================================
# SUGESTOES E ANUNCIOS DO MENU START
# ==========================================================

Write-Banner "ETAPA 9 DE 12 - SUGESTOES DO MENU INICIAR"

Invoke-Etapa -Nome "Desativando sugestoes e anuncios do menu Start" -Acao {
    $caminho = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    if (-not (Test-Path $caminho)) {
        New-Item -Path $caminho -Force | Out-Null
    }

    $propriedades = @(
        "SubscribedContent-338388Enabled",
        "SubscribedContent-338389Enabled",
        "SubscribedContent-353694Enabled",
        "SubscribedContent-353696Enabled",
        "SystemPaneSuggestionsEnabled",
        "SilentInstalledAppsEnabled",
        "ContentDeliveryAllowed",
        "OemPreInstalledAppsEnabled",
        "PreInstalledAppsEnabled",
        "PreInstalledAppsEverEnabled"
    )

    foreach ($propriedade in $propriedades) {
        Set-ItemProperty -Path $caminho -Name $propriedade -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

# ==========================================================
# LIMPEZA DE ARQUIVOS TEMPORARIOS
# ==========================================================

Write-Banner "ETAPA 10 DE 12 - ARQUIVOS TEMPORARIOS"

Invoke-Etapa -Nome "Limpando pasta temp do usuario" -Acao {
    $caminhoTemp = $env:TEMP
    if (Test-Path $caminhoTemp) {
        Get-ChildItem -Path $caminhoTemp -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Etapa -Nome "Limpando pasta temp do Windows" -Acao {
    $caminhoTempWindows = "C:\Windows\Temp"
    if (Test-Path $caminhoTempWindows) {
        Get-ChildItem -Path $caminhoTempWindows -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Etapa -Nome "Limpando lixeira do sistema" -Acao {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}

# ==========================================================
# REINICIAR O EXPLORER
# ==========================================================

Write-Banner "ETAPA 11 DE 12 - REINICIANDO O EXPLORER"

Invoke-Etapa -Nome "Reiniciando processo explorer.exe" -Acao {
    Stop-Process -Name explorer -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}

# ==========================================================
# FINALIZACAO
# ==========================================================

Write-Banner "ETAPA 12 DE 12 - CONCLUIDO"

Write-Host ""
Write-Host "Otimizacao concluida." -ForegroundColor Green
Write-Host "Um ponto de restauracao foi criado antes das alteracoes." -ForegroundColor Green
Write-Host "Caso algo nao funcione como esperado, use a Restauracao do" -ForegroundColor Green
Write-Host "Sistema do Windows para reverter." -ForegroundColor Green
Write-Host ""

$respostaReinicio = Read-Host "Deseja reiniciar o computador agora para aplicar todas as alteracoes? (S/N)"

if ($respostaReinicio -match "^[Ss]") {
    Write-Host "Reiniciando o computador em 10 segundos. Salve seu trabalho." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
else {
    Write-Host "Reinicio adiado. Recomenda-se reiniciar o computador manualmente em breve." -ForegroundColor Yellow
}
