# ==============================================================================
# FoodFlow - Comprehensive Runtime Security & Identity Verification Suite
# Phase 9B Security Test Suite
# Tests Ports: Gateway (:8080), User (:8081), Restaurant (:8082), Order (:8083),
#              Payment (:8084), Notification (:8085), Delivery (:8086)
# ==============================================================================

param (
    [string]$GatewayUrl = "http://localhost:8080",
    [string]$UserServiceUrl = "http://localhost:8081",
    [string]$RestaurantServiceUrl = "http://localhost:8082",
    [string]$OrderServiceUrl = "http://localhost:8083",
    [string]$PaymentServiceUrl = "http://localhost:8084",
    [string]$NotificationServiceUrl = "http://localhost:8085",
    [string]$DeliveryServiceUrl = "http://localhost:8086"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   FOODFLOW - PHASE 9B SECURITY AND IDENTITY VERIFICATION SUITE   " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

function Record-TestResult([string]$testName, [bool]$passed, [string]$details) {
    $script:TotalTests++
    if ($passed) {
        $script:PassedTests++
        Write-Host "  [PASS] $testName" -ForegroundColor Green
        if ($details) { Write-Host "         $details" -ForegroundColor DarkGray }
    } else {
        $script:FailedTests++
        Write-Host "  [FAIL] $testName" -ForegroundColor Red
        if ($details) { Write-Host "         $details" -ForegroundColor Yellow }
    }
}

function Parse-JwtPayload([string]$jwt) {
    try {
        if (-not $jwt) { return $null }
        $parts = $jwt.Split('.')
        if ($parts.Length -lt 2) { return $null }
        $payload = $parts[1].Replace('-', '+').Replace('_', '/')
        switch ($payload.Length % 4) {
            2 { $payload += '==' }
            3 { $payload += '=' }
        }
        $bytes = [Convert]::FromBase64String($payload)
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        return ($json | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Create-TamperedJwt([string]$jwt, [string]$newRole) {
    try {
        $parts = $jwt.Split('.')
        $header = $parts[0]
        $payloadObj = Parse-JwtPayload $jwt
        $payloadObj.role = $newRole
        $tamperedJson = $payloadObj | ConvertTo-Json -Compress
        $tamperedBytes = [System.Text.Encoding]::UTF8.GetBytes($tamperedJson)
        $tamperedBase64 = [Convert]::ToBase64String($tamperedBytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        return "$header.$tamperedBase64.$($parts[2])"
    } catch {
        return $jwt
    }
}

function Invoke-ApiCall {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null
    )
    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
            ErrorAction = "Stop"
        }
        if ($Body) {
            $params["Body"] = $Body
            $params["ContentType"] = "application/json"
        }
        $response = Invoke-WebRequest @params
        return @{
            StatusCode = [int]$response.StatusCode
            Content = $response.Content
            Headers = $response.Headers
        }
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($resp) {
            $stream = $resp.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            return @{
                StatusCode = [int]$resp.StatusCode
                Content = $content
                Headers = $resp.Headers
            }
        }
        return @{ StatusCode = 0; Content = $_.Exception.Message }
    } catch {
        return @{ StatusCode = 0; Content = $_.Exception.Message }
    }
}

# ==============================================================================
# TEST 1: CUSTOMER Authentication & JWT Claim Verification
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 1: CUSTOMER Authentication and JWT Claims ---" -ForegroundColor White
$customerEmail = "cust_$(Get-Random)@foodflow.test"
$customerRegBody = @{
    name = "Test Customer"
    email = $customerEmail
    password = "Password@123"
    phone = "9876543210"
    role = "CUSTOMER"
} | ConvertTo-Json

$custRegRes = Invoke-ApiCall -Uri "$GatewayUrl/api/auth/register" -Method "POST" -Body $customerRegBody
$custToken = $null
$custUserId = $null

if ($custRegRes.StatusCode -eq 201 -or $custRegRes.StatusCode -eq 200) {
    $custObj = $custRegRes.Content | ConvertFrom-Json
    $custToken = $custObj.token
    $custUserId = $custObj.user.id
    
    $claims = Parse-JwtPayload $custToken
    $hasUserId = ($claims.userId -ne $null -and $claims.userId -eq $custUserId)
    $hasRole = ($claims.role -eq "ROLE_CUSTOMER")
    
    Record-TestResult -testName "CUSTOMER Registration and Token Issuance" -passed $true -details "UserId: $custUserId, Email: $customerEmail"
    Record-TestResult -testName "CUSTOMER JWT Claims (userId present, role=ROLE_CUSTOMER)" -passed ($hasUserId -and $hasRole) -details "Extracted: userId=$($claims.userId), role=$($claims.role)"
} else {
    Record-TestResult -testName "CUSTOMER Registration and Token Issuance" -passed $false -details "Status: $($custRegRes.StatusCode) $($custRegRes.Content)"
}

# ==============================================================================
# TEST 2: RESTAURANT_OWNER Authentication & JWT Claims
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 2: RESTAURANT_OWNER Authentication and JWT Claims ---" -ForegroundColor White
$owner1Email = "owner1_$(Get-Random)@foodflow.test"
$owner1RegBody = @{
    name = "Restaurant Owner 1"
    email = $owner1Email
    password = "Password@123"
    phone = "9876543211"
    role = "RESTAURANT_OWNER"
} | ConvertTo-Json

$owner1Res = Invoke-ApiCall -Uri "$GatewayUrl/api/auth/register" -Method "POST" -Body $owner1RegBody
$owner1Token = $null
$owner1UserId = $null

if ($owner1Res.StatusCode -eq 201 -or $owner1Res.StatusCode -eq 200) {
    $owner1Obj = $owner1Res.Content | ConvertFrom-Json
    $owner1Token = $owner1Obj.token
    $owner1UserId = $owner1Obj.user.id
    
    $claims = Parse-JwtPayload $owner1Token
    $hasUserId = ($claims.userId -ne $null -and $claims.userId -eq $owner1UserId)
    $hasRole = ($claims.role -eq "ROLE_RESTAURANT_OWNER")
    
    Record-TestResult -testName "RESTAURANT_OWNER Registration and Token Issuance" -passed $true -details "UserId: $owner1UserId"
    Record-TestResult -testName "RESTAURANT_OWNER JWT Claims (role=ROLE_RESTAURANT_OWNER)" -passed ($hasUserId -and $hasRole) -details "Extracted role: $($claims.role)"
} else {
    Record-TestResult -testName "RESTAURANT_OWNER Registration and Token Issuance" -passed $false -details "Status: $($owner1Res.StatusCode)"
}

# Second owner for ownership tests
$owner2Email = "owner2_$(Get-Random)@foodflow.test"
$owner2RegBody = @{
    name = "Restaurant Owner 2"
    email = $owner2Email
    password = "Password@123"
    phone = "9876543212"
    role = "RESTAURANT_OWNER"
} | ConvertTo-Json

$owner2Res = Invoke-ApiCall -Uri "$GatewayUrl/api/auth/register" -Method "POST" -Body $owner2RegBody
$owner2Token = $null
$owner2UserId = $null
if ($owner2Res.StatusCode -eq 201 -or $owner2Res.StatusCode -eq 200) {
    $owner2Obj = $owner2Res.Content | ConvertFrom-Json
    $owner2Token = $owner2Obj.token
    $owner2UserId = $owner2Obj.user.id
}

# ==============================================================================
# TEST 3: DELIVERY_PARTNER Authentication & JWT Claims
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 3: DELIVERY_PARTNER Authentication and JWT Claims ---" -ForegroundColor White
$driverEmail = "driver_$(Get-Random)@foodflow.test"
$driverRegBody = @{
    name = "Delivery Driver"
    email = $driverEmail
    password = "Password@123"
    phone = "9876543213"
    role = "DELIVERY_PARTNER"
} | ConvertTo-Json

$driverRes = Invoke-ApiCall -Uri "$GatewayUrl/api/auth/register" -Method "POST" -Body $driverRegBody
$driverToken = $null
$driverUserId = $null

if ($driverRes.StatusCode -eq 201 -or $driverRes.StatusCode -eq 200) {
    $driverObj = $driverRes.Content | ConvertFrom-Json
    $driverToken = $driverObj.token
    $driverUserId = $driverObj.user.id
    
    $claims = Parse-JwtPayload $driverToken
    $hasRole = ($claims.role -eq "ROLE_DELIVERY_PARTNER")
    Record-TestResult -testName "DELIVERY_PARTNER Registration and Token Issuance" -passed $true -details "UserId: $driverUserId"
    Record-TestResult -testName "DELIVERY_PARTNER JWT Claims (role=ROLE_DELIVERY_PARTNER)" -passed $hasRole -details "Extracted role: $($claims.role)"
} else {
    Record-TestResult -testName "DELIVERY_PARTNER Registration and Token Issuance" -passed $false -details "Status: $($driverRes.StatusCode)"
}

# ==============================================================================
# TEST 4: Identity Propagation & Absence of Hardcoded 1L
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 4: Identity Propagation (No Hardcoded 1L) ---" -ForegroundColor White
$restaurantId = $null
if ($owner1Token) {
    $restBody = @{
        name = "Owner 1 Bistro $(Get-Random)"
        description = "Gourmet dining"
        address = "123 Security Blvd"
    } | ConvertTo-Json

    $createRestRes = Invoke-ApiCall -Uri "$GatewayUrl/api/restaurants" -Method "POST" `
        -Headers @{ "Authorization" = "Bearer $owner1Token" } -Body $restBody

    if ($createRestRes.StatusCode -eq 201) {
        $restObj = $createRestRes.Content | ConvertFrom-Json
        $restaurantId = $restObj.id
        $propMatch = ($restObj.ownerId -eq $owner1UserId)
        Record-TestResult -testName "Resource Created with Authenticated OwnerId" -passed $propMatch -details "OwnerId $($restObj.ownerId) matches JWT userId $owner1UserId"
    } else {
        Record-TestResult -testName "Restaurant Creation with Dynamic Identity" -passed $false -details "Status: $($createRestRes.StatusCode)"
    }
} else {
    Record-TestResult -testName "Identity Propagation Test" -passed $false -details "Skipped due to missing owner token"
}

# ==============================================================================
# TEST 5: Ownership Isolation (Cross-User Access Prohibition)
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 5: Ownership Isolation (403 on Cross-User Modification) ---" -ForegroundColor White
if ($restaurantId -and $owner2Token) {
    $tamperRestBody = @{
        name = "Hacked Restaurant Name"
        description = "Unauthorized modification"
        address = "456 Malicious Ln"
    } | ConvertTo-Json

    $owner2UpdateRes = Invoke-ApiCall -Uri "$GatewayUrl/api/restaurants/$restaurantId" -Method "PUT" `
        -Headers @{ "Authorization" = "Bearer $owner2Token" } -Body $tamperRestBody

    $isForbidden = ($owner2UpdateRes.StatusCode -eq 403)
    Record-TestResult -testName "Owner B Cannot Modify Owner A Restaurant (HTTP 403)" -passed $isForbidden -details "Status: $($owner2UpdateRes.StatusCode)"

    $owner2ToggleRes = Invoke-ApiCall -Uri "$GatewayUrl/api/restaurants/$restaurantId/status?isOpen=false" -Method "PATCH" `
        -Headers @{ "Authorization" = "Bearer $owner2Token" }

    $isToggleForbidden = ($owner2ToggleRes.StatusCode -eq 403)
    Record-TestResult -testName "Owner B Cannot Toggle Owner A Restaurant Status (HTTP 403)" -passed $isToggleForbidden -details "Status: $($owner2ToggleRes.StatusCode)"
} else {
    Record-TestResult -testName "Ownership Isolation Tests" -passed $false -details "Skipped due to missing prerequisite tokens or restaurantId"
}

# ==============================================================================
# TEST 6: Role-Based Access Control (RBAC) Boundaries
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 6: Role-Based Access Control (RBAC) Boundaries ---" -ForegroundColor White

if ($custToken) {
    $custRestBody = @{ name = "Illegal Customer Cafe"; description = "Invalid"; address = "Nowhere" } | ConvertTo-Json
    $custRestRes = Invoke-ApiCall -Uri "$GatewayUrl/api/restaurants" -Method "POST" `
        -Headers @{ "Authorization" = "Bearer $custToken" } -Body $custRestBody
    Record-TestResult -testName "CUSTOMER Blocked from RESTAURANT_OWNER Endpoint (HTTP 403)" -passed ($custRestRes.StatusCode -eq 403) -details "Status: $($custRestRes.StatusCode)"

    $custAssignRes = Invoke-ApiCall -Uri "$GatewayUrl/api/deliveries/1/assign" -Method "POST" `
        -Headers @{ "Authorization" = "Bearer $custToken" }
    Record-TestResult -testName "CUSTOMER Blocked from DELIVERY_PARTNER Endpoint (HTTP 403)" -passed ($custAssignRes.StatusCode -eq 403) -details "Status: $($custAssignRes.StatusCode)"
} else {
    Record-TestResult -testName "CUSTOMER RBAC Tests" -passed $false -details "Skipped due to missing customer token"
}

if ($owner1Token) {
    $payBody = @{ orderId = 999; amount = 50.00; paymentMethod = "CREDIT_CARD" } | ConvertTo-Json
    $ownerPayRes = Invoke-ApiCall -Uri "$GatewayUrl/api/payments" -Method "POST" `
        -Headers @{ "Authorization" = "Bearer $owner1Token"; "Idempotency-Key" = "test-$(Get-Random)" } -Body $payBody
    Record-TestResult -testName "RESTAURANT_OWNER Blocked from CUSTOMER Payment Endpoint (HTTP 403)" -passed ($ownerPayRes.StatusCode -eq 403) -details "Status: $($ownerPayRes.StatusCode)"
} else {
    Record-TestResult -testName "OWNER RBAC Test" -passed $false -details "Skipped due to missing owner token"
}

if ($driverToken) {
    $driverRestBody = @{ name = "Driver Diner"; description = "Invalid"; address = "Road" } | ConvertTo-Json
    $driverRestRes = Invoke-ApiCall -Uri "$GatewayUrl/api/restaurants" -Method "POST" `
        -Headers @{ "Authorization" = "Bearer $driverToken" } -Body $driverRestBody
    Record-TestResult -testName "DELIVERY_PARTNER Blocked from RESTAURANT_OWNER Endpoint (HTTP 403)" -passed ($driverRestRes.StatusCode -eq 403) -details "Status: $($driverRestRes.StatusCode)"
} else {
    Record-TestResult -testName "DRIVER RBAC Test" -passed $false -details "Skipped due to missing driver token"
}

# ==============================================================================
# TEST 7: Authentication Failure Matrix (401 Unauthorized)
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 7: Authentication Failure Matrix (HTTP 401) ---" -ForegroundColor White

$noAuthRes = Invoke-ApiCall -Uri "$GatewayUrl/api/orders" -Method "GET"
Record-TestResult -testName "Missing Authorization Header Returns HTTP 401" -passed ($noAuthRes.StatusCode -eq 401) -details "Status: $($noAuthRes.StatusCode)"

$bogusJwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJmYWtlQGZvb2RmbG93LnRlc3QiLCJ1c2VySWQiOjk5OTksInJvbGUiOiJST0xFX0FETUlOIn0.invalidsignaturehere1234567890abcdef"
$invalidSigRes = Invoke-ApiCall -Uri "$GatewayUrl/api/orders" -Method "GET" `
    -Headers @{ "Authorization" = "Bearer $bogusJwt" }
Record-TestResult -testName "Forged / Invalid Signature Returns HTTP 401" -passed ($invalidSigRes.StatusCode -eq 401) -details "Status: $($invalidSigRes.StatusCode)"

$malformedRes = Invoke-ApiCall -Uri "$GatewayUrl/api/orders" -Method "GET" `
    -Headers @{ "Authorization" = "Bearer thisIsNotAValidJwtFormat" }
Record-TestResult -testName "Malformed Token Returns HTTP 401" -passed ($malformedRes.StatusCode -eq 401) -details "Status: $($malformedRes.StatusCode)"

# ==============================================================================
# TEST 8: JWT Payload Tampering Verification
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 8: Cryptographic Signature and Tampering Verification ---" -ForegroundColor White
if ($custToken) {
    $tamperedAdminJwt = Create-TamperedJwt -jwt $custToken -newRole "ROLE_ADMIN"
    $tamperRes = Invoke-ApiCall -Uri "$GatewayUrl/api/restaurants" -Method "POST" `
        -Headers @{ "Authorization" = "Bearer $tamperedAdminJwt" } `
        -Body (@{ name = "Tampered Cafe"; description = "Hack"; address = "Hack" } | ConvertTo-Json)

    Record-TestResult -testName "Tampered JWT Payload Rejected Cryptographically (HTTP 401)" -passed ($tamperRes.StatusCode -eq 401) -details "Status: $($tamperRes.StatusCode)"
} else {
    Record-TestResult -testName "JWT Tampering Test" -passed $false -details "Skipped due to missing customer token"
}

# ==============================================================================
# TEST 9: Gateway Routing & Header Propagation
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 9: API Gateway Header Propagation and Tracing ---" -ForegroundColor White
if ($custToken) {
    $gwOrderRes = Invoke-ApiCall -Uri "$GatewayUrl/api/orders" -Method "GET" `
        -Headers @{ "Authorization" = "Bearer $custToken" }

    $hasCorrId = ($gwOrderRes.Headers["X-Correlation-Id"] -ne $null)
    $authForwarded = ($gwOrderRes.StatusCode -eq 200)
    Record-TestResult -testName "Gateway Transparently Propagates Bearer Auth (HTTP 200)" -passed $authForwarded -details "Status: $($gwOrderRes.StatusCode)"
    Record-TestResult -testName "Gateway Attaches X-Correlation-Id Header in Response" -passed $hasCorrId -details "Correlation-Id: $($gwOrderRes.Headers['X-Correlation-Id'])"
} else {
    Record-TestResult -testName "Gateway Tracing Tests" -passed $false -details "Skipped due to missing customer token"
}

# ==============================================================================
# TEST 10: Notification Privacy & Self-Access Only
# ==============================================================================
Write-Host ""
Write-Host "--- TEST 10: Notification Privacy and Self-Access Only ---" -ForegroundColor White
if ($custToken -and $owner1UserId) {
    $crossNotifRes = Invoke-ApiCall -Uri "$GatewayUrl/api/notifications/user/$owner1UserId" -Method "GET" `
        -Headers @{ "Authorization" = "Bearer $custToken" }
    
    Record-TestResult -testName "Customer Cannot Read Another User Notifications (HTTP 403)" -passed ($crossNotifRes.StatusCode -eq 403) -details "Status: $($crossNotifRes.StatusCode)"
} else {
    Record-TestResult -testName "Notification Privacy Test" -passed $false -details "Skipped due to missing tokens"
}

# ==============================================================================
# SUMMARY
# ==============================================================================
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "                    SECURITY TEST SUMMARY                       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " Total Tests  : $script:TotalTests"
Write-Host " Passed Tests : $script:PassedTests" -ForegroundColor Green
Write-Host " Failed Tests : $script:FailedTests" -ForegroundColor $(if ($script:FailedTests -gt 0) { "Red" } else { "Green" })
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
