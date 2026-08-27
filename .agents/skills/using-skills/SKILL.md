---
name: using-skills
description: Hướng dẫn dùng và kết hợp các skills trong repo Novels. Dùng khi cần chọn skill phù hợp, kết hợp nhiều skills cho một công việc, hoặc giới thiệu hệ thống skills cho thành viên mới. Tổng hợp 21 skills hiện có, quy tắc chọn, workflow mẫu và ví dụ thực tế theo ARCHITECTURE.md và Harness Slim.
---

# Using Skills — Dùng và Kết Hợp Skills trong Novels

> Mục tiêu: chọn đúng skill, kết hợp đúng thứ tự, không thừa không thiếu. Mỗi skill có một việc. Kết hợp chúng thành workflow thay vì dùng lẻ tẻ.

## 1. Gọi skill như thế nào

```js
skill({ name: "brainstorming" })
skill({ name: "writing-plans" })
skill({ name: "swiftui-expert-skill" })
```

Một phiên làm việc có thể gọi nhiều skills theo thứ tự. Không gọi skill khi công việc là thao tác đơn lẻ, rõ ràng, rủi ro thấp (<20 dòng, 1 file).

## 2. Bản đồ nhanh — 21 skills hiện có

### Nhóm A: Tư duy & lập kế hoạch (Discovery → Design → Plan)

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `brainstorming` | Trước mọi việc sáng tạo: tính năng mới, component mới, đổi hành vi. Bắt buộc trước khi code. | Sửa lỗi typo, tra cứu nhanh, việc đã có spec rõ |
| `agent-docs-architect` | Cần quyết định nên có tài liệu gì, đặt ở đâu, ai sở hữu, khi nào đọc, làm sao giữ tươi. Trước khi viết nhiều docs. | Chỉ viết 1 doc đã biết vị trí/chủ sở hữu |
| `writing-plans` | Có spec/yêu cầu và cần plan triển khai nhiều bước trước khi chạm code. | Việc 1 bước, fix nhỏ, đã có plan |
| `harness-task` | Đánh giá mọi request trong repo Harness Slim: chọn No feature / Inline plan / Separate plan. | Repo không dùng Harness Slim |

### Nhóm B: Triển khai & thực thi (Plan → Code)

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `executing-plans` | Có plan đã duyệt, thực thi tuần tự trong session riêng, có checkpoint review. | Chưa có plan, hoặc tasks độc lập cần parallel |
| `subagent-driven-development` | Có plan với tasks độc lập, muốn parallel trong cùng session: mỗi task = 1 subagent mới + review sau mỗi task + review toàn nhánh cuối. | Tasks phụ thuộc chặt, chưa có plan, cần brainstorm trước |
| `codebase-design` | Thiết kế/thu hẹp interface module, tìm seam, làm module sâu hơn, dễ test/AI-navigate. | Chỉ cần đặt tên/format chung (dùng coding-standards) |

### Nhóm C: Chất lượng code & SwiftUI (chuyên ngành iOS)

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `swiftui-expert-skill` | Viết/review/sửa SwiftUI: state `@Observable`, composition, list identity, animation, Liquid Glass, Instruments trace. | Logic thuần không UI |
| `swiftui-pro` | Review SwiftUI theo checklist 9 trục: API deprecated, views, data flow, navigation, design, a11y, performance, Swift, hygiene. | Prototype nhanh chưa cần polish |
| `frontend-design` | Cần gu thẩm mỹ: palette, type, layout, signature element, motion có chủ ý. Tránh 3 template mặc định của AI. | Backend/logic không có giao diện |
| `coding-standards` | Naming, readability, immutability, KISS/DRY/YAGNI, code smell. Nền chung khi không có skill hẹp hơn. | Đã có skill chuyên (SwiftUI/frontend/backend) bao phủ |

### Nhóm D: Vận hành dự án Novels (Harness Slim + Docs + Dọn dẹp)

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `harness-slim` | Tạo/thu gọn harness: `AGENTS.md`, `feature_index.json`, `features/`, `progress.md`, `init.sh`. | Chỉ đánh giá việc có cần feature không (dùng harness-task) |
| `harness-slim-review` | Audit harness hiện tại: tìm gap HIGH/MEDIUM/LOW, không sửa. | Muốn tạo/sửa harness |
| `agent-docs-writer` | Viết/sửa 1 doc đã biết chủ sở hữu & vị trí (AGENTS.md, ARCHITECTURE.md, spec, decision). Nhỏ nhất có thể. | Chưa biết doc nên tồn tại hay không (dùng architect) |
| `repo-gardening` | Dọn drift: helper trùng, abstraction suy đoán, dead code, pattern lệch chuẩn. Batch nhỏ, có verify. | Chỉ sửa prose lỗi thời, ownership chưa rõ |
| `simple-english` | Viết/sửa text kỹ thuật theo ASD-STE100: câu ≤20/25 từ, 1 từ 1 nghĩa, active voice. | Code, identifier, command |
| `find-skills` | Tìm skill mới từ ecosystem https://skills.sh/ khi việc hiện tại chưa có skill phù hợp. | Đã biết skill cần dùng |

### Nhóm E: Sửa lỗi & kết thúc

| Skill | Khi dùng | Khi KHÔNG dùng |
|---|---|---|
| `systematic-debugging` | Mọi bug/test fail/hành vi lạ. Bắt buộc 4 phase: Root Cause → Pattern → Hypothesis → Implementation. | Chưa đọc error message/stack trace |
| `verification-before-completion` | Trước khi claim "xong/pass/fix", trước commit/PR. Iron law: không evidence tươi thì không claim. | Chưa có gì để verify |
| `git-commit` | Tạo commit theo Conventional Commits, phân tích diff để chọn type/scope/message, stage thông minh. | Chưa verify xong |
| `handoff` | Tạo doc bàn giao ngắn cho agent/session tiếp theo khi user yêu cầu. | Đã có spec/plan/progress đủ |

## 3. Quy tắc chọn nhanh (Decision Tree)

```
Việc mới?
├─ Chưa rõ làm gì / cần khám phá ý tưởng? → brainstorming
├─ Đã rõ ý tưởng, cần plan nhiều bước?     → writing-plans
├─ Đã có plan?                             → executing-plans hoặc subagent-driven-development
│                                            (tasks độc lập + ở cùng session → subagent-driven-development)
└─ Sửa bug / test fail?                    → systematic-debugging

Việc docs?
├─ Chưa biết nên có docs gì / ở đâu?       → agent-docs-architect
└─ Đã biết doc & vị trí?                    → agent-docs-writer (+ simple-english để gọt câu)

Việc UI?
├─ Cần ý tưởng thẩm mỹ / layout / motion?  → frontend-design
├─ Code SwiftUI cụ thể?                    → swiftui-expert-skill (implement) + swiftui-pro (review)
└─ Chỉ cần chuẩn chung?                    → coding-standards

Việc repo/harness?
├─ Đánh giá có cần feature/plan không?     → harness-task
├─ Tạo/sửa harness?                        → harness-slim
├─ Audit harness?                          → harness-slim-review
└─ Dọn rác / drift?                        → repo-gardening

Trước khi kết thúc bất kỳ việc gì?
└─ verification-before-completion → git-commit → handoff (nếu cần)
```

## 4. Workflow kết hợp — mẫu cho Novels

### Pattern 1: Tính năng mới hoàn chỉnh (đường chính Novels)

```
brainstorming
  → agent-docs-architect (nếu đụng product/contracts/design mới)
  → agent-docs-writer (+ simple-english)
  → writing-plans
  → harness-task (chọn No feature / Inline / Separate)
  → subagent-driven-development HOẶC executing-plans
      ├─ trong mỗi task: swiftui-expert-skill / coding-standards
      └─ nếu có UI: frontend-design trước khi code
  → swiftui-pro (review)
  → verification-before-completion (./init.sh)
  → git-commit
  → handoff (nếu bàn giao)
```

*Ví dụ Novels:* `feat-006 AI Reading` — brainstorming làm rõ chunk ~1300, retry 3×, cache `processed_chapters.sqlite`; agent-docs-architect xác định docs `docs/contracts/ai-service.md` + `functional-specs/ai-reading.md`; writing-plans ra `docs/plans/feat-006.md`; subagent-driven-development chia tasks: cache actor, chunker, network client, UI mode switch.

### Pattern 2: Sửa bug / build fail

```
systematic-debugging (Phase 1: đọc lỗi, reproduce, check git diff, trace data flow)
  → Phase 2: so với code chạy được
  → Phase 3: hypothesis + test nhỏ nhất
  → Phase 4: tạo failing test → fix 1 chỗ → verify
  → verification-before-completion
  → git-commit
```

*Quy tắc sắt:* Không fix khi chưa xong Phase 1. Sau 3 fix fail → dừng, hỏi kiến trúc (có thể sai pattern).

### Pattern 3: Làm UI/UX cho màn hình Novels

```
brainstorming (rõ subject: iPhone reader offline, Vietnamese, tối giản đọc sách)
  → frontend-design (token: color/type/layout/signature, 2 pass: plan → critique → build)
  → swiftui-expert-skill (implement: @Observable, view extraction, ForEach identity)
  → swiftui-pro (review: deprecated API, a11y VoiceOver/Dynamic Type)
  → verification-before-completion
```

*Lưu ý Novels:* iOS 26+, Swift 5.0, không WebKit, `SwiftUI.Text` render spans, không SwiftData/CoreData/Keychain. Mọi animation phải tôn trọng Reduce Motion.

### Pattern 4: Tài liệu & quyết định

```
agent-docs-architect (inventory → assess pressure → gap → artifact map → blueprint)
  → (user duyệt blueprint)
  → agent-docs-writer từng doc (canonical trước, index sau)
  → simple-english (pragmatic pass cuối)
  → harness-slim-review (nếu đụng AGENTS.md/feature_index/progress/init.sh)
```

*Ví dụ Novels:* Thêm quyết định `docs/decisions/local-persistence.md` — architect xác định gap lưu trữ, writer viết doc 500 từ, simple-english gọt câu, review đảm bảo ARCHITECTURE.md §1 và `local-data.md` không trùng ownership.

### Pattern 5: Dọn dẹp & chuẩn hoá

```
repo-gardening (orient → chọn 1 theme batch nhỏ → clean từng candidate Confirmed → verify)
  → coding-standards hoặc swiftui-pro (review chuẩn)
  → verification-before-completion
  → git-commit (type: refactor/style/chore)
```

Không trộn gardening với feature work. Không tạo abstraction chung nếu chưa có ≥2 consumers thực.

### Pattern 6: Harness lifecycle

```
harness-task (đánh giá request: No feature / Inline / Separate)
  → harness-slim (tạo/sửa artifacts nếu cần)
  → harness-slim-review (audit trước khi bàn giao)
  → verification-before-completion
```

Nhớ: `AGENTS.md` là router ngắn, `feature_index.json` giữ 0-1 active, `progress.md` chỉ ghi khi có result/blocker/next action material.

## 5. Kết hợp theo vai trò (Orchestrator gợi ý)

| Vai trò bạn đảm nhận | Gọi theo thứ tự |
|---|---|
| Product / BA | `brainstorming` → `agent-docs-architect` → `agent-docs-writer` |
| Tech Lead | `codebase-design` → `writing-plans` → `harness-task` |
| iOS Dev | `swiftui-expert-skill` → `swiftui-pro` → `coding-standards` |
| Designer | `frontend-design` → `swiftui-expert-skill` (implement) |
| Debugger | `systematic-debugging` → `verification-before-completion` |
| Release | `verification-before-completion` → `git-commit` → `handoff` |
| Gardener | `repo-gardening` → `simple-english` (nếu đụng docs) |

## 6. Ví dụ thực tế trong Novels (4 ca)

### Ca A: "Thêm Prefetch chương kế tiếp" (feat-007)

```
1. brainstorming — làm rõ N=PREFETCH_COUNT (1..10 default 3), trigger khi mode != none
2. writing-plans — tasks: batch-check SQLite → sequential AI fetch → Task cancel on chapter/mode change
3. harness-task — Separate plan (≥4 files, DB + network + UI, cần phases/rollback)
4. subagent-driven-development — parallel 3 lanes: cache, networking actor, UI status
5. swiftui-expert-skill — Task cancellation, actor de-dup
6. verification-before-completion — ./init.sh (format+lint+build)
7. git-commit — feat(prefetch): add chapter prefetch with cancel
```

### Ca B: "Reader bị mất offset khi đổi typography"

```
1. systematic-debugging — Phase1: reproduce đổi font → offset reset; trace UserDefaults → @Observable → Reader view
2. Phase2: so với bản chạy được (feat-004): offset lưu per slug bookId
3. Phase3: hypothesis "Typography store trigger re-init Reader"
4. Phase4: test fail → fix 1 dòng (isolate typography state) → verify
5. swiftui-pro review — check @State private, ForEach identity, không dùng .indices
```

### Ca C: "Polish màn Library + Empty state"

```
1. frontend-design — palette giấy sách ấm + serif display + sans body, signature: kệ sách ngang
2. swiftui-expert-skill — List performance, image downsampling
3. simple-english — gọt copy empty: "Chưa có sách. Thêm sách từ catalog."
```

### Ca D: "Docs AI Service lỗi thời sau đổi header"

```
1. agent-docs-architect — gap: docs/contracts/ai-service.md thiếu AI_CUSTOM_HEADERS + AI_EXTRA_BODY
2. agent-docs-writer — sửa canonical doc, link từ ARCHITECTURE.md §1
3. simple-english — pass pragmatic (≤25 từ/câu mô tả, ≤20 từ/instruction)
4. harness-slim-review — check AGENTS.md routes còn đúng
```

## 7. Anti-patterns — đừng làm

| Sai | Đúng |
|---|---|
| Gọi `writing-plans` khi chưa brainstorming | `brainstorming` bắt buộc trước implementation |
| Fix bug bằng đoán mò, skip Phase 1 | `systematic-debugging` đủ 4 phase, có evidence |
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

## 9. Tham chiếu nhanh — tất cả skills theo alphabet

| # | Skill | Một dòng nhớ |
|---|---|---|
| 1 | `agent-docs-architect` | Thiết kế hệ tri thức docs: cái gì, ở đâu, khi nào đọc |
| 2 | `agent-docs-writer` | Viết 1 doc nhỏ nhất, đúng chủ sở hữu |
| 3 | `brainstorming` | Biến ý tưởng → thiết kế được duyệt trước khi code |
| 4 | `codebase-design` | Làm module sâu, seam rõ, dễ test |
| 5 | `coding-standards` | Nền tảng naming/readability/DRY/KISS/YAGNI |
| 6 | `executing-plans` | Thực thi plan tuần tự, có review checkpoint |
| 7 | `find-skills` | Tìm & cài skill mới từ skills.sh |
| 8 | `frontend-design` | Gu thẩm mỹ có chủ ý, tránh template AI |
| 9 | `git-commit` | Commit chuẩn Conventional Commits từ diff |
| 10 | `handoff` | Bàn giao ngắn cho session tiếp theo |
| 11 | `harness-slim` | Tạo/thu gọn AGENTS.md + feature_index + init.sh |
| 12 | `harness-slim-review` | Audit harness, báo HIGH/MEDIUM/LOW |
| 13 | `harness-task` | Chọn No feature / Inline / Separate |
| 14 | `repo-gardening` | Dọn drift theo batch nhỏ, có verify |
| 15 | `simple-english` | ASD-STE100: câu ngắn, 1 từ 1 nghĩa |
| 16 | `subagent-driven-development` | Plan → parallel subagents + review từng task |
| 17 | `swiftui-expert-skill` | Chuyên gia SwiftUI + Instruments trace |
| 18 | `swiftui-pro` | Review SwiftUI 9 trục, báo file/line + fix |
| 19 | `systematic-debugging` | 4 phase, no fix without root cause |
| 20 | `verification-before-completion` | Evidence trước claim, iron law |
| 21 | `writing-plans` | Viết plan chi tiết cho engineer zero-context |

## 10. Khi nào cần skill mới?

Nếu `find-skills` không có và việc lặp lại ≥3 lần, cân nhắc tạo skill mới:
- Đặt tên `kebab-case`, mô tả 1 câu rõ "khi nào dùng".
- Viết `SKILL.md` theo mẫu: Promise & boundary → Workflow → Validate.
- Đặt tại `.agents/skills/<tên>/SKILL.md` và thêm vào bảng trên.

---

*Skill này là router cho các skills khác. Nó không thay thế bất kỳ skill nào — nó giúp bạn chọn và xâu chuỗi chúng đúng cách cho Novels (iPhone, iOS 26+, offline-first, SwiftUI, ZIP book package).*
