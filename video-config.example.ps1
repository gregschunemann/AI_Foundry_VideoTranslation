# Azure AI Video Translation Configuration Example
# Copy this file to video-config.ps1 and update with your actual values

# Azure Speech Service Configuration for Video Translation
$env:AZURE_SPEECH_ENDPOINT = "https://your-speech-resource-name.cognitiveservices.azure.com"
$env:AZURE_SPEECH_KEY = "your-subscription-key-here"
$env:AZURE_SPEECH_REGION = "your-region-here"  # e.g., "eastus", "westus2", "westeurope"

# Example usage after setting up the environment variables:
# .\Start-VideoTranslation.ps1 -VideoFileUrl "https://example.com/video.mp4" -SourceLocale "es-ES" -TargetLocale "en-US" -AutoCreateIteration -AutoDownload

Write-Host "Environment variables configured for Azure AI Video Translation" -ForegroundColor Green
Write-Host "Speech Endpoint: $env:AZURE_SPEECH_ENDPOINT" -ForegroundColor Cyan
Write-Host "Speech Region: $env:AZURE_SPEECH_REGION" -ForegroundColor Cyan
Write-Host "Speech Key: $('*' * 20)..." -ForegroundColor Cyan

Write-Host "`nSupported Languages for Video Translation:" -ForegroundColor Yellow
Write-Host "Source languages: Chinese (Mandarin), English, French, German, Italian, Japanese, Korean, Portuguese, Spanish" -ForegroundColor White
Write-Host "Target languages: Chinese (Mandarin), English, French, German, Italian, Japanese, Korean, Portuguese, Spanish" -ForegroundColor White

Write-Host "`nCommon Language Codes:" -ForegroundColor Yellow
Write-Host "  en-US (English - United States)" -ForegroundColor Cyan
Write-Host "  es-ES (Spanish - Spain)" -ForegroundColor Cyan
Write-Host "  fr-FR (French - France)" -ForegroundColor Cyan
Write-Host "  de-DE (German - Germany)" -ForegroundColor Cyan
Write-Host "  it-IT (Italian - Italy)" -ForegroundColor Cyan
Write-Host "  ja-JP (Japanese - Japan)" -ForegroundColor Cyan
Write-Host "  ko-KR (Korean - Korea)" -ForegroundColor Cyan
Write-Host "  pt-BR (Portuguese - Brazil)" -ForegroundColor Cyan
Write-Host "  zh-CN (Chinese - Mandarin)" -ForegroundColor Cyan

Write-Host "`nNext Steps:" -ForegroundColor Green
Write-Host "1. Update the values above with your actual Azure Speech resource details" -ForegroundColor White
Write-Host "2. Save this file as 'video-config.ps1'" -ForegroundColor White
Write-Host "3. Run: .\video-config.ps1" -ForegroundColor White
Write-Host "4. Run: .\Start-VideoTranslation.ps1 -VideoFileUrl 'your-video-url' -SourceLocale 'es-ES' -TargetLocale 'en-US'" -ForegroundColor White
