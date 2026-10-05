# Local Runtime Verification Script for FoodFlow notification-service (:8085)
$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "FOODFLOW LOCAL RUNTIME VERIFICATION - NOTIFICATION SERVICE (:8085)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Health & Actuator Check
Write-Host "`n[TEST 1] Verifying notification-service Actuator Health on port 8085..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8085/actuator/health" -Method Get
    Write-Host "Actuator Health Status: $($health.status)" -ForegroundColor Green
    if ($health.status -ne "UP") {
        Write-Host "FAIL: Health is not UP" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "FAIL: Could not reach http://localhost:8085/actuator/health: $_" -ForegroundColor Red
    exit 1
}

# 2. Register / Authenticate Test User via user-service (:8081)
Write-Host "`n[TEST 2] Registering customer via user-service (:8081)..." -ForegroundColor Yellow
$ts = Get-Date -Format "yyyyMMddHHmmss"
$custEmail = "notif_cust_$ts@example.com"
$regBody = @{
    name = "Notification Customer"
    email = $custEmail
    password = "Password@123"
    phone = "9876543220"
    role = "CUSTOMER"
} | ConvertTo-Json
$res = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regBody
$token = $res.token
$userId = $res.user.id
Write-Host "Registered Customer: ID=$userId, Email=$custEmail" -ForegroundColor Green

# 3. Test SUCCESS Order Flow & Notification Creation
Write-Host "`n[TEST 3] Testing SUCCESS Order Flow -> payment.completed -> notification-service..." -ForegroundColor Yellow
$orderSuccessBody = @{
    restaurantId = 14
    deliveryAddress = "789 Notification Blvd, Bengaluru"
    items = @(
        @{
            menuItemId = 13
            quantity = 2
        }
    )
} | ConvertTo-Json

$orderHeaders = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

$orderRes = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers $orderHeaders -Body $orderSuccessBody
$orderId = $orderRes.id
$orderAmount = $orderRes.totalAmount
Write-Host "Order Created: ID=$orderId, Total Amount=$orderAmount, Initial Status=$($orderRes.status)" -ForegroundColor Green

Write-Host "Waiting 3 seconds for Kafka fan-out (payment.requested -> payment.completed -> notification)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Check order_db for order-service update
$sqlCheckOrder = "SELECT id, status FROM orders WHERE id = $orderId;"
$orderRow = docker exec foodflow-postgres psql -U foodflow -d order_db -c "$sqlCheckOrder"
Write-Host "Order DB Record for Order ${orderId}:`n$orderRow" -ForegroundColor Green

$orderFinal = Invoke-RestMethod -Uri "http://localhost:8083/api/orders/$orderId" -Method Get -Headers @{ Authorization = "Bearer $token" }
Write-Host "Order REST API Status: $($orderFinal.status)" -ForegroundColor Green
if ($orderFinal.status -eq "CONFIRMED") {
    Write-Host "CONFIRMED: order-service successfully consumed payment.completed!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Order status is $($orderFinal.status), expected CONFIRMED" -ForegroundColor Red
}

# Check notification_db for notification-service record
$sqlCheckNotif = "SELECT id, order_id, type, status, message, event_id FROM notifications WHERE order_id = $orderId;"
$notifRow = docker exec foodflow-postgres psql -U foodflow -d notification_db -c "$sqlCheckNotif"
Write-Host "Notification DB Record for Order ${orderId}:`n$notifRow" -ForegroundColor Green

# Extract event_id from DB
$rawEventId = docker exec foodflow-postgres psql -U foodflow -d notification_db -t -c "SELECT event_id FROM notifications WHERE order_id = $orderId AND type = 'ORDER_CONFIRMED' LIMIT 1;"
$eventId = [string](([string]::Join("", $rawEventId)).Trim())
Write-Host "Captured Event ID: $eventId" -ForegroundColor Green

# 4. Test FAILED Order Flow & Notification Creation
Write-Host "`n[TEST 4] Testing FAILED Order Flow -> payment.failed -> notification-service..." -ForegroundColor Yellow
$orderFailBody = @{
    restaurantId = 14
    deliveryAddress = "999 High Value Road, Bengaluru"
    items = @(
        @{
            menuItemId = 13
            quantity = 16  # 16 * 350.00 = 5600.00 > 5000.00 limit
        }
    )
} | ConvertTo-Json

$orderFailRes = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers $orderHeaders -Body $orderFailBody
$orderFailId = $orderFailRes.id
$orderFailAmount = $orderFailRes.totalAmount
Write-Host "Order Created: ID=$orderFailId, Total Amount=$orderFailAmount, Initial Status=$($orderFailRes.status)" -ForegroundColor Green

Write-Host "Waiting 3 seconds for Kafka fan-out (payment.requested -> payment.failed -> notification)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Check order_db for order-service update
$orderFailFinal = Invoke-RestMethod -Uri "http://localhost:8083/api/orders/$orderFailId" -Method Get -Headers @{ Authorization = "Bearer $token" }
Write-Host "Order REST API Status: $($orderFailFinal.status)" -ForegroundColor Green
if ($orderFailFinal.status -eq "PAYMENT_FAILED") {
    Write-Host "PAYMENT_FAILED: order-service successfully consumed payment.failed!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Order status is $($orderFailFinal.status), expected PAYMENT_FAILED" -ForegroundColor Red
}

# Check notification_db for notification-service record
$sqlCheckNotifFail = "SELECT id, order_id, type, status, message, event_id FROM notifications WHERE order_id = $orderFailId;"
$notifFailRow = docker exec foodflow-postgres psql -U foodflow -d notification_db -c "$sqlCheckNotifFail"
Write-Host "Notification DB Record for Order ${orderFailId}:`n$notifFailRow" -ForegroundColor Green

# 5. Test Kafka Fan-Out Verification
Write-Host "`n[TEST 5] Verifying Kafka Fan-Out between order-service and notification-service..." -ForegroundColor Yellow
Write-Host "Order Service Consumer Group: order-service-payment-group" -ForegroundColor Cyan
Write-Host "Notification Service Consumer Group: notification-service-group" -ForegroundColor Cyan
Write-Host "Result for Order $orderId (SUCCESS):" -ForegroundColor Green
Write-Host "  -> order-service status: $($orderFinal.status)" -ForegroundColor Green
$rawSuccess = docker exec foodflow-postgres psql -U foodflow -d notification_db -t -c "SELECT count(*) FROM notifications WHERE order_id = $orderId;"
$notifCountSuccess = [int](([string]::Join("", $rawSuccess)).Trim())
Write-Host "  -> notification-service notification count: $notifCountSuccess" -ForegroundColor Green

Write-Host "Result for Order $orderFailId (FAILURE):" -ForegroundColor Green
Write-Host "  -> order-service status: $($orderFailFinal.status)" -ForegroundColor Green
$rawFail = docker exec foodflow-postgres psql -U foodflow -d notification_db -t -c "SELECT count(*) FROM notifications WHERE order_id = $orderFailId;"
$notifCountFail = [int](([string]::Join("", $rawFail)).Trim())
Write-Host "  -> notification-service notification count: $notifCountFail" -ForegroundColor Green

if ($orderFinal.status -eq "CONFIRMED" -and $notifCountSuccess -ge 1 -and $orderFailFinal.status -eq "PAYMENT_FAILED" -and $notifCountFail -ge 1) {
    Write-Host "FAN-OUT SUCCESS: Both consumer groups independently consumed events without interfering with each other!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Fan-out test failed" -ForegroundColor Red
}

# 6. Test Notification Idempotency
Write-Host "`n[TEST 6] Testing Notification Idempotency with replay of eventId: $eventId..." -ForegroundColor Yellow
$rawBefore = docker exec foodflow-postgres psql -U foodflow -d notification_db -t -c "SELECT count(*) FROM notifications WHERE event_id = '$eventId';"
$notifCountBefore = [int](([string]::Join("", $rawBefore)).Trim())
Write-Host "Notification count before duplicate replay: $notifCountBefore" -ForegroundColor Cyan

# Replay exact same PaymentCompletedEvent to topic payment.completed
$replayPayload = @{
    eventId = [string]$eventId
    orderId = [int]$orderId
    paymentId = 9999
    amount = 700.00
    status = "SUCCESS"
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json -Compress

$replayPayload | docker exec -i foodflow-kafka kafka-console-producer --bootstrap-server localhost:9092 --topic payment.completed
Start-Sleep -Seconds 2

$rawAfter = docker exec foodflow-postgres psql -U foodflow -d notification_db -t -c "SELECT count(*) FROM notifications WHERE event_id = '$eventId';"
$notifCountAfter = [int](([string]::Join("", $rawAfter)).Trim())
Write-Host "Notification count after duplicate replay: $notifCountAfter" -ForegroundColor Green

if ($notifCountBefore -eq $notifCountAfter -and $notifCountAfter -ge 1) {
    Write-Host "IDEMPOTENCY SUCCESS: Duplicate event did NOT create any new notification record!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Duplicate event created new notification record!" -ForegroundColor Red
}

# 7. Test REST API: GET /api/notifications/order/{orderId}
Write-Host "`n[TEST 7] Testing GET /api/notifications/order/$orderId REST API..." -ForegroundColor Yellow
try {
    $notifApiRes = Invoke-RestMethod -Uri "http://localhost:8085/api/notifications/order/$orderId" -Method Get -Headers @{ Authorization = "Bearer $token" }
    Write-Host "API Response Count: $($notifApiRes.Count)" -ForegroundColor Green
    foreach ($n in $notifApiRes) {
        Write-Host "Notification ID: $($n.id), Type: $($n.type), Status: $($n.status), Message: $($n.message)" -ForegroundColor Green
    }
} catch {
    Write-Host "FAIL: Could not query notification REST API: $_" -ForegroundColor Red
}

# 8. Test Unauthenticated Access to REST API -> Expected 403 Forbidden
Write-Host "`n[TEST 8] Testing unauthenticated access to /api/notifications/order/$orderId..." -ForegroundColor Yellow
try {
    $unauthRes = Invoke-RestMethod -Uri "http://localhost:8085/api/notifications/order/$orderId" -Method Get
    Write-Host "FAIL: Unauthenticated request was allowed! (Status 200)" -ForegroundColor Red
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($statusCode): Unauthenticated request was properly rejected (Expected 403 Forbidden)" -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "ALL NOTIFICATION-SERVICE VERIFICATIONS COMPLETED!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
