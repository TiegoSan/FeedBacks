# FeedBacks

Standalone macOS app scaffold for importing mix feedback markers into Pro Tools.

Current scope:
- autonomous app shell
- GlassMaster-inspired branding
- startup splash screen
- Lobster title font
- main window layout for future import workflow
- embedded Python runtime for standalone PTSL import
- AAF export for marker-only interchange with other DAWs

Build:

```bash
cd /Users/gautier/GogoLabs/FeedBacks
xcodegen generate
open FeedBacks.xcodeproj
```

Embedded Python runtime:

```bash
cd /Users/gautier/GogoLabs/FeedBacks
./scripts/prepare_embedded_python.sh
```
