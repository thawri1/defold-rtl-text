local M = {}

M.space = "20"

-- Zero width joiners (important for Persian)
M.zwnj = "e2808c" -- U+200C (semi-space / نیم‌فاصله)
M.zwj  = "e2808d" -- U+200D (optional)

-- punctuation / digits act as boundaries
M.symbols = {
  "20","21","22","23","24","25","26","27","28","29",
  "2a","2b","2c","2d","2e","2f",
  "30","31","32","33","34","35","36","37","38","39",
  "3a","3b","3c","3d","3e","3f","40",
  "5b","5c","5d","5e","5f","60",
  "7b","7c","7d","7e",
  "d88c","d89b","d89f", -- ، ؛ ؟
  "e2808c","e2808d"     -- ZWNJ / ZWJ (treat as boundaries)
}

-- Arabic + Persian letters (presentation forms)
M.hex = {
  -- ALEF family
  d8a2 = { isolated="efba81", first="efba81", middle="efba81", last="efba82" }, -- آ
  d8a3 = { isolated="efba83", first="efba83", middle="efba83", last="efba84" }, -- أ
  d8a5 = { isolated="efba87", first="efba87", middle="efba87", last="efba88" }, -- إ
  d8a7 = { isolated="efba8d", first="efba8d", middle="efba8d", last="efba8e" }, -- ا

  -- Beh group
  d8a8 = { isolated="efba8f", first="efba91", middle="efba92", last="efba90" }, -- ب
  d9be = { isolated="efad96", first="efad98", middle="efad99", last="efad97" }, -- پ
  d8aa = { isolated="efba95", first="efba97", middle="efba98", last="efba96" }, -- ت
  d8ab = { isolated="efba99", first="efba9b", middle="efba9c", last="efba9a" }, -- ث

  -- Jim group
  d8ac = { isolated="efba9d", first="efba9f", middle="efbaa0", last="efba9e" }, -- ج
  da86 = { isolated="efadba", first="efadbc", middle="efadbd", last="efadbb" }, -- چ
  d8ad = { isolated="efbaa1", first="efbaa3", middle="efbaa4", last="efbaa2" }, -- ح
  d8ae = { isolated="efbaa5", first="efbaa7", middle="efbaa8", last="efbaa6" }, -- خ

  -- Dal / Reh group
  d8af = { isolated="efbaa9", first="efbaa9", middle="efbaa9", last="efbaaa" }, -- د
  d8b0 = { isolated="efbaab", first="efbaab", middle="efbaab", last="efbaac" }, -- ذ
  d8b1 = { isolated="efbaad", first="efbaad", middle="efbaad", last="efbaae" }, -- ر
  d8b2 = { isolated="efbaaf", first="efbaaf", middle="efbaaf", last="efbab0" }, -- ز
  da98 = { isolated="efae8a", first="efae8a", middle="efae8a", last="efae8b" }, -- ژ

  -- Seen group
  d8b3 = { isolated="efbab1", first="efbab3", middle="efbab4", last="efbab2" }, -- س
  d8b4 = { isolated="efbab5", first="efbab7", middle="efbab8", last="efbab6" }, -- ش
  d8b5 = { isolated="efbab9", first="efbabb", middle="efbabc", last="efbaba" }, -- ص
  d8b6 = { isolated="efbabd", first="efbabf", middle="efbb80", last="efbabe" }, -- ض
  d8b7 = { isolated="efbb81", first="efbb83", middle="efbb84", last="efbb82" }, -- ط
  d8b8 = { isolated="efbb85", first="efbb87", middle="efbb88", last="efbb86" }, -- ظ

  -- Ain group
  d8b9 = { isolated="efbb89", first="efbb8b", middle="efbb8c", last="efbb8a" }, -- ع
  d8ba = { isolated="efbb8d", first="efbb8f", middle="efbb90", last="efbb8e" }, -- غ

  -- Feh group
  d981 = { isolated="efbb91", first="efbb93", middle="efbb94", last="efbb92" }, -- ف
  d982 = { isolated="efbb95", first="efbb97", middle="efbb98", last="efbb96" }, -- ق
  d983 = { isolated="efbb99", first="efbb9b", middle="efbb9c", last="efbb9a" }, -- ك
  daa9 = { isolated="efae8e", first="efae90", middle="efae91", last="efae8f" }, -- ک
  daaf = { isolated="efae92", first="efae94", middle="efae95", last="efae93" }, -- گ

  -- Lam / Meem / Noon / Heh
  d984 = { isolated="efbb9d", first="efbb9f", middle="efbba0", last="efbb9e" }, -- ل
  d985 = { isolated="efbba1", first="efbba3", middle="efbba4", last="efbba2" }, -- م
  d986 = { isolated="efbba5", first="efbba7", middle="efbba8", last="efbba6" }, -- ن
  d987 = { isolated="efbba9", first="efbbab", middle="efbbac", last="efbbaa" }, -- ه

  -- Waw / Yeh
  d988 = { isolated="efbbad", first="efbbad", middle="efbbad", last="efbbae" }, -- و
  d98a = { isolated="efbbb1", first="efbbb3", middle="efbbb4", last="efbbb2" }, -- ي
  db8c = { isolated="efafbc", first="efafbe", middle="efafbf", last="efafbd" }, -- ی فارسی
}

return M
