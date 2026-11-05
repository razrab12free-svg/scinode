// Тексты сводки доски, PDF-отчёта, таймера фокуса и мотивации.
// Порядок: русский, узбекский, английский.
// В строках rp.pdf.* нет эмодзи: их нет во встроенном шрифте PDF.
const Map<String, List<String>> reportStrings = {
  // Сводка доски.
  'rp.summary': ['Сводка', 'Xulosa', 'Summary'],
  'rp.summary_title': ['Сводка доски', 'Doska xulosasi', 'Board summary'],
  'rp.done': ['Выполнено', 'Bajarildi', 'Done'],
  'rp.open': ['В работе', 'Jarayonda', 'In progress'],
  'rp.overdue': ['Просрочено', 'Muddati o‘tgan', 'Overdue'],
  'rp.percent': ['готово', 'bajarildi', 'done'],
  'rp.total': ['Всего задач: {n}', 'Jami vazifalar: {n}', 'Total tasks: {n}'],
  'rp.by_column': ['По колонкам', 'Ustunlar bo‘yicha', 'By column'],
  'rp.by_member': [
    'Нагрузка по участникам',
    'Ishtirokchilar yuklamasi',
    'Workload by member',
  ],
  'rp.member_line': [
    'В работе: {o} · выполнено: {d}',
    'Jarayonda: {o} · bajarildi: {d}',
    'In progress: {o} · done: {d}',
  ],
  'rp.focus_line': ['Фокус: {t}', 'Fokus: {t}', 'Focus: {t}'],
  'rp.weekly': [
    'Выполнено по неделям',
    'Haftalar bo‘yicha bajarildi',
    'Done per week',
  ],
  'rp.weeks_ago': ['{n} нед. назад', '{n} hafta oldin', '{n} wk ago'],
  'rp.this_week': ['Эта неделя', 'Shu hafta', 'This week'],
  'rp.overdue_list': [
    'Просроченные задачи',
    'Muddati o‘tgan vazifalar',
    'Overdue tasks',
  ],
  'rp.no_overdue': [
    'Просроченных задач нет. Отлично!',
    'Muddati o‘tgan vazifalar yo‘q. Ajoyib!',
    'No overdue tasks. Great!',
  ],
  'rp.empty': [
    'На доске пока нет задач',
    'Doskada hozircha vazifalar yo‘q',
    'There are no tasks on this board yet',
  ],
  'rp.make_pdf': ['PDF-отчёт', 'PDF hisobot', 'PDF report'],

  // Настройка отчёта.
  'rp.setup_title': ['Отчёт по доске', 'Doska hisoboti', 'Board report'],
  'rp.period': ['Период', 'Davr', 'Period'],
  'rp.period.week': ['Неделя', 'Hafta', 'Week'],
  'rp.period.month': ['Месяц', 'Oy', 'Month'],
  'rp.period.custom': ['Свой период', 'O‘z davrim', 'Custom'],
  'rp.period_range': ['{a} — {b}', '{a} — {b}', '{a} — {b}'],
  'rp.sections': ['Разделы', 'Bo‘limlar', 'Sections'],
  'rp.sec.summary': ['Итоги', 'Natijalar', 'Overview'],
  'rp.sec.columns': [
    'Задачи по колонкам',
    'Ustunlar bo‘yicha vazifalar',
    'Tasks by column',
  ],
  'rp.sec.members': [
    'Задачи по участникам',
    'Ishtirokchilar bo‘yicha vazifalar',
    'Tasks by member',
  ],
  'rp.sec.completed': [
    'Выполнено за период',
    'Davr ichida bajarilgan',
    'Completed in period',
  ],
  'rp.sec.overdue': ['Просроченные', 'Muddati o‘tganlar', 'Overdue'],
  'rp.sec.links': [
    'Статьи и гранты',
    'Maqolalar va grantlar',
    'Papers and grants',
  ],
  'rp.sec.focus': ['Время фокуса', 'Fokus vaqti', 'Focus time'],
  'rp.create': ['Создать отчёт', 'Hisobot yaratish', 'Create report'],
  'rp.need_section': [
    'Выберите хотя бы один раздел',
    'Kamida bitta bo‘limni tanlang',
    'Choose at least one section',
  ],
  'rp.building': [
    'Готовим отчёт…',
    'Hisobot tayyorlanmoqda…',
    'Preparing the report…',
  ],
  'rp.err': [
    'Не удалось создать отчёт. Попробуйте ещё раз.',
    'Hisobotni yaratib bo‘lmadi. Qayta urinib ko‘ring.',
    'Could not create the report. Please try again.',
  ],
  'rp.share': ['Поделиться', 'Ulashish', 'Share'],
  'rp.save': ['Сохранить', 'Saqlash', 'Save'],
  'rp.save_hint': [
    'В окне печати выберите «Сохранить как PDF»',
    'Chop etish oynasida «PDF sifatida saqlash»ni tanlang',
    'In the print window choose “Save as PDF”',
  ],

  // Тексты внутри PDF (без эмодзи).
  'rp.pdf.tagline': [
    'Открытая сеть учёных',
    'Olimlarning ochiq tarmog‘i',
    'Open network of scientists',
  ],
  'rp.pdf.kind': ['ОТЧЁТ ПО ДОСКЕ', 'DOSKA HISOBOTI', 'BOARD REPORT'],
  'rp.pdf.period': ['Период', 'Davr', 'Period'],
  'rp.pdf.members': ['Участники', 'Ishtirokchilar', 'Members'],
  'rp.pdf.generated': ['Дата отчёта', 'Hisobot sanasi', 'Report date'],
  'rp.pdf.made_in': [
    'Создано в приложении Scinode',
    'Scinode ilovasida yaratilgan',
    'Created with the Scinode app',
  ],
  'rp.pdf.page': ['Стр. {p} из {n}', '{p}-sahifa, jami {n}', 'Page {p} of {n}'],
  'rp.pdf.progress': ['Выполнение', 'Bajarilish', 'Completion'],
  'rp.pdf.in_period': [
    'За период выполнено: {d} · новых задач: {c}',
    'Davr ichida bajarildi: {d} · yangi vazifalar: {c}',
    'Completed in period: {d} · new tasks: {c}',
  ],
  'rp.pdf.task': ['Задача', 'Vazifa', 'Task'],
  'rp.pdf.due': ['Срок', 'Muddat', 'Due'],
  'rp.pdf.assignees': ['Исполнители', 'Ijrochilar', 'Assignees'],
  'rp.pdf.priority': ['Приоритет', 'Muhimlik', 'Priority'],
  'rp.pdf.member': ['Участник', 'Ishtirokchi', 'Member'],
  'rp.pdf.in_period_col': ['За период', 'Davr ichida', 'In period'],
  'rp.pdf.focus': ['Фокус', 'Fokus', 'Focus'],
  'rp.pdf.done_at': ['Выполнено', 'Bajarilgan sana', 'Completed'],
  'rp.pdf.late_by': [
    'Просрочено на',
    'Kechikish',
    'Overdue by',
  ],
  'rp.pdf.days': ['{n} дн.', '{n} kun', '{n} d'],
  'rp.pdf.cards': ['Задачи', 'Vazifalar', 'Tasks'],
  'rp.pdf.papers': ['Статьи', 'Maqolalar', 'Papers'],
  'rp.pdf.grants': ['Гранты', 'Grantlar', 'Grants'],
  'rp.pdf.deadline': ['Дедлайн', 'Muddat', 'Deadline'],
  'rp.pdf.number': ['Номер', 'Raqam', 'Number'],
  'rp.pdf.none': ['Нет данных', 'Ma’lumot yo‘q', 'No data'],
  'rp.pdf.no_tasks': ['Задач нет', 'Vazifalar yo‘q', 'No tasks'],
  'rp.pdf.focus_total': [
    'Всего времени фокуса: {t}',
    'Jami fokus vaqti: {t}',
    'Total focus time: {t}',
  ],
  'rp.pdf.focus_note': [
    'Время фокуса считается за всё время работы с доской.',
    'Fokus vaqti doska bilan ishlashning butun davri uchun hisoblanadi.',
    'Focus time is counted for the whole life of the board.',
  ],
  'rp.pdf.file': ['Отчёт', 'Hisobot', 'Report'],

  // Таймер фокуса.
  'fo.start': ['Фокус 25 мин', 'Fokus 25 daq', 'Focus 25 min'],
  'fo.section': ['Время фокуса', 'Fokus vaqti', 'Focus time'],
  'fo.total': [
    'Всего: {t} · моё: {m}',
    'Jami: {t} · meniki: {m}',
    'Total: {t} · mine: {m}',
  ],
  'fo.none': [
    'Пока не засекали. Таймер: 25 минут работы, 5 минут отдыха.',
    'Hali o‘lchanmagan. Taymer: 25 daqiqa ish, 5 daqiqa dam.',
    'Not tracked yet. Timer: 25 minutes of work, 5 minutes of rest.',
  ],
  'fo.work': ['Работаем', 'Ishlaymiz', 'Focus'],
  'fo.break': ['Перерыв', 'Tanaffus', 'Break'],
  'fo.pause': ['Пауза', 'Pauza', 'Pause'],
  'fo.resume': ['Продолжить', 'Davom etish', 'Resume'],
  'fo.stop': ['Стоп', 'To‘xtatish', 'Stop'],
  'fo.saved': [
    'Записано за сеанс: {t}',
    'Seansda yozildi: {t}',
    'Logged this session: {t}',
  ],
  'fo.min': ['{m} мин', '{m} daq', '{m} min'],
  'fo.hmin': ['{h} ч {m} мин', '{h} soat {m} daq', '{h} h {m} min'],

  // Мотивация.
  'mo.done': ['Готово! 🎉', 'Bajarildi! 🎉', 'Done! 🎉'],
  'mo.done_streak': [
    'Готово! 🔥 {n} дн. подряд',
    'Bajarildi! 🔥 {n} kun ketma-ket',
    'Done! 🔥 {n} days in a row',
  ],
  'mo.checklist': [
    'Чек-лист закрыт! ✅',
    'Ro‘yxat yakunlandi! ✅',
    'Checklist complete! ✅',
  ],
  'mo.goal_reached': [
    'Цель недели выполнена: {n} задач! 🏆',
    'Hafta maqsadi bajarildi: {n} ta vazifa! 🏆',
    'Weekly goal reached: {n} tasks! 🏆',
  ],
  'mo.streak': [
    '🔥 {n} дн. подряд вы двигаете задачи',
    '🔥 {n} kun ketma-ket vazifalarni oldinga surmoqdasiz',
    '🔥 {n} days in a row moving tasks forward',
  ],
  'mo.streak_start': [
    'Сдвиньте задачу сегодня, чтобы начать серию',
    'Seriyani boshlash uchun bugun vazifani suring',
    'Move a task today to start a streak',
  ],
  'mo.goal': [
    'Цель недели: {d} из {n}',
    'Hafta maqsadi: {d} / {n}',
    'Weekly goal: {d} of {n}',
  ],
  'mo.goal_title': ['Цель на неделю', 'Haftalik maqsad', 'Weekly goal'],
  'mo.goal_text': [
    'Сколько задач перенести в «Готово» за неделю (с понедельника)?',
    'Haftada (dushanbadan) nechta vazifani «Bajarildi»ga o‘tkazish kerak?',
    'How many tasks to move to “Done” per week (from Monday)?',
  ],
  'mo.goal_n': ['{n} задач', '{n} ta vazifa', '{n} tasks'],
};
