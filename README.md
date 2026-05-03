# FeedBacks!

Standalone macOS app for turning mix feedback notes into timeline markers.

## Current Features

- import a feedback text file with `Choose File`
- import feedback text directly from the clipboard with `Paste from Clipboard`
- parse feedback rows and preview them in the app
- send selected markers into Pro Tools through the embedded standalone Python/PTSL flow
- export selected markers to `AAF` for use in other DAWs
- choose the exported AAF frame rate
- customize the app interface through a `Colors` window
- customize interface colors plus border color, width, and corner radius

## Theme Customization

The `Colors` window is available from the app menu with `cmd + shift + C`.

What is customizable:

- main UI colors
- border colors
- border widths
- border corner radius

What is not customizable:

- marker palette colors inside the marker settings area stay fixed

## Build

```bash
cd /Users/gautier/GogoLabs/FeedBacks
xcodegen generate
open 'FeedBacks!.xcodeproj'
```

## Embedded Python Runtime

If the embedded runtime is missing or needs to be refreshed:

```bash
cd /Users/gautier/GogoLabs/FeedBacks
./scripts/prepare_embedded_python.sh
```

The project also re-signs the embedded Python runtime during the build via:

```bash
scripts/sign_embedded_python.sh
```

## Project Notes

- app bundle id: `fr.gogolabs.feedbacks`
- project name / scheme: `FeedBacks!`
- deployment target: macOS 14+
