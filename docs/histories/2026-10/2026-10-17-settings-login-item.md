## 2026-10-17 | 任务：避免登录项状态查询阻塞设置窗口

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-17-settings-login-item.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 26.5 (17F42)`

### 用户请求

排查设置打开卡顿；如果旧玻璃分支也受影响，同步修复。

### 变更

- 使用 LoginItemToggle 替换 LaunchAtLogin.Toggle，移除在 SwiftUI body 中同步查询系统状态的 onChange 表达式。
- 控件仅绑定内存缓存，出现及应用重新激活时后台刷新；最多保留一个在途请求，状态发布限定主线程。
- 用户更改开关时才在后台调用 SMAppService 注册或注销，随后读取实际状态；失败通过现有本地化标题和系统错误描述显示。
- 同一补丁应用于 liquid-glass-mini 和 math-rendering；工程加入新文件，没有新增或扩写测试。

### 设计意图

主线程采样多次出现 LaunchAtLogin.Observable.isEnabled → SMAppService.status → sendSMDRequest → 同步 XPC 等待。SwiftUI 每轮绑定与布局读取重复触发等待。对应代码在旧玻璃分支与上游基线相同，因此这是共有的设置性能问题，和公式分支的文本初始化崩溃分别处理。将系统调用移出界面读取链，保留 enabled 状态语义和用户控制权，不改变系统授权或登录项配置。

### 验证

- 修复前两次实际设置操作的 sample 调用栈确认上述等待路径。
- 同一补丁集成到公式分支后，Debug arm64 编译及 MarkdownRendererTests、ReverseTranslationTests、OpenAIStreamTaskControlTests 共 32 项既有测试通过。
- SwiftLint、git diff --check、工程 plutil 校验通过；新源码与工程引用在两个分支对应一致。
- review 检查缓存绑定、后台执行、主线程发布、并发合并、刷新与写入边界、错误处理；无有效未解决 finding。
- 新调试 app 的严格签名检查通过，已启动；连续打开/关闭设置和切换页的用户复验仍待反馈。没有通过更改实际开机启动状态来验证写入。
- SDK 声明与 Apple 的 [SMAppService 文档](https://developer.apple.com/documentation/servicemanagement/smappservice)用于核对系统状态与注册 API。

### 受影响文件

- `Easydict/Swift/View/SettingView/Tabs/TabView/LoginItemToggle.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/GeneralTab.swift`
- `Easydict.xcodeproj/project.pbxproj`
- 本任务 plan/history。

### 后续事项

- 继续收集实际设置交互反馈。未修改系统 ServiceManagement 服务本身。
