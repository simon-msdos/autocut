# [ autocut ]

**The "no-nonsense" terminal video splitter.**

I got tired of opening heavy video editors just to split a long recording into smaller chunks for Discord, Telegram, or WhatsApp. So, I wrote this. It’s a simple Bash script that wraps `ffmpeg` to handle the math and the slicing for you.

### ➔ Why use this?
*   **Human Time Formats:** It understands `9m30s`, `570`, or `00:09:30`. No need to calculate seconds in your head.
*   **Parallel Processing:** If you have a folder of videos, it can use `-p` to process them in parallel using all your CPU cores.
*   **Self-Installing:** Just run it once, and it can move itself to `/usr/local/bin` so you can call `autocut` from anywhere.
*   **Smart Scaling:** It automatically handles the "odd-dimension" errors that usually break `ffmpeg` (the `iw/2` scale trick).

### ➔ Quick Start
```bash
# Split a video into 10-minute chunks
autocut my_video.mp4 10m

# Split everything in a folder into 2-minute clips, 4 at a time
autocut ./recordings 2m -p 4
```

### ➔ Installation
```bash
curl -s https://raw.githubusercontent.com/simon-msdos/autocut/master/autocut.sh -o autocut
chmod +x autocut
./autocut --help
```

### ➔ Tech Stack
`Bash` `FFmpeg` `Parallel processing`

---
*Built because manual slicing is a waste of time.*
