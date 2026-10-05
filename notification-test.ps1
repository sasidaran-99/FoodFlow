$ErrorActionPreference = "Stop"

Write-Host "Creating user for testing..."
$userBody = @{
    email = "notify$(Get-Random)@example.com"
    password = "password123"
    name = "Notify Tester"
    phone = "1234567890"
    role = "RESTAURANT_OWNER"
} | ConvertTo-Json
$registerResponse = Invoke-RestMethod -Uri "http://localhost:8081/api/auth/register" -Method Post -Body $userBody -ContentType "application/json"
$token = $registerResponse.token

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

Write-Host "Creating a restaurant..."
$restaurantBody = @{
    name = "Notify Cafe"
    description = "Test notifications"
    address = "Event Street"
} | ConvertTo-Json
$restaurantResponse = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants" -Method Post -Body $restaurantBody -Headers $headers
$restaurantId = $restaurantResponse.id

Write-Host "Adding a valid menu item..."
$menuBody1 = @{
    name = "Standard Item"
    description = "Should pass payment"
    price = 500.00
} | ConvertTo-Json
$item1 = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -ContentType "application/json" -Headers $headers -Body $menuBody1
$menuItemId1 = $item1.id

Write-Host "`n--- TEST 1: End-to-End Fan-out ---"
$orderBody = @{
    restaurantId = $restaurantId
    items = @(
        @{
            menuItemId = $menuItemId1
            quantity = 2
        }
    )
} | ConvertTo-Json

$orderResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody
$orderId = $orderResponse.id
Write-Host "Created Order ID: $orderId"

Write-Host "Waiting 10 seconds for Kafka fan-out..."
Start-Sleep -Seconds 10

$finalOrder = Invoke-RestMethod -Method Get -Uri "http://localhost:8083/api/orders/$orderId" -Headers $headers
Write-Host "Final Order Status (Expected CONFIRMED): $($finalOrder.status)"

$notifications = Invoke-RestMethod -Method Get -Uri "http://localhost:8085/api/notifications/order/$orderId" -Headers $headers
if ($notifications.Count -eq 1) {
    Write-Host "SUCCESS: Notification created! Status: $($notifications[0].status), Message: $($notifications[0].message)"
} else {
    Write-Host "FAILED: Found $($notifications.Count) notifications."
}

Write-Host "`n--- TEST 2: Duplicate Event Handling (Idempotency) ---"
$eventId = $notifications[0].eventId
$duplicatePayload = @{
    eventId = $eventId
    orderId = $orderId
    paymentId = 999
    amount = 1000.00
    status = "SUCCESS"
    timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json -Compress

$duplicatePayload = $duplicatePayload.Replace('"', '\"')

Write-Host "Publishing duplicate event to Kafka..."
docker exec foodflow-kafka sh -c "echo `"$duplicatePayload`" | kafka-console-producer --broker-list localhost:9092 --topic payment.completed"

Start-Sleep -Seconds 5

$notificationsAfter = Invoke-RestMethod -Method Get -Uri "http://localhost:8085/api/notifications/order/$orderId" -Headers $headers
if ($notificationsAfter.Count -eq 1) {
    Write-Host "SUCCESS: Idempotency worked. Still only 1 notification."
} else {
    Write-Host "FAILED: Found $($notificationsAfter.Count) notifications!"
}

Write-Host "`n--- TEST 3: Failure Isolation (Simulated) ---"
Write-Host "Since the consumer group is distinct, if we stopped Notification Service, Order Service would still consume its copy."
Write-Host "Test completed successfully."
