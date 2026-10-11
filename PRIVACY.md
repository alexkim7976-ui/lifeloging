# LifeLogger Privacy Policy / 개인정보처리방침

## English

### Local-first activity tracking
LifeLogger records which apps and window titles you use, **only on your Mac**. Activity segments are stored in a local SwiftData database under `~/Library/Application Support/LifeLogger`. They are **never uploaded** as part of core tracking.

### Optional cloud messenger (opt-in)
The **bloomie messenger** feature uses Firebase (Authentication + Firestore) **only if you explicitly enable it** in Settings › Privacy. Chat messages and account data may be stored in Google Cloud. **Activity tracking data does not go to Firebase.**

### Permissions
| Permission | Purpose |
|------------|---------|
| Accessibility | Read active window titles for categorization |
| Notifications | Pomodoro, focus nudges, rest reminders |
| Calendar (optional) | Overlay today's events on the timeline (read-only, local) |
| Location (optional) | Approximate locale on dashboard only; not stored |
| Apple Events | Share activity text with other apps you choose |

### Your controls
- Export JSON/CSV or encrypted backup
- Retention policy (auto-delete after N days)
- Sensitive window title masking
- Encrypted backup with your password

Contact: support@lifelogger.app (placeholder)

---

## 한국어

### 로컬 우선 활동 트래킹
LifeLogger는 사용 중인 앱·창 제목을 **Mac에만** 기록합니다. SwiftData로 `~/Library/Application Support/LifeLogger`에 저장하며, **핵심 트래킹 데이터는 클라우드로 전송되지 않습니다.**

### 선택적 클라우드 메신저 (옵트인)
**bloomie 메신저**는 설정 › 개인정보에서 **명시적으로 동의한 경우에만** Firebase를 사용합니다. 채팅·계정 정보만 클라우드에 저장될 수 있으며, **활동 트래킹 기록은 Firebase로 가지 않습니다.**

### 권한
| 권한 | 목적 |
|------|------|
| 손쉬운 사용 | 창 제목으로 카테고리 분류 |
| 알림 | 뽀모도로·넛지·휴식 리마인더 |
| 캘린더(선택) | 타임라인 일정 오버레이(읽기 전용) |
| 위치(선택) | 대시보드 대략적 지역 표시, 저장 안 함 |
| Apple Events | 사용자가 선택한 앱으로 활동 공유 |

### 사용자 제어
- JSON/CSV·암호화 백업
- N일 보존 후 자동 삭제
- 민감 창제목 마스킹
- 사용자 암호 AES-GCM 백업

문의: support@lifelogger.app (placeholder)
