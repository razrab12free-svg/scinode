// Тексты замка приложения. Порядок: русский, узбекский, английский.
const Map<String, List<String>> lockStrings = {
  'lock.title': [
    'Scinode заблокирован',
    'Scinode qulflangan',
    'Scinode is locked',
  ],
  'lock.text': [
    'Подтвердите, что это вы: отпечаток пальца, лицо или PIN-код телефона.',
    'Bu siz ekaningizni tasdiqlang: barmoq izi, yuz yoki telefon PIN-kodi.',
    'Confirm it’s you: fingerprint, face or your phone’s PIN.',
  ],
  'lock.unlock': ['Разблокировать', 'Qulfni ochish', 'Unlock'],
  'lock.sys_title': [
    'Вход в Scinode',
    'Scinode’ga kirish',
    'Unlock Scinode',
  ],
  'lock.reason': [
    'Подтвердите, что это вы, чтобы открыть Scinode',
    'Scinode’ni ochish uchun bu siz ekaningizni tasdiqlang',
    'Confirm it’s you to open Scinode',
  ],
  'lock.reason_enable': [
    'Подтвердите, что это вы, чтобы включить замок',
    'Qulfni yoqish uchun bu siz ekaningizni tasdiqlang',
    'Confirm it’s you to turn on the lock',
  ],
  'lock.canceled': [
    'Проверка не пройдена. Нажмите «Разблокировать», чтобы попробовать ещё раз.',
    'Tekshiruvdan o‘tilmadi. Qayta urinish uchun «Qulfni ochish»ni bosing.',
    'Not confirmed. Tap “Unlock” to try again.',
  ],
  'lock.locked_out': [
    'Слишком много неудачных попыток. Подождите немного и попробуйте снова — можно ввести PIN-код телефона.',
    'Juda ko‘p muvaffaqiyatsiz urinish. Biroz kutib, qayta urinib ko‘ring — telefon PIN-kodini kiritish mumkin.',
    'Too many failed attempts. Wait a little and try again — you can use your phone’s PIN.',
  ],
  'lock.error': [
    'Не удалось открыть проверку телефона. Попробуйте ещё раз.',
    'Telefon tekshiruvini ochib bo‘lmadi. Qayta urinib ko‘ring.',
    'Couldn’t open the phone’s check. Please try again.',
  ],
  'lock.turned_off': [
    'На телефоне больше нет блокировки экрана, поэтому замок Scinode выключен. Включите блокировку экрана в настройках телефона, а затем — замок в «Профиле».',
    'Telefonda ekran qulfi endi yo‘q, shuning uchun Scinode qulfi o‘chirildi. Telefon sozlamalarida ekran qulfini, so‘ng «Profil»da qulfni yoqing.',
    'Your phone no longer has a screen lock, so the Scinode lock was turned off. Set a screen lock in phone settings, then turn on the lock in Profile.',
  ],
  // Профиль.
  'lock.setting': ['Замок приложения', 'Ilova qulfi', 'App lock'],
  'lock.setting_sub': [
    'Отпечаток, лицо или PIN телефона при открытии Scinode',
    'Scinode ochilganda barmoq izi, yuz yoki telefon PIN-kodi',
    'Fingerprint, face or phone PIN when opening Scinode',
  ],
  'lock.after': [
    'Блокировать после выхода из приложения:',
    'Ilovadan chiqqandan keyin qulflash:',
    'Lock after leaving the app:',
  ],
  'lock.now': ['Сразу', 'Darhol', 'Immediately'],
  'lock.min': ['{n} мин', '{n} daq', '{n} min'],
  'lock.on_done': [
    'Замок включён',
    'Qulf yoqildi',
    'App lock is on',
  ],
  'lock.off_done': [
    'Замок выключен',
    'Qulf o‘chirildi',
    'App lock is off',
  ],
  'lock.no_screen_title': [
    'Нет блокировки экрана',
    'Ekran qulfi yo‘q',
    'No screen lock',
  ],
  'lock.no_screen_text': [
    'Замок Scinode использует защиту самого телефона. Сначала включите блокировку экрана (PIN-код, графический ключ или пароль, по желанию — отпечаток пальца) в настройках телефона: «Настройки» → «Безопасность» → «Блокировка экрана». Потом вернитесь сюда и включите замок.',
    'Scinode qulfi telefonning o‘z himoyasidan foydalanadi. Avval telefon sozlamalarida ekran qulfini yoqing (PIN-kod, grafik kalit yoki parol, xohlasangiz — barmoq izi): «Sozlamalar» → «Xavfsizlik» → «Ekran qulfi». So‘ng bu yerga qaytib, qulfni yoqing.',
    'The Scinode lock uses your phone’s own protection. First set a screen lock (PIN, pattern or password, and a fingerprint if you like) in phone settings: Settings → Security → Screen lock. Then come back here and turn on the lock.',
  ],
  'lock.ok': ['Понятно', 'Tushunarli', 'Got it'],
};
