# MXFF AI — সম্পূর্ণ সেটআপ গাইড (বাংলা)

ফিউচারিস্টিক Android AI অ্যাসিস্ট্যান্ট **MXFF AI** — Gemini দ্বারা চালিত।

---

## ০. ভার্সন ২.১.০-এ ঠিক করা হয়েছে (APK fix)

- **Gemini মডেল এখন অটো-ডিটেক্ট হয়:** আগের APK-তে `gemini-2.5-flash` মডেলটি অনেক key-তে আর চালু নেই, তাই "এই Gemini মডেলটি পাওয়া যায়নি" এরর আসত। এখন MXFF AI আপনার key থেকে চালু মডেলের তালিকা নিয়ে নিজেই সঠিক মডেল বেছে নেয় এবং সেটিকে মনে রাখে। Settings → Model-এ **Auto** রাখলেই হবে; চাইলে তালিকা থেকে মডেল বেছে নিতে পারেন (⟳ বাটনে তালিকা রিফ্রেশ হয়)।
- মডেল হঠাৎ বন্ধ হয়ে গেলেও MXFF AI নিজে থেকেই অন্য চালু মডেল দিয়ে চেষ্টা করে।
- API key বসানোর সাথে সাথে মডেল তালিকা নিজে থেকে লোড হয়।

## ১. কী কী আছে (implemented features)

- **AMOLED কালো + নিয়ন লাল/সবুজ/সায়ান ডিজাইন**, glassmorphism প্যানেল
- **৩টি আলাদা Orb স্টেট:**
  - **State A (অ্যাপের ভেতরে):** বড় অ্যানিমেটেড orb — idle / listening / thinking / speaking আলাদা অ্যানিমেশন, ঘূর্ণায়মান ring, সবুজ particle, তারা
  - **State B (মিনিমাইজড floating orb):** অন্য অ্যাপ চালানোর সময় স্ক্রিনে ছোট ড্র্যাগযোগ্য orb; ট্যাপ করলে MXFF AI খোলে, লম্বা চাপলে লুকায়
  - **State C (Active assistant orb):** MXFF AI কথা বলা/শোনার সময় বড় orb + status টেক্সট ("MXFF AI is speaking…") + বন্ধ করার বাটন; সেশন শেষে আবার ছোট orb
- **Gemini AI:** মাল্টি-টার্ন চ্যাট, কনটেক্সট, বাংলা+ইংরেজি, ইতিহাস, ক্লিয়ার চ্যাট, লোডিং/এরর স্টেট, Retry বাটন, configurable system instruction ও মডেল
- **ভয়েস:** Speech-to-text + Text-to-speech, মাইক্রোফোন পারমিশন ফ্লো, listening/speaking অ্যানিমেশন, চলমান উত্তর বন্ধ করা (mic চাপলে interrupt), speech rate/volume/pitch সেটিংস
- **ফোন অ্যাকশন (voice command):** "Open TikTok / YouTube / Chrome / Settings" (বাংলাতেও: "টিকটক খোলো") — সরাসরি ইনস্টল করা অ্যাপ খোলে, **Play Store-এ যায় না**; "Minimize MXFF AI", "Show/Hide floating orb", "Sleep MXFF AI"
- **Sleep / START:** Sleep করলে ভয়েস, overlay, লিসেনিং সব বন্ধ; অ্যাপ খুলে START চাপলে আবার চালু
- **চ্যাট হিস্ট্রি:** লোকাল সেভ, পুরনো conversation দেখা, rename, delete, সব মুছে ফেলা
- **Settings:** Gemini API key (অ্যাপের ভেতরেই বসানো যায়), মডেল সিলেকশন, ভয়েস সেটিংস, ভাষা, orb অ্যানিমেশন, পারমিশন স্ট্যাটাস, privacy, about
- **Triggers:** Wake phrase কনফিগার + Listening mode (ব্যাখ্যা নিচে)

---

## ২. গুরুত্বপূর্ণ সীমাবদ্ধতা (সৎভাবে বলা হচ্ছে)

- **Always-on background wake word নেই।** Android সাধারণ অ্যাপকে ব্যাকগ্রাউন্ডে সবসময় মাইক্রোফোন চালু রাখতে দেয় না। তাই যা করা হয়েছে: **Listening mode** — অ্যাপটি খোলা/সামনে থাকলে কণ্ঠ শোনে; wake phrase (ডিফল্ট "MXFF") বললে কমান্ড নেয়। অন্য অ্যাপ ব্যবহারের সময় ভয়েস দরকার হলে floating orb-এ ট্যাপ করে MXFF AI খুলুন।
- API key অ্যাপের settings-এ ফোনেই থাকে; APK-তে হার্ডকোড করা হয় না (চাইলে build-এর সময় `--dart-define=GEMINI_API_KEY=...` দিয়েও দেওয়া যায়, তবে সেটিও key APK থেকে বের করা সম্ভব — এটাই Android-এর বাস্তবতা)। Production-এ নিজের backend proxy ব্যবহার করুন।
- ফোন বন্ধ করা/রিবুট দেওয়া সাধারণ অ্যাপ দিয়ে সম্ভব নয় — MXFF AI তাই দাবি করে না।

---

## ৩. প্রথমবার চালানোর ধাপ

1. APK ইনস্টল করুন (নিচের লিংক/ফাইল)।
2. অ্যাপ খুলে **Settings ট্যাব → API key**-তে Google AI Studio-র key বসান ([aistudio.google.com/apikey](https://aistudio.google.com/apikey))।
3. Home ট্যাবে টাইপ করে বা মাইক চেপে কথা বলুন।
4. **Floating Orb** চাইলে: Home → "Floating Orb" চাপুন → Android-এর "Display over other apps" অনুমতি দিন → আবার চাপুন।
5. মাইক প্রথমবার চাপলে মাইক্রোফোন অনুমতি চাইবে — Allow দিন।

---

## ৪. ডেভেলপার: বিল্ড কমান্ড

```bash
# নির্ভরতা
flutter pub get

# ডিবাগ রান
flutter run

# Release APK
flutter build apk --release
# (চাইলে build-এর সময় key: flutter build apk --release --dart-define=GEMINI_API_KEY=YOUR_KEY)

# আউটপুট
# build/app/outputs/flutter-apk/app-release.apk
```

প্রজেক্ট স্ট্রাকচার: `lib/` (Riverpod state, features, services, data models), `android/app/src/main/kotlin/com/mxff/ai/` (MainActivity, MxffOverlayService, OrbView)।

মডেল পরিবর্তন: Settings → Model ড্রপডাউন (gemini-2.5-flash ডিফল্ট) বা `lib/core/constants.dart`-এ `kDefaultGeminiModel`।

---

## ৫. যেগুলো এখনো আসল ডিভাইসে টেস্ট করতে হবে

স্যান্ডবক্সে APK কম্পাইল হয়েছে, কিন্তু আসল ফোনে এগুলো যাচাই করা হয়নি:

- [ ] মাইক্রোফোন ভয়েস ইনপুট (device-specific speech engine)
- [ ] TTS-এর বাংলা ভয়েস (ডিভাইসে Google TTS ইনস্টল থাকতে হয়)
- [ ] Overlay পারমিশন ফ্লো ও ড্র্যাগ (Android 13/14/15 আচরণ)
- [ ] অ্যাপ ওপেন কমান্ড (TikTok ইত্যাদির প্যাকেজ নাম ডিভাইসভেদে ভিন্ন হতে পারে)
- [ ] Sleep → START ফ্লো ও ব্যাটারি আচরণ
- [ ] আসল Gemini key দিয়ে চ্যাট/ভয়েস রেসপন্স

---

## ৬. সুরক্ষা

- AI-এর কোনো আর্বিট্রারি শেল কমান্ড বা কোড চালানো হয় না।
- Sensitive অ্যাকশনের আগে confirmation দেখানো হয়।
- চ্যাট ও সেটিংস শুধু ফোনে থাকে; কোথাও আপলোড হয় না।
