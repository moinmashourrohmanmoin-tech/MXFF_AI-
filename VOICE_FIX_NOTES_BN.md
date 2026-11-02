# MXFF AI Voice Fix (বাংলা)

এই ZIP-এ মূল MXFF AI v11 প্রজেক্টের ফাইলগুলো রাখা হয়েছে এবং নিচের পরিবর্তন করা হয়েছে:

1. Gemini Live PCM microphone route বন্ধ করে Android `speech_to_text` → Gemini chat → TTS পথ চালু করা হয়েছে।
2. Android speech recognizer-এর `done/notListening` status-এর পরে 900ms অপেক্ষা করে transcript পাঠানোর ব্যবস্থা করা হয়েছে।
3. GitHub Actions workflow `.github/workflows/build-apk.yml` রাখা হয়েছে। এটি `main` branch-এ push বা Actions থেকে manual run করলে `MXFF_AI_apk` নামে APK artifact তৈরি করবে।

**গুরুত্বপূর্ণ:** এটি বিকল্প speech-recognition path; সব ফোনে কাজ করার নিশ্চয়তা নয়। Android-এ Google Speech Services/সমর্থিত speech recognizer, microphone permission এবং internet প্রয়োজন হতে পারে। `flutter analyze` ও GitHub Actions build সফল হয়েছে—এমন দাবি করা হচ্ছে না; আপনার GitHub Actions result দেখে নিশ্চিত হবেন।
