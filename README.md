# 📞→⌚🌡️ Time & Temperature Announcer for FreePBX

This FreePBX dialplan module plays dynamic time, date, and weather temperature to callers using custom audio files. It supports personalized greetings, robust number parsing, and seamless temperature integration via a shell script that fetches live data.

## 🧩 Features

- Accurate playback of current time and date
- Personalized "Good morning / afternoon / evening" greetings
- Temperature fetched from Open-Meteo API and played as whole number
- Support for negative temperatures (e.g. “minus 5 degrees”)
- Modular number pronunciation using `custom-play-number`
- Graceful fallback logic and caching if temperature is unavailable

## 🔧 Dialplan Overview

Defined under `from-internal-custom`, this extension parses and plays:

- The current time: `custom/the-time-is`, followed by hour and minute using custom audio (`custom/1`, `custom/5`, `custom/20`, etc.)
- The current date and day: `custom/today-is`, day/month/date parsed as audio
- Temperature: fetched live, sanitized to whole number, parsed and played

The number playback logic intelligently handles:

- Single digits
- Teen numbers (10–19)
- Compound tens (e.g. 73 `custom/70`, `custom/3`)
- Hundreds (e.g. 103 `custom/100`, `custom/3`)

## 🛰️ Temperature Script

Located at `/usr/local/bin/get_temp.sh`, this Bash script:

- Queries Open-Meteo with predefined `LAT`/`LON` values
- Rounds float temperature to whole number
- Strips newline characters from output
- Logs readings and fallbacks to `/var/lib/asterisk/temp_script.log`
- Caches last known good value to `/var/lib/asterisk/last_known_temp`

> Sample Output: `73` or `-5` (cleaned before passing to dialplan)

## 🛡️ Security & Hardening

- All `Playback()` calls are immune to DTMF input — no caller breakouts
- No `Background()` or `WaitExten()` used
- One-second `Wait(1)` before hangup to avoid call clipping
- Caller routed to `*987` internally via static mapping (`<your DID here>`)
- Invalid numeric values route to `custom/error` (optional audio fallback)

## 🗂️ Files & Paths

| File / Context                       | Purpose                                |
|-------------------------------------|----------------------------------------|
| `extensions_custom.conf`            | Dialplan logic                         |
| `/usr/local/bin/get_temp.sh`        | Temperature fetch script               |
| `/var/lib/asterisk/temp_script.log` | Temperature script logging             |
| `/var/lib/asterisk/last_known_temp` | Cache fallback for weather             |
| `/var/lib/asterisk/sounds/custom/`  | Custom audio files (`*.slin`)          |

## 🔄 Requirements

- FreePBX, asterisk or similar with custom dialplan capability
- Bash shell & `curl` and `jq` for weather parsing
- `custom/` audio files matching digits and phrases (e.g. `custom/70.slin`)
- Executable permissions and ownership for temp script:
  ```bash
  chmod +x /usr/local/bin/get_temp.sh
  chown asterisk:asterisk /usr/local/bin/get_temp.sh
  ```

## 🚀 Setup Guide (For Beginners)

These instructions walk you through installing and configuring the Time & Temperature playback system in FreePBX/Asterisk from the main system terminal.

### 🧱 Prerequisites

- A working FreePBX server with terminal access
- Basic knowledge of Linux command line - Or google/copilot help
- Audio files for number playback placed in `/var/lib/asterisk/sounds/custom/` (slin format, .wav will work but with a slight delay in playback because they get converted on the fly)


### ⚙️ Step-by-Step Installation

#### 1️⃣ Upload Custom Audio Files via SCP

From your local machine or audio workstation, use `scp` to copy your `.wav` or `.slin` files to the server:
Either drag and drop to `/var/lib/asterisk/sounds/custom/` using the windows version of SCP or:
```bash
scp /local/path/to/audio/*.slin youruser@yourserver:/var/lib/asterisk/sounds/custom/
```

After uploading, from the command prompt on the FreePBX server, set ownership:

```bash
chown asterisk:asterisk /var/lib/asterisk/sounds/custom/*.slin
```

> 🔧 Tip: For best performance, convert `.wav` files to `.slin` or `.ulaw`. See audio optimization section for batch conversion using `sox` or `ffmpeg`.

---

#### 3️⃣ Add Temperature Script via SCP

From your local system, upload the script to the server either by drag and drop `/usr/local/bin/` or:

```bash
scp get_temp.sh youruser@yourserver:/usr/local/bin/
```

Then from the FreePBX terminal, make it executable:

```bash
chmod +x /usr/local/bin/get_temp.sh
chown asterisk:asterisk /usr/local/bin/get_temp.sh
```

Test it:

```bash
/usr/local/bin/get_temp.sh
```

> 🧪 The output should be a clean whole number (e.g. `72`). If it includes hidden characters or fails, see log at `/var/lib/asterisk/temp_script.log`.


#### 4️⃣ Insert Dialplan Code via FreePBX GUI

1. **Login to FreePBX Admin Interface**
   - Open your browser and go to: `http://yourserver/admin`
   - Authenticate using your admin credentials.

2. **Navigate to Custom Destinations**
   - Go to **Admin > Custom Destinations**
   - Click **Add Custom Destination**

3. **Define the Dialplan Context**
   - Set **Custom Destination** to your desired logic, for example:  
     `temp-check,s,1`
   - Give it a recognizable **Description** (e.g. `Temperature Playback`)
   - Click **Submit** and **Apply Config**

4. **Add Logic to extensions_custom.conf**
   - In the GUI, go to **Admin > Config Edit** (or use **System Admin > File Editor** if available)
   - Open `/etc/asterisk/extensions_custom.conf`
   - Add the dialplan provided in this github, copy/paste and update for your inbound DID

5. **Reload Dialplan**
   - Hit **Apply Config** or
     - Navigate to **Admin > Asterisk CLI**
     - Run the command:
       ```
       dialplan reload
       ```

#### 5️⃣ Create Feature Code in GUI

Open the FreePBX Admin Web Interface:

- Go to **Admin → Custom Destinations**
  - Add: `from-internal-custom,*987,1`
- Go to **Admin → Misc Applications**
  - Name: “Time & Temp”
  - Feature Code: `*987`
  - Destination: your custom context

You can now dial `*987` from any extension to hear the playback if this is part of a full PBX system, otherwise if stand alone Time & Temp, ignore this.

## 🔍 Monitoring & Logs

To monitor the playback flow:
```bash
tail -f /var/log/asterisk/full
```

To monitor the temperature script:
```bash
tail -f /var/lib/asterisk/temp_script.log
```

## ⚖️ License

This project is provided under a custom license:
> You are free to use, modify, and adapt this code for personal or internal use.  
> You may not sell, distribute, or offer this code (or derivatives of it) as part of a commercial product or service, whether modified or unmodified.  
> Redistribution is allowed only for educational or non-commercial personal purposes, with proper attribution to the original author.

© Pir8Radio All rights reserved.
