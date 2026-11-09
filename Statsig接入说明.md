# Statsig 配置与启动路由

在 Statsig 中创建 Dynamic Config，名称为 `slotmachine_app`，将 `StatsigConfig.example.json` 的内容作为默认配置。配置对所有用户一致。应用的 `SlotMachineSuite/Info.plist` 中，`StatsigConfigName` 已填写这个名称；`StatsigClientSDKKey` 需要填客户端 SDK Key（`client-` 开头），不能填服务端 Secret Key。示例中的 project 和 URL 故意留空，默认进入原生游戏。

## project 与 URL

首次启动没有本地 project 时，采用远端 `project`，删除空白字符并转小写后保存。以后启动始终使用保存过的 project，远端修改不会覆盖它；但每次新进程启动仍会初始化 Statsig，请求最新配置。这里“本地优先”仅指 project 的选择，不会跳过 URL 更新。

URL 字段为 `{project}_url`。例如 project 为 `csc` 时读取 `csc_url` 并使用 CSC 协议；project 为 `us` 时读取 `us_url`，为 `good` 时读取 `good_url`，为 `HAppt` 时读取 `happt_url`。除 `csc` 外的任意非空 project 都使用 US 协议。

要测试 US，可以将默认配置的 `project` 设置为 `us`，并将 `us_url` 设置为正式或测试 HTTPS 地址。测试 CSC 则使用 `project: csc` 和对应 `csc_url`。单个 Dynamic Config 中可以同时保留多个 URL 字段，客户端只读取已经选定的 project 对应字段。

远端 URL 和附加配置有效时，保存该 project 的完整网页配置，并使用最新 URL；远端 URL 缺失、无效、请求失败、超过启动等待时间或 Key 未配置时，尝试使用这个 project 的缓存。没有本地 project 且远端也没有 project，或没有任何有效 URL，进入原生游戏。已经保存的 project 即使暂时拿不到 URL，也不会被删除。

此版本不再用旧的 `web_enabled` 或固定 `url` 字段控制路由。把远端 project 或 URL 清空不会关闭已经缓存的网页路由；这是图中“本地 project 优先、URL 缓存兜底”的结果。若需要运营关闭开关，必须另行定义明确的失效规则，不应把清空字段当作关闭机制。

## URL 校验及附加字段

地址必须是具有有效 host、没有用户名或密码的 HTTPS URL。`allowed_hosts` 是额外允许的精确域名数组，例如 `["login.example.com"]`；入口地址的域名会自动加入。数组元素不能包含 scheme、路径、端口、通配符、query 或 fragment。自动跳转需要经过的每个域名都应配置，否则导航会被阻止。

`query_params` 只允许字符串键值对。基础 URL 的 query 和 fragment 会保留；原生设备与桥接保留字段由原生提供，不能通过远端覆盖。`title` 是可选页面标题。无效的可选白名单项和非字符串参数会被忽略，不会扩大访问权限，也不会阻止有效远端 URL 优先使用。URL 与清理后的白名单、参数一同按 project 缓存；远端 URL 无效时会使用对应缓存的完整快照。

可选归因字段为 `apfDevKey`、`apfAppId`、`adjustToken`、`adjEnvironment`，也兼容 `AppsFlyerDevKey`、`AppsFlyerAppID`、`AdjustAppToken`、`AdjustEnvironment` 等已有别名。已验证的非空凭据会保存用于离线启动；SDK 一旦初始化不会在本次进程重启。旧工程的远端启动事件名称没有在本次改造中接入。

## 网页协议范围

US 使用 `HAminiBridgeIOS` 的 `cmd/data` 协议，支持复制文本、HTTPS 外部链接、ATT、已有事件转发和关闭。ATT 结果包含 `status/idfa/idfv`，通过 DOM `ON_ATT_STATUS` 和可用时的 `cc.director.emit` 分发。

CSC 使用 `winnerNative/slotNative`，支持字典或 JSON 字符串的 `method/data` 消息，返回 Promise 结果。页面准备好后发送 `cc_init_complete`，原生调用 `NativeToCocos.returnDeviceInfo(object)`，设备信息同时作为 CSC URL 参数传入。支持 `copy_text`、HTTPS `open_url`、`show_att`、`close` 和空字符串的 `openUrlByWebView`；ATT 另回调 `NativeToCocos.returnAtt(idfa)`。桥只允许受信的主 frame 使用，回调绑定当前文档。

当前没有接入 CSC 的 Apple 登录、专用支付、OneSignal、子游戏 WebView、预加载或归因详情轮询；对应请求返回 `status: unsupported`。未接入的能力标志为 false，归因详情对象为空，Keychain ID 为空。广告标识及当前适配器中的 IDFV/AppsFlyer UID 保持 ATT 授权约束，不创建替代跟踪标识。需要以真实 H5 联调确认它是否依赖这些额外能力，不能将本次适配视为完整 Masquerade 服务迁移。

## 本地验证

project 和网页配置分别保存在 UserDefaults 的 `SMSLaunchProject.v1` 和 `SMSLaunchWebConfigurations.v1`，归因缓存为 `SMSLaunchAttribution.v1`。开发时在同一设备上切换 project，需要删除测试应用后重装，或仅在调试环境清除这些键；单纯杀掉重启或改变 Statsig project 不会重新分配。验证“URL 更新”则无需清除缓存，只改已保存 project 对应的 URL 并冷启动。

在 Mac 上，从工程根目录运行 `bash scripts/check-launch-routing.sh`，它会编译实际的 Objective-C 配置解析代码并执行隔离 UserDefaults 的路由检查，不依赖 CocoaPods。随后通过 `.xcworkspace` 编译和真机验证首次启动、断网缓存、远端 URL 更新、无效地址、CSC/US 握手、ATT、重载及跨域跳转。本次命令环境没有 Xcode，原生测试脚本与 Archive 需在 Mac 上运行。

新增 `PrivacyInfo.xcprivacy` 声明应用自己访问 UserDefaults 的用途（CA92.1）。它不是完整的数据收集声明，SDK 和网页实际数据收集仍需体现在最终 Archive 隐私报告、隐私政策和 App Store Connect 中。
