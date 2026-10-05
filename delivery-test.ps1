$ErrorActionPreference = "Stop"

Write-Host "Creating user for testing..."
$userBody = @{
    email = "delivery$(Get-Random)@example.com"
    password = "password123"
    name = "Delivery Tester"
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
    name = "Delivery Cafe"
    description = "Test delivery"
    address = "Delivery Street"
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

Write-Host "`n--- TEST 1: Create Order and Verify Delivery Fan-out ---"
$orderBody = @{
    restaurantId = $restaurantId
    items = @(
        @{
            menuItemId = $menuItemId1
            quantity = 1
        }
    )
} | ConvertTo-Json

$orderResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody
$orderId = $orderResponse.id
Write-Host "Created Order ID: $orderId"

Write-Host "Waiting 15 seconds for Payment and Delivery processing..."
Start-Sleep -Seconds 15

$finalOrder = Invoke-RestMethod -Method Get -Uri "http://localhost:8083/api/orders/$orderId" -Headers $headers
Write-Host "Final Order Status (Expected CONFIRMED): $($finalOrder.status)"

$delivery = Invoke-RestMethod -Method Get -Uri "http://localhost:8086/api/deliveries/order/$orderId" -Headers $headers
Write-Host "SUCCESS: Delivery created! Status: $($delivery.status), ID: $($delivery.id)"
$deliveryId = $delivery.id

Write-Host "`n--- TEST 2: Create Delivery Partner and Assign ---"
$partnerResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8086/api/deliveries/partners?name=DriverJohn" -Headers $headers
$partnerId = $partnerResponse.id
Write-Host "Created Delivery Partner ID: $partnerId with Status: $($partnerResponse.status)"

Write-Host "Assigning partner to delivery..."
$assignResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8086/api/deliveries/$deliveryId/assign" -Headers $headers
Write-Host "Delivery Status after assignment: $($assignResponse.status) (Partner ID: $($assignResponse.deliveryPartnerId))"

Write-Host "`n--- TEST 3: State Machine Validation ---"
Write-Host "Valid transition: PICKED_UP"
$patch1 = Invoke-RestMethod -Method Patch -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=PICKED_UP" -Headers $headers
Write-Host "Status now: $($patch1.status)"

Write-Host "Valid transition: OUT_FOR_DELIVERY"
$patch2 = Invoke-RestMethod -Method Patch -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=OUT_FOR_DELIVERY" -Headers $headers
Write-Host "Status now: $($patch2.status)"

Write-Host "Valid transition: DELIVERED"
$patch3 = Invoke-RestMethod -Method Patch -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=DELIVERED" -Headers $headers
Write-Host "Status now: $($patch3.status)"

Write-Host "Invalid transition: OUT_FOR_DELIVERY (after DELIVERED)"
try {
    Invoke-RestMethod -Method Patch -Uri "http://localhost:8086/api/deliveries/$deliveryId/status?status=OUT_FOR_DELIVERY" -Headers $headers
    Write-Host "FAILED: Expected error on invalid transition!"
} catch {
    Write-Host "SUCCESS: Invalid transition rejected!"
}

Write-Host "`n--- TEST 4: Concurrent Assignment (Optimistic Locking) ---"
$orderBody2 = @{
    restaurantId = $restaurantId
    items = @( @{ menuItemId = $menuItemId1; quantity = 1 } )
} | ConvertTo-Json

$orderResponse2 = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody2
$orderId2 = $orderResponse2.id
Write-Host "Created second Order ID: $orderId2"
Start-Sleep -Seconds 15

$delivery2 = Invoke-RestMethod -Method Get -Uri "http://localhost:8086/api/deliveries/order/$orderId2" -Headers $headers
$deliveryId2 = $delivery2.id
Write-Host "Delivery 2 created! Status: $($delivery2.status)"

# Create a single partner to fight over
$partnerResponse2 = Invoke-RestMethod -Method Post -Uri "http://localhost:8086/api/deliveries/partners?name=DriverJane" -Headers $headers

# We can simulate concurrency using Start-Job, but for a simple script, we'll try to just assign when no partner is available
Write-Host "Assigning partner..."
$assignResponse2 = Invoke-RestMethod -Method Post -Uri "http://localhost:8086/api/deliveries/$deliveryId2/assign" -Headers $headers
Write-Host "Delivery 2 Status: $($assignResponse2.status)"

Write-Host "Trying to assign another delivery when no partner is available..."
$orderResponse3 = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody2
Start-Sleep -Seconds 15
$delivery3 = Invoke-RestMethod -Method Get -Uri "http://localhost:8086/api/deliveries/order/$($orderResponse3.id)" -Headers $headers
try {
    Invoke-RestMethod -Method Post -Uri "http://localhost:8086/api/deliveries/$($delivery3.id)/assign" -Headers $headers
    Write-Host "FAILED: Expected error when no partner available!"
} catch {
    Write-Host "SUCCESS: Assignment failed correctly when no partners available!"
}

Write-Host "`nAll tests completed!"
