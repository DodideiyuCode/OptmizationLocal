#requires -Version 5.1
<#
    optimize.ps1
    Repositorio: BeniCode634/OptmizationLocal
    Script de otimizacao para Windows 10/11
    Execucao remota recomendada:
    irm https://raw.githubusercontent.com/BeniCode634/OptmizationLocal/main/optimize.ps1 | iex
#>

$ErrorActionPreference = "Stop"
$ScriptUrl = "https://raw.githubusercontent.com/BeniCode634/OptmizationLocal/main/optimize.ps1"

$script:TotalOk = 0
$script:TotalFalhou = 0
$script:HoraInicio = Get-Date
$script:CaminhoLog = Join-Path $env:TEMP ("OptmizationLocal_log_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".txt")

# ==========================================================
# FUNCOES AUXILIARES DE LOG E VISUAL
# ==========================================================

function Write-Log {
    param([string]$Texto)
    try {
        $carimbo = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $script:CaminhoLog -Value "[$carimbo] $Texto" -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Se nem o log conseguir gravar, apenas ignora para nao travar o script.
    }
}

function Write-Animado {
    param(
        [string]$Texto,
        [ConsoleColor]$Cor = "White",
        [int]$AtrasoMs = 6
    )
    foreach ($caractere in $Texto.ToCharArray()) {
        Write-Host -NoNewline $caractere -ForegroundColor $Cor
        Start-Sleep -Milliseconds $AtrasoMs
    }
    Write-Host ""
}

function Write-Banner {
    param([string]$Texto, [int]$Atual = 0, [int]$Total = 0)
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Animado -Texto $Texto -Cor Cyan -AtrasoMs 4
    Write-Host "==========================================================" -ForegroundColor Cyan
    if ($Total -gt 0) {
        Show-Progresso -Atual $Atual -Total $Total
    }
    Write-Log "===== $Texto ====="
}

function Show-Progresso {
    param([int]$Atual, [int]$Total)
    $percentual = [math]::Round(($Atual / $Total) * 100)
    $preenchido = [math]::Round(($percentual / 100) * 30)
    if ($preenchido -gt 30) { $preenchido = 30 }
    $vazio = 30 - $preenchido
    $barra = ("#" * $preenchido) + ("-" * $vazio)
    Write-Host ("  [" + $barra + "] " + $percentual + "%") -ForegroundColor DarkCyan
}

function Write-Step {
    param([string]$Texto)
    Write-Host ""
    Write-Host -NoNewline ">> " -ForegroundColor Yellow
    Write-Animado -Texto $Texto -Cor Yellow -AtrasoMs 5
}

function Write-Ok {
    param([string]$Texto)
    Write-Host "   OK: $Texto" -ForegroundColor Green
    Write-Log "OK: $Texto"
}

function Write-Falhou {
    param([string]$Nome, [string]$MensagemCompleta)
    $primeiraLinha = ($MensagemCompleta -split "`r`n|`n")[0].Trim()
    Write-Host "   FALHOU: $Nome -- $primeiraLinha" -ForegroundColor Red
    Write-Host "   (detalhes completos no log: $script:CaminhoLog)" -ForegroundColor DarkGray
    Write-Log "FALHOU: $Nome -- MENSAGEM COMPLETA: $MensagemCompleta"
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
        $script:TotalOk++
    }
    catch {
        Write-Falhou -Nome $Nome -MensagemCompleta $_.Exception.Message
        $script:TotalFalhou++
    }
}

function Invoke-ComandoExterno {
    param(
        [Parameter(Mandatory)][string]$Executavel,
        [Parameter(Mandatory)][string[]]$Argumentos
    )
    $saida = & $Executavel @Argumentos 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Comando '$Executavel $($Argumentos -join ' ')' retornou codigo $LASTEXITCODE. Saida: $saida"
    }
    return $saida
}

# ==========================================================
# GRAVACAO SEGURA NO REGISTRO (COM FALLBACK EM 3 NIVEIS)
# ==========================================================

function Set-RegistryOwnership {
    param([string]$Caminho)

    if ($Caminho -match "^(HKCU|HKLM):\\(.+)$") {
        $hiveTexto = $Matches[1]
        $subCaminho = $Matches[2]
    }
    else {
        throw "Nao foi possivel interpretar o caminho de registro: $Caminho"
    }

    $hive = switch ($hiveTexto) {
        "HKCU" { [Microsoft.Win32.Registry]::CurrentUser }
        "HKLM" { [Microsoft.Win32.Registry]::LocalMachine }
        default { throw "Hive de registro nao suportado: $hiveTexto" }
    }

    $direitos = [System.Security.AccessControl.RegistryRights]"TakeOwnership, ChangePermissions"
    $chave = $hive.OpenSubKey($subCaminho, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, $direitos)

    if (-not $chave) {
        throw "Chave de registro nao encontrada para assumir posse: $Caminho"
    }

    try {
        $acl = $chave.GetAccessControl()
        $identidadeAtual = [Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl.SetOwner($identidadeAtual)
        $chave.SetAccessControl($acl)

        $regra = New-Object System.Security.AccessControl.RegistryAccessRule($identidadeAtual, "FullControl", "Allow")
        $acl.AddAccessRule($regra)
        $chave.SetAccessControl($acl)
    }
    finally {
        $chave.Close()
    }
}

function Set-RegistryValueSeguro {
    param(
        [Parameter(Mandatory)][string]$Caminho,
        [Parameter(Mandatory)][string]$Nome,
        [Parameter(Mandatory)]$Valor,
        [string]$Tipo = "DWord"
    )

    if (-not (Test-Path $Caminho)) {
        New-Item -Path $Caminho -Force -ErrorAction Stop | Out-Null
    }

    # Nivel 1: cmdlet nativo do PowerShell
    try {
        New-ItemProperty -Path $Caminho -Name $Nome -Value $Valor -PropertyType $Tipo -Force -ErrorAction Stop | Out-Null
        return
    }
    catch {
        Write-Log "Nivel 1 (cmdlet) falhou para '$Caminho\$Nome' -- $($_.Exception.Message)"
    }

    # Nivel 2: reg.exe (bypassa alguns bloqueios de ACL do .NET)
    try {
        $caminhoRegExe = $Caminho -replace "^HKCU:\\", "HKCU\" -replace "^HKLM:\\", "HKLM\"
        $tipoReg = switch ($Tipo) {
            "DWord"  { "REG_DWORD" }
            "String" { "REG_SZ" }
            "Binary" { "REG_BINARY" }
            default  { "REG_SZ" }
        }
        $valorTexto = if ($Tipo -eq "Binary") {
            -join ($Valor | ForEach-Object { $_.ToString("X2") })
        }
        else {
            "$Valor"
        }

        $saidaReg = reg add "$caminhoRegExe" /v "$Nome" /t $tipoReg /d "$valorTexto" /f 2>&1
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Write-Log "Nivel 2 (reg.exe) falhou para '$Caminho\$Nome' -- $saidaReg"
    }
    catch {
        Write-Log "Nivel 2 (reg.exe) gerou excecao para '$Caminho\$Nome' -- $($_.Exception.Message)"
    }

    # Nivel 3: assumir posse da chave e tentar novamente
    try {
        Set-RegistryOwnership -Caminho $Caminho
        New-ItemProperty -Path $Caminho -Name $Nome -Value $Valor -PropertyType $Tipo -Force -ErrorAction Stop | Out-Null
        return
    }
    catch {
        throw "Nao foi possivel gravar '$Nome' em '$Caminho' apos 3 tentativas (cmdlet, reg.exe, posse da chave). Ultimo erro: $($_.Exception.Message)"
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
# TELA DE TERMOS DE USO E RESPONSABILIDADE (SETAS DO TECLADO)
# ==========================================================

function Show-TermoDeUso {
    $opcoes = @("SIM", "NAO")
    $selecionado = 0
    $confirmado = $false

    while (-not $confirmado) {
        Clear-Host
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "  OPTMIZATION LOCAL - TERMOS DE USO E RESPONSABILIDADE" -ForegroundColor Cyan
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
        Write-Host "TERMO DE RESPONSABILIDADE:" -ForegroundColor Magenta
        Write-Host "Este script e fornecido como esta, sem nenhuma garantia."
        Write-Host "Ao selecionar SIM, voce declara estar ciente de que o"
        Write-Host "autor e os mantenedores do repositorio Optmization Local"
        Write-Host "nao se responsabilizam por eventuais danos, perda de"
        Write-Host "dados, instabilidade do sistema, mau funcionamento de"
        Write-Host "hardware ou software, ou qualquer prejuizo direto ou"
        Write-Host "indireto decorrente do uso deste script. O ponto de"
        Write-Host "restauracao e criado automaticamente, mas a decisao de"
        Write-Host "usa-lo para reverter alteracoes e de sua responsabilidade."
        Write-Host "O uso deste script e por sua conta e risco."
        Write-Host ""
        Write-Host "Leia o repositorio completo antes de continuar:"
        Write-Host "https://github.com/BeniCode634/OptmizationLocal"
        Write-Host ""
        Write-Host "Voce concorda com os termos acima e deseja continuar?"
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
Write-Log "Usuario respondeu aos termos de uso: $respostaTermo"

if ($respostaTermo -ne "SIM") {
    Clear-Host
    Write-Host "Voce optou por NAO aceitar os termos." -ForegroundColor Red
    Write-Host "O script sera encerrado sem realizar nenhuma alteracao." -ForegroundColor Red
    exit
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Animado -Texto "OPTMIZATION LOCAL - INICIANDO OTIMIZACAO" -Cor Cyan -AtrasoMs 8
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Animado -Texto "Termos aceitos. Iniciando o processo em instantes..." -Cor Green -AtrasoMs 8
Write-Host "Log detalhado desta execucao: $script:CaminhoLog" -ForegroundColor DarkGray
Start-Sleep -Seconds 1

$totalEtapas = 12

# ==========================================================
# ETAPA 1 - PONTO DE RESTAURACAO DO SISTEMA
# ==========================================================

Write-Banner -Texto "ETAPA 1 DE 12 - PONTO DE RESTAURACAO" -Atual 1 -Total $totalEtapas

Invoke-Etapa -Nome "Habilitando protecao do sistema no disco C" -Acao {
    Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop
}

Invoke-Etapa -Nome "Ajustando intervalo minimo entre pontos de restauracao" -Acao {
    Set-RegistryValueSeguro -Caminho "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Nome "SystemRestorePointCreationFrequency" -Valor 0 -Tipo "DWord"
}

Invoke-Etapa -Nome "Criando ponto de restauracao (Optmization Local)" -Acao {
    Checkpoint-Computer -Description "Optmization Local - Antes da otimizacao" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
}

# ==========================================================
# ETAPA 2 - PLANO DE ENERGIA DE ALTO DESEMPENHO
# ==========================================================

Write-Banner -Texto "ETAPA 2 DE 12 - PLANO DE ENERGIA" -Atual 2 -Total $totalEtapas

Invoke-Etapa -Nome "Criando e ativando plano de Alto Desempenho" -Acao {
    $guidAltoDesempenho = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $planosExistentes = powercfg /list
    if ($planosExistentes -notmatch $guidAltoDesempenho) {
        Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("-duplicatescheme", $guidAltoDesempenho) | Out-Null
    }
    Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("/setactive", $guidAltoDesempenho) | Out-Null
}

Invoke-Etapa -Nome "Desativando timeout de monitor (AC e bateria)" -Acao {
    Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("/change", "monitor-timeout-ac", "0") | Out-Null
    Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("/change", "monitor-timeout-dc", "0") | Out-Null
}

Invoke-Etapa -Nome "Desativando timeout de standby (AC e bateria)" -Acao {
    Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("/change", "standby-timeout-ac", "0") | Out-Null
    Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("/change", "standby-timeout-dc", "0") | Out-Null
}

Invoke-Etapa -Nome "Desativando hibernacao" -Acao {
    Invoke-ComandoExterno -Executavel "powercfg" -Argumentos @("/hibernate", "off") | Out-Null
}

# ==========================================================
# ETAPA 3 - EFEITOS VISUAIS
# ==========================================================

Write-Banner -Texto "ETAPA 3 DE 12 - EFEITOS VISUAIS" -Atual 3 -Total $totalEtapas

Invoke-Etapa -Nome "Desativando transparencia do Windows" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Nome "EnableTransparency" -Valor 0 -Tipo "DWord"
}

Invoke-Etapa -Nome "Ajustando efeitos visuais para melhor desempenho" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Nome "VisualFXSetting" -Valor 2 -Tipo "DWord"

    $mascara = [byte[]](144, 18, 3, 128, 16, 0, 0, 0)
    Set-RegistryValueSeguro -Caminho "HKCU:\Control Panel\Desktop" -Nome "UserPreferencesMask" -Valor $mascara -Tipo "Binary"
}

Invoke-Etapa -Nome "Desativando animacoes de janelas e menus" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Control Panel\Desktop\WindowMetrics" -Nome "MinAnimate" -Valor "0" -Tipo "String"
    Set-RegistryValueSeguro -Caminho "HKCU:\Control Panel\Desktop" -Nome "MenuShowDelay" -Valor "0" -Tipo "String"
}

# ==========================================================
# ETAPA 4 - LIMPEZA DA BARRA DE TAREFAS
# ==========================================================

Write-Banner -Texto "ETAPA 4 DE 12 - BARRA DE TAREFAS" -Atual 4 -Total $totalEtapas

Invoke-Etapa -Nome "Ocultando botao Task View" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Nome "ShowTaskViewButton" -Valor 0 -Tipo "DWord"
}

Invoke-Etapa -Nome "Desativando Widgets na barra de tarefas" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Nome "TaskbarDa" -Valor 0 -Tipo "DWord"
    Set-RegistryValueSeguro -Caminho "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Nome "AllowNewsAndInterests" -Valor 0 -Tipo "DWord"
}

Invoke-Etapa -Nome "Desativando icone de Chat/Teams na barra de tarefas" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Nome "TaskbarMn" -Valor 0 -Tipo "DWord"
}

Invoke-Etapa -Nome "Desativando Copilot do Windows" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Nome "ShowCopilotButton" -Valor 0 -Tipo "DWord"
    Set-RegistryValueSeguro -Caminho "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Nome "TurnOffWindowsCopilot" -Valor 1 -Tipo "DWord"
}

# ==========================================================
# ETAPA 5 - SERVICOS NAO ESSENCIAIS
# ==========================================================

Write-Banner -Texto "ETAPA 5 DE 12 - SERVICOS DO WINDOWS" -Atual 5 -Total $totalEtapas

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
            throw "Servico nao encontrado neste sistema (normal em algumas edicoes do Windows)."
        }
    }
}

# ==========================================================
# ETAPA 6 - REMOCAO DE APPS UWP DESNECESSARIOS
# ==========================================================

Write-Banner -Texto "ETAPA 6 DE 12 - APPS PADRAO DO WINDOWS" -Atual 6 -Total $totalEtapas

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
        $encontrouAlgumaCoisa = $false
        $falhouRemocao = $false
        $ultimoErro = ""

        $pacotesInstalados = Get-AppxPackage -AllUsers -Name $padraoApp -ErrorAction SilentlyContinue
        if ($pacotesInstalados) {
            $encontrouAlgumaCoisa = $true
            foreach ($pacote in $pacotesInstalados) {
                try {
                    $pacote | Remove-AppxPackage -AllUsers -ErrorAction Stop
                }
                catch {
                    $falhouRemocao = $true
                    $ultimoErro = $_.Exception.Message
                }
            }
        }

        $pacotesProvisionados = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $padraoApp }
        if ($pacotesProvisionados) {
            $encontrouAlgumaCoisa = $true
            foreach ($pacote in $pacotesProvisionados) {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pacote.PackageName -ErrorAction Stop | Out-Null
                }
                catch {
                    $falhouRemocao = $true
                    $ultimoErro = $_.Exception.Message
                }
            }
        }

        if (-not $encontrouAlgumaCoisa) {
            throw "App nao encontrado neste sistema."
        }

        if ($falhouRemocao) {
            throw "App protegido pelo sistema, nao pode ser removido nesta build do Windows. Detalhe: $ultimoErro"
        }
    }
}

# ==========================================================
# ETAPA 7 - TELEMETRIA
# ==========================================================

Write-Banner -Texto "ETAPA 7 DE 12 - TELEMETRIA" -Atual 7 -Total $totalEtapas

Invoke-Etapa -Nome "Desativando telemetria via registro (AllowTelemetry)" -Acao {
    Set-RegistryValueSeguro -Caminho "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Nome "AllowTelemetry" -Valor 0 -Tipo "DWord"
}

Invoke-Etapa -Nome "Desativando telemetria via registro do usuario atual" -Acao {
    Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Nome "TailoredExperiencesWithDiagnosticDataEnabled" -Valor 0 -Tipo "DWord"
}

# ==========================================================
# ETAPA 8 - ENCERRAR PROCESSOS DESNECESSARIOS
# ==========================================================

Write-Banner -Texto "ETAPA 8 DE 12 - PROCESSOS EM EXECUCAO" -Atual 8 -Total $totalEtapas

$listaProcessos = @("OneDrive", "Cortana", "SearchApp", "Widgets", "YourPhone")

foreach ($nomeProcesso in $listaProcessos) {
    Invoke-Etapa -Nome "Encerrando processo: $nomeProcesso" -Acao {
        $processoAtivo = Get-Process -Name $nomeProcesso -ErrorAction SilentlyContinue
        if ($processoAtivo) {
            Stop-Process -Name $nomeProcesso -Force -ErrorAction Stop
        }
        else {
            throw "Processo nao estava em execucao (nada a fazer)."
        }
    }
}

# ==========================================================
# ETAPA 9 - SUGESTOES E ANUNCIOS DO MENU START
# ==========================================================

Write-Banner -Texto "ETAPA 9 DE 12 - SUGESTOES DO MENU INICIAR" -Atual 9 -Total $totalEtapas

$propriedadesContentDelivery = @(
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

foreach ($propriedade in $propriedadesContentDelivery) {
    Invoke-Etapa -Nome "Desativando sugestao do menu Start: $propriedade" -Acao {
        Set-RegistryValueSeguro -Caminho "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Nome $propriedade -Valor 0 -Tipo "DWord"
    }
}

# ==========================================================
# ETAPA 10 - LIMPEZA DE ARQUIVOS TEMPORARIOS
# ==========================================================

Write-Banner -Texto "ETAPA 10 DE 12 - ARQUIVOS TEMPORARIOS" -Atual 10 -Total $totalEtapas

Invoke-Etapa -Nome "Limpando pasta temp do usuario" -Acao {
    $caminhoTemp = $env:TEMP
    if (Test-Path $caminhoTemp) {
        Get-ChildItem -Path $caminhoTemp -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Etapa -Nome "Limpando pasta temp do Windows" -Acao {
    $caminhoTempWindows = "C:\Windows\Temp"
    if (Test-Path $caminhoTempWindows) {
        Get-ChildItem -Path $caminhoTempWindows -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Etapa -Nome "Limpando lixeira do sistema" -Acao {
    Clear-RecycleBin -Force -ErrorAction Stop
}

# ==========================================================
# ETAPA 11 - REINICIAR O EXPLORER
# ==========================================================

Write-Banner -Texto "ETAPA 11 DE 12 - REINICIANDO O EXPLORER" -Atual 11 -Total $totalEtapas

Invoke-Etapa -Nome "Reiniciando processo explorer.exe" -Acao {
    Stop-Process -Name explorer -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}

# ==========================================================
# ETAPA 12 - FINALIZACAO E RESUMO
# ==========================================================

Write-Banner -Texto "ETAPA 12 DE 12 - CONCLUIDO" -Atual 12 -Total $totalEtapas

$duracaoTotal = (Get-Date) - $script:HoraInicio
$duracaoFormatada = "{0:mm} min {0:ss} seg" -f $duracaoTotal

Write-Host ""
Write-Animado -Texto "Otimizacao concluida." -Cor Green -AtrasoMs 10
Write-Host ""
Write-Host "  Resumo da execucao" -ForegroundColor Cyan
Write-Host "  -------------------"
Write-Host ("  Etapas concluidas com sucesso : " + $script:TotalOk) -ForegroundColor Green
Write-Host ("  Etapas com falha              : " + $script:TotalFalhou) -ForegroundColor $(if ($script:TotalFalhou -gt 0) { "Yellow" } else { "Green" })
Write-Host ("  Tempo total de execucao       : " + $duracaoFormatada)
Write-Host ("  Log completo salvo em         : " + $script:CaminhoLog)
Write-Host ""
Write-Host "Um ponto de restauracao foi criado antes das alteracoes." -ForegroundColor Green
Write-Host "Caso algo nao funcione como esperado, use a Restauracao do" -ForegroundColor Green
Write-Host "Sistema do Windows para reverter." -ForegroundColor Green
Write-Host ""

if ($script:TotalFalhou -gt 0) {
    Write-Host "Algumas etapas falharam (normal em varias edicoes/versoes" -ForegroundColor Yellow
    Write-Host "do Windows, onde certos apps/servicos ja nao existem ou" -ForegroundColor Yellow
    Write-Host "sao protegidos pelo sistema). Consulte o log para detalhes." -ForegroundColor Yellow
    Write-Host ""
}

Write-Log "===== RESUMO FINAL: $script:TotalOk OK / $script:TotalFalhou FALHOU / Duracao $duracaoFormatada ====="

$respostaReinicio = Read-Host "Deseja reiniciar o computador agora para aplicar todas as alteracoes? (S/N)"

if ($respostaReinicio -match "^[Ss]") {
    Write-Host "Reiniciando o computador em 10 segundos. Salve seu trabalho." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}
else {
    Write-Host "Reinicio adiado. Recomenda-se reiniciar o computador manualmente em breve." -ForegroundColor Yellow
}
