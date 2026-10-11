import SwiftUI
import SwiftData
import AppKit

struct CategorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategoryMappingRule.priority, order: .reverse) private var rules: [CategoryMappingRule]
    @ObservedObject private var languageStore = AppLanguageStore.shared

    @State private var selectedLanguage = AppLanguageStore.shared.language

    @State private var newPattern = ""
    @State private var newCategory: ActivityCategory = .coding
    @State private var nudgeEnabled = DistractionNudgeStore.isEnabled
    @State private var nudgeMinutes = Double(DistractionNudgeStore.thresholdMinutes)
    @State private var restEnabled = RestReminderStore.isEnabled
    @State private var restMinutes = Double(RestReminderStore.thresholdMinutes)
    @State private var retentionEnabled = RetentionPolicyStore.isEnabled
    @State private var retentionDays = Double(RetentionPolicyStore.retentionDays)
    @State private var pauseAppInput = ""
    @State private var pauseApps = AutoPauseRuleStore.pausedAppNames
    @State private var hotkeysEnabled = GlobalHotkeyStore.isEnabled
    @State private var themePreset = GlassThemeStore.preset
    @State private var focusModeEnabled = FocusModeIntegrationStore.isEnabled
    @State private var backupPassword = ""
    @State private var backupMessage: String?
    @State private var showBackupAlert = false
    @State private var purgePreviewCount: Int?
    @State private var messengerConsent = MessengerConsentStore.hasConsented
    @State private var maskAppInput = ""
    @State private var showLanguagePicker = false

    var body: some View {
        ZStack {
            LiquidGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    LiquidGlassSectionHeader(title: L10n.tr("settings.title"), systemImage: "gearshape.fill")
                        .padding(.bottom, 4)

                    languageSection
                    securitySection
                    privacySection
                    mappingSection
                    nudgeSection
                    restSection
                    autoPauseSection
                    retentionSection
                    backupSection
                    hotkeySection
                    themeSection
                    focusModeSection
                    maskingSection
                    rulesSection
                    focusInfoSection
                }
                .padding(24)
            }
        }
        .frame(minWidth: 460, minHeight: 420)
        .id(languageStore.language.rawValue)
        .alert(L10n.tr("settings.backup.title"), isPresented: $showBackupAlert) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(backupMessage ?? "")
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.language.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Text(L10n.tr("settings.language.subtitle"))
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            Picker(L10n.tr("settings.language.title"), selection: $selectedLanguage) {
                ForEach(AppLanguage.userSelectableCases) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            .pickerStyle(.menu)
            .padding(10)
            .liquidGlassInsetPanel(cornerRadius: 10)
            .onChange(of: selectedLanguage) { _, language in
                AppLanguageStore.shared.setLanguage(language)
            }

            Button(L10n.tr("settings.language.chooseTitle")) {
                showLanguagePicker = true
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())
        }
        .padding(20)
        .liquidGlassCard()
        .sheet(isPresented: $showLanguagePicker) {
            LanguageSelectionView(isRequired: false)
        }
        .onAppear { selectedLanguage = languageStore.language }
        .onChange(of: languageStore.language) { _, language in selectedLanguage = language }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.security.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Label(L10n.tr("settings.security.storage"), systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            Label(L10n.tr("settings.security.permissions"), systemImage: "doc.badge.gearshape.fill")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            Label(L10n.tr("settings.security.clipboard"), systemImage: "clipboard")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            if SecurityBootstrap.lastFailureMessage != nil {
                Text(L10n.tr("settings.security.failed"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
            }

            Button(L10n.tr("settings.security.recheck")) {
                SecurityBootstrap.recheck()
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.privacy.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Text(L10n.tr("settings.privacy.localOnly"))
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            Toggle(isOn: $messengerConsent) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.privacy.messenger"))
                        .foregroundStyle(LiquidGlassStyle.bodyText)
                    Text(L10n.tr("settings.privacy.messengerHint"))
                        .font(.caption2)
                        .foregroundStyle(LiquidGlassStyle.tertiaryText)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: messengerConsent) { _, v in
                MessengerConsentStore.hasConsented = v
                if v {
                    BloomieCloudAuthService.shared.configureIfNeeded()
                }
            }

            Button(L10n.tr("settings.privacy.policy")) {
                if let url = Bundle.main.url(forResource: "PRIVACY", withExtension: "md") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(LiquidGlassSecondaryButtonStyle())
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var maskingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.masking.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Text(L10n.tr("settings.masking.subtitle"))
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)

            HStack {
                TextField(L10n.tr("settings.masking.addApp"), text: $maskAppInput)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(fieldBackground)
                Button("추가") {
                    var apps = SensitiveWindowMasking.blockedAppNames
                    let name = maskAppInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !apps.contains(name) else { return }
                    apps.append(name)
                    SensitiveWindowMasking.blockedAppNames = apps
                    maskAppInput = ""
                }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.mapping.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            TextField("앱/창 키워드", text: $newPattern)
                .textFieldStyle(.plain)
                .padding(12)
                .background(fieldBackground)

            Picker("카테고리", selection: $newCategory) {
                ForEach(ActivityCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.menu)
            .padding(12)
            .background(fieldBackground)

            Button("규칙 추가") {
                guard !newPattern.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let store = CategoryMappingStore(modelContext: modelContext)
                store.addRule(pattern: newPattern, category: newCategory)
                newPattern = ""
            }
            .buttonStyle(LiquidGlassPrimaryButtonStyle())
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var nudgeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.nudge.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Toggle(isOn: $nudgeEnabled) {
                Text("비집중 활동이 길어지면 알림")
                    .foregroundStyle(LiquidGlassStyle.bodyText)
            }
            .toggleStyle(.switch)
            .onChange(of: nudgeEnabled) { _, newValue in
                DistractionNudgeStore.isEnabled = newValue
            }

            if nudgeEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Text("기준 시간: \(Int(nudgeMinutes))분")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                    Slider(value: $nudgeMinutes, in: 5...60, step: 5)
                        .onChange(of: nudgeMinutes) { _, newValue in
                            DistractionNudgeStore.thresholdMinutes = Int(newValue)
                        }
                    Text("커뮤니케이션·브라우징·엔터테인먼트 등에 \(Int(nudgeMinutes))분 이상 연속으로 머물면 한 번 알려줘요.")
                        .font(.caption)
                        .foregroundStyle(LiquidGlassStyle.tertiaryText)
                }
            }
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var restSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.rest.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Toggle(isOn: $restEnabled) {
                Text("연속 몰입 시 눈 쉬기 알림")
                    .foregroundStyle(LiquidGlassStyle.bodyText)
            }
            .toggleStyle(.switch)
            .onChange(of: restEnabled) { _, v in RestReminderStore.isEnabled = v }

            if restEnabled {
                Text("기준: \(Int(restMinutes))분")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                Slider(value: $restMinutes, in: 20...90, step: 5)
                    .onChange(of: restMinutes) { _, v in RestReminderStore.thresholdMinutes = Int(v) }
            }
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var autoPauseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.autopause.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            HStack {
                TextField("앱 이름 (예: Zoom)", text: $pauseAppInput)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(fieldBackground)
                Button("추가") {
                    let name = pauseAppInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !pauseApps.contains(name) else { return }
                    pauseApps.append(name)
                    AutoPauseRuleStore.pausedAppNames = pauseApps
                    pauseAppInput = ""
                }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }

            if !pauseApps.isEmpty {
                ForEach(pauseApps, id: \.self) { app in
                    HStack {
                        Text(app).foregroundStyle(LiquidGlassStyle.bodyText)
                        Spacer()
                        Button("삭제") {
                            pauseApps.removeAll { $0 == app }
                            AutoPauseRuleStore.pausedAppNames = pauseApps
                        }
                        .buttonStyle(LiquidGlassSecondaryButtonStyle())
                    }
                }
            }

            Text("점심 시간(12:00–13:00) 등 시간대 규칙은 추후 확장 가능합니다.")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var retentionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.retention.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Toggle(isOn: $retentionEnabled) {
                Text("오래된 기록 자동 삭제")
                    .foregroundStyle(LiquidGlassStyle.bodyText)
            }
            .toggleStyle(.switch)
            .onChange(of: retentionEnabled) { _, v in RetentionPolicyStore.isEnabled = v }

            if retentionEnabled {
                Text("보존 기간: \(Int(retentionDays))일")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
                Slider(value: $retentionDays, in: 30...365, step: 30)
                    .onChange(of: retentionDays) { _, v in RetentionPolicyStore.retentionDays = Int(v) }

                Button("지금 정리 미리보기") {
                    let engine = FocusStatisticsEngine(modelContext: modelContext)
                    let cutoff = Calendar.current.date(
                        byAdding: .day,
                        value: -Int(retentionDays),
                        to: Calendar.current.startOfDay(for: Date())
                    ) ?? Date()
                    let segs = engine.fetchSegments(in: DateInterval(start: .distantPast, end: cutoff))
                    purgePreviewCount = segs.count
                }
                .buttonStyle(LiquidGlassSecondaryButtonStyle())

                if let count = purgePreviewCount {
                    Text("\(count)개 기록이 삭제 대상입니다.")
                        .font(.caption)
                        .foregroundStyle(LiquidGlassStyle.secondaryText)
                }
            }
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var backupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.backup.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            SecureField("백업 암호", text: $backupPassword)
                .textFieldStyle(.plain)
                .padding(10)
                .background(fieldBackground)

            HStack(spacing: 10) {
                Button("백업 내보내기") { runBackupExport() }
                    .buttonStyle(LiquidGlassPrimaryButtonStyle())
                Button("가져오기(병합)") { runBackupImport(merge: true) }
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
                Button("가져오기(덮어쓰기)") { runBackupImport(merge: false) }
                    .buttonStyle(LiquidGlassSecondaryButtonStyle())
            }

            Text("AES-GCM 암호화 · 기기 이전용 풀 백업")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("settings.hotkey.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Toggle(isOn: $hotkeysEnabled) {
                Text("전역 단축키 사용")
                    .foregroundStyle(LiquidGlassStyle.bodyText)
            }
            .toggleStyle(.switch)
            .onChange(of: hotkeysEnabled) { _, v in GlobalHotkeyStore.isEnabled = v }

            Text("⌃⌥L — 트래킹 토글 · ⌃⌥P — 뽀모도로 시작/정지")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.secondaryText)
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("settings.theme.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Picker("테마", selection: $themePreset) {
                ForEach(GlassThemePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: themePreset) { _, v in GlassThemeStore.preset = v }
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var focusModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("settings.focusMode.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            Toggle(isOn: $focusModeEnabled) {
                Text("집중 모드 켜짐 시 자동 트래킹")
                    .foregroundStyle(LiquidGlassStyle.bodyText)
            }
            .toggleStyle(.switch)
            .onChange(of: focusModeEnabled) { _, v in FocusModeIntegrationStore.isEnabled = v }

            Text("공개 API 한계로 휴리스틱 신호를 사용합니다. 불안정하면 끄세요.")
                .font(.caption)
                .foregroundStyle(LiquidGlassStyle.tertiaryText)
        }
        .padding(20)
        .liquidGlassCard()
    }

    private func runBackupExport() {
        let engine = FocusStatisticsEngine(modelContext: modelContext)
        let segs = engine.fetchSegments(in: DateInterval(start: .distantPast, end: Date()))
        switch ActivityBackupService.exportEncrypted(segments: segs, password: backupPassword) {
        case .saved(let name):
            backupMessage = "백업 완료: \(name)"
        case .failed(let reason):
            backupMessage = reason
        case .cancelled:
            return
        case .imported:
            break
        }
        showBackupAlert = true
    }

    private func runBackupImport(merge: Bool) {
        switch ActivityBackupService.importEncrypted(context: modelContext, merge: merge) {
        case .imported(let count):
            backupMessage = "\(count)개 기록을 가져왔습니다."
        case .failed(let reason):
            backupMessage = reason
        case .cancelled:
            return
        case .saved:
            break
        }
        showBackupAlert = true
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("settings.rules.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)

            if rules.isEmpty {
                Text("등록된 규칙이 없습니다.")
                    .foregroundStyle(LiquidGlassStyle.secondaryText)
            } else {
                List {
                    ForEach(rules) { rule in
                        HStack {
                            Text(rule.pattern)
                                .foregroundStyle(LiquidGlassStyle.bodyText)
                            Spacer()
                            LiquidGlassBadge(text: rule.category.rawValue, tint: LiquidGlassStyle.deepSky)
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                    .onDelete { indexSet in
                        let store = CategoryMappingStore(modelContext: modelContext)
                        for index in indexSet {
                            store.deleteRule(rules[index])
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(rules.count) * 44 + 12)
            }
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var focusInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("settings.focusInfo.title"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(LiquidGlassStyle.titleText)
            Text("✅ 코딩, 디자인, 문서·글쓰기")
                .foregroundStyle(LiquidGlassStyle.bodyText)
            Text("❌ 커뮤니케이션, 브라우징, 엔터테인먼트, 기타")
                .foregroundStyle(LiquidGlassStyle.secondaryText)
        }
        .padding(20)
        .liquidGlassCard()
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LiquidGlassStyle.insetPanelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(LiquidGlassStyle.insetPanelBorder, lineWidth: 1)
            )
    }
}
