// Тексты канбан-досок. Порядок: русский, узбекский, английский.
const Map<String, List<String>> boardStrings = {
  // Главная и список досок.
  'bd.tile': ['Мои проекты', 'Loyihalarim', 'My projects'],
  'bd.tile_sub': [
    'Доски задач для статей, грантов и диссертации',
    'Maqola, grant va dissertatsiya uchun vazifa doskalari',
    'Task boards for papers, grants and theses',
  ],
  'bd.title': ['Мои проекты', 'Loyihalarim', 'My projects'],
  'bd.new': ['Новая доска', 'Yangi doska', 'New board'],
  'bd.empty_title': [
    'Пока нет досок',
    'Hozircha doskalar yo‘q',
    'No boards yet',
  ],
  'bd.empty_text': [
    'Создайте доску по шаблону: статья, заявка на грант, диссертация или работа группы.',
    'Shablon bo‘yicha doska yarating: maqola, grant arizasi, dissertatsiya yoki guruh ishi.',
    'Create a board from a template: paper, grant application, thesis or team work.',
  ],
  'bd.archive': ['Архив', 'Arxiv', 'Archive'],
  'bd.archived': ['В архиве', 'Arxivda', 'Archived'],
  'bd.shared': ['Общая', 'Umumiy', 'Shared'],
  'bd.progress': ['Готово {p}%', 'Bajarildi {p}%', '{p}% done'],
  'bd.tasks_count': ['Задач: {n}', 'Vazifalar: {n}', 'Tasks: {n}'],
  'bd.my_tasks': ['Мои задачи', 'Vazifalarim', 'My tasks'],
  'bd.today_banner': [
    'Сегодня: {t} · просрочено: {o}',
    'Bugun: {t} · muddati o‘tgan: {o}',
    'Today: {t} · overdue: {o}',
  ],
  'bd.today_none': [
    'На сегодня задач нет',
    'Bugunga vazifa yo‘q',
    'No tasks for today',
  ],
  // Создание доски.
  'bd.choose_template': [
    'Выберите шаблон',
    'Shablonni tanlang',
    'Choose a template'
  ],
  'bd.name': ['Название доски', 'Doska nomi', 'Board name'],
  'bd.name_required': ['Введите название', 'Nomini kiriting', 'Enter a name'],
  'bd.create': ['Создать', 'Yaratish', 'Create'],
  'bd.color': ['Цвет', 'Rang', 'Colour'],
  'bd.icon': ['Значок', 'Belgi', 'Icon'],
  'bt.paper': ['Статья в журнал', 'Jurnalga maqola', 'Journal paper'],
  'bt.paper_sub': [
    'От идеи до публикации',
    'G‘oyadan nashrgacha',
    'From idea to publication',
  ],
  'bt.grant': ['Заявка на грант', 'Grant arizasi', 'Grant application'],
  'bt.grant_sub': [
    'Документы, бюджет, проверка, подача',
    'Hujjatlar, byudjet, tekshiruv, topshirish',
    'Documents, budget, review, submission',
  ],
  'bt.thesis': ['Диссертация', 'Dissertatsiya', 'Thesis'],
  'bt.thesis_sub': [
    'Главы и этапы до защиты',
    'Boblar va himoyagacha bosqichlar',
    'Chapters and stages up to the defence',
  ],
  'bt.lab': ['Научная группа', 'Ilmiy guruh', 'Research team'],
  'bt.lab_sub': [
    'Общие задачи лаборатории',
    'Laboratoriyaning umumiy vazifalari',
    'Shared tasks of a lab',
  ],
  'bt.empty': ['Пустая доска', 'Bo‘sh doska', 'Blank board'],
  'bt.empty_sub': [
    'Три простые колонки',
    'Uchta oddiy ustun',
    'Three simple columns',
  ],
  // Колонки шаблонов.
  'bt.col.ideas': ['Идеи', 'G‘oyalar', 'Ideas'],
  'bt.col.lit': ['Обзор литературы', 'Adabiyotlar sharhi', 'Literature review'],
  'bt.col.experiment': ['Эксперимент', 'Tajriba', 'Experiment'],
  'bt.col.draft': ['Черновик', 'Qoralama', 'Draft'],
  'bt.col.review': ['Рецензия', 'Taqriz', 'Peer review'],
  'bt.col.published': ['Опубликовано', 'Nashr etildi', 'Published'],
  'bt.col.prepare': ['Подготовка', 'Tayyorgarlik', 'Preparation'],
  'bt.col.documents': ['Документы', 'Hujjatlar', 'Documents'],
  'bt.col.budget': ['Бюджет', 'Byudjet', 'Budget'],
  'bt.col.check': ['На проверке', 'Tekshiruvda', 'In review'],
  'bt.col.submitted': ['Подано', 'Topshirildi', 'Submitted'],
  'bt.col.method': ['Методика', 'Metodika', 'Methods'],
  'bt.col.results': ['Результаты', 'Natijalar', 'Results'],
  'bt.col.abstract': ['Автореферат', 'Avtoreferat', 'Summary'],
  'bt.col.defense': ['Защита', 'Himoya', 'Defence'],
  'bt.col.work': ['В работе', 'Jarayonda', 'In progress'],
  'bt.col.done': ['Готово', 'Bajarildi', 'Done'],
  'bt.col.todo': ['Сделать', 'Bajarish kerak', 'To do'],
  // Стартовые карточки шаблонов.
  'bt.card.paper_topic': [
    'Сформулировать тему и гипотезу',
    'Mavzu va gipotezani shakllantirish',
    'Define the topic and hypothesis',
  ],
  'bt.card.paper_lit': [
    'Собрать 10–20 ключевых статей в библиотеку',
    'Kutubxonaga 10–20 ta asosiy maqola to‘plash',
    'Collect 10–20 key papers in the library',
  ],
  'bt.card.paper_journal': [
    'Выбрать журнал и прочитать требования к авторам',
    'Jurnal tanlash va mualliflarga talablarni o‘qish',
    'Choose a journal and read the author guidelines',
  ],
  'bt.card.grant_eligibility': [
    'Проверить условия участия (eligibility)',
    'Ishtirok shartlarini (eligibility) tekshirish',
    'Check eligibility rules',
  ],
  'bt.card.grant_team': [
    'Собрать команду и распределить роли',
    'Jamoa yig‘ish va rollarni taqsimlash',
    'Build the team and assign roles',
  ],
  'bt.card.grant_letters': [
    'Письма поддержки от партнёров',
    'Hamkorlardan qo‘llab-quvvatlash xatlari',
    'Letters of support from partners',
  ],
  'bt.card.grant_narrative': [
    'Описание проекта: цели, методы, результаты',
    'Loyiha tavsifi: maqsadlar, usullar, natijalar',
    'Project description: aims, methods, outcomes',
  ],
  'bt.card.grant_budget': [
    'Рассчитать бюджет и обоснование',
    'Byudjet va asoslashni hisoblash',
    'Prepare the budget and justification',
  ],
  'bt.card.grant_final': [
    'Финальная проверка и подача',
    'Yakuniy tekshiruv va topshirish',
    'Final check and submission',
  ],
  'bt.card.thesis_plan': [
    'Согласовать план с научным руководителем',
    'Rejani ilmiy rahbar bilan kelishish',
    'Agree the plan with the supervisor',
  ],
  'bt.card.thesis_review': [
    'Обзор литературы по теме',
    'Mavzu bo‘yicha adabiyotlar sharhi',
    'Literature review on the topic',
  ],
  'bt.card.thesis_method': [
    'Описать методику исследования',
    'Tadqiqot metodikasini yozish',
    'Describe the research methods',
  ],
  // Доска.
  'bd.add_card': ['Добавить задачу', 'Vazifa qo‘shish', 'Add task'],
  'bd.card_title_hint': [
    'Что нужно сделать?',
    'Nima qilish kerak?',
    'What needs to be done?'
  ],
  'bd.col_empty': [
    'Перетащите сюда задачу или добавьте новую',
    'Vazifani bu yerga torting yoki yangisini qo‘shing',
    'Drag a task here or add a new one',
  ],
  'bd.limit': ['{n} из {max}', '{n} / {max}', '{n} of {max}'],
  'bd.limit_warn': [
    'В колонке «{col}» больше задач, чем лимит ({max})',
    '«{col}» ustunida vazifalar limitdan ({max}) ko‘p',
    'Column “{col}” is over its limit ({max})',
  ],
  'bd.move_to': ['Переместить в…', 'Ko‘chirish…', 'Move to…'],
  'bd.moved': [
    'Перемещено в «{col}»',
    '«{col}» ga ko‘chirildi',
    'Moved to “{col}”'
  ],
  'bd.swipe_next': ['В «{col}»', '«{col}» ga', 'To “{col}”'],
  'bd.read_only': [
    'Вы наблюдатель: можно только смотреть',
    'Siz kuzatuvchisiz: faqat ko‘rish mumkin',
    'You are a viewer: read-only',
  ],
  'bd.filter': ['Фильтры', 'Filtrlar', 'Filters'],
  'bd.filter_reset': ['Сбросить', 'Tozalash', 'Reset'],
  'bd.search': ['Поиск по задачам', 'Vazifalardan qidirish', 'Search tasks'],
  'bd.f.assignee': ['Исполнитель', 'Ijrochi', 'Assignee'],
  'bd.f.anyone': ['Любой', 'Istalgan', 'Anyone'],
  'bd.f.me': ['Я', 'Men', 'Me'],
  'bd.f.nobody': ['Без исполнителя', 'Ijrochisiz', 'Unassigned'],
  'bd.f.label': ['Метка', 'Belgi', 'Label'],
  'bd.f.any_label': ['Любая', 'Istalgan', 'Any'],
  'bd.f.priority': ['Приоритет', 'Muhimlik', 'Priority'],
  'bd.f.any_priority': ['Любой', 'Istalgan', 'Any'],
  'bd.f.due': ['Срок', 'Muddat', 'Due'],
  'bd.f.due.any': ['Любой', 'Istalgan', 'Any'],
  'bd.f.due.overdue': ['Просрочено', 'Muddati o‘tgan', 'Overdue'],
  'bd.f.due.week': ['На этой неделе', 'Shu haftada', 'This week'],
  'bd.f.due.none': ['Без срока', 'Muddatsiz', 'No due date'],
  'bd.f.found': [
    'Показано задач: {n}',
    'Ko‘rsatilgan vazifalar: {n}',
    'Tasks shown: {n}',
  ],
  // Приоритеты.
  'bd.p.0': ['Низкий', 'Past', 'Low'],
  'bd.p.1': ['Средний', 'O‘rta', 'Medium'],
  'bd.p.2': ['Высокий', 'Yuqori', 'High'],
  'bd.p.3': ['Срочный', 'Shoshilinch', 'Urgent'],
  // Сроки.
  'bd.due.overdue': [
    'Просрочено на {n} дн.',
    '{n} kun kechikdi',
    '{n} d overdue',
  ],
  'bd.due.today': ['Сегодня', 'Bugun', 'Today'],
  'bd.due.tomorrow': ['Завтра', 'Ertaga', 'Tomorrow'],
  'bd.due.in': ['Через {n} дн.', '{n} kundan keyin', 'In {n} d'],
  // Карточка.
  'bd.card': ['Задача', 'Vazifa', 'Task'],
  'bd.c.title': ['Название', 'Nomi', 'Title'],
  'bd.c.desc': ['Описание', 'Tavsif', 'Description'],
  'bd.c.desc_hint': [
    'Подробности, ссылки, критерии готовности',
    'Tafsilotlar, havolalar, tayyorlik mezonlari',
    'Details, links, definition of done',
  ],
  'bd.c.column': ['Колонка', 'Ustun', 'Column'],
  'bd.c.due': ['Срок', 'Muddat', 'Due date'],
  'bd.c.no_due': ['Без срока', 'Muddatsiz', 'No due date'],
  'bd.c.set_due': ['Установить срок', 'Muddat belgilash', 'Set due date'],
  'bd.c.clear_due': ['Убрать срок', 'Muddatni olib tashlash', 'Clear due date'],
  'bd.c.priority': ['Приоритет', 'Muhimlik', 'Priority'],
  'bd.c.labels': ['Метки', 'Belgilar', 'Labels'],
  'bd.c.assignees': ['Исполнители', 'Ijrochilar', 'Assignees'],
  'bd.c.checklist': ['Чек-лист', 'Nazorat ro‘yxati', 'Checklist'],
  'bd.c.check_add': ['Добавить пункт', 'Band qo‘shish', 'Add item'],
  'bd.c.check_progress': ['{d} из {n}', '{d} / {n}', '{d} of {n}'],
  'bd.c.papers': [
    'Статьи из библиотеки',
    'Kutubxonadagi maqolalar',
    'Papers from library'
  ],
  'bd.c.add_paper': ['Прикрепить статью', 'Maqola biriktirish', 'Attach paper'],
  'bd.c.no_library': [
    'Библиотека пуста. Сохраните статьи из поиска.',
    'Kutubxona bo‘sh. Qidiruvdan maqolalarni saqlang.',
    'Your library is empty. Save papers from search.',
  ],
  'bd.c.grants': ['Гранты', 'Grantlar', 'Grants'],
  'bd.c.comments': ['Комментарии', 'Izohlar', 'Comments'],
  'bd.c.comment_hint': [
    'Написать комментарий',
    'Izoh yozish',
    'Write a comment'
  ],
  'bd.c.no_comments': [
    'Комментариев пока нет',
    'Hozircha izohlar yo‘q',
    'No comments yet'
  ],
  'bd.c.history': ['История', 'Tarix', 'History'],
  'bd.c.no_history': [
    'Изменений пока нет',
    'Hozircha o‘zgarishlar yo‘q',
    'No changes yet'
  ],
  'bd.c.delete': ['Удалить задачу', 'Vazifani o‘chirish', 'Delete task'],
  'bd.c.delete_q': [
    'Удалить задачу вместе с комментариями?',
    'Vazifa izohlari bilan birga o‘chirilsinmi?',
    'Delete this task with its comments?',
  ],
  'bd.c.write_to': [
    'Написать исполнителю',
    'Ijrochiga yozish',
    'Message assignee'
  ],
  'bd.c.save': ['Сохранить', 'Saqlash', 'Save'],
  'bd.c.reading': ['стр. {p} из {n}', '{p}/{n}-bet', 'p. {p} of {n}'],
  'bd.c.read_done': [
    'Статья дочитана. Отметить пункт чек-листа?',
    'Maqola o‘qib bo‘lindi. Nazorat bandini belgilaymizmi?',
    'Paper finished. Tick the checklist item?',
  ],
  // История.
  'bd.h.create': [
    '{who} создал(а) задачу',
    '{who} vazifa yaratdi',
    '{who} created the task'
  ],
  'bd.h.move': [
    '{who}: «{from}» → «{to}»',
    '{who}: «{from}» → «{to}»',
    '{who}: “{from}” → “{to}”'
  ],
  'bd.h.done': [
    '{who} завершил(а): «{to}»',
    '{who} yakunladi: «{to}»',
    '{who} completed: “{to}”'
  ],
  'bd.h.delete': [
    '{who} удалил(а) задачу',
    '{who} vazifani o‘chirdi',
    '{who} deleted the task'
  ],
  'bd.h.comment': [
    '{who} оставил(а) комментарий',
    '{who} izoh qoldirdi',
    '{who} commented'
  ],
  'bd.h.someone': ['Участник', 'Ishtirokchi', 'Member'],
  // Настройки доски.
  'bd.settings': ['Настройки доски', 'Doska sozlamalari', 'Board settings'],
  'bd.rename': ['Переименовать', 'Nomini o‘zgartirish', 'Rename'],
  'bd.columns': ['Колонки', 'Ustunlar', 'Columns'],
  'bd.col_add': ['Добавить колонку', 'Ustun qo‘shish', 'Add column'],
  'bd.col_name': ['Название колонки', 'Ustun nomi', 'Column name'],
  'bd.col_limit': [
    'Лимит задач (0 — без лимита)',
    'Vazifalar limiti (0 — cheklovsiz)',
    'Task limit (0 — no limit)',
  ],
  'bd.col_done': [
    'Колонка «Готово» (задачи считаются выполненными)',
    '«Bajarildi» ustuni (vazifalar bajarilgan hisoblanadi)',
    '“Done” column (tasks count as completed)',
  ],
  'bd.col_delete': ['Удалить колонку', 'Ustunni o‘chirish', 'Delete column'],
  'bd.col_delete_q': [
    'Удалить колонку «{col}»? Её задачи ({n}) будут перенесены в выбранную колонку.',
    '«{col}» ustuni o‘chirilsinmi? Uning vazifalari ({n}) tanlangan ustunga ko‘chiriladi.',
    'Delete column “{col}”? Its tasks ({n}) will be moved to the column you choose.',
  ],
  'bd.col_move_to': [
    'Перенести задачи в',
    'Vazifalarni ko‘chirish',
    'Move tasks to'
  ],
  'bd.col_last': [
    'Нельзя удалить последнюю колонку',
    'Oxirgi ustunni o‘chirib bo‘lmaydi',
    'You cannot delete the last column',
  ],
  'bd.col_max': [
    'Не больше 12 колонок',
    '12 tadan ko‘p ustun bo‘lmaydi',
    'No more than 12 columns',
  ],
  'bd.labels': ['Метки', 'Belgilar', 'Labels'],
  'bd.label_add': ['Добавить метку', 'Belgi qo‘shish', 'Add label'],
  'bd.label_name': ['Название метки', 'Belgi nomi', 'Label name'],
  'bd.members': ['Участники', 'Ishtirokchilar', 'Members'],
  'bd.invite': ['Пригласить', 'Taklif qilish', 'Invite'],
  'bd.invite_title': [
    'Пригласить в доску',
    'Doskaga taklif qilish',
    'Invite to board'
  ],
  'bd.invite_contacts': [
    'Из переписок',
    'Yozishmalardan',
    'From conversations'
  ],
  'bd.invite_search': [
    'Имя участника Scinode',
    'Scinode ishtirokchisi ismi',
    'Scinode member name',
  ],
  'bd.invite_none': [
    'Никого не найдено. Приглашать можно участников с опубликованным профилем.',
    'Hech kim topilmadi. Faqat profili e’lon qilingan ishtirokchilarni taklif qilish mumkin.',
    'Nobody found. You can invite members with a published profile.',
  ],
  'bd.invited': [
    '{name} добавлен(а) в доску',
    '{name} doskaga qo‘shildi',
    '{name} was added to the board'
  ],
  'bd.role.owner': ['Владелец', 'Egasi', 'Owner'],
  'bd.role.editor': ['Редактор', 'Muharrir', 'Editor'],
  'bd.role.viewer': ['Наблюдатель', 'Kuzatuvchi', 'Viewer'],
  'bd.role_change': ['Изменить роль', 'Rolni o‘zgartirish', 'Change role'],
  'bd.remove_member': [
    'Убрать из доски',
    'Doskadan chiqarish',
    'Remove from board'
  ],
  'bd.make_owner': ['Сделать владельцем', 'Egasi qilish', 'Make owner'],
  'bd.make_owner_q': [
    'Передать владение доской участнику {name}? Вы станете редактором.',
    'Doska egaligi {name}ga o‘tkazilsinmi? Siz muharrir bo‘lasiz.',
    'Transfer board ownership to {name}? You will become an editor.',
  ],
  'bd.leave': ['Покинуть доску', 'Doskadan chiqish', 'Leave board'],
  'bd.leave_q': [
    'Покинуть доску «{name}»? Вернуться можно только по приглашению.',
    '«{name}» doskasidan chiqilsinmi? Faqat taklif orqali qaytish mumkin.',
    'Leave “{name}”? You can only come back if invited again.',
  ],
  'bd.archive_do': ['В архив', 'Arxivga', 'Archive'],
  'bd.unarchive': [
    'Вернуть из архива',
    'Arxivdan qaytarish',
    'Restore from archive'
  ],
  'bd.delete': ['Удалить доску', 'Doskani o‘chirish', 'Delete board'],
  'bd.delete_q': [
    'Удалить доску «{name}» со всеми задачами, комментариями и историей? Это нельзя отменить.',
    '«{name}» doskasi barcha vazifalar, izohlar va tarix bilan o‘chirilsinmi? Buni bekor qilib bo‘lmaydi.',
    'Delete “{name}” with all tasks, comments and history? This cannot be undone.',
  ],
  'bd.deleted': ['Доска удалена', 'Doska o‘chirildi', 'Board deleted'],
  'bd.cancel': ['Отмена', 'Bekor qilish', 'Cancel'],
  'bd.ok': ['Готово', 'Tayyor', 'Done'],
  'bd.delete_do': ['Удалить', 'O‘chirish', 'Delete'],
  'bd.history': ['История доски', 'Doska tarixi', 'Board history'],
  // Связь с грантами.
  'bd.grant_prepare': [
    'Готовить заявку',
    'Arizani tayyorlash',
    'Prepare application'
  ],
  'bd.grant_add': ['Добавить в проект', 'Loyihaga qo‘shish', 'Add to project'],
  'bd.grant_board_name': [
    'Заявка: {title}',
    'Ariza: {title}',
    'Application: {title}'
  ],
  'bd.grant_card': [
    'Подать заявку: {title}',
    'Ariza topshirish: {title}',
    'Submit: {title}'
  ],
  'bd.grant_m30': [
    'Контрольная точка: за 30 дней до дедлайна',
    'Nazorat nuqtasi: muddatdan 30 kun oldin',
    'Checkpoint: 30 days before the deadline',
  ],
  'bd.grant_m14': [
    'Контрольная точка: за 14 дней — черновик готов',
    'Nazorat nuqtasi: 14 kun oldin — qoralama tayyor',
    'Checkpoint: 14 days before — draft ready',
  ],
  'bd.grant_m7': [
    'Контрольная точка: за 7 дней — финальная проверка',
    'Nazorat nuqtasi: 7 kun oldin — yakuniy tekshiruv',
    'Checkpoint: 7 days before — final check',
  ],
  'bd.grant_created': [
    'Доска заявки создана',
    'Ariza doskasi yaratildi',
    'Application board created',
  ],
  'bd.choose_board': ['Выберите доску', 'Doskani tanlang', 'Choose a board'],
  'bd.added_to': [
    'Добавлено в «{name}»',
    '«{name}» ga qo‘shildi',
    'Added to “{name}”'
  ],
  'bd.no_boards': [
    'Сначала создайте доску в «Мои проекты»',
    'Avval «Loyihalarim» bo‘limida doska yarating',
    'First create a board in “My projects”',
  ],
  // Мои задачи.
  'bd.g.overdue': ['Просрочено', 'Muddati o‘tgan', 'Overdue'],
  'bd.g.today': ['Сегодня', 'Bugun', 'Today'],
  'bd.g.week': ['На этой неделе', 'Shu haftada', 'This week'],
  'bd.g.later': ['Позже', 'Keyinroq', 'Later'],
  'bd.g.noDate': ['Без срока', 'Muddatsiz', 'No due date'],
  'bd.my_empty': [
    'Нет задач. Назначьте себя исполнителем или создайте личную доску.',
    'Vazifalar yo‘q. O‘zingizni ijrochi qiling yoki shaxsiy doska yarating.',
    'No tasks. Assign yourself or create a personal board.',
  ],
  // Ошибки.
  'bd.err.rules': [
    'Нет прав на это действие. Проверьте роль в доске и правила Firestore.',
    'Bu amal uchun ruxsat yo‘q. Doskadagi rolingiz va Firestore qoidalarini tekshiring.',
    'You are not allowed to do this. Check your board role and Firestore rules.',
  ],
  'bd.err.network': [
    'Нет связи. Изменения сохранятся на телефоне и отправятся позже.',
    'Aloqa yo‘q. O‘zgarishlar telefonda saqlanadi va keyinroq yuboriladi.',
    'No connection. Changes are saved on the phone and will sync later.',
  ],
  'bd.err.limit': [
    'Достигнут лимит (не больше 20 участников)',
    'Limitga yetildi (20 tadan ko‘p ishtirokchi bo‘lmaydi)',
    'Limit reached (no more than 20 members)',
  ],
  'bd.err.other': [
    'Что-то пошло не так. Повторите попытку.',
    'Nimadir xato ketdi. Qayta urinib ko‘ring.',
    'Something went wrong. Please try again.',
  ],
  'bd.err.load': [
    'Не удалось загрузить доски.',
    'Doskalarni yuklab bo‘lmadi.',
    'Could not load boards.',
  ],
  'bd.not_ready': [
    'Доски доступны после входа в аккаунт.',
    'Doskalar hisobga kirgandan so‘ng mavjud.',
    'Boards are available after you sign in.',
  ],
  'bd.unknown_user': ['Участник', 'Ishtirokchi', 'Member'],
  // Удаление данных.
  'bd.del_choice': [
    'Вы владелец общей доски «{name}». Что с ней сделать?',
    'Siz «{name}» umumiy doskasining egasisiz. U bilan nima qilamiz?',
    'You own the shared board “{name}”. What should happen to it?',
  ],
  'bd.del_transfer': [
    'Передать участнику',
    'Ishtirokchiga o‘tkazish',
    'Transfer to a member'
  ],
  'bd.del_remove': ['Удалить доску', 'Doskani o‘chirish', 'Delete board'],
};
