# verify-api-gateway.ps1
# Phase 11: FoodFlow API Gateway Final Runtime Verification Script
# Exclusively tests through API Gateway (:8080) with full end-to-end integration

$ErrorActionPreference = "Continue"
Add-Type -AssemblyName System.Net.Http
# Load environment variables from .env if present
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
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
}

$gatewayPort = if ($env:GATEWAY_PORT) { $env:GATEWAY_PORT } elseif ((Test-NetConnection -ComputerName 127.0.0.1 -Port 8087 -WarningAction SilentlyContinue).TcpTestSucceeded) { 8087 } else { 8080 }
$GATEWAY_URL = "http://localhost:$gatewayPort"
$TOTAL_TESTS = 0
$PASSED_TESTS = 0
$FAILED_TESTS = 0

function Report-Result {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = ""
    )
    $script:TOTAL_TESTS++
    if ($Success) {
        $script:PASSED_TESTS++
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        if ($Details) {
            Write-Host "         $Details" -ForegroundColor DarkGray
        }
    } else {
        $script:FAILED_TESTS++
        Write-Host "  [FAIL] $TestName" -ForegroundColor Red
        if ($Details) {
            Write-Host "         $Details" -ForegroundColor Yellow
        }
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " FOODFLOW PHASE 11 - API GATEWAY RUNTIME VERIFICATION (:8080)   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------
# 1. ACTUATOR HEALTH CHECK
# -----------------------------------------------------------------
Write-Host "`n[Test Group 1: Actuator Health & Subsystem Inspection]" -ForegroundColor Yellow
try {
    $healthResp = Invoke-RestMethod -Uri "$GATEWAY_URL/actuator/health" -Method Get
    $isUp = ($healthResp.status -eq "UP")
    $redisUp = ($healthResp.components.redis.status -eq "UP")
    Report-Result -TestName "Gateway Health Endpoint" -Success $isUp -Details "Status: $($healthResp.status)"
    Report-Result -TestName "Gateway Reactive Redis Health" -Success $redisUp -Details "Redis: $($healthResp.components.redis.status)"
} catch {
    Report-Result -TestName "Gateway Health Endpoint" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 2. GLOBAL CORS CONFIGURATION
# -----------------------------------------------------------------
Write-Host "`n[Test Group 2: Global CORS Configuration]" -ForegroundColor Yellow
try {
    $corsHeaders = @{
        "Origin" = "http://localhost:3000"
        "Access-Control-Request-Method" = "GET"
        "Access-Control-Request-Headers" = "Authorization,Content-Type"
    }
    $corsResp = Invoke-WebRequest -Uri "$GATEWAY_URL/api/restaurants" -Method Options -Headers $corsHeaders -UseBasicParsing
    $allowOrigin = $corsResp.Headers["Access-Control-Allow-Origin"]
    $allowMethods = $corsResp.Headers["Access-Control-Allow-Methods"]
    $corsOk = ($corsResp.StatusCode -eq 200 -and $allowOrigin -eq "*" -and $allowMethods -match "GET")
    Report-Result -TestName "CORS Preflight OPTIONS Request" -Success $corsOk -Details "Origin: $allowOrigin, Methods: $allowMethods"
} catch {
    Report-Result -TestName "CORS Preflight OPTIONS Request" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 3. CORRELATION ID GENERATION & PROPAGATION
# -----------------------------------------------------------------
Write-Host "`n[Test Group 3: Request Correlation ID Tracking]" -ForegroundColor Yellow
try {
    # 3a. Auto-generation when missing (on routed endpoint)
    $genCid = $null
    try {
        $resp = Invoke-WebRequest -Uri "$GATEWAY_URL/api/restaurants" -Method Get -UseBasicParsing
        $genCid = $resp.Headers["X-Correlation-Id"]
    } catch [System.Net.WebException] {
        $genCid = $_.Exception.Response.Headers.Get("X-Correlation-Id")
    }
    $autoGenOk = (-not [string]::IsNullOrWhiteSpace($genCid))
    Report-Result -TestName "Auto-generate X-Correlation-Id if missing" -Success $autoGenOk -Details "Generated CID: $genCid"

    # 3b. Preservation when supplied (on routed endpoint)
    $customCid = "cid-test-$(Get-Random)"
    $echoedCid = $null
    try {
        $resp = Invoke-WebRequest -Uri "$GATEWAY_URL/api/restaurants" -Method Get -Headers @{ "X-Correlation-Id" = $customCid } -UseBasicParsing
        $echoedCid = $resp.Headers["X-Correlation-Id"]
    } catch [System.Net.WebException] {
        $echoedCid = $_.Exception.Response.Headers.Get("X-Correlation-Id")
    }
    $echoOk = ($echoedCid -eq $customCid)
    Report-Result -TestName "Preserve & Echo Custom X-Correlation-Id" -Success $echoOk -Details "Echoed CID: $echoedCid"
} catch {
    Report-Result -TestName "Correlation ID Verification" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 4. REDIS RATE LIMITING (TOKEN BUCKET ON /api/auth/login)
# -----------------------------------------------------------------
Write-Host "`n[Test Group 4: Redis Token-Bucket Rate Limiter]" -ForegroundColor Yellow
try {
    $client = [System.Net.Http.HttpClient]::new()
    $loginUrl = "$GATEWAY_URL/api/auth/login"
    $loginPayload = '{"email":"rate_limit_probe@example.com","password":"DummyPassword123!"}'

    # Fire 25 concurrent requests to exceed burstCapacity (10)
    $tasks = @()
    1..25 | ForEach-Object {
        $content = [System.Net.Http.StringContent]::new($loginPayload, [System.Text.Encoding]::UTF8, "application/json")
        $tasks += $client.PostAsync($loginUrl, $content)
    }
    [System.Threading.Tasks.Task]::WaitAll($tasks)
    $codes = $tasks | ForEach-Object { [int]$_.Result.StatusCode }
    $codeGroups = $codes | Group-Object

    $count429 = ($codeGroups | Where-Object { $_.Name -eq "429" }).Count
    if (-not $count429) { $count429 = 0 }
    $countAllowed = $codes.Count - $count429

    $rateLimitOk = ($count429 -gt 0)
    Report-Result -TestName "Burst Capacity Rate Limiting (HTTP 429)" -Success $rateLimitOk -Details "Allowed: $countAllowed, Rate-Limited (429): $count429"

    # Inspect Redis keys created by rate limiter
    $redisKeys = docker exec foodflow-redis redis-cli keys "request_rate_limiter*"
    $redisKeysStr = ([string]::Join(" ", $redisKeys)).Trim()
    $hasRedisKeys = ($redisKeysStr.Length -gt 0)
    Report-Result -TestName "Redis Rate Limiter Keys Stored in Redis" -Success $hasRedisKeys -Details "Keys: $redisKeysStr"

    # Allow token bucket to replenish before testing normal login in Test Group 5
    Write-Host "         Allowing token bucket 3s to replenish..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3
} catch {
    Report-Result -TestName "Redis Rate Limiter Test" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 5. USER REGISTRATION, LOGIN & TOKEN FORWARDING
# -----------------------------------------------------------------
Write-Host "`n[Test Group 5: User Service Routing & Decentralized Auth]" -ForegroundColor Yellow
$customerEmail = "gw_user_$(Get-Random)@example.com"
$customerPassword = "Password123!"
$customerToken = $null
$customerUserId = $null

try {
    # 5a. Register customer via Gateway
    $regBody = @{
        name = "Gateway Customer"
        email = $customerEmail
        password = $customerPassword
        phone = "9876543210"
        role = "CUSTOMER"
    } | ConvertTo-Json

    $regResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/auth/register" -Method Post -ContentType "application/json" -Body $regBody
    $customerToken = $regResp.token
    $customerUserId = $regResp.user.id
    $regOk = ($customerToken -and $customerUserId)
    Report-Result -TestName "Register Customer via Gateway (/api/auth/register)" -Success $regOk -Details "UserId: $customerUserId"

    # 5b. Login customer via Gateway
    $loginBody = @{
        email = $customerEmail
        password = $customerPassword
    } | ConvertTo-Json
    $loginResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    $customerToken = $loginResp.token
    $loginOk = (-not [string]::IsNullOrWhiteSpace($customerToken))
    Report-Result -TestName "Login Customer via Gateway (/api/auth/login)" -Success $loginOk -Details "Token received"

    # 5c. User profile via Gateway with Bearer token
    $meResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/users/me" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $meOk = ($meResp.id -eq $customerUserId -and $meResp.email -eq $customerEmail)
    Report-Result -TestName "Authenticated /api/users/me with Bearer token" -Success $meOk -Details "Verified user: $($meResp.email)"
} catch {
    Report-Result -TestName "User Service Routing" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 6. RBAC & SECURITY ENFORCEMENT VIA GATEWAY
# -----------------------------------------------------------------
Write-Host "`n[Test Group 6: Decentralized RBAC Enforcement via Gateway]" -ForegroundColor Yellow
try {
    # 6a. Customer attempting restaurant creation (requires ROLE_RESTAURANT_OWNER) -> 403
    $fakeRest = @{
        name = "Customer Bistro"
        description = "Unauthorized creation"
        address = "123 Nowhere"
    } | ConvertTo-Json

    $rbacRestBlocked = $false
    try {
        Invoke-RestMethod -Uri "$GATEWAY_URL/api/restaurants" -Method Post -ContentType "application/json" -Headers @{ Authorization = "Bearer $customerToken" } -Body $fakeRest
    } catch [System.Net.WebException] {
        $status = [int]$_.Exception.Response.StatusCode
        $rbacRestBlocked = ($status -eq 403)
    }
    Report-Result -TestName "Customer Mutation Blocked by RBAC (HTTP 403)" -Success $rbacRestBlocked -Details "ROLE_CUSTOMER cannot create restaurant"

    # 6b. Tampered token -> 403
    $tamperedBlocked = $false
    try {
        Invoke-RestMethod -Uri "$GATEWAY_URL/api/users/me" -Method Get -Headers @{ Authorization = "Bearer eyJhbGciOiJIUzI1NiJ9.tampered.token" }
    } catch [System.Net.WebException] {
        $status = [int]$_.Exception.Response.StatusCode
        $tamperedBlocked = ($status -eq 403 -or $status -eq 401)
    }
    Report-Result -TestName "Tampered JWT Rejected (HTTP 403/401)" -Success $tamperedBlocked -Details "Invalid signature rejected downstream"

    # 6c. Unauthenticated protected request -> 403
    $unauthBlocked = $false
    try {
        Invoke-RestMethod -Uri "$GATEWAY_URL/api/users/me" -Method Get
    } catch [System.Net.WebException] {
        $status = [int]$_.Exception.Response.StatusCode
        $unauthBlocked = ($status -eq 403 -or $status -eq 401)
    }
    Report-Result -TestName "Unauthenticated Request Rejected (HTTP 403/401)" -Success $unauthBlocked -Details "Missing Bearer token rejected"
} catch {
    Report-Result -TestName "RBAC Enforcement Tests" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 7. RESTAURANT SERVICE ROUTING
# -----------------------------------------------------------------
Write-Host "`n[Test Group 7: Restaurant Service Routing via Gateway]" -ForegroundColor Yellow
$testRestaurantId = 14
$testMenuItemId = 13
try {
    # 7a. Get all restaurants via Gateway
    $restaurantsResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/restaurants" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $restListOk = ($restaurantsResp.content.Count -gt 0)
    Report-Result -TestName "Browse Restaurants via Gateway (/api/restaurants)" -Success $restListOk -Details "Total found: $($restaurantsResp.content.Count)"

    # 7b. Get menu items for Restaurant 14 via Gateway
    $menuResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/restaurants/$testRestaurantId/menu" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $menuOk = ($menuResp.Count -gt 0 -and $menuResp[0].id -eq $testMenuItemId)
    Report-Result -TestName "Browse Menu Items via Gateway (/api/restaurants/{id}/menu)" -Success $menuOk -Details "Menu Item ID: $($menuResp[0].id), Name: $($menuResp[0].name)"
} catch {
    Report-Result -TestName "Restaurant Service Routing" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 8. ORDER CREATION & ASYNC KAFKA PAYMENT PROCESSING VIA GATEWAY
# -----------------------------------------------------------------
Write-Host "`n[Test Group 8: Order Placement & Async Kafka Flow via Gateway]" -ForegroundColor Yellow
$orderId = $null
try {
    $orderPayload = @{
        restaurantId = $testRestaurantId
        items = @(
            @{
                menuItemId = $testMenuItemId
                quantity = 2
            }
        )
    } | ConvertTo-Json

    $createOrderResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/orders" -Method Post -ContentType "application/json" -Headers @{ Authorization = "Bearer $customerToken" } -Body $orderPayload
    $orderId = $createOrderResp.id
    $initialStatus = $createOrderResp.status
    $orderCreatedOk = ($orderId -and $initialStatus -eq "PAYMENT_PENDING")
    Report-Result -TestName "Place Order via Gateway (/api/orders)" -Success $orderCreatedOk -Details "Order ID: $orderId, Status: $initialStatus, Total: $($createOrderResp.totalAmount)"

    # Wait for Kafka event processing (payment-service processes payment and emits payment-success)
    Write-Host "         Waiting 3s for Kafka event processing..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 3

    $orderStatusResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/orders/$orderId" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $confirmedStatus = $orderStatusResp.status
    $orderConfirmedOk = ($confirmedStatus -eq "CONFIRMED")
    Report-Result -TestName "Order State Transition via Kafka Event (CONFIRMED)" -Success $orderConfirmedOk -Details "Order $orderId status: $confirmedStatus"
} catch {
    Report-Result -TestName "Order Creation & Event Processing" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 9. CROSS-USER RESOURCE ACCESS RBAC VIA GATEWAY
# -----------------------------------------------------------------
Write-Host "`n[Test Group 9: Cross-User Resource Isolation via Gateway]" -ForegroundColor Yellow
try {
    # Register Customer 2
    $cust2Email = "gw_cust2_$(Get-Random)@example.com"
    $cust2Body = @{
        name = "Gateway Customer 2"
        email = $cust2Email
        password = "Password123!"
        phone = "9777777777"
        role = "CUSTOMER"
    } | ConvertTo-Json
    $cust2Reg = Invoke-RestMethod -Uri "$GATEWAY_URL/api/auth/register" -Method Post -ContentType "application/json" -Body $cust2Body
    $cust2Token = $cust2Reg.token

    $crossAccessBlocked = $false
    try {
        Invoke-RestMethod -Uri "$GATEWAY_URL/api/orders/$orderId" -Method Get -Headers @{ Authorization = "Bearer $cust2Token" }
    } catch [System.Net.WebException] {
        $status = [int]$_.Exception.Response.StatusCode
        $crossAccessBlocked = ($status -eq 403)
    }
    Report-Result -TestName "Cross-User Order Access Blocked (HTTP 403)" -Success $crossAccessBlocked -Details "Customer 2 blocked from viewing Customer 1's order"
} catch {
    Report-Result -TestName "Cross-User Resource Isolation" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 10. PAYMENT SERVICE ROUTING VIA GATEWAY
# -----------------------------------------------------------------
Write-Host "`n[Test Group 10: Payment Service Routing via Gateway]" -ForegroundColor Yellow
try {
    $paymentResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/payments/order/$orderId" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $paymentOk = ($paymentResp.orderId -eq $orderId -and $paymentResp.status -eq "SUCCESS")
    Report-Result -TestName "Query Payment via Gateway (/api/payments/order/{id})" -Success $paymentOk -Details "Payment ID: $($paymentResp.id), Status: $($paymentResp.status), Ref: $($paymentResp.referenceNumber)"
} catch {
    Report-Result -TestName "Payment Service Routing" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 11. NOTIFICATION SERVICE ROUTING VIA GATEWAY
# -----------------------------------------------------------------
Write-Host "`n[Test Group 11: Notification Service Routing via Gateway]" -ForegroundColor Yellow
try {
    $notifyResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/notifications/order/$orderId" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $notifyOk = ($notifyResp -and $notifyResp.orderId -eq $orderId -and $notifyResp.type -eq "ORDER_CONFIRMED")
    Report-Result -TestName "Query Notification via Gateway (/api/notifications/order/{id})" -Success $notifyOk -Details "Notification ID: $($notifyResp.id), Type: $($notifyResp.type)"
} catch {
    Report-Result -TestName "Notification Service Routing" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 12. DELIVERY SERVICE ROUTING & LIFECYCLE VIA GATEWAY
# -----------------------------------------------------------------
Write-Host "`n[Test Group 12: Delivery Service Routing & Lifecycle via Gateway]" -ForegroundColor Yellow
try {
    # 12a. Customer queries delivery for order
    $deliveryResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/deliveries/order/$orderId" -Method Get -Headers @{ Authorization = "Bearer $customerToken" }
    $deliveryId = $deliveryResp.id
    $delPendingOk = ($deliveryId -and $deliveryResp.status -eq "ASSIGNMENT_PENDING")
    Report-Result -TestName "Query Initial Delivery via Gateway (/api/deliveries/order/{id})" -Success $delPendingOk -Details "Delivery ID: $deliveryId, Status: $($deliveryResp.status)"

    # 12b. Register and login Delivery Partner via Gateway
    $driverEmail = "gw_driver_$(Get-Random)@example.com"
    $driverBody = @{
        name = "Gateway Delivery Partner"
        email = $driverEmail
        password = "Password123!"
        phone = "9112233445"
        role = "DELIVERY_PARTNER"
    } | ConvertTo-Json
    $driverReg = Invoke-RestMethod -Uri "$GATEWAY_URL/api/auth/register" -Method Post -ContentType "application/json" -Body $driverBody
    $driverToken = $driverReg.token

    # 12c. Assign delivery partner via Gateway
    $assignResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/deliveries/$deliveryId/assign" -Method Post -Headers @{ Authorization = "Bearer $driverToken" }
    $assignedOk = ($assignResp.status -eq "ASSIGNED")
    Report-Result -TestName "Assign Delivery Partner via Gateway" -Success $assignedOk -Details "Delivery $deliveryId status: $($assignResp.status)"

    # 12d. Status transition: PICKED_UP
    $pickedResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/deliveries/$deliveryId/status?status=PICKED_UP" -Method Patch -Headers @{ Authorization = "Bearer $driverToken" }
    $pickedOk = ($pickedResp.status -eq "PICKED_UP")
    Report-Result -TestName "Transition Delivery to PICKED_UP via Gateway" -Success $pickedOk -Details "Status: $($pickedResp.status)"

    # 12e. Status transition: OUT_FOR_DELIVERY
    $ofdResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/deliveries/$deliveryId/status?status=OUT_FOR_DELIVERY" -Method Patch -Headers @{ Authorization = "Bearer $driverToken" }
    $ofdOk = ($ofdResp.status -eq "OUT_FOR_DELIVERY")
    Report-Result -TestName "Transition Delivery to OUT_FOR_DELIVERY via Gateway" -Success $ofdOk -Details "Status: $($ofdResp.status)"

    # 12f. Status transition: DELIVERED
    $delivResp = Invoke-RestMethod -Uri "$GATEWAY_URL/api/deliveries/$deliveryId/status?status=DELIVERED" -Method Patch -Headers @{ Authorization = "Bearer $driverToken" }
    $deliveredOk = ($delivResp.status -eq "DELIVERED")
    Report-Result -TestName "Transition Delivery to DELIVERED via Gateway" -Success $deliveredOk -Details "Status: $($delivResp.status)"
} catch {
    Report-Result -TestName "Delivery Service Lifecycle" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# 13. TIMEOUT & ERROR ISOLATION
# -----------------------------------------------------------------
Write-Host "`n[Test Group 13: Gateway Timeout & Route Error Isolation]" -ForegroundColor Yellow
try {
    $notFoundBlocked = $false
    try {
        Invoke-WebRequest -Uri "$GATEWAY_URL/api/nonexistent-service/probe" -Method Get -UseBasicParsing
    } catch [System.Net.WebException] {
        $status = [int]$_.Exception.Response.StatusCode
        $notFoundBlocked = ($status -eq 404)
    }
    Report-Result -TestName "Unmapped Route Returns HTTP 404 cleanly" -Success $notFoundBlocked -Details "Non-existent route isolated"
} catch {
    Report-Result -TestName "Gateway Error Isolation" -Success $false -Details $_.Exception.Message
}

# -----------------------------------------------------------------
# FINAL SUMMARY
# -----------------------------------------------------------------
Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " PHASE 11 API GATEWAY RUNTIME VERIFICATION SUMMARY              " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Total Verifications : $script:TOTAL_TESTS" -ForegroundColor White
Write-Host "  Passed              : $script:PASSED_TESTS" -ForegroundColor Green
Write-Host "  Failed              : $script:FAILED_TESTS" -ForegroundColor $(if ($script:FAILED_TESTS -eq 0) { "DarkGray" } else { "Red" })

if ($script:FAILED_TESTS -eq 0) {
    Write-Host "`n>>> ALL API GATEWAY RUNTIME VERIFICATIONS PASSED SUCCESSFULLY! <<<" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n>>> SOME API GATEWAY RUNTIME VERIFICATIONS FAILED! <<<" -ForegroundColor Red
    exit 1
}
