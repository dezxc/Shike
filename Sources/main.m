#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>
#import <UserNotifications/UserNotifications.h>
#import "ShikeCore.h"

static NSColor *SKAccentColor(void) {
    return [NSColor colorWithSRGBRed:0.91 green:0.29 blue:0.22 alpha:1.0];
}

static NSTextField *SKLabel(NSString *text, CGFloat size, NSFontWeight weight) {
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = NSColor.labelColor;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSButton *SKButton(NSString *title, id target, SEL action) {
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.controlSize = NSControlSizeLarge;
    return button;
}

static NSBox *SKPanelBox(CGFloat cornerRadius) {
    NSBox *box = [NSBox new];
    box.boxType = NSBoxCustom;
    box.titlePosition = NSNoTitle;
    box.cornerRadius = cornerRadius;
    box.borderWidth = 1;
    box.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.7];
    box.fillColor = [NSColor.controlBackgroundColor colorWithAlphaComponent:0.78];
    box.wantsLayer = YES;
    box.layer.shadowColor = NSColor.blackColor.CGColor;
    box.layer.shadowOpacity = 0.07;
    box.layer.shadowRadius = 12;
    box.layer.shadowOffset = NSMakeSize(0, -3);
    return box;
}

static void SKStyleScrollView(NSScrollView *scrollView) {
    scrollView.drawsBackground = YES;
    scrollView.backgroundColor = [NSColor.textBackgroundColor colorWithAlphaComponent:0.48];
    scrollView.borderType = NSNoBorder;
    scrollView.wantsLayer = YES;
    scrollView.layer.cornerRadius = 14;
    scrollView.layer.borderWidth = 1;
    scrollView.layer.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.65].CGColor;
    scrollView.layer.masksToBounds = YES;
}

static NSString *SKClockText(NSInteger seconds) {
    NSInteger safe = MAX(0, seconds);
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(safe / 60), (long)(safe % 60)];
}

static NSString *SKDurationText(NSInteger seconds) {
    if (seconds < 60) return [NSString stringWithFormat:@"%ld秒", (long)seconds];
    NSInteger minutes = (NSInteger)llround((double)seconds / 60.0);
    return [NSString stringWithFormat:@"%ld分钟", (long)minutes];
}

static NSString *SKCalendarConvertedDurationText(NSInteger seconds) {
    NSInteger totalMinutes = MAX(0, (NSInteger)llround((double)seconds / 60.0));
    if (totalMinutes < 60) return nil;
    NSInteger hours = totalMinutes / 60;
    NSInteger minutes = totalMinutes % 60;
    if (minutes == 0) return [NSString stringWithFormat:@"折合 %ld 小时", (long)hours];
    return [NSString stringWithFormat:@"折合 %ld 小时 %ld 分钟",
                                      (long)hours, (long)minutes];
}

static NSInteger SKShortBreakMinutesForFocusSeconds(NSInteger focusSeconds) {
    return MAX(1, (NSInteger)ceil(MAX(1, focusSeconds) / 300.0));
}

static CGFloat SKCalendarHourHeight(void) { return 72.0; }

static CGFloat SKCalendarHeaderHeight(void) { return 72.0; }

static CGFloat SKCalendarAllDayHeight(void) { return 34.0; }

static CGFloat SKCalendarGridTop(void) {
    return SKCalendarHeaderHeight() + SKCalendarAllDayHeight();
}

static CGFloat SKCalendarTimelineHeight(void) {
    return SKCalendarGridTop() + 24.0 + (24 - 7) * SKCalendarHourHeight();
}

static NSColor *SKCalendarAccentColor(void) {
    return [NSColor colorWithSRGBRed:0.26 green:0.65 blue:0.64 alpha:1.0];
}

static NSColor *SKCalendarSurfaceColor(void) {
    return NSColor.whiteColor;
}

static NSColor *SKCalendarSidebarColor(void) {
    return [NSColor colorWithSRGBRed:0.965 green:0.971 blue:0.978 alpha:1.0];
}

static CGFloat SKCalendarSidebarWidth(void) { return 228.0; }
static CGFloat SKCalendarMajorGridAlpha(void) { return 0.12; }
static CGFloat SKCalendarMinorGridAlpha(void) { return 0.055; }
static CGFloat SKCalendarColumnGuideAlpha(void) { return 0.10; }
static CGFloat SKCalendarHalfHourGuideLength(void) { return 0.0; }
static CGFloat SKCalendarMinimumBlockHeight(void) { return 15.0; }
static CGFloat SKCalendarDayContentInset(void) { return 3.0; }

static CGFloat SKCalendarCardFillAlpha(BOOL starter) {
    return starter ? 0.055 : 0.10;
}

static CGFloat SKCalendarLaneGap(CGFloat usableWidth, NSInteger laneCount) {
    if (laneCount <= 1) return 0;
    return MIN(3.0, MAX(1.0, usableWidth / (MAX(2, laneCount) * 6.0)));
}

static CGFloat SKCalendarLaneWidth(CGFloat usableWidth, NSInteger laneCount) {
    laneCount = MAX(1, laneCount);
    CGFloat gap = SKCalendarLaneGap(usableWidth, laneCount);
    return MAX(1.0, (usableWidth - gap * (laneCount - 1)) / laneCount);
}

static NSString *SKCalendarRecordTitle(SKFocusRecord *record) {
    if (record.logSummary.length) return record.logSummary;
    if (record.taskTitleSnapshot.length) return record.taskTitleSnapshot;
    return @"未命名专注";
}

static NSString *SKCalendarRecordDetail(SKFocusRecord *record) {
    if (record.logDetail.length) return record.logDetail;
    if (record.interruptionReason.length) return [@"中断：" stringByAppendingString:record.interruptionReason];
    return @"尚未填写详细日志";
}

static NSString *SKCalendarRecordTimeText(SKFocusRecord *record) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    formatter.dateFormat = @"HH:mm";
    NSDate *end = record.endedAt ?: [record.startedAt dateByAddingTimeInterval:MAX(0, record.actualSeconds)];
    return [NSString stringWithFormat:@"%@ – %@ · %@",
            [formatter stringFromDate:record.startedAt],
            [formatter stringFromDate:end],
            SKDurationText(record.actualSeconds)];
}

static NSArray<NSDictionary *> *SKCalendarLayoutSegmentGroup(NSArray<NSDictionary *> *group) {
    NSMutableArray<NSNumber *> *laneEnds = [NSMutableArray array];
    NSMutableArray<NSMutableDictionary *> *placed = [NSMutableArray array];
    for (NSDictionary *segment in group) {
        double start = [segment[@"start"] doubleValue];
        double end = [segment[@"end"] doubleValue];
        NSInteger lane = 0;
        while (lane < (NSInteger)laneEnds.count && start < laneEnds[(NSUInteger)lane].doubleValue - 0.0001) {
            lane++;
        }
        if (lane == (NSInteger)laneEnds.count) [laneEnds addObject:@(end)];
        else laneEnds[(NSUInteger)lane] = @(end);
        NSMutableDictionary *item = [segment mutableCopy];
        item[@"lane"] = @(lane);
        [placed addObject:item];
    }
    NSNumber *laneCount = @(MAX(1, (NSInteger)laneEnds.count));
    for (NSMutableDictionary *item in placed) item[@"laneCount"] = laneCount;
    return placed;
}

static NSArray<NSDictionary *> *SKCalendarLayoutSegments(NSArray<NSDictionary *> *segments) {
    NSArray<NSDictionary *> *sorted = [segments sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,
                                                                                               NSDictionary *b) {
        double startA = [a[@"start"] doubleValue];
        double startB = [b[@"start"] doubleValue];
        if (startA < startB) return NSOrderedAscending;
        if (startA > startB) return NSOrderedDescending;
        double endA = [a[@"end"] doubleValue];
        double endB = [b[@"end"] doubleValue];
        return endA > endB ? NSOrderedAscending : (endA < endB ? NSOrderedDescending : NSOrderedSame);
    }];
    NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
    NSMutableArray<NSDictionary *> *group = [NSMutableArray array];
    double groupEnd = -CGFLOAT_MAX;
    for (NSDictionary *segment in sorted) {
        double start = [segment[@"start"] doubleValue];
        double end = [segment[@"end"] doubleValue];
        if (group.count && start >= groupEnd - 0.0001) {
            [result addObjectsFromArray:SKCalendarLayoutSegmentGroup(group)];
            [group removeAllObjects];
            groupEnd = -CGFLOAT_MAX;
        }
        [group addObject:segment];
        groupEnd = MAX(groupEnd, end);
    }
    if (group.count) [result addObjectsFromArray:SKCalendarLayoutSegmentGroup(group)];
    return result;
}

static BOOL SKTimerPhaseNeedsResponsiveActivity(NSString *phase) {
    return [phase isEqualToString:SKTimerPhaseRunning] ||
           [phase isEqualToString:SKTimerPhaseTransition];
}

static NSColor *SKZenSurfaceColor(void) {
    return [NSColor colorWithSRGBRed:0.988 green:0.982 blue:0.968 alpha:1.0];
}

static BOOL SKFocusUsesQuietPresentation(NSString *phase, BOOL workSession) {
    return !workSession || ![phase isEqualToString:SKTimerPhaseReady];
}

static BOOL SKLogDetailsInitiallyExpanded(SKFocusRecord *record, BOOL completionPrompt) {
    return !completionPrompt || record.logDetail.length > 0 || record.interruptionReason.length > 0;
}

static NSString *SKRestHeadline(NSTimeInterval secondsSinceStart) {
    return secondsSinceStart >= 0 && secondsSinceStart < 2.5 ?
        @"这一刻已经留下" : @"先离开屏幕";
}

static CGFloat SKLogWindowWidth(void) { return 520; }
static CGFloat SKLogContentWidth(void) { return 420; }
static CGFloat SKStatusPrimaryButtonWidth(BOOL showsEndButton) {
    return showsEndButton ? 184 : 260;
}
static CGFloat SKTaskRowHeight(void) { return 54; }
static CGFloat SKTaskSurfaceBorderAlpha(void) { return 0.18; }
static NSColor *SKTaskSelectionFillColor(BOOL emphasized) {
    return [NSColor.whiteColor colorWithAlphaComponent:emphasized ? 0.82 : 0.64];
}

static NSFont *SKMenuBarCountdownFont(void) {
    return [NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightSemibold];
}

static NSImage *SKMenuBarTimerImage(void) {
    NSImageSymbolConfiguration *configuration =
        [NSImageSymbolConfiguration configurationWithPointSize:14
                                                        weight:NSFontWeightSemibold
                                                         scale:NSImageSymbolScaleMedium];
    NSImage *image = [[NSImage imageWithSystemSymbolName:@"timer"
                                accessibilityDescription:@"拾刻"]
                      imageWithSymbolConfiguration:configuration];
    image.template = YES;
    return image;
}

static void SKConfigureProminentPromptWindow(NSWindow *window) {
    window.level = NSStatusWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                NSWindowCollectionBehaviorFullScreenAuxiliary;
    window.hidesOnDeactivate = NO;
}

static NSDate *SKMondayStartOfWeek(NSCalendar *calendar, NSDate *date) {
    NSDate *dayStart = [calendar startOfDayForDate:date ?: NSDate.date];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:dayStart];
    NSInteger daysSinceMonday = (weekday + 5) % 7;
    return [calendar dateByAddingUnit:NSCalendarUnitDay
                                value:-daysSinceMonday
                               toDate:dayStart
                              options:0] ?: dayStart;
}

static BOOL SKStatusPopoverShouldDismiss(NSWindow *eventWindow,
                                         NSWindow *popoverWindow,
                                         NSWindow *statusWindow) {
    return eventWindow != popoverWindow && eventWindow != statusWindow;
}

@interface SKProgressRingView : NSView
@property(nonatomic) CGFloat progress;
@property(nonatomic, strong) NSColor *progressColor;
@end

@implementation SKProgressRingView

- (instancetype)init {
    self = [super init];
    if (self) {
        _progressColor = SKAccentColor();
        self.wantsLayer = YES;
    }
    return self;
}

- (void)setProgress:(CGFloat)progress {
    _progress = MIN(1.0, MAX(0.0, progress));
    self.needsDisplay = YES;
}

- (void)setProgressColor:(NSColor *)progressColor {
    _progressColor = progressColor ?: SKAccentColor();
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    CGFloat lineWidth = 8.0;
    NSRect ringRect = NSInsetRect(self.bounds, lineWidth + 2, lineWidth + 2);
    NSBezierPath *track = [NSBezierPath bezierPathWithOvalInRect:ringRect];
    track.lineWidth = lineWidth;
    [[NSColor separatorColor] setStroke];
    [track stroke];
    if (self.progress <= 0) return;
    NSPoint center = NSMakePoint(NSMidX(ringRect), NSMidY(ringRect));
    CGFloat radius = MIN(NSWidth(ringRect), NSHeight(ringRect)) / 2.0;
    NSBezierPath *arc = [NSBezierPath bezierPath];
    [arc appendBezierPathWithArcWithCenter:center
                                    radius:radius
                                startAngle:90
                                  endAngle:90 - 360 * self.progress
                                 clockwise:YES];
    arc.lineWidth = lineWidth;
    arc.lineCapStyle = NSLineCapStyleRound;
    [self.progressColor setStroke];
    [arc stroke];
}

@end

@interface SKWeekCalendarView : NSView
@property(nonatomic, copy) NSArray<SKFocusRecord *> *records;
@property(nonatomic, strong) NSDate *referenceDate;
@property(nonatomic) NSInteger viewMode;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *recordHitRegions;
@property(nonatomic, copy) void (^recordSelectionHandler)(NSArray<SKFocusRecord *> *records);
- (void)fitToEnclosingScrollView;
@end

@implementation SKWeekCalendarView

- (BOOL)isFlipped { return YES; }

- (void)setRecords:(NSArray<SKFocusRecord *> *)records {
    _records = [records copy];
    self.needsDisplay = YES;
}

- (void)setReferenceDate:(NSDate *)referenceDate {
    _referenceDate = referenceDate;
    self.needsDisplay = YES;
}

- (void)setViewMode:(NSInteger)viewMode {
    _viewMode = viewMode;
    [self fitToEnclosingScrollView];
    self.needsDisplay = YES;
}

- (void)fitToEnclosingScrollView {
    NSScrollView *scrollView = self.enclosingScrollView;
    if (!scrollView) return;
    NSRect frame = self.frame;
    frame.size.width = MAX(1, NSWidth(scrollView.contentView.bounds));
    frame.size.height = self.viewMode == 2 ? MAX(520, NSHeight(scrollView.contentView.bounds)) :
                                               SKCalendarTimelineHeight();
    self.frame = frame;
}

- (NSDate *)visibleStartDate {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *reference = self.referenceDate ?: NSDate.date;
    if (self.viewMode == 0) return [calendar startOfDayForDate:reference];
    return SKMondayStartOfWeek(calendar, reference);
}

- (void)drawMonthInRect:(NSRect)rect {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *reference = self.referenceDate ?: NSDate.date;
    NSDateComponents *month = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:reference];
    month.day = 1;
    NSDate *first = [calendar dateFromComponents:month];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:first];
    NSInteger mondayOffset = (weekday + 5) % 7;
    NSDate *gridStart = [calendar dateByAddingUnit:NSCalendarUnitDay value:-mondayOffset toDate:first options:0];
    CGFloat header = 32;
    CGFloat cellWidth = NSWidth(rect) / 7.0;
    CGFloat cellHeight = (NSHeight(rect) - header) / 6.0;
    [SKCalendarSurfaceColor() setFill];
    NSRectFill(rect);
    NSArray *weekdays = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    NSDictionary *headerStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium],
                                  NSForegroundColorAttributeName:NSColor.secondaryLabelColor};
    for (NSInteger day = 0; day < 7; day++) {
        NSString *title = weekdays[day];
        NSSize size = [title sizeWithAttributes:headerStyle];
        [title drawAtPoint:NSMakePoint(day * cellWidth + (cellWidth - size.width) / 2, 8)
            withAttributes:headerStyle];
    }
    NSColor *monthGuide = [NSColor.separatorColor colorWithAlphaComponent:SKCalendarMinorGridAlpha()];
    [monthGuide setStroke];
    for (NSInteger row = 0; row <= 6; row++) {
        CGFloat y = header + row * cellHeight;
        NSBezierPath *guide = [NSBezierPath bezierPath];
        [guide moveToPoint:NSMakePoint(10, y)];
        [guide lineToPoint:NSMakePoint(NSWidth(rect) - 10, y)];
        guide.lineWidth = 0.5;
        [guide stroke];
    }
    for (NSInteger index = 0; index < 42; index++) {
        NSInteger column = index % 7;
        NSInteger row = index / 7;
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:index toDate:gridStart options:0];
        NSRect cell = NSMakeRect(column * cellWidth, header + row * cellHeight, cellWidth, cellHeight);
        NSInteger dayNumber = [calendar component:NSCalendarUnitDay fromDate:date];
        BOOL sameMonth = [calendar component:NSCalendarUnitMonth fromDate:date] == month.month;
        NSDictionary *dayStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium],
                                   NSForegroundColorAttributeName:sameMonth ? NSColor.labelColor : NSColor.tertiaryLabelColor};
        if ([calendar isDateInToday:date]) {
            [[SKCalendarAccentColor() colorWithAlphaComponent:0.10] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(NSMinX(cell) + 6, NSMinY(cell) + 4, 28, 24)
                                              xRadius:12 yRadius:12] fill];
        }
        [[NSString stringWithFormat:@"%ld", (long)dayNumber]
            drawAtPoint:NSMakePoint(NSMinX(cell) + 8, NSMinY(cell) + 6) withAttributes:dayStyle];
        NSInteger count = 0;
        NSInteger seconds = 0;
        NSMutableArray<SKFocusRecord *> *dayRecords = [NSMutableArray array];
        for (SKFocusRecord *record in self.records) {
            if (record.deletedAt || ![calendar isDate:record.startedAt inSameDayAsDate:date]) continue;
            [dayRecords addObject:record];
            seconds += MAX(0, record.actualSeconds);
            if (record.countedAsTomato) count++;
        }
        if (count || seconds) {
            NSString *summary = [NSString stringWithFormat:@"%ld 🍅  %@", (long)count, SKDurationText(seconds)];
            NSDictionary *summaryStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:9.5 weight:NSFontWeightMedium],
                                           NSForegroundColorAttributeName:[SKCalendarAccentColor() colorWithAlphaComponent:0.82]};
            [summary drawInRect:NSInsetRect(NSMakeRect(NSMinX(cell), NSMinY(cell) + 25, NSWidth(cell), 20), 8, 0)
                 withAttributes:summaryStyle];
            NSDictionary *logStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightRegular],
                                       NSForegroundColorAttributeName:NSColor.secondaryLabelColor};
            NSInteger visibleLogCount = MIN(2, (NSInteger)dayRecords.count);
            for (NSInteger logIndex = 0; logIndex < visibleLogCount; logIndex++) {
                SKFocusRecord *record = dayRecords[(NSUInteger)logIndex];
                NSString *line = [@"• " stringByAppendingString:SKCalendarRecordTitle(record)];
                [line drawInRect:NSMakeRect(NSMinX(cell) + 8,
                                            NSMinY(cell) + 43 + logIndex * 14,
                                            NSWidth(cell) - 16, 13)
                     withAttributes:logStyle];
            }
            [self.recordHitRegions addObject:@{@"rect": [NSValue valueWithRect:cell],
                                                @"records": dayRecords}];
        }
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    self.recordHitRegions = [NSMutableArray array];
    [SKCalendarSurfaceColor() setFill];
    NSRectFill(self.bounds);

    if (self.viewMode == 2) {
        [self drawMonthInRect:self.bounds];
        return;
    }

    CGFloat left = 64;
    CGFloat header = SKCalendarHeaderHeight();
    CGFloat gridTop = SKCalendarGridTop();
    CGFloat width = MAX(1, NSWidth(self.bounds) - left - 1);
    NSInteger visibleDays = self.viewMode == 0 ? 1 : 7;
    CGFloat columnWidth = width / visibleDays;
    NSInteger startHour = 7;
    NSInteger endHour = 24;
    NSInteger hourCount = endHour - startHour;
    CGFloat hourHeight = SKCalendarHourHeight();
    CGFloat gridHeight = hourCount * hourHeight;
    CGFloat gridBottom = gridTop + gridHeight;

    [SKCalendarSurfaceColor() setFill];
    NSRectFill(NSMakeRect(0, 0, NSWidth(self.bounds), gridTop));
    NSColor *gridColor = [NSColor.separatorColor colorWithAlphaComponent:SKCalendarMajorGridAlpha()];
    NSColor *softGridColor = [NSColor.separatorColor colorWithAlphaComponent:SKCalendarMinorGridAlpha()];

    NSDictionary *small = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: NSColor.tertiaryLabelColor
    };
    NSDictionary *weekdayStyle = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: NSColor.secondaryLabelColor
    };
    NSDictionary *dayNumberStyle = @{
        NSFontAttributeName: [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.labelColor
    };

    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *weekStart = [self visibleStartDate];
    NSDateFormatter *weekdayFormatter = [NSDateFormatter new];
    weekdayFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    weekdayFormatter.dateFormat = @"EEE";

    NSInteger weekNumber = [calendar component:NSCalendarUnitWeekOfYear fromDate:weekStart];
    NSDictionary *gutterStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:9.5 weight:NSFontWeightRegular],
                                  NSForegroundColorAttributeName:NSColor.tertiaryLabelColor};
    [[NSString stringWithFormat:@"W%ld", (long)weekNumber]
        drawAtPoint:NSMakePoint(12, 39) withAttributes:gutterStyle];
    [@"全天" drawAtPoint:NSMakePoint(16, header + 10) withAttributes:gutterStyle];

    for (NSInteger day = 0; day < visibleDays; day++) {
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:day toDate:weekStart options:0];
        NSString *weekday = [weekdayFormatter stringFromDate:date];
        NSString *dayNumber = [NSString stringWithFormat:@"%ld",
                               (long)[calendar component:NSCalendarUnitDay fromDate:date]];
        NSSize weekdaySize = [weekday sizeWithAttributes:weekdayStyle];
        NSSize numberSize = [dayNumber sizeWithAttributes:dayNumberStyle];
        CGFloat centerX = left + day * columnWidth + columnWidth / 2;
        if ([calendar isDateInToday:date]) {
            [[SKCalendarAccentColor() colorWithAlphaComponent:0.022] setFill];
            NSRectFill(NSMakeRect(left + day * columnWidth + 3, gridTop,
                                  MAX(1, columnWidth - 6), gridHeight));
        }
        [weekday drawAtPoint:NSMakePoint(centerX - weekdaySize.width / 2, 11)
              withAttributes:weekdayStyle];
        if ([calendar isDateInToday:date]) {
            NSRect todayPill = NSMakeRect(centerX - 15, 29, 30, 27);
            [[SKCalendarAccentColor() colorWithAlphaComponent:0.10] setFill];
            [[NSBezierPath bezierPathWithRoundedRect:todayPill xRadius:14 yRadius:14] fill];
        }
        [dayNumber drawAtPoint:NSMakePoint(centerX - numberSize.width / 2, 33)
                withAttributes:dayNumberStyle];

        if (SKCalendarColumnGuideAlpha() > 0) {
            [[NSColor.separatorColor colorWithAlphaComponent:SKCalendarColumnGuideAlpha()] setStroke];
            NSBezierPath *vertical = [NSBezierPath bezierPath];
            [vertical moveToPoint:NSMakePoint(left + day * columnWidth, header)];
            [vertical lineToPoint:NSMakePoint(left + day * columnWidth, gridBottom)];
            vertical.lineWidth = 0.5;
            [vertical stroke];
        }
    }

    [gridColor setStroke];
    NSBezierPath *headerDivider = [NSBezierPath bezierPath];
    [headerDivider moveToPoint:NSMakePoint(left, gridTop)];
    [headerDivider lineToPoint:NSMakePoint(left + width - 10, gridTop)];
    headerDivider.lineWidth = 0.5;
    [headerDivider stroke];

    for (NSInteger hour = startHour; hour <= endHour; hour++) {
        CGFloat y = gridTop + (hour - startHour) * hourHeight;
        NSString *label = [NSString stringWithFormat:@"%02ld:00", (long)hour];
        [label drawAtPoint:NSMakePoint(13, y - 7) withAttributes:small];
        NSBezierPath *horizontal = [NSBezierPath bezierPath];
        [horizontal moveToPoint:NSMakePoint(left, y)];
        [horizontal lineToPoint:NSMakePoint(left + width, y)];
        horizontal.lineWidth = 0.5;
        [gridColor setStroke];
        [horizontal stroke];
        if (hour < endHour && SKCalendarHalfHourGuideLength() > 0) {
            NSBezierPath *halfHour = [NSBezierPath bezierPath];
            [halfHour moveToPoint:NSMakePoint(left + 14, y + hourHeight / 2)];
            [halfHour lineToPoint:NSMakePoint(left + 14 + SKCalendarHalfHourGuideLength(),
                                              y + hourHeight / 2)];
            halfHour.lineWidth = 0.5;
            [softGridColor setStroke];
            [halfHour stroke];
        }
    }

    for (NSInteger day = 0; day < visibleDays; day++) {
        NSDate *dayStart = [calendar dateByAddingUnit:NSCalendarUnitDay value:day toDate:weekStart options:0];
        NSDate *dayEnd = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:dayStart options:0];
        NSMutableArray<NSDictionary *> *segments = [NSMutableArray array];
        for (SKFocusRecord *record in self.records) {
            if (record.deletedAt) continue;
            NSDate *visualEnd = record.endedAt ?:
                [record.startedAt dateByAddingTimeInterval:MAX(60, record.actualSeconds)];
            NSDate *segmentStart = [record.startedAt laterDate:dayStart];
            NSDate *segmentEnd = [visualEnd earlierDate:dayEnd];
            if ([segmentEnd compare:segmentStart] != NSOrderedDescending) continue;
            double start = [segmentStart timeIntervalSinceDate:dayStart] / 3600.0;
            double end = [segmentEnd timeIntervalSinceDate:dayStart] / 3600.0;
            double clippedStart = MAX((double)startHour, MIN((double)endHour, start));
            double clippedEnd = MAX((double)startHour, MIN((double)endHour, end));
            if (clippedEnd <= clippedStart) continue;
            double minimumVisualHours = (SKCalendarMinimumBlockHeight() + 4.0) / hourHeight;
            [segments addObject:@{
                @"record": record,
                @"start": @(clippedStart),
                @"end": @(MAX(clippedEnd, clippedStart + minimumVisualHours)),
                @"actualEnd": @(clippedEnd)
            }];
        }

        for (NSDictionary *segment in SKCalendarLayoutSegments(segments)) {
            SKFocusRecord *record = segment[@"record"];
            double clippedStart = [segment[@"start"] doubleValue];
            double clippedEnd = [segment[@"actualEnd"] doubleValue];
            NSInteger lane = [segment[@"lane"] integerValue];
            NSInteger laneCount = MAX(1, [segment[@"laneCount"] integerValue]);
            CGFloat contentInset = SKCalendarDayContentInset();
            CGFloat usableWidth = MAX(18, columnWidth - contentInset * 2);
            CGFloat laneGap = SKCalendarLaneGap(usableWidth, laneCount);
            CGFloat laneWidth = SKCalendarLaneWidth(usableWidth, laneCount);
            CGFloat x = left + day * columnWidth + contentInset + lane * (laneWidth + laneGap);
            CGFloat y = gridTop + (clippedStart - startHour) * hourHeight + 2;
            CGFloat blockHeight = MAX(SKCalendarMinimumBlockHeight(),
                                      (clippedEnd - clippedStart) * hourHeight - 4);
            blockHeight = MIN(blockHeight, gridBottom - y - 1);
            NSRect block = NSMakeRect(x, y, laneWidth, blockHeight);

            BOOL aborted = [record.status isEqualToString:@"aborted"];
            NSColor *accent = aborted ?
                [NSColor colorWithSRGBRed:0.46 green:0.56 blue:0.57 alpha:1.0] :
                SKCalendarAccentColor();
            CGFloat fillAlpha = SKCalendarCardFillAlpha([record.kind isEqualToString:SKSessionKindStarter]);
            NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:block xRadius:4 yRadius:4];
            [[accent colorWithAlphaComponent:fillAlpha] setFill];
            [cardPath fill];
            [[accent colorWithAlphaComponent:0.48] setFill];
            NSRectFill(NSMakeRect(NSMinX(block), NSMinY(block) + 3, 2,
                                  MAX(1, NSHeight(block) - 4)));
            [self.recordHitRegions addObject:@{@"rect": [NSValue valueWithRect:block],
                                                @"records": @[record]}];

            [NSGraphicsContext saveGraphicsState];
            [cardPath addClip];
            NSMutableParagraphStyle *singleLine = [NSMutableParagraphStyle new];
            singleLine.lineBreakMode = NSLineBreakByTruncatingTail;
            NSDictionary *titleStyle = @{
                NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName:[accent colorWithAlphaComponent:0.95],
                NSParagraphStyleAttributeName:singleLine
            };
            NSRect textBounds = NSMakeRect(NSMinX(block) + 7, NSMinY(block) + 2,
                                           MAX(1, NSWidth(block) - 11), 14);
            [SKCalendarRecordTitle(record) drawInRect:textBounds withAttributes:titleStyle];

            if (blockHeight >= 27 && laneCount <= 3) {
                NSDictionary *timeStyle = @{
                    NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightRegular],
                    NSForegroundColorAttributeName:[accent colorWithAlphaComponent:0.78],
                    NSParagraphStyleAttributeName:singleLine
                };
                [SKCalendarRecordTimeText(record)
                    drawInRect:NSMakeRect(NSMinX(textBounds), NSMinY(block) + 14,
                                          NSWidth(textBounds), 12)
                    withAttributes:timeStyle];
            }
            if (blockHeight >= 44 && laneCount <= 2) {
                NSDictionary *detailStyle = @{
                    NSFontAttributeName:[NSFont systemFontOfSize:9.5 weight:NSFontWeightRegular],
                    NSForegroundColorAttributeName:[accent colorWithAlphaComponent:0.72],
                    NSParagraphStyleAttributeName:singleLine
                };
                [SKCalendarRecordDetail(record)
                    drawInRect:NSMakeRect(NSMinX(textBounds), NSMinY(block) + 27,
                                          NSWidth(textBounds), MAX(10, blockHeight - 30))
                    withAttributes:detailStyle];
            }
            [NSGraphicsContext restoreGraphicsState];
        }
    }

    NSDate *now = NSDate.date;
    for (NSInteger day = 0; day < visibleDays; day++) {
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:day toDate:weekStart options:0];
        if (![calendar isDateInToday:date]) continue;
        NSDateComponents *time = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:now];
        double currentHour = time.hour + time.minute / 60.0;
        if (currentHour < startHour || currentHour > endHour) break;
        CGFloat y = gridTop + (currentHour - startHour) * hourHeight;
        CGFloat startX = left + day * columnWidth;
        [SKAccentColor() setStroke];
        NSBezierPath *nowLine = [NSBezierPath bezierPath];
        [nowLine moveToPoint:NSMakePoint(startX, y)];
        [nowLine lineToPoint:NSMakePoint(startX + columnWidth, y)];
        nowLine.lineWidth = 1.5;
        [nowLine stroke];
        [SKAccentColor() setFill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(startX - 3, y - 3, 6, 6)] fill];
        break;
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    for (NSDictionary *region in self.recordHitRegions.reverseObjectEnumerator) {
        if (NSPointInRect(point, [region[@"rect"] rectValue])) {
            NSArray<SKFocusRecord *> *records = region[@"records"];
            if (records.count && self.recordSelectionHandler) self.recordSelectionHandler(records);
            return;
        }
    }
    [super mouseDown:event];
}

@end

@interface SKMiniCalendarView : NSView
@property(nonatomic, strong) NSDate *selectedDate;
@property(nonatomic, strong) NSDate *displayMonth;
@property(nonatomic, copy) NSArray<SKFocusRecord *> *records;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *hitRegions;
@property(nonatomic, copy) void (^dateSelectionHandler)(NSDate *date);
@end

@implementation SKMiniCalendarView

- (BOOL)isFlipped { return YES; }

- (NSDate *)firstDayOfMonth:(NSDate *)date {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDateComponents *parts = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth
                                          fromDate:date ?: NSDate.date];
    parts.day = 1;
    return [calendar dateFromComponents:parts] ?: NSDate.date;
}

- (void)setSelectedDate:(NSDate *)selectedDate {
    _selectedDate = selectedDate ?: NSDate.date;
    _displayMonth = [self firstDayOfMonth:_selectedDate];
    self.needsDisplay = YES;
}

- (void)setRecords:(NSArray<SKFocusRecord *> *)records {
    _records = [records copy];
    self.needsDisplay = YES;
}

- (NSArray<SKFocusRecord *> *)recordsOnDate:(NSDate *)date {
    NSMutableArray<SKFocusRecord *> *matches = [NSMutableArray array];
    for (SKFocusRecord *record in self.records) {
        if (!record.deletedAt && [NSCalendar.currentCalendar isDate:record.startedAt inSameDayAsDate:date]) {
            [matches addObject:record];
        }
    }
    return matches;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [SKCalendarSidebarColor() setFill];
    NSRectFill(self.bounds);
    self.hitRegions = [NSMutableArray array];

    CGFloat width = NSWidth(self.bounds);
    NSColor *systemBlue = [NSColor colorWithSRGBRed:0.08 green:0.43 blue:0.96 alpha:1.0];
    NSRect selectedTab = NSMakeRect(12, 12, width - 24, 38);
    [NSColor.whiteColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:selectedTab xRadius:7 yRadius:7] fill];
    NSDictionary *tabStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],
                               NSForegroundColorAttributeName:NSColor.labelColor};
    NSString *tabTitle = @"日历";
    NSSize tabSize = [tabTitle sizeWithAttributes:tabStyle];
    [tabTitle drawAtPoint:NSMakePoint(NSMidX(selectedTab) - tabSize.width / 2,
                                      NSMidY(selectedTab) - tabSize.height / 2)
            withAttributes:tabStyle];

    NSDate *monthStart = self.displayMonth ?: [self firstDayOfMonth:self.selectedDate ?: NSDate.date];
    NSDateFormatter *monthFormatter = [NSDateFormatter new];
    monthFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    monthFormatter.dateFormat = @"yyyy年MM月";
    NSDictionary *monthStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold],
                                 NSForegroundColorAttributeName:NSColor.labelColor};
    [[monthFormatter stringFromDate:monthStart] drawAtPoint:NSMakePoint(14, 76)
                                             withAttributes:monthStyle];

    NSDictionary *arrowStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:18 weight:NSFontWeightRegular],
                                 NSForegroundColorAttributeName:NSColor.secondaryLabelColor};
    NSRect previousRect = NSMakeRect(width - 66, 68, 26, 28);
    NSRect nextRect = NSMakeRect(width - 36, 68, 26, 28);
    [@"‹" drawAtPoint:NSMakePoint(NSMidX(previousRect) - 4, NSMinY(previousRect) + 3)
        withAttributes:arrowStyle];
    [@"›" drawAtPoint:NSMakePoint(NSMidX(nextRect) - 4, NSMinY(nextRect) + 3)
        withAttributes:arrowStyle];
    [self.hitRegions addObject:@{@"rect":[NSValue valueWithRect:previousRect], @"action":@"previous"}];
    [self.hitRegions addObject:@{@"rect":[NSValue valueWithRect:nextRect], @"action":@"next"}];

    CGFloat gridX = 10;
    CGFloat gridWidth = width - 20;
    CGFloat cellWidth = gridWidth / 7.0;
    CGFloat weekdayY = 110;
    CGFloat dateStartY = 137;
    CGFloat rowHeight = 31;
    NSArray<NSString *> *weekdays = @[@"一", @"二", @"三", @"四", @"五", @"六", @"日"];
    NSDictionary *weekdayStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium],
                                   NSForegroundColorAttributeName:NSColor.secondaryLabelColor};
    for (NSInteger column = 0; column < 7; column++) {
        NSString *weekday = weekdays[(NSUInteger)column];
        NSSize size = [weekday sizeWithAttributes:weekdayStyle];
        [weekday drawAtPoint:NSMakePoint(gridX + column * cellWidth + (cellWidth - size.width) / 2, weekdayY)
              withAttributes:weekdayStyle];
    }

    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:monthStart];
    NSInteger mondayOffset = (weekday + 5) % 7;
    NSDate *gridStart = [calendar dateByAddingUnit:NSCalendarUnitDay
                                             value:-mondayOffset
                                            toDate:monthStart
                                           options:0];
    NSInteger shownMonth = [calendar component:NSCalendarUnitMonth fromDate:monthStart];
    for (NSInteger index = 0; index < 42; index++) {
        NSInteger column = index % 7;
        NSInteger row = index / 7;
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:index toDate:gridStart options:0];
        CGFloat centerX = gridX + column * cellWidth + cellWidth / 2;
        CGFloat centerY = dateStartY + row * rowHeight + 10;
        NSRect hitRect = NSMakeRect(gridX + column * cellWidth,
                                    dateStartY + row * rowHeight - 4,
                                    cellWidth, rowHeight);
        BOOL selected = [calendar isDate:date inSameDayAsDate:self.selectedDate ?: NSDate.date];
        BOOL today = [calendar isDateInToday:date];
        BOOL inMonth = [calendar component:NSCalendarUnitMonth fromDate:date] == shownMonth;
        if (selected) {
            [systemBlue setFill];
            [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(centerX - 12, centerY - 12, 24, 24)] fill];
        } else if (today) {
            [systemBlue setStroke];
            NSBezierPath *todayRing = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(centerX - 11.5,
                                                                                        centerY - 11.5,
                                                                                        23, 23)];
            todayRing.lineWidth = 1;
            [todayRing stroke];
        }
        NSDictionary *dateStyle = @{
            NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:10.5 weight:selected ? NSFontWeightSemibold : NSFontWeightRegular],
            NSForegroundColorAttributeName:selected ? NSColor.whiteColor :
                (inMonth ? NSColor.labelColor : NSColor.tertiaryLabelColor)
        };
        NSString *dayText = [NSString stringWithFormat:@"%ld", (long)[calendar component:NSCalendarUnitDay fromDate:date]];
        NSSize daySize = [dayText sizeWithAttributes:dateStyle];
        [dayText drawAtPoint:NSMakePoint(centerX - daySize.width / 2, centerY - daySize.height / 2)
              withAttributes:dateStyle];

        NSArray<SKFocusRecord *> *dayRecords = [self recordsOnDate:date];
        NSInteger dotCount = MIN(3, (NSInteger)dayRecords.count);
        if (dotCount > 0 && !selected) {
            [[systemBlue colorWithAlphaComponent:0.38] setFill];
            CGFloat totalWidth = dotCount * 3 + (dotCount - 1) * 2;
            for (NSInteger dot = 0; dot < dotCount; dot++) {
                CGFloat x = centerX - totalWidth / 2 + dot * 5;
                [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, centerY + 13, 3, 3)] fill];
            }
        }
        [self.hitRegions addObject:@{@"rect":[NSValue valueWithRect:hitRect], @"date":date}];
    }

    CGFloat summaryY = dateStartY + rowHeight * 6 + 22;
    [[NSColor.separatorColor colorWithAlphaComponent:0.16] setStroke];
    NSBezierPath *divider = [NSBezierPath bezierPath];
    [divider moveToPoint:NSMakePoint(14, summaryY)];
    [divider lineToPoint:NSMakePoint(width - 14, summaryY)];
    divider.lineWidth = 0.5;
    [divider stroke];

    NSDate *selectedDate = self.selectedDate ?: NSDate.date;
    NSDateFormatter *selectedFormatter = [NSDateFormatter new];
    selectedFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    selectedFormatter.dateFormat = @"M月d日 EEEE";
    NSDictionary *selectedStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:12 weight:NSFontWeightSemibold],
                                    NSForegroundColorAttributeName:NSColor.labelColor};
    [[selectedFormatter stringFromDate:selectedDate] drawAtPoint:NSMakePoint(14, summaryY + 18)
                                                   withAttributes:selectedStyle];
    NSArray<SKFocusRecord *> *selectedRecords = [self recordsOnDate:selectedDate];
    NSInteger tomatoCount = 0;
    NSInteger focusedSeconds = 0;
    for (SKFocusRecord *record in selectedRecords) {
        if (record.countedAsTomato) tomatoCount++;
        focusedSeconds += MAX(0, record.actualSeconds);
    }
    NSString *summary = selectedRecords.count ?
        [NSString stringWithFormat:@"%ld 个番茄 · %@", (long)tomatoCount, SKDurationText(focusedSeconds)] :
        @"这一天还没有专注记录";
    NSDictionary *summaryStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular],
                                   NSForegroundColorAttributeName:NSColor.secondaryLabelColor};
    [summary drawAtPoint:NSMakePoint(14, summaryY + 43) withAttributes:summaryStyle];
    NSString *convertedDuration = selectedRecords.count ?
        SKCalendarConvertedDurationText(focusedSeconds) : nil;
    if (convertedDuration.length) {
        NSDictionary *convertedStyle =
            @{NSFontAttributeName:[NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium],
              NSForegroundColorAttributeName:[NSColor.secondaryLabelColor colorWithAlphaComponent:0.86]};
        [convertedDuration drawAtPoint:NSMakePoint(14, summaryY + 63)
                        withAttributes:convertedStyle];
    }
    NSDictionary *hintStyle = @{NSFontAttributeName:[NSFont systemFontOfSize:10 weight:NSFontWeightRegular],
                                NSForegroundColorAttributeName:NSColor.tertiaryLabelColor};
    CGFloat hintY = summaryY + (convertedDuration.length ? 86 : 68);
    [@"点击日期即可查看对应日或周" drawAtPoint:NSMakePoint(14, hintY)
                              withAttributes:hintStyle];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    for (NSDictionary *region in self.hitRegions.reverseObjectEnumerator) {
        if (!NSPointInRect(point, [region[@"rect"] rectValue])) continue;
        NSString *action = region[@"action"];
        if (action.length) {
            NSInteger offset = [action isEqualToString:@"previous"] ? -1 : 1;
            self.displayMonth = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitMonth
                                                                        value:offset
                                                                       toDate:self.displayMonth ?: NSDate.date
                                                                      options:0];
            self.needsDisplay = YES;
            return;
        }
        NSDate *date = region[@"date"];
        if (date) {
            _selectedDate = date;
            self.needsDisplay = YES;
            if (self.dateSelectionHandler) self.dateSelectionHandler(date);
            return;
        }
    }
    [super mouseDown:event];
}

@end

@interface SKCalendarWindowController : NSWindowController
@property(nonatomic, strong) SKWeekCalendarView *calendarView;
@property(nonatomic, strong) NSScrollView *calendarScrollView;
@property(nonatomic, strong) SKMiniCalendarView *miniCalendarView;
@property(nonatomic, strong) NSTextField *dateLabel;
@property(nonatomic, strong) NSSegmentedControl *modeControl;
- (instancetype)initWithRecords:(NSArray<SKFocusRecord *> *)records;
- (void)updateRecords:(NSArray<SKFocusRecord *> *)records;
@end

@implementation SKCalendarWindowController

- (instancetype)initWithRecords:(NSArray<SKFocusRecord *> *)records {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1340, 820)
                                                   styleMask:NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"拾刻日历";
    window.minSize = NSMakeSize(1000, 620);
    window.backgroundColor = SKCalendarSurfaceColor();
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    self = [super initWithWindow:window];
    if (!self) return nil;

    NSView *root = [NSView new];
    root.wantsLayer = YES;
    root.layer.backgroundColor = SKCalendarSurfaceColor().CGColor;

    self.miniCalendarView = [SKMiniCalendarView new];
    self.miniCalendarView.records = records;
    self.miniCalendarView.selectedDate = NSDate.date;
    self.miniCalendarView.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.miniCalendarView];

    NSBox *sidebarDivider = [NSBox new];
    sidebarDivider.boxType = NSBoxSeparator;
    sidebarDivider.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:sidebarDivider];

    NSView *mainArea = [NSView new];
    mainArea.wantsLayer = YES;
    mainArea.layer.backgroundColor = SKCalendarSurfaceColor().CGColor;
    mainArea.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:mainArea];

    NSStackView *left = [NSStackView new];
    left.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    left.spacing = 8;
    left.translatesAutoresizingMaskIntoConstraints = NO;
    NSButton *previous = SKButton(@"‹", self, @selector(previousPeriod:));
    NSButton *today = SKButton(@"今天", self, @selector(goToday:));
    NSButton *next = SKButton(@"›", self, @selector(nextPeriod:));
    for (NSButton *button in @[previous, today, next]) button.controlSize = NSControlSizeRegular;
    previous.bordered = NO;
    next.bordered = NO;
    previous.font = [NSFont systemFontOfSize:21 weight:NSFontWeightRegular];
    next.font = [NSFont systemFontOfSize:21 weight:NSFontWeightRegular];
    [left addArrangedSubview:previous];
    [left addArrangedSubview:today];
    [left addArrangedSubview:next];
    self.dateLabel = SKLabel(@"", 20, NSFontWeightSemibold);
    [left addArrangedSubview:self.dateLabel];

    self.modeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"日", @"周", @"月"]
                                                         trackingMode:NSSegmentSwitchTrackingSelectOne
                                                               target:self
                                                               action:@selector(modeChanged:)];
    self.modeControl.selectedSegment = 1;
    self.modeControl.controlSize = NSControlSizeRegular;
    self.modeControl.translatesAutoresizingMaskIntoConstraints = NO;

    self.calendarView = [[SKWeekCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, 1000, SKCalendarTimelineHeight())];
    self.calendarView.records = records;
    self.calendarView.referenceDate = NSDate.date;
    self.calendarView.viewMode = 1;
    self.calendarView.autoresizingMask = NSViewWidthSizable;
    self.calendarScrollView = [NSScrollView new];
    self.calendarScrollView.hasVerticalScroller = YES;
    self.calendarScrollView.hasHorizontalScroller = NO;
    self.calendarScrollView.autohidesScrollers = YES;
    self.calendarScrollView.borderType = NSNoBorder;
    self.calendarScrollView.drawsBackground = YES;
    self.calendarScrollView.backgroundColor = SKCalendarSurfaceColor();
    self.calendarScrollView.documentView = self.calendarView;
    self.calendarScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [mainArea addSubview:left];
    [mainArea addSubview:self.modeControl];
    [mainArea addSubview:self.calendarScrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.miniCalendarView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.miniCalendarView.topAnchor constraintEqualToAnchor:root.topAnchor],
        [self.miniCalendarView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [self.miniCalendarView.widthAnchor constraintEqualToConstant:SKCalendarSidebarWidth()],
        [sidebarDivider.leadingAnchor constraintEqualToAnchor:self.miniCalendarView.trailingAnchor],
        [sidebarDivider.topAnchor constraintEqualToAnchor:root.topAnchor],
        [sidebarDivider.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [sidebarDivider.widthAnchor constraintEqualToConstant:1],
        [mainArea.leadingAnchor constraintEqualToAnchor:sidebarDivider.trailingAnchor],
        [mainArea.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [mainArea.topAnchor constraintEqualToAnchor:root.topAnchor],
        [mainArea.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [left.leadingAnchor constraintEqualToAnchor:mainArea.leadingAnchor constant:18],
        [left.topAnchor constraintEqualToAnchor:mainArea.topAnchor constant:14],
        [self.modeControl.topAnchor constraintEqualToAnchor:mainArea.topAnchor constant:14],
        [self.modeControl.trailingAnchor constraintEqualToAnchor:mainArea.trailingAnchor constant:-24],
        [self.calendarScrollView.leadingAnchor constraintEqualToAnchor:mainArea.leadingAnchor],
        [self.calendarScrollView.trailingAnchor constraintEqualToAnchor:mainArea.trailingAnchor],
        [self.calendarScrollView.topAnchor constraintEqualToAnchor:left.bottomAnchor constant:10],
        [self.calendarScrollView.bottomAnchor constraintEqualToAnchor:mainArea.bottomAnchor]
    ]];
    __weak SKCalendarWindowController *weakSelf = self;
    self.miniCalendarView.dateSelectionHandler = ^(NSDate *date) {
        SKCalendarWindowController *strongSelf = weakSelf;
        strongSelf.calendarView.referenceDate = date;
        [strongSelf refreshDateLabel];
    };
    window.contentView = root;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.calendarView fitToEnclosingScrollView];
        [self.calendarScrollView.contentView scrollToPoint:NSZeroPoint];
        [self.calendarScrollView reflectScrolledClipView:self.calendarScrollView.contentView];
    });
    [self refreshDateLabel];
    return self;
}

- (void)updateRecords:(NSArray<SKFocusRecord *> *)records {
    self.calendarView.records = records;
    self.miniCalendarView.records = records;
}

- (void)refreshDateLabel {
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    formatter.dateFormat = self.calendarView.viewMode == 2 ? @"yyyy年MM月" : @"yyyy年MM月dd日";
    NSDate *referenceDate = self.calendarView.referenceDate ?: NSDate.date;
    self.dateLabel.stringValue = [formatter stringFromDate:referenceDate];
    if (![NSCalendar.currentCalendar isDate:self.miniCalendarView.selectedDate
                            inSameDayAsDate:referenceDate]) {
        self.miniCalendarView.selectedDate = referenceDate;
    }
}

- (void)movePeriod:(NSInteger)direction {
    NSCalendarUnit unit = self.calendarView.viewMode == 0 ? NSCalendarUnitDay :
                          self.calendarView.viewMode == 1 ? NSCalendarUnitWeekOfYear : NSCalendarUnitMonth;
    self.calendarView.referenceDate = [NSCalendar.currentCalendar dateByAddingUnit:unit
                                                                            value:direction
                                                                           toDate:self.calendarView.referenceDate ?: NSDate.date
                                                                          options:0];
    [self refreshDateLabel];
}

- (void)previousPeriod:(id)sender { [self movePeriod:-1]; }
- (void)nextPeriod:(id)sender { [self movePeriod:1]; }
- (void)goToday:(id)sender {
    self.calendarView.referenceDate = NSDate.date;
    [self refreshDateLabel];
}
- (void)modeChanged:(NSSegmentedControl *)sender {
    self.calendarView.viewMode = sender.selectedSegment;
    self.calendarScrollView.hasVerticalScroller = sender.selectedSegment != 2;
    [self.calendarView fitToEnclosingScrollView];
    [self.calendarScrollView.contentView scrollToPoint:NSZeroPoint];
    [self.calendarScrollView reflectScrolledClipView:self.calendarScrollView.contentView];
    [self refreshDateLabel];
}

@end

@interface SKLogWindowController : NSWindowController <NSWindowDelegate>
@property(nonatomic, strong) SKFocusRecord *record;
@property(nonatomic, strong) NSTextField *summaryField;
@property(nonatomic, strong) NSTextView *detailView;
@property(nonatomic, strong) NSTextField *reasonField;
@property(nonatomic, strong) NSView *optionalDetailsContainer;
@property(nonatomic, strong) NSLayoutConstraint *optionalDetailsHeightConstraint;
@property(nonatomic, strong) NSButton *detailsToggleButton;
@property(nonatomic) BOOL detailsExpanded;
@property(nonatomic) BOOL completionPrompt;
- (instancetype)initWithRecord:(SKFocusRecord *)record completionPrompt:(BOOL)completionPrompt;
- (NSModalResponse)runEditor;
- (void)toggleDetails:(id)sender;
@end

@implementation SKLogWindowController

- (instancetype)initWithRecord:(SKFocusRecord *)record completionPrompt:(BOOL)completionPrompt {
    BOOL detailsExpanded = SKLogDetailsInitiallyExpanded(record, completionPrompt);
    CGFloat contentHeight = detailsExpanded ? 560 : 405;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:
                        NSMakeRect(0, 0, SKLogWindowWidth(), contentHeight)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.movableByWindowBackground = YES;
    window.releasedWhenClosed = NO;
    self = [super initWithWindow:window];
    if (!self) return nil;
    self.record = record;
    self.completionPrompt = completionPrompt;
    self.detailsExpanded = detailsExpanded;
    window.delegate = self;

    NSView *root = [NSView new];
    root.wantsLayer = YES;
    root.layer.backgroundColor = SKZenSurfaceColor().CGColor;
    window.contentView = root;

    NSTextField *eyebrow = SKLabel(completionPrompt ? @"一轮完成" : @"专注日志", 11, NSFontWeightSemibold);
    eyebrow.textColor = [SKAccentColor() colorWithAlphaComponent:0.82];
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:eyebrow];
    NSTextField *headerTitle = SKLabel(completionPrompt ? @"这一刻，你完成了什么？" : @"回看这一刻", 25, NSFontWeightSemibold);
    headerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:headerTitle];
    NSTextField *headerSubtitle = SKLabel(completionPrompt ? @"写下一句就够了。" : @"保留真实发生的事，也保留当时的感受。", 12, NSFontWeightRegular);
    headerSubtitle.textColor = NSColor.secondaryLabelColor;
    headerSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:headerSubtitle];

    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    dateFormatter.dateFormat = @"M月d日  HH:mm";
    NSString *status = [record.status isEqualToString:@"aborted"] ? @"提前结束" : @"已完成";
    NSString *taskName = record.taskTitleSnapshot.length ? record.taskTitleSnapshot : @"未关联任务";
    NSTextField *taskLabel = SKLabel(taskName, 13, NSFontWeightSemibold);
    taskLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:taskLabel];
    NSTextField *metaLine = SKLabel([NSString stringWithFormat:@"%@  ·  计划 %@  ·  实际 %@  ·  %@",
                                     [dateFormatter stringFromDate:record.startedAt],
                                     SKDurationText(record.plannedSeconds),
                                     SKDurationText(record.actualSeconds), status],
                                    11, NSFontWeightRegular);
    metaLine.textColor = NSColor.secondaryLabelColor;
    metaLine.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:metaLine];

    self.summaryField = [NSTextField new];
    self.summaryField.placeholderString = @"例如：完成第三章提纲，知道下一步从哪里开始";
    self.summaryField.stringValue = record.logSummary ?: @"";
    self.summaryField.font = [NSFont systemFontOfSize:15 weight:NSFontWeightRegular];
    self.summaryField.controlSize = NSControlSizeLarge;
    self.summaryField.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.summaryField];

    self.detailsToggleButton = SKButton(@"添加详细记录  ···", self, @selector(toggleDetails:));
    self.detailsToggleButton.bordered = NO;
    self.detailsToggleButton.contentTintColor = NSColor.secondaryLabelColor;
    self.detailsToggleButton.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.detailsToggleButton];

    self.optionalDetailsContainer = [NSView new];
    self.optionalDetailsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.optionalDetailsContainer.hidden = !detailsExpanded;
    [root addSubview:self.optionalDetailsContainer];

    NSTextField *detailTitle = SKLabel(@"详情", 12, NSFontWeightSemibold);
    detailTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.optionalDetailsContainer addSubview:detailTitle];
    NSScrollView *detailScroll = [NSScrollView new];
    detailScroll.borderType = NSBezelBorder;
    detailScroll.hasVerticalScroller = YES;
    detailScroll.wantsLayer = YES;
    detailScroll.layer.cornerRadius = 8;
    detailScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.detailView = [[NSTextView alloc] initWithFrame:
                       NSMakeRect(0, 0, SKLogContentWidth(), 120)];
    self.detailView.font = [NSFont systemFontOfSize:13];
    self.detailView.textContainerInset = NSMakeSize(8, 8);
    self.detailView.string = record.logDetail ?: @"";
    detailScroll.documentView = self.detailView;
    [self.optionalDetailsContainer addSubview:detailScroll];

    NSTextField *reasonTitle = SKLabel(@"中断原因（可选）", 12, NSFontWeightSemibold);
    reasonTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [self.optionalDetailsContainer addSubview:reasonTitle];
    self.reasonField = [NSTextField new];
    self.reasonField.placeholderString = @"例如：临时会议、任务不清楚、注意力转移";
    self.reasonField.stringValue = record.interruptionReason ?: @"";
    self.reasonField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.optionalDetailsContainer addSubview:self.reasonField];
    BOOL interrupted = [record.status isEqualToString:@"aborted"];
    reasonTitle.hidden = !interrupted;
    self.reasonField.hidden = !interrupted;

    NSTextField *privacy = SKLabel(@"日志仅保存在这台 Mac 上", 10, NSFontWeightMedium);
    privacy.textColor = NSColor.tertiaryLabelColor;
    privacy.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:privacy];
    NSButton *skip = SKButton(completionPrompt ? @"稍后再写" : @"取消", self, @selector(cancel:));
    skip.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:skip];
    NSButton *save = SKButton(completionPrompt ? @"收下这一刻" : @"保存", self, @selector(save:));
    save.bezelColor = SKAccentColor();
    save.keyEquivalent = @"\r";
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:save];

    CGFloat detailsHeight = interrupted ? 190 : 140;
    self.optionalDetailsHeightConstraint = [self.optionalDetailsContainer.heightAnchor
        constraintEqualToConstant:detailsExpanded ? detailsHeight : 0];
    self.optionalDetailsHeightConstraint.active = YES;
    CGFloat contentInset = (SKLogWindowWidth() - SKLogContentWidth()) / 2.0;
    [NSLayoutConstraint activateConstraints:@[
        [eyebrow.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:contentInset],
        [eyebrow.topAnchor constraintEqualToAnchor:root.topAnchor constant:28],
        [headerTitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [headerTitle.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:8],
        [headerSubtitle.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [headerSubtitle.topAnchor constraintEqualToAnchor:headerTitle.bottomAnchor constant:6],
        [taskLabel.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [taskLabel.topAnchor constraintEqualToAnchor:headerSubtitle.bottomAnchor constant:20],
        [metaLine.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [metaLine.topAnchor constraintEqualToAnchor:taskLabel.bottomAnchor constant:4],
        [self.summaryField.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.summaryField.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-contentInset],
        [self.summaryField.topAnchor constraintEqualToAnchor:metaLine.bottomAnchor constant:22],
        [self.summaryField.heightAnchor constraintEqualToConstant:42],
        [self.detailsToggleButton.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor constant:-8],
        [self.detailsToggleButton.topAnchor constraintEqualToAnchor:self.summaryField.bottomAnchor constant:10],
        [self.optionalDetailsContainer.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [self.optionalDetailsContainer.trailingAnchor constraintEqualToAnchor:self.summaryField.trailingAnchor],
        [self.optionalDetailsContainer.topAnchor constraintEqualToAnchor:self.detailsToggleButton.bottomAnchor constant:6],
        [detailTitle.leadingAnchor constraintEqualToAnchor:self.optionalDetailsContainer.leadingAnchor],
        [detailTitle.topAnchor constraintEqualToAnchor:self.optionalDetailsContainer.topAnchor],
        [detailScroll.leadingAnchor constraintEqualToAnchor:detailTitle.leadingAnchor],
        [detailScroll.trailingAnchor constraintEqualToAnchor:self.optionalDetailsContainer.trailingAnchor],
        [detailScroll.topAnchor constraintEqualToAnchor:detailTitle.bottomAnchor constant:6],
        [detailScroll.heightAnchor constraintEqualToConstant:96],
        [reasonTitle.leadingAnchor constraintEqualToAnchor:detailTitle.leadingAnchor],
        [reasonTitle.topAnchor constraintEqualToAnchor:detailScroll.bottomAnchor constant:(interrupted ? 12 : 0)],
        [self.reasonField.leadingAnchor constraintEqualToAnchor:reasonTitle.leadingAnchor],
        [self.reasonField.trailingAnchor constraintEqualToAnchor:self.optionalDetailsContainer.trailingAnchor],
        [self.reasonField.topAnchor constraintEqualToAnchor:reasonTitle.bottomAnchor constant:(interrupted ? 5 : 0)],
        [self.reasonField.heightAnchor constraintEqualToConstant:interrupted ? 28 : 0],
        [privacy.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [privacy.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-28],
        [save.trailingAnchor constraintEqualToAnchor:self.summaryField.trailingAnchor],
        [save.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-22],
        [save.widthAnchor constraintEqualToConstant:126],
        [skip.trailingAnchor constraintEqualToAnchor:save.leadingAnchor constant:-8],
        [skip.centerYAnchor constraintEqualToAnchor:save.centerYAnchor]
    ]];
    self.detailsToggleButton.title = detailsExpanded ? @"收起详细记录  ···" : @"添加详细记录  ···";
    return self;
}

- (void)setDetailsExpanded:(BOOL)expanded animated:(BOOL)animated {
    if (self.detailsExpanded == expanded && self.optionalDetailsContainer.hidden == !expanded) return;
    self.detailsExpanded = expanded;
    self.detailsToggleButton.title = expanded ? @"收起详细记录  ···" : @"添加详细记录  ···";
    BOOL interrupted = [self.record.status isEqualToString:@"aborted"];
    self.optionalDetailsHeightConstraint.constant = expanded ? (interrupted ? 190 : 140) : 0;
    if (expanded) self.optionalDetailsContainer.hidden = NO;

    NSRect frame = self.window.frame;
    CGFloat targetContentHeight = expanded ? 560 : 405;
    NSRect contentRect = [self.window contentRectForFrameRect:frame];
    CGFloat delta = targetContentHeight - contentRect.size.height;
    frame.origin.y -= delta;
    frame.size.height += delta;
    void (^changes)(void) = ^{
        [self.window setFrame:frame display:YES];
        [self.window.contentView layoutSubtreeIfNeeded];
    };
    if (animated) {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.18;
            context.allowsImplicitAnimation = YES;
            changes();
        } completionHandler:^{
            if (!expanded) self.optionalDetailsContainer.hidden = YES;
        }];
    } else {
        changes();
        if (!expanded) self.optionalDetailsContainer.hidden = YES;
    }
}

- (void)toggleDetails:(id)sender {
    [self setDetailsExpanded:!self.detailsExpanded animated:self.window.visible];
}

- (NSModalResponse)runEditor {
    NSWindow *previousWindow = NSApp.keyWindow;
    [self.window center];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse response = [NSApp runModalForWindow:self.window];
    if (previousWindow && previousWindow.visible) {
        [previousWindow makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
    }
    return response;
}

- (void)save:(id)sender {
    NSString *(^clean)(NSString *) = ^NSString *(NSString *value) {
        NSString *result = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        return result.length ? result : nil;
    };
    self.record.logSummary = clean(self.summaryField.stringValue);
    self.record.logDetail = clean(self.detailView.string);
    self.record.interruptionReason = clean(self.reasonField.stringValue);
    [NSApp stopModalWithCode:NSModalResponseOK];
    [self close];
}

- (void)cancel:(id)sender {
    [NSApp stopModalWithCode:NSModalResponseCancel];
    [self close];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (NSApp.modalWindow == self.window) [NSApp stopModalWithCode:NSModalResponseCancel];
}

@end

@interface SKTaskRowView : NSTableRowView
@end

@interface SKTaskCompletionButton : NSButton
@end

@implementation SKTaskCompletionButton

- (NSEdgeInsets)alignmentRectInsets { return NSEdgeInsetsZero; }

@end

@implementation SKTaskRowView

- (void)drawSelectionInRect:(NSRect)dirtyRect {
    if (!self.selected) return;
    NSRect highlight = NSInsetRect(self.bounds, 5, 3);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:highlight xRadius:10 yRadius:10];
    [SKTaskSelectionFillColor(self.emphasized) setFill];
    [path fill];
    [[SKAccentColor() colorWithAlphaComponent:0.24] setStroke];
    path.lineWidth = 1;
    [path stroke];
    NSRect indicator = NSMakeRect(NSMinX(highlight) + 1, NSMinY(highlight) + 8,
                                  3, MAX(12, NSHeight(highlight) - 16));
    NSBezierPath *indicatorPath = [NSBezierPath bezierPathWithRoundedRect:indicator
                                                                  xRadius:1.5 yRadius:1.5];
    [SKAccentColor() setFill];
    [indicatorPath fill];
}

- (NSBackgroundStyle)interiorBackgroundStyle { return NSBackgroundStyleNormal; }

@end

@interface SKMainViewController : NSViewController
<NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, UNUserNotificationCenterDelegate>
@property(nonatomic, strong) SKAppStore *store;
@property(nonatomic, strong) SKTimerEngine *engine;
@property(nonatomic, strong) NSSegmentedControl *navigation;
@property(nonatomic, strong) NSView *contentHost;
@property(nonatomic, copy) NSArray<NSView *> *pages;

@property(nonatomic, strong) NSTableView *taskTable;
@property(nonatomic, strong) NSScrollView *taskScroll;
@property(nonatomic, strong) NSStackView *taskActions;
@property(nonatomic, strong) NSTextField *taskInputField;
@property(nonatomic, strong) NSTextField *taskEmptyLabel;

@property(nonatomic, strong) NSTextField *focusTaskLabel;
@property(nonatomic, strong) NSPopUpButton *focusTaskPopup;
@property(nonatomic, strong) NSTextField *phaseLabel;
@property(nonatomic, strong) NSTextField *timerLabel;
@property(nonatomic, strong) SKProgressRingView *focusProgress;
@property(nonatomic, strong) NSTextField *focusHintLabel;
@property(nonatomic, strong) NSBox *focusSettingsCard;
@property(nonatomic, strong) NSTextField *focusEyebrow;
@property(nonatomic, strong) NSTextField *durationField;
@property(nonatomic, strong) NSStackView *durationRow;
@property(nonatomic, strong) NSSegmentedControl *durationPresets;
@property(nonatomic, strong) NSButton *focusUntilButton;
@property(nonatomic, strong) NSButton *primaryButton;
@property(nonatomic, strong) NSButton *pauseButton;
@property(nonatomic, strong) NSButton *endButton;
@property(nonatomic, strong) NSTextField *todayLabel;

@property(nonatomic, strong) NSTextField *recordsSummaryLabel;
@property(nonatomic, strong) NSTextField *recordCountValue;
@property(nonatomic, strong) NSTextField *recordTimeValue;
@property(nonatomic, strong) NSSegmentedControl *recordMode;
@property(nonatomic, strong) NSPopUpButton *recordFilter;
@property(nonatomic, strong) NSScrollView *recordsScroll;
@property(nonatomic, strong) NSScrollView *calendarScroll;
@property(nonatomic, strong) NSTableView *recordsTable;
@property(nonatomic, strong) SKWeekCalendarView *calendarView;
@property(nonatomic, strong) NSStackView *recordActions;
@property(nonatomic, strong) NSWindowController *calendarWindowController;

@property(nonatomic, strong) NSButton *soundCheckbox;
@property(nonatomic, strong) NSButton *countdownCheckbox;
@property(nonatomic, strong) NSButton *dockCheckbox;
@property(nonatomic, strong) NSButton *launchCheckbox;
@property(nonatomic, strong) NSButton *popupNotificationsCheckbox;
@property(nonatomic, strong) NSTextField *notificationStatusLabel;
@property(nonatomic, strong) NSButton *notificationPermissionButton;
@property(nonatomic, strong) NSButton *interruptionReasonCheckbox;
@property(nonatomic, strong) NSPopUpButton *defaultWorkPopup;
@property(nonatomic, strong) NSPopUpButton *soundPopup;
@property(nonatomic, strong) NSSlider *volumeSlider;
@property(nonatomic, strong) NSSound *completionSound;
@property(nonatomic, strong) NSDate *restStartedAt;

@property(nonatomic, strong) NSTimer *ticker;
@property(nonatomic, strong) id timerResponsivenessActivity;
@property(nonatomic) BOOL handlingCompletion;
- (NSString *)menuBarTitle;
- (void)openCalendarWindow:(id)sender;
- (void)toggleTimerFromMenu:(id)sender;
- (void)statusPresetMinutes:(NSInteger)minutes;
- (void)syncPreparedTaskFromSelection;
- (void)scheduleNotificationForCurrentSession;
- (void)cancelPendingTimerNotifications;
- (void)updateTimerResponsivenessActivity;
- (BOOL)confirmNextFocusAfterBreak;
@end

@implementation SKMainViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _store = [[SKAppStore alloc] initWithStorageURL:SKAppStore.defaultStorageURL];
        [_store load];
        _engine = [SKTimerEngine new];
        if (_store.activeTimerSnapshot) {
            if (![_engine restoreFromDictionary:_store.activeTimerSnapshot]) {
                _store.activeTimerSnapshot = nil;
            }
        }
        if ([_engine.phase isEqualToString:SKTimerPhaseReady] && !_store.activeTimerSnapshot) {
            [self prepareDefaultSessionForceStandard:NO];
        }
    }
    return self;
}

- (void)dealloc {
    [self.ticker invalidate];
    if (self.timerResponsivenessActivity) {
        [NSProcessInfo.processInfo endActivity:self.timerResponsivenessActivity];
    }
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 900, 640)];
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = NSColor.underPageBackgroundColor.CGColor;

    NSImageView *brandIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    brandIcon.image = NSApp.applicationIconImage;
    brandIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    brandIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:brandIcon];
    NSStackView *brandStack = [NSStackView new];
    brandStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    brandStack.alignment = NSLayoutAttributeLeading;
    brandStack.spacing = 0;
    brandStack.translatesAutoresizingMaskIntoConstraints = NO;
    [brandStack addArrangedSubview:SKLabel(@"拾刻", 21, NSFontWeightBold)];
    NSTextField *tagline = SKLabel(@"把注意力交给下一刻", 10, NSFontWeightMedium);
    tagline.textColor = NSColor.secondaryLabelColor;
    [brandStack addArrangedSubview:tagline];
    [self.view addSubview:brandStack];

    self.navigation = [NSSegmentedControl segmentedControlWithLabels:@[@"任务", @"专注", @"记录", @"设置"]
                                                        trackingMode:NSSegmentSwitchTrackingSelectOne
                                                              target:self
                                                              action:@selector(navigationChanged:)];
    self.navigation.selectedSegment = 1;
    self.navigation.controlSize = NSControlSizeLarge;
    self.navigation.segmentStyle = NSSegmentStyleTexturedRounded;
    self.navigation.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.navigation];

    self.contentHost = [NSView new];
    self.contentHost.wantsLayer = YES;
    self.contentHost.layer.cornerRadius = 22;
    self.contentHost.layer.backgroundColor = [NSColor.windowBackgroundColor colorWithAlphaComponent:0.92].CGColor;
    self.contentHost.layer.borderWidth = 1;
    self.contentHost.layer.borderColor = [NSColor.separatorColor colorWithAlphaComponent:0.55].CGColor;
    self.contentHost.layer.shadowColor = NSColor.blackColor.CGColor;
    self.contentHost.layer.shadowOpacity = 0.08;
    self.contentHost.layer.shadowRadius = 20;
    self.contentHost.layer.shadowOffset = NSMakeSize(0, -4);
    self.contentHost.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.contentHost];

    NSTextField *privacyBadge = SKLabel(@"本地保存  ·  隐私优先", 11, NSFontWeightSemibold);
    privacyBadge.textColor = NSColor.secondaryLabelColor;
    privacyBadge.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:privacyBadge];

    [NSLayoutConstraint activateConstraints:@[
        [brandIcon.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:22],
        [brandIcon.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:15],
        [brandIcon.widthAnchor constraintEqualToConstant:36],
        [brandIcon.heightAnchor constraintEqualToConstant:36],
        [brandStack.leadingAnchor constraintEqualToAnchor:brandIcon.trailingAnchor constant:10],
        [brandStack.centerYAnchor constraintEqualToAnchor:brandIcon.centerYAnchor],
        [self.navigation.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.navigation.centerYAnchor constraintEqualToAnchor:brandIcon.centerYAnchor],
        [self.navigation.widthAnchor constraintEqualToConstant:320],
        [privacyBadge.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-22],
        [privacyBadge.centerYAnchor constraintEqualToAnchor:brandIcon.centerYAnchor],
        [self.contentHost.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [self.contentHost.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [self.contentHost.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:68],
        [self.contentHost.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-18]
    ]];

    self.pages = @[
        [self buildTasksPage],
        [self buildFocusPage],
        [self buildRecordsPage],
        [self buildSettingsPage]
    ];
    for (NSView *page in self.pages) {
        page.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentHost addSubview:page];
        [NSLayoutConstraint activateConstraints:@[
            [page.leadingAnchor constraintEqualToAnchor:self.contentHost.leadingAnchor],
            [page.trailingAnchor constraintEqualToAnchor:self.contentHost.trailingAnchor],
            [page.topAnchor constraintEqualToAnchor:self.contentHost.topAnchor],
            [page.bottomAnchor constraintEqualToAnchor:self.contentHost.bottomAnchor]
        ]];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
    for (SKTask *task in self.store.activeTasks) [self syncReminderForTask:task];

    [self refreshAll];
    [self showPage:1];
    self.ticker = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                   target:self
                                                 selector:@selector(timerTick:)
                                                 userInfo:nil
                                                  repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.ticker forMode:NSRunLoopCommonModes];
    if (([self.engine.phase isEqualToString:SKTimerPhaseRunning] ||
         [self.engine.phase isEqualToString:SKTimerPhaseTransition]) &&
        ![self.engine hasReachedEndAtDate:NSDate.date]) {
        [self scheduleNotificationForCurrentSession];
    }
    [self updateTimerResponsivenessActivity];
}

- (NSView *)buildTasksPage {
    NSView *page = [NSView new];
    page.wantsLayer = YES;
    page.layer.backgroundColor = SKZenSurfaceColor().CGColor;
    NSTextField *title = SKLabel(@"现在做什么？", 27, NSFontWeightSemibold);
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:title];
    NSTextField *subtitle = SKLabel(@"把脑子里的事放下来，一次只选一件。", 13, NSFontWeightRegular);
    subtitle.textColor = NSColor.secondaryLabelColor;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:subtitle];

    self.taskInputField = [NSTextField new];
    self.taskInputField.placeholderString = @"输入任务，按 Return 添加";
    self.taskInputField.font = [NSFont systemFontOfSize:14 weight:NSFontWeightRegular];
    self.taskInputField.controlSize = NSControlSizeLarge;
    self.taskInputField.bezelStyle = NSTextFieldRoundedBezel;
    self.taskInputField.target = self;
    self.taskInputField.action = @selector(addTask:);
    self.taskInputField.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.taskInputField];

    NSButton *add = SKButton(@"添加", self, @selector(addTask:));
    add.bezelColor = SKAccentColor();
    add.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:add];

    self.taskTable = [NSTableView new];
    self.taskTable.headerView = nil;
    self.taskTable.rowHeight = SKTaskRowHeight();
    self.taskTable.intercellSpacing = NSMakeSize(0, 2);
    self.taskTable.delegate = self;
    self.taskTable.dataSource = self;
    self.taskTable.target = self;
    self.taskTable.doubleAction = @selector(openTaskDetails:);
    self.taskTable.usesAlternatingRowBackgroundColors = NO;
    self.taskTable.backgroundColor = NSColor.clearColor;
    self.taskTable.gridStyleMask = NSTableViewGridNone;
    self.taskTable.style = NSTableViewStylePlain;
    NSTableColumn *done = [[NSTableColumn alloc] initWithIdentifier:@"done"];
    done.width = 46;
    done.resizingMask = NSTableColumnNoResizing;
    [self.taskTable addTableColumn:done];
    NSTableColumn *taskTitle = [[NSTableColumn alloc] initWithIdentifier:@"taskTitle"];
    taskTitle.width = 520;
    taskTitle.minWidth = 220;
    taskTitle.resizingMask = NSTableColumnAutoresizingMask;
    [self.taskTable addTableColumn:taskTitle];
    NSTableColumn *taskMeta = [[NSTableColumn alloc] initWithIdentifier:@"taskMeta"];
    taskMeta.width = 220;
    taskMeta.minWidth = 150;
    [self.taskTable addTableColumn:taskMeta];

    self.taskScroll = [NSScrollView new];
    self.taskScroll.documentView = self.taskTable;
    self.taskScroll.hasVerticalScroller = YES;
    SKStyleScrollView(self.taskScroll);
    self.taskScroll.drawsBackground = NO;
    self.taskScroll.layer.backgroundColor = [NSColor.whiteColor colorWithAlphaComponent:0.36].CGColor;
    self.taskScroll.layer.borderColor = [NSColor.separatorColor
        colorWithAlphaComponent:SKTaskSurfaceBorderAlpha()].CGColor;
    self.taskScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.taskScroll];

    self.taskEmptyLabel = SKLabel(@"还没有任务\n写下一个现在就能开始的动作\n\n例如：打开文档，先写第一句", 15, NSFontWeightMedium);
    self.taskEmptyLabel.textColor = NSColor.tertiaryLabelColor;
    self.taskEmptyLabel.alignment = NSTextAlignmentCenter;
    self.taskEmptyLabel.maximumNumberOfLines = 4;
    self.taskEmptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.taskEmptyLabel];

    NSButton *focusAction = SKButton(@"开始专注", self, @selector(focusSelectedTask:));
    focusAction.bezelColor = SKAccentColor();
    focusAction.controlSize = NSControlSizeRegular;
    NSArray<NSButton *> *secondaryActions = @[
        SKButton(@"查看详情", self, @selector(openTaskDetails:)),
        SKButton(@"上移", self, @selector(moveTaskUp:)),
        SKButton(@"下移", self, @selector(moveTaskDown:)),
        SKButton(@"删除", self, @selector(deleteTask:)),
        SKButton(@"回收站", self, @selector(openTrash:))
    ];
    for (NSButton *button in secondaryActions) {
        button.bordered = NO;
        button.controlSize = NSControlSizeRegular;
        button.contentTintColor = NSColor.secondaryLabelColor;
    }
    NSMutableArray<NSView *> *actionViews = [NSMutableArray arrayWithObject:focusAction];
    [actionViews addObjectsFromArray:secondaryActions];
    self.taskActions = [NSStackView stackViewWithViews:actionViews];
    self.taskActions.spacing = 8;
    self.taskActions.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.taskActions];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:page.leadingAnchor constant:72],
        [title.topAnchor constraintEqualToAnchor:page.topAnchor constant:28],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [self.taskInputField.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.taskInputField.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20],
        [self.taskInputField.trailingAnchor constraintEqualToAnchor:add.leadingAnchor constant:-10],
        [add.trailingAnchor constraintEqualToAnchor:page.trailingAnchor constant:-72],
        [add.centerYAnchor constraintEqualToAnchor:self.taskInputField.centerYAnchor],
        [add.widthAnchor constraintEqualToConstant:92],
        [self.taskScroll.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.taskScroll.trailingAnchor constraintEqualToAnchor:add.trailingAnchor],
        [self.taskScroll.topAnchor constraintEqualToAnchor:self.taskInputField.bottomAnchor constant:18],
        [self.taskScroll.bottomAnchor constraintEqualToAnchor:self.taskActions.topAnchor constant:-12],
        [self.taskEmptyLabel.centerXAnchor constraintEqualToAnchor:self.taskScroll.centerXAnchor],
        [self.taskEmptyLabel.centerYAnchor constraintEqualToAnchor:self.taskScroll.centerYAnchor],
        [self.taskActions.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.taskActions.bottomAnchor constraintEqualToAnchor:page.bottomAnchor constant:-28]
    ]];
    return page;
}

- (NSView *)buildFocusPage {
    NSView *page = [NSView new];
    page.wantsLayer = YES;
    page.layer.backgroundColor = SKZenSurfaceColor().CGColor;
    NSStackView *layout = [NSStackView new];
    layout.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    layout.alignment = NSLayoutAttributeCenterY;
    layout.spacing = 26;
    layout.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:layout];

    NSStackView *timerColumn = [NSStackView new];
    timerColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    timerColumn.alignment = NSLayoutAttributeCenterX;
    timerColumn.spacing = 12;
    [timerColumn.widthAnchor constraintEqualToConstant:360].active = YES;
    [layout addArrangedSubview:timerColumn];

    self.focusEyebrow = SKLabel(@"当前这一刻", 11, NSFontWeightSemibold);
    self.focusEyebrow.textColor = [SKAccentColor() colorWithAlphaComponent:0.82];
    [timerColumn addArrangedSubview:self.focusEyebrow];
    self.phaseLabel = SKLabel(@"准备好时，开始这一刻", 20, NSFontWeightSemibold);
    self.phaseLabel.alignment = NSTextAlignmentCenter;
    [timerColumn addArrangedSubview:self.phaseLabel];
    [timerColumn setCustomSpacing:18 afterView:self.phaseLabel];

    NSView *timerStage = [NSView new];
    [timerStage.widthAnchor constraintEqualToConstant:252].active = YES;
    [timerStage.heightAnchor constraintEqualToConstant:252].active = YES;
    self.focusProgress = [SKProgressRingView new];
    self.focusProgress.translatesAutoresizingMaskIntoConstraints = NO;
    [timerStage addSubview:self.focusProgress];
    self.timerLabel = SKLabel(@"25:00", 66, NSFontWeightLight);
    self.timerLabel.font = [NSFont monospacedDigitSystemFontOfSize:70 weight:NSFontWeightLight];
    self.timerLabel.alignment = NSTextAlignmentCenter;
    self.timerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [timerStage addSubview:self.timerLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.focusProgress.leadingAnchor constraintEqualToAnchor:timerStage.leadingAnchor],
        [self.focusProgress.trailingAnchor constraintEqualToAnchor:timerStage.trailingAnchor],
        [self.focusProgress.topAnchor constraintEqualToAnchor:timerStage.topAnchor],
        [self.focusProgress.bottomAnchor constraintEqualToAnchor:timerStage.bottomAnchor],
        [self.timerLabel.centerXAnchor constraintEqualToAnchor:timerStage.centerXAnchor],
        [self.timerLabel.centerYAnchor constraintEqualToAnchor:timerStage.centerYAnchor]
    ]];
    [timerColumn addArrangedSubview:timerStage];

    NSStackView *controls = [NSStackView new];
    controls.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controls.spacing = 10;
    controls.alignment = NSLayoutAttributeCenterY;
    self.primaryButton = SKButton(@"开始", self, @selector(primaryTimerAction:));
    self.primaryButton.keyEquivalent = @"\r";
    self.primaryButton.bezelColor = SKAccentColor();
    [self.primaryButton.widthAnchor constraintEqualToConstant:150].active = YES;
    self.pauseButton = SKButton(@"暂停", self, @selector(pauseTimer:));
    self.endButton = SKButton(@"提前结束", self, @selector(endTimer:));
    self.endButton.bordered = NO;
    self.endButton.contentTintColor = NSColor.secondaryLabelColor;
    [controls addArrangedSubview:self.primaryButton];
    [controls addArrangedSubview:self.pauseButton];
    [controls addArrangedSubview:self.endButton];
    [timerColumn addArrangedSubview:controls];

    self.todayLabel = SKLabel(@"今日 0 🍅", 13, NSFontWeightMedium);
    self.todayLabel.textColor = NSColor.secondaryLabelColor;
    [timerColumn addArrangedSubview:self.todayLabel];

    self.focusSettingsCard = SKPanelBox(18);
    [self.focusSettingsCard.widthAnchor constraintEqualToConstant:300].active = YES;
    [self.focusSettingsCard.heightAnchor constraintEqualToConstant:402].active = YES;
    [layout addArrangedSubview:self.focusSettingsCard];
    NSStackView *settingsColumn = [NSStackView new];
    settingsColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    settingsColumn.alignment = NSLayoutAttributeLeading;
    settingsColumn.spacing = 10;
    settingsColumn.translatesAutoresizingMaskIntoConstraints = NO;
    [self.focusSettingsCard addSubview:settingsColumn];

    [settingsColumn addArrangedSubview:SKLabel(@"本轮设置", 20, NSFontWeightBold)];
    NSTextField *settingsSubtitle = SKLabel(@"只决定眼前这一轮，之后自动回到默认。", 11, NSFontWeightRegular);
    settingsSubtitle.textColor = NSColor.secondaryLabelColor;
    [settingsColumn addArrangedSubview:settingsSubtitle];
    [settingsColumn setCustomSpacing:18 afterView:settingsSubtitle];

    self.focusTaskLabel = SKLabel(@"关联任务", 11, NSFontWeightSemibold);
    self.focusTaskLabel.textColor = NSColor.secondaryLabelColor;
    [settingsColumn addArrangedSubview:self.focusTaskLabel];
    self.focusTaskPopup = [NSPopUpButton new];
    self.focusTaskPopup.controlSize = NSControlSizeLarge;
    self.focusTaskPopup.target = self;
    self.focusTaskPopup.action = @selector(focusTaskChanged:);
    [self.focusTaskPopup.widthAnchor constraintEqualToConstant:260].active = YES;
    [settingsColumn addArrangedSubview:self.focusTaskPopup];

    NSBox *separator = [NSBox new];
    separator.boxType = NSBoxSeparator;
    [separator.widthAnchor constraintEqualToConstant:260].active = YES;
    [settingsColumn addArrangedSubview:separator];
    [settingsColumn setCustomSpacing:14 afterView:separator];

    NSTextField *durationTitle = SKLabel(@"本轮时长", 11, NSFontWeightSemibold);
    durationTitle.textColor = NSColor.secondaryLabelColor;
    [settingsColumn addArrangedSubview:durationTitle];

    self.durationRow = [NSStackView new];
    self.durationRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.durationRow.alignment = NSLayoutAttributeCenterY;
    self.durationRow.spacing = 8;
    [self.durationRow addArrangedSubview:SKLabel(@"专注", 13, NSFontWeightRegular)];
    self.durationField = [NSTextField new];
    self.durationField.alignment = NSTextAlignmentCenter;
    self.durationField.stringValue = @"25";
    self.durationField.target = self;
    self.durationField.action = @selector(customDurationChanged:);
    [self.durationField.widthAnchor constraintEqualToConstant:58].active = YES;
    [self.durationRow addArrangedSubview:self.durationField];
    [self.durationRow addArrangedSubview:SKLabel(@"分钟", 13, NSFontWeightRegular)];
    self.focusUntilButton = SKButton(@"专注到…", self, @selector(focusUntilTime:));
    self.focusUntilButton.controlSize = NSControlSizeRegular;
    [self.durationRow addArrangedSubview:self.focusUntilButton];
    [settingsColumn addArrangedSubview:self.durationRow];

    self.durationPresets = [NSSegmentedControl segmentedControlWithLabels:@[@"15", @"20", @"25", @"30"]
                                                           trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                 target:self
                                                                 action:@selector(durationPresetChanged:)];
    self.durationPresets.controlSize = NSControlSizeRegular;
    [self.durationPresets.widthAnchor constraintEqualToConstant:260].active = YES;
    [settingsColumn addArrangedSubview:self.durationPresets];
    [settingsColumn setCustomSpacing:18 afterView:self.durationPresets];

    NSBox *hintBox = SKPanelBox(12);
    [hintBox.widthAnchor constraintEqualToConstant:260].active = YES;
    [settingsColumn addArrangedSubview:hintBox];
    self.focusHintLabel = SKLabel(@"需要提前停下？直接改成本轮可用分钟，下一轮仍使用默认时长。", 12, NSFontWeightRegular);
    self.focusHintLabel.textColor = NSColor.secondaryLabelColor;
    self.focusHintLabel.maximumNumberOfLines = 4;
    self.focusHintLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.focusHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [hintBox addSubview:self.focusHintLabel];

    [NSLayoutConstraint activateConstraints:@[
        [layout.centerXAnchor constraintEqualToAnchor:page.centerXAnchor],
        [layout.centerYAnchor constraintEqualToAnchor:page.centerYAnchor],
        [layout.widthAnchor constraintLessThanOrEqualToAnchor:page.widthAnchor constant:-52],
        [layout.heightAnchor constraintLessThanOrEqualToAnchor:page.heightAnchor constant:-34],
        [settingsColumn.leadingAnchor constraintEqualToAnchor:self.focusSettingsCard.leadingAnchor constant:20],
        [settingsColumn.trailingAnchor constraintEqualToAnchor:self.focusSettingsCard.trailingAnchor constant:-20],
        [settingsColumn.topAnchor constraintEqualToAnchor:self.focusSettingsCard.topAnchor constant:20],
        [self.focusHintLabel.leadingAnchor constraintEqualToAnchor:hintBox.leadingAnchor constant:14],
        [self.focusHintLabel.trailingAnchor constraintEqualToAnchor:hintBox.trailingAnchor constant:-14],
        [self.focusHintLabel.topAnchor constraintEqualToAnchor:hintBox.topAnchor constant:12],
        [self.focusHintLabel.bottomAnchor constraintEqualToAnchor:hintBox.bottomAnchor constant:-12]
    ]];
    return page;
}

- (NSView *)buildRecordsPage {
    NSView *page = [NSView new];
    NSTextField *title = SKLabel(@"真实发生的专注", 28, NSFontWeightBold);
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:title];
    self.recordsSummaryLabel = SKLabel(@"今天完成 0 个番茄", 14, NSFontWeightMedium);
    self.recordsSummaryLabel.textColor = NSColor.secondaryLabelColor;
    self.recordsSummaryLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.recordsSummaryLabel];

    NSStackView *metrics = [NSStackView new];
    metrics.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    metrics.spacing = 12;
    metrics.distribution = NSStackViewDistributionFillEqually;
    metrics.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:metrics];
    NSBox *countCard = SKPanelBox(14);
    NSStackView *countColumn = [NSStackView new];
    countColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    countColumn.alignment = NSLayoutAttributeLeading;
    countColumn.spacing = 3;
    NSTextField *countTitle = SKLabel(@"今日完成", 11, NSFontWeightSemibold);
    countTitle.textColor = NSColor.secondaryLabelColor;
    self.recordCountValue = SKLabel(@"0 个番茄", 20, NSFontWeightBold);
    [countColumn addArrangedSubview:countTitle];
    [countColumn addArrangedSubview:self.recordCountValue];
    countColumn.translatesAutoresizingMaskIntoConstraints = NO;
    [countCard addSubview:countColumn];
    [NSLayoutConstraint activateConstraints:@[
        [countColumn.leadingAnchor constraintEqualToAnchor:countCard.leadingAnchor constant:16],
        [countColumn.trailingAnchor constraintLessThanOrEqualToAnchor:countCard.trailingAnchor constant:-16],
        [countColumn.centerYAnchor constraintEqualToAnchor:countCard.centerYAnchor]
    ]];
    NSBox *timeCard = SKPanelBox(14);
    NSStackView *timeColumn = [NSStackView new];
    timeColumn.orientation = NSUserInterfaceLayoutOrientationVertical;
    timeColumn.alignment = NSLayoutAttributeLeading;
    timeColumn.spacing = 3;
    NSTextField *timeTitle = SKLabel(@"真实专注", 11, NSFontWeightSemibold);
    timeTitle.textColor = NSColor.secondaryLabelColor;
    self.recordTimeValue = SKLabel(@"0秒", 20, NSFontWeightBold);
    [timeColumn addArrangedSubview:timeTitle];
    [timeColumn addArrangedSubview:self.recordTimeValue];
    timeColumn.translatesAutoresizingMaskIntoConstraints = NO;
    [timeCard addSubview:timeColumn];
    [NSLayoutConstraint activateConstraints:@[
        [timeColumn.leadingAnchor constraintEqualToAnchor:timeCard.leadingAnchor constant:16],
        [timeColumn.trailingAnchor constraintLessThanOrEqualToAnchor:timeCard.trailingAnchor constant:-16],
        [timeColumn.centerYAnchor constraintEqualToAnchor:timeCard.centerYAnchor]
    ]];
    [metrics addArrangedSubview:countCard];
    [metrics addArrangedSubview:timeCard];

    self.recordMode = [NSSegmentedControl segmentedControlWithLabels:@[@"列表", @"周视图"]
                                                        trackingMode:NSSegmentSwitchTrackingSelectOne
                                                              target:self
                                                              action:@selector(recordModeChanged:)];
    self.recordMode.selectedSegment = 0;
    self.recordMode.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.recordMode];

    self.recordFilter = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [self.recordFilter addItemsWithTitles:@[@"全部记录", @"今天", @"本周", @"已完成", @"提前结束"]];
    self.recordFilter.target = self;
    self.recordFilter.action = @selector(recordFilterChanged:);
    self.recordFilter.controlSize = NSControlSizeRegular;
    self.recordFilter.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.recordFilter];

    NSButton *openCalendar = SKButton(@"打开日历", self, @selector(openCalendarWindow:));
    openCalendar.controlSize = NSControlSizeRegular;
    openCalendar.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:openCalendar];

    self.recordsTable = [NSTableView new];
    self.recordsTable.delegate = self;
    self.recordsTable.dataSource = self;
    self.recordsTable.target = self;
    self.recordsTable.doubleAction = @selector(editSelectedRecord:);
    self.recordsTable.rowHeight = 42;
    self.recordsTable.intercellSpacing = NSMakeSize(0, 3);
    NSTableColumn *time = [[NSTableColumn alloc] initWithIdentifier:@"time"];
    time.title = @"时间";
    time.width = 150;
    [self.recordsTable addTableColumn:time];
    NSTableColumn *content = [[NSTableColumn alloc] initWithIdentifier:@"content"];
    content.title = @"完成内容";
    content.width = 500;
    [self.recordsTable addTableColumn:content];
    NSTableColumn *duration = [[NSTableColumn alloc] initWithIdentifier:@"duration"];
    duration.title = @"专注";
    duration.width = 110;
    [self.recordsTable addTableColumn:duration];
    self.recordsScroll = [NSScrollView new];
    self.recordsScroll.documentView = self.recordsTable;
    self.recordsScroll.hasVerticalScroller = YES;
    SKStyleScrollView(self.recordsScroll);
    self.recordsScroll.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.recordsScroll];

    self.calendarView = [[SKWeekCalendarView alloc]
        initWithFrame:NSMakeRect(0, 0, 900, SKCalendarTimelineHeight())];
    self.calendarView.autoresizingMask = NSViewWidthSizable;
    __weak SKMainViewController *weakSelf = self;
    self.calendarView.recordSelectionHandler = ^(NSArray<SKFocusRecord *> *records) {
        [weakSelf presentCalendarRecords:records];
    };
    self.calendarScroll = [NSScrollView new];
    self.calendarScroll.documentView = self.calendarView;
    self.calendarScroll.hasVerticalScroller = YES;
    self.calendarScroll.hasHorizontalScroller = NO;
    self.calendarScroll.autohidesScrollers = YES;
    SKStyleScrollView(self.calendarScroll);
    self.calendarScroll.layer.borderWidth = 0;
    self.calendarScroll.layer.cornerRadius = 10;
    self.calendarScroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.calendarScroll.hidden = YES;
    [page addSubview:self.calendarScroll];

    self.recordActions = [NSStackView stackViewWithViews:@[
        SKButton(@"编辑记录", self, @selector(editSelectedRecord:)),
        SKButton(@"删除记录", self, @selector(deleteSelectedRecord:)),
        SKButton(@"回收站", self, @selector(openTrash:))
    ]];
    self.recordActions.spacing = 10;
    self.recordActions.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:self.recordActions];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:page.leadingAnchor constant:60],
        [title.topAnchor constraintEqualToAnchor:page.topAnchor constant:24],
        [self.recordsSummaryLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.recordsSummaryLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:7],
        [openCalendar.trailingAnchor constraintEqualToAnchor:page.trailingAnchor constant:-60],
        [openCalendar.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.recordMode.trailingAnchor constraintEqualToAnchor:openCalendar.leadingAnchor constant:-10],
        [self.recordMode.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.recordFilter.trailingAnchor constraintEqualToAnchor:self.recordMode.leadingAnchor constant:-10],
        [self.recordFilter.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [self.recordsScroll.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.recordsScroll.trailingAnchor constraintEqualToAnchor:self.recordMode.trailingAnchor],
        [metrics.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [metrics.trailingAnchor constraintEqualToAnchor:openCalendar.trailingAnchor],
        [metrics.topAnchor constraintEqualToAnchor:self.recordsSummaryLabel.bottomAnchor constant:14],
        [metrics.heightAnchor constraintEqualToConstant:72],
        [self.recordsScroll.topAnchor constraintEqualToAnchor:metrics.bottomAnchor constant:14],
        [self.recordsScroll.bottomAnchor constraintEqualToAnchor:self.recordActions.topAnchor constant:-12],
        [self.recordActions.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.recordActions.bottomAnchor constraintEqualToAnchor:page.bottomAnchor constant:-22],
        [self.calendarScroll.leadingAnchor constraintEqualToAnchor:self.recordsScroll.leadingAnchor],
        [self.calendarScroll.trailingAnchor constraintEqualToAnchor:self.recordsScroll.trailingAnchor],
        [self.calendarScroll.topAnchor constraintEqualToAnchor:self.recordsScroll.topAnchor],
        [self.calendarScroll.bottomAnchor constraintEqualToAnchor:self.recordsScroll.bottomAnchor]
    ]];
    return page;
}

- (NSView *)buildSettingsPage {
    NSView *page = [NSView new];
    NSTextField *title = SKLabel(@"设置", 28, NSFontWeightBold);
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:title];

    NSStackView *column = [NSStackView new];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.spacing = 10;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [page addSubview:column];

    NSTextField *displayTitle = SKLabel(@"状态栏与启动", 15, NSFontWeightSemibold);
    [column addArrangedSubview:displayTitle];
    self.countdownCheckbox = [NSButton checkboxWithTitle:@"在顶部状态栏持续显示剩余时间"
                                                   target:self
                                                   action:@selector(appearanceSettingChanged:)];
    [column addArrangedSubview:self.countdownCheckbox];
    NSTextField *menuPositionHint = SKLabel(@"位置由 macOS 管理：按住 ⌘ 拖动图标，可将它移到右侧并保留位置。",
                                            10, NSFontWeightRegular);
    menuPositionHint.textColor = NSColor.tertiaryLabelColor;
    [column addArrangedSubview:menuPositionHint];
    self.dockCheckbox = [NSButton checkboxWithTitle:@"同时在 Dock 中显示拾刻"
                                              target:self
                                              action:@selector(appearanceSettingChanged:)];
    [column addArrangedSubview:self.dockCheckbox];
    self.launchCheckbox = [NSButton checkboxWithTitle:@"登录 Mac 后自动启动拾刻"
                                                target:self
                                                action:@selector(behaviorSettingChanged:)];
    [column addArrangedSubview:self.launchCheckbox];
    [column setCustomSpacing:20 afterView:self.launchCheckbox];

    NSTextField *timerTitle = SKLabel(@"番茄与休息", 15, NSFontWeightSemibold);
    [column addArrangedSubview:timerTitle];
    NSStackView *timerRules = [NSStackView new];
    timerRules.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    timerRules.spacing = 12;
    NSStackView *defaultWorkItem = [NSStackView new];
    defaultWorkItem.orientation = NSUserInterfaceLayoutOrientationVertical;
    defaultWorkItem.alignment = NSLayoutAttributeLeading;
    defaultWorkItem.spacing = 4;
    NSTextField *defaultWorkLabel = SKLabel(@"默认专注", 11, NSFontWeightMedium);
    defaultWorkLabel.textColor = NSColor.secondaryLabelColor;
    [defaultWorkItem addArrangedSubview:defaultWorkLabel];
    self.defaultWorkPopup = [NSPopUpButton new];
    [self.defaultWorkPopup addItemsWithTitles:@[@"15", @"20", @"25", @"30", @"45", @"50", @"60"]];
    self.defaultWorkPopup.target = self;
    self.defaultWorkPopup.action = @selector(timerSettingChanged:);
    [self.defaultWorkPopup.widthAnchor constraintEqualToConstant:92].active = YES;
    [defaultWorkItem addArrangedSubview:self.defaultWorkPopup];
    [timerRules addArrangedSubview:defaultWorkItem];
    [column addArrangedSubview:timerRules];
    NSTextField *breakRule = SKLabel(@"每轮休息只按刚结束的专注时长 1/5 计算：25 分钟休息 5 分钟，5 分钟休息 1 分钟，不跨天累计轮次。",
                                    11, NSFontWeightRegular);
    breakRule.textColor = NSColor.secondaryLabelColor;
    [column addArrangedSubview:breakRule];
    [column setCustomSpacing:20 afterView:breakRule];

    NSTextField *behaviorTitle = SKLabel(@"提醒与记录", 15, NSFontWeightSemibold);
    [column addArrangedSubview:behaviorTitle];
    self.popupNotificationsCheckbox = [NSButton checkboxWithTitle:@"计时结束时显示系统通知"
                                                            target:self
                                                            action:@selector(behaviorSettingChanged:)];
    NSStackView *notificationRow = [NSStackView new];
    notificationRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    notificationRow.alignment = NSLayoutAttributeCenterY;
    notificationRow.spacing = 10;
    [notificationRow addArrangedSubview:self.popupNotificationsCheckbox];
    self.notificationStatusLabel = SKLabel(@"正在检查权限…", 11, NSFontWeightMedium);
    self.notificationStatusLabel.textColor = NSColor.secondaryLabelColor;
    [notificationRow addArrangedSubview:self.notificationStatusLabel];
    self.notificationPermissionButton = SKButton(@"处理", self, @selector(notificationPermissionAction:));
    self.notificationPermissionButton.controlSize = NSControlSizeSmall;
    [notificationRow addArrangedSubview:self.notificationPermissionButton];
    [column addArrangedSubview:notificationRow];
    self.interruptionReasonCheckbox = [NSButton checkboxWithTitle:@"提前结束时询问原因"
                                                            target:self
                                                            action:@selector(behaviorSettingChanged:)];
    [column addArrangedSubview:self.interruptionReasonCheckbox];
    [column setCustomSpacing:20 afterView:self.interruptionReasonCheckbox];

    NSTextField *soundTitle = SKLabel(@"完成提醒", 15, NSFontWeightSemibold);
    [column addArrangedSubview:soundTitle];
    self.soundCheckbox = [NSButton checkboxWithTitle:@"专注完成时播放提醒音"
                                             target:self
                                             action:@selector(soundSettingChanged:)];
    [column addArrangedSubview:self.soundCheckbox];

    NSStackView *soundRow = [NSStackView new];
    soundRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    soundRow.alignment = NSLayoutAttributeCenterY;
    soundRow.spacing = 12;
    [soundRow addArrangedSubview:SKLabel(@"提醒音", 13, NSFontWeightMedium)];
    self.soundPopup = [NSPopUpButton new];
    [self.soundPopup addItemsWithTitles:@[@"Glass", @"Ping", @"Submarine"]];
    self.soundPopup.target = self;
    self.soundPopup.action = @selector(soundSettingChanged:);
    [soundRow addArrangedSubview:self.soundPopup];
    NSButton *preview = SKButton(@"试听", self, @selector(previewSound:));
    [soundRow addArrangedSubview:preview];
    [column addArrangedSubview:soundRow];

    NSStackView *volumeRow = [NSStackView new];
    volumeRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    volumeRow.alignment = NSLayoutAttributeCenterY;
    volumeRow.spacing = 12;
    [volumeRow addArrangedSubview:SKLabel(@"音量", 13, NSFontWeightMedium)];
    self.volumeSlider = [NSSlider sliderWithValue:0.75
                                         minValue:0
                                         maxValue:1
                                           target:self
                                           action:@selector(soundSettingChanged:)];
    [self.volumeSlider.widthAnchor constraintEqualToConstant:220].active = YES;
    [volumeRow addArrangedSubview:self.volumeSlider];
    [column addArrangedSubview:volumeRow];

    NSBox *ruleBox = SKPanelBox(12);
    ruleBox.translatesAutoresizingMaskIntoConstraints = NO;
    [column addArrangedSubview:ruleBox];
    NSTextField *rule = SKLabel(@"超过 3 小时未有效专注时，拾刻会先邀请你做 5 分钟；\n填写日志后自动休息 1 分钟，再由你决定是否开始下一轮。", 14, NSFontWeightRegular);
    rule.maximumNumberOfLines = 3;
    rule.translatesAutoresizingMaskIntoConstraints = NO;
    [ruleBox addSubview:rule];
    [NSLayoutConstraint activateConstraints:@[
        [rule.leadingAnchor constraintEqualToAnchor:ruleBox.leadingAnchor constant:18],
        [rule.trailingAnchor constraintEqualToAnchor:ruleBox.trailingAnchor constant:-18],
        [rule.topAnchor constraintEqualToAnchor:ruleBox.topAnchor constant:16],
        [rule.bottomAnchor constraintEqualToAnchor:ruleBox.bottomAnchor constant:-16],
        [ruleBox.widthAnchor constraintEqualToConstant:520]
    ]];

    NSTextField *privacy = SKLabel(@"数据只保存在这台 Mac 上，不需要登录，也不会上传专注内容。", 12, NSFontWeightRegular);
    privacy.textColor = NSColor.secondaryLabelColor;
    [column addArrangedSubview:privacy];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:page.leadingAnchor constant:70],
        [title.topAnchor constraintEqualToAnchor:page.topAnchor constant:26],
        [column.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [column.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:20],
        [column.bottomAnchor constraintLessThanOrEqualToAnchor:page.bottomAnchor constant:-22]
    ]];
    return page;
}

- (void)navigationChanged:(id)sender {
    [self showPage:self.navigation.selectedSegment];
}

- (void)showPage:(NSInteger)index {
    for (NSInteger i = 0; i < (NSInteger)self.pages.count; i++) self.pages[i].hidden = i != index;
    self.navigation.selectedSegment = index;
    if (index == 1) [self refreshFocus];
    if (index == 2) [self refreshRecords];
}

- (void)refreshAll {
    [self refreshTasks];
    [self refreshTaskPopup];
    [self refreshFocus];
    [self refreshRecords];
    self.soundCheckbox.state = self.store.soundEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.countdownCheckbox.state = self.store.showCountdownInMenuBar ? NSControlStateValueOn : NSControlStateValueOff;
    self.dockCheckbox.state = self.store.showDockIcon ? NSControlStateValueOn : NSControlStateValueOff;
    self.launchCheckbox.state = SMAppService.mainAppService.status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.popupNotificationsCheckbox.state = self.store.popupNotifications ? NSControlStateValueOn : NSControlStateValueOff;
    self.interruptionReasonCheckbox.state = self.store.recordInterruptionReason ? NSControlStateValueOn : NSControlStateValueOff;
    [self.defaultWorkPopup selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)self.store.defaultWorkMinutes]];
    [self.soundPopup selectItemWithTitle:self.store.selectedSoundName ?: @"Glass"];
    self.volumeSlider.doubleValue = self.store.soundVolume;
    [self refreshNotificationAuthorization];
}

- (void)refreshTasks {
    [self.taskTable reloadData];
    self.taskEmptyLabel.hidden = self.store.activeTasks.count > 0;
}

- (void)refreshTaskPopup {
    NSString *selected = self.store.selectedTaskID;
    [self.focusTaskPopup removeAllItems];
    [self.focusTaskPopup addItemWithTitle:@"不关联任务"];
    self.focusTaskPopup.lastItem.representedObject = [NSNull null];
    for (SKTask *task in self.store.activeTasks) {
        if (task.completedAt) continue;
        [self.focusTaskPopup addItemWithTitle:task.title];
        self.focusTaskPopup.lastItem.representedObject = task.identifier;
    }
    NSInteger index = 0;
    for (NSInteger i = 0; i < self.focusTaskPopup.numberOfItems; i++) {
        id represented = [self.focusTaskPopup itemAtIndex:i].representedObject;
        if ([represented isKindOfClass:NSString.class] && [represented isEqualToString:selected]) {
            index = i;
            break;
        }
    }
    [self.focusTaskPopup selectItemAtIndex:index];
}

- (void)refreshFocus {
    NSDate *now = NSDate.date;
    NSInteger remaining = [self.engine remainingSecondsAtDate:now];
    self.timerLabel.stringValue = SKClockText(remaining);
    self.todayLabel.stringValue = [NSString stringWithFormat:@"今日 %ld 🍅 · %@",
                                  (long)[self.store todayTomatoCountAtDate:now],
                                  SKDurationText([self.store todayFocusSecondsAtDate:now])];

    BOOL ready = [self.engine.phase isEqualToString:SKTimerPhaseReady];
    BOOL running = [self.engine.phase isEqualToString:SKTimerPhaseRunning];
    BOOL paused = [self.engine.phase isEqualToString:SKTimerPhasePaused];
    BOOL transition = [self.engine.phase isEqualToString:SKTimerPhaseTransition];
    BOOL breakSession = !self.engine.isWorkSession;
    BOOL quietPresentation = SKFocusUsesQuietPresentation(self.engine.phase,
                                                           self.engine.isWorkSession);

    self.focusSettingsCard.hidden = quietPresentation;
    self.todayLabel.hidden = quietPresentation;
    self.focusEyebrow.stringValue = breakSession ?
        ([self.engine.sessionKind isEqualToString:SKSessionKindLongBreak] ? @"长休息" : @"短休息") :
        (ready ? @"当前这一刻" : @"只做这一件事");

    CGFloat planned = MAX(1, self.engine.plannedSeconds);
    self.focusProgress.progress = ready ? 0 : (planned - remaining) / planned;
    self.focusProgress.progressColor = breakSession ?
                                       [NSColor colorWithSRGBRed:0.40 green:0.59 blue:0.60 alpha:1.0] :
                                       (paused ? NSColor.systemOrangeColor : SKAccentColor());

    if (ready) {
        if (breakSession) {
            self.phaseLabel.stringValue = [self.engine.sessionKind isEqualToString:SKSessionKindLongBreak] ?
                @"准备好就离开屏幕" : @"准备好就离开屏幕";
        } else if ([self.engine.sessionKind isEqualToString:SKSessionKindStarter]) {
            self.phaseLabel.stringValue = @"先做五分钟";
        } else if ([self.engine.sessionKind isEqualToString:SKSessionKindCustom]) {
            self.phaseLabel.stringValue = @"这一次，按你的时间来";
        } else {
            self.phaseLabel.stringValue = @"准备好时，再来一轮";
        }
    } else if (running) {
        if (breakSession) {
            NSTimeInterval restAge = self.restStartedAt ? [now timeIntervalSinceDate:self.restStartedAt] : 3;
            self.phaseLabel.stringValue = SKRestHeadline(restAge);
        } else if (self.engine.taskTitle.length) {
            self.phaseLabel.stringValue = self.engine.taskTitle;
        } else {
            self.phaseLabel.stringValue = @"正在专注";
        }
    } else if (paused) {
        self.phaseLabel.stringValue = breakSession ? @"休息已暂停" : @"已经暂停，回来就好";
    } else if (transition) {
        self.phaseLabel.stringValue = @"很好，已经开始了。30秒后继续";
    }

    if (breakSession) {
        self.focusHintLabel.stringValue = @"休息不会计入专注。起身、喝水、看看远处。";
    } else if ([self.engine.sessionKind isEqualToString:SKSessionKindStarter]) {
        self.focusHintLabel.stringValue = @"五分钟只是启动门槛。填写日志后会自动休息 1 分钟，再由你决定是否继续。";
    } else if ([self.engine.sessionKind isEqualToString:SKSessionKindCustom]) {
        self.focusHintLabel.stringValue = @"这个时长只影响当前一轮。完成或放弃后，会自动回到默认专注时长。";
    } else {
        self.focusHintLabel.stringValue = @"需要提前停下？直接改成本轮可用分钟，下一轮仍使用默认时长。";
    }

    id fieldEditor = self.durationField.currentEditor;
    BOOL editingDuration = fieldEditor && self.view.window.firstResponder == fieldEditor;
    if (!editingDuration) {
        self.durationField.integerValue = MAX(1, self.engine.plannedSeconds / 60);
    }
    self.durationRow.hidden = breakSession;
    self.durationPresets.hidden = breakSession;
    self.durationField.enabled = ready && !breakSession;
    self.durationPresets.enabled = ready && !breakSession;
    self.focusUntilButton.enabled = ready && !breakSession;
    NSInteger minutes = MAX(1, self.engine.plannedSeconds / 60);
    NSArray *presetValues = @[@15, @20, @25, @30];
    self.durationPresets.selectedSegment = -1;
    for (NSInteger i = 0; i < (NSInteger)presetValues.count; i++) {
        if ([presetValues[i] integerValue] == minutes) self.durationPresets.selectedSegment = i;
    }
    self.focusTaskPopup.enabled = ready && !breakSession;
    self.primaryButton.hidden = running || transition;
    self.primaryButton.title = paused ? @"继续" : (breakSession ? @"开始休息" : @"开始");
    self.pauseButton.hidden = !running;
    self.pauseButton.bezelColor = running ? SKAccentColor() : nil;
    self.endButton.hidden = ready && !breakSession;
    self.endButton.title = transition ? @"暂不继续" : (ready && breakSession ? @"跳过休息" : @"提前结束");
}

- (void)refreshRecords {
    NSDate *now = NSDate.date;
    NSInteger tomatoes = [self.store todayTomatoCountAtDate:now];
    NSInteger seconds = [self.store todayFocusSecondsAtDate:now];
    self.recordsSummaryLabel.stringValue =
        [NSString stringWithFormat:@"今天完成 %ld 个番茄 · 专注 %@", (long)tomatoes, SKDurationText(seconds)];
    self.recordCountValue.stringValue = [NSString stringWithFormat:@"%ld 个番茄", (long)tomatoes];
    self.recordTimeValue.stringValue = SKDurationText(seconds);
    [self.recordsTable reloadData];
    self.calendarView.records = self.visibleRecords;
}

- (NSArray<SKFocusRecord *> *)visibleRecords {
    NSArray<SKFocusRecord *> *records = self.store.activeRecords;
    NSInteger filter = self.recordFilter.indexOfSelectedItem;
    if (filter <= 0) return records;
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *now = NSDate.date;
    NSDate *weekStart = SKMondayStartOfWeek(calendar, now);
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SKFocusRecord *record, NSDictionary *bindings) {
        if (filter == 1) return [calendar isDate:record.endedAt inSameDayAsDate:now];
        if (filter == 2) return [record.endedAt compare:weekStart] != NSOrderedAscending;
        if (filter == 3) return [record.status isEqualToString:@"completed"];
        return [record.status isEqualToString:@"aborted"];
    }];
    return [records filteredArrayUsingPredicate:predicate];
}

- (void)prepareDefaultSessionForceStandard:(BOOL)forceStandard {
    self.restStartedAt = nil;
    NSDate *now = NSDate.date;
    BOOL stale = !self.store.lastMeaningfulFocusAt ||
                 [now timeIntervalSinceDate:self.store.lastMeaningfulFocusAt] >= 3 * 60 * 60;
    SKSessionKind kind = (!forceStandard && stale) ? SKSessionKindStarter : SKSessionKindStandard;
    NSInteger duration = [kind isEqualToString:SKSessionKindStarter] ? 300 : self.store.defaultWorkMinutes * 60;
    SKTask *task = self.store.selectedTask;
    NSString *chain = [kind isEqualToString:SKSessionKindStarter] ? NSUUID.UUID.UUIDString : nil;
    [self.engine prepareSessionKind:kind
                    durationSeconds:duration
                             taskID:task.identifier
                          taskTitle:task.title
                            chainID:chain];
    [self persistTimer];
}

- (void)persistTimer {
    [self updateTimerResponsivenessActivity];
    BOOL readyBreak = [self.engine.phase isEqualToString:SKTimerPhaseReady] && !self.engine.isWorkSession;
    self.store.activeTimerSnapshot = ([self.engine.phase isEqualToString:SKTimerPhaseReady] && !readyBreak) ?
        nil : self.engine.dictionaryRepresentation;
    [self.store save:nil];
}

- (void)updateTimerResponsivenessActivity {
    BOOL needsActivity = SKTimerPhaseNeedsResponsiveActivity(self.engine.phase);
    if (needsActivity && !self.timerResponsivenessActivity) {
        self.timerResponsivenessActivity = [NSProcessInfo.processInfo
            beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep
                              reason:@"保持拾刻倒计时与到点提醒准时响应"];
    } else if (!needsActivity && self.timerResponsivenessActivity) {
        [NSProcessInfo.processInfo endActivity:self.timerResponsivenessActivity];
        self.timerResponsivenessActivity = nil;
    }
}

- (void)syncPreparedTaskFromSelection {
    if (![self.engine.phase isEqualToString:SKTimerPhaseReady] || !self.engine.isWorkSession) return;
    SKTask *task = self.store.selectedTask;
    [self.engine prepareSessionKind:self.engine.sessionKind
                    durationSeconds:self.engine.plannedSeconds
                             taskID:task.identifier
                          taskTitle:task.title
                            chainID:self.engine.chainID];
    [self persistTimer];
}

- (void)addTask:(id)sender {
    NSString *title = [self.taskInputField.stringValue stringByTrimmingCharactersInSet:
                       NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0) {
        NSBeep();
        return;
    }
    SKTask *task = [self.store addTaskWithTitle:title];
    self.taskInputField.stringValue = @"";
    [self refreshTasks];
    NSUInteger taskIndex = [self.store.activeTasks indexOfObjectIdenticalTo:task];
    if (taskIndex != NSNotFound) {
        [self.taskTable selectRowIndexes:[NSIndexSet indexSetWithIndex:taskIndex] byExtendingSelection:NO];
    }
    [self refreshTaskPopup];
    [self syncPreparedTaskFromSelection];
    [self refreshFocus];
}

- (void)deleteTask:(id)sender {
    NSArray<SKTask *> *active = self.store.activeTasks;
    NSInteger row = self.taskTable.selectedRow;
    if (row < 0 || row >= (NSInteger)active.count) return;
    SKTask *task = active[(NSUInteger)row];
    [[UNUserNotificationCenter currentNotificationCenter]
        removePendingNotificationRequestsWithIdentifiers:@[[self reminderIdentifierForTask:task]]];
    [self.store deleteTask:task];
    [self refreshTasks];
    [self refreshTaskPopup];
    [self syncPreparedTaskFromSelection];
    [self refreshFocus];
}

- (void)openTaskDetails:(id)sender {
    NSInteger row = self.taskTable.selectedRow;
    NSArray<SKTask *> *active = self.store.activeTasks;
    if (row < 0 || row >= (NSInteger)active.count) { NSBeep(); return; }
    SKTask *task = active[(NSUInteger)row];

    NSAlert *alert = [NSAlert new];
    alert.messageText = @"任务详情";
    alert.informativeText = @"把下一步写清楚，开始时就不用再想。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"取消"];
    NSView *form = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 470, 382)];

    NSTextField *(^caption)(NSString *, CGFloat) = ^NSTextField *(NSString *text, CGFloat y) {
        NSTextField *label = SKLabel(text, 11, NSFontWeightSemibold);
        label.textColor = NSColor.secondaryLabelColor;
        label.frame = NSMakeRect(0, y, 100, 18);
        [form addSubview:label];
        return label;
    };
    caption(@"任务名称", 354);
    NSTextField *titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(104, 348, 366, 28)];
    titleField.stringValue = task.title ?: @"";
    [form addSubview:titleField];

    NSButton *pinned = [NSButton checkboxWithTitle:@"置顶" target:nil action:nil];
    pinned.frame = NSMakeRect(104, 312, 72, 24);
    pinned.state = task.pinned ? NSControlStateValueOn : NSControlStateValueOff;
    [form addSubview:pinned];
    caption(@"预计番茄", 315);
    NSTextField *estimate = [[NSTextField alloc] initWithFrame:NSMakeRect(260, 309, 58, 28)];
    estimate.integerValue = task.estimatedPomos;
    estimate.alignment = NSTextAlignmentCenter;
    [form addSubview:estimate];
    NSStepper *stepper = [[NSStepper alloc] initWithFrame:NSMakeRect(322, 309, 20, 28)];
    stepper.minValue = 0; stepper.maxValue = 99; stepper.integerValue = task.estimatedPomos;
    stepper.target = estimate; stepper.action = @selector(takeIntegerValueFrom:);
    [form addSubview:stepper];

    caption(@"标签", 273);
    NSTextField *tags = [[NSTextField alloc] initWithFrame:NSMakeRect(104, 267, 366, 28)];
    tags.placeholderString = @"例如：工作, 深度思考";
    tags.stringValue = [task.tags componentsJoinedByString:@", "] ?: @"";
    [form addSubview:tags];

    caption(@"重复", 231);
    NSPopUpButton *repeat = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(104, 225, 150, 28) pullsDown:NO];
    [repeat addItemsWithTitles:@[@"不重复", @"每天", @"每周", @"每月"]];
    NSDictionary *repeatIndexes = @{@"none": @0, @"daily": @1, @"weekly": @2, @"monthly": @3};
    [repeat selectItemAtIndex:[repeatIndexes[task.repeatRule ?: @"none"] integerValue]];
    [form addSubview:repeat];
    NSButton *remind = [NSButton checkboxWithTitle:@"提醒" target:nil action:nil];
    remind.frame = NSMakeRect(270, 227, 66, 24);
    remind.state = task.reminderAt ? NSControlStateValueOn : NSControlStateValueOff;
    [form addSubview:remind];
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(336, 225, 134, 28)];
    picker.datePickerElements = NSDatePickerElementFlagYearMonthDay | NSDatePickerElementFlagHourMinute;
    picker.dateValue = task.reminderAt ?: [NSDate dateWithTimeIntervalSinceNow:3600];
    [form addSubview:picker];

    caption(@"备注", 185);
    NSScrollView *noteScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(104, 137, 366, 66)];
    noteScroll.borderType = NSBezelBorder; noteScroll.hasVerticalScroller = YES;
    NSTextView *note = [[NSTextView alloc] initWithFrame:noteScroll.bounds];
    note.font = [NSFont systemFontOfSize:13]; note.string = task.note ?: @"";
    noteScroll.documentView = note; [form addSubview:noteScroll];

    caption(@"子任务", 108);
    NSScrollView *subtaskScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(104, 20, 366, 102)];
    subtaskScroll.borderType = NSBezelBorder; subtaskScroll.hasVerticalScroller = YES;
    NSTextView *subtasks = [[NSTextView alloc] initWithFrame:subtaskScroll.bounds];
    subtasks.font = [NSFont systemFontOfSize:13];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (SKSubtask *item in task.subtasks) {
        [lines addObject:[NSString stringWithFormat:@"[%@] %@", item.completed ? @"x" : @" ", item.title]];
    }
    subtasks.string = [lines componentsJoinedByString:@"\n"];
    subtaskScroll.documentView = subtasks; [form addSubview:subtaskScroll];
    NSTextField *tip = SKLabel(@"每行一个；用 [x] 标记完成", 10, NSFontWeightRegular);
    tip.textColor = NSColor.tertiaryLabelColor; tip.frame = NSMakeRect(0, 1, 190, 16); [form addSubview:tip];
    alert.accessoryView = form;
    if ([alert runModal] != NSAlertFirstButtonReturn) return;

    NSString *newTitle = [titleField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (newTitle.length) task.title = newTitle;
    task.pinned = pinned.state == NSControlStateValueOn;
    task.estimatedPomos = MAX(0, estimate.integerValue);
    NSString *noteText = [note.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    task.note = noteText.length ? noteText : nil;
    NSMutableArray<NSString *> *cleanTags = [NSMutableArray array];
    for (NSString *raw in [tags.stringValue componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",，"]]) {
        NSString *tag = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (tag.length && ![cleanTags containsObject:tag]) [cleanTags addObject:tag];
    }
    task.tags = cleanTags;
    task.repeatRule = @[@"none", @"daily", @"weekly", @"monthly"][(NSUInteger)repeat.indexOfSelectedItem];
    task.reminderAt = remind.state == NSControlStateValueOn ? picker.dateValue : nil;
    [task.subtasks removeAllObjects];
    NSInteger order = 0;
    for (NSString *raw in [subtasks.string componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (!line.length) continue;
        BOOL done = [line hasPrefix:@"[x]"] || [line hasPrefix:@"[X]"];
        if ([line hasPrefix:@"[x]"] || [line hasPrefix:@"[X]"] || [line hasPrefix:@"[ ]"]) {
            line = [[line substringFromIndex:3] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        }
        if (!line.length) continue;
        SKSubtask *item = [SKSubtask subtaskWithTitle:line sortOrder:order++];
        item.completed = done;
        [task.subtasks addObject:item];
    }
    [self.store save:nil];
    [self syncReminderForTask:task];
    [self refreshTasks];
    [self refreshTaskPopup];
    [self syncPreparedTaskFromSelection];
    [self refreshFocus];
}

- (void)moveTaskUp:(id)sender {
    NSInteger row = self.taskTable.selectedRow;
    if (row <= 0) return;
    SKTask *task = self.store.activeTasks[(NSUInteger)row];
    [self.store moveTaskAtIndex:(NSUInteger)row byOffset:-1];
    [self.taskTable reloadData];
    NSUInteger newIndex = [self.store.activeTasks indexOfObjectIdenticalTo:task];
    if (newIndex != NSNotFound) [self.taskTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newIndex]
                                            byExtendingSelection:NO];
}

- (void)moveTaskDown:(id)sender {
    NSInteger row = self.taskTable.selectedRow;
    if (row < 0 || row >= (NSInteger)self.store.activeTasks.count - 1) return;
    SKTask *task = self.store.activeTasks[(NSUInteger)row];
    [self.store moveTaskAtIndex:(NSUInteger)row byOffset:1];
    [self.taskTable reloadData];
    NSUInteger newIndex = [self.store.activeTasks indexOfObjectIdenticalTo:task];
    if (newIndex != NSNotFound) [self.taskTable selectRowIndexes:[NSIndexSet indexSetWithIndex:newIndex]
                                            byExtendingSelection:NO];
}

- (void)focusSelectedTask:(id)sender {
    NSArray<SKTask *> *active = self.store.activeTasks;
    NSInteger row = self.taskTable.selectedRow;
    if (row >= 0 && row < (NSInteger)active.count) {
        SKTask *task = active[(NSUInteger)row];
        self.store.selectedTaskID = task.identifier;
        [self.store save:nil];
        [self refreshTaskPopup];
        [self syncPreparedTaskFromSelection];
    }
    [self showPage:1];
}

- (void)taskDoneChanged:(NSButton *)sender {
    NSArray<SKTask *> *active = self.store.activeTasks;
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)active.count) return;
    SKTask *task = active[(NSUInteger)row];
    task.completedAt = sender.state == NSControlStateValueOn ? NSDate.date : nil;
    if (task.completedAt) {
#if !SHIKE_TESTING
        [[UNUserNotificationCenter currentNotificationCenter]
            removePendingNotificationRequestsWithIdentifiers:@[[self reminderIdentifierForTask:task]]];
#endif
        if ([self.store.selectedTaskID isEqualToString:task.identifier]) self.store.selectedTaskID = nil;
    } else {
        [self syncReminderForTask:task];
    }
    [self.store save:nil];
    [self.taskTable reloadData];
    if (task.completedAt) {
        [self.taskTable deselectAll:nil];
    } else {
        [self.taskTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                    byExtendingSelection:NO];
    }
    [self refreshTaskPopup];
    [self syncPreparedTaskFromSelection];
    [self refreshFocus];
}

- (void)taskTitleChanged:(NSTextField *)sender {
    NSArray<SKTask *> *active = self.store.activeTasks;
    NSInteger row = sender.tag;
    if (row < 0 || row >= (NSInteger)active.count) return;
    NSString *title = [sender.stringValue stringByTrimmingCharactersInSet:
                       NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0) {
        [self.taskTable reloadData];
        return;
    }
    active[(NSUInteger)row].title = title;
    [self.store save:nil];
    [self refreshTaskPopup];
    if ([self.store.selectedTaskID isEqualToString:active[(NSUInteger)row].identifier]) {
        [self syncPreparedTaskFromSelection];
        [self refreshFocus];
    }
}

- (void)focusTaskChanged:(id)sender {
    id represented = self.focusTaskPopup.selectedItem.representedObject;
    self.store.selectedTaskID = [represented isKindOfClass:NSString.class] ? represented : nil;
    [self.store save:nil];
    [self syncPreparedTaskFromSelection];
    [self refreshFocus];
}

- (void)customDurationChanged:(id)sender {
    if (![self.engine.phase isEqualToString:SKTimerPhaseReady] || !self.engine.isWorkSession) return;
    NSInteger minutes = MIN(180, MAX(1, self.durationField.integerValue));
    self.durationField.integerValue = minutes;
    SKTask *task = self.store.selectedTask;
    [self.engine prepareSessionKind:SKSessionKindCustom
                    durationSeconds:minutes * 60
                             taskID:task.identifier
                          taskTitle:task.title
                            chainID:nil];
    [self refreshFocus];
}

- (void)durationPresetChanged:(NSSegmentedControl *)sender {
    if (sender.selectedSegment < 0) return;
    NSArray *values = @[@15, @20, @25, @30];
    self.durationField.integerValue = [values[(NSUInteger)sender.selectedSegment] integerValue];
    [self customDurationChanged:self.durationField];
}

- (void)statusPresetMinutes:(NSInteger)minutes {
    if (![self.engine.phase isEqualToString:SKTimerPhaseReady]) return;
    self.durationField.integerValue = MIN(180, MAX(1, minutes));
    [self customDurationChanged:self.durationField];
}

- (void)focusUntilTime:(id)sender {
    if (![self.engine.phase isEqualToString:SKTimerPhaseReady]) return;
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"这一轮专注到几点？";
    alert.informativeText = @"只影响当前这一轮，结束或放弃后会恢复25分钟。";
    [alert addButtonWithTitle:@"使用这个时间"];
    [alert addButtonWithTitle:@"取消"];
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(0, 0, 180, 28)];
    picker.datePickerElements = NSDatePickerElementFlagHourMinute;
    picker.dateValue = [NSDate dateWithTimeIntervalSinceNow:20 * 60];
    alert.accessoryView = picker;
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *now = NSDate.date;
    NSDateComponents *time = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:picker.dateValue];
    NSDateComponents *today = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:now];
    today.hour = time.hour;
    today.minute = time.minute;
    NSDate *target = [calendar dateFromComponents:today];
    if ([target compare:now] != NSOrderedDescending) {
        target = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:target options:0];
    }
    NSInteger minutes = MIN(180, MAX(1, (NSInteger)ceil([target timeIntervalSinceDate:now] / 60.0)));
    self.durationField.integerValue = minutes;
    [self customDurationChanged:self.durationField];
}

- (void)primaryTimerAction:(id)sender {
    NSDate *now = NSDate.date;
    if ([self.engine.phase isEqualToString:SKTimerPhaseReady]) {
        if (self.engine.isWorkSession) self.restStartedAt = nil;
        else self.restStartedAt = now;
        SKTask *task = self.store.selectedTask;
        NSInteger enteredMinutes = MIN(180, MAX(1, self.durationField.integerValue));
        if (self.engine.isWorkSession && enteredMinutes * 60 != self.engine.plannedSeconds) {
            [self.engine prepareSessionKind:SKSessionKindCustom
                            durationSeconds:enteredMinutes * 60
                                     taskID:task.identifier
                                  taskTitle:task.title
                                    chainID:nil];
        }
        [self.engine prepareSessionKind:self.engine.sessionKind
                        durationSeconds:self.engine.plannedSeconds
                                 taskID:self.engine.isWorkSession ? task.identifier : self.engine.taskID
                              taskTitle:self.engine.isWorkSession ? task.title : self.engine.taskTitle
                                chainID:self.engine.chainID];
        [self.engine startAtDate:now];
        [self scheduleNotificationForCurrentSession];
    } else if ([self.engine.phase isEqualToString:SKTimerPhasePaused]) {
        [self.engine resumeAtDate:now];
        [self scheduleNotificationForCurrentSession];
    }
    [self persistTimer];
    [self refreshFocus];
}

- (void)pauseTimer:(id)sender {
    NSDate *now = NSDate.date;
    if ([self.engine hasReachedEndAtDate:now]) {
        [self timerTick:nil];
        return;
    }
    [self.engine pauseAtDate:now];
    [self cancelPendingTimerNotifications];
    [self persistTimer];
    [self refreshFocus];
}

- (void)endTimer:(id)sender {
    if ([self.engine.phase isEqualToString:SKTimerPhaseTransition]) {
        [self cancelPendingTimerNotifications];
        [self prepareDefaultSessionForceStandard:YES];
        [self refreshFocus];
        return;
    }
    [self finishCurrentSessionAborted:YES atDate:NSDate.date];
}

- (void)timerTick:(NSTimer *)timer {
    NSDate *now = NSDate.date;
    [self refreshFocus];
    if (!self.handlingCompletion && [self.engine hasReachedEndAtDate:now]) {
        self.handlingCompletion = YES;
        if ([self.engine.phase isEqualToString:SKTimerPhaseTransition]) {
            NSString *taskID = self.engine.taskID;
            NSString *taskTitle = self.engine.taskTitle;
            NSString *chain = self.engine.chainID;
            [self.engine prepareSessionKind:SKSessionKindStandard
                            durationSeconds:self.store.defaultWorkMinutes * 60
                                     taskID:taskID
                                  taskTitle:taskTitle
                                    chainID:chain];
            [self.engine startAtDate:now];
            [self playCompletionSound];
            [self scheduleNotificationAfter:self.store.defaultWorkMinutes * 60
                                      title:@"标准番茄完成了"
                                       body:@"你已经做得很好，记下一句完成内容吧。"];
            [self persistTimer];
            [self refreshFocus];
        } else {
            [self finishCurrentSessionAborted:NO atDate:self.engine.expectedEndAt ?: now];
        }
        self.handlingCompletion = NO;
    }
}

- (void)finishCurrentSessionAborted:(BOOL)aborted atDate:(NSDate *)endedAt {
    if (aborted) [self cancelPendingTimerNotifications];
    SKSessionKind kind = self.engine.sessionKind;
    NSString *taskID = self.engine.taskID;
    NSString *taskTitle = self.engine.taskTitle;
    NSString *chain = self.engine.chainID;
    NSDate *startedAt = self.engine.sessionStartedAt ?: endedAt;
    BOOL breakSession = !self.engine.isWorkSession;
    NSInteger actual = breakSession ? 0 :
        (aborted ? [self.engine actualFocusSecondsAtDate:endedAt] : self.engine.plannedSeconds);

    SKFocusRecord *record = nil;
    if (actual > 0) {
        record = [SKFocusRecord new];
        record.identifier = NSUUID.UUID.UUIDString;
        record.chainID = chain;
        record.taskID = taskID;
        record.taskTitleSnapshot = taskTitle;
        record.kind = kind;
        record.status = aborted ? @"aborted" : @"completed";
        record.plannedSeconds = self.engine.plannedSeconds;
        record.actualSeconds = actual;
        record.startedAt = startedAt;
        record.endedAt = endedAt;
        record.countedAsTomato = !aborted && ![kind isEqualToString:SKSessionKindStarter];
        [self.store addRecord:record];
    }

    BOOL naturallyCompletedWork = !aborted && !breakSession &&
        ![kind isEqualToString:SKSessionKindStarter];
    if (actual >= 300 || naturallyCompletedWork) self.store.lastMeaningfulFocusAt = endedAt;
    if (!aborted) [self playCompletionSound];

    if (breakSession) {
        [self prepareDefaultSessionForceStandard:YES];
        if (!aborted && [self confirmNextFocusAfterBreak]) {
            self.restStartedAt = nil;
            [self.engine startAtDate:NSDate.date];
            [self scheduleNotificationAfter:self.engine.plannedSeconds
                                      title:@"这一刻完成了"
                                       body:@"回来看看你刚刚推进了什么。"];
            [self persistTimer];
        }
    } else if (!aborted) {
        if (record) [self presentLogForRecord:record];
        NSInteger breakMinutes = SKShortBreakMinutesForFocusSeconds(self.engine.plannedSeconds);
        [self.engine prepareSessionKind:SKSessionKindShortBreak
                        durationSeconds:breakMinutes * 60
                                 taskID:taskID
                              taskTitle:taskTitle
                                chainID:chain];
        self.restStartedAt = NSDate.date;
        [self.engine startAtDate:self.restStartedAt];
        [self scheduleNotificationAfter:breakMinutes * 60
                                  title:@"休息结束了"
                                   body:@"回来决定是否开始下一轮番茄。"];
        [self persistTimer];
    } else {
        BOOL oneOff = [kind isEqualToString:SKSessionKindCustom];
        [self prepareDefaultSessionForceStandard:oneOff || actual >= 300 || !aborted];
        if (!aborted && record) [self presentLogForRecord:record];
        if (aborted && record && self.store.recordInterruptionReason) {
            [self presentInterruptionReasonForRecord:record];
        }
    }
    [self.store save:nil];
    [self refreshAll];
}

- (BOOL)confirmNextFocusAfterBreak {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"休息结束，要开始下一轮吗？";
    alert.informativeText = @"拾刻不会自动开始计时。选择“稍后再说”后会停在默认时长，只有你主动开始才会计入专注。";
    [alert addButtonWithTitle:@"开始下一轮"];
    [alert addButtonWithTitle:@"稍后再说"];
    SKConfigureProminentPromptWindow(alert.window);
    [NSApp unhide:nil];
    [NSRunningApplication.currentApplication
        activateWithOptions:NSApplicationActivateAllWindows |
                            NSApplicationActivateIgnoringOtherApps];
    [NSApp activateIgnoringOtherApps:YES];
    [alert.window center];
    [alert.window makeKeyAndOrderFront:nil];
    [alert.window orderFrontRegardless];
    return [alert runModal] == NSAlertFirstButtonReturn;
}

- (void)presentInterruptionReasonForRecord:(SKFocusRecord *)record {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"这一轮为什么停下？";
    alert.informativeText = @"可选。记下一句，帮助你发现真正的打断来源。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"跳过"];
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 360, 28)];
    field.placeholderString = @"例如：临时会议、注意力涣散、任务不清楚";
    alert.accessoryView = field;
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *text = [field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        record.interruptionReason = text.length ? text : nil;
        [self.store save:nil];
    }
}

- (void)presentLogForRecord:(SKFocusRecord *)record {
    [self editLogForRecord:record completionPrompt:YES];
}

- (void)scheduleNotificationAfter:(NSInteger)seconds title:(NSString *)title body:(NSString *)body {
    if (seconds < 1 || !self.store.popupNotifications) return;
    NSString *identifier = [self timerNotificationIdentifier];
    [[UNUserNotificationCenter currentNotificationCenter]
     removePendingNotificationRequestsWithIdentifiers:@[identifier, @"active-timer"]];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.body = body;
    content.sound = self.store.soundEnabled ? UNNotificationSound.defaultSound : nil;
    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:MAX(1, seconds) repeats:NO];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
                                                           withCompletionHandler:nil];
}

- (void)scheduleNotificationForCurrentSession {
    NSInteger remaining = [self.engine remainingSecondsAtDate:NSDate.date];
    if (remaining < 1) return;
    if ([self.engine.phase isEqualToString:SKTimerPhaseTransition]) {
        [self scheduleNotificationAfter:remaining title:@"准备继续" body:@"过渡结束，拾刻将带你进入默认番茄。"];
    } else if (self.engine.isWorkSession) {
        [self scheduleNotificationAfter:remaining title:@"这一刻完成了" body:@"回来看看你刚刚推进了什么。"];
    } else {
        [self scheduleNotificationAfter:remaining title:@"休息结束了" body:@"准备好时，再开始下一轮。"];
    }
}

- (NSString *)timerNotificationIdentifier {
    if ([self.engine.phase isEqualToString:SKTimerPhaseTransition]) return @"active-transition-timer";
    return self.engine.isWorkSession ? @"active-focus-timer" : @"active-break-timer";
}

- (void)cancelPendingTimerNotifications {
    [[UNUserNotificationCenter currentNotificationCenter]
     removePendingNotificationRequestsWithIdentifiers:@[
        @"active-timer", @"active-focus-timer", @"active-break-timer", @"active-transition-timer"
     ]];
}

- (NSString *)reminderIdentifierForTask:(SKTask *)task {
    return [@"task-reminder-" stringByAppendingString:task.identifier ?: @"unknown"];
}

- (void)syncReminderForTask:(SKTask *)task {
    NSString *identifier = [self reminderIdentifierForTask:task];
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];
    if (!task.reminderAt || task.completedAt || task.deletedAt) return;
    NSString *repeatRule = task.repeatRule ?: @"none";
    BOOL repeats = ![repeatRule isEqualToString:@"none"];
    if (!repeats && [task.reminderAt compare:NSDate.date] != NSOrderedDescending) return;

    NSCalendarUnit units = NSCalendarUnitHour | NSCalendarUnitMinute;
    if ([repeatRule isEqualToString:@"weekly"]) units |= NSCalendarUnitWeekday;
    else if ([repeatRule isEqualToString:@"monthly"]) units |= NSCalendarUnitDay;
    else if (!repeats) units |= NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents *components = [NSCalendar.currentCalendar components:units fromDate:task.reminderAt];
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = @"该开始这一刻了";
    content.body = task.title.length ? task.title : @"打开拾刻，先做最小的一步。";
    content.sound = self.store.soundEnabled ? UNNotificationSound.defaultSound : nil;
    UNCalendarNotificationTrigger *trigger =
        [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:repeats];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                           content:content
                                                                           trigger:trigger];
    [center addNotificationRequest:request withCompletionHandler:nil];
}

- (void)playCompletionSound {
    if (!self.store.soundEnabled) return;
    NSString *name = self.store.selectedSoundName.length ? self.store.selectedSoundName : @"Glass";
    NSSound *sound = [NSSound soundNamed:name];
    if (!sound) {
        NSString *path = [@"/System/Library/Sounds" stringByAppendingPathComponent:
                          [name stringByAppendingPathExtension:@"aiff"]];
        sound = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
    }
    if (self.completionSound.isPlaying) [self.completionSound stop];
    self.completionSound = sound;
    self.completionSound.volume = MIN(1.0, MAX(0.1, self.store.soundVolume));
    if (!self.completionSound || ![self.completionSound play]) NSBeep();
}

- (void)soundSettingChanged:(id)sender {
    self.store.soundEnabled = self.soundCheckbox.state == NSControlStateValueOn;
    self.store.selectedSoundName = self.soundPopup.selectedItem.title ?: @"Glass";
    self.store.soundVolume = self.volumeSlider.doubleValue;
    [self.store save:nil];
    if (self.store.popupNotifications &&
        ([self.engine.phase isEqualToString:SKTimerPhaseRunning] ||
         [self.engine.phase isEqualToString:SKTimerPhaseTransition])) {
        [self scheduleNotificationForCurrentSession];
    }
}

- (void)appearanceSettingChanged:(id)sender {
    self.store.showCountdownInMenuBar = self.countdownCheckbox.state == NSControlStateValueOn;
    self.store.showDockIcon = self.dockCheckbox.state == NSControlStateValueOn;
    [self.store save:nil];
    [NSApp setActivationPolicy:self.store.showDockIcon ? NSApplicationActivationPolicyRegular
                                                     : NSApplicationActivationPolicyAccessory];
}

- (void)timerSettingChanged:(id)sender {
    self.store.defaultWorkMinutes = MAX(1, self.defaultWorkPopup.selectedItem.title.integerValue);
    [self.store save:nil];
    if ([self.engine.phase isEqualToString:SKTimerPhaseReady] &&
        [self.engine.sessionKind isEqualToString:SKSessionKindStandard]) {
        [self prepareDefaultSessionForceStandard:YES];
        [self refreshFocus];
    }
}

- (void)behaviorSettingChanged:(id)sender {
    if (sender == self.launchCheckbox) {
        NSError *error = nil;
        BOOL enable = self.launchCheckbox.state == NSControlStateValueOn;
        BOOL success = enable ? [SMAppService.mainAppService registerAndReturnError:&error]
                              : [SMAppService.mainAppService unregisterAndReturnError:&error];
        if (!success) {
            self.launchCheckbox.state = enable ? NSControlStateValueOff : NSControlStateValueOn;
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"无法更新开机启动";
            alert.informativeText = error.localizedDescription ?: @"请先把拾刻移动到“应用程序”文件夹后重试。";
            [alert runModal];
        }
    }
    self.store.launchAtLogin = self.launchCheckbox.state == NSControlStateValueOn;
    self.store.popupNotifications = self.popupNotificationsCheckbox.state == NSControlStateValueOn;
    self.store.recordInterruptionReason = self.interruptionReasonCheckbox.state == NSControlStateValueOn;
    [self.store save:nil];
    if (sender == self.popupNotificationsCheckbox) {
        if (self.store.popupNotifications) {
            [self requestNotificationAuthorization];
            if ([self.engine.phase isEqualToString:SKTimerPhaseRunning] ||
                [self.engine.phase isEqualToString:SKTimerPhaseTransition]) {
                [self scheduleNotificationForCurrentSession];
            }
        } else {
            [self cancelPendingTimerNotifications];
        }
    }
}

- (void)requestNotificationAuthorization {
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound
        completionHandler:^(BOOL granted, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self refreshNotificationAuthorization]; });
        }];
}

- (void)refreshNotificationAuthorization {
    [[UNUserNotificationCenter currentNotificationCenter]
        getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
            dispatch_async(dispatch_get_main_queue(), ^{
                switch (settings.authorizationStatus) {
                    case UNAuthorizationStatusAuthorized:
                    case UNAuthorizationStatusProvisional:
                        self.notificationStatusLabel.stringValue = @"权限正常";
                        self.notificationStatusLabel.textColor = NSColor.systemGreenColor;
                        self.notificationPermissionButton.hidden = YES;
                        break;
                    case UNAuthorizationStatusDenied:
                        self.notificationStatusLabel.stringValue = @"已被系统关闭";
                        self.notificationStatusLabel.textColor = NSColor.systemOrangeColor;
                        self.notificationPermissionButton.title = @"打开系统设置";
                        self.notificationPermissionButton.hidden = NO;
                        break;
                    default:
                        self.notificationStatusLabel.stringValue = @"尚未授权";
                        self.notificationStatusLabel.textColor = NSColor.secondaryLabelColor;
                        self.notificationPermissionButton.title = @"允许通知";
                        self.notificationPermissionButton.hidden = NO;
                        break;
                }
            });
        }];
}

- (void)notificationPermissionAction:(id)sender {
    [[UNUserNotificationCenter currentNotificationCenter]
        getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (settings.authorizationStatus == UNAuthorizationStatusDenied) {
                    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.Notifications-Settings.extension"];
                    if (url) [NSWorkspace.sharedWorkspace openURL:url];
                } else {
                    [self requestNotificationAuthorization];
                }
            });
        }];
}

- (void)previewSound:(id)sender {
    [self soundSettingChanged:nil];
    [self playCompletionSound];
}

- (void)recordModeChanged:(id)sender {
    BOOL calendar = self.recordMode.selectedSegment == 1;
    self.recordsScroll.hidden = calendar;
    self.calendarScroll.hidden = !calendar;
    self.recordActions.hidden = calendar;
    if (calendar) {
        self.calendarView.viewMode = 1;
        self.calendarView.records = self.visibleRecords;
        [self.calendarView fitToEnclosingScrollView];
        [self.calendarScroll.contentView scrollToPoint:NSZeroPoint];
        [self.calendarScroll reflectScrolledClipView:self.calendarScroll.contentView];
    }
}

- (void)recordFilterChanged:(id)sender {
    [self.recordsTable reloadData];
    self.calendarView.records = self.visibleRecords;
}

- (void)editSelectedRecord:(id)sender {
    NSInteger row = self.recordsTable.selectedRow;
    NSArray<SKFocusRecord *> *records = self.visibleRecords;
    if (row < 0 || row >= (NSInteger)records.count) { NSBeep(); return; }
    [self editLogForRecord:records[(NSUInteger)row] completionPrompt:NO];
}

- (void)editLogForRecord:(SKFocusRecord *)record completionPrompt:(BOOL)completionPrompt {
    SKLogWindowController *editor = [[SKLogWindowController alloc] initWithRecord:record
                                                                 completionPrompt:completionPrompt];
    if ([editor runEditor] == NSModalResponseOK) {
        [self.store save:nil];
        [self refreshRecords];
        if (self.calendarWindowController) {
            [(SKCalendarWindowController *)self.calendarWindowController updateRecords:self.store.activeRecords];
        }
    }
}

- (void)presentCalendarRecords:(NSArray<SKFocusRecord *> *)records {
    if (!records.count) return;
    SKFocusRecord *selected = records.firstObject;
    if (records.count > 1) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"这一天的专注";
        alert.informativeText = @"选择一条记录查看或补充日志。";
        [alert addButtonWithTitle:@"查看日志"];
        [alert addButtonWithTitle:@"取消"];
        NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 420, 30) pullsDown:NO];
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"HH:mm";
        for (SKFocusRecord *record in records) {
            NSString *name = record.logSummary.length ? record.logSummary :
                             (record.taskTitleSnapshot.length ? record.taskTitleSnapshot : @"未填写日志");
            [popup addItemWithTitle:[NSString stringWithFormat:@"%@  ·  %@  ·  %@",
                                      [formatter stringFromDate:record.startedAt],
                                      SKDurationText(record.actualSeconds), name]];
            popup.lastItem.representedObject = record;
        }
        alert.accessoryView = popup;
        if ([alert runModal] != NSAlertFirstButtonReturn) return;
        selected = popup.selectedItem.representedObject;
    }
    [self editLogForRecord:selected completionPrompt:NO];
}

- (void)deleteSelectedRecord:(id)sender {
    NSInteger row = self.recordsTable.selectedRow;
    NSArray<SKFocusRecord *> *records = self.visibleRecords;
    if (row < 0 || row >= (NSInteger)records.count) { NSBeep(); return; }
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"把这条记录移到回收站？";
    alert.informativeText = @"今日统计和日历会同步更新，之后仍可恢复。";
    [alert addButtonWithTitle:@"移到回收站"];
    [alert addButtonWithTitle:@"取消"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    [self.store deleteRecord:records[(NSUInteger)row]];
    [self refreshRecords];
}

- (void)openTrash:(id)sender {
    NSArray<SKTask *> *tasks = self.store.deletedTasks;
    NSArray<SKFocusRecord *> *records = self.store.deletedRecords;
    if (!tasks.count && !records.count) {
        NSAlert *empty = [NSAlert new]; empty.messageText = @"回收站是空的";
        empty.informativeText = @"删除的任务和专注记录会先保留在这里。";
        [empty addButtonWithTitle:@"知道了"]; [empty runModal]; return;
    }
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"回收站";
    alert.informativeText = @"选择一项恢复，或永久删除。永久删除无法撤销。";
    [alert addButtonWithTitle:@"恢复"];
    [alert addButtonWithTitle:@"永久删除"];
    [alert addButtonWithTitle:@"取消"];
    NSPopUpButton *items = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 420, 30) pullsDown:NO];
    NSDateFormatter *formatter = [NSDateFormatter new]; formatter.dateFormat = @"MM-dd HH:mm";
    for (SKTask *task in tasks) {
        [items addItemWithTitle:[NSString stringWithFormat:@"任务 · %@", task.title]];
        items.lastItem.representedObject = @{@"type": @"task", @"item": task};
    }
    for (SKFocusRecord *record in records) {
        NSString *name = record.logSummary ?: record.taskTitleSnapshot ?: @"专注记录";
        [items addItemWithTitle:[NSString stringWithFormat:@"记录 · %@ · %@", [formatter stringFromDate:record.startedAt], name]];
        items.lastItem.representedObject = @{@"type": @"record", @"item": record};
    }
    alert.accessoryView = items;
    NSModalResponse response = [alert runModal];
    if (response != NSAlertFirstButtonReturn && response != NSAlertSecondButtonReturn) return;
    NSDictionary *selection = items.selectedItem.representedObject;
    BOOL taskType = [selection[@"type"] isEqualToString:@"task"];
    id item = selection[@"item"];
    if (response == NSAlertFirstButtonReturn) {
        if (taskType) {
            [self.store restoreTask:item];
            [self syncReminderForTask:item];
        } else {
            [self.store restoreRecord:item];
        }
    } else {
        NSAlert *confirm = [NSAlert new]; confirm.messageText = @"确认永久删除？";
        confirm.informativeText = @"这项数据将无法恢复。";
        [confirm addButtonWithTitle:@"永久删除"]; [confirm addButtonWithTitle:@"取消"];
        if ([confirm runModal] != NSAlertFirstButtonReturn) return;
        if (taskType) {
            [[UNUserNotificationCenter currentNotificationCenter]
                removePendingNotificationRequestsWithIdentifiers:@[[self reminderIdentifierForTask:item]]];
            [self.store permanentlyDeleteTask:item];
        } else {
            [self.store permanentlyDeleteRecord:item];
        }
    }
    [self refreshAll];
}

- (void)openCalendarWindow:(id)sender {
    if (!self.calendarWindowController) {
        self.calendarWindowController = [[SKCalendarWindowController alloc] initWithRecords:self.store.activeRecords];
        __weak SKMainViewController *weakSelf = self;
        ((SKCalendarWindowController *)self.calendarWindowController).calendarView.recordSelectionHandler =
            ^(NSArray<SKFocusRecord *> *records) { [weakSelf presentCalendarRecords:records]; };
    }
    [(SKCalendarWindowController *)self.calendarWindowController updateRecords:self.store.activeRecords];
    [self.calendarWindowController.window center];
    [self.calendarWindowController showWindow:nil];
    [self.calendarWindowController.window makeKeyAndOrderFront:nil];
}

- (void)toggleTimerFromMenu:(id)sender {
    if ([self.engine.phase isEqualToString:SKTimerPhaseRunning]) [self pauseTimer:nil];
    else if (![self.engine.phase isEqualToString:SKTimerPhaseTransition]) [self primaryTimerAction:nil];
}

- (NSString *)menuBarTitle {
    NSInteger remaining = [self.engine remainingSecondsAtDate:NSDate.date];
    if ([self.engine.phase isEqualToString:SKTimerPhaseRunning] ||
        [self.engine.phase isEqualToString:SKTimerPhasePaused] ||
        [self.engine.phase isEqualToString:SKTimerPhaseTransition]) {
        return SKClockText(remaining);
    }
    return SKClockText(self.engine.plannedSeconds);
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.taskTable) return self.store.activeTasks.count;
    if (tableView == self.recordsTable) return self.visibleRecords.count;
    return 0;
}

- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    if (tableView == self.taskTable) {
        SKTask *task = self.store.activeTasks[(NSUInteger)row];
        if ([tableColumn.identifier isEqualToString:@"done"]) {
            NSTableCellView *cell = [NSTableCellView new];
            NSString *symbolName = task.completedAt ? @"checkmark.circle.fill" : @"circle";
            NSImage *symbol = [NSImage imageWithSystemSymbolName:symbolName
                                         accessibilityDescription:task.completedAt ? @"已完成" : @"标记完成"];
            symbol.template = YES;
            NSButton *checkbox = [SKTaskCompletionButton buttonWithImage:symbol
                                                                   target:self
                                                                   action:@selector(taskDoneChanged:)];
            checkbox.buttonType = NSButtonTypeToggle;
            checkbox.bordered = NO;
            checkbox.controlSize = NSControlSizeSmall;
            checkbox.tag = row;
            checkbox.state = task.completedAt ? NSControlStateValueOn : NSControlStateValueOff;
            checkbox.contentTintColor = task.completedAt ? NSColor.systemGreenColor :
                                        NSColor.tertiaryLabelColor;
            checkbox.toolTip = task.completedAt ? @"恢复为未完成" : @"标记为完成";
            checkbox.translatesAutoresizingMaskIntoConstraints = NO;
            [cell addSubview:checkbox];
            [NSLayoutConstraint activateConstraints:@[
                [checkbox.widthAnchor constraintEqualToConstant:22],
                [checkbox.heightAnchor constraintEqualToConstant:22],
                [checkbox.centerXAnchor constraintEqualToAnchor:cell.centerXAnchor],
                [checkbox.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
            return cell;
        }
        if ([tableColumn.identifier isEqualToString:@"taskMeta"]) {
            NSMutableArray<NSString *> *parts = [NSMutableArray array];
            if (task.completedAt) [parts addObject:@"已完成"];
            if (task.pinned) [parts addObject:@"置顶"];
            if (task.estimatedPomos > 0) [parts addObject:[NSString stringWithFormat:@"%ld 🍅", (long)task.estimatedPomos]];
            if (task.subtasks.count) {
                NSInteger done = 0; for (SKSubtask *item in task.subtasks) if (item.completed) done++;
                [parts addObject:[NSString stringWithFormat:@"%ld/%ld 子任务", (long)done, (long)task.subtasks.count]];
            }
            if (task.tags.count) [parts addObject:[NSString stringWithFormat:@"#%@", [task.tags componentsJoinedByString:@" #"]]];
            NSTextField *meta = SKLabel([parts componentsJoinedByString:@"  ·  "], 11, NSFontWeightMedium);
            meta.textColor = NSColor.secondaryLabelColor;
            meta.alignment = NSTextAlignmentRight;
            meta.toolTip = task.note;
            meta.translatesAutoresizingMaskIntoConstraints = NO;
            NSTableCellView *cell = [NSTableCellView new];
            [cell addSubview:meta];
            [NSLayoutConstraint activateConstraints:@[
                [meta.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:8],
                [meta.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-14],
                [meta.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
            return cell;
        }
        NSTableCellView *cell = [NSTableCellView new];
        NSTextField *field = [NSTextField new];
        field.stringValue = task.title;
        field.tag = row;
        field.target = self;
        field.action = @selector(taskTitleChanged:);
        field.bordered = NO;
        field.drawsBackground = NO;
        field.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
        field.textColor = task.completedAt ? NSColor.secondaryLabelColor : NSColor.labelColor;
        if (task.completedAt) {
            field.attributedStringValue = [[NSAttributedString alloc]
                initWithString:task.title
                    attributes:@{NSFontAttributeName: field.font,
                                 NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
                                 NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
                                 NSStrikethroughColorAttributeName: NSColor.secondaryLabelColor}];
        }
        field.focusRingType = NSFocusRingTypeNone;
        field.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:field];
        [NSLayoutConstraint activateConstraints:@[
            [field.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:4],
            [field.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-8],
            [field.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
        return cell;
    }

    SKFocusRecord *record = self.visibleRecords[(NSUInteger)row];
    NSTextField *label = SKLabel(@"", 13, NSFontWeightRegular);
    if ([tableColumn.identifier isEqualToString:@"time"]) {
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
        formatter.dateFormat = @"MM-dd  HH:mm";
        label.stringValue = [formatter stringFromDate:record.startedAt];
        label.textColor = NSColor.secondaryLabelColor;
    } else if ([tableColumn.identifier isEqualToString:@"duration"]) {
        label.stringValue = SKDurationText(record.actualSeconds);
        label.textColor = record.countedAsTomato ? SKAccentColor() : NSColor.secondaryLabelColor;
    } else {
        NSString *content = record.logSummary.length ? record.logSummary :
                            (record.taskTitleSnapshot.length ? record.taskTitleSnapshot :
                             ([record.kind isEqualToString:SKSessionKindStarter] ? @"启动了五分钟" : @"未填写日志"));
        NSString *suffix = [record.status isEqualToString:@"aborted"] ? @" · 提前结束" : @"";
        label.stringValue = [content stringByAppendingString:suffix];
    }
    return label;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    if (tableView == self.taskTable) return [SKTaskRowView new];
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (notification.object != self.taskTable) return;
    NSInteger row = self.taskTable.selectedRow;
    if (row < 0 || row >= (NSInteger)self.store.activeTasks.count) return;
    SKTask *task = self.store.activeTasks[(NSUInteger)row];
    self.store.selectedTaskID = task.completedAt ? nil : task.identifier;
    [self.store save:nil];
    [self refreshTaskPopup];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner |
                      (self.store.soundEnabled ? UNNotificationPresentationOptionSound : 0));
}

@end

@interface SKStatusPopoverViewController : NSViewController
@property(nonatomic, weak) SKMainViewController *mainViewController;
@property(nonatomic, strong) NSTextField *timerLabel;
@property(nonatomic, strong) NSTextField *phaseLabel;
@property(nonatomic, strong) NSTextField *taskLabel;
@property(nonatomic, strong) NSTextField *todayLabel;
@property(nonatomic, strong) NSSegmentedControl *presets;
@property(nonatomic, strong) NSButton *primaryButton;
@property(nonatomic, strong) NSButton *endButton;
@property(nonatomic, strong) NSStackView *actionRow;
@property(nonatomic, strong) NSLayoutConstraint *primaryButtonWidthConstraint;
@property(nonatomic, strong) NSLayoutConstraint *endButtonWidthConstraint;
- (instancetype)initWithMainViewController:(SKMainViewController *)mainViewController;
- (void)refresh;
@end

@implementation SKStatusPopoverViewController

- (instancetype)initWithMainViewController:(SKMainViewController *)mainViewController {
    self = [super init];
    if (self) _mainViewController = mainViewController;
    return self;
}

- (void)loadView {
    NSVisualEffectView *background = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 336, 348)];
    background.material = NSVisualEffectMaterialPopover;
    background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    background.state = NSVisualEffectStateActive;
    self.view = background;

    NSStackView *column = [NSStackView new];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeCenterX;
    column.spacing = 10;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [background addSubview:column];

    NSStackView *brandRow = [NSStackView new];
    brandRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    brandRow.alignment = NSLayoutAttributeCenterY;
    brandRow.spacing = 8;
    NSImageView *mark = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 22, 22)];
    NSImage *markImage = [NSImage imageWithSystemSymbolName:@"circle.dashed.inset.filled" accessibilityDescription:@"拾刻"];
    markImage.template = YES;
    mark.image = markImage;
    mark.contentTintColor = SKAccentColor();
    [mark.widthAnchor constraintEqualToConstant:22].active = YES;
    [mark.heightAnchor constraintEqualToConstant:22].active = YES;
    [brandRow addArrangedSubview:mark];
    [brandRow addArrangedSubview:SKLabel(@"拾刻", 16, NSFontWeightSemibold)];
    [column addArrangedSubview:brandRow];

    self.phaseLabel = SKLabel(@"准备开始", 12, NSFontWeightMedium);
    self.phaseLabel.textColor = NSColor.secondaryLabelColor;
    self.phaseLabel.alignment = NSTextAlignmentCenter;
    [column addArrangedSubview:self.phaseLabel];
    self.timerLabel = SKLabel(@"25:00", 48, NSFontWeightLight);
    self.timerLabel.font = [NSFont monospacedDigitSystemFontOfSize:48 weight:NSFontWeightLight];
    self.timerLabel.alignment = NSTextAlignmentCenter;
    [column addArrangedSubview:self.timerLabel];
    self.taskLabel = SKLabel(@"未关联任务", 13, NSFontWeightMedium);
    self.taskLabel.textColor = NSColor.secondaryLabelColor;
    self.taskLabel.alignment = NSTextAlignmentCenter;
    [self.taskLabel.widthAnchor constraintLessThanOrEqualToConstant:286].active = YES;
    [column addArrangedSubview:self.taskLabel];

    self.presets = [NSSegmentedControl segmentedControlWithLabels:@[@"15", @"20", @"25", @"30"]
                                                        trackingMode:NSSegmentSwitchTrackingSelectOne
                                                              target:self
                                                              action:@selector(presetChanged:)];
    self.presets.controlSize = NSControlSizeRegular;
    [self.presets.widthAnchor constraintEqualToConstant:260].active = YES;
    [column addArrangedSubview:self.presets];

    self.actionRow = [NSStackView new];
    self.actionRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.actionRow.spacing = 8;
    [self.actionRow.widthAnchor constraintEqualToConstant:260].active = YES;
    self.primaryButton = SKButton(@"开始专注", self, @selector(primaryAction:));
    self.primaryButton.bezelColor = SKAccentColor();
    self.primaryButtonWidthConstraint = [self.primaryButton.widthAnchor
        constraintEqualToConstant:SKStatusPrimaryButtonWidth(NO)];
    self.primaryButtonWidthConstraint.active = YES;
    self.endButton = SKButton(@"结束", self, @selector(endAction:));
    self.endButtonWidthConstraint = [self.endButton.widthAnchor constraintEqualToConstant:0];
    self.endButtonWidthConstraint.active = YES;
    [self.actionRow addArrangedSubview:self.primaryButton];
    [self.actionRow addArrangedSubview:self.endButton];
    [column addArrangedSubview:self.actionRow];

    self.todayLabel = SKLabel(@"今日 0 🍅", 11, NSFontWeightMedium);
    self.todayLabel.textColor = NSColor.tertiaryLabelColor;
    [column addArrangedSubview:self.todayLabel];

    NSBox *separator = [NSBox new];
    separator.boxType = NSBoxSeparator;
    [separator.widthAnchor constraintEqualToConstant:286].active = YES;
    [column addArrangedSubview:separator];

    NSStackView *footer = [NSStackView new];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.spacing = 6;
    NSButton *open = SKButton(@"主窗口", self, @selector(openMainWindow:));
    NSButton *calendar = SKButton(@"日历", self, @selector(openCalendar:));
    NSButton *settings = SKButton(@"设置", self, @selector(openSettings:));
    NSButton *quit = SKButton(@"退出", self, @selector(quitApp:));
    for (NSButton *button in @[open, calendar, settings, quit]) button.controlSize = NSControlSizeSmall;
    [footer addArrangedSubview:open];
    [footer addArrangedSubview:calendar];
    [footer addArrangedSubview:settings];
    [footer addArrangedSubview:quit];
    [column addArrangedSubview:footer];

    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:24],
        [column.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-24],
        [column.topAnchor constraintEqualToAnchor:background.topAnchor constant:20],
        [column.bottomAnchor constraintLessThanOrEqualToAnchor:background.bottomAnchor constant:-18]
    ]];
    [self refresh];
}

- (void)refresh {
    if (!self.isViewLoaded) return;
    SKMainViewController *main = self.mainViewController;
    [main refreshFocus];
    self.timerLabel.stringValue = main.menuBarTitle;
    self.phaseLabel.stringValue = main.phaseLabel.stringValue ?: @"准备开始";
    SKTask *task = main.store.selectedTask;
    self.taskLabel.stringValue = task.title.length ? task.title : @"未关联任务";
    self.todayLabel.stringValue = main.todayLabel.stringValue ?: @"";
    BOOL ready = [main.engine.phase isEqualToString:SKTimerPhaseReady];
    BOOL running = [main.engine.phase isEqualToString:SKTimerPhaseRunning];
    BOOL paused = [main.engine.phase isEqualToString:SKTimerPhasePaused];
    BOOL transition = [main.engine.phase isEqualToString:SKTimerPhaseTransition];
    self.primaryButton.title = running ? @"暂停" : (paused ? @"继续" : @"开始专注");
    self.primaryButton.enabled = !transition;
    BOOL breakSession = !main.engine.isWorkSession;
    BOOL hidesEndButton = ready && !breakSession;
    self.endButton.hidden = hidesEndButton;
    self.actionRow.spacing = hidesEndButton ? 0 : 8;
    self.primaryButtonWidthConstraint.constant = SKStatusPrimaryButtonWidth(!hidesEndButton);
    self.endButtonWidthConstraint.constant = hidesEndButton ? 0 : 68;
    self.endButton.title = ready && breakSession ? @"跳过" : @"结束";
    self.presets.enabled = ready;
    self.presets.selectedSegment = -1;
    NSArray<NSNumber *> *values = @[@15, @20, @25, @30];
    NSInteger minutes = MAX(1, main.engine.plannedSeconds / 60);
    for (NSInteger index = 0; index < (NSInteger)values.count; index++) {
        if (values[(NSUInteger)index].integerValue == minutes) self.presets.selectedSegment = index;
    }
}

- (void)presetChanged:(NSSegmentedControl *)sender {
    if (sender.selectedSegment < 0) return;
    NSArray<NSNumber *> *values = @[@15, @20, @25, @30];
    [self.mainViewController statusPresetMinutes:values[(NSUInteger)sender.selectedSegment].integerValue];
    [self refresh];
}

- (void)primaryAction:(id)sender {
    [self.mainViewController toggleTimerFromMenu:sender];
    [self refresh];
}

- (void)endAction:(id)sender {
    [self.mainViewController endTimer:sender];
    [self refresh];
}

- (void)showMainPage:(NSInteger)page {
    NSWindow *window = [(NSObject *)NSApp.delegate valueForKey:@"window"];
    [self.mainViewController showPage:page];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)openMainWindow:(id)sender { [self showMainPage:1]; }
- (void)openSettings:(id)sender { [self showMainPage:3]; }

- (void)openCalendar:(id)sender {
    [self.mainViewController openCalendarWindow:sender];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)quitApp:(id)sender { [NSApp terminate:sender]; }

@end

static NSBox *SKOnboardingCard(NSString *symbolName, NSString *title, NSString *detail) {
    NSBox *card = SKPanelBox(16);
    NSStackView *stack = [NSStackView new];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeCenterX;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    NSImageView *icon = [NSImageView new];
    NSImage *image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:title];
    image.template = YES;
    icon.image = image;
    icon.contentTintColor = SKAccentColor();
    [icon.widthAnchor constraintEqualToConstant:30].active = YES;
    [icon.heightAnchor constraintEqualToConstant:30].active = YES;
    NSTextField *titleLabel = SKLabel(title, 15, NSFontWeightSemibold);
    titleLabel.alignment = NSTextAlignmentCenter;
    NSTextField *detailLabel = SKLabel(detail, 12, NSFontWeightRegular);
    detailLabel.textColor = NSColor.secondaryLabelColor;
    detailLabel.alignment = NSTextAlignmentCenter;
    detailLabel.maximumNumberOfLines = 4;
    detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [stack addArrangedSubview:icon];
    [stack addArrangedSubview:titleLabel];
    [stack addArrangedSubview:detailLabel];
    [card addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
        [stack.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];
    return card;
}

@interface SKOnboardingWindowController : NSWindowController
@property(nonatomic, strong) NSButton *notificationCheckbox;
@property(nonatomic, copy) void (^completion)(BOOL notifications);
- (instancetype)initWithCompletion:(void (^)(BOOL notifications))completion;
@end

@implementation SKOnboardingWindowController

- (instancetype)initWithCompletion:(void (^)(BOOL notifications))completion {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 540)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.movableByWindowBackground = YES;
    window.releasedWhenClosed = NO;
    self = [super initWithWindow:window];
    if (!self) return nil;
    self.completion = completion;

    NSView *root = [NSView new];
    root.wantsLayer = YES;
    root.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;
    window.contentView = root;

    NSImageView *appIcon = [NSImageView new];
    appIcon.image = NSApp.applicationIconImage;
    appIcon.imageScaling = NSImageScaleProportionallyUpOrDown;
    appIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:appIcon];
    NSTextField *eyebrow = SKLabel(@"低心智专注工具 · macOS", 11, NSFontWeightSemibold);
    eyebrow.textColor = SKAccentColor();
    eyebrow.alignment = NSTextAlignmentCenter;
    eyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:eyebrow];
    NSTextField *title = SKLabel(@"先开始，再变好", 30, NSFontWeightBold);
    title.alignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:title];
    NSTextField *subtitle = SKLabel(@"拾刻会留在顶部状态栏。难以开始时，先做五分钟；时间不完整时，就按这一刻真正拥有的时间来。", 13, NSFontWeightRegular);
    subtitle.textColor = NSColor.secondaryLabelColor;
    subtitle.alignment = NSTextAlignmentCenter;
    subtitle.maximumNumberOfLines = 2;
    subtitle.lineBreakMode = NSLineBreakByWordWrapping;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:subtitle];

    NSStackView *cards = [NSStackView stackViewWithViews:@[
        SKOnboardingCard(@"figure.walk.motion", @"五分钟启动", @"没状态也没关系，先把开始这件事变轻。"),
        SKOnboardingCard(@"timer", @"本轮自由定时", @"15、20、25、30 分钟，或直接专注到某个时刻。"),
        SKOnboardingCard(@"menubar.rectangle", @"状态栏直接操作", @"倒计时始终可见，不打开主窗口也能暂停、继续和结束。")
    ]];
    cards.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    cards.spacing = 12;
    cards.distribution = NSStackViewDistributionFillEqually;
    cards.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:cards];

    NSBox *statusPill = SKPanelBox(12);
    statusPill.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:statusPill];
    NSTextField *statusText = SKLabel(@"◴  25:00   ·   点击这里开始、暂停或调整本轮时间", 12, NSFontWeightSemibold);
    statusText.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightSemibold];
    statusText.translatesAutoresizingMaskIntoConstraints = NO;
    [statusPill addSubview:statusText];

    NSTextField *privacyNote = SKLabel(@"无需登录  ·  数据仅保存在本机  ·  隐私优先", 11, NSFontWeightMedium);
    privacyNote.textColor = NSColor.secondaryLabelColor;
    privacyNote.alignment = NSTextAlignmentCenter;
    privacyNote.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:privacyNote];

    self.notificationCheckbox = [NSButton checkboxWithTitle:@"计时结束时使用系统通知提醒我"
                                                     target:nil
                                                     action:nil];
    self.notificationCheckbox.state = NSControlStateValueOn;
    self.notificationCheckbox.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:self.notificationCheckbox];

    NSButton *later = SKButton(@"暂不设置", self, @selector(finishLater:));
    later.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:later];
    NSButton *start = SKButton(@"开始使用拾刻", self, @selector(finishOnboarding:));
    start.bezelColor = SKAccentColor();
    start.keyEquivalent = @"\r";
    start.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:start];

    [NSLayoutConstraint activateConstraints:@[
        [appIcon.topAnchor constraintEqualToAnchor:root.topAnchor constant:26],
        [appIcon.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [appIcon.widthAnchor constraintEqualToConstant:72],
        [appIcon.heightAnchor constraintEqualToConstant:72],
        [eyebrow.topAnchor constraintEqualToAnchor:appIcon.bottomAnchor constant:4],
        [eyebrow.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [title.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:5],
        [title.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [subtitle.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [subtitle.widthAnchor constraintEqualToConstant:590],
        [cards.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:34],
        [cards.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-34],
        [cards.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20],
        [cards.heightAnchor constraintEqualToConstant:142],
        [statusPill.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [statusPill.topAnchor constraintEqualToAnchor:cards.bottomAnchor constant:14],
        [statusText.leadingAnchor constraintEqualToAnchor:statusPill.leadingAnchor constant:18],
        [statusText.trailingAnchor constraintEqualToAnchor:statusPill.trailingAnchor constant:-18],
        [statusText.topAnchor constraintEqualToAnchor:statusPill.topAnchor constant:10],
        [statusText.bottomAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:-10],
        [privacyNote.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [privacyNote.topAnchor constraintEqualToAnchor:statusPill.bottomAnchor constant:13],
        [self.notificationCheckbox.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:46],
        [self.notificationCheckbox.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-27],
        [start.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-38],
        [start.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-22],
        [start.widthAnchor constraintEqualToConstant:142],
        [later.trailingAnchor constraintEqualToAnchor:start.leadingAnchor constant:-8],
        [later.centerYAnchor constraintEqualToAnchor:start.centerYAnchor]
    ]];
    return self;
}

- (void)completeWithNotifications:(BOOL)notifications {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"ShikeHasCompletedOnboardingV1"];
    if (self.completion) self.completion(notifications);
    [self close];
}

- (void)finishOnboarding:(id)sender {
    [self completeWithNotifications:self.notificationCheckbox.state == NSControlStateValueOn];
}

- (void)finishLater:(id)sender { [self completeWithNotifications:NO]; }

@end

@interface SKAppDelegate : NSObject <NSApplicationDelegate, NSPopoverDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) SKMainViewController *mainViewController;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSTimer *statusTicker;
@property(nonatomic, strong) NSPopover *statusPopover;
@property(nonatomic, strong) SKStatusPopoverViewController *statusPanel;
@property(nonatomic, strong) SKOnboardingWindowController *onboardingWindowController;
@property(nonatomic, strong) id globalMouseMonitor;
@property(nonatomic, strong) id localMouseMonitor;
- (void)installStatusPopoverDismissMonitors;
- (void)removeStatusPopoverDismissMonitors;
@end

@implementation SKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *iconPath = [NSBundle.mainBundle pathForResource:@"Shike" ofType:@"icns"];
    NSImage *applicationIcon = iconPath.length ? [[NSImage alloc] initWithContentsOfFile:iconPath] : nil;
    if (applicationIcon) NSApp.applicationIconImage = applicationIcon;
    self.mainViewController = [SKMainViewController new];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 640)
                                             styleMask:NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable |
                                                       NSWindowStyleMaskResizable
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    self.window.title = @"拾刻 Shike";
    self.window.minSize = NSMakeSize(840, 600);
    self.window.titlebarAppearsTransparent = YES;
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.tabbingMode = NSWindowTabbingModeDisallowed;
    self.window.releasedWhenClosed = NO;
    self.window.contentViewController = self.mainViewController;
    [self.window center];
    [self.window orderOut:nil];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.autosaveName = @"com.zhuxinchen.Shike.statusItem";
    self.statusItem.visible = YES;
    self.statusItem.button.image = SKMenuBarTimerImage();
    self.statusItem.button.imageScaling = NSImageScaleProportionallyDown;
    self.statusItem.button.imagePosition = NSImageLeading;
    self.statusItem.button.imageHugsTitle = YES;
    self.statusItem.button.font = SKMenuBarCountdownFont();
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(toggleStatusPopover:);
    self.statusItem.button.enabled = YES;
    self.statusPanel = [[SKStatusPopoverViewController alloc] initWithMainViewController:self.mainViewController];
    self.statusPopover = [NSPopover new];
    self.statusPopover.behavior = NSPopoverBehaviorTransient;
    self.statusPopover.delegate = self;
    self.statusPopover.animates = YES;
    self.statusPopover.contentSize = NSMakeSize(336, 348);
    self.statusPopover.contentViewController = self.statusPanel;
    self.statusTicker = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                        target:self
                                                      selector:@selector(updateStatusItem:)
                                                      userInfo:nil
                                                       repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.statusTicker forMode:NSRunLoopCommonModes];
    [self updateStatusItem:nil];
    [NSApp setActivationPolicy:self.mainViewController.store.showDockIcon ? NSApplicationActivationPolicyRegular
                                                                    : NSApplicationActivationPolicyAccessory];

    NSMenu *mainMenu = [NSMenu new];
    NSMenuItem *appItem = [NSMenuItem new];
    [mainMenu addItem:appItem];
    NSMenu *appMenu = [NSMenu new];
    NSMenuItem *about = [appMenu addItemWithTitle:@"关于拾刻" action:@selector(showAbout:) keyEquivalent:@""];
    about.target = self;
    NSMenuItem *guide = [appMenu addItemWithTitle:@"再次查看使用引导" action:@selector(showOnboarding:) keyEquivalent:@""];
    guide.target = self;
    NSMenuItem *dataFolder = [appMenu addItemWithTitle:@"打开本地数据目录" action:@selector(openDataFolder:) keyEquivalent:@""];
    dataFolder.target = self;
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"退出拾刻" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;

    NSMenuItem *focusItem = [NSMenuItem new];
    [mainMenu addItem:focusItem];
    NSMenu *focusMenu = [[NSMenu alloc] initWithTitle:@"专注"];
    NSMenuItem *toggle = [focusMenu addItemWithTitle:@"开始／暂停／继续"
                                             action:@selector(toggleTimerFromMenu:)
                                      keyEquivalent:@" "];
    toggle.target = self.mainViewController;
    NSMenuItem *calendar = [focusMenu addItemWithTitle:@"打开日历"
                                                action:@selector(openCalendarWindow:)
                                         keyEquivalent:@"k"];
    calendar.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    calendar.target = self.mainViewController;
    NSMenuItem *statusPanel = [focusMenu addItemWithTitle:@"打开状态栏面板"
                                                   action:@selector(toggleStatusPopover:)
                                            keyEquivalent:@"m"];
    statusPanel.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    statusPanel.target = self;
    focusItem.submenu = focusMenu;
    NSApp.mainMenu = mainMenu;

    BOOL onboardingComplete = [NSUserDefaults.standardUserDefaults boolForKey:@"ShikeHasCompletedOnboardingV1"];
    BOOL hasExistingData = [NSFileManager.defaultManager fileExistsAtPath:SKAppStore.defaultStorageURL.path];
    if (!onboardingComplete && !hasExistingData) [self showOnboarding:nil];
    BOOL showMainForQA = [NSProcessInfo.processInfo.arguments containsObject:@"--show-main-window"];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusItem.visible = YES;
        [self updateStatusItem:nil];
        if (showMainForQA) [self showMainWindow:nil];
    });

}

- (void)showOnboarding:(id)sender {
    __weak SKAppDelegate *weakSelf = self;
    self.onboardingWindowController = [[SKOnboardingWindowController alloc]
        initWithCompletion:^(BOOL notifications) {
            SKAppDelegate *strongSelf = weakSelf;
            strongSelf.mainViewController.store.popupNotifications = notifications;
            [strongSelf.mainViewController.store save:nil];
            [strongSelf.mainViewController refreshAll];
            if (notifications) [strongSelf.mainViewController requestNotificationAuthorization];
            [strongSelf showMainWindow:nil];
        }];
    [self.onboardingWindowController.window center];
    [self.onboardingWindowController showWindow:nil];
    [self.onboardingWindowController.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showAbout:(id)sender {
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentCenter;
    NSAttributedString *credits = [[NSAttributedString alloc]
        initWithString:@"把注意力交给下一刻\n低心智启动 · 自由番茄 · 真实专注日历\n\n所有数据仅保存在这台 Mac 上。"
        attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:12],
                     NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
                     NSParagraphStyleAttributeName: style}];
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName: @"拾刻 Shike",
        NSAboutPanelOptionCredits: credits,
        NSAboutPanelOptionApplicationIcon: NSApp.applicationIconImage
    }];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)openDataFolder:(id)sender {
    NSURL *folder = [SKAppStore.defaultStorageURL URLByDeletingLastPathComponent];
    [NSFileManager.defaultManager createDirectoryAtURL:folder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    [NSWorkspace.sharedWorkspace openURL:folder];
}

- (void)toggleStatusPopover:(id)sender {
    if (self.statusPopover.shown) {
        [self.statusPopover close];
    } else {
        [self.statusPanel refresh];
        NSStatusBarButton *button = self.statusItem.button;
        [self.statusPopover showRelativeToRect:button.bounds
                                        ofView:button
                                 preferredEdge:NSRectEdgeMinY];
        [self installStatusPopoverDismissMonitors];
    }
}

- (void)installStatusPopoverDismissMonitors {
    [self removeStatusPopoverDismissMonitors];
    __weak SKAppDelegate *weakSelf = self;
    NSEventMask clicks = NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown;
    self.globalMouseMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:clicks
                                                                    handler:^(NSEvent *event) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SKAppDelegate *strongSelf = weakSelf;
            if (strongSelf.statusPopover.shown) [strongSelf.statusPopover close];
        });
    }];
    self.localMouseMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:clicks
                                                                   handler:^NSEvent *(NSEvent *event) {
        SKAppDelegate *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.statusPopover.shown) return event;
        NSWindow *popoverWindow = strongSelf.statusPopover.contentViewController.view.window;
        NSWindow *statusWindow = strongSelf.statusItem.button.window;
        if (SKStatusPopoverShouldDismiss(event.window, popoverWindow, statusWindow)) {
            [strongSelf.statusPopover close];
        }
        return event;
    }];
}

- (void)removeStatusPopoverDismissMonitors {
    if (self.globalMouseMonitor) {
        [NSEvent removeMonitor:self.globalMouseMonitor];
        self.globalMouseMonitor = nil;
    }
    if (self.localMouseMonitor) {
        [NSEvent removeMonitor:self.localMouseMonitor];
        self.localMouseMonitor = nil;
    }
}

- (void)popoverDidClose:(NSNotification *)notification {
    [self removeStatusPopoverDismissMonitors];
}

- (void)showMainWindow:(id)sender {
    [self.statusPopover close];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)updateStatusItem:(NSTimer *)timer {
    BOOL showCountdown = self.mainViewController.store.showCountdownInMenuBar;
    NSString *remaining = self.mainViewController.menuBarTitle;
    self.statusItem.length = showCountdown ? NSVariableStatusItemLength : NSSquareStatusItemLength;
    self.statusItem.visible = YES;
    self.statusItem.button.title = showCountdown ? remaining : @"";
    self.statusItem.button.toolTip = [NSString stringWithFormat:@"拾刻 · 剩余 %@\n按住 ⌘ 拖动可调整位置", remaining];
    self.statusItem.button.accessibilityLabel = [NSString stringWithFormat:@"拾刻，剩余时间 %@", remaining];
    [self.statusPanel refresh];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    self.statusItem.visible = YES;
    [self updateStatusItem:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (!hasVisibleWindows) {
        self.statusItem.visible = YES;
        [self updateStatusItem:nil];
        [self toggleStatusPopover:nil];
        [NSApp activateIgnoringOtherApps:YES];
    }
    return YES;
}

@end

#ifndef SHIKE_TESTING
int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        SKAppDelegate *delegate = [SKAppDelegate new];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
#endif
