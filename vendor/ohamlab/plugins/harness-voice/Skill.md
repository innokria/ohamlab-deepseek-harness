---
name: audio
description: Generate Hindi text-to-speech audio using ohamlab-voice model rahul7star/tts-nano-o-hi
---

# Audio Skill - Hindi Text-to-Speech

Generate Hindi speech audio from text using the `rahul7star/tts-nano-o-hi` model.

## Overview

This skill wraps the `ohamlab_voicestudio` package to synthesize Hindi speech from text input. The generated audio uses the model `rahul7star/tts-nano-o-hi` at 24 kHz sample rate, as documented in the ohamlab-voice readme.

## Features

- **Hindi Text-to-Speech**: Convert Hindi text to speech audio
- **24 kHz Sample Rate**: Standard audio format as per readme specification
- **Multiple Text Support**: Handle single words or full sentences
- **WAV Output**: Generate standard WAV audio files
- **Automatic File Storage**: Saves to `/data/dsh/audio/` directory

## Usage

### Prerequisites

The ohamlab-voice service must be running (PID 1511 confirmed active):

```bash
# Verify voice service is running
ps aux | grep ohamlab-voice
# Or check via /proc
cat /proc/1511/cmdline
```

### Skill Execution

#### Option 1: Via Python

```python
from ohamlab_voicestudio import VoiceStudio
import os

studio = VoiceStudio(model="rahul7star/tts-nano-o-hi", device="cpu")
rate, audio = studio.speak("नमस्ते")
# Audio saved automatically to /data/dsh/audio/
```

#### Option 2: Via Command Line

```bash
# Using the voice studio CLI
ohamlab-voice studio --model rahul7star/tts-nano-o-hi --device cpu --text "नमस्ते! आप कैसे हैं?"

# Or via Python script
python3 -c "
import sys
sys.path.insert(0, '/app/ohamlab-voice-venv/lib/python3.11/site-packages')
from ohamlab_voicestudio import VoiceStudio
studio = VoiceStudio(model='rahul7star/tts-nano-o-hi', device='cpu')
rate, audio = studio.speak('नमस्ते! आप कैसे हैं? आज का दिन बहुत अच्छा है।')
print(f'Audio generated: {len(audio)} samples at {rate} Hz')
"
```

#### Option 3: Via This Skill's Workflow

```bash
# The skill handles audio generation internally
# See usage examples below
```

## Input Text

Supported Hindi text formats:

| Input Example | Description |
|--------------|-------------|
| `"नमस्ते"` | Single word "Hello" |
| `"नमस्ते! आप कैसे हैं?"` | Greeting + question |
| `"आज का दिन बहुत अच्छा है।"` | Full sentence |
| `"नमस्ते! आप कैसे हैं? आज का दिन बहुत अच्छा है।"` | Complete paragraph |

## Output Files

Audio files are saved to `/data/dsh/audio/` with auto-generated names:

| File | Description |
|------|-------------|
| `hello_hindi.wav` | Short audio (single word) |
| `hello_hindi_full.wav` | Full sentence audio |
| Custom names based on sanitized input text |

### Output Details

- **Sample Rate**: 24,000 Hz
- **Format**: 16-bit PCM WAV
- **Audio Type**: numpy.ndarray (float32)
- **Mono Channel**: Single channel audio

## Technical Details

### Model Configuration

- **Model Name**: `rahul7star/tts-nano-o-hi`
- **Provider**: Hugging Face (`hf`)
- **Sample Rate**: 24,000 Hz
- **Device**: CPU (optimized for compatibility)
- **Package**: `ohamlab_voicestudio` v0.1.0b3

### Python API

```python
from ohamlab_voicestudio import VoiceStudio

# Initialize studio
studio = VoiceStudio(model="rahul7star/tts-nano-o-hi", device="cpu")

# Generate audio
rate, audio = studio.speak(hindi_text)

# Properties
print(f"Sample rate: {rate}")      # 24000
print(f"Audio type: {type(audio)}")  # <class 'numpy.ndarray'>
print(f"Audio length: {len(audio)}") # Number of samples
print(f"Audio dtype: {audio.dtype}") # float32
```

### Audio Duration Calculation

```
Duration (seconds) = Number of samples ÷ 24000

Example: 74,880 samples ÷ 24,000 = ~3.12 seconds
```

## Error Handling

### Common Issues

| Error | Solution |
|-------|----------|
| `ImportError: No module named 'ohamlab_voicestudio'` | Ensure venv is activated: `/app/ohamlab-voice-venv/bin/python` |
| HF Hub unauthenticated warnings | Set `HF_TOKEN` environment variable or accept unauthenticated requests |
| Model download failures | Check internet connection, model is hosted at `rahul7star/tts-nano-o-hi` |
| Audio too short/silent | Ensure text is not empty, minimum 1 character required |

### Timeout

- Typical execution: 5-30 seconds depending on text length
- HF Hub download: ~2-5 seconds (first time only, cached afterward)
- Total: ~10-45 seconds for typical usage

## Installation Verification

```bash
# Verify ohamlab-voice package is installed
/app/ohamlab-voice-venv/bin/python -m pip show ohamlab-voicestudio

# Verify voice service is running
ps -p 1511 -o cmd=

# Test basic functionality
/app/ohamlab-voice-venv/bin/python -c "
from ohamlab_voicestudio import VoiceStudio
studio = VoiceStudio(model='rahul7star/tts-nano-o-hi', device='cpu')
rate, audio = studio.speak('नमस्ते')
print(f'Success: {len(audio)} samples at {rate} Hz')
"
```

## Skill Integration

This skill can be integrated with other ohamlab skills:

```bash
# Combine with agent-lab skill
ohamlab-agent-lab create task --text "Generate Hindi TTS for दीपावली की शुभकामनाएं"

# Or via Python integration
from ohamlab_agent_lab.tasks import TaskManager
# Assign audio generation as a task step
```

## References

- [ohamlab-voice README](/app/ohamlab-voicestudio/README.md)
- [OhamLab VoiceStudio Documentation](https://huggingface.co/rahul7star/tts-nano-o-hi)
- [DSH Web GUI](http://127.0.0.1:3080) - Access audio files in `/data/dsh/audio/`
