#import <Foundation/Foundation.h>

#define SHIKE_TESTING 1
#import "../Sources/main.m"

static void SKAppAssert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"❌ %@", message);
        exit(1);
    }
}

static CGFloat SKIconAlphaOccupancyAtPath(NSString *path) {
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
    NSBitmapImageRep *largest = nil;
    for (NSImageRep *representation in image.representations) {
        if (![representation isKindOfClass:NSBitmapImageRep.class]) continue;
        NSBitmapImageRep *bitmap = (NSBitmapImageRep *)representation;
        if (!largest || bitmap.pixelsWide > largest.pixelsWide) largest = bitmap;
    }
    if (!largest || !largest.hasAlpha) return 1.0;
    NSInteger width = largest.pixelsWide;
    NSInteger height = largest.pixelsHigh;
    NSInteger step = MAX(1, width / 512);
    NSInteger minX = width, minY = height, maxX = -1, maxY = -1;
    for (NSInteger y = 0; y < height; y += step) {
        for (NSInteger x = 0; x < width; x += step) {
            if ([largest colorAtX:x y:y].alphaComponent <= 0.02) continue;
            minX = MIN(minX, x); minY = MIN(minY, y);
            maxX = MAX(maxX, x); maxY = MAX(maxY, y);
        }
    }
    if (maxX < minX || maxY < minY) return 0;
    CGFloat occupiedWidth = (maxX - minX + step) / (CGFloat)width;
    CGFloat occupiedHeight = (maxY - minY + step) / (CGFloat)height;
    return MAX(occupiedWidth, occupiedHeight);
}

@interface SKTestMainViewController : SKMainViewController
@property(nonatomic) NSInteger presentedLogs;
@property(nonatomic) NSInteger playedSounds;
@property(nonatomic) NSInteger scheduledNotifications;
@property(nonatomic, copy) NSString *lastNotificationTitle;
@property(nonatomic) NSInteger nextFocusPrompts;
@property(nonatomic) BOOL acceptNextFocus;
@end

@implementation SKTestMainViewController
- (void)presentLogForRecord:(SKFocusRecord *)record { self.presentedLogs += 1; }
- (void)playCompletionSound { self.playedSounds += 1; }
- (void)scheduleNotificationAfter:(NSInteger)seconds title:(NSString *)title body:(NSString *)body {
    if (seconds > 0) {
        self.scheduledNotifications += 1;
        self.lastNotificationTitle = title;
    }
}
- (void)cancelPendingTimerNotifications {}
- (void)refreshNotificationAuthorization {}
- (BOOL)confirmNextFocusAfterBreak {
    self.nextFocusPrompts += 1;
    return self.acceptNextFocus;
}
@end

static SKTestMainViewController *SKTestController(void) {
    SKTestMainViewController *controller = [SKTestMainViewController new];
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"shike-app-test-%@/data.json", NSUUID.UUID.UUIDString]]];
    controller.store = [[SKAppStore alloc] initWithStorageURL:url];
    controller.engine = [SKTimerEngine new];
    return controller;
}

static void testStarterCompletionFlow(void) {
    SKTestMainViewController *controller = SKTestController();
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:1000];
    [controller.engine prepareSessionKind:SKSessionKindStarter durationSeconds:300
                                   taskID:nil taskTitle:nil chainID:@"starter-chain"];
    [controller.engine startAtDate:start];
    [controller finishCurrentSessionAborted:NO atDate:[start dateByAddingTimeInterval:300]];
    SKAppAssert(controller.store.records.count == 1, @"五分钟启动完成后必须生成记录");
    SKFocusRecord *record = controller.store.records.firstObject;
    SKAppAssert(!record.countedAsTomato && [record.status isEqualToString:@"completed"],
                @"五分钟启动应完成但不计为标准番茄");
    SKAppAssert(controller.presentedLogs == 1 && controller.playedSounds == 1,
                @"五分钟启动完成后必须提醒并弹出日志");
    SKAppAssert([controller.engine.phase isEqualToString:SKTimerPhaseRunning] &&
                [controller.engine.sessionKind isEqualToString:SKSessionKindShortBreak] &&
                controller.engine.plannedSeconds == 60 && controller.restStartedAt != nil,
                @"五分钟日志处理后必须自动开始一分钟休息");
    SKAppAssert(controller.scheduledNotifications == 1 &&
                [controller.lastNotificationTitle isEqualToString:@"休息结束了"],
                @"一分钟休息必须显示倒计时并安排结束通知");
}

static void testStandardCompletionAndBreakCadence(void) {
    SKTestMainViewController *controller = SKTestController();
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:2000];
    [controller.engine prepareSessionKind:SKSessionKindStandard durationSeconds:1500
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:start];
    [controller finishCurrentSessionAborted:NO atDate:[start dateByAddingTimeInterval:1500]];
    SKAppAssert(controller.store.records.firstObject.countedAsTomato, @"标准番茄完成后必须计数");
    SKAppAssert([controller.engine.sessionKind isEqualToString:SKSessionKindShortBreak] &&
                [controller.engine.phase isEqualToString:SKTimerPhaseRunning] &&
                controller.engine.plannedSeconds == 300,
                @"25分钟标准番茄填写日志后必须自动开始5分钟短休息");
    SKAppAssert(controller.presentedLogs == 1, @"标准番茄完成后必须弹出日志");

    controller = SKTestController();
    for (NSInteger index = 0; index < 8; index++) {
        NSDate *roundStart = [start dateByAddingTimeInterval:index * 3600];
        [controller.engine prepareSessionKind:SKSessionKindStandard durationSeconds:1500
                                       taskID:nil taskTitle:nil chainID:nil];
        [controller.engine startAtDate:roundStart];
        [controller finishCurrentSessionAborted:NO
                                         atDate:[roundStart dateByAddingTimeInterval:1500]];
        SKAppAssert([controller.engine.sessionKind isEqualToString:SKSessionKindShortBreak] &&
                    [controller.engine.phase isEqualToString:SKTimerPhaseRunning] &&
                    controller.engine.plannedSeconds == 300,
                    @"无论累计完成多少轮，标准番茄都只能进入可预测的5分钟比例休息");
    }
    SKAppAssert(controller.store.records.count == 8 && controller.presentedLogs == 8,
                @"移除长休息后不能影响连续番茄的记录和日志流程");
}

static void testCustomAndAbortFlows(void) {
    SKTestMainViewController *controller = SKTestController();
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:3000];
    [controller.engine prepareSessionKind:SKSessionKindCustom durationSeconds:1200
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:start];
    [controller finishCurrentSessionAborted:NO atDate:[start dateByAddingTimeInterval:1200]];
    SKAppAssert(controller.store.records.firstObject.countedAsTomato && controller.presentedLogs == 1,
                @"临时番茄完成后必须计数并弹出日志");
    SKAppAssert([controller.engine.sessionKind isEqualToString:SKSessionKindShortBreak] &&
                [controller.engine.phase isEqualToString:SKTimerPhaseRunning] &&
                controller.engine.plannedSeconds == 240,
                @"20分钟临时番茄填写日志后必须自动开始4分钟休息");
    SKAppAssert(controller.store.lastMeaningfulFocusAt != nil,
                @"自然完成的临时番茄必须保证重启后仍恢复默认时长");
    NSDate *breakEnd = [controller.engine.sessionStartedAt
        dateByAddingTimeInterval:controller.engine.plannedSeconds];
    [controller finishCurrentSessionAborted:NO atDate:breakEnd];
    SKAppAssert([controller.engine.sessionKind isEqualToString:SKSessionKindStandard] &&
                [controller.engine.phase isEqualToString:SKTimerPhaseReady] &&
                controller.engine.plannedSeconds == controller.store.defaultWorkMinutes * 60,
                @"临时番茄休息结束且用户选择稍后后必须恢复默认时长");

    controller = SKTestController();
    [controller.engine prepareSessionKind:SKSessionKindStandard durationSeconds:1500
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:start];
    [controller finishCurrentSessionAborted:YES atDate:[start dateByAddingTimeInterval:10]];
    SKFocusRecord *aborted = controller.store.records.firstObject;
    SKAppAssert([aborted.status isEqualToString:@"aborted"] && aborted.actualSeconds == 10,
                @"提前结束必须保存真实专注时间");
    SKAppAssert(controller.playedSounds == 0 && controller.presentedLogs == 0,
                @"提前结束不能播放完成音或弹出完成日志");
}

static void testBreakSkipAndNotificationKinds(void) {
    SKTestMainViewController *controller = SKTestController();
    [controller.engine prepareSessionKind:SKSessionKindShortBreak durationSeconds:300
                                   taskID:nil taskTitle:nil chainID:nil];
    SKAppAssert([[controller timerNotificationIdentifier] isEqualToString:@"active-break-timer"],
                @"休息必须使用独立通知标识");
    [controller finishCurrentSessionAborted:YES atDate:NSDate.date];
    SKAppAssert(controller.store.records.count == 0 && controller.playedSounds == 0,
                @"跳过尚未开始的休息不能生成记录或播放完成音");
    SKAppAssert([controller.engine.sessionKind isEqualToString:SKSessionKindStandard],
                @"跳过休息后应回到标准番茄");

    [controller.engine prepareTransitionWithDurationSeconds:30 taskID:nil taskTitle:nil chainID:nil atDate:NSDate.date];
    SKAppAssert([[controller timerNotificationIdentifier] isEqualToString:@"active-transition-timer"],
                @"过渡必须使用独立通知标识");
    [controller.engine prepareSessionKind:SKSessionKindStandard durationSeconds:1500
                                   taskID:nil taskTitle:nil chainID:nil];
    SKAppAssert([[controller timerNotificationIdentifier] isEqualToString:@"active-focus-timer"],
                @"专注必须使用独立通知标识");
}

static void testAutomaticTransitionAndBreakResume(void) {
    SKTestMainViewController *controller = SKTestController();
    NSDate *transitionStart = [NSDate dateWithTimeIntervalSinceNow:-31];
    [controller.engine prepareTransitionWithDurationSeconds:30 taskID:nil taskTitle:nil
                                                    chainID:@"chain" atDate:transitionStart];
    [controller timerTick:nil];
    SKAppAssert([controller.engine.phase isEqualToString:SKTimerPhaseRunning] &&
                [controller.engine.sessionKind isEqualToString:SKSessionKindStandard],
                @"旧版30秒过渡快照结束后仍须兼容并启动默认番茄");
    SKAppAssert(controller.playedSounds == 1 && controller.scheduledNotifications == 1,
                @"过渡完成必须提醒并安排下一轮通知");

    controller = SKTestController();
    NSDate *start = NSDate.date;
    [controller.engine prepareSessionKind:SKSessionKindShortBreak durationSeconds:300
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:start];
    [controller.engine pauseAtDate:[start dateByAddingTimeInterval:10]];
    [controller primaryTimerAction:nil];
    SKAppAssert([controller.lastNotificationTitle isEqualToString:@"休息结束了"],
                @"暂停休息后继续不能使用专注完成文案");
}

static void testBreakCompletionRequiresConfirmation(void) {
    NSDate *start = [NSDate dateWithTimeIntervalSince1970:5000];
    SKTestMainViewController *controller = SKTestController();
    controller.store.endlessMode = YES;
    [controller.engine prepareSessionKind:SKSessionKindShortBreak durationSeconds:300
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:start];
    [controller finishCurrentSessionAborted:NO atDate:[start dateByAddingTimeInterval:300]];
    SKAppAssert(controller.nextFocusPrompts == 1,
                @"休息自然结束后必须主动询问是否开始下一轮");
    SKAppAssert([controller.engine.phase isEqualToString:SKTimerPhaseReady] &&
                [controller.engine.sessionKind isEqualToString:SKSessionKindStandard],
                @"用户选择稍后再说后必须停在默认番茄，不能偷偷开始计时");
    SKAppAssert(controller.store.records.count == 0,
                @"休息及额外停留时间不能生成专注记录");

    controller = SKTestController();
    controller.acceptNextFocus = YES;
    [controller.engine prepareSessionKind:SKSessionKindLongBreak durationSeconds:900
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:start];
    [controller finishCurrentSessionAborted:NO atDate:[start dateByAddingTimeInterval:900]];
    SKAppAssert(controller.nextFocusPrompts == 1 &&
                [controller.engine.phase isEqualToString:SKTimerPhaseRunning] &&
                [controller.engine.sessionKind isEqualToString:SKSessionKindStandard],
                @"只有用户明确确认后才能启动下一轮标准番茄");
    SKAppAssert(controller.scheduledNotifications == 1,
                @"确认开始下一轮后必须重新安排完成通知");
}

static void testBreakPromptStaysProminentAcrossApps(void) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 320, 180)
                                                   styleMask:NSWindowStyleMaskBorderless
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    SKConfigureProminentPromptWindow(window);
    NSWindowCollectionBehavior behavior = window.collectionBehavior;
    SKAppAssert(window.level == NSStatusWindowLevel && !window.hidesOnDeactivate,
                @"休息结束提示必须位于普通App窗口之上，且拾刻失去焦点时不能隐藏");
    SKAppAssert((behavior & NSWindowCollectionBehaviorCanJoinAllSpaces) != 0 &&
                (behavior & NSWindowCollectionBehaviorFullScreenAuxiliary) != 0,
                @"休息结束提示必须能跨桌面空间并显示在全屏App上方");
    SKAppAssert(SKTimerPhaseNeedsResponsiveActivity(SKTimerPhaseRunning) &&
                SKTimerPhaseNeedsResponsiveActivity(SKTimerPhaseTransition) &&
                !SKTimerPhaseNeedsResponsiveActivity(SKTimerPhasePaused) &&
                !SKTimerPhaseNeedsResponsiveActivity(SKTimerPhaseReady),
                @"运行中的专注和休息必须阻止App Nap延迟到点弹窗，暂停与待机则无需保持活跃");
}

static void testCalendarUsesReadableScrollableTimeline(void) {
    SKCalendarWindowController *controller =
        [[SKCalendarWindowController alloc] initWithRecords:@[]];
    SKAppAssert(SKCalendarConvertedDurationText(59 * 60) == nil &&
                [SKCalendarConvertedDurationText(60 * 60) isEqualToString:@"折合 1 小时"] &&
                [SKCalendarConvertedDurationText(61 * 60) isEqualToString:@"折合 1 小时 1 分钟"] &&
                [SKCalendarConvertedDurationText(175 * 60) isEqualToString:@"折合 2 小时 55 分钟"],
                @"日历累计时长必须在保留总分钟数的同时正确换算小时与分钟，并处理整小时边界");
    SKAppAssert(SKCalendarHourHeight() >= 72 && SKCalendarTimelineHeight() >= 1200,
                @"日历每小时高度必须足够宽松，使25分钟番茄具有清晰的视觉存在感");
    SKAppAssert(SKCalendarHeaderHeight() >= 72 && SKCalendarAllDayHeight() >= 34 &&
                SKCalendarGridTop() >= 106,
                @"日历必须保留独立的星期日期表头、周数和全天区域");
    SKAppAssert(SKCalendarMajorGridAlpha() >= 0.10 && SKCalendarMajorGridAlpha() <= 0.14 &&
                SKCalendarMinorGridAlpha() < SKCalendarMajorGridAlpha() &&
                SKCalendarColumnGuideAlpha() >= 0.08 && SKCalendarColumnGuideAlpha() <= 0.12 &&
                SKCalendarHalfHourGuideLength() == 0,
                @"日历必须使用参考图式清晰但低对比的小时与日期分隔，并隐藏多余半小时线");
    SKAppAssert(SKCalendarMinimumBlockHeight() >= 15 &&
                SKCalendarDayContentInset() <= 4 &&
                SKCalendarCardFillAlpha(NO) >= 0.095 && SKCalendarCardFillAlpha(NO) <= 0.105 &&
                SKCalendarCardFillAlpha(YES) < SKCalendarCardFillAlpha(NO),
                @"专注卡片必须接近参考图的宽版浅青时间块，文字清晰且五分钟启动卡片更轻");
    SKAppAssert([SKCalendarSurfaceColor() isEqual:NSColor.whiteColor],
                @"日历主时间轴必须使用参考图式纯白底色，不能继承系统窗口灰色");
    SKAppAssert(controller.miniCalendarView != nil &&
                SKCalendarSidebarWidth() >= 220 && SKCalendarSidebarWidth() <= 250,
                @"日历窗口左侧必须保留固定宽度的迷你月历侧边栏");
    NSDateComponents *selectedParts = [NSDateComponents new];
    selectedParts.year = 2026;
    selectedParts.month = 7;
    selectedParts.day = 27;
    NSDate *selectedDate = [NSCalendar.currentCalendar dateFromComponents:selectedParts];
    controller.miniCalendarView.dateSelectionHandler(selectedDate);
    SKAppAssert([NSCalendar.currentCalendar isDate:controller.calendarView.referenceDate
                                  inSameDayAsDate:selectedDate],
                @"点击左侧迷你月历中的日期必须立即驱动右侧日/周/月视图跳转");
    SKAppAssert(controller.calendarScrollView.hasVerticalScroller &&
                controller.calendarScrollView.documentView == controller.calendarView,
                @"日历日/周时间轴必须放在可上下滚动的视图中");
    SKAppAssert(NSHeight(controller.calendarView.frame) >= SKCalendarTimelineHeight(),
                @"可滚动日历必须保留完整的07:00至24:00纵向时间轴，而不能压缩到一屏");

    NSArray<NSDictionary *> *overlapping = SKCalendarLayoutSegments(@[
        @{@"id": @"a", @"start": @15.00, @"end": @15.25},
        @{@"id": @"b", @"start": @15.08, @"end": @15.33},
        @{@"id": @"c", @"start": @15.40, @"end": @15.65}
    ]);
    SKAppAssert([overlapping[0][@"laneCount"] integerValue] == 2 &&
                [overlapping[1][@"laneCount"] integerValue] == 2 &&
                [overlapping[0][@"lane"] integerValue] != [overlapping[1][@"lane"] integerValue],
                @"同一时间段的日历记录必须自动分到不同横向通道，不能互相覆盖");
    SKAppAssert([overlapping[2][@"laneCount"] integerValue] == 1,
                @"与前一组不再相交的记录必须恢复完整列宽");

    NSArray<NSDictionary *> *dense = SKCalendarLayoutSegments(@[
        @{@"start": @16.00, @"end": @16.25},
        @{@"start": @16.02, @"end": @16.27},
        @{@"start": @16.04, @"end": @16.29},
        @{@"start": @16.06, @"end": @16.31}
    ]);
    NSMutableSet<NSNumber *> *lanes = [NSMutableSet set];
    for (NSDictionary *segment in dense) [lanes addObject:segment[@"lane"]];
    SKAppAssert(lanes.count == 4 && [dense.firstObject[@"laneCount"] integerValue] == 4,
                @"密集番茄记录也必须获得唯一通道，避免截图中的多层文字叠加");
    CGFloat denseUsableWidth = 90;
    NSInteger denseLaneCount = 12;
    CGFloat denseGap = SKCalendarLaneGap(denseUsableWidth, denseLaneCount);
    CGFloat denseLaneWidth = SKCalendarLaneWidth(denseUsableWidth, denseLaneCount);
    SKAppAssert(denseLaneWidth * denseLaneCount + denseGap * (denseLaneCount - 1) <=
                    denseUsableWidth + 0.001,
                @"极密集记录必须始终收在当天列内，不能覆盖相邻日期或重新叠加");

    SKFocusRecord *record = [SKFocusRecord new];
    record.startedAt = [NSDate dateWithTimeIntervalSince1970:1000];
    record.endedAt = [record.startedAt dateByAddingTimeInterval:1500];
    record.actualSeconds = 1500;
    record.taskTitleSnapshot = @"整理需求";
    record.logSummary = @"完成日历交互方案";
    record.logDetail = @"明确周视图、日志卡片和点击编辑流程";
    SKAppAssert([[SKCalendarRecordTitle(record) lowercaseString]
                    isEqualToString:[record.logSummary lowercaseString]] &&
                [SKCalendarRecordDetail(record) isEqualToString:record.logDetail],
                @"日历卡片必须优先直接展示本次工作摘要和具体日志");
    SKAppAssert([SKCalendarRecordTimeText(record) containsString:@"25分钟"],
                @"日历卡片必须显示本次专注的实际起止时间和时长");

    record.logSummary = nil;
    record.logDetail = nil;
    SKAppAssert([SKCalendarRecordTitle(record) isEqualToString:@"整理需求"] &&
                [SKCalendarRecordDetail(record) isEqualToString:@"尚未填写详细日志"],
                @"缺少日志时日历仍须显示关联任务，并明确提示可以补写日志");
}

static void testMondayBasedWeekBoundary(void) {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    NSDateComponents *sunday = [NSDateComponents new];
    sunday.year = 2026;
    sunday.month = 8;
    sunday.day = 9;
    sunday.hour = 12;
    NSDate *weekStart = SKMondayStartOfWeek(calendar, [calendar dateFromComponents:sunday]);
    NSDateComponents *parts = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                           fromDate:weekStart];
    SKAppAssert(parts.year == 2026 && parts.month == 8 && parts.day == 3,
                @"周日必须仍属于此前周一开始的当前周，而不能跳到下一周");
}

static void testStatusPopoverOutsideClickClassification(void) {
    NSWindow *popoverWindow = (NSWindow *)[NSObject new];
    NSWindow *statusWindow = (NSWindow *)[NSObject new];
    NSWindow *mainWindow = (NSWindow *)[NSObject new];
    SKAppAssert(!SKStatusPopoverShouldDismiss(popoverWindow, popoverWindow, statusWindow),
                @"点击状态栏面板内部不能收起面板");
    SKAppAssert(!SKStatusPopoverShouldDismiss(statusWindow, popoverWindow, statusWindow),
                @"再次点击状态栏按钮应交给按钮自身切换面板");
    SKAppAssert(SKStatusPopoverShouldDismiss(mainWindow, popoverWindow, statusWindow) &&
                SKStatusPopoverShouldDismiss(nil, popoverWindow, statusWindow),
                @"点击主窗口、桌面或其他应用必须收起状态栏面板");
}

static void testBreakRatioAndMenuBarTypography(void) {
    SKAppAssert(SKShortBreakMinutesForFocusSeconds(5 * 60) == 1 &&
                SKShortBreakMinutesForFocusSeconds(20 * 60) == 4 &&
                SKShortBreakMinutesForFocusSeconds(25 * 60) == 5,
                @"普通休息必须始终按专注时长的1/5计算");
    SKAppAssert(SKShortBreakMinutesForFocusSeconds(30) == 1,
                @"极短番茄的休息时间也不能低于1分钟");
    NSFont *font = SKMenuBarCountdownFont();
    SKAppAssert(font.pointSize >= 14,
                @"状态栏倒计时字体不能小于14pt，以保证菜单栏可读性");
    NSImage *icon = SKMenuBarTimerImage();
    SKAppAssert(icon != nil && icon.isTemplate,
                @"状态栏计时图标必须使用可适配菜单栏颜色的SF Symbol模板");
    SKAppAssert(fabs(icon.size.height - font.pointSize) <= 3,
                @"状态栏计时图标与倒计时文字必须保持接近的视觉尺寸");
    NSString *appIconPath = [NSFileManager.defaultManager.currentDirectoryPath
        stringByAppendingPathComponent:@"Resources/Shike.icns"];
    CGFloat occupancy = SKIconAlphaOccupancyAtPath(appIconPath);
    SKAppAssert(occupancy >= 0.78 && occupancy <= 0.89,
                @"Dock 图标必须保留足够的透明安全边距，视觉体量不能再次大于相邻应用");
}

static void testZenFocusAndProgressiveLog(void) {
    SKAppAssert(!SKFocusUsesQuietPresentation(SKTimerPhaseReady, YES) &&
                SKFocusUsesQuietPresentation(SKTimerPhaseRunning, YES) &&
                SKFocusUsesQuietPresentation(SKTimerPhasePaused, YES) &&
                SKFocusUsesQuietPresentation(SKTimerPhaseReady, NO),
                @"只有尚未开始的工作番茄可以显示本轮设置，专注或休息时必须进入静默呈现");
    SKAppAssert([SKRestHeadline(0) isEqualToString:@"这一刻已经留下"] &&
                [SKRestHeadline(3) isEqualToString:@"先离开屏幕"],
                @"完成日志后的休息必须先确认成果，再温和提示用户离开屏幕");

    SKFocusRecord *record = [SKFocusRecord new];
    record.status = @"completed";
    record.startedAt = [NSDate dateWithTimeIntervalSince1970:1000];
    record.endedAt = [record.startedAt dateByAddingTimeInterval:300];
    record.plannedSeconds = 300;
    record.actualSeconds = 300;
    SKAppAssert(!SKLogDetailsInitiallyExpanded(record, YES) &&
                SKLogDetailsInitiallyExpanded(record, NO),
                @"新完成日志默认只呈现一个主问题，编辑历史日志时则必须保留完整信息");
    SKLogWindowController *logController =
        [[SKLogWindowController alloc] initWithRecord:record completionPrompt:YES];
    CGFloat collapsedHeight = NSHeight(logController.window.contentView.bounds);
    SKAppAssert(!logController.detailsExpanded && logController.optionalDetailsContainer.hidden,
                @"完成弹窗的详细记录区必须默认收起，避免一上来呈现完整表单");
    [logController toggleDetails:nil];
    SKAppAssert(logController.detailsExpanded && !logController.optionalDetailsContainer.hidden &&
                NSHeight(logController.window.contentView.bounds) > collapsedHeight,
                @"用户点击添加详细记录后，详情区和窗口高度必须同步展开");

    record.logDetail = @"明确下一步";
    SKAppAssert(SKLogDetailsInitiallyExpanded(record, YES),
                @"已有详细内容的日志再次打开时不能把内容隐藏起来");
    SKLogWindowController *existingLog =
        [[SKLogWindowController alloc] initWithRecord:record completionPrompt:YES];
    SKAppAssert(existingLog.detailsExpanded && !existingLog.optionalDetailsContainer.hidden,
                @"带详情的完成日志必须以展开状态打开");

    SKTestMainViewController *controller = SKTestController();
    [controller loadView];
    [controller.engine prepareSessionKind:SKSessionKindStandard durationSeconds:1500
                                   taskID:@"task" taskTitle:@"写出第一段" chainID:nil];
    [controller refreshFocus];
    SKAppAssert(!controller.focusSettingsCard.hidden && !controller.todayLabel.hidden,
                @"番茄开始前必须保留时长和任务设置以及今日反馈");
    [controller.engine startAtDate:NSDate.date];
    [controller refreshFocus];
    SKAppAssert(controller.focusSettingsCard.hidden && controller.todayLabel.hidden &&
                !controller.pauseButton.hidden && !controller.endButton.hidden &&
                [controller.phaseLabel.stringValue isEqualToString:@"写出第一段"],
                @"专注开始后必须收起设置和统计，只保留任务、倒计时及必要控制");

    NSDate *restStart = NSDate.date;
    [controller.engine prepareSessionKind:SKSessionKindShortBreak durationSeconds:60
                                   taskID:nil taskTitle:nil chainID:nil];
    [controller.engine startAtDate:restStart];
    controller.restStartedAt = restStart;
    [controller refreshFocus];
    SKAppAssert(controller.focusSettingsCard.hidden &&
                [controller.phaseLabel.stringValue isEqualToString:@"这一刻已经留下"],
                @"休息开始时必须隐藏设置并短暂确认刚完成的这一刻");
    controller.restStartedAt = [NSDate dateWithTimeIntervalSinceNow:-3];
    [controller refreshFocus];
    SKAppAssert([controller.phaseLabel.stringValue isEqualToString:@"先离开屏幕"],
                @"休息仪式结束后必须切换为克制的离屏提示");
}

static void testCompactLogAndCenteredStatusAction(void) {
    SKFocusRecord *record = [SKFocusRecord new];
    record.status = @"completed";
    record.startedAt = [NSDate dateWithTimeIntervalSince1970:1000];
    record.endedAt = [record.startedAt dateByAddingTimeInterval:1500];
    record.plannedSeconds = 1500;
    record.actualSeconds = 1500;
    SKLogWindowController *logController =
        [[SKLogWindowController alloc] initWithRecord:record completionPrompt:YES];
    [logController.window.contentView layoutSubtreeIfNeeded];
    CGFloat windowWidth = NSWidth(logController.window.contentView.bounds);
    CGFloat fieldWidth = NSWidth(logController.summaryField.frame);
    SKAppAssert(fabs(windowWidth - SKLogWindowWidth()) < 1 &&
                fabs(fieldWidth - SKLogContentWidth()) < 1 &&
                fabs(NSMidX(logController.summaryField.frame) - windowWidth / 2.0) < 1,
                @"日志窗口必须采用紧凑宽度，主输入框不能横向铺满且必须保持居中");

    SKTestMainViewController *main = SKTestController();
    [main loadView];
    [main.engine prepareSessionKind:SKSessionKindStandard durationSeconds:1500
                              taskID:nil taskTitle:nil chainID:nil];
    SKStatusPopoverViewController *status =
        [[SKStatusPopoverViewController alloc] initWithMainViewController:main];
    [status loadView];
    [status.view layoutSubtreeIfNeeded];
    NSRect readyButtonFrame = [status.view convertRect:status.primaryButton.bounds
                                             fromView:status.primaryButton];
    NSRect presetFrame = [status.view convertRect:status.presets.bounds fromView:status.presets];
    SKAppAssert(status.endButton.hidden &&
                fabs(status.primaryButtonWidthConstraint.constant - 260) < 1 &&
                fabs(NSMidX(readyButtonFrame) - NSMidX(presetFrame)) < 1,
                @"状态栏待机时开始专注按钮必须占满操作行，并与时长选择保持同一中轴");

    [main.engine startAtDate:NSDate.date];
    [status refresh];
    [status.view layoutSubtreeIfNeeded];
    SKAppAssert(!status.endButton.hidden &&
                fabs(status.primaryButtonWidthConstraint.constant - 184) < 1 &&
                fabs(status.endButtonWidthConstraint.constant - 68) < 1,
                @"开始计时后操作行必须在保持总宽度不变的前提下为结束按钮让出空间");
}

static void testLightweightTaskRowsStayAligned(void) {
    SKTestMainViewController *controller = SKTestController();
    [controller.store addTaskWithTitle:@"外部租户录制"];
    [controller loadView];
    NSTableColumn *doneColumn = [controller.taskTable tableColumnWithIdentifier:@"done"];
    NSTableColumn *titleColumn = [controller.taskTable tableColumnWithIdentifier:@"taskTitle"];
    NSView *doneCell = [controller tableView:controller.taskTable
                          viewForTableColumn:doneColumn row:0];
    NSView *titleCell = [controller tableView:controller.taskTable
                           viewForTableColumn:titleColumn row:0];
    doneCell.frame = NSMakeRect(0, 0, doneColumn.width, SKTaskRowHeight());
    titleCell.frame = NSMakeRect(0, 0, 360, SKTaskRowHeight());
    [doneCell layoutSubtreeIfNeeded];
    [titleCell layoutSubtreeIfNeeded];
    NSView *checkbox = doneCell.subviews.firstObject;
    NSView *title = titleCell.subviews.firstObject;
    SKAppAssert(fabs(NSMidY(checkbox.frame) - SKTaskRowHeight() / 2.0) < 1 &&
                fabs(NSMidY(title.frame) - SKTaskRowHeight() / 2.0) < 1 &&
                fabs(NSMidY(checkbox.frame) - NSMidY(title.frame)) < 1,
                @"任务复选框与任务名称必须严格共享同一条垂直中线");

    NSTableRowView *rowView = [controller tableView:controller.taskTable rowViewForRow:0];
    NSColor *selectionFill = [SKTaskSelectionFillColor(YES)
        colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
    NSInteger borderedActions = 0;
    for (NSButton *button in controller.taskActions.arrangedSubviews) {
        if ([button isKindOfClass:NSButton.class] && button.bordered) borderedActions++;
    }
    SKAppAssert(controller.taskTable.rowHeight == SKTaskRowHeight() &&
                controller.taskTable.gridStyleMask == NSTableViewGridNone &&
                [rowView isKindOfClass:SKTaskRowView.class] &&
                rowView.interiorBackgroundStyle == NSBackgroundStyleNormal &&
                selectionFill.redComponent >= 0.99 && selectionFill.alphaComponent >= 0.64,
                @"任务列表必须使用宽松的无网格自定义圆角行，不能回退到传统表格样式");
    SKAppAssert(CGColorGetAlpha(controller.taskScroll.layer.borderColor) <=
                    SKTaskSurfaceBorderAlpha() + 0.001 &&
                controller.taskInputField.bezelStyle == NSTextFieldRoundedBezel &&
                borderedActions == 1,
                @"任务页必须使用轻边框、圆角输入框，并只强调开始专注这个主操作");

    NSButton *completionButton = (NSButton *)checkbox;
    completionButton.state = NSControlStateValueOn;
    [controller taskDoneChanged:completionButton];
    SKTask *completedTask = controller.store.activeTasks.firstObject;
    SKAppAssert(completedTask.completedAt != nil && controller.taskTable.selectedRow == -1,
                @"点击完成标记后必须进入明确的完成状态，并与当前任务选中态分离");
    NSView *completedDoneCell = [controller tableView:controller.taskTable
                                   viewForTableColumn:doneColumn row:0];
    NSView *completedTitleCell = [controller tableView:controller.taskTable
                                    viewForTableColumn:titleColumn row:0];
    NSButton *completedButton = completedDoneCell.subviews.firstObject;
    NSTextField *completedTitle = completedTitleCell.subviews.firstObject;
    NSNumber *strike = [completedTitle.attributedStringValue
        attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:nil];
    SKAppAssert(completedButton.image != nil && !completedButton.bordered &&
                strike.integerValue != 0 &&
                [completedTitle.textColor isEqual:NSColor.secondaryLabelColor],
                @"完成状态必须使用圆形完成图标和可读删除线，不能只把整行文字压暗");
}

int main(void) {
    @autoreleasepool {
        testStarterCompletionFlow();
        testStandardCompletionAndBreakCadence();
        testCustomAndAbortFlows();
        testBreakSkipAndNotificationKinds();
        testAutomaticTransitionAndBreakResume();
        testBreakCompletionRequiresConfirmation();
        testBreakPromptStaysProminentAcrossApps();
        testCalendarUsesReadableScrollableTimeline();
        testMondayBasedWeekBoundary();
        testStatusPopoverOutsideClickClassification();
        testBreakRatioAndMenuBarTypography();
        testZenFocusAndProgressiveLog();
        testCompactLogAndCenteredStatusAction();
        testLightweightTaskRowsStayAligned();
        NSLog(@"✅ ShikeAppTests 全部通过");
    }
    return 0;
}
