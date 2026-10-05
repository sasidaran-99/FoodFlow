# ==============================================================================
# FoodFlow — Microservice Suite Process Launcher
# ==============================================================================

# Load environment variables from .env if present
if (Test-Path ".env") {
    Write-Host "Loading environment variables from .env file..." -ForegroundColor DarkGray
    Get-Content ".env" | ForEach-Object {
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
}

# Validate required sensitive environment variables
if (-not $env:JWT_SECRET) {
    Write-Error "CRITICAL: JWT_SECRET environment variable is not set. Please set it in your environment or in a .env file (copy .env.example to .env)."
    exit 1
}
if (-not $env:DB_PASSWORD) {
    Write-Error "CRITICAL: DB_PASSWORD environment variable is not set. Please set it in your environment or in a .env file (copy .env.example to .env)."
    exit 1
}

if (-not $env:REDIS_HOST) { $env:REDIS_HOST = "localhost" }
if (-not $env:USER_SERVICE_URL) { $env:USER_SERVICE_URL = "http://localhost:8081" }
if (-not $env:RESTAURANT_SERVICE_URL) { $env:RESTAURANT_SERVICE_URL = "http://localhost:8082" }
if (-not $env:ORDER_SERVICE_URL) { $env:ORDER_SERVICE_URL = "http://localhost:8083" }
if (-not $env:PAYMENT_SERVICE_URL) { $env:PAYMENT_SERVICE_URL = "http://localhost:8084" }
if (-not $env:NOTIFICATION_SERVICE_URL) { $env:NOTIFICATION_SERVICE_URL = "http://localhost:8085" }
if (-not $env:DELIVERY_SERVICE_URL) { $env:DELIVERY_SERVICE_URL = "http://localhost:8086" }

if (-not (Test-Path logs)) { New-Item -ItemType Directory -Path logs }

$services = @(
    @{ Name = "user-service"; Jar = "user-service\target\user-service-1.0.0-SNAPSHOT.jar"; Port = 8081 },
    @{ Name = "restaurant-service"; Jar = "restaurant-service\target\restaurant-service-1.0.0-SNAPSHOT.jar"; Port = 8082 },
    @{ Name = "order-service"; Jar = "order-service\target\order-service-1.0.0-SNAPSHOT.jar"; Port = 8083 },
    @{ Name = "payment-service"; Jar = "payment-service\target\payment-service-1.0.0-SNAPSHOT.jar"; Port = 8084 },
    @{ Name = "notification-service"; Jar = "notification-service\target\notification-service-1.0.0-SNAPSHOT.jar"; Port = 8085 },
    @{ Name = "delivery-service"; Jar = "delivery-service\target\delivery-service-1.0.0-SNAPSHOT.jar"; Port = 8086 },
    @{ Name = "api-gateway"; Jar = "api-gateway\target\api-gateway-1.0.0-SNAPSHOT.jar"; Port = 8080 }
)

Write-Host "Starting FoodFlow Microservices..." -ForegroundColor Cyan

foreach ($svc in $services) {
    Write-Host "Launching $($svc.Name)..." -ForegroundColor Yellow
    $logOut = "logs\$($svc.Name).log"
    $logErr = "logs\$($svc.Name)-err.log"
    Start-Process java -ArgumentList "-Duser.timezone=UTC", "-jar", $svc.Jar -RedirectStandardOutput $logOut -RedirectStandardError $logErr
    Start-Sleep -Seconds 2
}

Write-Host "`nWaiting for all services to become healthy..." -ForegroundColor Cyan

$timeoutSeconds = 60
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($svc in $services) {
    $port = $svc.Port
    $online = $false
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSeconds -and -not $online) {
        $conn = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
        if ($conn.TcpTestSucceeded) {
            $online = $true
            Write-Host "  [ONLINE] $($svc.Name) on port $port" -ForegroundColor Green
        } else {
            Start-Sleep -Seconds 2
        }
    }
    if (-not $online) {
        Write-Host "  [TIMEOUT] $($svc.Name) failed to respond on port $port within timeout" -ForegroundColor Red
    }
}

Write-Host "`nAll service ports probed." -ForegroundColor Cyan
