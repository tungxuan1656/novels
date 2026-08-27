---
name: using-skills
description: Hướng dẫn dùng và kết hợp các skills trong repo Novels. Dùng khi cần chọn skill phù hợp, kết hợp nhiều skills cho một công việc, hoặc giới thiệu hệ thống skills cho thành viên mới. Tổng hợp 21 skills hiện có, quy tắc chọn, workflow mẫu và ví dụ thực tế theo ARCHITECTURE.md và Harness Slim.
---
# Using Skills — Dùng và Kết Hợp Skills trong Novels
> Mục tiêu: chọn đúng skill, kết hợp đúng thứ tự, không thừa không thiếu. Mỗi skill một việc — xâu chuỗi thành workflow.
## 1. Gọi skill như thế nào
```js
skill({ name: "brainstorming" }) // + writing-plans, swiftui-expert-skill, ...
```
Một phiên có thể gọi nhiều skills theo thứ tự. Không gọi skill khi công việc nhẹ, rõ ràng, rủi ro thấp (thuộc No feature / 1 file, <200 dòng như AGENTS.md § Plans).
## 2. Bản đồ nhanh — 21 skills hiện có

<!-- drift: 21 skills excluding this router; verify via init.sh -->

### Nhóm A: Tư duy & lập kế hoạch

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `brainstorming` | Trước mọi việc sáng tạo (tính năng/component mới, đổi hành vi) — bắt buộc cho nhóm việc này (không áp cho bug/gardening/docs đơn thuần) | Sửa typo, tra cứu nhanh, việc đã có spec rõ |
| `agent-docs-architect` | Cần quyết định docs nào, ở đâu, ai sở hữu, khi nào đọc, làm sao giữ tươi | Chỉ viết 1 doc đã biết vị trí/chủ sở hữu |
| `writing-plans` | Có spec/yêu cầu và cần plan nhiều bước trước khi chạm code | Việc 1 bước, fix nhỏ, đã có plan |
| `harness-task` | Đánh giá mọi request: chọn No feature / Inline / Separate | Repo không dùng Harness Slim |

### Nhóm B: Triển khai & thực thi

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `executing-plans` | Có plan đã duyệt, thực thi tuần tự, có checkpoint | Chưa có plan, hoặc tasks độc lập cần parallel |
| `subagent-driven-development` | Có plan với tasks độc lập, muốn parallel trong cùng session + review | Tasks phụ thuộc chặt, chưa có plan |
| `codebase-design` | Thiết kế/thu hẹp interface, tìm seam, module sâu, dễ test | Chỉ cần naming/format (dùng coding-standards) |

### Nhóm C: Chất lượng code & SwiftUI

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `swiftui-expert-skill` | Viết/review/sửa SwiftUI: @Observable, composition, identity, animation, Liquid Glass | Logic thuần không UI |
| `swiftui-pro` | Review SwiftUI 9 trục: API, views, data flow, nav, design, a11y, perf, Swift, hygiene | Prototype nhanh chưa cần polish |
| `frontend-design` | Cần gu thẩm mỹ: palette, type, layout, signature, motion | Backend/logic không giao diện |
| `coding-standards` | Naming, readability, KISS/DRY/YAGNI, smell | Đã có skill chuyên bao phủ |

### Nhóm D: Vận hành dự án

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `harness-slim` | Tạo/thu gọn harness: AGENTS.md, feature_index.json, features/, progress.md, init.sh | Chỉ đánh giá có cần feature không (dùng harness-task) |
| `harness-slim-review` | Audit harness: gap HIGH/MEDIUM/LOW, không sửa | Muốn tạo/sửa harness |
| `agent-docs-writer` | Viết/sửa 1 doc đã biết chủ sở hữu & vị trí (nhỏ nhất) | Chưa biết doc nên tồn tại không (dùng architect) |
| `repo-gardening` | Dọn drift: helper trùng, dead code, batch nhỏ có verify | Chỉ sửa prose, ownership chưa rõ |
| `simple-english` | Viết/sửa prose ASD-STE100: câu ≤20/25 từ, 1 từ 1 nghĩa | Code, identifier, command |
| `find-skills` | Tìm skill mới từ https://skills.sh khi chưa có skill phù hợp | Đã biết skill cần dùng |

### Nhóm E: Sửa lỗi & kết thúc

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `systematic-debugging` | Mọi bug/test fail. 4 phase: Root Cause → Pattern → Hypothesis → Fix | Chưa đọc error/stack trace |
| `verification-before-completion` | Trước khi claim "xong", trước commit/PR. Không evidence tươi thì không claim | Chưa có gì để verify |
| `git-commit` | Tạo commit Conventional Commits, phân tích diff | Chưa verify xong |
| `handoff` | Bàn giao ngắn khi user yêu cầu | Đã có progress.md đầy đủ + linked docs → không cần handoff (chỉ khi dở dang cần bàn giao) |

## 3. Quy tắc chọn nhanh (Decision Tree)

```
0. Đánh giá scale trước → harness-task (No feature / Inline / Separate) → rồi mới chọn skill

Việc mới?
├─ Chưa rõ / cần khám phá ý tưởng?        → brainstorming
├─ Đã rõ, cần plan nhiều bước?              → writing-plans
├─ Đã có plan?                              → executing-plans / subagent-driven-development
│                                             (tasks độc lập + cùng session → subagent)
└─ Bug / test fail?                         → systematic-debugging

Việc docs? → chưa biết docs gì/ở đâu → agent-docs-architect | đã biết doc & vị trí → agent-docs-writer (+ simple-english)
Việc UI?   → ý tưởng thẩm mỹ → frontend-design | code SwiftUI → swiftui-expert-skill + swiftui-pro | chuẩn chung → coding-standards
Việc repo/harness? → đánh giá feature/plan → harness-task | tạo/sửa → harness-slim | audit → harness-slim-review | dọn drift → repo-gardening

Trước khi kết thúc → verification-before-completion → git-commit → handoff (nếu cần)
Không match skill nào? → find-skills (https://skills.sh)
Note: Viết/sửa prose kỹ thuật → simple-english; thiết kế module sâu → codebase-design
```

## 4. Workflow kết hợp — mẫu cho Novels

### Pattern 1: Tính năng mới hoàn chỉnh (đường chính)

`harness-task → brainstorming → agent-docs-architect (nếu đụng product/contracts/design) → agent-docs-writer (+ simple-english) → writing-plans → subagent-driven-development / executing-plans (swiftui-expert-skill / coding-standards, + frontend-design nếu có UI) → swiftui-pro → verification-before-completion (./init.sh) → git-commit → handoff`

*VD feat-006 AI Reading — brainstorming chunk ~1300, retry 3×, cache processed_chapters.sqlite; architect xác định docs/contracts/ai-service.md + functional-specs/ai-reading.md; writing-plans → docs/plans/feat-006.md; subagent chia cache actor, chunker, network client, UI switch.*

### Pattern 2: Sửa bug / build fail

`systematic-debugging Phase1 đọc lỗi/reproduce/git diff/trace → Phase2 so với code chạy được → Phase3 hypothesis + test nhỏ → Phase4 failing test → fix 1 chỗ → verify → verification-before-completion → git-commit`

Không fix khi chưa xong Phase 1; sau 3 fail → dừng hỏi kiến trúc.

### Pattern 3: Làm UI/UX cho màn hình Novels

`brainstorming (iPhone offline, Vietnamese, tối giản) → frontend-design (token + 2 pass plan→critique→build) → swiftui-expert-skill (@Observable, extraction, ForEach identity) → swiftui-pro (deprecated API, a11y VoiceOver/Dynamic Type) → verification-before-completion`

*iOS 26+, Swift 5.0, không WebKit/CoreData/Keychain, SwiftUI.Text render spans, tôn trọng Reduce Motion.*

### Pattern 4: Tài liệu & quyết định

`agent-docs-architect (inventory→pressure→gap→artifact map→blueprint) → user duyệt → agent-docs-writer (canonical trước, index sau) → simple-english → harness-slim-review (nếu đụng harness)`

*VD thêm docs/decisions/local-persistence.md: architect tìm gap, writer 500 từ, simple-english gọt câu, review ARCHITECTURE.md §1 vs local-data.md.*

### Pattern 5: Dọn dẹp & chuẩn hoá

`repo-gardening (orient→1 theme batch nhỏ→clean Confirmed→verify) → coding-standards hoặc swiftui-pro → verification-before-completion → git-commit (refactor/style/chore)`

Không trộn gardening với feature; không tạo abstraction nếu chưa có ≥2 consumers.

### Pattern 6: Harness lifecycle

`harness-task → harness-slim (tạo/sửa artifacts) → harness-slim-review (audit) → verification-before-completion`

`AGENTS.md` là router ngắn, `feature_index.json` giữ 0-1 active, `progress.md` chỉ ghi khi có result/blocker/next action material.

## 5. Kết hợp theo vai trò

Chọn skills theo việc (xem §3 & §4), không theo chức danh cố định. Ví dụ: việc sáng tạo → `brainstorming`, việc bug → `systematic-debugging`, việc UI → `frontend-design` + `swiftui-expert-skill`.

## 6. Ví dụ thực tế trong Novels (4 ca)

**Ca A: "Thêm Prefetch chương kế tiếp" (feat-007)** — `harness-task` Separate plan (≥4 files, DB+network+UI) → `brainstorming` N=PREFETCH_COUNT 1..10 default 3 → `writing-plans` batch-check SQLite→sequential AI fetch→Task cancel → `subagent-driven-development` 3 lanes cache/network/UI → `swiftui-expert-skill` cancellation/de-dup → `verification-before-completion` ./init.sh → `git-commit` feat(prefetch): add chapter prefetch with cancel

**Ca B: "Reader mất offset khi đổi typography"** — `systematic-debugging` Phase1 reproduce đổi font→offset reset trace UserDefaults→@Observable→Reader; Phase2 so với feat-004 offset per slug; Phase3 hypothesis "Typography store trigger re-init"; Phase4 test fail→fix 1 dòng isolate state→verify→`swiftui-pro` check @State private, ForEach identity

**Ca C: "Polish màn Library + Empty state"** — `frontend-design` palette giấy ấm + serif display + sans body, signature kệ sách ngang → `swiftui-expert-skill` List perf, downsampling → `simple-english` gọt copy: "Chưa có sách. Thêm sách từ catalog."

**Ca D: "Docs AI Service lỗi thời sau đổi header"** — `agent-docs-architect` gap ai-service.md thiếu AI_CUSTOM_HEADERS + AI_EXTRA_BODY → `agent-docs-writer` sửa canonical + link ARCHITECTURE.md §1 → `simple-english` ≤25 từ/câu mô tả, ≤20 từ/instruction → `harness-slim-review` check AGENTS.md routes

## 7. Anti-patterns — đừng làm

| Sai | Đúng |
|---|---|
| Gọi `writing-plans` khi chưa làm rõ ý tưởng cho việc sáng tạo | `brainstorming` trước khi plan cho việc sáng tạo |
| Fix bug đoán mò, skip Phase 1 | `systematic-debugging` đủ 4 phase, có evidence |
| Claim "xong" khi chưa chạy `./init.sh` | `verification-before-completion` luôn chạy tươi |
| Trộn gardening + feature trong 1 commit | Tách batch, mỗi commit 1 theme |
| Tạo `docs/plans/feat-xxx.md` cho việc 1 file <200 dòng | Dùng inline plan trong `features/feat-xxx.md` |
| Dùng `frontend-design` cho logic thuần | Dùng `coding-standards` / `swiftui-expert-skill` |
| Gọi `agent-docs-writer` khi chưa rõ doc thuộc đâu | Gọi `agent-docs-architect` trước |
| Tự chọn API SwiftUI cũ | Tra `references/latest-apis.md` trong `swiftui-expert-skill` |
| Viết commit message thủ công dài dòng | Dùng `git-commit` phân tích diff |

## 8. Checklist trước khi giao việc

- [ ] Đã chọn skill đúng nhóm (A/B/C/D/E)?
- [ ] Đã xếp đúng thứ tự workflow (không nhảy cóc)?
- [ ] Mỗi skill chỉ làm việc thuộc scope của nó?
- [ ] Có `verification-before-completion` trước khi claim xong?
- [ ] Commit qua `git-commit` với Conventional Commits?
- [ ] Nếu bàn giao, có `handoff` ngắn gọn, không duplicate spec/plan?

---

*Skill này là router cho các skills khác. Nó không thay thế bất kỳ skill nào — giúp bạn chọn và xâu chuỗi chúng đúng cách cho Novels (iPhone, iOS 26+, offline-first, SwiftUI, ZIP book package).*
