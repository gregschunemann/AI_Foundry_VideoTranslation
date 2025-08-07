# Azure AI Foundry Video Translation PowerShell Toolkit

This PowerShell toolkit provides comprehensive support for **Azure AI Foundry video translation** capabilities, enabling automated video translation workflows with subtitle generation and quality improvements.

## Features

### Video Translation 🎬
- **Complete video translation workflow**
- **Create translation objects and iterations**
- **Monitor translation progress with real-time polling**
- **Download translated videos and subtitles automatically**
- **Support for multiple iterations to improve quality**
- **Support for 9 languages** (Chinese, English, French, German, Italian, Japanese, Korean, Portuguese, Spanish)
- **Platform and Personal Voice support**
- **WebVTT subtitle editing for iterative improvements**

## Prerequisites

1. **Azure AI Foundry Speech resource** in a [supported region](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/video-translation-overview#supported-regions-and-languages)
2. **PowerShell 5.1 or later**
3. **Azure Blob Storage account** (for video files and WebVTT iterations)
4. **Video file in MP4 format** (max 5GB, max 4 hours)

## Quick Start: Video Translation

### 1. Configure Credentials

```powershell
# Copy the example config
Copy-Item "video-config.example.ps1" "video-config.ps1"

# Edit video-config.ps1 with your actual values:
$env:AZURE_SPEECH_ENDPOINT = "https://your-speech-resource.cognitiveservices.azure.com"
$env:AZURE_SPEECH_KEY = "your-subscription-key"
$env:AZURE_SPEECH_REGION = "your-region"  # e.g., "eastus"

# Load the configuration
.\video-config.ps1
```

### 2. Start Your First Video Translation

```powershell
# Complete workflow: Create translation → Create iteration → Download results
.\Start-VideoTranslation.ps1 `
  -VideoFileUrl "https://example.com/video.mp4" `
  -SourceLocale "es-ES" `
  -TargetLocale "en-US" `
  -AutoCreateIteration `
  -AutoDownload
```

## Video Translation Workflow

### Step-by-Step Process

#### 1️⃣ Create Translation Object
```powershell
.\Start-VideoTranslation.ps1 `
  -VideoFileUrl "https://your-storage.blob.core.windows.net/videos/sample.mp4" `
  -SourceLocale "es-ES" `
  -TargetLocale "en-US" `
  -DisplayName "Spanish to English Translation" `
  -VoiceKind "PlatformVoice" `
  -SpeakerCount 2
```

#### 2️⃣ Create and Monitor Iteration
```powershell
.\New-VideoTranslationIteration.ps1 `
  -TranslationId "your-translation-id" `
  -ExportSubtitleInVideo $true `
  -AutoDownload
```

#### 3️⃣ Download Results
```powershell
.\Get-VideoTranslationResults.ps1 `
  -TranslationId "your-translation-id" `
  -IterationId "your-iteration-id"
```

#### 4️⃣ Check Status Anytime
```powershell
# List all translations
.\Get-VideoTranslationStatus.ps1 -ListAll

# Check specific translation
.\Get-VideoTranslationStatus.ps1 -TranslationId "your-translation-id"

# Check specific iteration
.\Get-VideoTranslationStatus.ps1 -TranslationId "your-translation-id" -IterationId "your-iteration-id"
```

### Advanced: Quality Improvement with Multiple Iterations

```powershell
# 1. Create first iteration
.\New-VideoTranslationIteration.ps1 -TranslationId "your-id" -AutoDownload

# 2. Edit the downloaded metadata WebVTT file to improve translations

# 3. Upload edited WebVTT to your blob storage

# 4. Create improved iteration
.\New-VideoTranslationIteration.ps1 `
  -TranslationId "your-id" `
  -WebVttFileUrl "https://your-storage.blob.core.windows.net/edited-subtitles.vtt" `
  -AutoDownload
```

## Supported Languages

| Language | Code | Supported as Source | Supported as Target |
|----------|------|:------------------:|:------------------:|
| Chinese (Mandarin) | zh-CN | ✅ | ✅ |
| English (US) | en-US | ✅ | ✅ |
| French | fr-FR | ✅ | ✅ |
| German | de-DE | ✅ | ✅ |
| Italian | it-IT | ✅ | ✅ |
| Japanese | ja-JP | ✅ | ✅ |
| Korean | ko-KR | ✅ | ✅ |
| Portuguese (Brazil) | pt-BR | ✅ | ✅ |
| Spanish | es-ES | ✅ | ✅ |

## File Organization

### Video Translation Scripts
- **`Start-VideoTranslation.ps1`** - Main workflow script
- **`New-VideoTranslationIteration.ps1`** - Create new iterations
- **`Get-VideoTranslationResults.ps1`** - Download results
- **`Get-VideoTranslationStatus.ps1`** - Check status of translations/iterations
- **`VideoTranslationHelpers.ps1`** - Helper functions library

### Configuration Templates
- **`video-config.example.ps1`** - Video translation configuration template

## Parameters Reference

### Start-VideoTranslation.ps1 Parameters

| Parameter | Type | Required | Description |
|-----------|------|:--------:|-------------|
| `VideoFileUrl` | String | ✅ | URL of MP4 video file (max 5GB, 4 hours) |
| `SourceLocale` | String | ✅ | Source language code (e.g., "es-ES") |
| `TargetLocale` | String | ✅ | Target language code (e.g., "en-US") |
| `TranslationId` | String | ❌ | Custom ID (auto-generated if not provided) |
| `DisplayName` | String | ❌ | Friendly name for the translation |
| `VoiceKind` | String | ❌ | "PlatformVoice" or "PersonalVoice" |
| `SpeakerCount` | Integer | ❌ | Number of speakers (default: 1) |
| `SubtitleMaxCharCountPerSegment` | Integer | ❌ | Max subtitle characters (default: 50) |
| `ExportSubtitleInVideo` | Boolean | ❌ | Embed subtitles in video (default: false) |
| `EnableLipSync` | Boolean | ❌ | Enable lip synchronization (default: false) |
| `AutoCreateIteration` | Switch | ❌ | Automatically create first iteration |
| `AutoDownload` | Switch | ❌ | Automatically download results |
| `PollingIntervalSeconds` | Integer | ❌ | Status check interval (default: 30) |
| `MaxWaitTimeMinutes` | Integer | ❌ | Maximum wait time (default: 60) |

## Output Files

When you run the video translation workflow, you'll get several types of files:

### 📥 Downloaded Results
- **`translated_video_*.mp4`** - The translated video file
- **`source_subtitles_*.vtt`** - Source language subtitles (WebVTT format)
- **`target_subtitles_*.vtt`** - Target language subtitles (WebVTT format)  
- **`metadata_*.vtt`** - WebVTT with JSON metadata for editing

### 📊 Status & Tracking Files
- **`translation_creation_*.json`** - Translation object creation response
- **`iteration_creation_*.json`** - Iteration creation responses
- **`iteration_details_*.json`** - Complete iteration details
- **`translation_status_*.json`** - Translation status snapshots
- **`iteration_status_*.json`** - Iteration status snapshots

## Error Handling & Best Practices

### ✅ Built-in Features
- **Automatic retry logic** with exponential backoff
- **Comprehensive error messages** with HTTP status codes
- **Real-time progress monitoring** with configurable polling
- **Detailed logging** with verbose output support
- **File naming consistency** with timestamps and IDs

### 🔒 Security Best Practices
- **Environment variable configuration** (never hardcode keys)
- **HTTPS enforcement** for all API calls
- **Credential validation** before API operations

### 🚀 Performance Optimizations
- **Efficient polling** with configurable intervals
- **Parallel operations** where applicable
- **File size validation** and proper handling

## Usage Examples

### Example 1: Quick Translation
```powershell
# Load configuration
.\video-config.ps1

# Translate Spanish video to English with automatic workflow
.\Start-VideoTranslation.ps1 `
  -VideoFileUrl "https://example.blob.core.windows.net/videos/spanish-tutorial.mp4" `
  -SourceLocale "es-ES" `
  -TargetLocale "en-US" `
  -AutoCreateIteration `
  -AutoDownload
```

### Example 2: Custom Settings
```powershell
.\Start-VideoTranslation.ps1 `
  -VideoFileUrl "https://example.com/meeting.mp4" `
  -SourceLocale "fr-FR" `
  -TargetLocale "en-US" `
  -DisplayName "Board Meeting Translation" `
  -VoiceKind "PlatformVoice" `
  -SpeakerCount 5 `
  -SubtitleMaxCharCountPerSegment 30 `
  -ExportSubtitleInVideo $true `
  -EnableLipSync $true
```

### Example 3: Manual Workflow with Quality Control
```powershell
# 1. Create translation object only
.\Start-VideoTranslation.ps1 `
  -VideoFileUrl "https://example.com/video.mp4" `
  -SourceLocale "ja-JP" `
  -TargetLocale "en-US"

# 2. Create first iteration when ready
.\New-VideoTranslationIteration.ps1 `
  -TranslationId "your-translation-id" `
  -ExportSubtitleInVideo $true

# 3. Download and review results
.\Get-VideoTranslationResults.ps1 `
  -TranslationId "your-translation-id" `
  -IterationId "your-iteration-id"

# 4. Create improved iteration with edited WebVTT
.\New-VideoTranslationIteration.ps1 `
  -TranslationId "your-translation-id" `
  -WebVttFileUrl "https://yourstorage.blob.core.windows.net/improved.vtt"
```

### Example 4: Status Monitoring
```powershell
# List all your video translations
.\Get-VideoTranslationStatus.ps1 -ListAll

# Monitor specific translation progress
.\Get-VideoTranslationStatus.ps1 -TranslationId "12345678-1234-1234-1234-123456789012"

# Check specific iteration results
.\Get-VideoTranslationStatus.ps1 `
  -TranslationId "12345678-1234-1234-1234-123456789012" `
  -IterationId "87654321-4321-4321-4321-210987654321"
```

## Troubleshooting

### Common Issues

**❌ "Failed to initialize configuration"**
```powershell
# Solution: Check your environment variables
.\video-config.ps1
# Verify the output shows your actual endpoint, not placeholder values
```

**❌ "Translation creation failed: 400 Bad Request"**
- Check that your video URL is publicly accessible
- Verify video is MP4 format, under 5GB, and under 4 hours
- Confirm source/target languages are supported

**❌ "Iteration did not complete successfully"**
```powershell
# Check the detailed error in the status
.\Get-VideoTranslationStatus.ps1 -TranslationId "your-id" -IterationId "your-iteration-id"
```

**❌ "Download failed"**
- Ensure iteration status is "Succeeded" before downloading
- Check network connectivity and file permissions

### Getting Help

1. **Enable verbose output** for detailed logging:
   ```powershell
   .\Start-VideoTranslation.ps1 -VideoFileUrl "..." -Verbose
   ```

2. **Check status files** generated in your output directory

3. **Review Azure portal** for Speech service quotas and limits

## API Reference

This toolkit implements the [Azure AI Video Translation REST API](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/video-translation-get-started?pivots=rest-api&tabs=webvtt-source):

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Create Translation | PUT | `/videotranslation/translations/{id}` |
| Create Iteration | PUT | `/videotranslation/translations/{id}/iterations/{iterationId}` |
| Get Translation | GET | `/videotranslation/translations/{id}` |
| Get Iteration | GET | `/videotranslation/translations/{id}/iterations/{iterationId}` |
| Get Operation Status | GET | `/videotranslation/operations/{operationId}` |
| List Translations | GET | `/videotranslation/translations` |
| Delete Translation | DELETE | `/videotranslation/translations/{id}` |

## Security & Compliance

- **Credentials**: Store in environment variables, never in code
- **HTTPS**: All API communications use TLS encryption
- **Least Privilege**: Use dedicated Speech service keys
- **Data Retention**: Azure retains translation history for 31 days
- **Regional Data**: Data processed in your specified Azure region
