#!/usr/bin/env python3
"""Patch LifeLogger project for English UI localization (App Store 2.1a)."""
from __future__ import annotations

import re
from pathlib import Path

PROJ = Path("/Users/taehyeonkim/Desktop/project/life loging")
LANGS = ["en", "zh-Hans", "ko", "es", "hi", "ar", "pt", "ru", "de"]


def entry(key: str, values: dict[str, str]) -> str:
    lines = [f'        "{key}": [']
    for i, lang in enumerate(LANGS):
        v = values.get(lang, values["en"]).replace("\\", "\\\\").replace('"', '\\"')
        comma = "," if i < len(LANGS) - 1 else ""
        lines.append(f'            "{lang}": "{v}"{comma}')
    lines.append("        ],")
    return "\n".join(lines)


def add(store: dict, key: str, **kwargs: str) -> None:
    mapped: dict[str, str] = {}
    for k, v in kwargs.items():
        mapped["zh-Hans" if k == "zhHans" else k] = v
    store[key] = mapped


def build_keys() -> dict[str, dict[str, str]]:
    n: dict[str, dict[str, str]] = {}

    def a(key: str, **kw: str) -> None:
        add(n, key, **kw)

    a("chart.collecting", en="Collecting data…", zhHans="正在收集数据…", ko="데이터 수집 중...", es="Recopilando datos…", hi="डेटा एकत्रित हो रहा है…", ar="جارٍ جمع البيانات…", pt="Coletando dados…", ru="Сбор данных…", de="Daten werden erfasst…")
    a("chart.axis.time", en="Time", zhHans="时间", ko="시간", es="Tiempo", hi="समय", ar="الوقت", pt="Tempo", ru="Время", de="Zeit")
    a("chart.axis.category", en="Category", zhHans="类别", ko="카테고리", es="Categoría", hi="श्रेणी", ar="الفئة", pt="Categoria", ru="Категория", de="Kategorie")
    a("chart.axis.weekday", en="Day", zhHans="星期", ko="요일", es="Día", hi="दिन", ar="اليوم", pt="Dia", ru="День", de="Tag")
    a("chart.axis.focusRatio", en="Focus rate", zhHans="专注率", ko="집중률", es="Tasa de enfoque", hi="फ़ोकस दर", ar="معدل التركيز", pt="Taxa de foco", ru="Доля фокуса", de="Fokusrate")
    a("chart.axis.hour", en="Hour", zhHans="小时", ko="시", es="Hora", hi="घंटा", ar="ساعة", pt="Hora", ru="Час", de="Stunde")
    a("report.subtitle", en="A look back at your last 7 days of focus", zhHans="回顾近 7 天的专注节奏", ko="최근 7일 몰입 흐름 회고", es="Repaso de tus últimos 7 días de enfoque", hi="पिछले 7 दिनों की फ़ोकस समीक्षा", ar="مراجعة تركيزك خلال آخر 7 أيام", pt="Retrospectiva dos últimos 7 dias de foco", ru="Обзор фокуса за последние 7 дней", de="Rückblick auf deine Fokus-Woche")
    a("report.weekFocus", en="Weekly focus", zhHans="本周专注", ko="주간 집중", es="Enfoque semanal", hi="साप्ताहिक फ़ोकस", ar="تركيز الأسبوع", pt="Foco semanal", ru="Фокус за неделю", de="Wochenfokus")
    a("report.avgFocus", en="Avg focus rate", zhHans="平均专注率", ko="평균 집중률", es="Tasa media", hi="औसत फ़ोकस", ar="متوسط التركيز", pt="Taxa média", ru="Средний фокус", de="Ø Fokusrate")
    a("report.bestDay", en="Best day", zhHans="最佳日", ko="최고의 날", es="Mejor día", hi="सर्वश्रेष्ठ दिन", ar="أفضل يوم", pt="Melhor dia", ru="Лучший день", de="Bester Tag")
    a("report.dailyFocus", en="Daily focus rate", zhHans="每日专注率", ko="일별 집중률", es="Enfoque diario", hi="दैनिक फ़ोकस दर", ar="معدل التركيز اليومي", pt="Foco diário", ru="Фокус по дням", de="Tägliche Fokusrate")
    a("report.goldenTime", en="Golden focus time", zhHans="黄金专注时段", ko="몰입 골든타임", es="Hora dorada", hi="स्वर्णिम फ़ोकस समय", ar="وقت التركيز الذهبي", pt="Horário de ouro", ru="Золотое время", de="Goldene Fokuszeit")
    a("report.goldenAround", en="%@ around %d:00", zhHans="%@ 约 %d 点", ko="%@ %d시 전후", es="%@ alrededor de las %d:00", hi="%@ लगभग %d:00", ar="%@ حوالي الساعة %d:00", pt="%@ por volta das %d:00", ru="%@ около %d:00", de="%@ gegen %d:00")
    a("report.goldenDetail", en="Your focus success rate peaks at %d%% in this window.", zhHans="该时段专注成功率最高，达 %d%%。", ko="이 시간대 집중 성공률이 %d%%로 가장 높아요.", es="Tu tasa de éxito de enfoque llega al %d%% en esta franja.", hi="इस समय आपकी फ़ोकस सफलता %d%% पर चरम है।", ar="يبلغ معدل نجاح تركيزك ذروته عند %d%% في هذه الفترة.", pt="Sua taxa de sucesso de foco chega a %d%% nesse horário.", ru="Успешность фокуса здесь достигает %d%%.", de="Deine Fokus-Erfolgsrate liegt hier bei %d%%.")
    a("report.weekJournal", en="This week's journal", zhHans="本周回顾", ko="이번 주 회고", es="Diario de la semana", hi="इस सप्ताह की डायरी", ar="مفكرة هذا الأسبوع", pt="Diário da semana", ru="Дневник недели", de="Wochenjournal")
    a("report.weekJournalEmpty", en="No journal entries this week.", zhHans="本周还没有写下回顾。", ko="이번 주 작성한 회고가 없습니다.", es="No hay entradas esta semana.", hi="इस सप्ताह कोई प्रविष्टि नहीं।", ar="لا توجد إدخالات هذا الأسبوع.", pt="Nenhuma entrada nesta semana.", ru="На этой неделе записей нет.", de="Keine Journaleinträge diese Woche.")
    a("report.weekdaySuffix", en="", zhHans="", ko="요일", es="", hi="", ar="", pt="", ru="", de="")
    a("heatmap.title", en="Focus heatmap", zhHans="专注热图", ko="집중 히트맵", es="Mapa de calor", hi="फ़ोकस हीटमैप", ar="خريطة التركيز", pt="Mapa de calor", ru="Теплокарта фокуса", de="Fokus-Heatmap")
    a("heatmap.viewAll", en="View all", zhHans="查看全部", ko="전체 보기", es="Ver todo", hi="सभी देखें", ar="عرض الكل", pt="Ver tudo", ru="Показать все", de="Alle anzeigen")
    a("heatmap.tooltip", en="%@\nFocus %@ · %d%%", zhHans="%@\n专注 %@ · %d%%", ko="%@\n집중 %@ · %d%%", es="%@\nEnfoque %@ · %d%%", hi="%@\nफ़ोकस %@ · %d%%", ar="%@\nالتركيز %@ · %d%%", pt="%@\nFoco %@ · %d%%", ru="%@\nФокус %@ · %d%%", de="%@\nFokus %@ · %d%%")
    a("deepwork.title", en="Deep work sessions", zhHans="深度工作时段", ko="딥워크 세션", es="Sesiones de deep work", hi="डीप वर्क सत्र", ar="جلسات العمل العميق", pt="Sessões de deep work", ru="Сессии глубокой работы", de="Deep-Work-Sitzungen")
    a("deepwork.summary", en="Today %d · longest %@ · total %@", zhHans="今天 %d 次 · 最长 %@ · 共 %@", ko="오늘 %d회 · 최장 %@ · 총 %@", es="Hoy %d · más larga %@ · total %@", hi="आज %d · सबसे लंबा %@ · कुल %@", ar="اليوم %d · الأطول %@ · الإجمالي %@", pt="Hoje %d · mais longa %@ · total %@", ru="Сегодня %d · макс. %@ · всего %@", de="Heute %d · längste %@ · gesamt %@")
    a("deepwork.empty", en="No uninterrupted 25+ minute focus blocks yet.", zhHans="还没有超过 25 分钟的连续专注块。", ko="25분 이상 끊김 없는 집중 블록이 없어요.", es="Aún no hay bloques de enfoque de 25+ minutos.", hi="अभी तक 25+ मिनट का निरंतर फ़ोकस ब्लॉक नहीं।", ar="لا توجد بعد كتل تركيز متواصلة لأكثر من 25 دقيقة.", pt="Ainda não há blocos de foco de 25+ minutos.", ru="Пока нет непрерывных блоков фокуса 25+ мин.", de="Noch keine ununterbrochenen 25+-Minuten-Blöcke.")
    a("depth.title", en="Focus depth", zhHans="专注深度", ko="집중 깊이", es="Profundidad de enfoque", hi="फ़ोकस गहराई", ar="عمق التركيز", pt="Profundidade de foco", ru="Глубина фокуса", de="Fokustiefe")
    a("depth.switches", en="Avg %.1f app switches per hour", zhHans="平均每小时切换应用 %.1f 次", ko="시간당 평균 %.1f회 앱 전환", es="Media de %.1f cambios de app por hora", hi="प्रति घंटा औसतन %.1f ऐप स्विच", ar="متوسط %.1f تبديل تطبيق في الساعة", pt="Média de %.1f trocas de app por hora", ru="В среднем %.1f переключений приложений/час", de="Ø %.1f App-Wechsel pro Stunde")
    a("weekCompare.title", en="This week vs last week", zhHans="本周 vs 上周", ko="이번 주 vs 지난 주", es="Esta semana vs la anterior", hi="इस सप्ताह बनाम पिछला", ar="هذا الأسبوع مقابل السابق", pt="Esta semana vs anterior", ru="Эта неделя vs прошлая", de="Diese Woche vs. letzte")
    a("weekCompare.delta", en="Focus rate %+.0f pp", zhHans="专注率 %+.0f 百分点", ko="집중률 %+.0f%%p", es="Tasa de enfoque %+.0f pp", hi="फ़ोकस दर %+.0f pp", ar="معدل التركيز %+.0f نقطة", pt="Taxa de foco %+.0f pp", ru="Фокус %+.0f п.п.", de="Fokusrate %+.0f Pp")
    a("hourly.title", en="Today's hourly focus", zhHans="今日分时专注", ko="오늘 시간대별 집중", es="Enfoque por hora hoy", hi="आज का घंटेवार फ़ोकस", ar="التركيز حسب الساعة اليوم", pt="Foco por hora hoje", ru="Фокус по часам сегодня", de="Heutiger Stundenfokus")
    a("project.title", en="Time by project", zhHans="按项目时间", ko="프로젝트별 시간", es="Tiempo por proyecto", hi="प्रोजेक्ट के अनुसार समय", ar="الوقت حسب المشروع", pt="Tempo por projeto", ru="Время по проектам", de="Zeit nach Projekt")
    a("project.range", en="Range", zhHans="范围", ko="기간", es="Rango", hi="अवधि", ar="المدى", pt="Período", ru="Период", de="Zeitraum")
    a("project.today", en="Today", zhHans="今天", ko="오늘", es="Hoy", hi="आज", ar="اليوم", pt="Hoje", ru="Сегодня", de="Heute")
    a("project.7d", en="7 days", zhHans="7 天", ko="7일", es="7 días", hi="7 दिन", ar="7 أيام", pt="7 dias", ru="7 дней", de="7 Tage")
    a("project.30d", en="30 days", zhHans="30 天", ko="30일", es="30 días", hi="30 दिन", ar="30 يومًا", pt="30 dias", ru="30 дней", de="30 Tage")
    a("project.empty", en="Add tags to segments to group time by project.", zhHans="给片段添加标签即可按项目汇总。", ko="세그먼트에 태그를 추가하면 프로젝트별로 모아요.", es="Añade etiquetas a los segmentos para agrupar por proyecto.", hi="प्रोजेक्ट के अनुसार समूह के लिए टैग जोड़ें।", ar="أضف وسومًا للمقاطع للتجميع حسب المشروع.", pt="Adicione tags aos segmentos para agrupar por projeto.", ru="Добавьте теги сегментам, чтобы группировать по проектам.", de="Tags an Segmente hängen, um nach Projekt zu gruppieren.")
    a("journal.title", en="Today's journal", zhHans="今日回顾", ko="오늘의 회고", es="Diario de hoy", hi="आज की डायरी", ar="مفكرة اليوم", pt="Diário de hoje", ru="Дневник за сегодня", de="Heutiges Journal")
    a("journal.placeholder", en="Leave a one-line reflection", zhHans="写下一句今日回顾", ko="한 줄 회고를 남겨보세요", es="Deja una reflexión de una línea", hi="एक पंक्ति का चिंतन लिखें", ar="اترك تأملاً في سطر واحد", pt="Deixe uma reflexão de uma linha", ru="Оставьте короткую заметку", de="Hinterlasse eine einzeilige Reflexion")
    a("summary.title", en="LifeLogger · Today's summary", zhHans="LifeLogger · 今日摘要", ko="LifeLogger · 오늘 요약", es="LifeLogger · Resumen de hoy", hi="LifeLogger · आज का सारांश", ar="LifeLogger · ملخص اليوم", pt="LifeLogger · Resumo de hoje", ru="LifeLogger · Сводка за сегодня", de="LifeLogger · Heutige Zusammenfassung")
    a("summary.focusPercent", en="%d%% focus", zhHans="%d%% 专注", ko="%d%% 집중", es="%d%% enfoque", hi="%d%% फ़ोकस", ar="%d%% تركيز", pt="%d%% foco", ru="%d%% фокус", de="%d%% Fokus")
    a("summary.detail", en="%@ focus · deep work %d · depth %d", zhHans="%@ 专注 · 深度工作 %d · 深度 %d", ko="%@ 집중 · 딥워크 %d회 · 깊이 %d", es="%@ enfoque · deep work %d · profundidad %d", hi="%@ फ़ोकस · डीप वर्क %d · गहराई %d", ar="%@ تركيز · عمل عميق %d · عمق %d", pt="%@ foco · deep work %d · profundidade %d", ru="%@ фокус · deep work %d · глубина %d", de="%@ Fokus · Deep Work %d · Tiefe %d")
    a("summary.renderFailed", en="Couldn't create image", zhHans="无法生成图片", ko="이미지 생성 실패", es="No se pudo crear la imagen", hi="छवि नहीं बन सकी", ar="تعذر إنشاء الصورة", pt="Não foi possível criar a imagem", ru="Не удалось создать изображение", de="Bild konnte nicht erstellt werden")
    a("summary.copied", en="Copied to clipboard.", zhHans="已复制到剪贴板。", ko="클립보드에 복사했습니다.", es="Copiado al portapapeles.", hi="क्लिपबोर्ड पर कॉपी किया।", ar="تم النسخ إلى الحافظة.", pt="Copiado para a área de transferência.", ru="Скопировано в буфер.", de="In die Zwischenablage kopiert.")
    a("summary.saveTitle", en="Save summary card", zhHans="保存摘要卡片", ko="요약 카드 저장", es="Guardar tarjeta de resumen", hi="सारांश कार्ड सहेजें", ar="حفظ بطاقة الملخص", pt="Salvar cartão de resumo", ru="Сохранить карточку сводки", de="Zusammenfassungskarte speichern")
    a("summary.pngFailed", en="PNG conversion failed", zhHans="PNG 转换失败", ko="PNG 변환 실패", es="Error al convertir a PNG", hi="PNG रूपांतरण विफल", ar="فشل تحويل PNG", pt="Falha na conversão PNG", ru="Ошибка преобразования PNG", de="PNG-Konvertierung fehlgeschlagen")
    a("summary.saved", en="Saved: %@", zhHans="已保存：%@", ko="저장 완료: %@", es="Guardado: %@", hi="सहेजा गया: %@", ar="تم الحفظ: %@", pt="Salvo: %@", ru="Сохранено: %@", de="Gespeichert: %@")
    a("summary.saveFailed", en="Save failed: %@", zhHans="保存失败：%@", ko="저장 실패: %@", es="Error al guardar: %@", hi="सहेजना विफल: %@", ar="فشل الحفظ: %@", pt="Falha ao salvar: %@", ru="Ошибка сохранения: %@", de="Speichern fehlgeschlagen: %@")
    a("menubar.popover.focusToday", en="Focus today", zhHans="今日专注", ko="오늘 집중", es="Enfoque de hoy", hi="आज का फ़ोकस", ar="تركيز اليوم", pt="Foco de hoje", ru="Фокус сегодня", de="Fokus heute")
    a("menubar.popover.pause", en="Pause", zhHans="暂停", ko="일시정지", es="Pausar", hi="रोकें", ar="إيقاف مؤقت", pt="Pausar", ru="Пауза", de="Pause")
    a("menubar.popover.start", en="Start", zhHans="开始", ko="시작", es="Iniciar", hi="शुरू", ar="بدء", pt="Iniciar", ru="Старт", de="Start")
    a("dashboard.export.asFormat", en="Export as %@", zhHans="导出为 %@", ko="%@로 내보내기", es="Exportar como %@", hi="%@ के रूप में निर्यात", ar="تصدير كـ %@", pt="Exportar como %@", ru="Экспорт в %@", de="Als %@ exportieren")
    a("activity.focusToday", en="Today %@", zhHans="今日 %@", ko="오늘 %@", es="Hoy %@", hi="आज %@", ar="اليوم %@", pt="Hoje %@", ru="Сегодня %@", de="Heute %@")
    a("focus.goal.prefix", en="Goal %@", zhHans="目标 %@", ko="목표 %@", es="Objetivo %@", hi="लक्ष्य %@", ar="الهدف %@", pt="Meta %@", ru="Цель %@", de="Ziel %@")
    a("focus.goal.custom", en="Custom · %d min", zhHans="自定义 · %d 分钟", ko="직접 조절 · %d분", es="Personalizado · %d min", hi="कस्टम · %d मि.", ar="مخصص · %d د", pt="Personalizado · %d min", ru="Своё · %d мин", de="Benutzerdefiniert · %d Min.")
    a("focus.goal.hours", en="%d h", zhHans="%d 小时", ko="%d시간", es="%d h", hi="%d घं", ar="%d س", pt="%d h", ru="%d ч", de="%d Std.")
    a("focus.goal.hoursMinutes", en="%d h %d min", zhHans="%d 小时 %d 分钟", ko="%d시간 %d분", es="%d h %d min", hi="%d घं %d मि.", ar="%d س %d د", pt="%d h %d min", ru="%d ч %d мин", de="%d Std. %d Min.")
    a("widget.focusToday", en="Focus today", zhHans="今日专注", ko="오늘 집중", es="Enfoque de hoy", hi="आज का फ़ोकस", ar="تركيز اليوم", pt="Foco de hoje", ru="Фокус сегодня", de="Fokus heute")
    a("widget.tracking", en="Tracking", zhHans="跟踪中", ko="추적 중", es="Registrando", hi="ट्रैकिंग", ar="تتبع", pt="Rastreando", ru="Отслеживание", de="Erfassung")
    a("widget.paused", en="Paused", zhHans="已暂停", ko="일시정지", es="En pausa", hi="रोका गया", ar="متوقف", pt="Pausado", ru="Пауза", de="Pausiert")
    a("widget.focus", en="Focus", zhHans="专注", ko="집중", es="Enfoque", hi="फ़ोकस", ar="تركيز", pt="Foco", ru="Фокус", de="Fokus")
    a("widget.total", en="Total", zhHans="总计", ko="전체", es="Total", hi="कुल", ar="الإجمالي", pt="Total", ru="Всего", de="Gesamt")
    a("widget.pause", en="Pause", zhHans="暂停", ko="일시정지", es="Pausar", hi="रोकें", ar="إيقاف", pt="Pausar", ru="Пауза", de="Pause")
    a("widget.start", en="Start", zhHans="开始", ko="시작", es="Iniciar", hi="शुरू", ar="بدء", pt="Iniciar", ru="Старт", de="Start")
    a("widget.currentApp", en="Current app", zhHans="当前应用", ko="현재 앱", es="App actual", hi="वर्तमान ऐप", ar="التطبيق الحالي", pt="App atual", ru="Текущее приложение", de="Aktuelle App")
    a("widget.description", en="Check your focus rate and control tracking from the desktop.", zhHans="在桌面查看专注比例并控制跟踪。", ko="바탕화면에서 집중 비율을 확인하고 트래킹을 제어하세요.", es="Consulta tu tasa de enfoque y controla el seguimiento desde el escritorio.", hi="डेस्कटॉप से फ़ोकस दर देखें और ट्रैकिंग नियंत्रित करें।", ar="تحقق من معدل تركيزك وتحكم بالتتبع من سطح المكتب.", pt="Veja sua taxa de foco e controle o rastreamento na área de trabalho.", ru="Смотрите долю фокуса и управляйте отслеживанием с рабочего стола.", de="Fokusrate prüfen und Tracking vom Desktop steuern.")
    a("widget.desktopName", en="LifeLogger · Desktop", zhHans="LifeLogger · 桌面", ko="LifeLogger · 바탕화면", es="LifeLogger · Escritorio", hi="LifeLogger · डेस्कटॉप", ar="LifeLogger · سطح المكتب", pt="LifeLogger · Área de trabalho", ru="LifeLogger · Рабочий стол", de="LifeLogger · Schreibtisch")
    a("widget.desktopDescription", en="A compact focus widget that pins nicely to the desktop.", zhHans="适合固定到桌面的紧凑专注小组件。", ko="작은 크기로 바탕화면에 고정하기 좋은 집중 위젯입니다.", es="Un widget compacto de enfoque ideal para el escritorio.", hi="डेस्कटॉप पर पिन करने के लिए कॉम्पैक्ट फ़ोकस विजेट।", ar="ودجت تركيز مضغوط يناسب التثبيت على سطح المكتب.", pt="Um widget compacto de foco ideal para a área de trabalho.", ru="Компактный виджет фокуса для рабочего стола.", de="Kompaktes Fokus-Widget zum Anheften auf dem Schreibtisch.")
    a("theme.deepOcean", en="Deep Ocean", zhHans="深海", ko="딥 오션", es="Océano profundo", hi="गहरा महासागर", ar="المحيط العميق", pt="Oceano profundo", ru="Глубокий океан", de="Tiefer Ozean")
    a("theme.midnight", en="Midnight", zhHans="午夜", ko="미드나잇", es="Medianoche", hi="मध्यरात्रि", ar="منتصف الليل", pt="Meia-noite", ru="Полночь", de="Mitternacht")
    a("theme.forest", en="Forest", zhHans="森林", ko="포레스트", es="Bosque", hi="जंगल", ar="غابة", pt="Floresta", ru="Лес", de="Wald")
    a("pomodoro.phase.idle", en="Idle", zhHans="待命", ko="대기", es="Inactivo", hi="निष्क्रिय", ar="خامل", pt="Inativo", ru="Ожидание", de="Bereit")
    a("pomodoro.phase.focus", en="Focus", zhHans="专注", ko="집중", es="Enfoque", hi="फ़ोकस", ar="تركيز", pt="Foco", ru="Фокус", de="Fokus")
    a("pomodoro.phase.shortBreak", en="Break", zhHans="休息", ko="휴식", es="Descanso", hi="विराम", ar="استراحة", pt="Pausa", ru="Перерыв", de="Pause")
    a("pomodoro.phase.longBreak", en="Long break", zhHans="长休息", ko="긴 휴식", es="Descanso largo", hi="लंबा विराम", ar="استراحة طويلة", pt="Pausa longa", ru="Длинный перерыв", de="Lange Pause")
    a("pomodoro.notify.focusDoneTitle", en="Focus complete!", zhHans="专注完成！", ko="집중 완료!", es="¡Enfoque completado!", hi="फ़ोकस पूरा!", ar="اكتمل التركيز!", pt="Foco concluído!", ru="Фокус завершён!", de="Fokus abgeschlossen!")
    a("pomodoro.notify.focusDoneBody", en="Start a 5-minute break.", zhHans="开始 5 分钟休息。", ko="5분 휴식을 시작하세요.", es="Empieza un descanso de 5 minutos.", hi="5 मिनट का विराम शुरू करें।", ar="ابدأ استراحة لمدة 5 دقائق.", pt="Comece uma pausa de 5 minutos.", ru="Начните 5-минутный перерыв.", de="Starte eine 5-Minuten-Pause.")
    a("pomodoro.notify.breakDoneTitle", en="Break over", zhHans="休息结束", ko="휴식 종료", es="Fin del descanso", hi="विराम समाप्त", ar="انتهت الاستراحة", pt="Pausa encerrada", ru="Перерыв окончен", de="Pause vorbei")
    a("pomodoro.notify.breakDoneBody", en="Time to focus again.", zhHans="该继续专注了。", ko="다시 집중 시간을 시작합니다.", es="Es hora de enfocarte de nuevo.", hi="फिर से फ़ोकस का समय।", ar="حان وقت التركيز مجددًا.", pt="Hora de focar novamente.", ru="Пора снова сосредоточиться.", de="Zeit, wieder zu fokussieren.")
    a("pomodoro.notify.focusEndTitle", en="Focus time ended", zhHans="专注时间结束", ko="집중 시간 종료", es="Terminó el tiempo de enfoque", hi="फ़ोकस समय समाप्त", ar="انتهى وقت التركيز", pt="Tempo de foco encerrado", ru="Время фокуса закончилось", de="Fokuszeit beendet")
    a("pomodoro.notify.focusEndBody", en="Nice work! Take a break.", zhHans="做得好！休息一下吧。", ko="잘하셨어요! 휴식을 취하세요.", es="¡Bien hecho! Tómate un descanso.", hi="शाबाश! थोड़ा आराम करें।", ar="أحسنت! خذ استراحة.", pt="Bom trabalho! Faça uma pausa.", ru="Отлично! Сделайте перерыв.", de="Gut gemacht! Mach eine Pause.")
    a("pomodoro.notify.breakEndBody", en="Ready to focus again?", zhHans="准备好再次专注了吗？", ko="다시 집중해볼까요?", es="¿Listo para enfocarte otra vez?", hi="फिर से फ़ोकस के लिए तैयार?", ar="هل أنت مستعد للتركيز مجددًا؟", pt="Pronto para focar de novo?", ru="Готовы снова сосредоточиться?", de="Bereit, wieder zu fokussieren?")
    a("notch.shareHelp", en="Share with a friend", zhHans="分享给朋友", ko="친구에게 공유", es="Compartir con un amigo", hi="मित्र के साथ साझा करें", ar="مشاركة مع صديق", pt="Compartilhar com um amigo", ru="Поделиться с другом", de="Mit einem Freund teilen")
    a("status.afk", en="Away", zhHans="离开", ko="자리 비움", es="Ausente", hi="दूर", ar="بعيد", pt="Ausente", ru="Отошёл", de="Abwesend")
    a("status.analyzing", en="Analyzing…", zhHans="分析中…", ko="분석 중…", es="Analizando…", hi="विश्लेषण…", ar="جارٍ التحليل…", pt="Analisando…", ru="Анализ…", de="Analyse…")
    a("status.paused", en="Paused", zhHans="已暂停", ko="일시정지", es="En pausa", hi="रोका गया", ar="متوقف", pt="Pausado", ru="Пауза", de="Pausiert")
    a("status.active", en="In progress", zhHans="进行中", ko="진행 중", es="En curso", hi="चालू", ar="جارٍ", pt="Em andamento", ru="В процессе", de="Aktiv")
    a("status.detecting", en="Detecting activity…", zhHans="正在检测活动…", ko="활동 감지 중…", es="Detectando actividad…", hi="गतिविधि पहचानी जा रही है…", ar="جارٍ اكتشاف النشاط…", pt="Detectando atividade…", ru="Обнаружение активности…", de="Aktivität wird erkannt…")
    a("status.afkSubtitle", en="Stepped away for a moment", zhHans="暂时离开一下", ko="잠시 멀어져 있어요", es="Se ausentó un momento", hi="थोड़ी देर के लिए दूर", ar="ابتعد للحظة", pt="Ausentou-se por um momento", ru="Ненадолго отошёл", de="Kurz weggegangen")
    a("status.stopped", en="Stopped", zhHans="已停止", ko="멈춤", es="Detenido", hi="रुका", ar="متوقف", pt="Parado", ru="Остановлено", de="Gestoppt")
    a("status.justStarted", en="Just started", zhHans="刚开始", ko="막 시작", es="Recién empezado", hi="अभी शुरू", ar="بدأ للتو", pt="Recém-começado", ru="Только начал", de="Gerade gestartet")
    a("status.warmingUp", en="Getting into flow", zhHans="进入状态中", ko="흐름 타는 중", es="Entrando en flujo", hi="प्रवाह में आ रहे हैं", ar="يدخل في التدفق", pt="Entrando no fluxo", ru="Входит в поток", de="Kommt in den Flow")
    a("status.inFlow", en="In the zone", zhHans="沉浸中", ko="몰입 중", es="En la zona", hi="ज़ोन में", ar="في حالة تركيز", pt="No fluxo", ru="В потоке", de="Im Flow")
    a("status.deepIn", en="Deeply focused", zhHans="深度投入", ko="깊이 들어감", es="Enfoque profundo", hi="गहरा फ़ोकस", ar="تركيز عميق", pt="Foco profundo", ru="Глубокий фокус", de="Tief fokussiert")
    a("status.longStretch", en="Long stretch", zhHans="长时间持续", ko="오래 이어짐", es="Racha larga", hi="लंबा सिलसिला", ar="فترة طويلة", pt="Longa sequência", ru="Долгая серия", de="Langer Lauf")
    a("status.resting", en="Resting", zhHans="休息中", ko="쉬는 중", es="Descansando", hi="आराम", ar="يستريح", pt="Descansando", ru="Отдыхает", de="Pause")
    a("mood.greatFlow", en="Great flow", zhHans="状态很好", ko="몰입 흐름 좋음", es="Gran flujo", hi="बेहतरीन प्रवाह", ar="تدفق رائع", pt="Ótimo fluxo", ru="Отличный поток", de="Super Flow")
    a("mood.steady", en="Keeping rhythm", zhHans="保持节奏", ko="리듬 유지 중", es="Manteniendo el ritmo", hi="लय बनाए रखना", ar="يحافظ على الإيقاع", pt="Mantendo o ritmo", ru="Держит ритм", de="Rhythmus halten")
    a("mood.pushABit", en="A little more", zhHans="再加把劲", ko="조금만 더", es="Un poco más", hi="थोड़ा और", ar="قليل أكثر", pt="Mais um pouco", ru="Ещё чуть-чуть", de="Noch ein bisschen")
    a("mood.lightStart", en="Easing in", zhHans="轻松开始", ko="가볍게 시작", es="Empezando suave", hi="हल्के से शुरू", ar="بداية خفيفة", pt="Começando leve", ru="Лёгкий старт", de="Leichter Start")
    a("mood.slowOk", en="Slow is fine", zhHans="慢慢来也没关系", ko="천천히 가도 OK", es="Ir despacio está bien", hi="धीरे ठीक है", ar="البطء مقبول", pt="Devagar está bem", ru="Медленно — нормально", de="Langsam ist okay")
    a("widgetGuide.title", en="Add a desktop widget", zhHans="添加桌面小组件", ko="바탕화면 위젯 추가", es="Añadir widget de escritorio", hi="डेस्कटॉप विजेट जोड़ें", ar="إضافة ودجت سطح المكتب", pt="Adicionar widget na área de trabalho", ru="Добавить виджет на рабочий стол", de="Desktop-Widget hinzufügen")
    a("widgetGuide.subtitle", en="Pin a LifeLogger widget to your Mac desktop.", zhHans="把 LifeLogger 小组件固定到 Mac 桌面。", ko="LifeLogger 위젯을 Mac 바탕화면에 고정하세요.", es="Fija un widget de LifeLogger en el escritorio del Mac.", hi="Mac डेस्कटॉप पर LifeLogger विजेट पिन करें।", ar="ثبّت ودجت LifeLogger على سطح مكتب Mac.", pt="Fixe um widget do LifeLogger na área de trabalho do Mac.", ru="Закрепите виджет LifeLogger на рабочем столе Mac.", de="Heften Sie ein LifeLogger-Widget an den Mac-Schreibtisch.")
    a("widgetGuide.step1", en="Control-click (or right-click) an empty spot on the desktop", zhHans="在桌面空白处按住 Control 并点击（或右键单击）", ko="바탕화면 빈 곳에서 Control + 클릭 (또는 우클릭)", es="Haz clic con Control (o clic derecho) en un espacio vacío del escritorio", hi="डेस्कटॉप की खाली जगह पर Control + क्लिक (या राइट-क्लिक)", ar="انقر مع Control (أو انقر يمينًا) على مساحة فارغة على سطح المكتب", pt="Control-clique (ou clique com o botão direito) em um espaço vazio na área de trabalho", ru="Control-клик (или правый клик) по пустому месту на рабочем столе", de="Control-Klick (oder Rechtsklick) auf eine leere Stelle des Schreibtischs")
    a("widgetGuide.step2", en='Choose "Edit Widgets…"', zhHans="选择“编辑小组件…”", ko="「위젯 편집…」 선택", es='Elige "Editar widgets…"', hi='"Edit Widgets…" चुनें', ar='اختر "Edit Widgets…"', pt='Escolha "Editar Widgets…"', ru="Выберите «Изменить виджеты…»", de="„Widgets bearbeiten…“ wählen")
    a("widgetGuide.step3", en='Type "LifeLogger" in the search field', zhHans="在搜索框输入 “LifeLogger”", ko="검색창에 「LifeLogger」 입력", es='Escribe "LifeLogger" en el campo de búsqueda', hi='खोज में "LifeLogger" टाइप करें', ar='اكتب "LifeLogger" في حقل البحث', pt='Digite "LifeLogger" no campo de busca', ru="Введите «LifeLogger» в поиске", de="„LifeLogger“ in die Suche eingeben")
    a("widgetGuide.step4", en="Drag the size you want (small/medium/large) to the desktop", zhHans="把想要的尺寸（小/中/大）拖到桌面", ko="원하는 크기(작음/중간/큼)를 바탕화면으로 드래그", es="Arrastra el tamaño que quieras (pequeño/mediano/grande) al escritorio", hi="चाहिए आकार (छोटा/मध्यम/बड़ा) डेस्कटॉप पर खींचें", ar="اسحب الحجم الذي تريده (صغير/متوسط/كبير) إلى سطح المكتب", pt="Arraste o tamanho desejado (pequeno/médio/grande) para a área de trabalho", ru="Перетащите нужный размер (маленький/средний/большой) на рабочий стол", de="Gewünschte Größe (klein/mittel/groß) auf den Schreibtisch ziehen")
    a("widgetGuide.recommended", en="Recommended widgets", zhHans="推荐小组件", ko="추천 위젯", es="Widgets recomendados", hi="अनुशंसित विजेट", ar="الودجات الموصى بها", pt="Widgets recomendados", ru="Рекомендуемые виджеты", de="Empfohlene Widgets")
    a("widgetGuide.recDesktop", en="LifeLogger · Desktop — small size, includes play/pause buttons", zhHans="LifeLogger · 桌面 — 小尺寸，含播放/暂停按钮", ko="LifeLogger · 바탕화면 — 작은 크기, 재생/일시정지 버튼 포함", es="LifeLogger · Escritorio — tamaño pequeño, con botones de reproducción/pausa", hi="LifeLogger · डेस्कटॉप — छोटा आकार, प्ले/पॉज़ बटन सहित", ar="LifeLogger · سطح المكتب — حجم صغير مع أزرار تشغيل/إيقاف", pt="LifeLogger · Área de trabalho — tamanho pequeno, com botões play/pause", ru="LifeLogger · Рабочий стол — маленький размер, кнопки play/pause", de="LifeLogger · Schreibtisch — klein, mit Play/Pause-Tasten")
    a("widgetGuide.recMain", en="LifeLogger — medium/large, includes a 7-day trend chart", zhHans="LifeLogger — 中/大尺寸，含 7 日趋势图", ko="LifeLogger — 중/대형, 7일 추세 차트 포함", es="LifeLogger — mediano/grande, con gráfica de 7 días", hi="LifeLogger — मध्यम/बड़ा, 7-दिन ट्रेंड चार्ट सहित", ar="LifeLogger — متوسط/كبير مع مخطط اتجاه 7 أيام", pt="LifeLogger — médio/grande, com gráfico de tendência de 7 dias", ru="LifeLogger — средний/большой, график тренда за 7 дней", de="LifeLogger — mittel/groß, mit 7-Tage-Trenddiagramm")
    a("widgetGuide.footer", en="Data refreshes automatically while the app is running.", zhHans="应用运行时数据会自动刷新。", ko="앱이 실행 중일 때 데이터가 자동으로 갱신됩니다.", es="Los datos se actualizan automáticamente mientras la app está abierta.", hi="ऐप चलने पर डेटा अपने आप अपडेट होता है।", ar="تتحدث البيانات تلقائيًا أثناء تشغيل التطبيق.", pt="Os dados atualizam automaticamente enquanto o app está em execução.", ru="Данные обновляются автоматически, пока приложение запущено.", de="Daten aktualisieren sich automatisch, solange die App läuft.")
    # Settings
    a("settings.rules.keyword", en="App/window keyword", zhHans="应用/窗口关键词", ko="앱/창 키워드", es="Palabra clave de app/ventana", hi="ऐप/विंडो कीवर्ड", ar="كلمة مفتاحية للتطبيق/النافذة", pt="Palavra-chave de app/janela", ru="Ключевое слово приложения/окна", de="App-/Fenster-Stichwort")
    a("settings.rules.category", en="Category", zhHans="类别", ko="카테고리", es="Categoría", hi="श्रेणी", ar="الفئة", pt="Categoria", ru="Категория", de="Kategorie")
    a("settings.rules.addRule", en="Add rule", zhHans="添加规则", ko="규칙 추가", es="Añadir regla", hi="नियम जोड़ें", ar="إضافة قاعدة", pt="Adicionar regra", ru="Добавить правило", de="Regel hinzufügen")
    a("settings.rules.empty", en="No rules yet.", zhHans="还没有规则。", ko="등록된 규칙이 없습니다.", es="Aún no hay reglas.", hi="अभी कोई नियम नहीं।", ar="لا توجد قواعد بعد.", pt="Ainda não há regras.", ru="Правил пока нет.", de="Noch keine Regeln.")
    a("settings.nudge.title", en="Notify when non-focus activity runs long", zhHans="非专注活动过长时通知", ko="비집중 활동이 길어지면 알림", es="Avisar si la actividad no enfocada dura mucho", hi="गैर-फ़ोकस गतिविधि लंबी होने पर सूचित करें", ar="أبلغ عند طول النشاط غير المركز", pt="Avisar quando atividade fora de foco durar muito", ru="Уведомлять о долгой нефокусной активности", de="Benachrichtigen bei langer Nicht-Fokus-Aktivität")
    a("settings.nudge.threshold", en="Threshold: %d min", zhHans="阈值：%d 分钟", ko="기준 시간: %d분", es="Umbral: %d min", hi="सीमा: %d मि.", ar="الحد: %d د", pt="Limite: %d min", ru="Порог: %d мин", de="Schwelle: %d Min.")
    a("settings.nudge.detail", en="You'll get one alert after %d+ continuous minutes in communication, browsing, entertainment, and similar categories.", zhHans="在沟通、浏览、娱乐等类别连续停留 %d 分钟以上时提醒一次。", ko="커뮤니케이션·브라우징·엔터테인먼트 등에 %d분 이상 연속으로 머물면 한 번 알려줘요.", es="Recibirás un aviso tras %d+ minutos seguidos en comunicación, navegación, entretenimiento y similares.", hi="संचार, ब्राउज़िंग, मनोरंजन आदि में %d+ मिनट लगातार रहने पर एक अलर्ट मिलेगा।", ar="ستتلقى تنبيهًا واحدًا بعد %d+ دقائق متواصلة في التواصل والتصفح والترفيه وما شابه.", pt="Você recebe um alerta após %d+ minutos contínuos em comunicação, navegação, entretenimento e similares.", ru="Одно уведомление после %d+ минут подряд в общении, браузинге, развлечениях и похожих категориях.", de="Ein Hinweis nach %d+ Minuten durchgehend in Kommunikation, Surfen, Unterhaltung u. Ä.")
    a("settings.rest.title", en="Eye-rest reminder during long focus", zhHans="长时间专注时的护眼提醒", ko="연속 몰입 시 눈 쉬기 알림", es="Recordatorio de descanso ocular en enfoque largo", hi="लंबे फ़ोकस में आँख आराम रिमाइंडर", ar="تذكير براحة العين أثناء التركيز الطويل", pt="Lembrete de descanso ocular em foco longo", ru="Напоминание отдохнуть глазам при долгом фокусе", de="Augenpause bei langem Fokus")
    a("settings.rest.threshold", en="Threshold: %d min", zhHans="阈值：%d 分钟", ko="기준: %d분", es="Umbral: %d min", hi="सीमा: %d मि.", ar="الحد: %d د", pt="Limite: %d min", ru="Порог: %d мин", de="Schwelle: %d Min.")
    a("settings.pauseApp.placeholder", en="App name (e.g. Zoom)", zhHans="应用名称（例如 Zoom）", ko="앱 이름 (예: Zoom)", es="Nombre de app (p. ej. Zoom)", hi="ऐप नाम (जैसे Zoom)", ar="اسم التطبيق (مثل Zoom)", pt="Nome do app (ex.: Zoom)", ru="Имя приложения (напр. Zoom)", de="App-Name (z. B. Zoom)")
    a("settings.pauseApp.delete", en="Delete", zhHans="删除", ko="삭제", es="Eliminar", hi="हटाएँ", ar="حذف", pt="Excluir", ru="Удалить", de="Löschen")
    a("settings.pauseApp.note", en="Time-window rules (e.g. lunch 12:00–13:00) can be added later.", zhHans="时段规则（例如午餐 12:00–13:00）可在之后扩展。", ko="점심 시간(12:00–13:00) 등 시간대 규칙은 추후 확장 가능합니다.", es="Las reglas por franja horaria (p. ej. comida 12:00–13:00) se podrán ampliar más adelante.", hi="समय-विंडो नियम (जैसे दोपहर 12:00–13:00) बाद में जोड़े जा सकते हैं।", ar="يمكن إضافة قواعد الفترات الزمنية (مثل الغداء 12:00–13:00) لاحقًا.", pt="Regras por janela de horário (ex.: almoço 12:00–13:00) podem ser adicionadas depois.", ru="Правила по времени (например обед 12:00–13:00) можно добавить позже.", de="Zeitfenster-Regeln (z. B. Mittag 12:00–13:00) können später ergänzt werden.")
    a("settings.retention.title", en="Auto-delete old records", zhHans="自动删除旧记录", ko="오래된 기록 자동 삭제", es="Eliminar registros antiguos automáticamente", hi="पुराने रिकॉर्ड स्वतः हटाएँ", ar="حذف السجلات القديمة تلقائيًا", pt="Excluir registros antigos automaticamente", ru="Автоудаление старых записей", de="Alte Einträge automatisch löschen")
    a("settings.retention.days", en="Keep for: %d days", zhHans="保留：%d 天", ko="보존 기간: %d일", es="Conservar: %d días", hi="रखें: %d दिन", ar="الاحتفاظ: %d يومًا", pt="Manter: %d dias", ru="Хранить: %d дн.", de="Aufbewahren: %d Tage")
    a("settings.retention.preview", en="Preview cleanup now", zhHans="立即预览清理", ko="지금 정리 미리보기", es="Vista previa de limpieza", hi="अभी सफ़ाई पूर्वावलोकन", ar="معاينة التنظيف الآن", pt="Pré-visualizar limpeza agora", ru="Предпросмотр очистки", de="Bereinigung jetzt Vorschau")
    a("settings.retention.count", en="%d records would be deleted.", zhHans="将删除 %d 条记录。", ko="%d개 기록이 삭제 대상입니다.", es="Se eliminarían %d registros.", hi="%d रिकॉर्ड हटाए जाएंगे।", ar="سيتم حذف %d سجلًا.", pt="%d registros seriam excluídos.", ru="Будет удалено записей: %d.", de="%d Einträge würden gelöscht.")
    a("settings.backup.password", en="Backup password", zhHans="备份密码", ko="백업 암호", es="Contraseña de copia", hi="बैकअप पासवर्ड", ar="كلمة مرور النسخ الاحتياطي", pt="Senha do backup", ru="Пароль резервной копии", de="Backup-Passwort")
    a("settings.backup.export", en="Export backup", zhHans="导出备份", ko="백업 내보내기", es="Exportar copia", hi="बैकअप निर्यात", ar="تصدير النسخة", pt="Exportar backup", ru="Экспорт резервной копии", de="Backup exportieren")
    a("settings.backup.importMerge", en="Import (merge)", zhHans="导入（合并）", ko="가져오기(병합)", es="Importar (combinar)", hi="आयात (मर्ज)", ar="استيراد (دمج)", pt="Importar (mesclar)", ru="Импорт (слияние)", de="Importieren (zusammenführen)")
    a("settings.backup.importOverwrite", en="Import (overwrite)", zhHans="导入（覆盖）", ko="가져오기(덮어쓰기)", es="Importar (sobrescribir)", hi="आयात (ओवरराइट)", ar="استيراد (استبدال)", pt="Importar (substituir)", ru="Импорт (перезапись)", de="Importieren (überschreiben)")
    a("settings.backup.note", en="AES-GCM encrypted · full backup for device moves", zhHans="AES-GCM 加密 · 适合换机的完整备份", ko="AES-GCM 암호화 · 기기 이전용 풀 백업", es="Cifrado AES-GCM · copia completa para cambiar de dispositivo", hi="AES-GCM एन्क्रिप्टेड · डिवाइस स्थानांतरण के लिए पूर्ण बैकअप", ar="مشفّر بـ AES-GCM · نسخة كاملة لنقل الجهاز", pt="Criptografado AES-GCM · backup completo para troca de dispositivo", ru="Шифрование AES-GCM · полный бэкап для переноса", de="AES-GCM-verschlüsselt · Vollbackup für Gerätewechsel")
    a("settings.backup.done", en="Backup complete: %@", zhHans="备份完成：%@", ko="백업 완료: %@", es="Copia completa: %@", hi="बैकअप पूर्ण: %@", ar="اكتمل النسخ: %@", pt="Backup concluído: %@", ru="Резервная копия готова: %@", de="Backup fertig: %@")
    a("settings.backup.imported", en="Imported %d records.", zhHans="已导入 %d 条记录。", ko="%d개 기록을 가져왔습니다.", es="Se importaron %d registros.", hi="%d रिकॉर्ड आयात किए।", ar="تم استيراد %d سجلًا.", pt="%d registros importados.", ru="Импортировано записей: %d.", de="%d Einträge importiert.")
    a("settings.hotkeys.title", en="Use global hotkeys", zhHans="使用全局快捷键", ko="전역 단축키 사용", es="Usar atajos globales", hi="वैश्विक हॉटकी उपयोग करें", ar="استخدام اختصارات عامة", pt="Usar atalhos globais", ru="Глобальные горячие клавиши", de="Globale Tastenkürzel verwenden")
    a("settings.hotkeys.detail", en="⌃⌥L — toggle tracking · ⌃⌥P — start/stop Pomodoro", zhHans="⌃⌥L — 切换跟踪 · ⌃⌥P — 开始/停止番茄钟", ko="⌃⌥L — 트래킹 토글 · ⌃⌥P — 뽀모도로 시작/정지", es="⌃⌥L — alternar seguimiento · ⌃⌥P — iniciar/parar Pomodoro", hi="⌃⌥L — ट्रैकिंग टॉगल · ⌃⌥P — पोमोडोरो शुरू/रोकें", ar="⌃⌥L — تبديل التتبع · ⌃⌥P — بدء/إيقاف بومودورو", pt="⌃⌥L — alternar rastreamento · ⌃⌥P — iniciar/parar Pomodoro", ru="⌃⌥L — переключить отслеживание · ⌃⌥P — старт/стоп Pomodoro", de="⌃⌥L — Tracking umschalten · ⌃⌥P — Pomodoro starten/stoppen")
    a("settings.theme", en="Theme", zhHans="主题", ko="테마", es="Tema", hi="थीम", ar="السمة", pt="Tema", ru="Тема", de="Design")
    a("settings.focusMode.title", en="Auto-track when Focus mode is on", zhHans="开启专注模式时自动跟踪", ko="집중 모드 켜짐 시 자동 트래킹", es="Seguir automáticamente con el modo Enfoque", hi="फ़ोकस मोड चालू होने पर ऑटो-ट्रैक", ar="تتبع تلقائي عند تشغيل وضع التركيز", pt="Rastrear automaticamente com o modo Foco", ru="Автоотслеживание при режиме Фокус", de="Auto-Tracking bei Fokusmodus")
    a("settings.focusMode.detail", en="Uses heuristic signals due to public API limits. Turn off if unstable.", zhHans="因公开 API 限制使用启发式信号。不稳定时可关闭。", ko="공개 API 한계로 휴리스틱 신호를 사용합니다. 불안정하면 끄세요.", es="Usa señales heurísticas por límites de la API pública. Desactívalo si es inestable.", hi="सार्वजनिक API सीमाओं के कारण ह्यूरिस्टिक संकेतों का उपयोग। अस्थिर हो तो बंद करें।", ar="يستخدم إشارات تقريبية بسبب حدود واجهة برمجة عامة. أوقفه إن كان غير مستقر.", pt="Usa sinais heurísticos devido a limites da API pública. Desative se for instável.", ru="Использует эвристики из‑за ограничений публичного API. Отключите при нестабильности.", de="Nutzt Heuristiken wegen öffentlicher API-Grenzen. Bei Instabilität ausschalten.")
    a("settings.focusCats", en="Focus: Coding, Design, Writing", zhHans="专注：编程、设计、写作", ko="집중: 코딩, 디자인, 문서·글쓰기", es="Enfoque: Programación, Diseño, Escritura", hi="फ़ोकस: कोडिंग, डिज़ाइन, लेखन", ar="التركيز: برمجة، تصميم، كتابة", pt="Foco: Programação, Design, Escrita", ru="Фокус: Разработка, Дизайн, Тексты", de="Fokus: Programmieren, Design, Schreiben")
    a("settings.nonFocusCats", en="Non-focus: Communication, Browsing, Entertainment, Other", zhHans="非专注：沟通、浏览、娱乐、其他", ko="비집중: 커뮤니케이션, 브라우징, 엔터테인먼트, 기타", es="No enfoque: Comunicación, Navegación, Entretenimiento, Otros", hi="गैर-फ़ोकस: संचार, ब्राउज़िंग, मनोरंजन, अन्य", ar="غير تركيز: تواصل، تصفح، ترفيه، أخرى", pt="Fora de foco: Comunicação, Navegação, Entretenimento, Outros", ru="Нефокус: Общение, Просмотр, Развлечения, Другое", de="Nicht-Fokus: Kommunikation, Surfen, Unterhaltung, Sonstiges")
    a("notify.eyeRest.title", en="Take an eye break", zhHans="让眼睛休息一下", ko="잠깐, 눈을 쉬어요", es="Descansa la vista", hi="आँखों को आराम दें", ar="أرح عينيك", pt="Descanse os olhos", ru="Дайте глазам отдохнуть", de="Augenpause")
    a("notify.eyeRest.body", en="You've been focusing for a while. Look into the distance for 20 seconds?", zhHans="你已经专注很久了。远眺 20 秒怎么样？", ko="오래 집중하고 있어요. 20초만 멀리 바라볼까요?", es="Llevas un rato enfocado. ¿Miras a lo lejos 20 segundos?", hi="आप काफी देर से फ़ोकस में हैं। 20 सेकंड दूर देखें?", ar="تركّز منذ فترة. أنظر بعيدًا لمدة 20 ثانية؟", pt="Você está focado há um tempo. Olhar ao longe por 20 segundos?", ru="Вы долго в фокусе. Посмотрите вдаль на 20 секунд?", de="Du bist schon lange fokussiert. 20 Sekunden in die Ferne schauen?")
    a("notify.eyeRest.bodyGoal", en="Deep focus underway. Goal '%@' — stretch for a moment?", zhHans="正在深度专注。目标“%@”——要不要伸个懒腰？", ko="오래 집중 중이에요. 목표 '%@' — 잠깐 스트레칭 어때요?", es="Enfoque profundo en marcha. Objetivo '%@' — ¿un estiramiento?", hi="गहरा फ़ोकस चल रहा है। लक्ष्य '%@' — थोड़ा स्ट्रेच?", ar="تركيز عميق جارٍ. الهدف '%@' — هل تتمدد قليلاً؟", pt="Foco profundo em andamento. Meta '%@' — alongar um pouco?", ru="Идёт глубокий фокус. Цель «%@» — размяться?", de="Tiefer Fokus läuft. Ziel „%@“ — kurz dehnen?")
    a("notify.nudge.title", en="Quick focus check", zhHans="快速专注检查", ko="잠깐, 집중 흐름 체크", es="Revisión rápida de enfoque", hi="त्वरित फ़ोकस जाँच", ar="فحص تركيز سريع", pt="Checagem rápida de foco", ru="Быстрая проверка фокуса", de="Kurzer Fokus-Check")
    a("notify.nudge.body", en="You've been in %@ for %d+ minutes. Head back to focus?", zhHans="你已在「%@」停留超过 %d 分钟。要回到专注吗？", ko="%@에 %d분 넘게 머물고 있어요. 다시 집중으로 돌아올까요?", es="Llevas %d+ minutos en %@. ¿Volvemos al enfoque?", hi="आप %@ में %d+ मिनट से हैं। वापस फ़ोकस पर?", ar="أنت في %@ منذ أكثر من %d دقيقة. أتعود للتركيز؟", pt="Você está em %@ há %d+ minutos. Voltar ao foco?", ru="Вы в «%@» уже %d+ мин. Вернуться к фокусу?", de="Du bist seit %d+ Minuten in %@. Zurück zum Fokus?")
    a("notify.nudge.bodyGoal", en="%d minutes in %@ · today's goal: %@", zhHans="%d 分钟在「%@」· 今日目标：%@", ko="%d분째 %@ 중이에요. 오늘 목표: %@", es="%d minutos en %@ · objetivo de hoy: %@", hi="%d मिनट %@ में · आज का लक्ष्य: %@", ar="%d دقيقة في %@ · هدف اليوم: %@", pt="%d minutos em %@ · meta de hoje: %@", ru="%d мин в «%@» · цель на сегодня: %@", de="%d Minuten in %@ · heutiges Ziel: %@")
    a("share.noActivity", en="Nothing to share right now.", zhHans="现在没有可分享的活动。", ko="지금 공유할 활동이 없습니다.", es="No hay actividad para compartir ahora.", hi="अभी साझा करने के लिए कुछ नहीं।", ar="لا يوجد نشاط للمشاركة الآن.", pt="Nada para compartilhar agora.", ru="Сейчас нечего поделиться.", de="Gerade nichts zum Teilen.")
    a("share.taskNone", en="Task: (no title)", zhHans="任务：（无标题）", ko="작업: (제목 없음)", es="Tarea: (sin título)", hi="कार्य: (कोई शीर्षक नहीं)", ar="المهمة: (بدون عنوان)", pt="Tarefa: (sem título)", ru="Задача: (без названия)", de="Aufgabe: (kein Titel)")
    a("share.task", en="Task: %@", zhHans="任务：%@", ko="작업: %@", es="Tarea: %@", hi="कार्य: %@", ar="المهمة: %@", pt="Tarefa: %@", ru="Задача: %@", de="Aufgabe: %@")
    a("share.nowDoing", en="What I'm doing now", zhHans="我正在做的事", ko="지금 하고 있는 일", es="Lo que estoy haciendo", hi="मैं अभी क्या कर रहा/रही हूँ", ar="ما أفعله الآن", pt="O que estou fazendo agora", ru="Чем я сейчас занимаюсь", de="Was ich gerade mache")
    a("share.app", en="App: %@", zhHans="应用：%@", ko="앱: %@", es="App: %@", hi="ऐप: %@", ar="التطبيق: %@", pt="App: %@", ru="Приложение: %@", de="App: %@")
    a("share.category", en="Category: %@", zhHans="类别：%@", ko="카테고리: %@", es="Categoría: %@", hi="श्रेणी: %@", ar="الفئة: %@", pt="Categoria: %@", ru="Категория: %@", de="Kategorie: %@")
    a("share.thisActivity", en="This activity: %@", zhHans="此活动：%@", ko="이 활동: %@", es="Esta actividad: %@", hi="यह गतिविधि: %@", ar="هذا النشاط: %@", pt="Esta atividade: %@", ru="Эта активность: %@", de="Diese Aktivität: %@")
    a("share.todayFocus", en="Today's focus: %@", zhHans="今日专注：%@", ko="오늘 집중: %@", es="Enfoque de hoy: %@", hi="आज का फ़ोकस: %@", ar="تركيز اليوم: %@", pt="Foco de hoje: %@", ru="Фокус сегодня: %@", de="Heutiger Fokus: %@")
    a("share.todayGoal", en="Today's goal: %@", zhHans="今日目标：%@", ko="오늘 목표: %@", es="Objetivo de hoy: %@", hi="आज का लक्ष्य: %@", ar="هدف اليوم: %@", pt="Meta de hoje: %@", ru="Цель на сегодня: %@", de="Heutiges Ziel: %@")
    a("share.viaLifeLogger", en="Shared from LifeLogger", zhHans="来自 LifeLogger 的分享", ko="LifeLogger에서 공유됨", es="Compartido desde LifeLogger", hi="LifeLogger से साझा", ar="مشارك من LifeLogger", pt="Compartilhado do LifeLogger", ru="Поделено из LifeLogger", de="Geteilt aus LifeLogger")
    a("share.failedNoActivity", en="Nothing to share.", zhHans="没有可分享的内容。", ko="공유할 활동이 없습니다.", es="No hay nada que compartir.", hi="साझा करने के लिए कुछ नहीं।", ar="لا يوجد ما يمكن مشاركته.", pt="Nada para compartilhar.", ru="Нечего поделиться.", de="Nichts zum Teilen.")
    a("share.bloomieShared", en="Shared current activity to bloomie.", zhHans="已将当前活动分享到 bloomie。", ko="bloomie로 현재 활동을 공유했습니다.", es="Actividad actual compartida en bloomie.", hi="वर्तमान गतिविधि bloomie पर साझा की।", ar="تمت مشاركة النشاط الحالي إلى bloomie.", pt="Atividade atual compartilhada no bloomie.", ru="Текущая активность отправлена в bloomie.", de="Aktuelle Aktivität an bloomie geteilt.")
    a("share.bloomieClipboard", en="Couldn't find the bloomie app, so it was copied to the clipboard.\n\n%@", zhHans="找不到 bloomie 应用，已复制到剪贴板。\n\n%@", ko="bloomie 앱을 찾을 수 없어 클립보드에 복사했습니다.\n\n%@", es="No se encontró la app bloomie; se copió al portapapeles.\n\n%@", hi="bloomie ऐप नहीं मिला, क्लिपबोर्ड पर कॉपी किया।\n\n%@", ar="تعذر العثور على تطبيق bloomie، لذا نُسخ إلى الحافظة.\n\n%@", pt="Não foi possível encontrar o app bloomie; copiado para a área de transferência.\n\n%@", ru="Приложение bloomie не найдено — скопировано в буфер.\n\n%@", de="bloomie-App nicht gefunden — in die Zwischenablage kopiert.\n\n%@")
    return n


def patch_catalog() -> None:
    path = PROJ / "LifeLogger/Services/L10nCatalog.swift"
    text = path.read_text(encoding="utf-8")
    existing = set(re.findall(r'"([^"]+)":\s*\[', text))
    keys = build_keys()
    to_add = {k: v for k, v in keys.items() if k not in existing}
    print(f"Catalog: adding {len(to_add)} keys")
    blocks = [entry(k, v) for k, v in to_add.items()]
    insert = "\n".join(blocks) + "\n"
    idx = text.rfind("    ]\n}")
    if idx < 0:
        raise SystemExit("catalog end not found")
    path.write_text(text[:idx] + insert + text[idx:], encoding="utf-8")


def repl(path: Path, replacements: list[tuple[str, str]]) -> None:
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in replacements:
        if old not in text:
            print(f"WARN missing in {path.name}: {old[:60]!r}")
            continue
        text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"Patched {path.relative_to(PROJ)}")
    else:
        print(f"No changes {path.relative_to(PROJ)}")


def main() -> None:
    patch_catalog()

    # Dashboard export button
    repl(
        PROJ / "LifeLogger/UI/Dashboard/DashboardView.swift",
        [
            (
                'Button("\\(format.rawValue)로 내보내기") { exportData(format: format) }',
                'Button(L10n.tr("dashboard.export.asFormat", format.rawValue)) { exportData(format: format) }',
            )
        ],
    )

    # ActivityCategory comment already Korean OK; keep bloomie label Korean for API
    # Ensure localizedName stays in extension (already exists)

    # Metadata
    for plist in [
        PROJ / "LifeLogger/Info.plist",
        PROJ / "LifeLoggerWidget/Info.plist",
    ]:
        t = plist.read_text(encoding="utf-8")
        t2 = t.replace(
            "<key>CFBundleDevelopmentRegion</key>\n\t<string>ko</string>",
            "<key>CFBundleDevelopmentRegion</key>\n\t<string>en</string>",
        )
        if t2 != t:
            plist.write_text(t2, encoding="utf-8")
            print(f"Updated {plist.name} development region")

    pbx = PROJ / "LifeLogger.xcodeproj/project.pbxproj"
    pbx_text = pbx.read_text(encoding="utf-8")
    pbx_text2 = pbx_text.replace("developmentRegion = ko;", "developmentRegion = en;")
    pbx_text2 = pbx_text2.replace(
        "knownRegions = (\n\t\t\t\tko,\n\t\t\t\tBase,\n\t\t\t);",
        "knownRegions = (\n\t\t\t\ten,\n\t\t\t\tko,\n\t\t\t\tBase,\n\t\t\t);",
    )
    # Add L10n to widget target if missing
    if "L10N001BUILDW01" not in pbx_text2:
        # Insert widget build file refs after existing L10n build files
        pbx_text2 = pbx_text2.replace(
            "\t\tL10N003BUILD01 /* L10nCatalog.swift in Sources */ = {isa = PBXBuildFile; fileRef = L10N003APP01 /* L10nCatalog.swift */; };\n",
            "\t\tL10N003BUILD01 /* L10nCatalog.swift in Sources */ = {isa = PBXBuildFile; fileRef = L10N003APP01 /* L10nCatalog.swift */; };\n"
            "\t\tL10N001BUILDW01 /* AppLanguage.swift in Sources */ = {isa = PBXBuildFile; fileRef = L10N001APP01 /* AppLanguage.swift */; };\n"
            "\t\tL10N002BUILDW01 /* L10n.swift in Sources */ = {isa = PBXBuildFile; fileRef = L10N002APP01 /* L10n.swift */; };\n"
            "\t\tL10N003BUILDW01 /* L10nCatalog.swift in Sources */ = {isa = PBXBuildFile; fileRef = L10N003APP01 /* L10nCatalog.swift */; };\n"
            "\t\tL10N004BUILDW01 /* ActivityCategory+Localized.swift in Sources */ = {isa = PBXBuildFile; fileRef = L10N004LOC01 /* ActivityCategory+Localized.swift */; };\n",
        )
        # Find widget sources build phase and add files
        # Look for LifeLoggerWidget Sources section - ActivityCategory in Sources for widget
        marker = "\t\t\t\t7253B176AB9D415F8A5D6C15 /* ActivityCategory.swift in Sources */,\n"
        if marker in pbx_text2 and "L10N001BUILDW01 /* AppLanguage.swift in Sources */," not in pbx_text2:
            pbx_text2 = pbx_text2.replace(
                marker,
                marker
                + "\t\t\t\tL10N001BUILDW01 /* AppLanguage.swift in Sources */,\n"
                + "\t\t\t\tL10N002BUILDW01 /* L10n.swift in Sources */,\n"
                + "\t\t\t\tL10N003BUILDW01 /* L10nCatalog.swift in Sources */,\n"
                + "\t\t\t\tL10N004BUILDW01 /* ActivityCategory+Localized.swift in Sources */,\n",
            )
    if pbx_text2 != pbx_text:
        pbx.write_text(pbx_text2, encoding="utf-8")
        print("Updated project.pbxproj")

    yml = PROJ / "project.yml"
    yml_text = yml.read_text(encoding="utf-8")
    if "developmentRegion" not in yml_text:
        yml_text = yml_text.replace(
            "options:\n  bundleIdPrefix: com.lifelogger\n",
            "options:\n  bundleIdPrefix: com.lifelogger\n  developmentRegion: en\n",
        )
        yml.write_text(yml_text, encoding="utf-8")
        print("Updated project.yml")

    print("Phase 1 done")


if __name__ == "__main__":
    main()
