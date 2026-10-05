$loginBody = @{
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod -Method Post -Uri "http://localhost:8081/api/auth/login" -ContentType "application/json" -Body $loginBody
$token = $loginResponse.token
Write-Host "Token obtained: $token"

$headers = @{
    Authorization = "Bearer $token"
}

# Test 1: Successful Payment
$paymentBody1 = @{
    orderId = 1001
    amount = 500.00
} | ConvertTo-Json

$headers.Add("Idempotency-Key", "idemp-key-001")

Write-Host "`n--- Test 1: Successful Payment ---"
$response1 = Invoke-RestMethod -Method Post -Uri "http://localhost:8084/api/payments" -ContentType "application/json" -Headers $headers -Body $paymentBody1
$response1 | ConvertTo-Json

# Test 2: Duplicate Idempotency Key (Idempotency check)
Write-Host "`n--- Test 2: Duplicate Request (Idempotency) ---"
$response2 = Invoke-RestMethod -Method Post -Uri "http://localhost:8084/api/payments" -ContentType "application/json" -Headers $headers -Body $paymentBody1
$response2 | ConvertTo-Json

if ($response1.id -eq $response2.id) {
    Write-Host "SUCCESS: Idempotency check passed! Exact same payment record returned."
} else {
    Write-Host "FAILED: Different payment IDs returned."
}

# Test 3: Failed Payment (Amount > 5000)
$paymentBody3 = @{
    orderId = 1002
    amount = 6000.00
} | ConvertTo-Json

$headers["Idempotency-Key"] = "idemp-key-002"

Write-Host "`n--- Test 3: Failed Payment (Due to mock constraint) ---"
$response3 = Invoke-RestMethod -Method Post -Uri "http://localhost:8084/api/payments" -ContentType "application/json" -Headers $headers -Body $paymentBody3
$response3 | ConvertTo-Json

if ($response3.status -eq "FAILED") {
    Write-Host "SUCCESS: High amount properly declined."
}

# Test 4: Invalid Amount Validation (Negative)
$paymentBody4 = @{
    orderId = 1003
    amount = -50.00
} | ConvertTo-Json

$headers["Idempotency-Key"] = "idemp-key-003"

Write-Host "`n--- Test 4: Invalid Amount ---"
try {
    Invoke-RestMethod -Method Post -Uri "http://localhost:8084/api/payments" -ContentType "application/json" -Headers $headers -Body $paymentBody4
    Write-Host "FAILED: Request succeeded when it should have failed validation!"
} catch {
    Write-Host "SUCCESS: Caught expected validation error: $_"
}

# Test 5: Missing Idempotency Key Header
$headers.Remove("Idempotency-Key")

Write-Host "`n--- Test 5: Missing Header ---"
try {
    Invoke-RestMethod -Method Post -Uri "http://localhost:8084/api/payments" -ContentType "application/json" -Headers $headers -Body $paymentBody1
    Write-Host "FAILED: Request succeeded when it should have required the header!"
} catch {
    Write-Host "SUCCESS: Caught expected missing header error: $_"
}
