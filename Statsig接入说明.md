# Statsig Parameter Store 接入与启动路由

应用通过 Statsig iOS SDK 1.62.9 的 `Statsig.getParameterStore` 读取 `csc_info` 和 `us_info`。用户提供的客户端 SDK Key 已填写到 `SlotMachineSuite/Info.plist` 的 `StatsigClientSDKKey`。不再读取旧 Dynamic Config `slotmachine_app`，也不需要 `StatsigConfigName`。

`StatsigConfig.example.json` 是两个仓库的参数对照示例。请在 Statsig 控制台分别维护同名 Parameter Store，把每个对象内的字段建成对应仓库的参数；不要把整份文件建成一个 Dynamic Config。示例 URL 留空、open 默认关闭；实际地址需要从控制台完整填写，截图中的截断地址不可作为有效配置。

## open 与仓库选择

每次新进程启动都会请求 Statsig。只有本次成功获取或经服务端确认未变化的配置才能参与决策。读取到的 `open` 必须是 boolean 类型的 true；false、缺失、字符串 "true"、数字 1 以及其他类型都不能开启网页。客户端通过 Parameter Store 的类型化 API 读取参数，默认值为 false。

`csc_info.open=true` 且该仓库有有效 URL 时选择 CSC，使用 CSC bridge。否则检查 `us_info`，同样要求 open=true 和有效 URL，使用 US bridge。两者同时可用时固定 CSC 优先；两者都不可用时进入原生游戏。不按地区、归因结果或 `source` 选择仓库，也不再用本地 project 锁定选择。日志只记录配置来源、URL 来源和最终协议，不输出 Key、URL 或 query 内容。

Statsig 初始化超时为 4 秒，启动流程另有 5 秒的最终回退。网络失败、超时、Key 无效或仅取得未经本次服务端确认的 SDK 缓存时进入原生游戏。迟到的回调不会再次切换页面，同一进程的多个调用共享一次启动结果。开关修改在下次冷启动生效。

## URL 和缓存

地址直接读取各仓库的 `url`，必须是具有 host、不含用户名和密码的 HTTPS URL。`allowed_hosts` 是可选的精确域名数组，入口域名自动加入；域名元素不能包含 scheme、路径、端口、通配符、query 或 fragment。跨域导航需要在这里配置；无效元素会被忽略。

`query_params` 是可选字符串键值对象，其他类型的值会被忽略。基础 URL 中的 query 和 fragment 会保留。原生设备、bridge、跟踪及 source 等保留字段由原生提供，不能由 URL 内已有参数或 query_params 覆盖。`title` 可选，默认为 Starlight。

有效 URL、白名单和 query 参数按仓库保存在 `SMSParameterStoreWebConfigurations.v2`。仅当本次该仓库明确 open=true、而 URL 缺失或无效时，才尝试使用同一仓库的完整 URL 快照；不会混用另一仓库的地址、域名或 query。ATT 和 source 标志始终使用本次值，归因凭据不从快照恢复。

本次取得的仓库 open 为 false、缺失或类型错误时，清除该仓库快照，不允许缓存绕过关闭。若请求失败、没有取得任何仓库，则当次进入原生并保留 URL 数据，以供以后成功取得 open=true 时使用。旧版 `SMSLaunchProject.v1`、`SMSLaunchWebConfigurations.v1` 和 `SMSLaunchAttribution.v1` 都不再读取，不会恢复旧路由或旧归因凭据。

## ATT、source 与 Adjust

`preShowAtt` 为 boolean。true 时，在选中的网页首次加载前，等待页面可见且应用处于 Active，再在系统尚未决定 ATT 状态时发起一次请求。已有授权结果、false 或类型不符时直接加载。授权返回后才构造入口 URL，从而使用最新授权状态；拒绝不阻止网页加载，不重复自动弹窗。网页仍可通过已有 showAtt/show_att bridge 主动请求 ATT。

`source` 为 boolean，默认 false。目前仅保留为网页 URL 的 `source=true` 或 `source=false` 参数，不承担路由、地域判断或归因判断功能。若 H5 对此字段另有约定，需要按其真实协议联调。

`adjustToken` 为 12 位字母数字 App Token，空值或格式无效会被忽略。`adjEnvironment` 忽略大小写和首尾空白，仅 sandbox 选择测试环境，空值及其他值使用 production。`adjustStartEvent` 是 6 位字母数字的 Adjust Event Token；选中仓库、成功初始化 Adjust 后，每个进程至多发送一次该启动事件。没有可用 App Token 或没有链接 SDK 时不发送。

`adjustEvent_a` 及其他 `adjustEvent_*` 字符串定义事件映射，值同样要求 6 位字母数字 Token。US bridge 的 `logEvent`、CSC bridge 的 `log_event` 接受包含 name 和可选 values 的事件对象。name 为 `a` 或 `adjustEvent_a` 时会查找 `adjustEvent_a` 映射；values 中合法的 `adjust_event_token` 可以直接指定事件。未配置 Token 不会上报虚假的 Adjust 成功结果，也不会把 App Token 或事件 Token 加入网页 URL。

可选的 `apfDevKey`、`apfAppId` 分别映射到 AppsFlyer 凭据。仅对已选中网页仓库应用远端归因配置，不混用未选中仓库的值，不保留旧仓库凭据作为下次离线回退。Info.plist 中显式填写的本地归因凭据仍可用于应用启动；SDK 一旦初始化不会在本进程内重启或切换凭据。因此使用远端 Adjust 配置时，应保持 Info.plist 的 AdjustAppToken 为空。广告标识以及当前适配器的 IDFV/AppsFlyer UID 仍受 ATT 授权约束，不创建替代跟踪标识。

## 网页协议与验证

US 使用 `HAminiBridgeIOS` 的 cmd/data 协议，支持复制、HTTPS 外部链接、ATT、事件和关闭。ATT 结果包含 status/idfa/idfv，通过 DOM `ON_ATT_STATUS` 和可用时的 `cc.director.emit` 分发。CSC 使用 winnerNative/slotNative 的 method/data 协议，支持字典或 JSON 字符串，返回 Promise 结果；准备完成的 cc_init_complete 会触发 `NativeToCocos.returnDeviceInfo`，ATT 另回调 `NativeToCocos.returnAtt`。bridge 只允许受信的主 frame 使用，延迟回调绑定当前文档。

CSC 的 Apple 登录、专用支付、OneSignal、子游戏 WebView、预加载和归因详情轮询仍未接入，相关请求返回 unsupported。能力标志、归因详情和 Keychain ID 不伪造为已实现。实际 H5 需要联调确认依赖的能力。

在 Mac 工程根目录运行 `bash scripts/check-launch-routing.sh`，编译实际 Objective-C 参数解析器并执行隔离 UserDefaults 的回归检查。检查涵盖双仓库优先级、严格 Boolean、关闭清缓存、请求失败、fresh open 下 URL 回退、跨仓库隔离、旧缓存迁移、坏值过滤和 Adjust 参数。然后使用 `SlotMachineSuite.xcworkspace` 编译并真机验证启动、ATT 前后台、H5 握手与事件上报。当前 Linux 命令环境没有 Xcode，不能据此声称已完成 iOS 编译、原生测试脚本或真机网络联调。

项目已声明 UserDefaults 的隐私用途（CA92.1）。最终 Archive 中 SDK 和网页的实际数据收集仍应与应用隐私说明一致。

参考：Statsig 1.62.9 的 [ParameterStore API](https://github.com/statsig-io/statsig-kit/blob/1.62.9/Sources/Statsig/ParameterStore.swift)、[Statsig 初始化与读取 API](https://github.com/statsig-io/statsig-kit/blob/1.62.9/Sources/Statsig/Statsig.swift) 和 [EvaluationSource 定义](https://github.com/statsig-io/statsig-kit/blob/1.62.9/Sources/Statsig/EvaluationDetails.swift)。
