$ErrorActionPreference = "Stop"

Write-Host "Creating user for testing..."
$userBody = @{
    email = "redis$(Get-Random)@example.com"
    password = "password123"
    name = "Redis Tester"
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
    name = "Redis Cafe"
    description = "Fast data"
    address = "Cache Street"
} | ConvertTo-Json
$restaurantResponse = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants" -Method Post -Body $restaurantBody -Headers $headers
$restaurantId = $restaurantResponse.id
Write-Host "Restaurant created with ID: $restaurantId"

Write-Host "`n--- TEST 1: First Request (CACHE MISS) ---"
$start1 = Get-Date
$menu1 = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -Method Get -Headers $headers
$time1 = ((Get-Date) - $start1).TotalMilliseconds
Write-Host "Time: $time1 ms"

Write-Host "`n--- TEST 2: Second Request (CACHE HIT) ---"
$start2 = Get-Date
$menu2 = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -Method Get -Headers $headers
$time2 = ((Get-Date) - $start2).TotalMilliseconds
Write-Host "Time: $time2 ms (should be faster, verify in logs that DB was not hit)"

Write-Host "`n--- TEST 3: Add Menu Item (CACHE INVALIDATION) ---"
$menuItemBody = @{
    name = "Cached Burger"
    description = "Very fast"
    price = 500
} | ConvertTo-Json
$itemResponse = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -Method Post -Body $menuItemBody -Headers $headers
Write-Host "Menu item created with ID: $($itemResponse.id)"

Write-Host "`n--- TEST 4: Third Request (CACHE MISS due to invalidation) ---"
$start3 = Get-Date
$menu3 = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -Method Get -Headers $headers
$time3 = ((Get-Date) - $start3).TotalMilliseconds
Write-Host "Time: $time3 ms"
Write-Host "Menu count now: $($menu3.Count)"

Write-Host "`n--- TEST 5: Verify Redis Failure Fallback ---"
Write-Host "Stopping Redis container..."
docker stop foodflow-redis | Out-Null
Start-Sleep -Seconds 2

Write-Host "Making request while Redis is DOWN..."
$start4 = Get-Date
try {
    $menu4 = Invoke-RestMethod -Uri "http://localhost:8082/api/restaurants/$restaurantId/menu" -Method Get -Headers $headers
    $time4 = ((Get-Date) - $start4).TotalMilliseconds
    Write-Host "Time: $time4 ms"
    Write-Host "SUCCESS: Application survived Redis failure and fell back to Postgres!"
} catch {
    Write-Host "FAILED: Request threw an error when Redis was down."
}

Write-Host "Starting Redis container back up..."
docker start foodflow-redis | Out-Null

Write-Host "`nRedis testing completed successfully."
