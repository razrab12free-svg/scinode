// Тексты заполнения профиля по ORCID. Порядок: русский, узбекский, английский.
const Map<String, List<String>> orcidStrings = {
  'orc.fill': [
    'Заполнить профиль по ORCID',
    'Profilni ORCID orqali to‘ldirish',
    'Fill profile from ORCID',
  ],
  'orc.hint': [
    'Введите свой ORCID iD — имя, организация, страна, публикации и направления подтянутся из открытых данных ORCID и OpenAlex.',
    'ORCID iD raqamingizni kiriting — ism, tashkilot, mamlakat, nashrlar va yo‘nalishlar ORCID va OpenAlex ochiq ma’lumotlaridan olinadi.',
    'Enter your ORCID iD — name, organization, country, publications and research areas will be pulled from open ORCID and OpenAlex data.',
  ],
  'orc.bad': [
    'Проверьте номер ORCID: 16 цифр (последней может быть X), например 0000-0002-1825-0097. Можно вставить ссылку orcid.org.',
    'ORCID raqamini tekshiring: 16 ta raqam (oxirgisi X bo‘lishi mumkin), masalan 0000-0002-1825-0097. orcid.org havolasini qo‘yish mumkin.',
    'Check the ORCID number: 16 digits (the last may be X), e.g. 0000-0002-1825-0097. You can paste an orcid.org link.',
  ],
  'orc.err.notfound': [
    'В ORCID нет записи с таким номером. Проверьте цифры.',
    'ORCID’da bunday raqamli yozuv yo‘q. Raqamlarni tekshiring.',
    'ORCID has no record with this number. Check the digits.',
  ],
  'orc.err.network': [
    'Нет связи с ORCID. Проверьте интернет и попробуйте ещё раз.',
    'ORCID bilan aloqa yo‘q. Internetni tekshirib, qayta urinib ko‘ring.',
    'Can’t reach ORCID. Check your internet and try again.',
  ],
  'orc.err.other': [
    'ORCID сейчас не отвечает. Попробуйте позже.',
    'ORCID hozir javob bermayapti. Keyinroq urinib ko‘ring.',
    'ORCID isn’t responding right now. Please try later.',
  ],
  'orc.empty': [
    'В этой записи ORCID нет открытых данных: владелец скрыл их или ещё не заполнил.',
    'Bu ORCID yozuvida ochiq ma’lumot yo‘q: egasi ularni yashirgan yoki hali to‘ldirmagan.',
    'This ORCID record has no public data: the owner hid it or hasn’t filled it in yet.',
  ],
  'orc.found_title': [
    'Найдено по ORCID',
    'ORCID orqali topildi',
    'Found via ORCID',
  ],
  'orc.bio': ['О себе', 'O‘zim haqimda', 'About'],
  'orc.author': [
    '{name} — работ: {n}',
    '{name} — ishlar: {n}',
    '{name} — works: {n}',
  ],
  'orc.no_author': [
    'В OpenAlex автор с этим ORCID не найден. Публикации можно привязать вручную ниже.',
    'OpenAlex’da bu ORCID bilan muallif topilmadi. Nashrlarni quyida qo‘lda bog‘lash mumkin.',
    'No OpenAlex author with this ORCID. You can link publications manually below.',
  ],
  'orc.tags': [
    'Добавить направления',
    'Yo‘nalishlarni qo‘shish',
    'Add research areas',
  ],
  'orc.check_note': [
    'Данные взяты из открытых записей ORCID и OpenAlex. Проверьте их и нажмите «Сохранить».',
    'Ma’lumotlar ORCID va OpenAlex ochiq yozuvlaridan olindi. Ularni tekshirib, «Saqlash»ni bosing.',
    'Data comes from open ORCID and OpenAlex records. Check it, then tap “Save”.',
  ],
  'orc.apply': ['Подставить', 'Qo‘yish', 'Apply'],
  'orc.applied': [
    'Данные подставлены. Не забудьте сохранить профиль.',
    'Ma’lumotlar qo‘yildi. Profilni saqlashni unutmang.',
    'Filled in. Don’t forget to save your profile.',
  ],
  'search.err.notfound': [
    'Ничего не найдено',
    'Hech narsa topilmadi',
    'Nothing found',
  ],
};
