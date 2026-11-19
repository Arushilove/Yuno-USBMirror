# iPhone USB Screen Mirror (sirf USB cable se)

Ye project 2 hisson me hai:

| Hissa | Kahan chalta hai | Folder |
|---|---|---|
| Viewer (video dekhta hai) | Windows PC (Python) | `pc/` |
| App + Broadcast Extension (screen bhejta hai) | iPhone (Swift) | `ios/` |

Kaise kaam karta hai:

```
iPhone screen -> ReplayKit -> H.264 (VideoToolbox) -> TCP server (port 5000 iPhone par)
      -> USB cable (usbmuxd tunnel) -> PC viewer -> FFmpeg decode -> OpenCV window
```

## Zaroori cheezein

- Windows PC + USB data cable
- **Mac + Xcode** (iPhone app sirf Xcode se ban sakta hai. Windows par iOS app build nahi hoti.)
- Apple ID (free chalega, lekin free signing ka app sirf 7 din chalta hai)
- Windows par Apple ka USB driver (Apple Mobile Device Support). Douwan install karne se ye aa gaya ho sakta hai. Check: Settings -> Apps me "Apple Mobile Device Support".
- Python 3.9+

## Part 1: PC side (Windows)

```
cd pc
pip install -r requirements.txt
python list_iphones.py
```
iPhone USB se lagao, unlock karo, "Trust" dabao. `list_iphones.py` me tumhara iPhone dikhna chahiye. Nahi dikha to aage mat badho.

## Part 2: iPhone app (Mac par Xcode me)

1. Xcode -> **File -> New -> Project -> iOS -> App**. Name: `USBMirror`, Interface: SwiftUI, Language: Swift.
2. **File -> New -> Target -> Broadcast Upload Extension**. Name: `BroadcastExtension`. **"Include UI Extension" ka tick hata do.**
3. Project ke default files badlo:
   - `USBMirrorApp.swift` aur `ContentView.swift` ko `ios/USBMirror/` ke files se replace karo.
   - Extension ki `SampleHandler.swift` ko `ios/BroadcastExtension/SampleHandler.swift` se replace karo.
   - `StreamServer.swift` aur `H264Encoder.swift` ko extension target me add karo (drag karke, Target Membership me sirf **BroadcastExtension** tick rakho).
4. `ContentView.swift` me ye line apne extension ke Bundle ID se badlo:
   ```swift
   picker.preferredExtension = "com.yourname.USBMirror.BroadcastExtension"
   ```
   (Extension ka Bundle ID: target -> Signing & Capabilities me dikhta hai. Wo app ke Bundle ID se shuru hona chahiye.)
5. Dono targets me **Signing & Capabilities -> Team** me apna Apple ID chuno.
6. iPhone me Settings -> Privacy & Security -> **Developer Mode** ON karo (restart hoga).
7. Xcode me device chuno aur Run (Cmd+R) dabao.

## Part 3: Chalana

1. iPhone USB se lagao (unlock + Trust).
2. iPhone par **USB Mirror** app kholo, bada button dabao, popup me **USB Mirror** chuno, **Start Broadcast** dabao (3 second countdown hoga).
3. PC par:
   ```
   cd pc
   python mirror_viewer.py
   ```
4. Window me iPhone ki screen aa jayegi. Band karne ke liye `q` ya `Esc` dabao.

Options: `--port 5000` (agar extension ka port badla ho), `--height 800` (window ki height).

## Problems aur hal

| Dikkat | Matlab / hal |
|---|---|
| `usbmuxd se connect nahi ho paya` | Apple Mobile Device Support install nahi ya service band hai (`services.msc` -> Apple Mobile Device Service -> Start) |
| `Koi iPhone nahi mila` | Cable data wali lagao, iPhone unlock karo, Trust dabao |
| `Connect fail (code 3)` | Broadcast start nahi hua. Pehle iPhone par Start Broadcast karo |
| Connect ho gaya par window khali | iPhone ki screen par kuch hilao. ReplayKit tabhi frame deta hai jab screen badalti hai |
| Broadcast turant band ho jata hai | Xcode me extension ka console/log dekho (Debug -> Attach to Process by PID or Name -> BroadcastExtension) |
| Video atakti ya tuti hai | `H264Encoder.swift` me bitrate 8_000_000 se kam karo, ya `StreamServer.swift` ka `maxPending` badlo |
| 7 din baad app khulta nahi | Free Apple ID ki limit hai. Xcode se dobara Run karo |

## Limits (jo isme nahi hai)

- Audio nahi hai.
- PC se iPhone ko touch/control nahi kar sakte. Ye iOS par Apple seedha allow nahi karta.
- Sirf dekhna (mirroring). Recording ke liye PC par OBS se viewer window capture kar sakte ho.
- Ye code maine likha hai lekin **asli iPhone par test nahi kiya**. PC side ka usbmuxd wala hissa fake server par test hua hai. Video decode aur iOS wala hissa tumhare device par pehli baar chalega, to chhoti-moti error aa sakti hai.
