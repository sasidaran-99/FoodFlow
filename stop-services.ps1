# ==============================================================================
# FoodFlow - Microservice Suite Process Stopper
# Gracefully stops all FoodFlow microservice instances running on ports 8081-8087
# (Never touches SynTrace containers on 8080 or 5432)
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         FOODFLOW MICROSERVICE PROCESS STOPPER            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$ports = 8081..8087
$stoppedCount = 0

foreach ($port in $ports) {
    try {
        $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
        if ($conns) {
            foreach ($conn in $conns) {
                $pidToKill = $conn.OwningProcess
                if ($pidToKill -gt 0) {
                    $proc = Get-Process -Id $pidToKill -ErrorAction SilentlyContinue
                    if ($proc) {
                        Write-Host "Stopping process $($proc.ProcessName) (PID: $pidToKill) listening on port $port..." -ForegroundColor Yellow
                        Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
                        $stoppedCount++
                    }
                }
            }
        }
    } catch {}
}

if ($stoppedCount -gt 0) {
    Write-Host "[OK] Stopped $stoppedCount FoodFlow microservice process(es)." -ForegroundColor Green
} else {
    Write-Host "[OK] No active FoodFlow microservice processes found on ports 8081-8087." -ForegroundColor DarkGray
}
