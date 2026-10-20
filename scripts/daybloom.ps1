<#
  Daybloom — utilitário de desenvolvimento para Windows.
  Uso: powershell -ExecutionPolicy Bypass -File scripts\daybloom.ps1 <comando>
  Comandos: preparar | instalar | backend | godot | editor | jogo | testes | verificar
  Nenhum caminho absoluto é fixo: tudo é relativo à pasta do repositório.
#>
param(
    [Parameter(Position = 0)][string]$Comando = "ajuda",
    [switch]$BaixarGodot
)

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $PSScriptRoot
$Backend = Join-Path $Raiz "backend"
$Jogo = Join-Path $Raiz "game"
$Ferramentas = Join-Path $Raiz "tools"
$Venv = Join-Path $Backend ".venv"
$VenvPython = Join-Path $Venv "Scripts\python.exe"
$GodotVersao = "4.7.1"

function Escrever([string]$texto, [string]$cor = "Gray") { Write-Host $texto -ForegroundColor $cor }
function Titulo([string]$texto) { Write-Host ""; Write-Host "== $texto ==" -ForegroundColor Cyan }

function Ler-Env {
    # Carrega backend\.env (se existir) para o processo atual, sem sobrescrever.
    $arquivo = Join-Path $Backend ".env"
    if (Test-Path $arquivo) {
        foreach ($linha in Get-Content $arquivo -Encoding UTF8) {
            $l = $linha.Trim()
            if ($l -eq "" -or $l.StartsWith("#") -or -not $l.Contains("=")) { continue }
            $partes = $l.Split("=", 2)
            if (-not [Environment]::GetEnvironmentVariable($partes[0].Trim(), "Process")) {
                [Environment]::SetEnvironmentVariable($partes[0].Trim(), $partes[1].Trim().Trim('"'), "Process")
            }
        }
    }
}

function Porta-Backend { if ($env:DAYBLOOM_PORT) { return $env:DAYBLOOM_PORT } return "8765" }

function Encontrar-Python {
    $candidatos = @()
    if (Get-Command py -ErrorAction SilentlyContinue) { $candidatos += ,@("py", "-3") }
    foreach ($nome in @("python", "python3")) {
        $cmd = Get-Command $nome -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -notlike "*WindowsApps*") { $candidatos += ,@($cmd.Source) }
    }
    $anaconda = Join-Path $env:USERPROFILE "anaconda3\python.exe"
    if (Test-Path $anaconda) { $candidatos += ,@($anaconda) }
    foreach ($c in $candidatos) {
        try {
            $exe = $c[0]; $extra = @($c | Select-Object -Skip 1)
            $versao = & $exe @extra -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
            if ($LASTEXITCODE -eq 0 -and $versao) {
                $p = $versao.Trim().Split(".")
                if ([int]$p[0] -eq 3 -and [int]$p[1] -ge 10) { return ,$c }
            }
        } catch { }
    }
    return $null
}

function Encontrar-Godot {
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $salvo = Join-Path $Ferramentas "godot_path.txt"
    if (Test-Path $salvo) {
        $p = (Get-Content $salvo -Encoding UTF8 | Select-Object -First 1).Trim()
        if ($p -and (Test-Path $p)) { return $p }
    }
    $locais = @(
        (Join-Path $Ferramentas "godot"),
        (Join-Path $env:LOCALAPPDATA "Programs\Godot"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"),
        (Join-Path $env:ProgramFiles "Godot"),
        (Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps\common\Godot Engine"),
        (Join-Path $env:USERPROFILE "Downloads"),
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "OneDrive\Desktop"),
        (Join-Path $env:USERPROFILE "Documents"),
        (Join-Path $env:USERPROFILE "Godot"),
        "C:\Godot"
    )
    $achados = @()
    foreach ($local in $locais) {
        if ($local -and (Test-Path $local)) {
            $achados += Get-ChildItem -Path $local -Filter "Godot*.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match "^Godot_v4\.[4-9]|^godot\.windows|^Godot\.exe$|^Godot_v4" }
        }
    }
    foreach ($nome in @("godot", "godot4", "Godot")) {
        $cmd = Get-Command $nome -ErrorAction SilentlyContinue
        if ($cmd) { $achados += Get-Item $cmd.Source }
    }
    if ($achados.Count -eq 0) { return $null }
    # Prefere a versão de console (mostra a saída no terminal) e a mais nova.
    $ordenados = $achados | Sort-Object @{Expression = { $_.Name -match "4\.7" }; Descending = $true }, @{Expression = { $_.Name -notmatch "console" }; Descending = $false }, Name -Descending
    $escolhido = $ordenados | Select-Object -First 1
    New-Item -ItemType Directory -Force -Path $Ferramentas | Out-Null
    Set-Content -Path $salvo -Value $escolhido.FullName -Encoding UTF8
    return $escolhido.FullName
}

function Godot-Console([string]$exe) {
    # Para testes, usa o executável de console quando existir ao lado do normal.
    if ($exe -match "_console\.exe$") { return $exe }
    $console = $exe -replace "\.exe$", "_console.exe"
    if (Test-Path $console) { return $console }
    return $exe
}

function Baixar-Godot {
    $destino = Join-Path $Ferramentas "godot"
    New-Item -ItemType Directory -Force -Path $destino | Out-Null
    $zip = Join-Path $destino "godot.zip"
    $url = "https://github.com/godotengine/godot/releases/download/$GodotVersao-stable/Godot_v$GodotVersao-stable_win64.exe.zip"
    Escrever "Baixando Godot $GodotVersao de $url ..." "Yellow"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $destino -Force
    Remove-Item $zip
    Remove-Item (Join-Path $Ferramentas "godot_path.txt") -ErrorAction SilentlyContinue
    return (Encontrar-Godot)
}

function Exigir-Godot {
    $g = Encontrar-Godot
    if (-not $g) {
        Escrever "Godot 4.7 não encontrado." "Red"
        Escrever "Defina a variável GODOT_BIN com o caminho do executável, ou rode: scripts\preparar_ambiente.bat -BaixarGodot" "Yellow"
        exit 3
    }
    return $g
}

function Importar-Projeto([string]$godot, [switch]$Forcar) {
    $cache = Join-Path $Jogo ".godot\global_script_class_cache.cfg"
    if ($Forcar -or -not (Test-Path $cache)) {
        Escrever "Importando o projeto Godot (primeira execução)..." "Yellow"
        $exe = Godot-Console $godot
        & $exe --headless --path $Jogo --import 2>&1 | Out-Null
    }
}

function Testar-Mongo {
    if (-not (Test-Path $VenvPython)) { Escrever "[ERRO] Ambiente Python não instalado (rode scripts\instalar_dependencias.bat)" "Red"; return $false }
    Push-Location $Backend
    try { & $VenvPython -m app.check; return ($LASTEXITCODE -eq 0) } finally { Pop-Location }
}

function Backend-Ativo {
    try {
        $r = Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/health" -f (Porta-Backend)) -TimeoutSec 2
        return $r
    } catch { return $null }
}

function Cmd-Instalar {
    Titulo "Instalando dependências Python"
    $py = Encontrar-Python
    if (-not $py) { Escrever "Python 3.10+ não encontrado. Instale em https://www.python.org/downloads/" "Red"; exit 2 }
    $exe = $py[0]; $extra = @($py | Select-Object -Skip 1)
    if (-not (Test-Path $VenvPython)) {
        Escrever "Criando ambiente virtual em backend\.venv ..."
        & $exe @extra -m venv $Venv
        if ($LASTEXITCODE -ne 0) { Escrever "Falha ao criar o ambiente virtual." "Red"; exit 2 }
    }
    & $VenvPython -m pip install --upgrade pip --quiet
    & $VenvPython -m pip install -r (Join-Path $Backend "requirements-dev.txt")
    if ($LASTEXITCODE -ne 0) { Escrever "Falha ao instalar dependências." "Red"; exit 2 }
    Escrever "Dependências instaladas." "Green"
}

function Cmd-Preparar {
    Titulo "Preparando o ambiente do Daybloom"
    Cmd-Instalar
    $envArq = Join-Path $Backend ".env"
    if (-not (Test-Path $envArq)) {
        Copy-Item (Join-Path $Backend ".env.example") $envArq
        Escrever "Criado backend\.env a partir de .env.example" "Green"
    }
    Ler-Env
    Titulo "Serviços locais"
    $mongoOk = Testar-Mongo
    if (-not $mongoOk) { Escrever "Inicie o MongoDB Community Server (serviço 'MongoDB') para salvar partidas." "Yellow" }
    Titulo "Godot"
    $g = Encontrar-Godot
    if (-not $g -and $BaixarGodot) { $g = Baixar-Godot }
    if ($g) {
        Escrever "Godot encontrado: $g" "Green"
        Importar-Projeto $g -Forcar
        Escrever "Projeto importado." "Green"
    } else {
        Escrever "Godot não encontrado. Defina GODOT_BIN ou rode novamente com -BaixarGodot." "Yellow"
    }
    Escrever ""
    Escrever "Pronto! Use scripts\iniciar_jogo.bat para jogar." "Green"
}

function Cmd-Backend {
    Ler-Env
    if (-not (Test-Path $VenvPython)) { Escrever "Rode scripts\instalar_dependencias.bat primeiro." "Red"; exit 2 }
    if (-not (Testar-Mongo)) { Escrever "Atenção: o MongoDB está inacessível; o jogo não conseguirá salvar." "Yellow" }
    Push-Location $Backend
    try { & $VenvPython -m app } finally { Pop-Location }
}

function Cmd-Godot([switch]$Editor) {
    $g = Exigir-Godot
    Importar-Projeto $g
    if ($Editor) { & $g --path $Jogo -e } else { & $g --path $Jogo }
}

function Cmd-Jogo {
    Ler-Env
    $g = Exigir-Godot
    Importar-Projeto $g
    $processo = $null
    $saude = Backend-Ativo
    if (-not $saude) {
        if (-not (Test-Path $VenvPython)) { Escrever "Rode scripts\preparar_ambiente.bat primeiro." "Red"; exit 2 }
        if (-not (Testar-Mongo)) { Escrever "O MongoDB está inacessível: você poderá jogar, mas não salvar." "Yellow" }
        Escrever "Iniciando backend local..."
        $processo = Start-Process -FilePath $VenvPython -ArgumentList "-m", "app" -WorkingDirectory $Backend -WindowStyle Minimized -PassThru
        for ($i = 0; $i -lt 40 -and -not $saude; $i++) { Start-Sleep -Milliseconds 500; $saude = Backend-Ativo }
        if (-not $saude) { Escrever "O backend não respondeu; o jogo abrirá sem salvamento." "Yellow" }
    }
    if ($saude) {
        $m = if ($saude.mongo.ok) { "MongoDB conectado" } else { "MongoDB indisponível" }
        $o = if ($saude.ollama.reachable) { "Ollama ativo" } else { "Ollama indisponível (diálogos clássicos)" }
        Escrever "Backend ativo: $m · $o" "Green"
    }
    Escrever "Abrindo o Daybloom..."
    $jogo = Start-Process -FilePath $g -ArgumentList "--path", "`"$Jogo`"" -PassThru
    $jogo.WaitForExit()
    if ($processo -and -not $processo.HasExited) {
        Escrever "Encerrando backend local..."
        Stop-Process -Id $processo.Id -ErrorAction SilentlyContinue
    }
}

function Cmd-Testes {
    Ler-Env
    $falhas = 0
    Titulo "Testes do backend (pytest)"
    if (-not (Test-Path $VenvPython)) { Escrever "Rode scripts\instalar_dependencias.bat primeiro." "Red"; exit 2 }
    $mongoOk = Testar-Mongo
    if (-not $mongoOk) { Escrever "MongoDB inacessível: os testes de integração com o banco serão IGNORADOS (não aprovados)." "Yellow" }
    Push-Location $Backend
    try { & $VenvPython -m pytest -q; if ($LASTEXITCODE -ne 0) { $falhas++ } } finally { Pop-Location }

    Titulo "Testes do jogo (Godot headless)"
    $g = Exigir-Godot
    $exe = Godot-Console $g
    Importar-Projeto $g
    $saida = Join-Path $Jogo "tests\output"
    New-Item -ItemType Directory -Force -Path $saida | Out-Null
    $resultado = Join-Path $saida "resultado_godot.json"
    Remove-Item $resultado -ErrorAction SilentlyContinue
    $log = Join-Path $saida "godot_testes.log"
    & $exe --headless --fixed-fps 60 --path $Jogo --log-file $log res://tests/test_runner.tscn 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match "^(\[|  OK|  FALHOU|      -|===)" } | ForEach-Object { Write-Host $_ }
    if (Test-Path $resultado) {
        $r = Get-Content $resultado -Raw -Encoding UTF8 | ConvertFrom-Json
        $cor = if ($r.failed -eq 0) { "Green" } else { "Red" }
        Escrever ("Godot: {0} testes, {1} falhas" -f $r.total, $r.failed) $cor
        foreach ($t in $r.results) { if (-not $t.ok) { Escrever ("  FALHOU {0}::{1}" -f $t.suite, $t.test) "Red"; foreach ($f in $t.failures) { Escrever "    - $f" "Red" } } }
        if ($r.failed -ne 0) { $falhas++ }
    } else {
        Escrever "Os testes do Godot não produziram resultado (veja $log)." "Red"
        $falhas++
    }
    Titulo "Resumo"
    if ($falhas -eq 0) { Escrever "Todos os testes passaram." "Green" } else { Escrever "Há falhas nos testes." "Red" }
    exit $falhas
}

function Cmd-Verificar {
    Ler-Env
    Titulo "Verificação do ambiente"
    $py = Encontrar-Python
    if ($py) { Escrever ("Python: " + ($py -join " ")) "Green" } else { Escrever "Python 3.10+: não encontrado" "Red" }
    if (Test-Path $VenvPython) { Escrever "Ambiente virtual: OK" "Green" } else { Escrever "Ambiente virtual: ausente" "Yellow" }
    $g = Encontrar-Godot
    if ($g) { Escrever "Godot: $g" "Green" } else { Escrever "Godot: não encontrado" "Red" }
    if (Test-Path $VenvPython) { Testar-Mongo | Out-Null }
    $s = Backend-Ativo
    if ($s) { Escrever "Backend: ativo na porta $(Porta-Backend)" "Green" } else { Escrever "Backend: desligado" "Yellow" }
}

switch ($Comando.ToLower()) {
    "preparar" { Cmd-Preparar }
    "instalar" { Cmd-Instalar }
    "backend" { Cmd-Backend }
    "godot" { Cmd-Godot }
    "editor" { Cmd-Godot -Editor }
    "jogo" { Cmd-Jogo }
    "testes" { Cmd-Testes }
    "verificar" { Cmd-Verificar }
    default {
        Escrever "Comandos: preparar | instalar | backend | godot | editor | jogo | testes | verificar"
    }
}
