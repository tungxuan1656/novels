# Contract - Sentence Audio

## Request

`AudioSpeechClient` sends one explicit selected English sentence to the fixed HTTPS endpoint `https://9router.tungxuan.io.vn/v1/audio/speech`. No endpoint, voice, speed, custom headers or AI body/provider controls are exposed.

- Method: `POST`; `Content-Type: application/json`.
- Authentication: `Authorization: Bearer <AUDIO_API_KEY>`, independent of AI credentials. Trim surrounding whitespace; reject empty keys or embedded newlines before transport.
- JSON contains exactly `model` (trimmed `AUDIO_MODEL`) and `input` (selected sentence, unchanged). Blank model/input fails locally.
- Request timeout: 60 seconds. Ephemeral URLSession; no shared cookies or disk response cache. No automatic retries, diagnostic logs, response-body errors, or background requests.

```json
{"model":"edge-tts/en-AU-WilliamMultilingualNeural","input":"Hello, this is a text to speech test."}
```

## Response and Playback

- A successful `2xx` response returns raw audio bytes, not JSON or base64. Reject empty data or data larger than 10 MiB. When present, MIME must be `audio/*` or `application/octet-stream`.
- `AVAudioPlayer(data:)` validates decodability and plays in memory. No file, persistent audio cache or background playback is introduced. The size check runs after download; it is not a streamed response limit.
- Apple and API playback activate the shared `AVAudioSession` with `.playback`, `.spokenAudio` and `.duckOthers`. Explicit listening remains audible in Silent mode. Stop, completion and playback failure release the session with `.notifyOthersOnDeactivation`; pending downloads do not activate it.
- Non-2xx errors show HTTP status and generic configuration/retry guidance, never the provider body. Invalid audio or playback failure shows a recoverable message. Network failures show connection guidance. No silent fallback to Apple.
- The observable `ReaderSpeech` owns request task, player and system synthesizer. Stop is enabled only while loading or playing. New speech stops previous work. Stop cancels pending transport, clears loading/playback state and stops either player. Generation checks and playback-object identities prevent stale results or completion callbacks from changing newer playback. Retain callback objects through the main-actor identity check; an identifier alone can be reused after deallocation.
- Stop on sheet dismissal, Google lookup, reader exit, chapter/mode/content change, backgrounding, audio-source change or explicit Stop. Each API request snapshots the key/model; edits affect the next request.

## Apple Source

Apple is the default and uses `AVSpeechSynthesizer` with an available English voice. Missing voices show a download hint. No sentence is sent to the API; installed voice quality/offline availability require device verification.

## Verification

Focused tests cover request fields/authentication, configuration, MIME/status/empty/oversized responses, transport cancellation, replacement/stop state and undecodable audio. A decodable PCM fixture verifies Silent-compatible session category/mode and Stop state through natural completion; it does not prove real-device audibility. A late-callback test covers player/utterance retention and protects replacement playback from old errors/completions. Full gate: `../../init.sh`. Live provider/model MP3 playback, audio routes and iOS 26.0 require real-device checks; mocked tests do not establish voice quality.

## Links

- [Settings](settings-schema.md), [learning behavior](../product/functional-specs/bilingual-learning.md), [security](../../SECURITY.md).
