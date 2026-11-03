# MXFF AI — বাংলা Full Device Control আপডেট

## এই আপডেটে যোগ/উন্নত
- Accessibility Service দিয়ে দৃশ্যমান অ্যাপ UI-তে টেক্সট-ভিত্তিক ক্লিক, স্ক্রল, লেখা, Back, Home, Recents ও Notifications অ্যাকশন।
- বাংলা কথ্য নির্দেশের একাধিক রূপ: “আগের পেজে যাও”, “নিচে নামাও”, “উপরে স্ক্রল”, “লাইক দাও”, “হ্যালো লিখে দাও”, “অ্যাসিস্ট্যান্ট বন্ধ করো”।
- বাংলা/ইংরেজি অ্যাপ নাম দিয়ে অ্যাপ খোলা (যে অ্যাপের package alias তালিকায় আছে)।
- “ফ্রি ফায়ার সার্চ করো” বা “সার্চ করো ফ্রি ফায়ার” ধরনের নির্দেশে ওয়েব সার্চ খোলা।
- Accessibility-র লেখা টাইপ করার সময় password/PIN/OTP-সদৃশ ফিল্ডে টাইপ বন্ধ রাখার সুরক্ষা।
- Accessibility Settings খোলার শর্টকাট এবং অন্য অ্যাপে গেলে Overlay Orb দেখানোর আগের সুবিধা।

## এখনো সম্পূর্ণ নয় — পরিষ্কারভাবে জানানো হচ্ছে
- অন্য অ্যাপের ভেতরে নিরবচ্ছিন্ন মাইক্রোফোন শোনা এবং wake-word: এখনো তৈরি হয়নি। Android-এর microphone foreground service, স্থায়ী notification, runtime permission এবং lifecycle handling আলাদাভাবে বাস্তবায়ন ও ডিভাইসে পরীক্ষা করা প্রয়োজন।
- Floating Orb-এ ট্যাপ করে সরাসরি cross-app voice session শুরু করা: এখনো সম্পূর্ণ সংযুক্ত নয়।
- Gemini দিয়ে যেকোনো স্বাভাবিক বাংলা বাক্যকে বহু-ধাপের UI action-এ রূপান্তর: এখনো নেই; বর্তমানে পরিচিত কমান্ডগুলো rule-based।
- “লাইক দাও” কেবল তখনই কাজ করবে যখন বর্তমান অ্যাপে Accessibility-তে Like লেখা/বাটন দৃশ্যমান ও ক্লিকযোগ্য হিসেবে প্রকাশিত হয়।
- Android-এর নিরাপদ/সুরক্ষিত স্ক্রিন, অপ্রকাশিত UI, DRM বা অন্য অ্যাপের গোপন তথ্য নিয়ন্ত্রণ/পড়া যাবে না।

## চালু করার নিয়ম
1. MXFF AI-কে Microphone permission দিন।
2. Android Settings → Accessibility → MXFF AI App Control চালু করুন।
3. Display over other apps / Overlay permission দিন।
4. অ্যাপ খুলে মাইক্রোফোন বোতাম দিয়ে কথা বলুন।

## Build ও পরীক্ষা
এই পরিবেশে Flutter/Android SDK নেই, তাই APK compile বা বাস্তব ফোনে পরীক্ষা করা সম্ভব হয়নি। ZIP-টি source update; একে পরীক্ষিত APK বলা যাবে না।
