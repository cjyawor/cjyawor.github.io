# GermanBuddy

An iPhone app where you talk out loud to a German-speaking avatar (Lena). You speak German, she answers in German, out loud, with her mouth moving. Optional English tips under each reply fix your mistakes.

## How it works

- Speech in: Apple Speech framework, de-DE
- Brain: Claude API (claude-haiku-5-5), prompt tuned to your CEFR level
- Speech out: AVSpeechSynthesizer, German voice
- Avatar: SwiftUI drawing, blinks, thinks, opens its mouth on each spoken word

## Build (needs a Mac with Xcode 15+)

    brew install xcodegen
    cd GermanBuddy
    xcodegen
    open GermanBuddy.xcodeproj

Pick your team under Signing, run on your iPhone (the simulator has weak speech support), paste your Anthropic API key on first launch.

Tip: Settings > Accessibility > Spoken Content > Voices > German, download an Enhanced or Premium voice. It sounds much better.

## Not built yet

- Backend proxy so the API key is not on the phone (fine for personal use, not for App Store release)
- Realistic avatar (Ready Player Me or a RealityKit 3D head with real lip-sync)
- Streaming replies for lower lag
