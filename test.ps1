$body = @{
    email = "test@example.com"
    password = "password123"
    name = "Test User"
    phone = "9876543210"
    role = "RESTAURANT_OWNER"
} | ConvertTo-Json

$response = Invoke-RestMethod -Method Post -Uri "http://localhost:8081/api/auth/register" -ContentType "application/json" -Body $body
$response | ConvertTo-Json

$loginBody = @{
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8081/api/auth/login" -ContentType "application/json" -Body $loginBody
$loginResponse | ConvertTo-Json

$token = $loginResponse.token

$restaurantBody = @{
    name = "Test Restaurant"
    description = "Test Description"
    address = "123 Test Street"
} | ConvertTo-Json

$headers = @{
    Authorization = "Bearer $token"
}

$restaurantResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8082/api/restaurants" -ContentType "application/json" -Headers $headers -Body $restaurantBody
$restaurantResponse | ConvertTo-Json
