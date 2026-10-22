# Bundled audio

The Irodori 初級2 lesson audio (338 MP3, `Z_[LL-TT]_<type><suffix>.mp3`) is bundled into the app
but is **not committed** (see `.gitignore`). To enable the Audio library, copy the files here:

```sh
cp ~/Downloads/Z_audio_all/*.mp3 Kachiiro/Audio/
```

The folder is part of the synchronized Xcode group, so the files are bundled on the next build.
