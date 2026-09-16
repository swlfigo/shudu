# 数独游戏设计

日期：2026-09-16  
工程：现有 SpriteKit 跨平台模板（`shudu iOS` + `shudu macOS` + `shudu Shared`）  
方案：纯 Swift 引擎 + SpriteKit 整屏 UI，两端共用同一套 Scene

## 目标

做一款标准 9×9 休闲数独，支持：

- 随机生成唯一解题
- 简单 / 中等 / 困难
- 每局有限次提示（填入一格正确答案）
- 笔记、撤销/重做、计时、冲突高亮与冲突次数

不对照隐藏答案判「对错」。冲突只看同行、同列、同宫是否出现重复数字。盘面填满且无冲突即胜利；对唯一解题，这等价于填对。

## 非目标（第一版不做）

- 每日挑战、成就、历史统计、iCloud 存档
- 音效、设置页、主题切换
- 对照答案的即时判错、三错失败
- 变体规则（对角线、杀手、不规则宫、16×16）
- SwiftUI 叠层、GameplayKit 实体组件

## 架构

三层，全部放在 `shudu Shared/`，不依赖 UIKit / AppKit（除 Scene 里用 `#if os` 处理点击）。

```
shudu Shared/
  Engine/
    SudokuBoard.swift
    SudokuSolver.swift
    SudokuGenerator.swift
    Difficulty.swift
  Game/
    GameState.swift
    GameCommand.swift
  UI/
    GameScene.swift
    BoardNode.swift
    CellNode.swift
    NumberPadNode.swift
    HUDNode.swift
    NewGameOverlayNode.swift
    Palette.swift
```

- `Engine`：无状态算法。输入盘面，输出新盘面或判定结果。可单测。
- `Game`：一局的可变状态（选中格、笔记模式、撤销栈、计时、剩余提示、冲突次数）。
- `UI`：只读 `GameState` 画出来，把点击变成 `GameCommand`。

平台入口只负责把 `GameScene` 交给 `SKView`，关掉 FPS / node count 调试叠加。

`GameScene` 用代码构建，不再依赖模板 `GameScene.sks` 的 Hello 节点。`scaleMode = .resizeFill`，在 `didChangeSize` 里重排，以适配 iPhone 旋转和 Mac 窗口缩放。

新增 `shuduTests` 单元测试 target，只测 Engine 和 Game，不测 SpriteKit 节点。

## 数据模型

格子下标 `0...80`，`row = i / 9`，`col = i % 9`，`box = (row / 3) * 3 + col / 3`。

```swift
struct Cell: Equatable {
    var value: Int?          // 1...9
    var isGiven: Bool
    var notes: Set<Int>      // 1...9
}

enum Difficulty: String, CaseIterable {
    case easy, medium, hard
    var hintCount: Int {
        switch self {
        case .easy: 3
        case .medium: 2
        case .hard: 1
        }
    }
}

struct Puzzle: Equatable {
    var givens: [Int?]       // 81，题目
    var solution: [Int]      // 81，唯一解
    var difficulty: Difficulty
}
```

`GameState` 持有：

- `puzzle: Puzzle?`（首屏选难度前为 `nil`）
- `cells: [Cell]`（81；无 puzzle 时全空）
- `selectedIndex: Int?`
- `isNotesMode: Bool`
- `hintsRemaining: Int`
- `conflictCount: Int`
- `elapsed: TimeInterval`
- `timerRunning: Bool`
- `undoStack` / `redoStack`
- `isGenerating: Bool`
- `generationID: UInt`
- `overlay: Overlay`（`.none` / `.newGame(allowsCancel: Bool)` / `.win`）

`overlay != .none` 或 `isGenerating` 时，棋盘和数字键的输入一律忽略；只处理遮罩按钮。出题中时新局遮罩内容换成「出题中…」，取消按钮隐藏（避免半生成态）。

## 生成与难度

### 完整解盘

用位掩码回溯填充 9×9。每一层把数字 1–9 随机打乱再试，保证随机。成功则得到 `solution[81]`。

### 唯一解

`SudokuSolver.countSolutions(board, limit: 2)`：同样用位掩码回溯，找到 2 个解就停。`limit == 1` 时只求一个解。

### 人类手法评级

在**当前题目给定 + 空格**上模拟，不看玩家填数。按顺序应用手法，能完全解出则停：

1. Naked Single（格内只剩一个候选）
2. Hidden Single（某行/列/宫里某数字只剩一格）
3. Naked Pair、Hidden Pair
4. Pointing（宫内某数字锁在一行或一列，从该行/列的宫外剔除）

评级规则（无歧义）：

- 只用 1–2 就能解完 → `easy`
- 1–2 不够，加上 3–4 能解完 → `medium`
- 1–4 仍不能解完，但唯一解成立 → `hard`

不实现 X-Wing 等更高级手法。Hard 的定义就是「中等手法解不完的唯一解题」。

### 挖空流程

目标给定数量只作搜索下限，**不以格数定义难度**：

| 难度 | 给定下限 | 接受条件 |
|------|----------|----------|
| 简单 | 36 | 评级为 easy |
| 中等 | 28 | 评级为 medium |
| 困难 | 22 | 评级为 hard |

步骤：

1. 生成完整解盘。
2. 把 81 个位置洗牌，依次尝试挖空：挖掉后若仍唯一则保留，否则还原。
3. 给定数量触达该档下限后停止挖空。
4. 评级。
5. 按档位修正：
   - 求 easy 却评成更难：随机把解数字填回空格，直到评为 easy。
   - 求 medium 却评为 easy：继续按随机序挖空（保持唯一解），直到评为 medium，或无法再挖。
   - 求 medium 却评为 hard：随机填回，直到评为 medium。
   - 求 hard 却更易：继续挖空直到评为 hard，或无法再挖。
6. 一整轮失败则回到 1。最多 20 轮。
7. 仍失败：采用本轮得到的唯一解题，即使评级与请求不完全一致。HUD 仍显示玩家点的那一档，提示次数仍按玩家所点档位（3/2/1）。这种情况应极少，测试里要能跑完生成，不要求 20 轮内 100% 命中。

生成必须在后台队列执行，主线程只切 `isGenerating` 和换盘。

单次生成墙上时间上限 8 秒；超时走步骤 7。

## 对局规则

### 选中

点格子即选中。给定格可以选中（用来看同行/列/宫和高亮相同数字），但不能改值、不能写笔记、不能清除。

### 填数

非笔记模式、选中非给定空格或已手填格：点 1–9 写入该数字，清空该格笔记，并从**同行、列、宫其他格的笔记**中删掉该数字。写入覆盖旧值。

点「清」：清空该格手填值和笔记。给定格忽略。

### 笔记

「笔记」是开关，点一次进入，再点退出。开启时按钮描边。

笔记模式下，对选中的空格（无值）：点 1–9 切换该候选是否存在。对已有值的格子忽略。给定格忽略。

笔记不计入冲突，不影响胜利判定。

### 冲突

某格 `value != nil`，且同行或同列或同宫另有一格值相同 → 这些格子都算冲突，赤陶底。

冲突次数：玩家**一次填数动作**若在落子后使该格处于冲突中，则 `conflictCount += 1`。清格、改成不冲突的数、撤销、提示、笔记都不减少已计数，也不因提示增加。

同一格反复改成冲突数字：每次填数都计 1 次。

### 提示

剩余次数 = 开局时该难度的 `hintCount`。为 0 时按钮变暗，点击忽略。

盘面已满时按钮同样不可用。

可用时：在空格中优先选当前盘面（含玩家已填）下的 Naked Single 或 Hidden Single；没有则选下标最小的空格。把该格写成 `puzzle.solution` 中的数字，清笔记，剔除 peers 笔记。这是一次普通填数命令，进入撤销栈，并 `hintsRemaining -= 1`。不增加冲突次数（解数字不会与已填正确约束冲突；若玩家先前填错导致提示格看起来冲突，仍高亮冲突，但不因提示本身加计数）。

### 撤销 / 重做

命令类型：`placeDigit`、`clear`、`toggleNote`、`applyHint`。

每条命令记下足够还原的格子快照（该格 value/notes，以及因填数被剔除笔记的 peers 差分）。

- 撤销：弹出 undo，反向应用，推进 redo。撤销提示时 `hintsRemaining += 1`。
- 重做：弹出 redo，正向应用。重做提示时再 `hintsRemaining -= 1`。
- 任何新的玩家命令清空 redo。
- iOS：点「撤销」撤销；**长按「撤销」重做**。
- Mac：`⌘Z` 撤销，`⌘⇧Z` 重做。

空栈时点击忽略。

### 计时

格式 `m:ss`，超过 59:59 用 `h:mm:ss`。

首次成功改变盘面（填数、清除、笔记、提示）后才开始走时。新局遮罩打开、应用进入后台、`isGenerating == true` 时暂停。胜利后停表。

### 胜利

81 格都有值，且没有任何冲突。弹出胜利遮罩：用时、冲突次数、剩余提示，以及「再来一局」（回到难度选择）。

### 新局

启动时没有进行中的盘：直接显示新局遮罩，三档「简单 · 提示 3」等，无取消。

对局中点「新局」：同样三档，另有「取消」。不先弹第二层确认。

选定难度后遮罩改为「出题中…」，后台生成，完成后换盘：重置 cells（给定写入 `isGiven = true`）、选中清空、笔记模式关、提示次数按档位、冲突 0、计时 0、撤销栈空、遮罩关。

## 界面

### 自适应

`scene.size.height >= scene.size.width` → 竖排：顶栏 HUD、中央棋盘、底部 1–9 + 清、再下一行 笔记 / 撤销 / 提示 / 新局。

否则 → 横排：棋盘在左，右侧从上到下 HUD、3×3 数字键、清/笔记/撤销、提示/新局。

棋盘保持正方形，边长取可用区域的短边，居中。宫线粗于格线。

### 格子视觉

背景 `#1C1916`，棋盘纸色 `#EFE4CC`，宫线 `#3A2F24`。

| 状态 | 表现 |
|------|------|
| 给定 | 深墨 `#2B2118`，粗体 |
| 手填 | 蓝墨 `#3D5C8A`，半粗 |
| 选中 | 底 `#D7C49A` |
| 同行/列/宫 | 底 `#F4EAD4` |
| 与选中格数字相同 | 底 `#E4D4A8` |
| 冲突 | 底 `#F0C8B4`，字 `#8A2A1A` |
| 笔记 | 格内 3×3 小字 `#7A6A58` |

底色优先级从高到低：冲突 > 选中 > 与选中格相同数字 > 同行/列/宫 > 默认纸色。选中格若冲突仍用赤陶底，加 2pt 深墨描边表示选中。

难度中文名固定：easy → 简单，medium → 中等，hard → 困难。

数字键：底 `#2A2420`，字纸色。提示键底 `#3A4A38`。笔记开启时金色描边 `#D4B483`。

字体：优先 New York / Palatino，缺省用系统 serif。

### HUD

四项：当前难度中文名、用时、`冲突 N`、`提示 N`。提示次数与按钮文案同步。

### 遮罩

半透明 `#1C1916`。卡片纸色。新局三档按钮深墨底纸色字。胜利卡片展示统计和「再来一局」。

### 输入（Mac 额外）

| 键 | 动作 |
|----|------|
| 1–9 | 与数字键相同（受笔记模式影响） |
| Delete / Backspace | 清 |
| N | 切换笔记 |
| H | 提示 |
| ⌘Z | 撤销 |
| ⌘⇧Z | 重做 |

iOS 仅触控。两端都是点格选中、点键行动。

## 错误与边界

- 未选中格子时：点 1–9 或「清」忽略。点「提示」仍有效，算法自己选格填入。
- 给定格上的填数、清除、笔记：忽略。
- 提示用尽或盘满：忽略。
- 撤销/重做空栈：忽略。
- 生成超时（8 秒）：采用本轮已得到的唯一解盘开局（步骤 7），不弹系统 Alert。
- 极端情况（完整解盘都失败，几乎不会发生）：遮罩文案改为「出题失败」，提供「重试」，留在新局遮罩，不进入对局。
- 后台生成完成时若 `generationID` 已变（不应在出题中取消，此为防护）：丢弃结果。
- 窗口极小：棋盘最小边长 288pt；Mac 窗口 `minSize` 480×640。

## 测试

`shuduTests` 覆盖：

1. 完整解盘合法（行、列、宫 1–9 各一次）。
2. `countSolutions` 对唯一盘返回 1，对故意造的多解盘返回 2（limit 2）。
3. 挖空后盘面唯一。
4. 评级：构造只靠 Hidden Single 的盘 → easy；需要 Pair/Pointing 的盘 → medium；手法不够的唯一盘 → hard。
5. 填数后 peers 笔记被剔除；给定格不可写。
6. 同行重复 → 两格都冲突；冲突次数只在造成冲突的填数时 +1。
7. 提示写入 solution 对应格，次数 -1，可撤销并恢复次数。
8. 撤销/重做还原 value 与 notes。
9. 满盘无冲突 → 胜利；满盘有冲突 → 不胜利。
10. 各难度 `hintCount` 为 3/2/1。

生成「请求某难度 20 轮内命中」不做硬断言，避免测试抖。可对生成器做「返回唯一解且 81 格解合法」的冒烟。

## 实现顺序

1. Engine：盘面、求解、评级、生成 + 测试。
2. GameState 命令循环 + 测试。
3. SpriteKit：棋盘、键盘、HUD、遮罩、自适应布局。
4. 接上 iOS / macOS 入口，去掉模板 Hello 与 FPS 叠加。
5. 真机/模拟器点选路径：新局 → 填数 → 笔记 → 冲突 → 提示 → 撤销 → 胜利。
