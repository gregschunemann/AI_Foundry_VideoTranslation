[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Endpoint,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionKey,
    
    [Parameter(Mandatory = $false)]
    [string]$Region,
    
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
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = $PSScriptRoot,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputRootDirectory,
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoDownload,
    
    [Parameter(Mandatory = $false)]
    [int]$PollingIntervalSeconds = 30,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxWaitTimeMinutes = 60
)

# Import required modules and functions
. "$PSScriptRoot\VideoTranslationHelpers.ps1"

# Use OutputRootDirectory if specified, otherwise use OutputDirectory for backward compatibility
$DownloadDirectory = if ($OutputRootDirectory) { $OutputRootDirectory } else { $OutputDirectory }

# Initialize configuration
$config = Initialize-VideoTranslationConfig -Endpoint $Endpoint -SubscriptionKey $SubscriptionKey -Region $Region

if (-not $config) {
    Write-Error "Failed to initialize configuration. Please check your credentials."
    exit 1
}

# Generate unique iteration ID if not provided
if (-not $IterationId) {
    $IterationId = [System.Guid]::NewGuid().ToString()
}

Write-Host "Creating New Video Translation Iteration" -ForegroundColor Green
Write-Host "=======================================" -ForegroundColor Green
Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
Write-Host "Iteration ID: $IterationId" -ForegroundColor Cyan

if ($WebVttFileUrl) {
    Write-Host "WebVTT File: $WebVttFileUrl" -ForegroundColor Cyan
}

Write-Host ""

try {
    # First, check if the translation exists
    Write-Host "Checking translation status..." -ForegroundColor Yellow
    $translationStatus = Get-VideoTranslationStatus -TranslationId $TranslationId -Config $config
    
    if (-not $translationStatus.Success) {
        Write-Error "Translation not found or inaccessible: $($translationStatus.Error)"
        exit 1
    }
    
    Write-Host "Translation found: $($translationStatus.DisplayName)" -ForegroundColor Green
    Write-Host "Translation Status: $($translationStatus.Status)" -ForegroundColor Cyan
    
    # Create the iteration
    Write-Host "`nCreating iteration..." -ForegroundColor Yellow
    
    $iterationParams = @{
        TranslationId = $TranslationId
        IterationId = $IterationId
        Config = $config
        OutputDirectory = $OutputDirectory
    }
    
    # Add optional parameters if provided
    if ($PSBoundParameters.ContainsKey('WebVttFileUrl') -and $WebVttFileUrl) {
        $iterationParams.WebVttFileUrl = $WebVttFileUrl
    }
    
    if ($PSBoundParameters.ContainsKey('SpeakerCount')) {
        $iterationParams.SpeakerCount = $SpeakerCount
    }
    
    if ($PSBoundParameters.ContainsKey('SubtitleMaxCharCountPerSegment')) {
        $iterationParams.SubtitleMaxCharCountPerSegment = $SubtitleMaxCharCountPerSegment
    }
    
    if ($PSBoundParameters.ContainsKey('ExportSubtitleInVideo')) {
        $iterationParams.ExportSubtitleInVideo = $ExportSubtitleInVideo
    }
    
    $iteration = New-VideoTranslationIteration @iterationParams
    
    if (-not $iteration.Success) {
        Write-Error "Iteration creation failed: $($iteration.Error)"
        exit 1
    }
    
    Write-Host "Iteration created successfully!" -ForegroundColor Green
    Write-Host "Status: $($iteration.Status)" -ForegroundColor Cyan
    Write-Host "Created: $($iteration.CreatedDateTime)" -ForegroundColor Cyan
    
    # Wait for iteration to complete
    Write-Host "`nWaiting for iteration to complete..." -ForegroundColor Yellow
    $iterationReady = Wait-ForOperationCompletion -OperationId $iteration.OperationId -Config $config -MaxWaitTimeMinutes $MaxWaitTimeMinutes -PollingIntervalSeconds $PollingIntervalSeconds
    
    if (-not $iterationReady -or $iterationReady.Status -ne "Succeeded") {
        Write-Error "Iteration did not complete successfully. Final status: $($iterationReady.Status)"
        exit 1
    }
    
    Write-Host "Iteration completed successfully!" -ForegroundColor Green
    
    # Download results if requested
    if ($AutoDownload) {
        Write-Host "`nDownloading results..." -ForegroundColor Yellow
        
        $downloadResult = Get-VideoTranslationResults -TranslationId $TranslationId -IterationId $IterationId -Config $config -OutputDirectory $DownloadDirectory
        
        if ($downloadResult.Success) {
            Write-Host "Download completed successfully!" -ForegroundColor Green
            Write-Host "Files downloaded to: $($downloadResult.DownloadFolder)" -ForegroundColor Cyan
            
            if ($downloadResult.Files.Count -gt 0) {
                Write-Host "`nDownloaded files:" -ForegroundColor Cyan
                foreach ($file in $downloadResult.Files) {
                    $relativePath = $file.Replace($downloadResult.DownloadFolder, "").TrimStart('\')
                    Write-Host "  - $relativePath" -ForegroundColor White
                }
            }
        } else {
            Write-Warning "Download failed: $($downloadResult.Error)"
        }
    } else {
        Write-Host "`nIteration completed successfully!" -ForegroundColor Green
        Write-Host "Use Get-VideoTranslationResults to download the translated video and subtitles." -ForegroundColor Yellow
        Write-Host "Example: Get-VideoTranslationResults -TranslationId '$TranslationId' -IterationId '$IterationId'" -ForegroundColor Cyan
    }
    
    # Final Summary
    Write-Host "`n=======================================" -ForegroundColor Green
    Write-Host "Video Translation Iteration Summary" -ForegroundColor Green
    Write-Host "=======================================" -ForegroundColor Green
    Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
    Write-Host "Iteration ID: $IterationId" -ForegroundColor Cyan
    Write-Host "Status: Completed Successfully" -ForegroundColor Green
    
    if ($AutoDownload) {
        Write-Host "Files Downloaded: Yes" -ForegroundColor Green
        Write-Host "Download Location: Check the VideoTranslation folder created" -ForegroundColor Cyan
    } else {
        Write-Host "Files Downloaded: No" -ForegroundColor Yellow
    }
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    if (-not $AutoDownload) {
        Write-Host "1. Download results: Get-VideoTranslationResults -TranslationId '$TranslationId' -IterationId '$IterationId'" -ForegroundColor White
    } else {
        Write-Host "1. Review downloaded files in the created VideoTranslation folder" -ForegroundColor White
    }
    Write-Host "2. Create additional iterations for quality improvements if needed" -ForegroundColor White
    Write-Host "3. Use the WebVTT metadata file to make targeted edits for subsequent iterations" -ForegroundColor White
    
} catch {
    Write-Error "An error occurred during iteration creation: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}
