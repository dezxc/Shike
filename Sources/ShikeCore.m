#import "ShikeCore.h"

SKSessionKind const SKSessionKindStarter = @"starter";
SKSessionKind const SKSessionKindStandard = @"standard";
SKSessionKind const SKSessionKindCustom = @"custom";
SKSessionKind const SKSessionKindShortBreak = @"shortBreak";
SKSessionKind const SKSessionKindLongBreak = @"longBreak";

SKTimerPhase const SKTimerPhaseReady = @"ready";
SKTimerPhase const SKTimerPhaseRunning = @"running";
SKTimerPhase const SKTimerPhasePaused = @"paused";
SKTimerPhase const SKTimerPhaseTransition = @"transition";

static NSTimeInterval SKDateValue(id value) {
    return [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0;
}

static NSString *SKStringValue(id value, NSString *fallback) {
    return [value isKindOfClass:NSString.class] ? value : fallback;
}

static NSDate *SKOptionalDate(id value) {
    return [value respondsToSelector:@selector(doubleValue)] ?
        [NSDate dateWithTimeIntervalSince1970:[value doubleValue]] : nil;
}

static BOOL SKDictionary(id value) {
    return [value isKindOfClass:NSDictionary.class];
}

static NSArray *SKArray(id value) {
    return [value isKindOfClass:NSArray.class] ? value : @[];
}

static BOOL SKValidSessionKind(NSString *kind) {
    return [@[SKSessionKindStarter, SKSessionKindStandard, SKSessionKindCustom,
              SKSessionKindShortBreak, SKSessionKindLongBreak] containsObject:kind];
}

@implementation SKSubtask

+ (instancetype)subtaskWithTitle:(NSString *)title sortOrder:(double)sortOrder {
    SKSubtask *subtask = [SKSubtask new];
    subtask.identifier = NSUUID.UUID.UUIDString;
    subtask.title = title;
    subtask.sortOrder = sortOrder;
    return subtask;
}

+ (instancetype)subtaskFromDictionary:(NSDictionary *)dictionary {
    if (!SKDictionary(dictionary)) return nil;
    NSString *identifier = SKStringValue(dictionary[@"id"], @"");
    NSString *title = SKStringValue(dictionary[@"title"], @"");
    if (identifier.length == 0 || title.length == 0) return nil;
    SKSubtask *subtask = [SKSubtask new];
    subtask.identifier = identifier;
    subtask.title = title;
    subtask.completed = [dictionary[@"completed"] boolValue];
    subtask.sortOrder = [dictionary[@"sortOrder"] doubleValue];
    return subtask;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"id": self.identifier,
        @"title": self.title,
        @"completed": @(self.completed),
        @"sortOrder": @(self.sortOrder)
    };
}

@end

@implementation SKTask

+ (instancetype)taskWithTitle:(NSString *)title sortOrder:(double)sortOrder {
    SKTask *task = [SKTask new];
    task.identifier = NSUUID.UUID.UUIDString;
    task.title = title;
    task.createdAt = NSDate.date;
    task.sortOrder = sortOrder;
    task.repeatRule = @"none";
    task.tags = @[];
    task.subtasks = [NSMutableArray array];
    return task;
}

+ (instancetype)taskFromDictionary:(NSDictionary *)dictionary {
    if (!SKDictionary(dictionary)) return nil;
    NSString *identifier = SKStringValue(dictionary[@"id"], @"");
    NSString *title = SKStringValue(dictionary[@"title"], @"");
    if (identifier.length == 0 || title.length == 0) return nil;
    SKTask *task = [SKTask new];
    task.identifier = identifier;
    task.title = title;
    NSTimeInterval createdAt = SKDateValue(dictionary[@"createdAt"]);
    task.createdAt = createdAt > 0 ? [NSDate dateWithTimeIntervalSince1970:createdAt] : NSDate.date;
    task.completedAt = SKOptionalDate(dictionary[@"completedAt"]);
    task.deletedAt = SKOptionalDate(dictionary[@"deletedAt"]);
    task.sortOrder = [dictionary[@"sortOrder"] doubleValue];
    task.pinned = [dictionary[@"pinned"] boolValue];
    task.estimatedPomos = MAX(0, [dictionary[@"estimatedPomos"] integerValue]);
    task.note = SKStringValue(dictionary[@"note"], nil);
    task.reminderAt = SKOptionalDate(dictionary[@"reminderAt"]);
    task.repeatRule = SKStringValue(dictionary[@"repeatRule"], @"none");
    NSArray *tags = [dictionary[@"tags"] isKindOfClass:NSArray.class] ? dictionary[@"tags"] : @[];
    NSMutableArray *safeTags = [NSMutableArray array];
    for (id tag in tags) if ([tag isKindOfClass:NSString.class] && [tag length]) [safeTags addObject:tag];
    task.tags = safeTags;
    task.subtasks = [NSMutableArray array];
    for (id item in SKArray(dictionary[@"subtasks"])) {
        if (!SKDictionary(item)) continue;
        SKSubtask *subtask = [SKSubtask subtaskFromDictionary:item];
        if (subtask) [task.subtasks addObject:subtask];
    }
    [task.subtasks sortUsingComparator:^NSComparisonResult(SKSubtask *a, SKSubtask *b) {
        return a.sortOrder < b.sortOrder ? NSOrderedAscending :
               a.sortOrder > b.sortOrder ? NSOrderedDescending : NSOrderedSame;
    }];
    return task;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *result = [@{
        @"id": self.identifier,
        @"title": self.title,
        @"createdAt": @(self.createdAt.timeIntervalSince1970),
        @"sortOrder": @(self.sortOrder),
        @"pinned": @(self.pinned),
        @"estimatedPomos": @(MAX(0, self.estimatedPomos)),
        @"repeatRule": self.repeatRule ?: @"none",
        @"tags": self.tags ?: @[]
    } mutableCopy];
    if (self.completedAt) result[@"completedAt"] = @(self.completedAt.timeIntervalSince1970);
    if (self.deletedAt) result[@"deletedAt"] = @(self.deletedAt.timeIntervalSince1970);
    if (self.note.length) result[@"note"] = self.note;
    if (self.reminderAt) result[@"reminderAt"] = @(self.reminderAt.timeIntervalSince1970);
    NSMutableArray *subtasks = [NSMutableArray arrayWithCapacity:self.subtasks.count];
    for (SKSubtask *subtask in self.subtasks) [subtasks addObject:subtask.dictionaryRepresentation];
    result[@"subtasks"] = subtasks;
    return result;
}

@end

@implementation SKFocusRecord

+ (instancetype)recordFromDictionary:(NSDictionary *)dictionary {
    if (!SKDictionary(dictionary)) return nil;
    NSString *identifier = SKStringValue(dictionary[@"id"], @"");
    if (identifier.length == 0) return nil;
    NSTimeInterval startedValue = SKDateValue(dictionary[@"startedAt"]);
    NSTimeInterval endedValue = SKDateValue(dictionary[@"endedAt"]);
    if (startedValue <= 0 || endedValue <= 0) return nil;
    SKFocusRecord *record = [SKFocusRecord new];
    record.identifier = identifier;
    record.chainID = SKStringValue(dictionary[@"chainID"], nil);
    record.taskID = SKStringValue(dictionary[@"taskID"], nil);
    record.taskTitleSnapshot = SKStringValue(dictionary[@"taskTitleSnapshot"], nil);
    NSString *kind = SKStringValue(dictionary[@"kind"], SKSessionKindStandard);
    record.kind = SKValidSessionKind(kind) ? kind : SKSessionKindStandard;
    NSString *status = SKStringValue(dictionary[@"status"], @"completed");
    record.status = [@[@"completed", @"aborted"] containsObject:status] ? status : @"completed";
    record.plannedSeconds = MIN(24 * 60 * 60, MAX(1, [dictionary[@"plannedSeconds"] integerValue]));
    record.actualSeconds = MIN(record.plannedSeconds, MAX(0, [dictionary[@"actualSeconds"] integerValue]));
    record.startedAt = [NSDate dateWithTimeIntervalSince1970:startedValue];
    record.endedAt = [NSDate dateWithTimeIntervalSince1970:MAX(startedValue, endedValue)];
    record.countedAsTomato = [dictionary[@"countedAsTomato"] boolValue] &&
                             [record.status isEqualToString:@"completed"] &&
                             ![record.kind isEqualToString:SKSessionKindStarter];
    record.logSummary = SKStringValue(dictionary[@"logSummary"], nil);
    record.logDetail = SKStringValue(dictionary[@"logDetail"], nil);
    record.interruptionReason = SKStringValue(dictionary[@"interruptionReason"], nil);
    record.deletedAt = SKOptionalDate(dictionary[@"deletedAt"]);
    return record;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *result = [@{
        @"id": self.identifier,
        @"kind": self.kind,
        @"status": self.status,
        @"plannedSeconds": @(self.plannedSeconds),
        @"actualSeconds": @(self.actualSeconds),
        @"startedAt": @(self.startedAt.timeIntervalSince1970),
        @"endedAt": @(self.endedAt.timeIntervalSince1970),
        @"countedAsTomato": @(self.countedAsTomato)
    } mutableCopy];
    if (self.chainID) result[@"chainID"] = self.chainID;
    if (self.taskID) result[@"taskID"] = self.taskID;
    if (self.taskTitleSnapshot) result[@"taskTitleSnapshot"] = self.taskTitleSnapshot;
    if (self.logSummary) result[@"logSummary"] = self.logSummary;
    if (self.logDetail) result[@"logDetail"] = self.logDetail;
    if (self.interruptionReason) result[@"interruptionReason"] = self.interruptionReason;
    if (self.deletedAt) result[@"deletedAt"] = @(self.deletedAt.timeIntervalSince1970);
    return result;
}

@end

@interface SKAppStore ()
@property(nonatomic, strong) NSURL *storageURL;
@property(nonatomic, strong, readwrite) NSMutableArray<SKTask *> *tasks;
@property(nonatomic, strong, readwrite) NSMutableArray<SKFocusRecord *> *records;
@end

@implementation SKAppStore

- (instancetype)initWithStorageURL:(NSURL *)storageURL {
    self = [super init];
    if (self) {
        _storageURL = storageURL;
        _tasks = [NSMutableArray array];
        _records = [NSMutableArray array];
        _soundEnabled = YES;
        _selectedSoundName = @"Glass";
        _soundVolume = 0.75;
        _defaultWorkMinutes = 25;
        _shortBreakMinutes = 5;
        _showCountdownInMenuBar = YES;
        _showDockIcon = YES;
        _popupNotifications = YES;
    }
    return self;
}

+ (NSURL *)defaultStorageURL {
    NSString *overridePath = NSProcessInfo.processInfo.environment[@"SHIKE_DATA_PATH"];
    if (overridePath.length) return [NSURL fileURLWithPath:overridePath];
    NSURL *base = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                         inDomain:NSUserDomainMask
                                                appropriateForURL:nil
                                                           create:YES
                                                            error:nil];
    return [[base URLByAppendingPathComponent:@"Shike" isDirectory:YES]
            URLByAppendingPathComponent:@"data.json"];
}

- (void)load {
    NSData *data = [NSData dataWithContentsOfURL:self.storageURL];
    if (!data) return;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![root isKindOfClass:NSDictionary.class]) return;

    [self.tasks removeAllObjects];
    for (id item in SKArray(root[@"tasks"])) {
        if (!SKDictionary(item)) continue;
        SKTask *task = [SKTask taskFromDictionary:item];
        if (task) [self.tasks addObject:task];
    }
    [self.tasks sortUsingComparator:^NSComparisonResult(SKTask *a, SKTask *b) {
        if (a.sortOrder < b.sortOrder) return NSOrderedAscending;
        if (a.sortOrder > b.sortOrder) return NSOrderedDescending;
        return [a.createdAt compare:b.createdAt];
    }];

    [self.records removeAllObjects];
    for (id item in SKArray(root[@"records"])) {
        if (!SKDictionary(item)) continue;
        SKFocusRecord *record = [SKFocusRecord recordFromDictionary:item];
        if (record) [self.records addObject:record];
    }
    [self.records sortUsingComparator:^NSComparisonResult(SKFocusRecord *a, SKFocusRecord *b) {
        return [b.startedAt compare:a.startedAt];
    }];

    NSDictionary *settings = [root[@"settings"] isKindOfClass:NSDictionary.class] ? root[@"settings"] : @{};
    self.selectedTaskID = SKStringValue(settings[@"selectedTaskID"], nil);
    id lastFocus = settings[@"lastMeaningfulFocusAt"];
    NSTimeInterval lastFocusValue = [lastFocus respondsToSelector:@selector(doubleValue)] ? [lastFocus doubleValue] : 0;
    self.lastMeaningfulFocusAt = lastFocusValue > 0 ? [NSDate dateWithTimeIntervalSince1970:lastFocusValue] : nil;
    if (settings[@"soundEnabled"] != nil) self.soundEnabled = [settings[@"soundEnabled"] boolValue];
    NSString *soundName = SKStringValue(settings[@"selectedSoundName"], @"Glass");
    self.selectedSoundName = [@[@"Glass", @"Ping", @"Submarine"] containsObject:soundName] ? soundName : @"Glass";
    if (settings[@"soundVolume"] != nil) self.soundVolume = MIN(1, MAX(0, [settings[@"soundVolume"] doubleValue]));
    if (settings[@"defaultWorkMinutes"] != nil) self.defaultWorkMinutes = MIN(180, MAX(1, [settings[@"defaultWorkMinutes"] integerValue]));
    if (settings[@"shortBreakMinutes"] != nil) self.shortBreakMinutes = MIN(60, MAX(1, [settings[@"shortBreakMinutes"] integerValue]));
    self.endlessMode = [settings[@"endlessMode"] boolValue];
    if (settings[@"showCountdownInMenuBar"] != nil) self.showCountdownInMenuBar = [settings[@"showCountdownInMenuBar"] boolValue];
    if (settings[@"showDockIcon"] != nil) self.showDockIcon = [settings[@"showDockIcon"] boolValue];
    if (settings[@"popupNotifications"] != nil) self.popupNotifications = [settings[@"popupNotifications"] boolValue];
    self.launchAtLogin = [settings[@"launchAtLogin"] boolValue];
    self.recordInterruptionReason = [settings[@"recordInterruptionReason"] boolValue];
    self.activeTimerSnapshot = [root[@"activeTimer"] isKindOfClass:NSDictionary.class] ? root[@"activeTimer"] : nil;
}

- (BOOL)save:(NSError **)error {
    NSMutableArray *taskData = [NSMutableArray arrayWithCapacity:self.tasks.count];
    for (SKTask *task in self.tasks) [taskData addObject:task.dictionaryRepresentation];
    NSMutableArray *recordData = [NSMutableArray arrayWithCapacity:self.records.count];
    for (SKFocusRecord *record in self.records) [recordData addObject:record.dictionaryRepresentation];

    NSMutableDictionary *settings = [@{
        @"soundEnabled": @(self.soundEnabled),
        @"selectedSoundName": self.selectedSoundName ?: @"Glass",
        @"soundVolume": @(self.soundVolume),
        @"defaultWorkMinutes": @(self.defaultWorkMinutes),
        @"shortBreakMinutes": @(self.shortBreakMinutes),
        @"endlessMode": @(self.endlessMode),
        @"showCountdownInMenuBar": @(self.showCountdownInMenuBar),
        @"showDockIcon": @(self.showDockIcon),
        @"popupNotifications": @(self.popupNotifications),
        @"launchAtLogin": @(self.launchAtLogin),
        @"recordInterruptionReason": @(self.recordInterruptionReason)
    } mutableCopy];
    if (self.selectedTaskID) settings[@"selectedTaskID"] = self.selectedTaskID;
    if (self.lastMeaningfulFocusAt) {
        settings[@"lastMeaningfulFocusAt"] = @(self.lastMeaningfulFocusAt.timeIntervalSince1970);
    }

    NSMutableDictionary *root = [@{
        @"version": @2,
        @"tasks": taskData,
        @"records": recordData,
        @"settings": settings
    } mutableCopy];
    if (self.activeTimerSnapshot) root[@"activeTimer"] = self.activeTimerSnapshot;

    NSURL *directory = [self.storageURL URLByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:directory
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:error]) {
        return NO;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:root
                                                   options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                     error:error];
    if (!data) return NO;
    return [data writeToURL:self.storageURL options:NSDataWritingAtomic error:error];
}

- (SKTask *)addTaskWithTitle:(NSString *)title {
    title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!title.length) title = @"未命名任务";
    double order = self.tasks.lastObject ? self.tasks.lastObject.sortOrder + 1 : 0;
    SKTask *task = [SKTask taskWithTitle:title sortOrder:order];
    [self.tasks addObject:task];
    self.selectedTaskID = task.identifier;
    [self save:nil];
    return task;
}

- (void)deleteTask:(SKTask *)task {
    task.deletedAt = NSDate.date;
    if ([self.selectedTaskID isEqualToString:task.identifier]) self.selectedTaskID = nil;
    [self save:nil];
}

- (void)restoreTask:(SKTask *)task {
    task.deletedAt = nil;
    [self save:nil];
}

- (void)permanentlyDeleteTask:(SKTask *)task {
    [self.tasks removeObject:task];
    if ([self.selectedTaskID isEqualToString:task.identifier]) self.selectedTaskID = nil;
    [self save:nil];
}

- (NSArray<SKTask *> *)activeTasks {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SKTask *task, NSDictionary *bindings) {
        return task.deletedAt == nil;
    }];
    return [[self.tasks filteredArrayUsingPredicate:predicate]
        sortedArrayUsingComparator:^NSComparisonResult(SKTask *a, SKTask *b) {
            if (a.pinned != b.pinned) return a.pinned ? NSOrderedAscending : NSOrderedDescending;
            if (a.sortOrder < b.sortOrder) return NSOrderedAscending;
            if (a.sortOrder > b.sortOrder) return NSOrderedDescending;
            return [a.createdAt compare:b.createdAt];
        }];
}

- (NSArray<SKTask *> *)deletedTasks {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SKTask *task, NSDictionary *bindings) {
        return task.deletedAt != nil;
    }];
    return [[self.tasks filteredArrayUsingPredicate:predicate]
        sortedArrayUsingComparator:^NSComparisonResult(SKTask *a, SKTask *b) {
            return [b.deletedAt compare:a.deletedAt];
        }];
}

- (void)moveTaskAtIndex:(NSUInteger)index byOffset:(NSInteger)offset {
    NSArray<SKTask *> *active = self.activeTasks;
    NSInteger destination = (NSInteger)index + offset;
    if (index >= active.count || destination < 0 || destination >= (NSInteger)active.count) return;
    SKTask *neighbor = active[(NSUInteger)destination];
    SKTask *moving = active[index];
    if (neighbor.pinned != moving.pinned) return;
    NSMutableArray<SKTask *> *ordered = [active mutableCopy];
    SKTask *task = ordered[index];
    [ordered removeObjectAtIndex:index];
    [ordered insertObject:task atIndex:(NSUInteger)destination];
    [ordered enumerateObjectsUsingBlock:^(SKTask *item, NSUInteger idx, BOOL *stop) {
        item.sortOrder = (double)idx;
    }];
    [self save:nil];
}

- (SKTask *)selectedTask {
    for (SKTask *task in self.tasks) {
        if (!task.deletedAt && !task.completedAt && [task.identifier isEqualToString:self.selectedTaskID]) return task;
    }
    return nil;
}

- (void)addRecord:(SKFocusRecord *)record {
    [self.records addObject:record];
    [self.records sortUsingComparator:^NSComparisonResult(SKFocusRecord *a, SKFocusRecord *b) {
        return [b.startedAt compare:a.startedAt];
    }];
    [self save:nil];
}

- (void)deleteRecord:(SKFocusRecord *)record {
    record.deletedAt = NSDate.date;
    [self save:nil];
}

- (void)restoreRecord:(SKFocusRecord *)record {
    record.deletedAt = nil;
    [self save:nil];
}

- (void)permanentlyDeleteRecord:(SKFocusRecord *)record {
    [self.records removeObject:record];
    [self save:nil];
}

- (NSArray<SKFocusRecord *> *)activeRecords {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SKFocusRecord *record, NSDictionary *bindings) {
        return record.deletedAt == nil;
    }];
    return [self.records filteredArrayUsingPredicate:predicate];
}

- (NSArray<SKFocusRecord *> *)deletedRecords {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(SKFocusRecord *record, NSDictionary *bindings) {
        return record.deletedAt != nil;
    }];
    return [[self.records filteredArrayUsingPredicate:predicate]
        sortedArrayUsingComparator:^NSComparisonResult(SKFocusRecord *a, SKFocusRecord *b) {
            return [b.deletedAt compare:a.deletedAt];
        }];
}

- (NSInteger)todayTomatoCountAtDate:(NSDate *)date {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSInteger count = 0;
    for (SKFocusRecord *record in self.activeRecords) {
        if (record.countedAsTomato && [calendar isDate:record.endedAt inSameDayAsDate:date]) count++;
    }
    return count;
}

- (NSInteger)todayFocusSecondsAtDate:(NSDate *)date {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSInteger total = 0;
    for (SKFocusRecord *record in self.activeRecords) {
        if ([calendar isDate:record.endedAt inSameDayAsDate:date]) total += MAX(0, record.actualSeconds);
    }
    return total;
}

@end

@interface SKTimerEngine ()
@property(nonatomic, copy, readwrite) SKTimerPhase phase;
@property(nonatomic, copy, readwrite) SKSessionKind sessionKind;
@property(nonatomic, readwrite) NSInteger plannedSeconds;
@property(nonatomic, readwrite) NSInteger storedRemainingSeconds;
@property(nonatomic, readwrite) NSInteger accumulatedFocusSeconds;
@property(nonatomic, strong, readwrite, nullable) NSDate *sessionStartedAt;
@property(nonatomic, strong, readwrite, nullable) NSDate *expectedEndAt;
@property(nonatomic, strong, nullable) NSDate *phaseStartedAt;
@property(nonatomic, copy, readwrite, nullable) NSString *taskID;
@property(nonatomic, copy, readwrite, nullable) NSString *taskTitle;
@property(nonatomic, copy, readwrite, nullable) NSString *chainID;
@end

@implementation SKTimerEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _phase = SKTimerPhaseReady;
        _sessionKind = SKSessionKindStandard;
        _plannedSeconds = 1500;
        _storedRemainingSeconds = 1500;
    }
    return self;
}

- (void)prepareSessionKind:(SKSessionKind)kind
           durationSeconds:(NSInteger)durationSeconds
                    taskID:(NSString *)taskID
                 taskTitle:(NSString *)taskTitle
                   chainID:(NSString *)chainID {
    self.phase = SKTimerPhaseReady;
    self.sessionKind = SKValidSessionKind(kind) ? kind : SKSessionKindStandard;
    self.plannedSeconds = MAX(1, durationSeconds);
    self.storedRemainingSeconds = self.plannedSeconds;
    self.accumulatedFocusSeconds = 0;
    self.sessionStartedAt = nil;
    self.expectedEndAt = nil;
    self.phaseStartedAt = nil;
    self.taskID = taskID;
    self.taskTitle = taskTitle;
    self.chainID = chainID;
}

- (void)prepareTransitionWithDurationSeconds:(NSInteger)durationSeconds
                                      taskID:(NSString *)taskID
                                   taskTitle:(NSString *)taskTitle
                                     chainID:(NSString *)chainID
                                      atDate:(NSDate *)date {
    self.phase = SKTimerPhaseTransition;
    self.sessionKind = SKSessionKindStarter;
    self.plannedSeconds = MAX(1, durationSeconds);
    self.storedRemainingSeconds = self.plannedSeconds;
    self.accumulatedFocusSeconds = 0;
    self.sessionStartedAt = nil;
    self.phaseStartedAt = date;
    self.expectedEndAt = [date dateByAddingTimeInterval:self.plannedSeconds];
    self.taskID = taskID;
    self.taskTitle = taskTitle;
    self.chainID = chainID;
}

- (void)startAtDate:(NSDate *)date {
    if (![self.phase isEqualToString:SKTimerPhaseReady]) return;
    self.phase = SKTimerPhaseRunning;
    self.sessionStartedAt = date;
    self.phaseStartedAt = date;
    self.accumulatedFocusSeconds = 0;
    self.storedRemainingSeconds = self.plannedSeconds;
    self.expectedEndAt = [date dateByAddingTimeInterval:self.storedRemainingSeconds];
}

- (void)pauseAtDate:(NSDate *)date {
    if (![self.phase isEqualToString:SKTimerPhaseRunning]) return;
    if ([self hasReachedEndAtDate:date]) return;
    NSInteger remaining = [self remainingSecondsAtDate:date];
    self.storedRemainingSeconds = remaining;
    self.accumulatedFocusSeconds = MAX(0, self.plannedSeconds - remaining);
    self.phase = SKTimerPhasePaused;
    self.phaseStartedAt = nil;
    self.expectedEndAt = nil;
}

- (void)resumeAtDate:(NSDate *)date {
    if (![self.phase isEqualToString:SKTimerPhasePaused]) return;
    self.phase = SKTimerPhaseRunning;
    self.phaseStartedAt = date;
    self.expectedEndAt = [date dateByAddingTimeInterval:self.storedRemainingSeconds];
}

- (BOOL)updatePreparedDurationSeconds:(NSInteger)durationSeconds {
    if (![self.phase isEqualToString:SKTimerPhaseReady]) return NO;
    self.plannedSeconds = MAX(1, durationSeconds);
    self.storedRemainingSeconds = self.plannedSeconds;
    return YES;
}

- (NSInteger)remainingSecondsAtDate:(NSDate *)date {
    if (([self.phase isEqualToString:SKTimerPhaseRunning] ||
         [self.phase isEqualToString:SKTimerPhaseTransition]) && self.expectedEndAt) {
        NSInteger calculated = MAX(0, (NSInteger)ceil([self.expectedEndAt timeIntervalSinceDate:date]));
        return MIN(MAX(0, self.storedRemainingSeconds), calculated);
    }
    return MAX(0, self.storedRemainingSeconds);
}

- (NSInteger)actualFocusSecondsAtDate:(NSDate *)date {
    if ([self.phase isEqualToString:SKTimerPhaseTransition] || !self.isWorkSession) return 0;
    if ([self.phase isEqualToString:SKTimerPhaseRunning]) {
        return MIN(self.plannedSeconds, MAX(0, self.plannedSeconds - [self remainingSecondsAtDate:date]));
    }
    return MIN(self.plannedSeconds, MAX(0, self.accumulatedFocusSeconds));
}

- (BOOL)isWorkSession {
    return ![self.sessionKind isEqualToString:SKSessionKindShortBreak] &&
           ![self.sessionKind isEqualToString:SKSessionKindLongBreak];
}

- (BOOL)hasReachedEndAtDate:(NSDate *)date {
    BOOL active = [self.phase isEqualToString:SKTimerPhaseRunning] ||
                  [self.phase isEqualToString:SKTimerPhaseTransition];
    return active && [self remainingSecondsAtDate:date] <= 0;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *result = [@{
        @"phase": self.phase,
        @"sessionKind": self.sessionKind,
        @"plannedSeconds": @(self.plannedSeconds),
        @"storedRemainingSeconds": @(self.storedRemainingSeconds),
        @"accumulatedFocusSeconds": @(self.accumulatedFocusSeconds)
    } mutableCopy];
    if (self.sessionStartedAt) result[@"sessionStartedAt"] = @(self.sessionStartedAt.timeIntervalSince1970);
    if (self.expectedEndAt) result[@"expectedEndAt"] = @(self.expectedEndAt.timeIntervalSince1970);
    if (self.phaseStartedAt) result[@"phaseStartedAt"] = @(self.phaseStartedAt.timeIntervalSince1970);
    if (self.taskID) result[@"taskID"] = self.taskID;
    if (self.taskTitle) result[@"taskTitle"] = self.taskTitle;
    if (self.chainID) result[@"chainID"] = self.chainID;
    return result;
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) return NO;
    NSString *phase = SKStringValue(dictionary[@"phase"], @"");
    NSSet *validPhases = [NSSet setWithArray:@[
        SKTimerPhaseReady, SKTimerPhaseRunning, SKTimerPhasePaused, SKTimerPhaseTransition
    ]];
    if (![validPhases containsObject:phase]) return NO;
    NSString *kind = SKStringValue(dictionary[@"sessionKind"], @"");
    if (!SKValidSessionKind(kind) || ![dictionary[@"plannedSeconds"] isKindOfClass:NSNumber.class]) return NO;
    NSInteger planned = [dictionary[@"plannedSeconds"] integerValue];
    if (planned < 1 || planned > 24 * 60 * 60) return NO;
    self.phase = phase;
    self.sessionKind = kind;
    self.plannedSeconds = planned;
    self.storedRemainingSeconds = MIN(planned, MAX(0, [dictionary[@"storedRemainingSeconds"] integerValue]));
    self.accumulatedFocusSeconds = MIN(planned, MAX(0, [dictionary[@"accumulatedFocusSeconds"] integerValue]));
    NSNumber *started = dictionary[@"sessionStartedAt"];
    NSNumber *expected = dictionary[@"expectedEndAt"];
    NSNumber *phaseStarted = dictionary[@"phaseStartedAt"];
    self.sessionStartedAt = started ? [NSDate dateWithTimeIntervalSince1970:started.doubleValue] : nil;
    self.expectedEndAt = expected ? [NSDate dateWithTimeIntervalSince1970:expected.doubleValue] : nil;
    self.phaseStartedAt = phaseStarted ? [NSDate dateWithTimeIntervalSince1970:phaseStarted.doubleValue] : nil;
    self.taskID = SKStringValue(dictionary[@"taskID"], nil);
    self.taskTitle = SKStringValue(dictionary[@"taskTitle"], nil);
    self.chainID = SKStringValue(dictionary[@"chainID"], nil);
    BOOL running = [phase isEqualToString:SKTimerPhaseRunning];
    BOOL transition = [phase isEqualToString:SKTimerPhaseTransition];
    if ((running || transition) && (!self.expectedEndAt || !self.phaseStartedAt)) return NO;
    if (running && !self.sessionStartedAt) return NO;
    if ([phase isEqualToString:SKTimerPhasePaused] && self.storedRemainingSeconds <= 0) return NO;
    if ([phase isEqualToString:SKTimerPhaseReady]) {
        self.expectedEndAt = nil;
        self.phaseStartedAt = nil;
    }
    return YES;
}

@end
