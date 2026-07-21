#import <UIKit/UIKit.h>
#import <dlfcn.h>

// ========== SimpleForceCriminal 导出函数指针定义 ==========
typedef void (*InitPluginFunc)(void);
typedef void (*SetTargetUserIdFunc)(int userId);
typedef void (*SetTargetStarsFunc)(int stars);
typedef void (*SetForceCriminalEnabledFunc)(bool enabled);
typedef void (*ModifyPlayerFunc)(void);
typedef int (*GetTargetStarsFunc)(void);
typedef bool (*IsEnabledFunc)(void);

static InitPluginFunc           fc_InitPlugin = NULL;
static SetTargetUserIdFunc      fc_SetTargetUserId = NULL;
static SetTargetStarsFunc       fc_SetTargetStars = NULL;
static SetForceCriminalEnabledFunc fc_SetForceCriminalEnabled = NULL;
static ModifyPlayerFunc         fc_ModifyPlayer = NULL;
static GetTargetStarsFunc       fc_GetTargetStars = NULL;
static IsEnabledFunc            fc_IsEnabled = NULL;

static BOOL functionsResolved = NO;

// 动态解析 SimpleForceCriminal.dylib 的导出函数
void resolveFunctions() {
    if (functionsResolved) return;
    
    // 尝试用 RTLD_DEFAULT 查找（如果 dylib 已经加载进进程）
    fc_InitPlugin = (InitPluginFunc)dlsym(RTLD_DEFAULT, "InitPlugin");
    fc_SetTargetUserId = (SetTargetUserIdFunc)dlsym(RTLD_DEFAULT, "SetTargetUserId");
    fc_SetTargetStars = (SetTargetStarsFunc)dlsym(RTLD_DEFAULT, "SetTargetStars");
    fc_SetForceCriminalEnabled = (SetForceCriminalEnabledFunc)dlsym(RTLD_DEFAULT, "SetForceCriminalEnabled");
    fc_ModifyPlayer = (ModifyPlayerFunc)dlsym(RTLD_DEFAULT, "ModifyPlayer");
    fc_GetTargetStars = (GetTargetStarsFunc)dlsym(RTLD_DEFAULT, "GetTargetStars");
    fc_IsEnabled = (IsEnabledFunc)dlsym(RTLD_DEFAULT, "IsEnabled");
    
    // 如果没找到，尝试带下划线的符号名
    if (!fc_InitPlugin) fc_InitPlugin = (InitPluginFunc)dlsym(RTLD_DEFAULT, "_InitPlugin");
    if (!fc_SetTargetUserId) fc_SetTargetUserId = (SetTargetUserIdFunc)dlsym(RTLD_DEFAULT, "_SetTargetUserId");
    if (!fc_SetTargetStars) fc_SetTargetStars = (SetTargetStarsFunc)dlsym(RTLD_DEFAULT, "_SetTargetStars");
    if (!fc_SetForceCriminalEnabled) fc_SetForceCriminalEnabled = (SetForceCriminalEnabledFunc)dlsym(RTLD_DEFAULT, "_SetForceCriminalEnabled");
    if (!fc_ModifyPlayer) fc_ModifyPlayer = (ModifyPlayerFunc)dlsym(RTLD_DEFAULT, "_ModifyPlayer");
    if (!fc_GetTargetStars) fc_GetTargetStars = (GetTargetStarsFunc)dlsym(RTLD_DEFAULT, "_GetTargetStars");
    if (!fc_IsEnabled) fc_IsEnabled = (IsEnabledFunc)dlsym(RTLD_DEFAULT, "_IsEnabled");
    
    functionsResolved = YES;
    
    // 初始化插件
    if (fc_InitPlugin) {
        fc_InitPlugin();
    }
}

// ========== 浮动菜单视图 ==========
@interface FCMFloatingView : UIView <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *userIdField;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) NSMutableArray *starButtons;
@property (nonatomic, assign) int selectedStars;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) CGPoint originalCenter;
@end

@implementation FCMFloatingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.18 alpha:0.95];
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1.0].CGColor;
        self.clipsToBounds = YES;
        self.selectedStars = 5;
        self.isEnabled = NO;
        
        [self setupUI];
        
        // 添加拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)setupUI {
    CGFloat width = self.bounds.size.width;
    CGFloat y = 10;
    
    // 标题
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y, width - 20, 20)];
    self.titleLabel.text = @"Force Criminal Menu";
    self.titleLabel.textColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1.0];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.titleLabel];
    y += 28;
    
    // ID 输入框
    self.userIdField = [[UITextField alloc] initWithFrame:CGRectMake(10, y, width - 20, 36)];
    self.userIdField.placeholder = @"输入玩家ID";
    self.userIdField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.userIdField.textColor = [UIColor whiteColor];
    self.userIdField.font = [UIFont systemFontOfSize:14];
    self.userIdField.borderStyle = UITextBorderStyleRoundedRect;
    self.userIdField.keyboardType = UIKeyboardTypeNumberPad;
    self.userIdField.delegate = self;
    [self addSubview:self.userIdField];
    y += 44;
    
    // 星级按钮 (5个)
    self.starButtons = [NSMutableArray array];
    CGFloat btnW = (width - 20 - 16) / 5;
    for (int i = 0; i < 5; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(10 + i * (btnW + 4), y, btnW, 32);
        [btn setTitle:[NSString stringWithFormat:@"%d★", i + 1] forState:UIControlStateNormal];
        btn.tintColor = [UIColor whiteColor];
        btn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        btn.layer.cornerRadius = 6;
        btn.tag = i + 1;
        [btn addTarget:self action:@selector(starButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
        [self.starButtons addObject:btn];
    }
    [self updateStarSelection];
    y += 40;
    
    // 开关按钮
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.toggleButton.frame = CGRectMake(10, y, width - 20, 40);
    [self.toggleButton setTitle:@"开启强制罪犯" forState:UIControlStateNormal];
    self.toggleButton.tintColor = [UIColor whiteColor];
    self.toggleButton.backgroundColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1.0];
    self.toggleButton.layer.cornerRadius = 8;
    self.toggleButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [self.toggleButton addTarget:self action:@selector(toggleTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.toggleButton];
    y += 48;
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, y, width - 20, 16)];
    self.statusLabel.text = @"状态: 未开启";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.statusLabel];
}

- (void)updateStarSelection {
    for (UIButton *btn in self.starButtons) {
        if (btn.tag == self.selectedStars) {
            btn.backgroundColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1.0];
        } else {
            btn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        }
    }
}

- (void)starButtonTapped:(UIButton *)sender {
    self.selectedStars = (int)sender.tag;
    [self updateStarSelection];
    
    resolveFunctions();
    if (fc_SetTargetStars) {
        fc_SetTargetStars(self.selectedStars);
    }
}

- (void)toggleTapped {
    resolveFunctions();
    
    if (!fc_SetTargetUserId || !fc_SetForceCriminalEnabled || !fc_ModifyPlayer) {
        self.statusLabel.text = @"错误: 找不到 SimpleForceCriminal 函数";
        self.statusLabel.textColor = [UIColor redColor];
        return;
    }
    
    NSString *userIdStr = self.userIdField.text;
    int userId = [userIdStr intValue];
    
    if (userId <= 0) {
        self.statusLabel.text = @"请输入有效的玩家ID";
        self.statusLabel.textColor = [UIColor orangeColor];
        return;
    }
    
    self.isEnabled = !self.isEnabled;
    
    if (self.isEnabled) {
        fc_SetTargetUserId(userId);
        fc_SetTargetStars(self.selectedStars);
        fc_SetForceCriminalEnabled(true);
        fc_ModifyPlayer();
        
        [self.toggleButton setTitle:@"关闭强制罪犯" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [UIColor colorWithRed:0.73 green:0.11 blue:0.11 alpha:1.0];
        self.statusLabel.text = [NSString stringWithFormat:@"状态: 已开启 | ID:%d | %d星", userId, self.selectedStars];
        self.statusLabel.textColor = [UIColor greenColor];
    } else {
        fc_SetForceCriminalEnabled(false);
        
        [self.toggleButton setTitle:@"开启强制罪犯" forState:UIControlStateNormal];
        self.toggleButton.backgroundColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1.0];
        self.statusLabel.text = @"状态: 已关闭";
        self.statusLabel.textColor = [UIColor lightGrayColor];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

// 拖动逻辑
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.startPoint = [gesture locationInView:self.superview];
        self.originalCenter = self.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint current = [gesture locationInView:self.superview];
        CGFloat dx = current.x - self.startPoint.x;
        CGFloat dy = current.y - self.startPoint.y;
        self.center = CGPointMake(self.originalCenter.x + dx, self.originalCenter.y + dy);
    }
}

// 点击空白收起键盘
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.userIdField resignFirstResponder];
}

@end

// ========== 全局悬浮窗 ==========
static UIWindow *floatingWindow = nil;

void createFloatingMenu() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (floatingWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat menuWidth = 240;
        CGFloat menuHeight = 220;
        
        floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, menuWidth, menuHeight)];
        floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
        floatingWindow.backgroundColor = [UIColor clearColor];
        floatingWindow.hidden = NO;
        floatingWindow.layer.cornerRadius = 12;
        
        FCMFloatingView *menuView = [[FCMFloatingView alloc] initWithFrame:floatingWindow.bounds];
        [floatingWindow addSubview:menuView];
    });
}

// ========== 初始化入口 ==========
// dylib 加载后自动执行，不依赖 Substrate
__attribute__((constructor))
static void fcm_entry() {
    // 等主线程准备好，延迟 1.5 秒创建菜单
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        createFloatingMenu();
    });
}
