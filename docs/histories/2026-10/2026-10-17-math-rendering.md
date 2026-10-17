## 2026-10-17 | 任务：增加本地 MathJax 公式渲染

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-17-math-rendering.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 26.5 (17F42)`

### 用户请求

在显示设置中增加公式渲染选项，支持行内及独立公式。用户指定新分支基于当前玻璃迷你窗口版本，方便将两个功能拆成 PR。

### 变更

- 从 `58babafbf4354033eed94365f1ce79fd1c72ebb0` 创建 `math-rendering`；公式功能保留在独立分支；共有设置卡顿补丁另行同步至 `liquid-glass-mini`，并更新本分支基线。
- 增加默认关闭的独立 MathJax 开关和六种语言说明，普通翻译结果及玻璃迷你窗口共用渲染能力。
- 在 Markdown 前保护 `$…$`、`$$…$$`、`\(…\)`、`\[…\]` 公式，跳过代码区域和转义符；未闭合或排版失败时保留可读源文。
- 固定 MathJax 4.1.3 和 TeX 字体包，通过受限 JavaScriptCore 串行工作队列输出 SVG，再作为原生文本附件显示；不使用 WebView、CDN 或外部渲染服务。
- 保留文本选择、玻璃材质、细滚动条及顶部拖动。复制包含公式的选区时还原其 LaTeX 源码，普通选区保留原有复制行为。
- 普通结果异步完成后复算高度；玻璃窗口根据原生文本布局更新高度。内容代次和结果/视图身份检查防止旧回调覆盖新内容。
- 增加可复现 npm 构建脚本、锁文件、离线资源及 Apache-2.0 许可证，更新 Xcode 源码与资源引用；未新增或扩写测试。

### 设计意图

保留已有 Markdown 格式化和原生文本视图，以共享的公式附件扩展译文显示，不另建网页渲染管线。MathJax 的本地适配器和完整 TeX 字体避免运行时动态字体请求；只启用 base、ams、newcommand、boldsymbol 扩展。输入长度、宏展开和缓存均有限制，且每个公式使用独立 TeX 输入处理器，宏定义不跨结果泄漏。

### 验证

- 最终 Debug arm64 编译及 32 项既有测试通过，实际命令如下；`agent_dd` 使用该 checkout 独立的 Agent DerivedData：

  ```sh
  xcodebuild test -workspace Easydict.xcworkspace -scheme Easydict \
    -configuration Debug -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$agent_dd" ENABLE_PREVIEWS=YES \
    'EXCLUDED_SOURCE_FILE_NAMES=Easydict-27.icon' \
    ASSETCATALOG_COMPILER_APPICON_NAME=Easydict-26 \
    -only-testing:EasydictTests/MarkdownRendererTests \
    -only-testing:EasydictTests/ReverseTranslationTests \
    -only-testing:EasydictTests/OpenAIStreamTaskControlTests
  ```

- 沿用此前本机图标编译覆写；没有改变工程默认图标。既有测试覆盖 Markdown 与翻译流程，不直接覆盖新增公式解析器或完整 UI。
- 修改的 Swift 文件 SwiftLint 无违规；`git diff --check`、String Catalog 和 npm JSON 检查、工程 `plutil -lint` 以及两个构建脚本的 `node --check` 通过。
- 本地 MathJax → JavaScriptCore → SVG → NSImage 原生预览成功，分数、根号、上下标清晰显示。没有把这项预览写成完整应用交互验证。
- `npm run --prefix BuildTools/MathJax build` 可重复生成相同资源，SHA-256 为 `d4f3843567b85d121c091e8a48ee85c76ad41924bc68f47a25028c4a78a3fa79`；资源约 3 MB。
- 使用 review 技能，冻结基线 `58babafbf4354033eed94365f1ce79fd1c72ebb0` 和所有变更/未跟踪文件摘要。检查解析、Markdown 保护、资源和线程边界、复制、生命周期及窗口高度；修复普通文字复制降级问题，复验后无进一步有效 finding。
- 方案评估：共享 SVG 文本附件满足原生选择、复制和滚动要求；独立开关不改变 Markdown 选择，也不依赖额外 TeX 安装。
- `codesign --verify --deep --strict build/Easydict-debug.app` 通过；干净替换产物并启动，仅为本机调试版打开公式选项。
- 交互回归：LLDB 复现了首次查询因 `MarkdownLabel` 未实现 `init(frame:textContainer:)` 而触发的 fatal error。移除新增 initializer，改在视图挂接窗口时订阅偏好，保留 AppKit 的继承初始化链。修复后同一 hello 查询成功创建窗口，主线程采样正常空闲，32 项既有测试再次通过；旧玻璃分支没有这些 initializer 改动。
- 手动检查：尚未在实际应用中逐项确认公式选择/复制、经典窗口高度、流式边界与多屏行为，待用户试用反馈；界面自动化此前不可用。

### 2026-10-18：公式闪烁与深浅色外观修复

- 用户反馈 Google 译文中的 `$CWG$`、`$C$`、`$W$`、`$G$` 间歇保留源码，且夜间模式下公式呈黑色；范围覆盖共用 MarkdownLabel 的经典及玻璃窗口。
- 原代码在构造附件和判断 pending 时分别读取可被后台更新或驱逐的缓存，布局更新又使旧回调失效。改为取得完整结果批次后一次替换，当前标签强持有批次，宽度和外观变化不重新请求或丢弃公式。
- 在视图 effectiveAppearance 下解析动态前景色并生成 SVG 附件，保留 alpha；外观变化时重新着色。经典结果窗口只更新现有标签尺寸和总高度，避免重建标签丢失批次及选择。
- Xcode 27.1 (27A9275) Debug arm64 build-for-testing 成功；随后 test-without-building 运行 MarkdownRendererTests、ReverseTranslationTests、OpenAIStreamTaskControlTests，共 32 项既有测试通过。使用默认 macOS 27 图标，未新增或扩写测试。
- 原生渲染诊断使用用户提供的译文，确认四个公式附件完整、五次宽度调整后仍完整，复制还原 LaTeX；人工检查浅色/深色绘图预览，公式颜色与正文一致。
- SwiftLint 和 git diff --check 通过；review 检查完整批次、缓存驱逐、失败结果、内容代次、宽度与外观切换、经典高度更新和复制，最终生产文件摘要不变，无进一步有效 finding。
- 修复版已通过 codesign 校验，替换固定 `build/Easydict-debug.app` 并启动；退出测试目录遗留的第二个进程。CUA 仍超时，实际应用的连续翻译、主题切换及经典窗口交互仍待用户确认；原生预览不替代完整 UI 验收。
- 本次只修改 `math-rendering`，保留本分支的设置修复；`liquid-glass-mini` 与现有 PR 不变，未推送本次修复。

### 受影响文件

- `BuildTools/MathJax/`：包装源码、构建脚本、版本锁和说明。
- `Easydict/Swift/Feature/Math/`：解析、排版缓存、原生附件及离线资源。
- `Easydict/Swift/Feature/Markdown/MarkdownLabel.swift`
- `Easydict/Swift/Feature/Configuration/Defaults.Keys+Extension.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/GeneralTab.swift`
- `Easydict/Swift/View/Window/GlassMiniView.swift`
- `Easydict/Swift/View/Window/GlassMiniTextView.swift`
- `Easydict/Swift/View/Window/GlassMiniPresentation.swift`
- `Easydict/objc/ViewController/View/WordResultView/EZWordResultView.m`
- `Easydict/App/Localizable.xcstrings`
- `Easydict.xcodeproj/project.pbxproj`
- 本任务 plan/history。

### 后续事项

- 第二个 PR 应以 `liquid-glass-mini` 为比较基准，或等待第一个 PR 合并后调整基线；本轮未创建 PR。
- 未支持的 TeX 扩展会显示源文；每个结果最多处理 64 个公式，每个公式最多 4096 个字符。
- 设置共有补丁见 [记录](2026-10-17-settings-login-item.md)；源于主线程同步查询登录项状态，与公式初始化崩溃是两个独立问题。
- 继续收集实际交互反馈；如需扩充自动化公式测试，另行取得用户授权。
