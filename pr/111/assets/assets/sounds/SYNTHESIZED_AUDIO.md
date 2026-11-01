The former `background.wav` was a 24-second synthesized sine-wave loop without
checked-in authoring sources. It has been replaced by **The Common Table**, an
original five-arrangement soundtrack authored in [`music/score.py`](../../music/score.py)
and synthesized by [`scripts/generate_music.py`](../../scripts/generate_music.py).
See [music preparation and provenance](../../music/README.md). Only text sources
are versioned; generated music MP3 files and their manifest are ignored build assets.

`your_turn.wav` and `tak.wav` remain synthesized sine-wave effects. No third-party
recordings or melodies are used by these effects or the new music. These assets
and the music sources use the repository license. Other existing effect assets
are unchanged by this soundtrack update.

The six `landing_{wood,stone,marble}[_heavy].ogg` contact sounds are original
procedural audio: seeded filtered noise, damped sine resonances, a low body and a
quiet settling contact. Rebuild with `python3 tools/generate_landing_audio.py`
(requires ffmpeg with libvorbis). They last 190/240 ms with bounded peaks and
faded tails. No third-party recordings are used; the repository license applies.
