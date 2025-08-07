# Example: Complete Video Translation Workflow
# This script demonstrates the full video translation process using Azure AI Foundry

# Prerequisites:
# 1. Configure your credentials by copying video-config.example.ps1 to video-config.ps1
# 2. Update video-config.ps1 with your actual Azure Speech service details
# 3. Upload your MP4 video to Azure Blob Storage

Write-Host "Azure AI Video Translation - Complete Example Workflow" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green

# Step 1: Load configuration
Write-Host "`nStep 1: Loading configuration..." -ForegroundColor Yellow
try {
    if (Test-Path "video-config.ps1") {
        . ".\video-config.ps1"
        Write-Host "✅ Configuration loaded successfully" -ForegroundColor Green
    } else {
        Write-Error "❌ video-config.ps1 not found. Please copy video-config.example.ps1 to video-config.ps1 and configure it."
        Write-Host "Run: Copy-Item 'video-config.example.ps1' 'video-config.ps1'" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Error "❌ Failed to load configuration: $($_.Exception.Message)"
    exit 1
}

# Step 2: Set example parameters (modify these for your actual video)
$videoUrl = "https://ai.azure.com/speechassetscache/ttsvoice/VideoTranslation/PublicDoc/SampleData/es-ES-TryOutOriginal.mp4"  # Microsoft sample video
$sourceLanguage = "es-ES"  # Spanish
$targetLanguage = "en-US"  # English

Write-Host "`nStep 2: Translation Parameters" -ForegroundColor Yellow
Write-Host "Video URL: $videoUrl" -ForegroundColor Cyan
Write-Host "Source Language: $sourceLanguage" -ForegroundColor Cyan
Write-Host "Target Language: $targetLanguage" -ForegroundColor Cyan

# Step 3: Ask user if they want to proceed
Write-Host "`nStep 3: Confirmation" -ForegroundColor Yellow
$proceed = Read-Host "Do you want to proceed with the translation? (y/N)"
if ($proceed -ne "y" -and $proceed -ne "Y") {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Step 4: Execute the complete translation workflow
Write-Host "`nStep 4: Starting video translation workflow..." -ForegroundColor Yellow
Write-Host "This will:" -ForegroundColor White
Write-Host "  • Create a translation object" -ForegroundColor White
Write-Host "  • Create and monitor an iteration" -ForegroundColor White
Write-Host "  • Download the translated video and subtitles" -ForegroundColor White
Write-Host "  • Save all status information for tracking" -ForegroundColor White

try {
    # Run the main translation script with automatic workflow
    & ".\Start-VideoTranslation.ps1" `
        -VideoFileUrl $videoUrl `
        -SourceLocale $sourceLanguage `
        -TargetLocale $targetLanguage `
        -DisplayName "Example Spanish to English Translation" `
        -Description "Complete workflow example using Microsoft sample video" `
        -VoiceKind "PlatformVoice" `
        -SpeakerCount 1 `
        -SubtitleMaxCharCountPerSegment 50 `
        -ExportSubtitleInVideo $true `
        -AutoCreateIteration `
        -AutoDownload `
        -PollingIntervalSeconds 30 `
        -MaxWaitTimeMinutes 60 `
        -Verbose
        
    Write-Host "`n🎉 Translation workflow completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "❌ Translation workflow failed: $($_.Exception.Message)"
    Write-Host "Check the error details above for troubleshooting information." -ForegroundColor Red
    exit 1
}

# Step 5: Show next steps
Write-Host "`nStep 5: Next Steps" -ForegroundColor Yellow
Write-Host "📁 Check the current directory for downloaded files:" -ForegroundColor White
Write-Host "   • translated_video_*.mp4 - Your translated video" -ForegroundColor Cyan
Write-Host "   • target_subtitles_*.vtt - Translated subtitles" -ForegroundColor Cyan
Write-Host "   • source_subtitles_*.vtt - Original subtitles" -ForegroundColor Cyan
Write-Host "   • metadata_*.vtt - Metadata for quality improvements" -ForegroundColor Cyan
Write-Host "   • Various *.json files - Status and tracking information" -ForegroundColor Cyan

Write-Host "`n🔄 To improve translation quality:" -ForegroundColor Yellow
Write-Host "   1. Edit the metadata_*.vtt file to correct translations" -ForegroundColor White
Write-Host "   2. Upload the edited file to your Azure Blob Storage" -ForegroundColor White
Write-Host "   3. Create a new iteration with the edited WebVTT file" -ForegroundColor White

Write-Host "`n📊 Useful commands for management:" -ForegroundColor Yellow
Write-Host "   • List all translations: .\Get-VideoTranslationStatus.ps1 -ListAll" -ForegroundColor Cyan
Write-Host "   • Check specific status: .\Get-VideoTranslationStatus.ps1 -TranslationId 'your-id'" -ForegroundColor Cyan
Write-Host "   • Download results again: .\Get-VideoTranslationResults.ps1 -TranslationId 'your-id' -IterationId 'your-iteration-id'" -ForegroundColor Cyan

Write-Host "`n✅ Example workflow completed!" -ForegroundColor Green
