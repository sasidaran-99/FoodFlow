# Local Runtime Verification Script for FoodFlow payment-service (:8084)
$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "FOODFLOW LOCAL RUNTIME VERIFICATION - PAYMENT SERVICE (:8084)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Health & Actuator Check
Write-Host "`n[TEST 1] Verifying payment-service Actuator Health on port 8084..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8084/actuator/health" -Method Get
    Write-Host "Actuator Health Status: $($health.status)" -ForegroundColor Green
    if ($health.status -ne "UP") {
        Write-Host "FAIL: Health is not UP" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "FAIL: Could not reach http://localhost:8084/actuator/health: $_" -ForegroundColor Red
    exit 1
}

# 2. Register / Authenticate Test Users via user-service (:8081)
Write-Host "`n[TEST 2] Registering and authenticating test users via user-service (:8081)..." -ForegroundColor Yellow
$ts = Get-Date -Format "yyyyMMddHHmmss"

# Customer A
$custAEmail = "pay_cust_a_$ts@example.com"
$regBodyA = @{
    name = "Payment Customer A"
    email = $custAEmail
    password = "Password@123"
    phone = "9876543210"
    role = "CUSTOMER"
} | ConvertTo-Json
$resA = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regBodyA
$tokenA = $resA.token
$userIdA = $resA.user.id
Write-Host "Registered Customer A: ID=$userIdA, Email=$custAEmail" -ForegroundColor Green

# Customer B
$custBEmail = "pay_cust_b_$ts@example.com"
$regBodyB = @{
    name = "Payment Customer B"
    email = $custBEmail
    password = "Password@123"
    phone = "9876543211"
    role = "CUSTOMER"
} | ConvertTo-Json
$resB = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regBodyB
$tokenB = $resB.token
$userIdB = $resB.user.id
Write-Host "Registered Customer B: ID=$userIdB, Email=$custBEmail" -ForegroundColor Green

# Admin
$adminEmail = "pay_admin_$ts@example.com"
$regBodyAdmin = @{
    name = "Payment Admin"
    email = $adminEmail
    password = "Password@123"
    phone = "9876543212"
    role = "ADMIN"
} | ConvertTo-Json
$resAdmin = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regBodyAdmin
$tokenAdmin = $resAdmin.token
$userIdAdmin = $resAdmin.user.id
Write-Host "Registered Admin: ID=$userIdAdmin, Email=$adminEmail" -ForegroundColor Green

# Restaurant Owner
$ownerEmail = "pay_owner_$ts@example.com"
$regBodyOwner = @{
    name = "Payment Owner"
    email = $ownerEmail
    password = "Password@123"
    phone = "9876543213"
    role = "RESTAURANT_OWNER"
} | ConvertTo-Json
$resOwner = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regBodyOwner
$tokenOwner = $resOwner.token
Write-Host "Registered Restaurant Owner: Email=$ownerEmail" -ForegroundColor Green

# 3. Test SUCCESS Payment Flow (Order <= 5000)
Write-Host "`n[TEST 3] Testing SUCCESS Payment Flow via Kafka (Order <= 5000)..." -ForegroundColor Yellow
$orderSuccessBody = @{
    restaurantId = 14
    deliveryAddress = "123 Success Lane, Bengaluru"
    items = @(
        @{
            menuItemId = 13
            quantity = 2
        }
    )
} | ConvertTo-Json

$orderSuccessHeaders = @{
    Authorization = "Bearer $tokenA"
    "Content-Type" = "application/json"
}

$orderSuccessRes = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers $orderSuccessHeaders -Body $orderSuccessBody
$orderSuccessId = $orderSuccessRes.id
$orderSuccessAmount = $orderSuccessRes.totalAmount
$orderSuccessInitStatus = $orderSuccessRes.status
Write-Host "Order created: ID=$orderSuccessId, Amount=$orderSuccessAmount, Initial Status=$orderSuccessInitStatus" -ForegroundColor Green

# Wait for Kafka payment processing
Write-Host "Waiting 3 seconds for Kafka event flow (payment.requested -> payment.completed)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Check payment_db
$sqlCheckPaySuccess = "SELECT id, order_id, user_id, amount, status, reference_number, idempotency_key FROM payments WHERE order_id = $orderSuccessId;"
$paySuccessRow = docker exec foodflow-postgres psql -U foodflow -d payment_db -c "$sqlCheckPaySuccess"
Write-Host "Payment DB Record for Order ${orderSuccessId}:`n$paySuccessRow" -ForegroundColor Green

# Check order_db
$sqlCheckOrderSuccess = "SELECT id, status FROM orders WHERE id = $orderSuccessId;"
$orderSuccessFinalRow = docker exec foodflow-postgres psql -U foodflow -d order_db -c "$sqlCheckOrderSuccess"
Write-Host "Order DB Record for Order ${orderSuccessId}:`n$orderSuccessFinalRow" -ForegroundColor Green

# Query order via order-service REST API
$orderSuccessFinalApi = Invoke-RestMethod -Uri "http://localhost:8083/api/orders/$orderSuccessId" -Method Get -Headers @{ Authorization = "Bearer $tokenA" }
Write-Host "Order REST API Status: $($orderSuccessFinalApi.status)" -ForegroundColor Green
if ($orderSuccessFinalApi.status -eq "CONFIRMED") {
    Write-Host "SUCCESS: Payment was processed successfully and Order $orderSuccessId transitioned to CONFIRMED!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Order $orderSuccessId status is $($orderSuccessFinalApi.status), expected CONFIRMED" -ForegroundColor Red
}

# 4. Test Idempotency
Write-Host "`n[TEST 4] Testing Idempotency in payment-service..." -ForegroundColor Yellow
$idempKey = "test-idemp-$ts"
$directPayBody = @{
    orderId = 9999
    amount = 700.00
} | ConvertTo-Json

$directPayHeaders = @{
    Authorization = "Bearer $tokenA"
    "Content-Type" = "application/json"
    "Idempotency-Key" = $idempKey
}

Write-Host "First POST /api/payments with Idempotency-Key: $idempKey" -ForegroundColor Cyan
$directPayRes1 = Invoke-RestMethod -Uri "http://localhost:8084/api/payments" -Method Post -Headers $directPayHeaders -Body $directPayBody
Write-Host "Response 1: ID=$($directPayRes1.id), Ref=$($directPayRes1.referenceNumber), Status=$($directPayRes1.status)" -ForegroundColor Green

Write-Host "Second (Duplicate) POST /api/payments with same Idempotency-Key: $idempKey" -ForegroundColor Cyan
$directPayRes2 = Invoke-RestMethod -Uri "http://localhost:8084/api/payments" -Method Post -Headers $directPayHeaders -Body $directPayBody
Write-Host "Response 2: ID=$($directPayRes2.id), Ref=$($directPayRes2.referenceNumber), Status=$($directPayRes2.status)" -ForegroundColor Green

if ($directPayRes1.id -eq $directPayRes2.id -and $directPayRes1.referenceNumber -eq $directPayRes2.referenceNumber) {
    Write-Host "SUCCESS: Duplicate payment request returned exact same payment record without creating a new row!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Duplicate payment request created different record!" -ForegroundColor Red
}

$sqlCountIdemp = "SELECT count(*) FROM payments WHERE idempotency_key = '$idempKey';"
$countIdempRes = docker exec foodflow-postgres psql -U foodflow -d payment_db -t -c "$sqlCountIdemp"
Write-Host "Payment DB count for idempotency key '$idempKey': $($countIdempRes.Trim())" -ForegroundColor Green

# 5. Test FAILURE Payment Flow (Order > 5000)
Write-Host "`n[TEST 5] Testing FAILURE Payment Flow via Kafka (Order > 5000)..." -ForegroundColor Yellow
$orderFailBody = @{
    restaurantId = 14
    deliveryAddress = "456 Failure Road, Bengaluru"
    items = @(
        @{
            menuItemId = 13
            quantity = 16  # 16 * 350.00 = 5600.00 > 5000.00 limit
        }
    )
} | ConvertTo-Json

$orderFailRes = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers $orderSuccessHeaders -Body $orderFailBody
$orderFailId = $orderFailRes.id
$orderFailAmount = $orderFailRes.totalAmount
Write-Host "Order created: ID=$orderFailId, Amount=$orderFailAmount, Initial Status=$($orderFailRes.status)" -ForegroundColor Green

Write-Host "Waiting 3 seconds for Kafka payment failure flow (payment.requested -> payment.failed)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Check payment_db
$sqlCheckPayFail = "SELECT id, order_id, user_id, amount, status, reference_number FROM payments WHERE order_id = $orderFailId;"
$payFailRow = docker exec foodflow-postgres psql -U foodflow -d payment_db -c "$sqlCheckPayFail"
Write-Host "Payment DB Record for Order ${orderFailId}:`n$payFailRow" -ForegroundColor Green

# Check order_db
$orderFailFinalApi = Invoke-RestMethod -Uri "http://localhost:8083/api/orders/$orderFailId" -Method Get -Headers @{ Authorization = "Bearer $tokenA" }
Write-Host "Order REST API Status: $($orderFailFinalApi.status)" -ForegroundColor Green
if ($orderFailFinalApi.status -eq "PAYMENT_FAILED") {
    Write-Host "SUCCESS: Payment was rejected (> 5000) and Order $orderFailId transitioned to PAYMENT_FAILED!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Order $orderFailId status is $($orderFailFinalApi.status), expected PAYMENT_FAILED" -ForegroundColor Red
}

# 6. Payment Security & RBAC Verification
Write-Host "`n[TEST 6] Testing Security, RBAC & Cross-User Isolation in payment-service..." -ForegroundColor Yellow

# 6.1 Customer A accesses their own payment by orderId
Write-Host "`n[6.1] Customer A accessing their own payment by orderId ($orderSuccessId)..." -ForegroundColor Cyan
try {
    $payGetA = Invoke-RestMethod -Uri "http://localhost:8084/api/payments/order/$orderSuccessId" -Method Get -Headers @{ Authorization = "Bearer $tokenA" }
    Write-Host "SUCCESS (200 OK): Customer A retrieved payment: ID=$($payGetA.id), Status=$($payGetA.status), UserId=$($payGetA.userId)" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Customer A could not access their own payment: $_" -ForegroundColor Red
}

# 6.2 Customer B attempts to access Customer A's payment by orderId -> Expected 403 Forbidden
Write-Host "`n[6.2] Customer B attempting to access Customer A's payment by orderId ($orderSuccessId)..." -ForegroundColor Cyan
try {
    $payGetB = Invoke-RestMethod -Uri "http://localhost:8084/api/payments/order/$orderSuccessId" -Method Get -Headers @{ Authorization = "Bearer $tokenB" }
    Write-Host "FAIL: Customer B was able to access Customer A's payment! (Status 200)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($statusCode): Customer B was denied access (Expected 403 Forbidden)" -ForegroundColor Green
}

# 6.3 Customer B attempts to access Customer A's payment by payment ID -> Expected 403 Forbidden
Write-Host "`n[6.3] Customer B attempting to access Customer A's payment by payment ID ($($directPayRes1.id))..." -ForegroundColor Cyan
try {
    $payGetB2 = Invoke-RestMethod -Uri "http://localhost:8084/api/payments/$($directPayRes1.id)" -Method Get -Headers @{ Authorization = "Bearer $tokenB" }
    Write-Host "FAIL: Customer B was able to access Customer A's payment by ID! (Status 200)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($statusCode): Customer B was denied access by ID (Expected 403 Forbidden)" -ForegroundColor Green
}

# 6.4 Admin accesses Customer A's payment by orderId -> Expected 200 OK (Admin bypass)
Write-Host "`n[6.4] Admin accessing Customer A's payment by orderId ($orderSuccessId)..." -ForegroundColor Cyan
try {
    $payGetAdmin = Invoke-RestMethod -Uri "http://localhost:8084/api/payments/order/$orderSuccessId" -Method Get -Headers @{ Authorization = "Bearer $tokenAdmin" }
    Write-Host "SUCCESS (200 OK): Admin successfully accessed Customer A's payment (Admin bypass confirmed)" -ForegroundColor Green
} catch {
    Write-Host "FAIL: Admin could not access payment: $_" -ForegroundColor Red
}

# 6.5 Restaurant Owner attempts to access POST /api/payments -> Expected 403 Forbidden (Only CUSTOMER allowed)
Write-Host "`n[6.5] Restaurant Owner attempting to call POST /api/payments..." -ForegroundColor Cyan
try {
    $payOwnerCall = Invoke-RestMethod -Uri "http://localhost:8084/api/payments" -Method Post -Headers @{ Authorization = "Bearer $tokenOwner"; "Content-Type" = "application/json"; "Idempotency-Key" = "owner-key-$ts" } -Body $directPayBody
    Write-Host "FAIL: Restaurant Owner was able to call POST /api/payments! (Status 200)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($statusCode): Restaurant Owner was denied access to POST /api/payments (Expected 403 Forbidden)" -ForegroundColor Green
}

# 6.6 Invalid / Tampered JWT -> Expected 403/401
Write-Host "`n[6.6] Calling payment endpoint with tampered JWT..." -ForegroundColor Cyan
try {
    $tamperedToken = $tokenA.Substring(0, $tokenA.Length - 5) + "ABCDE"
    $tamperedRes = Invoke-RestMethod -Uri "http://localhost:8084/api/payments/order/$orderSuccessId" -Method Get -Headers @{ Authorization = "Bearer $tamperedToken" }
    Write-Host "FAIL: Tampered JWT was accepted! (Status 200)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($statusCode): Tampered JWT was rejected (Expected 403/401)" -ForegroundColor Green
}

# 6.7 Missing Authorization Header -> Expected 403/401
Write-Host "`n[6.7] Calling payment endpoint with no Authorization header..." -ForegroundColor Cyan
try {
    $noAuthRes = Invoke-RestMethod -Uri "http://localhost:8084/api/payments/order/$orderSuccessId" -Method Get
    Write-Host "FAIL: Unauthenticated request was accepted! (Status 200)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($statusCode): Unauthenticated request was rejected (Expected 403/401)" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "ALL PAYMENT-SERVICE LOCAL RUNTIME VERIFICATIONS COMPLETED!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
