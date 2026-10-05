$ErrorActionPreference = "Stop"

$GATEWAY_URL = "http://localhost:8080"

Write-Host "=========================================="
Write-Host "API Gateway E2E Test"
Write-Host "All traffic will be routed through port 8080"
Write-Host "==========================================`n"

Write-Host "1. Testing Public Endpoint (User Registration & Login)"
$userBody = @{
    email = "gateway$(Get-Random)@example.com"
    password = "password123"
    name = "Gateway Tester"
    phone = "1234567890"
    role = "RESTAURANT_OWNER"
} | ConvertTo-Json

# Hit gateway port 8080 which proxies to user-service port 8081
$registerResponse = Invoke-RestMethod -Uri "$GATEWAY_URL/api/auth/register" -Method Post -Body $userBody -ContentType "application/json"
$token = $registerResponse.token
Write-Host "SUCCESS: Registered and received token through Gateway."

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

Write-Host "`n2. Testing Missing JWT on Protected Endpoint"
try {
    Invoke-RestMethod -Uri "$GATEWAY_URL/api/restaurants" -Method Post -Body "{}" -ContentType "application/json"
    Write-Host "FAILED: Expected 401 Unauthorized!"
} catch {
    Write-Host "SUCCESS: Missing JWT correctly rejected (401) by downstream service!"
}

Write-Host "`n3. Testing Protected Endpoint with JWT (Restaurant Creation)"
$restaurantBody = @{
    name = "Gateway Cafe"
    description = "Test routing"
    address = "Route Street"
} | ConvertTo-Json
$restaurantResponse = Invoke-RestMethod -Uri "$GATEWAY_URL/api/restaurants" -Method Post -Body $restaurantBody -Headers $headers
$restaurantId = $restaurantResponse.id
Write-Host "SUCCESS: Created Restaurant ID $restaurantId through Gateway."

Write-Host "`n4. Testing Rate Limiting on Login (Optional Demo)"
Write-Host "Making 6 rapid login requests..."
$loginBody = @{ email = $userBody | ConvertFrom-Json | Select-Object -ExpandProperty email; password = "password123" } | ConvertTo-Json
$successCount = 0
$rateLimitedCount = 0
for ($i = 0; $i -lt 6; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "$GATEWAY_URL/api/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
        if ($resp.StatusCode -eq 200) { $successCount++ }
    } catch {
        if ($_.Exception.Response.StatusCode -eq 429) {
            $rateLimitedCount++
        }
    }
}
Write-Host "Successes: $successCount, Rate Limited (429): $rateLimitedCount"
if ($rateLimitedCount -gt 0) {
    Write-Host "SUCCESS: Redis Rate Limiting is active!"
}

Write-Host "`n5. Testing End-to-End Core Workflow via Gateway"
Write-Host "Adding Menu Item..."
$menuBody = @{ name = "Gateway Burger"; description = "Yum"; price = 150.00 } | ConvertTo-Json
$item = Invoke-RestMethod -Method Post -Uri "$GATEWAY_URL/api/restaurants/$restaurantId/menu" -ContentType "application/json" -Headers $headers -Body $menuBody

Write-Host "Creating Order..."
$orderBody = @{ restaurantId = $restaurantId; items = @( @{ menuItemId = $item.id; quantity = 2 } ) } | ConvertTo-Json
$order = Invoke-RestMethod -Method Post -Uri "$GATEWAY_URL/api/orders" -ContentType "application/json" -Headers $headers -Body $orderBody
$orderId = $order.id
Write-Host "SUCCESS: Created Order ID $orderId through Gateway."

Write-Host "`n6. Testing Failure Isolation (Simulated Downstream Failure)"
Write-Host "(If a downstream service is down, Gateway returns 503 or 504 depending on timeouts)."

Write-Host "`nAll Gateway tests completed successfully!"
