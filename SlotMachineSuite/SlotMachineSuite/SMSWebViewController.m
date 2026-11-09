#import "SMSWebViewController.h"
#import "SlotMachineViewController.h"
#import "AttributionManager.h"
#import <WebKit/WebKit.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/AdSupport.h>

static NSString * const SMSBridgeName = @"HAminiBridgeIOS";
static NSString * const SMSDocumentIDKey = @"__smsWebDocumentID";
static void *SMSCanGoBackContext = &SMSCanGoBackContext;

@interface SMSWeakScriptHandler : NSObject <WKScriptMessageHandler>
@property (nonatomic, weak) id<WKScriptMessageHandler> target;
@end

@implementation SMSWeakScriptHandler
- (void)userContentController:(WKUserContentController *)controller
     didReceiveScriptMessage:(WKScriptMessage *)message {
    [self.target userContentController:controller didReceiveScriptMessage:message];
}
@end

@interface SMSWebViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property (nonatomic, copy) NSDictionary<NSString *, id> *configuration;
@property (nonatomic, copy) NSSet<NSString *> *allowedHosts;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) SMSWeakScriptHandler *scriptHandler;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIBarButtonItem *backButton;
@property (nonatomic, strong) UIView *failureView;
@property (nonatomic, strong) UILabel *failureLabel;
@property (nonatomic, strong) UILabel *noticeLabel;
@property (nonatomic, strong) UIAlertController *webDialog;
@property (nonatomic, copy) void (^dialogCompletion)(BOOL confirmed);
@property (nonatomic) BOOL tornDown;
@property (nonatomic) BOOL visible;
@property (nonatomic) BOOL trustedDocument;
@property (nonatomic) BOOL observingCanGoBack;
@property (nonatomic) NSUInteger documentGeneration;
@property (nonatomic) BOOL attPending;
@property (nonatomic) BOOL attRequestInFlight;
@property (nonatomic, copy) NSString *attDocumentID;
@property (nonatomic) NSUInteger attGeneration;
@end

@implementation SMSWebViewController

- (instancetype)initWithConfiguration:(NSDictionary<NSString *, id> *)configuration {
    NSParameterAssert([NSThread isMainThread]);
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Snapshot the collections so a caller cannot change the policy after construction.
        NSMutableDictionary *snapshot = [configuration mutableCopy];
        snapshot[@"query_params"] = [[NSDictionary alloc] initWithDictionary:configuration[@"query_params"]
                                                                copyItems:YES];
        snapshot[@"url"] = [configuration[@"url"] copy];
        if (configuration[@"title"]) snapshot[@"title"] = [configuration[@"title"] copy];
        NSMutableSet *hosts = [NSMutableSet set];
        for (NSString *host in configuration[@"allowed_hosts"]) {
            [hosts addObject:host.lowercaseString];
        }
        _allowedHosts = [hosts copy];
        snapshot[@"allowed_hosts"] = _allowedHosts.allObjects;
        _configuration = [snapshot copy];
        self.title = snapshot[@"title"] ?: @"网页";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.hidesBackButton = YES;
    self.backButton = [[UIBarButtonItem alloc] initWithTitle:@"后退" style:UIBarButtonItemStylePlain
                                                    target:self action:@selector(goBack)];
    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain
                                                           target:self action:@selector(returnToNative)];
    self.navigationItem.leftBarButtonItems = @[self.backButton, close];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.spinner];

    WKWebViewConfiguration *webConfiguration = [WKWebViewConfiguration new];
    webConfiguration.allowsInlineMediaPlayback = YES;
    webConfiguration.allowsAirPlayForMediaPlayback = NO;
    webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = NO;
    self.scriptHandler = [SMSWeakScriptHandler new];
    self.scriptHandler.target = self;
    [webConfiguration.userContentController addScriptMessageHandler:self.scriptHandler name:SMSBridgeName];
    // A fresh, read-only identity per main-frame document guards delayed ATT delivery, including reloads.
    NSString *identityScript =
        @"(function(){var v=new Uint32Array(4);crypto.getRandomValues(v);"
         "Object.defineProperty(window,'__smsWebDocumentID',"
         "{value:Array.from(v).join('-'),writable:false,configurable:false});})();";
    [webConfiguration.userContentController addUserScript:
        [[WKUserScript alloc] initWithSource:identityScript injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                           forMainFrameOnly:YES]];
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:webConfiguration];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.observingCanGoBack = YES;
    [self.webView addObserver:self forKeyPath:@"canGoBack"
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:SMSCanGoBackContext];
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webView];
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor]
    ]];
    [self buildStatusViews];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification object:nil];
    [center addObserver:self selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification object:nil];
    [self retryLoading];
}

- (void)buildStatusViews {
    self.failureView = [UIView new];
    self.failureView.backgroundColor = UIColor.systemBackgroundColor;
    self.failureView.translatesAutoresizingMaskIntoConstraints = NO;
    self.failureView.hidden = YES;
    [self.view addSubview:self.failureView];
    self.failureLabel = [UILabel new];
    self.failureLabel.textAlignment = NSTextAlignmentCenter;
    self.failureLabel.numberOfLines = 0;
    self.failureLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.failureLabel.adjustsFontForContentSizeCategory = YES;
    UIButton *retry = [UIButton buttonWithType:UIButtonTypeSystem];
    [retry setTitle:@"重试" forState:UIControlStateNormal];
    [retry addTarget:self action:@selector(retryLoading) forControlEvents:UIControlEventTouchUpInside];
    UIButton *native = [UIButton buttonWithType:UIButtonTypeSystem];
    [native setTitle:@"返回原生游戏" forState:UIControlStateNormal];
    [native addTarget:self action:@selector(returnToNative) forControlEvents:UIControlEventTouchUpInside];
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.failureLabel, retry, native]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.failureView addSubview:stack];
    self.noticeLabel = [UILabel new];
    self.noticeLabel.backgroundColor = UIColor.secondarySystemBackgroundColor;
    self.noticeLabel.textColor = UIColor.labelColor;
    self.noticeLabel.numberOfLines = 0;
    self.noticeLabel.textAlignment = NSTextAlignmentCenter;
    self.noticeLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.noticeLabel.adjustsFontForContentSizeCategory = YES;
    self.noticeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.noticeLabel.hidden = YES;
    [self.view addSubview:self.noticeLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.failureView.topAnchor constraintEqualToAnchor:self.webView.topAnchor],
        [self.failureView.bottomAnchor constraintEqualToAnchor:self.webView.bottomAnchor],
        [self.failureView.leadingAnchor constraintEqualToAnchor:self.webView.leadingAnchor],
        [self.failureView.trailingAnchor constraintEqualToAnchor:self.webView.trailingAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.failureView.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.failureView.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.failureView.trailingAnchor constant:-24],
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:self.failureView.topAnchor constant:8],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.failureView.bottomAnchor constant:-8],
        [retry.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [native.heightAnchor constraintGreaterThanOrEqualToConstant:44],
        [self.noticeLabel.leadingAnchor constraintEqualToAnchor:self.webView.leadingAnchor constant:12],
        [self.noticeLabel.trailingAnchor constraintEqualToAnchor:self.webView.trailingAnchor constant:-12],
        [self.noticeLabel.bottomAnchor constraintEqualToAnchor:self.webView.bottomAnchor constant:-12]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.visible = YES;
    [self updateMediaSuspension];
    [self processPendingATT];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.visible = NO;
    [self updateMediaSuspension];
    [self finishWebDialog:NO];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed ||
        self.navigationController.isBeingDismissed || !self.parentViewController) {
        [self tearDown];
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    [super didMoveToParentViewController:parent];
    if (!parent && self.isViewLoaded) [self tearDown];
}

- (void)dealloc {
    [self tearDown];
}

#pragma mark - URL construction and policy

- (BOOL)isAllowedWebURL:(NSURL *)url {
    return [url.scheme.lowercaseString isEqualToString:@"https"] &&
           url.host.length > 0 && [self.allowedHosts containsObject:url.host.lowercaseString] &&
           url.user == nil && url.password == nil;
}

- (BOOL)isHTTPSURL:(NSURL *)url {
    return [url.scheme.lowercaseString isEqualToString:@"https"] && url.host.length > 0 &&
           url.user == nil && url.password == nil;
}

- (BOOL)isTrackingAuthorized {
    if (@available(iOS 14.0, *)) {
        return ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusAuthorized;
    }
    return NO;
}

- (NSURL *)initialURL {
    NSURLComponents *components = [NSURLComponents componentsWithString:self.configuration[@"url"]];
    if (![self isAllowedWebURL:components.URL]) return nil;
    NSMutableDictionary<NSString *, NSString *> *parameters = [self.configuration[@"query_params"] mutableCopy];
    NSDictionary<NSString *, NSString *> *native = [[AttributionManager sharedManager] webQueryParameters];
    NSSet *trackingKeys = [NSSet setWithArray:@[@"idfa", @"idfv", @"apf"]];
    NSSet *nativeKeys = [NSSet setWithArray:@[@"pkg", @"channel", @"jsb", @"supportVersion", @"supportShowAtt",
                                            @"idfa", @"idfv", @"apf"]];
    // Native/reserved fields can only come from the adapter, never from remote configuration.
    [parameters removeObjectsForKeys:nativeKeys.allObjects];
    BOOL authorized = [self isTrackingAuthorized];
    [native enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class] &&
            (authorized || ![trackingKeys containsObject:key])) {
            parameters[key] = value;
        }
    }];
    parameters[@"jsb"] = SMSBridgeName;
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![nativeKeys containsObject:item.name] && !parameters[item.name]) [items addObject:item];
    }
    for (NSString *key in [parameters.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [items addObject:[NSURLQueryItem queryItemWithName:key value:parameters[key]]];
    }
    components.queryItems = items.count ? items : nil;
    // NSURLComponents retains the original fragment and encodes individual query names/values.
    return components.URL;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (self.tornDown) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    NSURL *url = action.request.URL;
    BOOL newWindow = action.targetFrame == nil;
    BOOL mainFrame = newWindow || action.targetFrame.isMainFrame;
    BOOL userLink = action.navigationType == WKNavigationTypeLinkActivated;
    if ([self isAllowedWebURL:url]) {
        if (newWindow) {
            // This delegate owns target=_blank routing; createWebView never loads a second time.
            decisionHandler(WKNavigationActionPolicyCancel);
            [webView loadRequest:action.request];
        } else {
            decisionHandler(WKNavigationActionPolicyAllow);
        }
        return;
    }
    if (!mainFrame && [url.absoluteString isEqualToString:@"about:blank"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }
    decisionHandler(WKNavigationActionPolicyCancel);
    if (mainFrame && userLink && [self isHTTPSURL:url]) {
        [self openExternalURL:url];
        return;
    }
    NSString *scheme = url.scheme.lowercaseString;
    if (userLink && ([scheme isEqualToString:@"tel"] || [scheme isEqualToString:@"mailto"])) {
        [self openExternalURL:url];
        return;
    }
    NSString *message = @"已阻止此链接：仅允许授权的 HTTPS 网页；外部链接需要由用户点击打开。";
    if (mainFrame) [self showFailure:message];
    else [self showNotice:message];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)response
    decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSURL *url = response.response.URL;
    BOOL allowed = [self isAllowedWebURL:url] ||
                   (!response.isForMainFrame && [url.absoluteString isEqualToString:@"about:blank"]);
    if (self.tornDown || !allowed || !response.canShowMIMEType) {
        decisionHandler(WKNavigationResponsePolicyCancel);
        if (!self.tornDown) {
            if (response.isForMainFrame) [self showFailure:@"此网页未获授权，或其内容无法显示。"];
            else [self showNotice:@"已阻止未授权或不支持的网页内容。"];
        }
        return;
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
  forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)windowFeatures {
    return nil;
}

- (void)openExternalURL:(NSURL *)url {
    if (self.tornDown || !url) return;
    __weak typeof(self) weakSelf = self;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success) [weakSelf showNotice:@"无法打开外部链接，请检查设备是否支持该链接。"];
        });
    }];
}

#pragma mark - Loading and native return

- (void)invalidateDocument {
    self.trustedDocument = NO;
    self.documentGeneration++;
    self.attPending = NO;
    self.attDocumentID = nil;
    [self finishWebDialog:NO];
}

- (void)retryLoading {
    if (self.tornDown) return;
    [self invalidateDocument];
    self.failureView.hidden = YES;
    self.noticeLabel.hidden = YES;
    NSURL *url = [self initialURL];
    if (!url) {
        [self showFailure:@"网页地址无效或未包含在授权域名中。"];
        return;
    }
    [self.spinner startAnimating];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
    [self updateBackButton];
}

- (void)goBack {
    if (self.webView.canGoBack && !self.tornDown) {
        self.failureView.hidden = YES;
        self.noticeLabel.hidden = YES;
        [self.webView goBack];
    }
}

- (void)returnToNative {
    if (self.tornDown) return;
    UINavigationController *navigation = self.navigationController;
    if (!navigation) {
        [self showFailure:@"无法返回游戏：缺少导航容器。"];
        return;
    }
    [self tearDown];
    navigation.viewControllers = @[[SlotMachineViewController new]];
    [navigation setNavigationBarHidden:YES animated:NO];
}

- (void)updateBackButton {
    self.backButton.enabled = !self.tornDown && self.webView.canGoBack;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                       change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if (context == SMSCanGoBackContext) {
        [self updateBackButton];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)showNotice:(NSString *)message {
    if (self.tornDown) return;
    self.noticeLabel.text = message;
    self.noticeLabel.hidden = NO;
}

- (void)showFailure:(NSString *)message {
    if (self.tornDown) return;
    [self invalidateDocument];
    [self.spinner stopAnimating];
    self.failureLabel.text = message;
    self.failureView.hidden = NO;
    self.noticeLabel.hidden = YES;
    [self updateBackButton];
    [self updateMediaSuspension];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self invalidateDocument];
    self.failureView.hidden = YES;
    self.noticeLabel.hidden = YES;
    [self.spinner startAnimating];
    [self updateBackButton];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    self.trustedDocument = !self.tornDown && self.failureView.hidden && [self isAllowedWebURL:webView.URL];
    [self updateBackButton];
    [self updateMediaSuspension];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.spinner stopAnimating];
    self.trustedDocument = !self.tornDown && [self isAllowedWebURL:webView.URL] && self.failureView.hidden;
    [self updateBackButton];
    [self updateMediaSuspension];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return;
    [self showFailure:@"网页加载失败，请检查网络连接后重试，或返回原生游戏。"];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) return;
    [self showFailure:@"网页加载中断，请重试，或返回原生游戏。"];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [self showFailure:@"网页进程已停止，请重试，或返回原生游戏。"];
}

#pragma mark - Bridge authorization and commands

- (BOOL)isAuthorizedFrame:(WKFrameInfo *)frame {
    if (self.tornDown || !self.trustedDocument || !frame.isMainFrame ||
        ![self isAllowedWebURL:self.webView.URL] || ![self isAllowedWebURL:frame.request.URL]) return NO;
    WKSecurityOrigin *origin = frame.securityOrigin;
    NSURL *current = self.webView.URL;
    NSInteger currentPort = current.port ? current.port.integerValue : 443;
    NSInteger originPort = origin.port ? origin.port : 443;
    return [origin.protocol.lowercaseString isEqualToString:@"https"] &&
           [self.allowedHosts containsObject:origin.host.lowercaseString] &&
           [current.host.lowercaseString isEqualToString:origin.host.lowercaseString] && currentPort == originPort;
}

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    if (message.webView != self.webView || ![message.name isEqualToString:SMSBridgeName] ||
        ![self isAuthorizedFrame:message.frameInfo] || ![message.body isKindOfClass:NSDictionary.class]) return;
    NSDictionary *body = message.body;
    NSString *command = body[@"cmd"];
    if (![command isKindOfClass:NSString.class]) return;
    NSDictionary *data = [body[@"data"] isKindOfClass:NSDictionary.class] ? body[@"data"] : @{};
    if ([command isEqualToString:@"openUrlByDefaultBrowser"]) {
        NSString *value = data[@"url"];
        NSURL *url = [value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil;
        if ([self isHTTPSURL:url]) [self openExternalURL:url];
        else [self showNotice:@"外部浏览器仅支持有效的 HTTPS 链接。"];
    } else if ([command isEqualToString:@"copyText"]) {
        NSString *text = data[@"text"];
        if ([text isKindOfClass:NSString.class]) UIPasteboard.generalPasteboard.string = text;
    } else if ([command isEqualToString:@"showAtt"]) {
        [self prepareATTForCurrentDocument];
    } else if ([command isEqualToString:@"logEvent"]) {
        NSString *name = data[@"name"];
        id values = data[@"values"];
        if ([name isKindOfClass:NSString.class] && name.length > 0 &&
            (!values || ([values isKindOfClass:NSDictionary.class] && [NSJSONSerialization isValidJSONObject:values]))) {
            [[AttributionManager sharedManager] logEvent:name values:values ?: @{}];
        }
    } else if ([command isEqualToString:@"close"]) {
        [self returnToNative];
    }
}

#pragma mark - ATT, scoped to the requesting document

- (void)prepareATTForCurrentDocument {
    if (self.attPending || self.attRequestInFlight || self.tornDown) return;
    NSUInteger generation = self.documentGeneration;
    __weak typeof(self) weakSelf = self;
    [self.webView evaluateJavaScript:[@"window." stringByAppendingString:SMSDocumentIDKey]
                 completionHandler:^(id result, NSError *error) {
        SMSWebViewController *self = weakSelf;
        if (!self || self.tornDown || error || self.documentGeneration != generation || !self.trustedDocument ||
            ![self isAllowedWebURL:self.webView.URL] || ![result isKindOfClass:NSString.class] ||
            self.attPending || self.attRequestInFlight) return;
        self.attDocumentID = result;
        self.attGeneration = generation;
        self.attPending = YES;
        [self processPendingATT];
    }];
}

- (void)processPendingATT {
    if (!self.attPending || self.attRequestInFlight || self.tornDown || !self.visible ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    self.attPending = NO;
    NSUInteger generation = self.attGeneration;
    NSString *documentID = self.attDocumentID;
    if (generation != self.documentGeneration || !self.trustedDocument || ![self isAllowedWebURL:self.webView.URL]) return;
    if (@available(iOS 14.0, *)) {
        ATTrackingManagerAuthorizationStatus status = ATTrackingManager.trackingAuthorizationStatus;
        if (status == ATTrackingManagerAuthorizationStatusNotDetermined) {
            // Without this usage description iOS may terminate the app; keep the result honest instead.
            NSString *description = [NSBundle.mainBundle objectForInfoDictionaryKey:@"NSUserTrackingUsageDescription"];
            if (![description isKindOfClass:NSString.class] || description.length == 0) {
                [self showNotice:@"当前应用未配置跟踪授权说明，无法发起授权请求。"];
                [self emitATTStatus:@"notDetermined" generation:generation documentID:documentID];
                return;
            }
            self.attRequestInFlight = YES;
            __weak typeof(self) weakSelf = self;
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus result) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    SMSWebViewController *self = weakSelf;
                    if (!self) return;
                    self.attRequestInFlight = NO;
                    [self emitATTStatus:[self stringForATTStatus:result] generation:generation documentID:documentID];
                });
            }];
        } else {
            [self emitATTStatus:[self stringForATTStatus:status] generation:generation documentID:documentID];
        }
    } else {
        [self emitATTStatus:@"unavailable" generation:generation documentID:documentID];
    }
}

- (NSString *)stringForATTStatus:(ATTrackingManagerAuthorizationStatus)status API_AVAILABLE(ios(14.0)) {
    switch (status) {
        case ATTrackingManagerAuthorizationStatusAuthorized: return @"authorized";
        case ATTrackingManagerAuthorizationStatusDenied: return @"denied";
        case ATTrackingManagerAuthorizationStatusRestricted: return @"restricted";
        case ATTrackingManagerAuthorizationStatusNotDetermined: return @"notDetermined";
    }
    return @"unknown";
}

- (void)emitATTStatus:(NSString *)status generation:(NSUInteger)generation documentID:(NSString *)documentID {
    if (self.tornDown || !self.trustedDocument || generation != self.documentGeneration ||
        ![self isAllowedWebURL:self.webView.URL] || !documentID.length) return;
    NSString *idfa = @"";
    if ([status isEqualToString:@"authorized"] && [self isTrackingAuthorized]) {
        idfa = ASIdentifierManager.sharedManager.advertisingIdentifier.UUIDString ?: @"";
    }
    NSDictionary *detail = @{@"status": status, @"idfa": idfa};
    NSDictionary *arguments = @{@"detail": detail, @"documentID": documentID,
                                @"hosts": self.allowedHosts.allObjects};
    // Frame nil is the main frame. Check again inside that document at execution time to close navigation races.
    NSString *script =
        @"if(location.protocol==='https:' && hosts.indexOf(location.hostname.toLowerCase())!==-1 && "
         "window.__smsWebDocumentID===documentID) {"
         "window.dispatchEvent(new CustomEvent('ON_ATT_STATUS',{detail:detail}));}";
    if (@available(iOS 14.0, *)) {
        [self.webView callAsyncJavaScript:script arguments:arguments inFrame:nil
                          inContentWorld:WKContentWorld.pageWorld completionHandler:nil];
    }
}

#pragma mark - JavaScript dialogs

- (void)presentWebDialog:(NSString *)message frame:(WKFrameInfo *)frame confirm:(BOOL)confirm
             completion:(void (^)(BOOL))completion {
    if (![self isAuthorizedFrame:frame] || !self.visible || self.presentedViewController || self.dialogCompletion) {
        completion(NO);
        return;
    }
    self.dialogCompletion = completion;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:frame.securityOrigin.host
                                                                 message:message preferredStyle:UIAlertControllerStyleAlert];
    self.webDialog = alert;
    __weak typeof(self) weakSelf = self;
    if (confirm) {
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [weakSelf finishWebDialog:NO];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf finishWebDialog:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)finishWebDialog:(BOOL)confirmed {
    void (^completion)(BOOL) = self.dialogCompletion;
    self.dialogCompletion = nil;
    UIAlertController *alert = self.webDialog;
    self.webDialog = nil;
    if (alert.presentingViewController) [alert dismissViewControllerAnimated:NO completion:nil];
    if (completion) completion(confirmed);
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message
 initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    [self presentWebDialog:message frame:frame confirm:NO completion:^(BOOL confirmed) { completionHandler(); }];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message
 initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    [self presentWebDialog:message frame:frame confirm:YES completion:completionHandler];
}

#pragma mark - Application lifecycle and cleanup

- (void)applicationWillResignActive:(NSNotification *)notification {
    if (@available(iOS 15.0, *)) [self.webView setAllMediaPlaybackSuspended:YES completionHandler:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self updateMediaSuspension];
    [self processPendingATT];
}

- (void)updateMediaSuspension {
    if (@available(iOS 15.0, *)) {
        BOOL suspend = self.tornDown || !self.visible || !self.failureView.hidden ||
                       UIApplication.sharedApplication.applicationState != UIApplicationStateActive;
        [self.webView setAllMediaPlaybackSuspended:suspend completionHandler:nil];
    }
}

- (void)tearDown {
    if (_tornDown) return;
    _tornDown = YES;
    _trustedDocument = NO;
    _documentGeneration++;
    _attPending = NO;
    _attDocumentID = nil;
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (_observingCanGoBack) {
        [_webView removeObserver:self forKeyPath:@"canGoBack" context:SMSCanGoBackContext];
        _observingCanGoBack = NO;
    }
    _scriptHandler.target = nil;
    [_webView.configuration.userContentController removeScriptMessageHandlerForName:SMSBridgeName];
    [_webView.configuration.userContentController removeAllUserScripts];
    _webView.navigationDelegate = nil;
    _webView.UIDelegate = nil;
    [_webView stopLoading];
    if (@available(iOS 15.0, *)) [_webView setAllMediaPlaybackSuspended:YES completionHandler:nil];
    [_spinner stopAnimating];
    [self finishWebDialog:NO];
}

@end
