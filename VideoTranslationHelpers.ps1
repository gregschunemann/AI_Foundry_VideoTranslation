# Video Translation Helper Functions
# This file contains all the helper functions for Azure AI Video Translation

function Initialize-VideoTranslationConfig {
    [CmdletBinding()]
    param(
        [string]$Endpoint,
        [string]$SubscriptionKey,
        [string]$Region
    )
    
    # Try to load from environment variables if parameters not provided
    if (-not $Endpoint) {
        $Endpoint = $env:AZURE_SPEECH_ENDPOINT
    }
    if (-not $SubscriptionKey) {
        $SubscriptionKey = $env:AZURE_SPEECH_KEY
    }
    if (-not $Region) {
        $Region = $env:AZURE_SPEECH_REGION
    }
    
    # Validate required parameters
    if (-not $Endpoint -or -not $SubscriptionKey -or -not $Region) {
        Write-Error "Missing required configuration. Please provide Endpoint, SubscriptionKey, and Region either as parameters or environment variables."
        Write-Host "Required environment variables:" -ForegroundColor Yellow
        Write-Host "  AZURE_SPEECH_ENDPOINT" -ForegroundColor Cyan
        Write-Host "  AZURE_SPEECH_KEY" -ForegroundColor Cyan
        Write-Host "  AZURE_SPEECH_REGION" -ForegroundColor Cyan
        return $null
    }
    
    # Ensure endpoint has proper format
    if (-not $Endpoint.StartsWith("https://")) {
        if ($Endpoint.StartsWith("http://")) {
            $Endpoint = $Endpoint.Replace("http://", "https://")
            Write-Warning "Changed endpoint from HTTP to HTTPS for security"
        } else {
            $Endpoint = "https://$Endpoint"
        }
    }
    
    # Remove trailing slash if present
    $Endpoint = $Endpoint.TrimEnd('/')
    
    return @{
        Endpoint = $Endpoint
        SubscriptionKey = $SubscriptionKey
        Region = $Region
        ApiVersion = "2024-05-20-preview"
        BaseUrl = "$Endpoint/videotranslation"
    }
}

function Invoke-VideoTranslationApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $true)]
        [string]$Method,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Body = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$OperationId,
        
        [Parameter(Mandatory = $false)]
        [string]$ContentType = "application/json"
    )
    
    try {
        # Prepare headers
        $headers = @{
            "Ocp-Apim-Subscription-Key" = $Config.SubscriptionKey
            "Content-Type" = $ContentType
        }
        
        # Add Operation-Id if provided
        if ($OperationId) {
            $headers["Operation-Id"] = $OperationId
        }
        
        # Prepare request parameters
        $requestParams = @{
            Uri = $Uri
            Method = $Method
            Headers = $headers
        }
        
        # Add body for non-GET requests
        if ($Method -ne "GET" -and $Body.Count -gt 0) {
            $requestParams.Body = ($Body | ConvertTo-Json -Depth 10)
        }
        
        Write-Verbose "Making API request: $Method $Uri"
        if ($Body.Count -gt 0) {
            Write-Verbose "Request body: $($requestParams.Body)"
        }
        
        # Make the API call with retry logic
        $response = Invoke-RestMethodWithRetry @requestParams
        
        return @{
            Success = $true
            Data = $response
            StatusCode = 200
        }
        
    } catch {
        $errorDetails = $_.Exception.Message
        $statusCode = 0
        
        if ($_.Exception -is [System.Net.WebException]) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $errorDetails = Get-ErrorDetailsFromResponse -Exception $_.Exception
        }
        
        Write-Error "API call failed: $errorDetails"
        
        return @{
            Success = $false
            Error = $errorDetails
            StatusCode = $statusCode
        }
    }
}

function Invoke-RestMethodWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter(Mandatory = $true)]
        [string]$Method,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,
        
        [Parameter(Mandatory = $false)]
        [string]$Body,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$BaseDelaySeconds = 2
    )
    
    $attempt = 0
    $lastError = $null
    
    do {
        try {
            $attempt++
            
            if ($attempt -gt 1) {
                $delay = [Math]::Pow(2, $attempt - 1) * $BaseDelaySeconds
                Write-Verbose "Retrying in $delay seconds... (Attempt $attempt of $($MaxRetries + 1))"
                Start-Sleep -Seconds $delay
            }
            
            $requestParams = @{
                Uri = $Uri
                Method = $Method
                Headers = $Headers
            }
            
            if ($Body) {
                $requestParams.Body = $Body
            }
            
            return Invoke-RestMethod @requestParams
            
        } catch {
            $lastError = $_
            
            # Check if this is a retryable error
            $isRetryable = $false
            if ($_.Exception -is [System.Net.WebException]) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                $isRetryable = $statusCode -in @(429, 500, 502, 503, 504)
            }
            
            if ($attempt -le $MaxRetries -and $isRetryable) {
                Write-Warning "Request failed with retryable error. Will retry... (Attempt $attempt of $($MaxRetries + 1))"
                continue
            } else {
                throw $lastError
            }
        }
    } while ($attempt -le $MaxRetries)
    
    throw $lastError
}

function Get-ErrorDetailsFromResponse {
    [CmdletBinding()]
    param(
        [System.Exception]$Exception
    )
    
    try {
        if ($Exception -is [System.Net.WebException] -and $Exception.Response) {
            $stream = $Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseText = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            try {
                $errorObject = $responseText | ConvertFrom-Json
                if ($errorObject.error) {
                    return "$($errorObject.error.code): $($errorObject.error.message)"
                } elseif ($errorObject.message) {
                    return $errorObject.message
                } else {
                    return $responseText
                }
            } catch {
                return $responseText
            }
        }
    } catch {
        # If we can't parse the error, return the original message
    }
    
    return $Exception.Message
}

function New-VideoTranslation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranslationId,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "",
        
        [Parameter(Mandatory = $true)]
        [string]$SourceLocale,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetLocale,
        
        [Parameter(Mandatory = $true)]
        [string]$VideoFileUrl,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("PlatformVoice", "PersonalVoice")]
        [string]$VoiceKind = "PlatformVoice",
        
        [Parameter(Mandatory = $false)]
        [int]$SpeakerCount = 1,
        
        [Parameter(Mandatory = $false)]
        [int]$SubtitleMaxCharCountPerSegment = 50,
        
        [Parameter(Mandatory = $false)]
        [bool]$ExportSubtitleInVideo = $false,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableLipSync = $false,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = $PWD
    )
    
    $operationId = [System.Guid]::NewGuid().ToString()
    $uri = "$($Config.BaseUrl)/translations/$TranslationId" + "?api-version=$($Config.ApiVersion)"
    
    $requestBody = @{
        displayName = $DisplayName
        description = $Description
        input = @{
            sourceLocale = $SourceLocale
            targetLocale = $TargetLocale
            voiceKind = $VoiceKind
            speakerCount = $SpeakerCount
            subtitleMaxCharCountPerSegment = $SubtitleMaxCharCountPerSegment
            exportSubtitleInVideo = $ExportSubtitleInVideo
            enableLipSync = $EnableLipSync
            videoFileUrl = $VideoFileUrl
        }
    }
    
    Write-Verbose "Creating translation with ID: $TranslationId"
    Write-Verbose "Video URL: $VideoFileUrl"
    Write-Verbose "Source: $SourceLocale -> Target: $TargetLocale"
    
    $response = Invoke-VideoTranslationApi -Uri $uri -Method "PUT" -Config $Config -Body $requestBody -OperationId $operationId
    
    if ($response.Success) {
        # Save the response to file for tracking
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "translation_creation_${TranslationId}_${timestamp}.json"
        $filepath = Join-Path $OutputDirectory $filename
        
        $response.Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
        Write-Verbose "Translation creation response saved to: $filepath"
        
        return @{
            TranslationId = $TranslationId
            OperationId = $operationId
            Status = $response.Data.status
            DisplayName = $response.Data.displayName
            CreatedDateTime = $response.Data.createdDateTime
            Success = $true
            ResponseFile = $filepath
        }
    } else {
        return @{
            TranslationId = $TranslationId
            OperationId = $operationId
            Status = "Failed"
            Success = $false
            Error = $response.Error
        }
    }
}

function New-VideoTranslationIteration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranslationId,
        
        [Parameter(Mandatory = $false)]
        [string]$IterationId,
        
        [Parameter(Mandatory = $false)]
        [string]$WebVttFileUrl,
        
        [Parameter(Mandatory = $false)]
        [int]$SpeakerCount,
        
        [Parameter(Mandatory = $false)]
        [int]$SubtitleMaxCharCountPerSegment,
        
        [Parameter(Mandatory = $false)]
        [bool]$ExportSubtitleInVideo,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = $PWD
    )
    
    if (-not $IterationId) {
        $IterationId = [System.Guid]::NewGuid().ToString()
    }
    
    $operationId = [System.Guid]::NewGuid().ToString()
    $uri = "$($Config.BaseUrl)/translations/$TranslationId/iterations/$IterationId" + "?api-version=$($Config.ApiVersion)"
    
    # Build request body with only specified parameters
    $inputObject = @{}
    
    if ($PSBoundParameters.ContainsKey('SpeakerCount')) {
        $inputObject.speakerCount = $SpeakerCount
    }
    
    if ($PSBoundParameters.ContainsKey('SubtitleMaxCharCountPerSegment')) {
        $inputObject.subtitleMaxCharCountPerSegment = $SubtitleMaxCharCountPerSegment
    }
    
    if ($PSBoundParameters.ContainsKey('ExportSubtitleInVideo')) {
        $inputObject.exportSubtitleInVideo = $ExportSubtitleInVideo
    }
    
    if ($WebVttFileUrl) {
        $inputObject.webvttFile = @{
            url = $WebVttFileUrl
        }
    }
    
    $requestBody = @{
        input = $inputObject
    }
    
    Write-Verbose "Creating iteration with ID: $IterationId"
    Write-Verbose "Translation ID: $TranslationId"
    if ($WebVttFileUrl) {
        Write-Verbose "WebVTT File URL: $WebVttFileUrl"
    }
    
    $response = Invoke-VideoTranslationApi -Uri $uri -Method "PUT" -Config $Config -Body $requestBody -OperationId $operationId
    
    if ($response.Success) {
        # Save the response to file for tracking
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "iteration_creation_${TranslationId}_${IterationId}_${timestamp}.json"
        $filepath = Join-Path $OutputDirectory $filename
        
        $response.Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
        Write-Verbose "Iteration creation response saved to: $filepath"
        
        return @{
            TranslationId = $TranslationId
            IterationId = $IterationId
            OperationId = $operationId
            Status = $response.Data.status
            CreatedDateTime = $response.Data.createdDateTime
            Success = $true
            ResponseFile = $filepath
        }
    } else {
        return @{
            TranslationId = $TranslationId
            IterationId = $IterationId
            OperationId = $operationId
            Status = "Failed"
            Success = $false
            Error = $response.Error
        }
    }
}

function Get-VideoTranslationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranslationId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $uri = "$($Config.BaseUrl)/translations/$TranslationId" + "?api-version=$($Config.ApiVersion)"
    
    $response = Invoke-VideoTranslationApi -Uri $uri -Method "GET" -Config $Config
    
    if ($response.Success) {
        return @{
            Success = $true
            TranslationId = $response.Data.id
            Status = $response.Data.status
            DisplayName = $response.Data.displayName
            Description = $response.Data.description
            CreatedDateTime = $response.Data.createdDateTime
            LastActionDateTime = $response.Data.lastActionDateTime
            Input = $response.Data.input
        }
    } else {
        return @{
            Success = $false
            Error = $response.Error
        }
    }
}

function Get-VideoTranslationIterationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranslationId,
        
        [Parameter(Mandatory = $true)]
        [string]$IterationId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $uri = "$($Config.BaseUrl)/translations/$TranslationId/iterations/$IterationId" + "?api-version=$($Config.ApiVersion)"
    
    $response = Invoke-VideoTranslationApi -Uri $uri -Method "GET" -Config $Config
    
    if ($response.Success) {
        return @{
            Success = $true
            TranslationId = $TranslationId
            IterationId = $response.Data.id
            Status = $response.Data.status
            CreatedDateTime = $response.Data.createdDateTime
            LastActionDateTime = $response.Data.lastActionDateTime
            Input = $response.Data.input
            Result = $response.Data.result
        }
    } else {
        return @{
            Success = $false
            Error = $response.Error
        }
    }
}

function Get-OperationStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $uri = "$($Config.BaseUrl)/operations/$OperationId" + "?api-version=$($Config.ApiVersion)"
    
    $response = Invoke-VideoTranslationApi -Uri $uri -Method "GET" -Config $Config
    
    if ($response.Success) {
        return @{
            Success = $true
            OperationId = $response.Data.id
            Status = $response.Data.status
        }
    } else {
        return @{
            Success = $false
            Error = $response.Error
        }
    }
}

function Wait-ForOperationCompletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxWaitTimeMinutes = 60,
        
        [Parameter(Mandatory = $false)]
        [int]$PollingIntervalSeconds = 30
    )
    
    $maxWaitTime = [TimeSpan]::FromMinutes($MaxWaitTimeMinutes)
    $startTime = Get-Date
    $pollingInterval = [TimeSpan]::FromSeconds($PollingIntervalSeconds)
    
    Write-Verbose "Waiting for operation $OperationId to complete..."
    Write-Host "Polling every $PollingIntervalSeconds seconds (max wait: $MaxWaitTimeMinutes minutes)"
    
    do {
        $operationStatus = Get-OperationStatus -OperationId $OperationId -Config $Config
        
        if (-not $operationStatus.Success) {
            Write-Warning "Failed to get operation status: $($operationStatus.Error)"
            Start-Sleep -Seconds $PollingIntervalSeconds
            continue
        }
        
        $elapsed = (Get-Date) - $startTime
        $elapsedStr = "{0:mm\:ss}" -f $elapsed
        
        Write-Host "[$elapsedStr] Operation status: $($operationStatus.Status)" -ForegroundColor Cyan
        
        if ($operationStatus.Status -in @("Succeeded", "Failed", "Cancelled")) {
            return $operationStatus
        }
        
        if ($elapsed -lt $maxWaitTime) {
            Start-Sleep -Seconds $PollingIntervalSeconds
        }
        
    } while ($elapsed -lt $maxWaitTime)
    
    Write-Warning "Operation did not complete within the maximum wait time of $MaxWaitTimeMinutes minutes"
    return $null
}

function Get-VideoTranslationResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranslationId,
        
        [Parameter(Mandatory = $true)]
        [string]$IterationId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = $PWD
    )
    
    # Get the iteration status to retrieve download URLs
    $iterationStatus = Get-VideoTranslationIterationStatus -TranslationId $TranslationId -IterationId $IterationId -Config $Config
    
    if (-not $iterationStatus.Success) {
        return @{
            Success = $false
            Error = "Failed to get iteration status: $($iterationStatus.Error)"
        }
    }
    
    if ($iterationStatus.Status -ne "Succeeded") {
        return @{
            Success = $false
            Error = "Iteration is not in Succeeded status. Current status: $($iterationStatus.Status)"
        }
    }
    
    if (-not $iterationStatus.Result) {
        return @{
            Success = $false
            Error = "No result URLs available for this iteration"
        }
    }
    
    # Create organized folder structure
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $translationFolderName = "VideoTranslation_${TranslationId}_${timestamp}"
    $translationFolder = Join-Path $OutputDirectory $translationFolderName
    $videosFolder = Join-Path $translationFolder "Videos"
    $subtitlesFolder = Join-Path $translationFolder "Subtitles"
    $metadataFolder = Join-Path $translationFolder "Metadata"
    
    # Create the folder structure
    foreach ($folder in @($translationFolder, $videosFolder, $subtitlesFolder, $metadataFolder)) {
        if (-not (Test-Path $folder)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }
    
    Write-Host "Created download folder structure:" -ForegroundColor Cyan
    Write-Host "  📁 $translationFolderName/" -ForegroundColor White
    Write-Host "    📁 Videos/" -ForegroundColor White
    Write-Host "    📁 Subtitles/" -ForegroundColor White
    Write-Host "    📁 Metadata/" -ForegroundColor White
    Write-Host ""
    
    $downloadedFiles = @()
    $errors = @()
    
    # Download translated video
    if ($iterationStatus.Result.translatedVideoFileUrl) {
        try {
            $videoFilename = "translated_video_${TranslationId}_${IterationId}.mp4"
            $videoPath = Join-Path $videosFolder $videoFilename
            
            Write-Host "Downloading translated video..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $iterationStatus.Result.translatedVideoFileUrl -OutFile $videoPath
            $downloadedFiles += $videoPath
            Write-Host "Video downloaded: $videoPath" -ForegroundColor Green
        } catch {
            $errors += "Failed to download video: $($_.Exception.Message)"
        }
    }
    
    # Download source locale subtitles
    if ($iterationStatus.Result.sourceLocaleSubtitleWebvttFileUrl) {
        try {
            $sourceSubtitlesFilename = "source_subtitles_${TranslationId}_${IterationId}.vtt"
            $sourceSubtitlesPath = Join-Path $subtitlesFolder $sourceSubtitlesFilename
            
            Write-Host "Downloading source subtitles..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $iterationStatus.Result.sourceLocaleSubtitleWebvttFileUrl -OutFile $sourceSubtitlesPath
            $downloadedFiles += $sourceSubtitlesPath
            Write-Host "Source subtitles downloaded: $sourceSubtitlesPath" -ForegroundColor Green
        } catch {
            $errors += "Failed to download source subtitles: $($_.Exception.Message)"
        }
    }
    
    # Download target locale subtitles
    if ($iterationStatus.Result.targetLocaleSubtitleWebvttFileUrl) {
        try {
            $targetSubtitlesFilename = "target_subtitles_${TranslationId}_${IterationId}.vtt"
            $targetSubtitlesPath = Join-Path $subtitlesFolder $targetSubtitlesFilename
            
            Write-Host "Downloading target subtitles..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $iterationStatus.Result.targetLocaleSubtitleWebvttFileUrl -OutFile $targetSubtitlesPath
            $downloadedFiles += $targetSubtitlesPath
            Write-Host "Target subtitles downloaded: $targetSubtitlesPath" -ForegroundColor Green
        } catch {
            $errors += "Failed to download target subtitles: $($_.Exception.Message)"
        }
    }
    
    # Download metadata JSON
    if ($iterationStatus.Result.metadataJsonWebvttFileUrl) {
        try {
            $metadataFilename = "metadata_${TranslationId}_${IterationId}.vtt"
            $metadataPath = Join-Path $metadataFolder $metadataFilename
            
            Write-Host "Downloading metadata..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $iterationStatus.Result.metadataJsonWebvttFileUrl -OutFile $metadataPath
            $downloadedFiles += $metadataPath
            Write-Host "Metadata downloaded: $metadataPath" -ForegroundColor Green
        } catch {
            $errors += "Failed to download metadata: $($_.Exception.Message)"
        }
    }
    
    # Save iteration details to JSON file for reference
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $detailsFilename = "iteration_details_${TranslationId}_${IterationId}_${timestamp}.json"
        $detailsPath = Join-Path $metadataFolder $detailsFilename
        
        $iterationStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $detailsPath -Encoding UTF8
        $downloadedFiles += $detailsPath
        Write-Verbose "Iteration details saved to: $detailsPath"
    } catch {
        $errors += "Failed to save iteration details: $($_.Exception.Message)"
    }
    
    return @{
        Success = ($downloadedFiles.Count -gt 0)
        Files = $downloadedFiles
        Errors = $errors
        Error = if ($errors.Count -gt 0) { $errors -join "; " } else { $null }
        DownloadFolder = $translationFolder
    }
}

function Get-VideoTranslationList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $uri = "$($Config.BaseUrl)/translations" + "?api-version=$($Config.ApiVersion)"
    
    $response = Invoke-VideoTranslationApi -Uri $uri -Method "GET" -Config $Config
    
    if ($response.Success) {
        return @{
            Success = $true
            Translations = $response.Data.value
            Count = $response.Data.value.Count
        }
    } else {
        return @{
            Success = $false
            Error = $response.Error
        }
    }
}

function Remove-VideoTranslation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TranslationId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    if ($PSCmdlet.ShouldProcess($TranslationId, "Delete Video Translation")) {
        $uri = "$($Config.BaseUrl)/translations/$TranslationId" + "?api-version=$($Config.ApiVersion)"
        
        try {
            $response = Invoke-VideoTranslationApi -Uri $uri -Method "DELETE" -Config $Config
            
            return @{
                Success = $true
                TranslationId = $TranslationId
                Message = "Translation deleted successfully"
            }
        } catch {
            return @{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}
