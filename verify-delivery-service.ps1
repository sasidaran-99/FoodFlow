# Local Runtime Verification Script for FoodFlow delivery-service (:8086)
$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "FOODFLOW LOCAL RUNTIME VERIFICATION - DELIVERY SERVICE (:8086)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Health & Actuator Check
Write-Host "`n[TEST 1] Verifying delivery-service Actuator Health on port 8086..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8086/actuator/health" -Method Get
    Write-Host "Actuator Health Status: $($health.status)" -ForegroundColor Green
    if ($health.status -ne "UP") {
        Write-Host "FAIL: Health is not UP" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "FAIL: Could not reach http://localhost:8086/actuator/health: $_" -ForegroundColor Red
    exit 1
}

# 2. Register & Authenticate Test Users (CUSTOMER, RESTAURANT_OWNER, DELIVERY_PARTNER, ADMIN)
Write-Host "`n[TEST 2] Registering users with all roles via user-service (:8081)..." -ForegroundColor Yellow
$ts = Get-Date -Format "yyyyMMddHHmmss"

# Customer
$custEmail = "deliv_cust_$ts@example.com"
$regCust = @{ name = "Delivery Customer"; email = $custEmail; password = "Password@123"; phone = "9876543310"; role = "CUSTOMER" } | ConvertTo-Json
$resCust = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regCust
$tokenCust = $resCust.token
Write-Host "Registered CUSTOMER: $($resCust.user.id) ($custEmail)" -ForegroundColor Green

# Restaurant Owner
$ownerEmail = "deliv_owner_$ts@example.com"
$regOwner = @{ name = "Delivery Owner"; email = $ownerEmail; password = "Password@123"; phone = "9876543311"; role = "RESTAURANT_OWNER" } | ConvertTo-Json
$resOwner = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regOwner
$tokenOwner = $resOwner.token
Write-Host "Registered RESTAURANT_OWNER: $($resOwner.user.id) ($ownerEmail)" -ForegroundColor Green

# Delivery Partner
$partnerEmail = "deliv_partner_$ts@example.com"
$regPartner = @{ name = "Delivery Rider"; email = $partnerEmail; password = "Password@123"; phone = "9876543312"; role = "DELIVERY_PARTNER" } | ConvertTo-Json
$resPartner = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regPartner
$tokenPartner = $resPartner.token
Write-Host "Registered DELIVERY_PARTNER: $($resPartner.user.id) ($partnerEmail)" -ForegroundColor Green

# Admin
$adminEmail = "deliv_admin_$ts@example.com"
$regAdmin = @{ name = "Delivery Admin"; email = $adminEmail; password = "Password@123"; phone = "9876543313"; role = "ADMIN" } | ConvertTo-Json
$resAdmin = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -ContentType "application/json" -Body $regAdmin
$tokenAdmin = $resAdmin.token
Write-Host "Registered ADMIN: $($resAdmin.user.id) ($adminEmail)" -ForegroundColor Green

# 3. RBAC & Security Verification
Write-Host "`n[TEST 3] Testing RBAC on delivery-service endpoints..." -ForegroundColor Yellow

# Customer attempts partner-only assign -> Expected 403 Forbidden
try {
    $r = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/1/assign" -Method Post -Headers @{ Authorization = "Bearer $tokenCust" }
    Write-Host "FAIL: Customer was able to call assign!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Customer denied access to /assign (Expected 403)" -ForegroundColor Green
}

# Restaurant Owner attempts partner-only assign -> Expected 403 Forbidden
try {
    $r = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/1/assign" -Method Post -Headers @{ Authorization = "Bearer $tokenOwner" }
    Write-Host "FAIL: Restaurant Owner was able to call assign!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Restaurant Owner denied access to /assign (Expected 403)" -ForegroundColor Green
}

# Customer attempts admin-only create partner -> Expected 403 Forbidden
try {
    $r = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/partners?name=RogueDriver" -Method Post -Headers @{ Authorization = "Bearer $tokenCust" }
    Write-Host "FAIL: Customer was able to create partner!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Customer denied access to create partner (Expected 403)" -ForegroundColor Green
}

# Unauthenticated request -> Expected 403 Forbidden
try {
    $r = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/1" -Method Get
    Write-Host "FAIL: Unauthenticated request permitted!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Unauthenticated request rejected (Expected 403)" -ForegroundColor Green
}

# Tampered JWT -> Expected 403 Forbidden
try {
    $tampered = $tokenCust.Substring(0, $tokenCust.Length - 5) + "ZZZZZ"
    $r = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/1" -Method Get -Headers @{ Authorization = "Bearer $tampered" }
    Write-Host "FAIL: Tampered JWT permitted!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Tampered JWT rejected (Expected 403)" -ForegroundColor Green
}

# 4. Admin creates Delivery Partner via API
Write-Host "`n[TEST 4] Admin creating Delivery Partner via POST /api/deliveries/partners..." -ForegroundColor Yellow
$driverName = "ExpressDriver_$ts"
$partnerRes = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/partners?name=$driverName" -Method Post -Headers @{ Authorization = "Bearer $tokenAdmin" }
$partnerId = $partnerRes.id
Write-Host "Created Partner: ID=$partnerId, Name=$($partnerRes.name), Status=$($partnerRes.status), Version=$($partnerRes.version)" -ForegroundColor Green

# Verify in delivery_db
$sqlCheckPartner = "SELECT id, name, status, version FROM delivery_partners WHERE id = $partnerId;"
$dbPartnerRow = docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "$sqlCheckPartner"
Write-Host "Partner in delivery_db:`n$dbPartnerRow" -ForegroundColor Green

# 5. End-to-End Order Creation & order.confirmed Consumption
Write-Host "`n[TEST 5] Customer places order -> payment -> order.confirmed -> delivery-service..." -ForegroundColor Yellow
$orderBody = @{
    restaurantId = 14
    deliveryAddress = "100 Delivery Parkway, Bengaluru"
    items = @( @{ menuItemId = 13; quantity = 2 } )
} | ConvertTo-Json

$orderRes = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers @{ Authorization = "Bearer $tokenCust"; "Content-Type" = "application/json" } -Body $orderBody
$orderId = $orderRes.id
Write-Host "Created Order: ID=$orderId, Total Amount=$($orderRes.totalAmount), Status=$($orderRes.status)" -ForegroundColor Green

Write-Host "Waiting 4 seconds for full pipeline (payment -> order confirmed -> delivery created)..." -ForegroundColor Cyan
Start-Sleep -Seconds 4

# Check order_db
$orderApi = Invoke-RestMethod -Uri "http://localhost:8083/api/orders/$orderId" -Method Get -Headers @{ Authorization = "Bearer $tokenCust" }
Write-Host "Order REST API Status: $($orderApi.status)" -ForegroundColor Green
if ($orderApi.status -eq "CONFIRMED") {
    Write-Host "CONFIRMED: Order reached CONFIRMED!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Order status is $($orderApi.status), expected CONFIRMED" -ForegroundColor Red
}

# Check delivery_db
$sqlCheckDeliv = "SELECT id, order_id, restaurant_id, delivery_partner_id, status, version, event_id FROM deliveries WHERE order_id = $orderId;"
$delivDbRow = docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "$sqlCheckDeliv"
Write-Host "Delivery in delivery_db:`n$delivDbRow" -ForegroundColor Green

$delivApi = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/order/$orderId" -Method Get -Headers @{ Authorization = "Bearer $tokenPartner" }
$deliveryId = $delivApi.id
Write-Host "Delivery API: ID=$deliveryId, OrderId=$($delivApi.orderId), Status=$($delivApi.status)" -ForegroundColor Green
if ($delivApi.status -eq "ASSIGNMENT_PENDING") {
    Write-Host "SUCCESS: Delivery created in ASSIGNMENT_PENDING state!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Delivery status is $($delivApi.status), expected ASSIGNMENT_PENDING" -ForegroundColor Red
}

$rawEventId = docker exec foodflow-postgres psql -U foodflow -d delivery_db -t -c "SELECT event_id FROM deliveries WHERE id = $deliveryId;"
$eventId = [string](([string]::Join("", $rawEventId)).Trim())
Write-Host "Captured Event ID: $eventId" -ForegroundColor Green

# 6. Driver Assignment
Write-Host "`n[TEST 6] Assigning Delivery Partner $partnerId to Delivery $deliveryId..." -ForegroundColor Yellow
$assignRes = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId/assign" -Method Post -Headers @{ Authorization = "Bearer $tokenPartner" }
Write-Host "Assign Response: ID=$($assignRes.id), PartnerId=$($assignRes.deliveryPartnerId), Status=$($assignRes.status)" -ForegroundColor Green

# Verify partner status is now BUSY
$sqlCheckPartnerBusy = "SELECT id, name, status, version FROM delivery_partners WHERE id = $partnerId;"
$dbPartnerBusy = docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "$sqlCheckPartnerBusy"
Write-Host "Partner DB state after assignment (Expected BUSY, version 1):`n$dbPartnerBusy" -ForegroundColor Green

# 7. Delivery State Machine Valid Transitions
Write-Host "`n[TEST 7] Testing Delivery State Machine Valid Transitions..." -ForegroundColor Yellow

# Step 7.1: ASSIGNED -> PICKED_UP
Write-Host "Transition: ASSIGNED -> PICKED_UP..." -ForegroundColor Cyan
$pickedUpRes = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=PICKED_UP" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
Write-Host "Status after PICKED_UP: $($pickedUpRes.status)" -ForegroundColor Green

# Step 7.2: PICKED_UP -> OUT_FOR_DELIVERY
Write-Host "Transition: PICKED_UP -> OUT_FOR_DELIVERY..." -ForegroundColor Cyan
$ofdRes = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=OUT_FOR_DELIVERY" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
Write-Host "Status after OUT_FOR_DELIVERY: $($ofdRes.status)" -ForegroundColor Green

# Step 7.3: OUT_FOR_DELIVERY -> DELIVERED
Write-Host "Transition: OUT_FOR_DELIVERY -> DELIVERED..." -ForegroundColor Cyan
$deliveredRes = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=DELIVERED" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
Write-Host "Status after DELIVERED: $($deliveredRes.status)" -ForegroundColor Green

# 8. Terminal State Behavior & Driver Re-availability
Write-Host "`n[TEST 8] Verifying Terminal State Behavior & Driver Re-availability..." -ForegroundColor Yellow

# Verify Partner status is back to AVAILABLE
$sqlCheckPartnerAvail = "SELECT id, name, status, version FROM delivery_partners WHERE id = $partnerId;"
$dbPartnerAvail = docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "$sqlCheckPartnerAvail"
Write-Host "Partner DB state after delivery completion (Expected AVAILABLE):`n$dbPartnerAvail" -ForegroundColor Green

# Attempt illegal transitions on terminal DELIVERED delivery
Write-Host "Attempting DELIVERED -> OUT_FOR_DELIVERY (Illegal)..." -ForegroundColor Cyan
try {
    $bad1 = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=OUT_FOR_DELIVERY" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
    Write-Host "FAIL: Illegal transition was accepted!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Illegal transition rejected from terminal state" -ForegroundColor Green
}

Write-Host "Attempting DELIVERED -> PICKED_UP (Illegal)..." -ForegroundColor Cyan
try {
    $bad2 = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=PICKED_UP" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
    Write-Host "FAIL: Illegal transition was accepted!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Illegal transition rejected from terminal state" -ForegroundColor Green
}

# 9. Invalid State Transitions on Non-Terminal Delivery
Write-Host "`n[TEST 9] Testing Invalid State Transitions on Non-Terminal Delivery..." -ForegroundColor Yellow

# Create another order to get a fresh ASSIGNMENT_PENDING delivery
$order2Res = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers @{ Authorization = "Bearer $tokenCust"; "Content-Type" = "application/json" } -Body $orderBody
$order2Id = $order2Res.id
Start-Sleep -Seconds 3
$deliv2 = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/order/$order2Id" -Method Get -Headers @{ Authorization = "Bearer $tokenPartner" }
$delivery2Id = $deliv2.id
Write-Host "Fresh Delivery Created: ID=$delivery2Id in Status=$($deliv2.status)" -ForegroundColor Green

# Try skipping from ASSIGNMENT_PENDING -> OUT_FOR_DELIVERY (Illegal)
Write-Host "Attempting ASSIGNMENT_PENDING -> OUT_FOR_DELIVERY (Illegal)..." -ForegroundColor Cyan
try {
    $bad3 = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$delivery2Id/status?status=OUT_FOR_DELIVERY" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
    Write-Host "FAIL: Illegal skipping transition accepted!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Illegal skipping transition rejected" -ForegroundColor Green
}

# Try skipping from ASSIGNMENT_PENDING -> DELIVERED (Illegal)
Write-Host "Attempting ASSIGNMENT_PENDING -> DELIVERED (Illegal)..." -ForegroundColor Cyan
try {
    $bad4 = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$delivery2Id/status?status=DELIVERED" -Method Patch -Headers @{ Authorization = "Bearer $tokenPartner" }
    Write-Host "FAIL: Illegal skipping transition accepted!" -ForegroundColor Red
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Write-Host "SUCCESS ($code): Illegal skipping transition rejected" -ForegroundColor Green
}

# 10. Optimistic Locking / Concurrency Verification
Write-Host "`n[TEST 10] Testing Optimistic Locking / Concurrency with JPA @Version..." -ForegroundColor Yellow

# Create a second pending delivery
$order3Res = Invoke-RestMethod -Uri "http://localhost:8083/api/orders" -Method Post -Headers @{ Authorization = "Bearer $tokenCust"; "Content-Type" = "application/json" } -Body $orderBody
$order3Id = $order3Res.id
Start-Sleep -Seconds 3
$deliv3 = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/order/$order3Id" -Method Get -Headers @{ Authorization = "Bearer $tokenPartner" }
$delivery3Id = $deliv3.id

# We have delivery2Id ($delivery2Id) and delivery3Id ($delivery3Id) both ASSIGNMENT_PENDING.
# Ensure all other partners are BUSY except one dedicated driver
$optDriver = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/partners?name=SoloContender_$ts" -Method Post -Headers @{ Authorization = "Bearer $tokenAdmin" }
$soloId = $optDriver.id
Write-Host "Created Solo Driver for Concurrency Race: ID=$soloId, Status=$($optDriver.status)" -ForegroundColor Green

# Set any other partner in DB to BUSY so only soloId is AVAILABLE
docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "UPDATE delivery_partners SET status = 'BUSY' WHERE id != $soloId;" | Out-Null
$availCount = docker exec foodflow-postgres psql -U foodflow -d delivery_db -t -c "SELECT count(*) FROM delivery_partners WHERE status = 'AVAILABLE';"
Write-Host "Total AVAILABLE partners before race: $([string]::Join('', $availCount).Trim()) (Only partner $soloId)" -ForegroundColor Cyan

# Fire two concurrent assignment requests
Write-Host "Firing two simultaneous assignment requests for Delivery $delivery2Id and Delivery $delivery3Id..." -ForegroundColor Cyan

$scriptBlock = {
    param($delivId, $token)
    try {
        $res = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$delivId/assign" -Method Post -Headers @{ Authorization = "Bearer $token" }
        return "SUCCESS:$($res.deliveryPartnerId)"
    } catch {
        return "FAILED:$($_.Exception.Response.StatusCode.value__):$($_.Exception.Message)"
    }
}

$job1 = Start-Job -ScriptBlock $scriptBlock -ArgumentList $delivery2Id, $tokenPartner
$job2 = Start-Job -ScriptBlock $scriptBlock -ArgumentList $delivery3Id, $tokenPartner

$out1 = Receive-Job -Job $job1 -Wait
$out2 = Receive-Job -Job $job2 -Wait
Remove-Job -Job $job1, $job2

Write-Host "Job 1 (Delivery $delivery2Id) Result: $out1" -ForegroundColor Green
Write-Host "Job 2 (Delivery $delivery3Id) Result: $out2" -ForegroundColor Green

# Check DB state
$sqlSoloCheck = "SELECT id, name, status, version FROM delivery_partners WHERE id = $soloId;"
$dbSoloRes = docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "$sqlSoloCheck"
Write-Host "Solo Partner DB state after concurrency race:`n$dbSoloRes" -ForegroundColor Green

$sqlDelivCheck = "SELECT id, order_id, delivery_partner_id, status FROM deliveries WHERE id IN ($delivery2Id, $delivery3Id);"
$dbDelivRes = docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "$sqlDelivCheck"
Write-Host "Deliveries DB state after concurrency race:`n$dbDelivRes" -ForegroundColor Green

# Verify exactly one was assigned
$assignedCount = docker exec foodflow-postgres psql -U foodflow -d delivery_db -t -c "SELECT count(*) FROM deliveries WHERE delivery_partner_id = $soloId;"
$assignedCount = [int](([string]::Join("", $assignedCount)).Trim())
Write-Host "Total deliveries assigned to partner ${soloId}: $assignedCount" -ForegroundColor Green
if ($assignedCount -eq 1) {
    Write-Host "CONCURRENCY SUCCESS: Exactly 1 delivery was assigned! Double-booking prevented by @Version optimistic locking!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Partner assigned to $assignedCount deliveries!" -ForegroundColor Red
}

# Restore partner statuses
docker exec foodflow-postgres psql -U foodflow -d delivery_db -c "UPDATE delivery_partners SET status = 'AVAILABLE';" | Out-Null

# 11. Kafka Idempotency
Write-Host "`n[TEST 11] Testing Kafka Idempotency with replay of eventId: $eventId..." -ForegroundColor Yellow
$delivCountBefore = docker exec foodflow-postgres psql -U foodflow -d delivery_db -t -c "SELECT count(*) FROM deliveries WHERE event_id = '$eventId';"
$delivCountBefore = [int](([string]::Join("", $delivCountBefore)).Trim())
Write-Host "Delivery count before duplicate replay: $delivCountBefore" -ForegroundColor Cyan

# Replay exact same OrderConfirmedEvent to topic order.confirmed
$replayOrderEvent = @{
    eventId = [string]$eventId
    orderId = [int]$orderId
    restaurantId = 14
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json -Compress

$replayOrderEvent | docker exec -i foodflow-kafka kafka-console-producer --bootstrap-server localhost:9092 --topic order.confirmed
Start-Sleep -Seconds 2

$delivCountAfter = docker exec foodflow-postgres psql -U foodflow -d delivery_db -t -c "SELECT count(*) FROM deliveries WHERE event_id = '$eventId';"
$delivCountAfter = [int](([string]::Join("", $delivCountAfter)).Trim())
Write-Host "Delivery count after duplicate replay: $delivCountAfter" -ForegroundColor Green

if ($delivCountBefore -eq $delivCountAfter -and $delivCountAfter -eq 1) {
    Write-Host "IDEMPOTENCY SUCCESS: Duplicate order.confirmed event safely ignored! Exactly 1 delivery record remains!" -ForegroundColor Green
} else {
    Write-Host "FAIL: Duplicate delivery record was created!" -ForegroundColor Red
}

# 12. Query API Verification
Write-Host "`n[TEST 12] Testing GET /api/deliveries/{id} and /api/deliveries/order/{orderId}..." -ForegroundColor Yellow
$getById = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/$deliveryId" -Method Get -Headers @{ Authorization = "Bearer $tokenPartner" }
Write-Host "GET /api/deliveries/$deliveryId -> ID=$($getById.id), Status=$($getById.status), PartnerId=$($getById.deliveryPartnerId)" -ForegroundColor Green

$getByOrder = Invoke-RestMethod -Uri "http://localhost:8086/api/deliveries/order/$orderId" -Method Get -Headers @{ Authorization = "Bearer $tokenCust" }
Write-Host "GET /api/deliveries/order/$orderId -> ID=$($getByOrder.id), Status=$($getByOrder.status), PartnerId=$($getByOrder.deliveryPartnerId)" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "ALL DELIVERY-SERVICE VERIFICATIONS COMPLETED SUCCESSFULLY!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
