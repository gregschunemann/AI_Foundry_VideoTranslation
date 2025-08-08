[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Endpoint,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionKey,
    
    [Parameter(Mandatory = $false)]
    [string]$Region,
    
    [Parameter(Mandatory = $true)]
    [string]$VideoFileUrl,
    
    [Parameter(Mandatory = $true)]
    [string]$SourceLocale = "es-ES",
    
    [Parameter(Mandatory = $true)]
    [string]$TargetLocale = "en-US",
    
    [Parameter(Mandatory = $false)]
    [string]$TranslationId,
    
    [Parameter(Mandatory = $false)]
    [string]$DisplayName = "Video Translation",
    
    [Parameter(Mandatory = $false)]
    [string]$Description = "Video translation created via PowerShell",
    
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
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = $PSScriptRoot,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputRootDirectory,
    
    [Parameter(Mandatory = $false)]
    [switch]$AutoCreateIteration,
    
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

# Generate unique IDs if not provided
if (-not $TranslationId) {
    $TranslationId = [System.Guid]::NewGuid().ToString()
}

Write-Host "Starting Azure AI Video Translation Workflow" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
Write-Host "Video URL: $VideoFileUrl" -ForegroundColor Cyan
Write-Host "Source Language: $SourceLocale" -ForegroundColor Cyan
Write-Host "Target Language: $TargetLocale" -ForegroundColor Cyan
Write-Host ""

try {
    # Step 1: Create Translation Object
    Write-Host "Step 1: Creating translation object..." -ForegroundColor Yellow
    
    $translationParams = @{
        TranslationId = $TranslationId
        DisplayName = $DisplayName
        Description = $Description
        SourceLocale = $SourceLocale
        TargetLocale = $TargetLocale
        VideoFileUrl = $VideoFileUrl
        VoiceKind = $VoiceKind
        SpeakerCount = $SpeakerCount
        SubtitleMaxCharCountPerSegment = $SubtitleMaxCharCountPerSegment
        ExportSubtitleInVideo = $ExportSubtitleInVideo
        EnableLipSync = $EnableLipSync
        Config = $config
        OutputDirectory = $OutputDirectory
    }
    
    $translation = New-VideoTranslation @translationParams
    
    if ($translation.Status -eq "Failed") {
        Write-Error "Translation creation failed: $($translation.Error)"
        exit 1
    }
    
    Write-Host "Translation object created successfully!" -ForegroundColor Green
    Write-Host "Status: $($translation.Status)" -ForegroundColor Cyan
    
    # Wait for translation creation to complete
    Write-Host "Waiting for translation creation to complete..." -ForegroundColor Yellow
    $translationReady = Wait-ForOperationCompletion -OperationId $translation.OperationId -Config $config -MaxWaitTimeMinutes $MaxWaitTimeMinutes -PollingIntervalSeconds $PollingIntervalSeconds
    
    if (-not $translationReady -or $translationReady.Status -ne "Succeeded") {
        Write-Error "Translation creation did not complete successfully."
        exit 1
    }
    
    Write-Host "Translation object is ready!" -ForegroundColor Green
    
    # Step 2: Create First Iteration (if requested)
    if ($AutoCreateIteration) {
        Write-Host "`nStep 2: Creating first iteration..." -ForegroundColor Yellow
        
        $iterationId = [System.Guid]::NewGuid().ToString()
        $iteration = New-VideoTranslationIteration -TranslationId $TranslationId -IterationId $iterationId -Config $config -OutputDirectory $OutputDirectory
        
        if ($iteration.Status -eq "Failed") {
            Write-Error "Iteration creation failed: $($iteration.Error)"
            exit 1
        }
        
        Write-Host "Iteration created successfully!" -ForegroundColor Green
        Write-Host "Iteration ID: $iterationId" -ForegroundColor Cyan
        Write-Host "Status: $($iteration.Status)" -ForegroundColor Cyan
        
        # Wait for iteration to complete
        Write-Host "Waiting for iteration to complete..." -ForegroundColor Yellow
        $iterationReady = Wait-ForOperationCompletion -OperationId $iteration.OperationId -Config $config -MaxWaitTimeMinutes $MaxWaitTimeMinutes -PollingIntervalSeconds $PollingIntervalSeconds
        
        if (-not $iterationReady -or $iterationReady.Status -ne "Succeeded") {
            Write-Error "Iteration did not complete successfully."
            exit 1
        }
        
        Write-Host "Iteration completed successfully!" -ForegroundColor Green
        
        # Step 3: Download Results (if requested)
        if ($AutoDownload) {
            Write-Host "`nStep 3: Downloading translated video and subtitles..." -ForegroundColor Yellow
            
            $downloadResult = Get-VideoTranslationResults -TranslationId $TranslationId -IterationId $iterationId -Config $config -OutputDirectory $DownloadDirectory
            
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
            Write-Host "`nIteration completed. Use Get-VideoTranslationResults to download the translated video and subtitles." -ForegroundColor Yellow
            Write-Host "Example: Get-VideoTranslationResults -TranslationId '$TranslationId' -IterationId '$iterationId'" -ForegroundColor Cyan
        }
    } else {
        Write-Host "`nTranslation object created. Use New-VideoTranslationIteration to start the translation process." -ForegroundColor Yellow
        Write-Host "Example: New-VideoTranslationIteration -TranslationId '$TranslationId'" -ForegroundColor Cyan
    }
    
    # Final Summary
    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host "Video Translation Workflow Summary" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
    Write-Host "Source Language: $SourceLocale" -ForegroundColor Cyan
    Write-Host "Target Language: $TargetLocale" -ForegroundColor Cyan
    Write-Host "Status: Completed" -ForegroundColor Green
    
    if ($AutoCreateIteration) {
        Write-Host "Iteration ID: $iterationId" -ForegroundColor Cyan
        if ($AutoDownload) {
            Write-Host "Files Downloaded: Yes" -ForegroundColor Green
        } else {
            Write-Host "Files Downloaded: No (use Get-VideoTranslationResults)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    if (-not $AutoCreateIteration) {
        Write-Host "1. Create an iteration: New-VideoTranslationIteration -TranslationId '$TranslationId'" -ForegroundColor White
    } elseif (-not $AutoDownload) {
        Write-Host "1. Download results: Get-VideoTranslationResults -TranslationId '$TranslationId' -IterationId '$iterationId'" -ForegroundColor White
    } else {
        Write-Host "1. Check downloaded files in the created VideoTranslation folder" -ForegroundColor White
        Write-Host "2. Create additional iterations if needed for quality improvements" -ForegroundColor White
    }
    
} catch {
    Write-Error "An error occurred during the video translation workflow: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}
