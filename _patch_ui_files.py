#!/usr/bin/env python3
"""Replace hardcoded Hangul UI strings with L10n.tr in the full project."""
from __future__ import annotations

from pathlib import Path

PROJ = Path("/Users/taehyeonkim/Desktop/project/life loging")


def write(rel: str, content: str) -> None:
    path = PROJ / rel
    path.write_text(content, encoding="utf-8")
    print(f"Wrote {rel}")


def patch_file(rel: str, replacements: list[tuple[str, str]]) -> None:
    path = PROJ / rel
    text = path.read_text(encoding="utf-8")
    original = text
    for old, new in replacements:
        count = text.count(old)
        if count == 0:
            print(f"WARN {rel}: missing {old[:70]!r}")
        else:
            text = text.replace(old, new)
    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"Patched {rel}")
    else:
        print(f"No change {rel}")


def patch_category_bar_chart() -> None:
    rel = "LifeLogger/UI/Dashboard/CategoryBarChartView.swift"
    path = PROJ / rel
    text = path.read_text(encoding="utf-8")

    reps = [
        ('LiquidGlassSectionHeader(title: "카테고리별 시간", systemImage: "chart.bar.fill")',
         'LiquidGlassSectionHeader(title: L10n.tr("chart.categoryTime"), systemImage: "chart.bar.fill")'),
        ('Text("데이터 수집 중...")', 'Text(L10n.tr("chart.collecting"))'),
        ('x: .value("시간", item.hours),\n                        y: .value("카테고리", item.category.rawValue)',
         'x: .value(L10n.tr("chart.axis.time"), item.hours),\n                        y: .value(L10n.tr("chart.axis.category"), item.category.localizedName)'),
        ('LiquidGlassSectionHeader(title: "오늘 많이 쓴 앱", systemImage: "square.stack.3d.up.fill")',
         'LiquidGlassSectionHeader(title: L10n.tr("chart.topApps"), systemImage: "square.stack.3d.up.fill")'),
        ('Text("주간 리포트")', 'Text(L10n.tr("dashboard.weeklyReport"))'),
        ('Text("최근 7일 몰입 흐름 회고")', 'Text(L10n.tr("report.subtitle"))'),
        ('Button("닫기") { dismiss() }', 'Button(L10n.tr("common.close")) { dismiss() }'),
        ('metric(title: "주간 집중", value: DurationFormat.hoursMinutes(weekFocusSeconds))',
         'metric(title: L10n.tr("report.weekFocus"), value: DurationFormat.hoursMinutes(weekFocusSeconds))'),
        ('metric(title: "평균 집중률", value: "\\(Int(averageRatio * 100))%")',
         'metric(title: L10n.tr("report.avgFocus"), value: "\\(Int(averageRatio * 100))%")'),
        ('metric(title: "최고의 날", value: bestDayLabel)',
         'metric(title: L10n.tr("report.bestDay"), value: bestDayLabel)'),
        ('LiquidGlassSectionHeader(title: "일별 집중률", systemImage: "chart.xyaxis.line")',
         'LiquidGlassSectionHeader(title: L10n.tr("report.dailyFocus"), systemImage: "chart.xyaxis.line")'),
        ('x: .value("요일", item.day),\n                    y: .value("집중률", item.ratio)',
         'x: .value(L10n.tr("chart.axis.weekday"), item.day),\n                    y: .value(L10n.tr("chart.axis.focusRatio"), item.ratio)'),
        ('LiquidGlassSectionHeader(title: "몰입 골든타임", systemImage: "sparkles")',
         'LiquidGlassSectionHeader(title: L10n.tr("report.goldenTime"), systemImage: "sparkles")'),
        ('Text("\\(insight.weekdayName) \\(insight.bestHour)시 전후")',
         'Text(L10n.tr("report.goldenAround", insight.weekdayName, insight.bestHour))'),
        ('Text("이 시간대 집중 성공률이 \\(Int(insight.successProbability * 100))%로 가장 높아요.")',
         'Text(L10n.tr("report.goldenDetail", Int(insight.successProbability * 100)))'),
        ('LiquidGlassSectionHeader(title: "이번 주 회고", systemImage: "text.book.closed.fill")',
         'LiquidGlassSectionHeader(title: L10n.tr("report.weekJournal"), systemImage: "text.book.closed.fill")'),
        ('Text("이번 주 작성한 회고가 없습니다.")', 'Text(L10n.tr("report.weekJournalEmpty"))'),
        ('f.locale = Locale(identifier: "ko_KR")\n        return f.string(from: date)',
         'f.locale = AppLanguageStore.shared.effectiveLanguage.locale\n        return f.string(from: date)'),
        ('formatter.locale = Locale(identifier: "ko_KR")\n        formatter.dateFormat = "E"',
         'formatter.locale = AppLanguageStore.shared.effectiveLanguage.locale\n        formatter.dateFormat = "E"'),
        ('bestDayLabel = formatter.string(from: dayDate) + "요일"',
         'bestDayLabel = formatter.string(from: dayDate) + L10n.tr("report.weekdaySuffix")'),
        ('LiquidGlassSectionHeader(title: "집중 히트맵", systemImage: "calendar")',
         'LiquidGlassSectionHeader(title: L10n.tr("heatmap.title"), systemImage: "calendar")'),
        ('Button("전체 보기", action: onOpenSheet)', 'Button(L10n.tr("heatmap.viewAll"), action: onOpenSheet)'),
        ('Text("집중 히트맵")', 'Text(L10n.tr("heatmap.title"))'),
        ('Button("닫기") { dismiss() }.buttonStyle(LiquidGlassSecondaryButtonStyle())',
         'Button(L10n.tr("common.close")) { dismiss() }.buttonStyle(LiquidGlassSecondaryButtonStyle())'),
        ('f.locale = Locale(identifier: "ko_KR")\n        return "\\(f.string(from: day.date))\\n집중 \\(DurationFormat.hoursMinutes(day.focusSeconds)) · \\(Int(day.focusRatio * 100))%"',
         'f.locale = AppLanguageStore.shared.effectiveLanguage.locale\n        return L10n.tr("heatmap.tooltip", f.string(from: day.date), DurationFormat.hoursMinutes(day.focusSeconds), Int(day.focusRatio * 100))'),
        ('LiquidGlassSectionHeader(title: "딥워크 세션", systemImage: "brain.head.profile")',
         'LiquidGlassSectionHeader(title: L10n.tr("deepwork.title"), systemImage: "brain.head.profile")'),
        ('Text("오늘 \\(sessions.count)회 · 최장 \\(DurationFormat.hoursMinutes(longest)) · 총 \\(DurationFormat.hoursMinutes(total))")',
         'Text(L10n.tr("deepwork.summary", sessions.count, DurationFormat.hoursMinutes(longest), DurationFormat.hoursMinutes(total)))'),
        ('Text("25분 이상 끊김 없는 집중 블록이 없어요.")', 'Text(L10n.tr("deepwork.empty"))'),
        ('LiquidGlassSectionHeader(title: "집중 깊이", systemImage: "gauge.with.dots.needle.67percent")',
         'LiquidGlassSectionHeader(title: L10n.tr("depth.title"), systemImage: "gauge.with.dots.needle.67percent")'),
        ('Text("시간당 평균 \\(String(format: "%.1f", metrics.switchesPerHour))회 앱 전환")',
         'Text(String(format: L10n.tr("depth.switches"), metrics.switchesPerHour))'),
        ('LiquidGlassSectionHeader(title: "이번 주 vs 지난 주", systemImage: "arrow.left.arrow.right")',
         'LiquidGlassSectionHeader(title: L10n.tr("weekCompare.title"), systemImage: "arrow.left.arrow.right")'),
        ('Text(String(format: "집중률 %+.0f%%p", delta))',
         'Text(String(format: L10n.tr("weekCompare.delta"), delta))'),
        ('Text(cat.rawValue)', 'Text(cat.localizedName)'),
        ('LiquidGlassSectionHeader(title: "오늘 시간대별 집중", systemImage: "clock.fill")',
         'LiquidGlassSectionHeader(title: L10n.tr("hourly.title"), systemImage: "clock.fill")'),
        ('AreaMark(x: .value("시", item.hour), y: .value("집중률", item.focusRatio))',
         'AreaMark(x: .value(L10n.tr("chart.axis.hour"), item.hour), y: .value(L10n.tr("chart.axis.focusRatio"), item.focusRatio))'),
        ('LineMark(x: .value("시", item.hour), y: .value("집중률", item.focusRatio))',
         'LineMark(x: .value(L10n.tr("chart.axis.hour"), item.hour), y: .value(L10n.tr("chart.axis.focusRatio"), item.focusRatio))'),
        ('LiquidGlassSectionHeader(title: "프로젝트별 시간", systemImage: "folder.fill")',
         'LiquidGlassSectionHeader(title: L10n.tr("project.title"), systemImage: "folder.fill")'),
        ('Picker("기간", selection: $rangeDays) {\n                    Text("오늘").tag(1)\n                    Text("7일").tag(7)\n                    Text("30일").tag(30)',
         'Picker(L10n.tr("project.range"), selection: $rangeDays) {\n                    Text(L10n.tr("project.today")).tag(1)\n                    Text(L10n.tr("project.7d")).tag(7)\n                    Text(L10n.tr("project.30d")).tag(30)'),
        ('Text("세그먼트에 태그를 추가하면 프로젝트별로 모아요.")', 'Text(L10n.tr("project.empty"))'),
        ('LiquidGlassSectionHeader(title: "오늘의 회고", systemImage: "text.book.closed.fill")',
         'LiquidGlassSectionHeader(title: L10n.tr("journal.title"), systemImage: "text.book.closed.fill")'),
        ('TextField("한 줄 회고를 남겨보세요", text: $todayText, axis: .vertical)',
         'TextField(L10n.tr("journal.placeholder"), text: $todayText, axis: .vertical)'),
        ('f.locale = Locale(identifier: "ko_KR")\n        return f.string(from: date)\n    }\n}\n\n// MARK: - #14',
         'f.locale = AppLanguageStore.shared.effectiveLanguage.locale\n        return f.string(from: date)\n    }\n}\n\n// MARK: - #14'),
        ('Text("LifeLogger · 오늘 요약")', 'Text(L10n.tr("summary.title"))'),
        ('Text("\\(Int(focusRatio * 100))% 집중")', 'Text(L10n.tr("summary.focusPercent", Int(focusRatio * 100)))'),
        ('Text(DurationFormat.hoursMinutes(focusSeconds) + " 집중 · 딥워크 \\(deepWorkCount)회 · 깊이 \\(depthScore)")',
         'Text(L10n.tr("summary.detail", DurationFormat.hoursMinutes(focusSeconds), deepWorkCount, depthScore))'),
        ('guard let image = renderPNG(from: view) else { return "이미지 생성 실패" }',
         'guard let image = renderPNG(from: view) else { return L10n.tr("summary.renderFailed") }'),
        ('return "클립보드에 복사했습니다."', 'return L10n.tr("summary.copied")'),
        ('panel.title = "요약 카드 저장"', 'panel.title = L10n.tr("summary.saveTitle")'),
        ('let png = rep.representation(using: .png, properties: [:]) else { return "PNG 변환 실패" }',
         'let png = rep.representation(using: .png, properties: [:]) else { return L10n.tr("summary.pngFailed") }'),
        ('return "저장 완료: \\(url.lastPathComponent)"', 'return L10n.tr("summary.saved", url.lastPathComponent)'),
        ('return "저장 실패: \\(error.localizedDescription)"', 'return L10n.tr("summary.saveFailed", error.localizedDescription)'),
        ('Text("LifeLogger 시작하기")', 'Text(L10n.tr("onboarding.title"))'),
        ('title: "손쉬운 사용",\n                    detail: "창 제목 추적에 필요합니다.",',
         'title: L10n.tr("onboarding.accessibility.title"),\n                    detail: L10n.tr("onboarding.accessibility.detail"),'),
        ('title: "알림",\n                    detail: "뽀모도로·넛지·휴식 알림에 사용됩니다.",',
         'title: L10n.tr("onboarding.notifications.title"),\n                    detail: L10n.tr("onboarding.notifications.detail"),'),
        ('Button("시작하기") {', 'Button(L10n.tr("onboarding.getStarted")) {'),
        ('Button("시스템 설정 열기") { NSWorkspace.shared.open(url) }',
         'Button(L10n.tr("onboarding.openSystemSettings")) { NSWorkspace.shared.open(url) }'),
        ('Text("오늘 집중")', 'Text(L10n.tr("menubar.popover.focusToday"))'),
        ('Button(tracker.isTracking ? "일시정지" : "시작") {',
         'Button(tracker.isTracking ? L10n.tr("menubar.popover.pause") : L10n.tr("menubar.popover.start")) {'),
    ]

    original = text
    for old, new in reps:
        if old not in text:
            print(f"WARN CategoryBarChart missing: {old[:80]!r}")
        else:
            text = text.replace(old, new)
    # Comment-only Hangul is fine; leave MARK comments
    path.write_text(text, encoding="utf-8")
    print(f"Patched {rel} ({'changed' if text != original else 'same'})")


def patch_activity_category() -> None:
    # Keep raw values Korean for SwiftData; document localizedName in Shared via comment
    # Move localizedName into Shared would break widget without L10n - keep extension.
    # Add note in ActivityCategory.swift and ensure bloomie stays Korean.
    path = PROJ / "Shared/ActivityCategory.swift"
    text = path.read_text(encoding="utf-8")
    if "localizedName" not in text:
        # Add a pointer comment only
        text = text.replace(
            "enum ActivityCategory: String, Codable, CaseIterable, Sendable {",
            "/// Display names: use `localizedName` (see ActivityCategory+Localized). Raw values stay Korean for persisted data compatibility.\nenum ActivityCategory: String, Codable, CaseIterable, Sendable {",
        )
        path.write_text(text, encoding="utf-8")
        print("Annotated ActivityCategory.swift")


def patch_rest() -> None:
    patch_file(
        "LifeLogger/UI/Dashboard/CurrentActivityCardView.swift",
        [
            ('metaChip(icon: "target", text: "오늘 \\(snapshot.focusPercentLabel)")',
             'metaChip(icon: "target", text: L10n.tr("activity.focusToday", snapshot.focusPercentLabel))'),
        ],
    )
    patch_file(
        "LifeLogger/UI/Dashboard/FocusRingView.swift",
        [
            ('Text("목표 \\(DailyFocusGoalStore.label(forMinutes: goalMinutes))")',
             'Text(L10n.tr("focus.goal.prefix", DailyFocusGoalStore.label(forMinutes: goalMinutes)))'),
            ('Text("직접 조절 · \\(Int(draftMinutes))분")',
             'Text(L10n.tr("focus.goal.custom", Int(draftMinutes)))'),
        ],
    )
    patch_file(
        "LifeLogger/UI/Notch/NotchHUDView.swift",
        [
            ("Text(tracker.currentCategory.rawValue)", "Text(tracker.currentCategory.localizedName)"),
            ('.help("친구에게 공유")', '.help(L10n.tr("notch.shareHelp"))'),
            ('if tracker.isAFK { return "자리 비움" }\n        if tracker.currentAppName.isEmpty { return "분석 중…" }',
             'if tracker.isAFK { return L10n.tr("status.afk") }\n        if tracker.currentAppName.isEmpty { return L10n.tr("status.analyzing") }'),
        ],
    )
    patch_file(
        "LifeLogger/UI/Components/LiquidGlassStyle.swift",
        [
            ("var title: String {\n        switch self {\n        case .deepOcean: return \"딥 오션\"\n        case .midnight: return \"미드나잇\"\n        case .forest: return \"포레스트\"\n        }\n    }",
             "@MainActor\n    var title: String {\n        switch self {\n        case .deepOcean: return L10n.tr(\"theme.deepOcean\")\n        case .midnight: return L10n.tr(\"theme.midnight\")\n        case .forest: return L10n.tr(\"theme.forest\")\n        }\n    }"),
        ],
    )
    patch_file(
        "LifeLogger/Core/Pomodoro/PomodoroTimer.swift",
        [
            ("var displayName: String {\n        switch self {\n        case .idle: return \"대기\"\n        case .focus: return \"집중\"\n        case .shortBreak: return \"휴식\"\n        case .longBreak: return \"긴 휴식\"\n        }\n    }",
             "@MainActor\n    var displayName: String {\n        switch self {\n        case .idle: return L10n.tr(\"pomodoro.phase.idle\")\n        case .focus: return L10n.tr(\"pomodoro.phase.focus\")\n        case .shortBreak: return L10n.tr(\"pomodoro.phase.shortBreak\")\n        case .longBreak: return L10n.tr(\"pomodoro.phase.longBreak\")\n        }\n    }"),
            ('title: "집중 완료!",\n                body: "5분 휴식을 시작하세요."',
             'title: L10n.tr("pomodoro.notify.focusDoneTitle"),\n                body: L10n.tr("pomodoro.notify.focusDoneBody")'),
            ('title: "휴식 종료",\n                body: "다시 집중 시간을 시작합니다."',
             'title: L10n.tr("pomodoro.notify.breakDoneTitle"),\n                body: L10n.tr("pomodoro.notify.breakDoneBody")'),
            ('content.title = "집중 시간 종료"\n            content.body = "잘하셨어요! 휴식을 취하세요."',
             'content.title = L10n.tr("pomodoro.notify.focusEndTitle")\n            content.body = L10n.tr("pomodoro.notify.focusEndBody")'),
            ('content.title = "휴식 종료"\n            content.body = "다시 집중해볼까요?"',
             'content.title = L10n.tr("pomodoro.notify.breakDoneTitle")\n            content.body = L10n.tr("pomodoro.notify.breakEndBody")'),
        ],
    )

    # DailyFocusGoalStore + CurrentActivityShareService status strings
    patch_file(
        "LifeLogger/Core/Sharing/CurrentActivityShareService.swift",
        [
            ('static func label(forMinutes minutes: Int) -> String {\n        if minutes % 60 == 0 { return "\\(minutes / 60)시간" }\n        return "\\(minutes / 60)시간 \\(minutes % 60)분"\n    }',
             '@MainActor\n    static func label(forMinutes minutes: Int) -> String {\n        if minutes % 60 == 0 { return L10n.tr("focus.goal.hours", minutes / 60) }\n        return L10n.tr("focus.goal.hoursMinutes", minutes / 60, minutes % 60)\n    }'),
            ('if !isTracking { return "일시정지" }\n        if isAFK { return "자리 비움" }\n        if appName.isEmpty { return "분석 중…" }\n        return "진행 중"',
             'if !isTracking { return L10n.tr("status.paused") }\n        if isAFK { return L10n.tr("status.afk") }\n        if appName.isEmpty { return L10n.tr("status.analyzing") }\n        return L10n.tr("status.active")'),
            ('if isAFK { return "자리 비움" }\n        if appName.isEmpty { return "활동 감지 중…" }',
             'if isAFK { return L10n.tr("status.afk") }\n        if appName.isEmpty { return L10n.tr("status.detecting") }'),
            ('if isAFK { return "잠시 멀어져 있어요" }',
             'if isAFK { return L10n.tr("status.afkSubtitle") }'),
            ('if !isTracking { return "멈춤" }\n        if isAFK { return "자리 비움" }\n        switch elapsedSeconds {\n        case ..<120: return "막 시작"\n        case 120..<600: return "흐름 타는 중"\n        case 600..<1800: return "몰입 중"\n        case 1800..<3600: return "깊이 들어감"\n        default: return "오래 이어짐"',
             'if !isTracking { return L10n.tr("status.stopped") }\n        if isAFK { return L10n.tr("status.afk") }\n        switch elapsedSeconds {\n        case ..<120: return L10n.tr("status.justStarted")\n        case 120..<600: return L10n.tr("status.warmingUp")\n        case 600..<1800: return L10n.tr("status.inFlow")\n        case 1800..<3600: return L10n.tr("status.deepIn")\n        default: return L10n.tr("status.longStretch")'),
            ('if !isTracking { return "일시정지" }\n        if isAFK { return "쉬는 중" }\n        switch focusRatioToday {\n        case 0.75...: return "몰입 흐름 좋음"\n        case 0.55..<0.75: return "리듬 유지 중"\n        case 0.35..<0.55: return "조금만 더"\n        case 0.15..<0.35: return "가볍게 시작"\n        default: return "천천히 가도 OK"',
             'if !isTracking { return L10n.tr("status.paused") }\n        if isAFK { return L10n.tr("status.resting") }\n        switch focusRatioToday {\n        case 0.75...: return L10n.tr("mood.greatFlow")\n        case 0.55..<0.75: return L10n.tr("mood.steady")\n        case 0.35..<0.55: return L10n.tr("mood.pushABit")\n        case 0.15..<0.35: return L10n.tr("mood.lightStart")\n        default: return L10n.tr("mood.slowOk")'),
        ],
    )

    # Make status/mood/format helpers MainActor-aware by marking the computed props
    # They already call L10n which is MainActor - need @MainActor on the props
    path = PROJ / "LifeLogger/Core/Sharing/CurrentActivityShareService.swift"
    t = path.read_text(encoding="utf-8")
    for prop in ["statusLabel", "headline", "subtitle", "elapsedHumanLabel", "focusMoodLabel"]:
        # already may have been partially done; ensure @MainActor on var
        pass
    # Patch formatShareText section if still Korean
    reps2 = [
        ('return "지금 공유할 활동이 없습니다."', 'return L10n.tr("share.noActivity")'),
        ('? "작업: (제목 없음)"\n            : "작업: \\(snapshot.windowTitle)"',
         '? L10n.tr("share.taskNone")\n            : L10n.tr("share.task", snapshot.windowTitle)'),
        ('return .failed("공유할 활동이 없습니다.")', 'return .failed(L10n.tr("share.failedNoActivity"))'),
        ('return "bloomie로 현재 활동을 공유했습니다."', 'return L10n.tr("share.bloomieShared")'),
    ]
    for old, new in reps2:
        if old in t:
            t = t.replace(old, new)
    # Replace the multi-line share text builder carefully
    old_block = '''        text += """
        📍 지금 하고 있는 일
        앱: \\(snapshot.appName)
        \\(taskLine)
        카테고리: \\(snapshot.category.rawValue)
        이 활동: \\(snapshot.elapsedLabel)
        오늘 집중: \\(snapshot.focusPercentLabel)
        """'''
    # Read actual content around share formatting
    path.write_text(t, encoding="utf-8")

    # Desktop widget guide
    path = PROJ / "LifeLogger/UI/Dashboard/DesktopWidgetGuideView.swift"
    t = path.read_text(encoding="utf-8")
    reps = [
        ('Text("바탕화면 위젯 추가")', 'Text(L10n.tr("widgetGuide.title"))'),
        ('Text("LifeLogger 위젯을 Mac 바탕화면에 고정하세요.")', 'Text(L10n.tr("widgetGuide.subtitle"))'),
        ('guideStep(number: 1, text: "바탕화면 빈 곳에서 Control + 클릭 (또는 우클릭)")',
         'guideStep(number: 1, text: L10n.tr("widgetGuide.step1"))'),
        ('guideStep(number: 2, text: "「위젯 편집…」 선택")',
         'guideStep(number: 2, text: L10n.tr("widgetGuide.step2"))'),
        ('guideStep(number: 3, text: "검색창에 「LifeLogger」 입력")',
         'guideStep(number: 3, text: L10n.tr("widgetGuide.step3"))'),
        ('guideStep(number: 4, text: "원하는 크기(작음/중간/큼)를 바탕화면으로 드래그")',
         'guideStep(number: 4, text: L10n.tr("widgetGuide.step4"))'),
        ('LiquidGlassSectionHeader(title: "추천 위젯", systemImage: "sparkles")',
         'LiquidGlassSectionHeader(title: L10n.tr("widgetGuide.recommended"), systemImage: "sparkles")'),
        ('Label("LifeLogger · 바탕화면 — 작은 크기, ▶️/⏸️ 버튼 포함", systemImage: "square.grid.2x2")',
         'Label(L10n.tr("widgetGuide.recDesktop"), systemImage: "square.grid.2x2")'),
        ('Label("LifeLogger — 중/대형, 7일 추세 차트 포함", systemImage: "chart.line.uptrend.xyaxis")',
         'Label(L10n.tr("widgetGuide.recMain"), systemImage: "chart.line.uptrend.xyaxis")'),
        ('Text("앱이 실행 중일 때 데이터가 자동으로 갱신됩니다.")', 'Text(L10n.tr("widgetGuide.footer"))'),
        ('Button("닫기") { dismiss() }', 'Button(L10n.tr("common.close")) { dismiss() }'),
    ]
    for old, new in reps:
        if old not in t:
            print(f"WARN DesktopWidgetGuide: {old[:60]!r}")
        t = t.replace(old, new)
    path.write_text(t, encoding="utf-8")
    print("Patched DesktopWidgetGuideView")


def patch_category_settings() -> None:
    path = PROJ / "LifeLogger/UI/Settings/CategorySettingsView.swift"
    t = path.read_text(encoding="utf-8")
    reps = [
        ('Button("추가") {', 'Button(L10n.tr("common.add")) {'),
        ('TextField("앱/창 키워드", text: $newPattern)', 'TextField(L10n.tr("settings.rules.keyword"), text: $newPattern)'),
        ('Picker("카테고리", selection: $newCategory) {', 'Picker(L10n.tr("settings.rules.category"), selection: $newCategory) {'),
        ("Text(category.rawValue).tag(category)", "Text(category.localizedName).tag(category)"),
        ('Button("규칙 추가") {', 'Button(L10n.tr("settings.rules.addRule")) {'),
        ('Text("비집중 활동이 길어지면 알림")', 'Text(L10n.tr("settings.nudge.title"))'),
        ('Text("기준 시간: \\(Int(nudgeMinutes))분")', 'Text(L10n.tr("settings.nudge.threshold", Int(nudgeMinutes)))'),
        ('Text("커뮤니케이션·브라우징·엔터테인먼트 등에 \\(Int(nudgeMinutes))분 이상 연속으로 머물면 한 번 알려줘요.")',
         'Text(L10n.tr("settings.nudge.detail", Int(nudgeMinutes)))'),
        ('Text("연속 몰입 시 눈 쉬기 알림")', 'Text(L10n.tr("settings.rest.title"))'),
        ('Text("기준: \\(Int(restMinutes))분")', 'Text(L10n.tr("settings.rest.threshold", Int(restMinutes)))'),
        ('TextField("앱 이름 (예: Zoom)", text: $pauseAppInput)',
         'TextField(L10n.tr("settings.pauseApp.placeholder"), text: $pauseAppInput)'),
        ('Button("삭제") {', 'Button(L10n.tr("settings.pauseApp.delete")) {'),
        ('Text("점심 시간(12:00–13:00) 등 시간대 규칙은 추후 확장 가능합니다.")',
         'Text(L10n.tr("settings.pauseApp.note"))'),
        ('Text("오래된 기록 자동 삭제")', 'Text(L10n.tr("settings.retention.title"))'),
        ('Text("보존 기간: \\(Int(retentionDays))일")', 'Text(L10n.tr("settings.retention.days", Int(retentionDays)))'),
        ('Button("지금 정리 미리보기") {', 'Button(L10n.tr("settings.retention.preview")) {'),
        ('Text("\\(count)개 기록이 삭제 대상입니다.")', 'Text(L10n.tr("settings.retention.count", count))'),
        ('SecureField("백업 암호", text: $backupPassword)', 'SecureField(L10n.tr("settings.backup.password"), text: $backupPassword)'),
        ('Button("백업 내보내기") { runBackupExport() }', 'Button(L10n.tr("settings.backup.export")) { runBackupExport() }'),
        ('Button("가져오기(병합)") { runBackupImport(merge: true) }',
         'Button(L10n.tr("settings.backup.importMerge")) { runBackupImport(merge: true) }'),
        ('Button("가져오기(덮어쓰기)") { runBackupImport(merge: false) }',
         'Button(L10n.tr("settings.backup.importOverwrite")) { runBackupImport(merge: false) }'),
        ('Text("AES-GCM 암호화 · 기기 이전용 풀 백업")', 'Text(L10n.tr("settings.backup.note"))'),
        ('Text("전역 단축키 사용")', 'Text(L10n.tr("settings.hotkeys.title"))'),
        ('Text("⌃⌥L — 트래킹 토글 · ⌃⌥P — 뽀모도로 시작/정지")', 'Text(L10n.tr("settings.hotkeys.detail"))'),
        ('Picker("테마", selection: $themePreset) {', 'Picker(L10n.tr("settings.theme"), selection: $themePreset) {'),
        ('Text("집중 모드 켜짐 시 자동 트래킹")', 'Text(L10n.tr("settings.focusMode.title"))'),
        ('Text("공개 API 한계로 휴리스틱 신호를 사용합니다. 불안정하면 끄세요.")',
         'Text(L10n.tr("settings.focusMode.detail"))'),
        ('backupMessage = "백업 완료: \\(name)"', 'backupMessage = L10n.tr("settings.backup.done", name)'),
        ('backupMessage = "\\(count)개 기록을 가져왔습니다."', 'backupMessage = L10n.tr("settings.backup.imported", count)'),
        ('Text("등록된 규칙이 없습니다.")', 'Text(L10n.tr("settings.rules.empty"))'),
        ("LiquidGlassBadge(text: rule.category.rawValue,", "LiquidGlassBadge(text: rule.category.localizedName,"),
        ('Text("✅ 코딩, 디자인, 문서·글쓰기")', 'Text(L10n.tr("settings.focusCats"))'),
        ('Text("❌ 커뮤니케이션, 브라우징, 엔터테인먼트, 기타")', 'Text(L10n.tr("settings.nonFocusCats"))'),
    ]
    for old, new in reps:
        if old not in t:
            print(f"WARN CategorySettings: {old[:70]!r}")
        else:
            t = t.replace(old, new)
    path.write_text(t, encoding="utf-8")
    print("Patched CategorySettingsView")


def patch_widgets() -> None:
    path = PROJ / "LifeLoggerWidget/LifeLoggerWidgetViews.swift"
    t = path.read_text(encoding="utf-8")
    reps = [
        ('Text("오늘 집중")', 'Text(L10n.tr("widget.focusToday"))'),
        ('Text(entry.stats.isTrackingEnabled ? "추적 중" : "일시정지")',
         'Text(entry.stats.isTrackingEnabled ? L10n.tr("widget.tracking") : L10n.tr("widget.paused"))'),
        ('WidgetStatBlock(title: "집중", value: formatDuration(entry.stats.todayFocusSeconds))',
         'WidgetStatBlock(title: L10n.tr("widget.focus"), value: formatDuration(entry.stats.todayFocusSeconds))'),
        ('WidgetStatBlock(title: "전체", value: formatDuration(entry.stats.todayTotalSeconds))',
         'WidgetStatBlock(title: L10n.tr("widget.total"), value: formatDuration(entry.stats.todayTotalSeconds))'),
        ('isTracking ? "일시정지" : "시작",',
         'isTracking ? L10n.tr("widget.pause") : L10n.tr("widget.start"),'),
        ('Text("현재 앱")', 'Text(L10n.tr("widget.currentApp"))'),
    ]
    for old, new in reps:
        if old not in t:
            print(f"WARN WidgetViews: {old[:60]!r}")
        t = t.replace(old, new)
    path.write_text(t, encoding="utf-8")
    print("Patched LifeLoggerWidgetViews")

    path = PROJ / "LifeLoggerWidget/LifeLoggerWidget.swift"
    t = path.read_text(encoding="utf-8")
    reps = [
        ('.description("바탕화면에서 집중 비율을 확인하고 트래킹을 제어하세요.")',
         '.description(L10n.tr("widget.description"))'),
        ('.configurationDisplayName("LifeLogger · 바탕화면")',
         '.configurationDisplayName(L10n.tr("widget.desktopName"))'),
        ('.description("작은 크기로 바탕화면에 고정하기 좋은 집중 위젯입니다.")',
         '.description(L10n.tr("widget.desktopDescription"))'),
    ]
    for old, new in reps:
        if old not in t:
            print(f"WARN Widget: {old[:60]!r}")
        t = t.replace(old, new)
    # Also first configurationDisplayName if Korean elsewhere
    path.write_text(t, encoding="utf-8")
    print("Patched LifeLoggerWidget")

    path = PROJ / "LifeLoggerWidget/ToggleTrackingIntent.swift"
    t = path.read_text(encoding="utf-8")
    # App Intents LocalizedStringResource - use English defaults (dev region en)
    reps = [
        ('static let title: LocalizedStringResource = "트래킹 토글"',
         'static let title: LocalizedStringResource = "Toggle Tracking"'),
        ('static let description = IntentDescription("LifeLogger 활동 추적을 켜거나 끕니다.")',
         'static let description = IntentDescription("Turn LifeLogger activity tracking on or off.")'),
        ('static let title: LocalizedStringResource = "LifeLogger 위젯"',
         'static let title: LocalizedStringResource = "LifeLogger Widget"'),
    ]
    for old, new in reps:
        if old not in t:
            print(f"WARN Intent: {old[:60]!r}")
        t = t.replace(old, new)
    path.write_text(t, encoding="utf-8")
    print("Patched ToggleTrackingIntent")


def patch_tracker_notifications() -> None:
    path = PROJ / "LifeLogger/Core/Tracking/ActivityTracker.swift"
    t = path.read_text(encoding="utf-8")
    # Read the notification section for exact text
    reps = [
        ('content.title = "잠깐, 눈을 쉬어요"', 'content.title = L10n.tr("notify.eyeRest.title")'),
        ('? "오래 집중하고 있어요. 20초만 멀리 바라볼까요?"\n            : "오래 집중 중이에요. 목표 \'\\(goal)\' — 잠깐 스트레칭 어때요?"',
         '? L10n.tr("notify.eyeRest.body")\n            : L10n.tr("notify.eyeRest.bodyGoal", goal)'),
        ('content.title = "잠깐, 집중 흐름 체크"', 'content.title = L10n.tr("notify.nudge.title")'),
        ('content.body = "\\(categoryName)에 \\(minutes)분 넘게 머물고 있어요. 다시 집중으로 돌아올까요?"',
         'content.body = L10n.tr("notify.nudge.body", categoryName, minutes)'),
        ('content.body = "\\(minutes)분째 \\(categoryName) 중이에요. 오늘 목표: \\(goal)"',
         'content.body = L10n.tr("notify.nudge.bodyGoal", minutes, categoryName, goal)'),
        ("let categoryName = currentCategory.rawValue", "let categoryName = currentCategory.localizedName"),
    ]
    for old, new in reps:
        if old not in t:
            print(f"WARN ActivityTracker: {old[:80]!r}")
        else:
            t = t.replace(old, new)
    path.write_text(t, encoding="utf-8")
    print("Patched ActivityTracker")


def patch_share_text_builder() -> None:
    path = PROJ / "LifeLogger/Core/Sharing/CurrentActivityShareService.swift"
    t = path.read_text(encoding="utf-8")
    # Find and replace the share text composition
    import re
    # Look for Korean share template
    pattern = re.compile(
        r'(text \+= """\n)[\s\S]*?(LifeLogger에서 공유됨)"""',
        re.M,
    )
    m = pattern.search(t)
    if m:
        replacement = '''text += """
        \\(L10n.tr("share.nowDoing"))
        \\(L10n.tr("share.app", snapshot.appName))
        \\(taskLine)
        \\(L10n.tr("share.category", snapshot.category.localizedName))
        \\(L10n.tr("share.thisActivity", snapshot.elapsedLabel))
        \\(L10n.tr("share.todayFocus", snapshot.focusPercentLabel))
        """'''
        # Actually simpler approach - replace line by line in the block
        pass

    # Simpler line replacements
    line_reps = [
        ("카테고리: \\(snapshot.category.rawValue)", '\\(L10n.tr("share.category", snapshot.category.localizedName))'),
        ("📍 지금 하고 있는 일", '\\(L10n.tr("share.nowDoing"))'),
        ("앱: \\(snapshot.appName)", '\\(L10n.tr("share.app", snapshot.appName))'),
        ("이 활동: \\(snapshot.elapsedLabel)", '\\(L10n.tr("share.thisActivity", snapshot.elapsedLabel))'),
        ("오늘 집중: \\(snapshot.focusPercentLabel)", '\\(L10n.tr("share.todayFocus", snapshot.focusPercentLabel))'),
        ('text += "\\n오늘 목표: \\(goal)"', 'text += "\\n" + L10n.tr("share.todayGoal", goal)'),
        ('text += "\\n\\nLifeLogger에서 공유됨"', 'text += "\\n\\n" + L10n.tr("share.viaLifeLogger")'),
        ('return "bloomie 앱을 찾을 수 없어 클립보드에 복사했습니다.\\n\\n\\(text)"',
         'return L10n.tr("share.bloomieClipboard", text)'),
    ]
    for old, new in line_reps:
        if old not in t:
            print(f"WARN share text: {old[:60]!r}")
        else:
            t = t.replace(old, new)

    # Mark computed properties that use L10n as @MainActor
    for name in ["var statusLabel:", "var headline:", "var subtitle:", "var elapsedHumanLabel:", "var focusMoodLabel:"]:
        annotated = "@MainActor\n    " + name
        if annotated not in t and name in t:
            t = t.replace(name, annotated, 1)

    path.write_text(t, encoding="utf-8")
    print("Patched share text builder")


def patch_control_strip() -> None:
    path = PROJ / "LifeLogger/UI/Features/ControlStripFallbackView.swift"
    if not path.exists():
        return
    t = path.read_text(encoding="utf-8")
    old = 'FeatureMetricsStore.string("context.currentTag", default: tracker.currentCategory.rawValue)'
    new = 'FeatureMetricsStore.string("context.currentTag", default: tracker.currentCategory.localizedName)'
    if old in t:
        path.write_text(t.replace(old, new), encoding="utf-8")
        print("Patched ControlStripFallbackView")


def main() -> None:
    patch_category_bar_chart()
    patch_activity_category()
    patch_rest()
    patch_category_settings()
    patch_widgets()
    patch_tracker_notifications()
    patch_share_text_builder()
    patch_control_strip()
    print("UI patch complete")


if __name__ == "__main__":
    main()
