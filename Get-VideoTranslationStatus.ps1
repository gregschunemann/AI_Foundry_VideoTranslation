[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Endpoint,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionKey,
    
    [Parameter(Mandatory = $false)]
    [string]$Region,
    
    [Parameter(Mandatory = $false)]
    [string]$TranslationId,
    
    [Parameter(Mandatory = $false)]
    [string]$IterationId,
    
    [Parameter(Mandatory = $false)]
    [string]$OperationId,
    
    [Parameter(Mandatory = $false)]
    [switch]$ListAll,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = $PSScriptRoot
)

# Import required modules and functions
. "$PSScriptRoot\VideoTranslationHelpers.ps1"

# Initialize configuration
$config = Initialize-VideoTranslationConfig -Endpoint $Endpoint -SubscriptionKey $SubscriptionKey -Region $Region

if (-not $config) {
    Write-Error "Failed to initialize configuration. Please check your credentials."
    exit 1
}

Write-Host "Video Translation Status Check" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green

try {
    if ($ListAll) {
        # List all translations
        Write-Host "Retrieving all video translations..." -ForegroundColor Yellow
        
        $translationList = Get-VideoTranslationList -Config $config
        
        if (-not $translationList.Success) {
            Write-Error "Failed to retrieve translation list: $($translationList.Error)"
            exit 1
        }
        
        if ($translationList.Count -eq 0) {
            Write-Host "No video translations found in your account." -ForegroundColor Yellow
            exit 0
        }
        
        Write-Host "Found $($translationList.Count) video translation(s):" -ForegroundColor Green
        Write-Host ""
        
        foreach ($translation in $translationList.Translations) {
            Write-Host "🎬 Translation: $($translation.displayName)" -ForegroundColor Cyan
            Write-Host "   ID: $($translation.id)" -ForegroundColor White
            Write-Host "   Status: $($translation.status)" -ForegroundColor $(
                switch ($translation.status) {
                    "Succeeded" { "Green" }
                    "Failed" { "Red" }
                    "Running" { "Yellow" }
                    default { "White" }
                }
            )
            Write-Host "   Source: $($translation.input.sourceLocale)" -ForegroundColor Gray
            Write-Host "   Target: $($translation.input.targetLocale)" -ForegroundColor Gray
            Write-Host "   Created: $($translation.createdDateTime)" -ForegroundColor Gray
            Write-Host "   Last Updated: $($translation.lastActionDateTime)" -ForegroundColor Gray
            Write-Host ""
        }
        
    } elseif ($OperationId) {
        # Check operation status
        Write-Host "Checking operation status..." -ForegroundColor Yellow
        Write-Host "Operation ID: $OperationId" -ForegroundColor Cyan
        Write-Host ""
        
        $operationStatus = Get-OperationStatus -OperationId $OperationId -Config $config
        
        if (-not $operationStatus.Success) {
            Write-Error "Failed to get operation status: $($operationStatus.Error)"
            exit 1
        }
        
        Write-Host "Operation Status Retrieved Successfully!" -ForegroundColor Green
        Write-Host "=======================================" -ForegroundColor Green
        Write-Host "Operation ID: $($operationStatus.OperationId)" -ForegroundColor Cyan
        Write-Host "Status: $($operationStatus.Status)" -ForegroundColor $(
            switch ($operationStatus.Status) {
                "Succeeded" { "Green" }
                "Failed" { "Red" }
                "Running" { "Yellow" }
                "NotStarted" { "White" }
                default { "White" }
            }
        )
        
    } elseif ($TranslationId -and $IterationId) {
        # Check specific iteration status
        Write-Host "Checking iteration status..." -ForegroundColor Yellow
        Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
        Write-Host "Iteration ID: $IterationId" -ForegroundColor Cyan
        Write-Host ""
        
        $iterationStatus = Get-VideoTranslationIterationStatus -TranslationId $TranslationId -IterationId $IterationId -Config $config
        
        if (-not $iterationStatus.Success) {
            Write-Error "Failed to get iteration status: $($iterationStatus.Error)"
            exit 1
        }
        
        Write-Host "Iteration Status Retrieved Successfully!" -ForegroundColor Green
        Write-Host "=======================================" -ForegroundColor Green
        Write-Host "Translation ID: $($iterationStatus.TranslationId)" -ForegroundColor Cyan
        Write-Host "Iteration ID: $($iterationStatus.IterationId)" -ForegroundColor Cyan
        Write-Host "Status: $($iterationStatus.Status)" -ForegroundColor $(
            switch ($iterationStatus.Status) {
                "Succeeded" { "Green" }
                "Failed" { "Red" }
                "Running" { "Yellow" }
                "NotStarted" { "White" }
                default { "White" }
            }
        )
        Write-Host "Created: $($iterationStatus.CreatedDateTime)" -ForegroundColor Gray
        Write-Host "Last Updated: $($iterationStatus.LastActionDateTime)" -ForegroundColor Gray
        
        if ($iterationStatus.Input) {
            Write-Host "`nIteration Settings:" -ForegroundColor Yellow
            if ($iterationStatus.Input.speakerCount) {
                Write-Host "  Speaker Count: $($iterationStatus.Input.speakerCount)" -ForegroundColor White
            }
            if ($iterationStatus.Input.subtitleMaxCharCountPerSegment) {
                Write-Host "  Max Subtitle Characters: $($iterationStatus.Input.subtitleMaxCharCountPerSegment)" -ForegroundColor White
            }
            if ($iterationStatus.Input.PSObject.Properties['exportSubtitleInVideo']) {
                Write-Host "  Export Subtitle in Video: $($iterationStatus.Input.exportSubtitleInVideo)" -ForegroundColor White
            }
            if ($iterationStatus.Input.webvttFile) {
                Write-Host "  WebVTT File: $($iterationStatus.Input.webvttFile.url)" -ForegroundColor White
            }
        }
        
        if ($iterationStatus.Status -eq "Succeeded" -and $iterationStatus.Result) {
            Write-Host "`nDownload URLs Available:" -ForegroundColor Green
            if ($iterationStatus.Result.translatedVideoFileUrl) {
                Write-Host "  🎥 Translated Video: Available" -ForegroundColor Green
            }
            if ($iterationStatus.Result.sourceLocaleSubtitleWebvttFileUrl) {
                Write-Host "  📄 Source Subtitles: Available" -ForegroundColor Green
            }
            if ($iterationStatus.Result.targetLocaleSubtitleWebvttFileUrl) {
                Write-Host "  📄 Target Subtitles: Available" -ForegroundColor Green
            }
            if ($iterationStatus.Result.metadataJsonWebvttFileUrl) {
                Write-Host "  📊 Metadata: Available" -ForegroundColor Green
            }
            
            Write-Host "`nTo download results, use:" -ForegroundColor Yellow
            Write-Host "Get-VideoTranslationResults -TranslationId '$TranslationId' -IterationId '$IterationId'" -ForegroundColor Cyan
        }
        
        # Save detailed status to file
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "iteration_status_${TranslationId}_${IterationId}_${timestamp}.json"
        $filepath = Join-Path $OutputDirectory $filename
        
        $iterationStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
        Write-Host "`nDetailed status saved to: $filepath" -ForegroundColor Gray
        
    } elseif ($TranslationId) {
        # Check translation status
        Write-Host "Checking translation status..." -ForegroundColor Yellow
        Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
        Write-Host ""
        
        $translationStatus = Get-VideoTranslationStatus -TranslationId $TranslationId -Config $config
        
        if (-not $translationStatus.Success) {
            Write-Error "Failed to get translation status: $($translationStatus.Error)"
            exit 1
        }
        
        Write-Host "Translation Status Retrieved Successfully!" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Green
        Write-Host "Translation Information:" -ForegroundColor Cyan
        Write-Host "  ID: $($translationStatus.TranslationId)" -ForegroundColor White
        Write-Host "  Display Name: $($translationStatus.DisplayName)" -ForegroundColor White
        Write-Host "  Description: $($translationStatus.Description)" -ForegroundColor White
        Write-Host "  Status: $($translationStatus.Status)" -ForegroundColor $(
            switch ($translationStatus.Status) {
                "Succeeded" { "Green" }
                "Failed" { "Red" }
                "Running" { "Yellow" }
                "NotStarted" { "White" }
                default { "White" }
            }
        )
        Write-Host "  Created: $($translationStatus.CreatedDateTime)" -ForegroundColor Gray
        Write-Host "  Last Updated: $($translationStatus.LastActionDateTime)" -ForegroundColor Gray
        
        if ($translationStatus.Input) {
            Write-Host "`nTranslation Settings:" -ForegroundColor Yellow
            Write-Host "  Source Language: $($translationStatus.Input.sourceLocale)" -ForegroundColor White
            Write-Host "  Target Language: $($translationStatus.Input.targetLocale)" -ForegroundColor White
            Write-Host "  Voice Kind: $($translationStatus.Input.voiceKind)" -ForegroundColor White
            Write-Host "  Speaker Count: $($translationStatus.Input.speakerCount)" -ForegroundColor White
            Write-Host "  Max Subtitle Characters: $($translationStatus.Input.subtitleMaxCharCountPerSegment)" -ForegroundColor White
            Write-Host "  Export Subtitle in Video: $($translationStatus.Input.exportSubtitleInVideo)" -ForegroundColor White
            Write-Host "  Lip Sync Enabled: $($translationStatus.Input.enableLipSync)" -ForegroundColor White
        }
        
        # Get iterations for this translation
        Write-Host "`nChecking for iterations..." -ForegroundColor Yellow
        
        try {
            $uri = "$($Config.BaseUrl)/translations/$TranslationId/iterations?api-version=$($Config.ApiVersion)"
            $iterationsResponse = Invoke-VideoTranslationApi -Uri $uri -Method "GET" -Config $config
            
            if ($iterationsResponse.Success -and $iterationsResponse.Data.value.Count -gt 0) {
                Write-Host "Found $($iterationsResponse.Data.value.Count) iteration(s):" -ForegroundColor Green
                
                foreach ($iteration in $iterationsResponse.Data.value) {
                    Write-Host "  🔄 Iteration: $($iteration.id)" -ForegroundColor Cyan
                    Write-Host "     Status: $($iteration.status)" -ForegroundColor $(
                        switch ($iteration.status) {
                            "Succeeded" { "Green" }
                            "Failed" { "Red" }
                            "Running" { "Yellow" }
                            "NotStarted" { "White" }
                            default { "White" }
                        }
                    )
                    Write-Host "     Created: $($iteration.createdDateTime)" -ForegroundColor Gray
                    
                    if ($iteration.status -eq "Succeeded") {
                        Write-Host "     📥 Results available for download" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "No iterations found for this translation." -ForegroundColor Yellow
                Write-Host "Create an iteration to start the translation process:" -ForegroundColor Yellow
                Write-Host "New-VideoTranslationIteration -TranslationId '$TranslationId'" -ForegroundColor Cyan
            }
        } catch {
            Write-Warning "Could not retrieve iterations: $($_.Exception.Message)"
        }
        
        # Save detailed status to file
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $filename = "translation_status_${TranslationId}_${timestamp}.json"
        $filepath = Join-Path $OutputDirectory $filename
        
        $translationStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
        Write-Host "`nDetailed status saved to: $filepath" -ForegroundColor Gray
        
    } else {
        Write-Error "Please specify either -ListAll, -TranslationId, -OperationId, or both -TranslationId and -IterationId"
        Write-Host "`nUsage examples:" -ForegroundColor Yellow
        Write-Host "• List all translations: Get-VideoTranslationStatus -ListAll" -ForegroundColor Cyan
        Write-Host "• Check translation: Get-VideoTranslationStatus -TranslationId 'your-translation-id'" -ForegroundColor Cyan
        Write-Host "• Check iteration: Get-VideoTranslationStatus -TranslationId 'your-translation-id' -IterationId 'your-iteration-id'" -ForegroundColor Cyan
        Write-Host "• Check operation: Get-VideoTranslationStatus -OperationId 'your-operation-id'" -ForegroundColor Cyan
        exit 1
    }
    
} catch {
    Write-Error "An error occurred while checking status: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}
