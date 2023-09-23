# Define the path to your configuration file
$configFileUrl = "https://raw.githubusercontent.com/vamsi560/everest/main/config.txt"

# Download the configuration file from the URL
try {
    $configContent = Invoke-RestMethod -Uri $configFileUrl -ErrorAction Stop
} catch {
    Write-Error "Failed to download the configuration file. Error: $_"
    exit 1
}

# Check if $configContent is not null before proceeding
if ($null -eq $configContent) {
    Write-Error "Failed to download the configuration file. The content is null."
    exit 1
}

# Convert the configuration content into an array of lines
$config = $configContent -split [Environment]::NewLine | ForEach-Object {
    $key, $value = $_ -split "="
    [PSCustomObject]@{
        Key = $key.Trim()
        Value = $value.Trim()
    }
}


# Access values from the configuration object
$subscriptionId = $config | Where-Object { $_.Key -eq "SubscriptionId" } | Select-Object -ExpandProperty Value
$resourceGroupName = $config | Where-Object { $_.Key -eq "ResourceGroupName" } | Select-Object -ExpandProperty Value
$apiName = $config | Where-Object { $_.Key -eq "ApiName" } | Select-Object -ExpandProperty Value
$specificationUrl = $config | Where-Object { $_.Key -eq "SpecificationUrl" } | Select-Object -ExpandProperty Value
$apiId = $config | Where-Object { $_.Key -eq "ApiId" } | Select-Object -ExpandProperty Value
$apimName = $config | Where-Object { $_.Key -eq "ApimName" } | Select-Object -ExpandProperty Value
$apiPolicyConfigFilePath = $config | Where-Object { $_.Key -eq "ApiPolicyConfigFilePath" } | Select-Object -ExpandProperty Value
$apiVisibility = $config | Where-Object { $_.Key -eq "ApiVisibility" } | Select-Object -ExpandProperty Value
$swagger2postmanPath = $config | Where-Object { $_.Key -eq "Swagger2PostmanPath" } | Select-Object -ExpandProperty Value
$postmanCollectionFilePath = $config | Where-Object { $_.Key -eq "PostmanCollectionFilePath" } | Select-Object -ExpandProperty Value

# Authenticate with your Azure account
az login

# Step 1: API Creation and Validation
# Create API in APIM using validated OAS specification
az apim api import --resource-group $resourceGroupName --service-name $apimName --path "/$apiName" --api-id $apiId --specification-url $specificationUrl --specification-format OpenApiJson

# Step 2: Azure API Management Setup
# If APIM instance does not exist, create it
$existingApim = az apim show --name $apimName --resource-group $resourceGroupName --query "name" -o tsv
if (-not $existingApim) {
    az apim create --name $apimName --resource-group $resourceGroupName --publisher-email "your_publisher_email" --publisher-name "your_publisher_name"
}

# Step 3: Policies Configuration
# Apply policies to the created API using your policy config file
az apim api update --resource-group $resourceGroupName --service-name $apimName --api-id $apiId --set "policies=@$apiPolicyConfigFilePath"

# Step 4: API Publishing and Visibility
# Publish the API and set visibility
az apim api update --resource-group $resourceGroupName --service-name $apimName --api-id $apiName

# Associate the API with the existing product "Unlimited"
az apim product api add --resource-group $resourceGroupName --service-name $apimName --product-id "Unlimited" --api-id $apiId

# Step 6: Testing and Postman Collection Generation
# Execute Swagger2Postman to convert OAS to Postman collection
Start-Process -FilePath $swagger2postmanPath -ArgumentList "convert -i $specificationUrl -o $postmanCollectionFilePath"

# Wait for the process to complete (adjust the timeout as needed)
Start-Sleep -Seconds 5

# Optionally, you can check if the output file exists to ensure successful conversion
if (Test-Path $postmanCollectionFilePath) {
    Write-Output "Postman collection generated successfully."
} else {
    Write-Output "Failed to generate Postman collection."
}

Write-Output "Script execution completed."
