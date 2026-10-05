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
    name = "Test Order Restaurant"
    description = "Test Order Description"
    address = "123 Order Street"
} | ConvertTo-Json

$restaurantResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants" -ContentType "application/json" -Headers $headers -Body $restaurantBody
$restaurantId = $restaurantResponse.id
Write-Host "Created Restaurant ID: $restaurantId"

# 2. Add Menu Item
$menuBody = @{
    name = "Biryani"
    description = "Chicken Biryani"
    price = 180.50
} | ConvertTo-Json

$menuResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -ContentType "application/json" -Headers $headers -Body $menuBody
$menuItemId = $menuResponse.id
Write-Host "Created Menu Item ID: $menuItemId with Price: $($menuResponse.price)"

# 3. Create Order
$orderBody = @{
    restaurantId = $restaurantId
    items = @(
        @{
            menuItemId = $menuItemId
            quantity = 2
        }
    )
} | ConvertTo-Json

$orderResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody
$orderId = $orderResponse.id
Write-Host "Created Order ID: $orderId with Total Amount: $($orderResponse.totalAmount)"

# 4. Fetch Order History
$ordersResponse = Invoke-RestMethod -Method Get -Uri "http://localhost:8083/api/orders" -ContentType "application/json" -Headers $headers
Write-Host "Fetched Order History, Total Elements: $($ordersResponse.totalElements)"

# 5. State Transitions
$transitions = @(
    "PAYMENT_PENDING",
    "CONFIRMED",
    "RESTAURANT_ACCEPTED",
    "PREPARING",
    "READY_FOR_PICKUP",
    "OUT_FOR_DELIVERY",
    "DELIVERED"
)

foreach ($state in $transitions) {
    $updateResponse = Invoke-RestMethod -Method Patch -Uri "http://localhost:8083/api/orders/$orderId/status?status=$state" -ContentType "application/json" -Headers $headers
    Write-Host "Transitioned Order to: $($updateResponse.status)"
}

# 6. Test Invalid Transition (DELIVERED to CANCELLED)
try {
    $invalidResponse = Invoke-RestMethod -Method Patch -Uri "http://localhost:8083/api/orders/$orderId/status?status=CANCELLED" -ContentType "application/json" -Headers $headers
    Write-Host "Error: Invalid transition succeeded!"
} catch {
    Write-Host "Expected Error Caught: $_"
}
