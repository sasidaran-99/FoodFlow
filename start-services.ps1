# ==============================================================================
# FoodFlow - Microservice Suite Process Launcher
# Starts and health-checks all FoodFlow backend microservices on Windows
# ==============================================================================

[CmdletBinding()]
param (
    [int]$TimeoutSeconds = 120,
    [switch]$ForceRestart
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         FOODFLOW MICROSERVICE PROCESS LAUNCHER           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load environment variables from .env if present
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Write-Host "[1/6] Loading environment variables from .env file..." -ForegroundColor DarkGray
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $varName = $parts[0].Trim()
            $varVal = $parts[1].Trim()
            if (-not [System.Environment]::GetEnvironmentVariable($varName, "Process")) {
                [System.Environment]::SetEnvironmentVariable($varName, $varVal, "Process")
            }
        }
    }
} else {
    Write-Host "[1/6] No .env file found; using existing environment variables." -ForegroundColor DarkGray
}

# 2. Validate required secrets
Write-Host "[2/6] Validating required configuration..." -ForegroundColor DarkGray
$missingConfigs = @()
if (-not $env:JWT_SECRET) { $missingConfigs += "JWT_SECRET" }
if (-not $env:DB_PASSWORD) { $missingConfigs += "DB_PASSWORD" }

if ($missingConfigs.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: Missing required environment variable(s): $($missingConfigs -join ', ')" -ForegroundColor Red
    Write-Host "Please create a .env file from .env.example or set the environment variables in PowerShell:" -ForegroundColor Yellow
    Write-Host "  Copy-Item .env.example .env" -ForegroundColor Yellow
    Write-Host "  (Then set your secure DB_PASSWORD and JWT_SECRET values in .env)" -ForegroundColor Yellow
    exit 1
}

# 3. Setup Default Infrastructure & Inter-Service URLs
if (-not $env:DB_HOST) { $env:DB_HOST = "localhost" }
if (-not $env:DB_PORT) { $env:DB_PORT = "5433" }
if (-not $env:DB_USER) { $env:DB_USER = "foodflow" }
if (-not $env:REDIS_HOST) { $env:REDIS_HOST = "localhost" }
if (-not $env:REDIS_PORT) { $env:REDIS_PORT = "6379" }
if (-not $env:KAFKA_BOOTSTRAP_SERVERS) { $env:KAFKA_BOOTSTRAP_SERVERS = "localhost:9092" }
if (-not $env:USER_SERVICE_URL) { $env:USER_SERVICE_URL = "http://localhost:8081" }
if (-not $env:RESTAURANT_SERVICE_URL) { $env:RESTAURANT_SERVICE_URL = "http://localhost:8082" }
if (-not $env:ORDER_SERVICE_URL) { $env:ORDER_SERVICE_URL = "http://localhost:8083" }
if (-not $env:PAYMENT_SERVICE_URL) { $env:PAYMENT_SERVICE_URL = "http://localhost:8084" }
if (-not $env:NOTIFICATION_SERVICE_URL) { $env:NOTIFICATION_SERVICE_URL = "http://localhost:8085" }
if (-not $env:DELIVERY_SERVICE_URL) { $env:DELIVERY_SERVICE_URL = "http://localhost:8086" }

# 4. Resolve Gateway Port (Avoid conflicts with external apps like SynTrace on port 8080)
$gatewayPort = if ($env:GATEWAY_PORT) { [int]$env:GATEWAY_PORT } else { 8080 }

if ($gatewayPort -eq 8080) {
    $conn8080 = Test-NetConnection -ComputerName 127.0.0.1 -Port 8080 -WarningAction SilentlyContinue
    if ($conn8080.TcpTestSucceeded) {
        $isFoodFlowGateway = $false
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:8080/actuator/health" -TimeoutSec 2 -ErrorAction Stop
            if ($resp.status -eq "UP" -and $resp.components.redis) {
                $isFoodFlowGateway = $true
            }
        } catch {}

        if (-not $isFoodFlowGateway) {
            Write-Host ""
            Write-Host "[NOTICE] Port 8080 is occupied by an external service (e.g. SynTrace container)." -ForegroundColor Yellow
            Write-Host "[NOTICE] Routing FoodFlow API Gateway to port 8087 for local development." -ForegroundColor Yellow
            $gatewayPort = 8087
            $env:GATEWAY_PORT = "8087"
        }
    }
}

# 5. Define services and pre-flight JAR verification
$services = @(
    @{ Name = "user-service";         Jar = Join-Path $PSScriptRoot "user-service\target\user-service-1.0.0-SNAPSHOT.jar";                 Port = 8081 },
    @{ Name = "restaurant-service";   Jar = Join-Path $PSScriptRoot "restaurant-service\target\restaurant-service-1.0.0-SNAPSHOT.jar";     Port = 8082 },
    @{ Name = "order-service";        Jar = Join-Path $PSScriptRoot "order-service\target\order-service-1.0.0-SNAPSHOT.jar";               Port = 8083 },
    @{ Name = "payment-service";      Jar = Join-Path $PSScriptRoot "payment-service\target\payment-service-1.0.0-SNAPSHOT.jar";           Port = 8084 },
    @{ Name = "notification-service"; Jar = Join-Path $PSScriptRoot "notification-service\target\notification-service-1.0.0-SNAPSHOT.jar"; Port = 8085 },
    @{ Name = "delivery-service";     Jar = Join-Path $PSScriptRoot "delivery-service\target\delivery-service-1.0.0-SNAPSHOT.jar";         Port = 8086 },
    @{ Name = "api-gateway";          Jar = Join-Path $PSScriptRoot "api-gateway\target\api-gateway-1.0.0-SNAPSHOT.jar";                   Port = $gatewayPort }
)

Write-Host "[3/6] Verifying packaged JAR artifacts..." -ForegroundColor DarkGray
$missingJars = @()
foreach ($svc in $services) {
    if (-not (Test-Path $svc.Jar)) {
        $missingJars += $svc.Jar
    }
}

if ($missingJars.Count -gt 0) {
    Write-Host ""
    Write-Host "ERROR: The following microservice JAR artifacts were not found:" -ForegroundColor Red
    foreach ($jar in $missingJars) {
        Write-Host "  - $jar" -ForegroundColor Red
    }
    Write-Host "`nPlease build all services first by running:" -ForegroundColor Yellow
    Write-Host "  mvn clean package -DskipTests" -ForegroundColor Yellow
    exit 1
}

# Ensure logs directory exists
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

# 6. Check Infrastructure Readiness
Write-Host "[4/6] Probing backend infrastructure..." -ForegroundColor DarkGray
$infraChecks = @(
    @{ Name = "PostgreSQL (foodflow-postgres)"; Port = [int]$env:DB_PORT },
    @{ Name = "Redis (foodflow-redis)";         Port = [int]$env:REDIS_PORT },
    @{ Name = "Kafka (foodflow-kafka)";         Port = 9092 }
)

foreach ($infra in $infraChecks) {
    $conn = Test-NetConnection -ComputerName 127.0.0.1 -Port $infra.Port -WarningAction SilentlyContinue
    if ($conn.TcpTestSucceeded) {
        Write-Host "  [OK] $($infra.Name) reachable on port $($infra.Port)" -ForegroundColor Green
    } else {
        Write-Warning "Cannot connect to $($infra.Name) on port $($infra.Port). Ensure Docker containers are running (docker compose up -d)."
    }
}

# 7. Launch Services
Write-Host "`n[5/6] Starting FoodFlow Microservices..." -ForegroundColor Cyan

$processMap = @{}
$alreadyRunning = @{}

foreach ($svc in $services) {
    $port = $svc.Port
    $healthUrl = "http://localhost:$port/actuator/health"
    
    # Check if already running and healthy
    $isHealthy = $false
    try {
        $res = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2 -ErrorAction Stop
        if ($res.status -eq "UP") { $isHealthy = $true }
    } catch {}

    if ($isHealthy -and -not $ForceRestart) {
        Write-Host "  [RUNNING] $($svc.Name) is already healthy on port $port." -ForegroundColor Green
        $alreadyRunning[$svc.Name] = $true
        continue
    }

    $logOut = Join-Path $logsDir "$($svc.Name).log"
    $logErr = Join-Path $logsDir "$($svc.Name)-err.log"

    Write-Host "  Launching $($svc.Name) on port $port..." -ForegroundColor Yellow
    $javaArgs = @(
        "-Duser.timezone=UTC",
        "-Dserver.port=$port",
        "-DDB_HOST=$($env:DB_HOST)",
        "-DDB_PORT=$($env:DB_PORT)",
        "-DDB_USER=$($env:DB_USER)",
        "-DDB_PASSWORD=$($env:DB_PASSWORD)",
        "-DJWT_SECRET=$($env:JWT_SECRET)",
        "-DREDIS_HOST=$($env:REDIS_HOST)",
        "-DREDIS_PORT=$($env:REDIS_PORT)",
        "-DKAFKA_BOOTSTRAP_SERVERS=$($env:KAFKA_BOOTSTRAP_SERVERS)",
        "-DGATEWAY_PORT=$gatewayPort",
        "-jar",
        $svc.Jar
    )

    $proc = Start-Process java -ArgumentList $javaArgs -WorkingDirectory $PSScriptRoot -PassThru -RedirectStandardOutput $logOut -RedirectStandardError $logErr
    $processMap[$svc.Name] = $proc

    Start-Sleep -Milliseconds 800
    if ($proc.HasExited) {
        $exitCode = $proc.ExitCode
        Write-Host "  [FAILED] $($svc.Name) exited immediately with code $exitCode." -ForegroundColor Red
        if (Test-Path $logErr) {
            $errContent = Get-Content $logErr -Tail 10
            if ($errContent) {
                Write-Host "  Error output:" -ForegroundColor Red
                $errContent | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
            }
        }
    }
}

# 8. Wait for Health Endpoints
Write-Host "`n[6/6] Waiting for services to pass Actuator health checks - Timeout: $TimeoutSeconds seconds..." -ForegroundColor Cyan

$results = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($svc in $services) {
    $port = $svc.Port
    $healthUrl = "http://localhost:$port/actuator/health"
    $healthy = $false

    if ($alreadyRunning[$svc.Name]) {
        $healthy = $true
        $results += [PSCustomObject]@{
            Service = $svc.Name
            Port    = $port
            Status  = "UP"
            Health  = "Healthy - Already Running"
        }
        continue
    }

    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds -and -not $healthy) {
        $proc = $processMap[$svc.Name]
        if ($proc -and $proc.HasExited) {
            break
        }

        try {
            $res = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 3 -ErrorAction Stop
            if ($res.status -eq "UP") {
                $healthy = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    }

    if ($healthy) {
        Write-Host "  [HEALTHY] $($svc.Name) on port $port is UP ($([math]::Round($sw.Elapsed.TotalSeconds))s)" -ForegroundColor Green
        $results += [PSCustomObject]@{
            Service = $svc.Name
            Port    = $port
            Status  = "UP"
            Health  = "Healthy"
        }
    } else {
        $proc = $processMap[$svc.Name]
        $exited = ($proc -and $proc.HasExited)
        $statusMsg = if ($exited) { "Exited with code $($proc.ExitCode)" } else { "Timeout" }
        Write-Host "  [FAILED] $($svc.Name) on port $port ($statusMsg)" -ForegroundColor Red
        
        $logErr = Join-Path $logsDir "$($svc.Name)-err.log"
        if (Test-Path $logErr) {
            $errTail = Get-Content $logErr -Tail 5
            if ($errTail) {
                $errTail | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
            }
        }

        $results += [PSCustomObject]@{
            Service = $svc.Name
            Port    = $port
            Status  = "FAILED"
            Health  = $statusMsg
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "                 SERVICE STATUS SUMMARY                   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$allUp = ($results | Where-Object { $_.Status -ne "UP" }).Count -eq 0
if ($allUp) {
    Write-Host "[SUCCESS] All FoodFlow microservices are UP and healthy!" -ForegroundColor Green
    Write-Host "API Gateway entry point: http://localhost:$gatewayPort" -ForegroundColor Cyan
    Write-Host "Frontend web application: http://localhost:3000" -ForegroundColor Cyan
} else {
    Write-Host "[WARNING] Some services failed to start. Check logs in the 'logs/' folder." -ForegroundColor Yellow
}
