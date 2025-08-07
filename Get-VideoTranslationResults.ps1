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
    
    [Parameter(Mandatory = $true)]
    [string]$IterationId,
    
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

Write-Host "Downloading Video Translation Results" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
Write-Host "Iteration ID: $IterationId" -ForegroundColor Cyan
Write-Host "Output Directory: $OutputDirectory" -ForegroundColor Cyan
Write-Host ""

try {
    # Download the results
    Write-Host "Fetching translation results..." -ForegroundColor Yellow
    
    $downloadResult = Get-VideoTranslationResults -TranslationId $TranslationId -IterationId $IterationId -Config $config -OutputDirectory $OutputDirectory
    
    if ($downloadResult.Success) {
        Write-Host "Download completed successfully!" -ForegroundColor Green
        
        if ($downloadResult.Files.Count -gt 0) {
            Write-Host "`nDownloaded files:" -ForegroundColor Green
            foreach ($file in $downloadResult.Files) {
                $fileName = Split-Path $file -Leaf
                $fileSize = if (Test-Path $file) {
                    $size = (Get-Item $file).Length
                    if ($size -gt 1MB) {
                        "{0:N2} MB" -f ($size / 1MB)
                    } elseif ($size -gt 1KB) {
                        "{0:N2} KB" -f ($size / 1KB)
                    } else {
                        "$size bytes"
                    }
                } else {
                    "Unknown"
                }
                
                Write-Host "  ✓ $fileName ($fileSize)" -ForegroundColor White
            }
        }
        
        if ($downloadResult.Errors.Count -gt 0) {
            Write-Host "`nWarnings/Errors during download:" -ForegroundColor Yellow
            foreach ($errMsg in $downloadResult.Errors) {
                Write-Host "  ⚠ $errMsg" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nFile Details:" -ForegroundColor Cyan
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        
        foreach ($file in $downloadResult.Files) {
            if (Test-Path $file) {
                $fileName = Split-Path $file -Leaf
                $fileInfo = Get-Item $file
                
                Write-Host "📁 $fileName" -ForegroundColor White
                Write-Host "   Path: $($fileInfo.FullName)" -ForegroundColor Gray
                Write-Host "   Size: $("{0:N0}" -f $fileInfo.Length) bytes" -ForegroundColor Gray
                Write-Host "   Modified: $($fileInfo.LastWriteTime)" -ForegroundColor Gray
                
                # Show file type specific information
                if ($fileName -like "*.mp4") {
                    Write-Host "   Type: Translated Video" -ForegroundColor Green
                } elseif ($fileName -like "*source_subtitles*.vtt") {
                    Write-Host "   Type: Source Language Subtitles (WebVTT)" -ForegroundColor Magenta
                } elseif ($fileName -like "*target_subtitles*.vtt") {
                    Write-Host "   Type: Target Language Subtitles (WebVTT)" -ForegroundColor Blue
                } elseif ($fileName -like "*metadata*.vtt") {
                    Write-Host "   Type: Metadata with JSON Properties (WebVTT)" -ForegroundColor Yellow
                } elseif ($fileName -like "*iteration_details*.json") {
                    Write-Host "   Type: Iteration Details (JSON)" -ForegroundColor Cyan
                }
                Write-Host ""
            }
        }
        
        # Final Summary
        Write-Host "====================================" -ForegroundColor Green
        Write-Host "Download Summary" -ForegroundColor Green
        Write-Host "====================================" -ForegroundColor Green
        Write-Host "Translation ID: $TranslationId" -ForegroundColor Cyan
        Write-Host "Iteration ID: $IterationId" -ForegroundColor Cyan
        Write-Host "Files Downloaded: $($downloadResult.Files.Count)" -ForegroundColor Green
        Write-Host "Download Location: $OutputDirectory" -ForegroundColor Cyan
        
        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "1. Review the translated video file" -ForegroundColor White
        Write-Host "2. Check subtitle files for accuracy" -ForegroundColor White
        Write-Host "3. Use metadata file to create improved iterations if needed" -ForegroundColor White
        Write-Host "4. Create additional iterations with WebVTT edits for quality improvements" -ForegroundColor White
        
        Write-Host "`nUseful Commands:" -ForegroundColor Yellow
        Write-Host "• Create another iteration: New-VideoTranslationIteration -TranslationId '$TranslationId' -WebVttFileUrl 'your-edited-webvtt-url'" -ForegroundColor Cyan
        Write-Host "• List all translations: Get-VideoTranslationList" -ForegroundColor Cyan
        Write-Host "• Check translation status: Get-VideoTranslationStatus -TranslationId '$TranslationId'" -ForegroundColor Cyan
        
    } else {
        Write-Error "Download failed: $($downloadResult.Error)"
        exit 1
    }
    
} catch {
    Write-Error "An error occurred during download: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
    exit 1
}
