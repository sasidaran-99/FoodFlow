$loginBody = @{
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8081/api/auth/login" -ContentType "application/json" -Body $loginBody
$token = $loginResponse.token
Write-Host "Token obtained"

$headers = @{
    Authorization = "Bearer $token"
}

# 1. Create Restaurant
$restaurantBody = @{
    name = "Kafka Test Restaurant"
    description = "Test Order Description"
    address = "123 Order Street"
} | ConvertTo-Json

$restaurantResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants" -ContentType "application/json" -Headers $headers -Body $restaurantBody
$restaurantId = $restaurantResponse.id
Write-Host "Created Restaurant ID: $restaurantId"

# 2. Add Menu Item (Valid Amount)
$menuBody1 = @{
    name = "Standard Item"
    description = "Should pass payment"
    price = 500.00
} | ConvertTo-Json

$menuResponse1 = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -ContentType "application/json" -Headers $headers -Body $menuBody1
$menuItemId1 = $menuResponse1.id
Write-Host "Created Valid Menu Item ID: $menuItemId1"

# 3. Add Menu Item (High Amount)
$menuBody2 = @{
    name = "Expensive Item"
    description = "Should fail payment"
    price = 6000.00
} | ConvertTo-Json

$menuResponse2 = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -ContentType "application/json" -Headers $headers -Body $menuBody2
$menuItemId2 = $menuResponse2.id
Write-Host "Created Expensive Menu Item ID: $menuItemId2"

# 4. Create Order 1 (Success Flow)
$orderBody1 = @{
    restaurantId = $restaurantId
    items = @(
        @{
            menuItemId = $menuItemId1
            quantity = 2
        }
    )
} | ConvertTo-Json

$orderResponse1 = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody1
$orderId1 = $orderResponse1.id
Write-Host "Created Order 1 ID: $orderId1 with initial status: $($orderResponse1.status)"

# 5. Create Order 2 (Failed Flow)
$orderBody2 = @{
    restaurantId = $restaurantId
    items = @(
        @{
            menuItemId = $menuItemId2
            quantity = 1
        }
    )
} | ConvertTo-Json

$orderResponse2 = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody2
$orderId2 = $orderResponse2.id
Write-Host "Created Order 2 ID: $orderId2 with initial status: $($orderResponse2.status)"

# 6. Wait for Kafka to process messages
Write-Host "Waiting 10 seconds for Kafka event processing..."
Start-Sleep -Seconds 10

# 7. Check final states
$finalOrder1 = Invoke-RestMethod -Method Get -Uri "http://localhost:8083/api/orders/$orderId1" -ContentType "application/json" -Headers $headers
Write-Host "Final Order 1 Status (Expected CONFIRMED): $($finalOrder1.status)"

$finalOrder2 = Invoke-RestMethod -Method Get -Uri "http://localhost:8083/api/orders/$orderId2" -ContentType "application/json" -Headers $headers
Write-Host "Final Order 2 Status (Expected PAYMENT_FAILED): $($finalOrder2.status)"
