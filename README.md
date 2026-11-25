# Myanmar Simple Keyboard for Mac — by Linn Labs

**iPhone လိုပဲ `ေ` ကို အရင်ရိုက်လို့ရတဲ့ Mac မြန်မာ keyboard**
Type `ေ` first on your Mac, just like the iPhone Myanmar keyboard.

| | ရိုက်တဲ့အစဉ် (`ကြေ`) |
|---|---|
| 📱 iPhone | `ေ` → `က` → `ြ` |
| 💻 Mac မူလ keyboard | `က` → `ြ` → `ေ` |
| ✅ **Myanmar Simple** | `ေ` → `က` → `ြ` (iPhone အတိုင်း) |

- ⌨️ Key နေရာ အားလုံးက Mac မူလ **Myanmar** keyboard အတိုင်းပါ (Shift၊ Option အပါအဝင်) — Apple ရဲ့ layout ကို တိုက်ရိုက်သုံးထားလို့ပါ။
- 🔤 သိမ်းတဲ့စာက Unicode မှန်ပါတယ် (Facebook၊ Google မှာ ရှာရင် မှန်မှန်တွေ့ပါတယ်)။
- 🍎 macOS 15 (Sequoia) နဲ့ အထက် · M chip နဲ့ Intel နှစ်မျိုးလုံး
- 🆓 အခမဲ့ · Open source (MIT)

> ⚠️ **Beta** — စမ်းသပ်ဆဲ version ပါ။ ပြဿနာ တွေ့ရင် [Issues](../../issues) မှာ ပြောပေးပါ။

---

## ⬇️ ထည့်နည်း (Install)

1. **[Releases](../../releases/latest)** စာမျက်နှာကနေ `MyanmarSimpleKeyboard-x.y.z.pkg` ကို download ဆွဲပါ။
2. `.pkg` ကို နှစ်ချက်နှိပ်ပါ။
3. **"Apple could not verify…"** ဆိုပြီး ပေါ်လာရင် (Apple Developer sign မလုပ်ထားလို့ပါ)-
   - **Done** နှိပ်ပါ
   -  → **System Settings** → **Privacy & Security** → အောက်ဆုံးနားက **"Open Anyway"** နှိပ်ပါ
   - Password ရိုက်ပြီး **Open** နှိပ်ပါ
4. Installer အတိုင်း **Continue → Install** နှိပ်ပါ။
5. Menu bar ညာဘက်အပေါ်က keyboard icon ကိုနှိပ်ပြီး **မြန်မာ (Simple)** ကို ရွေးပါ။

**Menu မှာ မတွေ့ရင်:** System Settings → Keyboard → Text Input → **Edit…** → **+** → **Burmese** → **မြန်မာ (Simple)** → **Add**။ ဒါလည်း မပေါ်သေးရင် Log out လုပ်ပြီး ပြန်ဝင်ပါ။

💡 Apple ရဲ့ မူလ Myanmar keyboard ကို မဖျက်ဘဲ ထားထားပါ။ ပြဿနာရှိရင် ချက်ချင်း ပြန်ပြောင်းသုံးလို့ရပါတယ်။

## ✍️ သုံးနည်း

- `ေ` နှိပ်လိုက်ရင် **မျဉ်းတားထားတဲ့ `ေ`** လေး ပေါ်ပြီး စောင့်နေပါမယ်။
- ဗျည်း (`က`) နဲ့ `ျ ြ ွ ှ` တွေ ရိုက်ပြီး နောက်ထပ် စာလုံးတစ်ခုခု (`ာ`၊ `း`၊ space…) ရိုက်လိုက်တာနဲ့ `ေ` က နေရာမှန်ကို အလိုအလျောက် ရောက်သွားပါမယ်။
- `ေ` ရိုက်ပြီး ⌫ Backspace နှိပ်ရင် `ေ` ပျက်သွားပါမယ်။
- ဆင့်ဗျည်း (`ကန္တော့`) နဲ့ ကင်းစီး (`သင်္ဘော`၊ Option+i) တွေလည်း ရပါတယ်။

စမ်းရမယ့် စာလုံးစာရင်း → [TESTING.md](TESTING.md)

## 🗑️ ဖြုတ်နည်း (Uninstall)

1. System Settings → Keyboard → Text Input → Edit… မှာ **မြန်မာ (Simple)** ကိုရွေးပြီး **−** နှိပ်ပါ။
2. Terminal ဖွင့်ပြီး ဒါကို ကူးထည့်ပါ-
   ```bash
   sudo rm -rf "/Library/Input Methods/MyanmarSimpleKeyboard.app" && sudo pkgutil --forget com.linnlabs.inputmethod.MyanmarSimple.pkg
   ```
3. Log out လုပ်ပြီး ပြန်ဝင်ပါ။

---

## English

**Myanmar Simple Keyboard** is a macOS input method that lets you type the vowel sign `ေ` (U+1031) *before* the consonant — the visual order used by the iPhone Myanmar keyboard — while storing correct Unicode (`က ြ ေ`).

- Uses Apple's own built-in *Myanmar* layout for every key (normal, Shift, Option, Caps Lock), so nothing moves.
- `ေ` is held as marked text until the consonant cluster after it (consonant, stacked consonants `္`, kinzi `င်္`, medials `ျ ြ ွ ှ`) is complete, then inserted in Unicode order.
- macOS 15+ · Apple Silicon & Intel · ad-hoc signed (not notarized): use *Privacy & Security → Open Anyway* the first time.

### Build from source

```bash
scripts/test.sh                 # unit tests for the ေ composer
VERSION=0.1.0 scripts/build.sh  # → build/MyanmarSimpleKeyboard-0.1.0.pkg
```

CI builds and tests on macOS 15 and 26, Apple Silicon and Intel, then installs the package on the runner and checks that macOS registers and enables the keyboard.

Project layout: `Sources/Core` (the ေ composer, pure Swift) · `Sources/App` (InputMethodKit app) · `Tests` · `pkg` (installer) · `Tools` (layout extraction).

## License

MIT © 2026 Linn Labs
