#import <Foundation/Foundation.h>
#import <stdlib.h>
#import "ShikeCore.h"

static void SKAssert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"❌ %@", message);
        exit(1);
    }
}

static void testTimerStartPauseResume(void) {
    SKTimerEngine *engine = [SKTimerEngine new];
    NSDate *t0 = [NSDate dateWithTimeIntervalSince1970:1000];
    [engine prepareSessionKind:SKSessionKindStandard
              durationSeconds:1500
                       taskID:@"task"
                    taskTitle:@"写测试"
                      chainID:nil];
    [engine startAtDate:t0];
    SKAssert([[engine phase] isEqualToString:SKTimerPhaseRunning], @"开始后应处于运行状态");
    SKAssert([engine remainingSecondsAtDate:[t0 dateByAddingTimeInterval:100]] == 1400,
             @"倒计时必须按绝对时间计算");

    [engine pauseAtDate:[t0 dateByAddingTimeInterval:100]];
    SKAssert([[engine phase] isEqualToString:SKTimerPhasePaused], @"暂停状态不正确");
    SKAssert([engine actualFocusSecondsAtDate:[t0 dateByAddingTimeInterval:500]] == 100,
             @"暂停期间不应累计专注时间");

    [engine resumeAtDate:[t0 dateByAddingTimeInterval:500]];
    SKAssert([engine remainingSecondsAtDate:[t0 dateByAddingTimeInterval:600]] == 1300,
             @"恢复后应从剩余时间继续");
}

static void testPersistenceRoundTrip(void) {
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"shike-test-%@/data.json", NSUUID.UUID.UUIDString]]];
    SKAppStore *store = [[SKAppStore alloc] initWithStorageURL:url];
    SKTask *task = [store addTaskWithTitle:@"阅读第三章"];
    task.pinned = YES;
    task.estimatedPomos = 3;
    task.note = @"整理核心概念";
    task.tags = @[@"读书", @"学习"];
    [task.subtasks addObject:[SKSubtask subtaskWithTitle:@"回顾笔记" sortOrder:0]];
    store.shortBreakMinutes = 7;
    store.lastMeaningfulFocusAt = [NSDate dateWithTimeIntervalSince1970:2000];

    SKFocusRecord *record = [SKFocusRecord new];
    record.identifier = NSUUID.UUID.UUIDString;
    record.taskID = task.identifier;
    record.taskTitleSnapshot = task.title;
    record.kind = SKSessionKindCustom;
    record.status = @"completed";
    record.plannedSeconds = 900;
    record.actualSeconds = 900;
    record.startedAt = [NSDate dateWithTimeIntervalSince1970:3000];
    record.endedAt = [NSDate dateWithTimeIntervalSince1970:3900];
    record.countedAsTomato = YES;
    record.logSummary = @"完成笔记";
    [store addRecord:record];
    SKAssert([store save:nil], @"保存应成功");

    SKAppStore *reloaded = [[SKAppStore alloc] initWithStorageURL:url];
    [reloaded load];
    SKAssert(reloaded.tasks.count == 1, @"任务持久化失败");
    SKAssert(reloaded.records.count == 1, @"专注记录持久化失败");
    SKAssert([reloaded.records.firstObject.taskTitleSnapshot isEqualToString:@"阅读第三章"],
             @"历史任务名称快照必须保留");
    SKAssert(reloaded.tasks.firstObject.pinned, @"任务置顶状态必须保留");
    SKAssert(reloaded.tasks.firstObject.estimatedPomos == 3, @"预计番茄数必须保留");
    SKAssert(reloaded.tasks.firstObject.subtasks.count == 1, @"子任务必须保留");
    SKAssert(reloaded.shortBreakMinutes == 7, @"番茄偏好必须保留");
}

static void testSnapshotRestore(void) {
    SKTimerEngine *engine = [SKTimerEngine new];
    NSDate *t0 = [NSDate dateWithTimeIntervalSince1970:5000];
    [engine prepareSessionKind:SKSessionKindStarter
              durationSeconds:300
                       taskID:nil
                    taskTitle:nil
                      chainID:@"chain"];
    [engine startAtDate:t0];
    NSDictionary *snapshot = engine.dictionaryRepresentation;

    SKTimerEngine *restored = [SKTimerEngine new];
    SKAssert([restored restoreFromDictionary:snapshot], @"快照恢复应成功");
    SKAssert([restored remainingSecondsAtDate:[t0 dateByAddingTimeInterval:120]] == 180,
             @"恢复后剩余时间必须正确");
    SKAssert([restored.chainID isEqualToString:@"chain"], @"链路编号必须恢复");
}

static void testOneOffDurationCanOnlyChangeBeforeStart(void) {
    SKTimerEngine *engine = [SKTimerEngine new];
    [engine prepareSessionKind:SKSessionKindCustom
              durationSeconds:1200
                       taskID:nil
                    taskTitle:nil
                      chainID:nil];
    SKAssert(engine.plannedSeconds == 1200, @"本轮应支持20分钟临时时长");
    SKAssert([engine updatePreparedDurationSeconds:18 * 60], @"开始前应允许修改本轮时长");
    SKAssert(engine.plannedSeconds == 18 * 60, @"临时时长修改失败");
    [engine startAtDate:[NSDate dateWithTimeIntervalSince1970:1000]];
    SKAssert(![engine updatePreparedDurationSeconds:10 * 60], @"开始后必须锁定本轮时长");
    SKAssert(engine.plannedSeconds == 18 * 60, @"运行中不应改变计划时长");
}

static void testSoftDeleteAndRestore(void) {
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"shike-delete-test-%@/data.json", NSUUID.UUID.UUIDString]]];
    SKAppStore *store = [[SKAppStore alloc] initWithStorageURL:url];
    SKTask *task = [store addTaskWithTitle:@"可以恢复的任务"];
    [store deleteTask:task];
    SKAssert(store.activeTasks.count == 0 && store.deletedTasks.count == 1,
             @"删除任务应进入回收站");
    [store restoreTask:task];
    SKAssert(store.activeTasks.count == 1 && store.deletedTasks.count == 0,
             @"回收站任务应可恢复");

    SKFocusRecord *record = [SKFocusRecord new];
    record.identifier = NSUUID.UUID.UUIDString;
    record.kind = SKSessionKindStandard;
    record.status = @"completed";
    record.plannedSeconds = 1500;
    record.actualSeconds = 1500;
    record.startedAt = NSDate.date;
    record.endedAt = NSDate.date;
    [store addRecord:record];
    [store deleteRecord:record];
    SKAssert(store.activeRecords.count == 0 && store.deletedRecords.count == 1,
             @"删除记录应进入回收站");
    [store restoreRecord:record];
    SKAssert(store.activeRecords.count == 1 && store.deletedRecords.count == 0,
             @"回收站记录应可恢复");
    [store deleteRecord:record];
    [store permanentlyDeleteRecord:record];
    SKAssert(store.records.count == 0, @"记录应支持永久删除");
}

static void testBreakDoesNotCountAsFocus(void) {
    SKTimerEngine *engine = [SKTimerEngine new];
    NSDate *t0 = [NSDate dateWithTimeIntervalSince1970:2000];
    [engine prepareSessionKind:SKSessionKindShortBreak
              durationSeconds:300
                       taskID:nil
                    taskTitle:nil
                      chainID:nil];
    [engine startAtDate:t0];
    SKAssert(!engine.isWorkSession, @"短休息不能视为工作番茄");
    SKAssert([engine actualFocusSecondsAtDate:[t0 dateByAddingTimeInterval:120]] == 0,
             @"休息时间不能累计为专注时间");
}

static void testTimerBoundaryTransitions(void) {
    SKTimerEngine *engine = [SKTimerEngine new];
    NSDate *t0 = [NSDate dateWithTimeIntervalSince1970:10000];
    [engine prepareSessionKind:SKSessionKindStandard durationSeconds:300 taskID:nil taskTitle:nil chainID:nil];
    [engine startAtDate:t0];
    SKAssert([engine remainingSecondsAtDate:[t0 dateByAddingTimeInterval:-60]] == 300,
             @"系统时间回拨时剩余时间不能超过计划时长");
    [engine pauseAtDate:[t0 dateByAddingTimeInterval:100]];
    [engine resumeAtDate:[t0 dateByAddingTimeInterval:200]];
    [engine pauseAtDate:[t0 dateByAddingTimeInterval:250]];
    SKAssert(engine.storedRemainingSeconds == 150, @"多次暂停恢复后剩余时间应准确");
    SKAssert([engine actualFocusSecondsAtDate:[t0 dateByAddingTimeInterval:999]] == 150,
             @"暂停期间不能继续累计专注时间");
    [engine resumeAtDate:[t0 dateByAddingTimeInterval:300]];
    NSDate *end = [t0 dateByAddingTimeInterval:450];
    SKAssert([engine hasReachedEndAtDate:end], @"到达结束时间必须完成");
    [engine pauseAtDate:end];
    SKAssert([engine.phase isEqualToString:SKTimerPhaseRunning],
             @"归零瞬间的暂停不能绕过完成处理");
}

static void testInvalidSnapshotsAreRejected(void) {
    SKTimerEngine *engine = [SKTimerEngine new];
    SKAssert(![engine restoreFromDictionary:@{}], @"空快照必须拒绝");
    SKAssert(![engine restoreFromDictionary:@{@"phase": SKTimerPhaseRunning,
                                              @"sessionKind": @"unknown",
                                              @"plannedSeconds": @300}],
             @"未知会话类型必须拒绝");
    SKAssert(![engine restoreFromDictionary:@{@"phase": SKTimerPhaseRunning,
                                              @"sessionKind": SKSessionKindStandard,
                                              @"plannedSeconds": @300,
                                              @"storedRemainingSeconds": @100}],
             @"缺少绝对结束时间的运行快照必须拒绝");
    SKAssert(![engine restoreFromDictionary:@{@"phase": SKTimerPhasePaused,
                                              @"sessionKind": SKSessionKindStandard,
                                              @"plannedSeconds": @300,
                                              @"storedRemainingSeconds": @0}],
             @"剩余时间为零的暂停快照必须拒绝");
}

static void testCorruptPersistenceIsSanitized(void) {
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"shike-corrupt-test-%@/data.json", NSUUID.UUID.UUIDString]]];
    NSDictionary *root = @{
        @"tasks": @[@"bad", @{}, @{ @"id": @"task-1", @"title": @"保留任务",
                                      @"subtasks": @[@"bad-subtask"] }],
        @"records": @[@42, @{ @"id": @"record-1", @"kind": @"invalid",
                                @"status": @"aborted", @"plannedSeconds": @300,
                                @"actualSeconds": @999, @"startedAt": @100,
                                @"endedAt": @50, @"countedAsTomato": @YES }],
        @"settings": @{ @"soundVolume": @9, @"selectedSoundName": @"missing",
                         @"defaultWorkMinutes": @(-3), @"shortBreakMinutes": @999,
                         @"longBreakMinutes": @10, @"longBreakEvery": @6,
                         @"completedWorkSessions": @45,
                         @"lastMeaningfulFocusAt": [NSNull null] }
    };
    [[NSFileManager defaultManager] createDirectoryAtURL:[url URLByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:0 error:nil];
    [data writeToURL:url atomically:YES];

    SKAppStore *store = [[SKAppStore alloc] initWithStorageURL:url];
    [store load];
    SKAssert(store.tasks.count == 1 && store.records.count == 1,
             @"损坏数组元素应跳过，合法元素应保留");
    SKAssert(store.soundVolume == 1 && [store.selectedSoundName isEqualToString:@"Glass"],
             @"声音设置必须限制到安全范围");
    SKAssert(store.defaultWorkMinutes == 1 && store.shortBreakMinutes == 60,
             @"番茄设置必须限制到安全范围");
    SKAssert([store save:nil], @"兼容旧版长休息设置后应能正常保存");
    NSDictionary *savedRoot = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:url] options:0 error:nil];
    NSDictionary *savedSettings = savedRoot[@"settings"];
    SKAssert(savedSettings[@"longBreakMinutes"] == nil &&
             savedSettings[@"longBreakEvery"] == nil &&
             savedSettings[@"completedWorkSessions"] == nil,
             @"旧版跨天累计长休息设置必须在下次保存时清理，不能继续影响计时");
    SKFocusRecord *record = store.records.firstObject;
    SKAssert(record.actualSeconds == 300 && !record.countedAsTomato,
             @"损坏记录的时长和番茄计数必须修正");
    SKAssert([record.endedAt compare:record.startedAt] != NSOrderedAscending,
             @"记录结束时间不能早于开始时间");
}

static void testTaskSelectionAndPinnedOrdering(void) {
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"shike-order-test-%@/data.json", NSUUID.UUID.UUIDString]]];
    SKAppStore *store = [[SKAppStore alloc] initWithStorageURL:url];
    SKTask *pinned = [store addTaskWithTitle:@"置顶"];
    pinned.pinned = YES;
    SKTask *first = [store addTaskWithTitle:@"普通一"];
    SKTask *second = [store addTaskWithTitle:@"普通二"];
    [store moveTaskAtIndex:1 byOffset:-1];
    SKAssert([store.activeTasks[0] isEqual:pinned] && [store.activeTasks[1] isEqual:first],
             @"普通任务不能越过置顶分组造成假移动");
    [store moveTaskAtIndex:2 byOffset:-1];
    SKAssert([store.activeTasks[1] isEqual:second] && [store.activeTasks[2] isEqual:first],
             @"同分组任务应正常移动");
    store.selectedTaskID = second.identifier;
    second.completedAt = NSDate.date;
    SKAssert(store.selectedTask == nil, @"已完成任务不能继续作为当前专注任务");
    SKTask *untitled = [store addTaskWithTitle:@"  \n "];
    SKAssert([untitled.title isEqualToString:@"未命名任务"], @"核心层不能创建空标题任务");
}

static void testStatisticsIgnoreDeletedRecords(void) {
    NSURL *url = [NSURL fileURLWithPath:
                  [NSTemporaryDirectory() stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"shike-stats-test-%@/data.json", NSUUID.UUID.UUIDString]]];
    SKAppStore *store = [[SKAppStore alloc] initWithStorageURL:url];
    NSDate *now = NSDate.date;
    SKFocusRecord *record = [SKFocusRecord new];
    record.identifier = NSUUID.UUID.UUIDString;
    record.kind = SKSessionKindStandard;
    record.status = @"completed";
    record.plannedSeconds = 1500;
    record.actualSeconds = 1500;
    record.startedAt = [now dateByAddingTimeInterval:-1500];
    record.endedAt = now;
    record.countedAsTomato = YES;
    [store addRecord:record];
    SKAssert([store todayTomatoCountAtDate:now] == 1 && [store todayFocusSecondsAtDate:now] == 1500,
             @"正常记录应进入今日统计");
    [store deleteRecord:record];
    SKAssert([store todayTomatoCountAtDate:now] == 0 && [store todayFocusSecondsAtDate:now] == 0,
             @"回收站记录不能进入今日统计");
}

static void testStorageOverrideForIsolatedQA(void) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"shike-override-%@/data.json", NSUUID.UUID.UUIDString]];
    setenv("SHIKE_DATA_PATH", path.UTF8String, 1);
    SKAssert([SKAppStore.defaultStorageURL.path isEqualToString:path],
             @"QA 验收必须能够使用隔离数据文件");
    unsetenv("SHIKE_DATA_PATH");
}

int main(void) {
    @autoreleasepool {
        testTimerStartPauseResume();
        testPersistenceRoundTrip();
        testSnapshotRestore();
        testOneOffDurationCanOnlyChangeBeforeStart();
        testSoftDeleteAndRestore();
        testBreakDoesNotCountAsFocus();
        testTimerBoundaryTransitions();
        testInvalidSnapshotsAreRejected();
        testCorruptPersistenceIsSanitized();
        testTaskSelectionAndPinnedOrdering();
        testStatisticsIgnoreDeletedRecords();
        testStorageOverrideForIsolatedQA();
        NSLog(@"✅ ShikeCoreTests 全部通过");
    }
    return 0;
}
