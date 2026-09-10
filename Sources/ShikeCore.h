#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * SKSessionKind NS_TYPED_ENUM;
FOUNDATION_EXPORT SKSessionKind const SKSessionKindStarter;
FOUNDATION_EXPORT SKSessionKind const SKSessionKindStandard;
FOUNDATION_EXPORT SKSessionKind const SKSessionKindCustom;
FOUNDATION_EXPORT SKSessionKind const SKSessionKindShortBreak;
FOUNDATION_EXPORT SKSessionKind const SKSessionKindLongBreak;

typedef NSString * SKTimerPhase NS_TYPED_ENUM;
FOUNDATION_EXPORT SKTimerPhase const SKTimerPhaseReady;
FOUNDATION_EXPORT SKTimerPhase const SKTimerPhaseRunning;
FOUNDATION_EXPORT SKTimerPhase const SKTimerPhasePaused;
FOUNDATION_EXPORT SKTimerPhase const SKTimerPhaseTransition;

@interface SKSubtask : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic) BOOL completed;
@property(nonatomic) double sortOrder;

+ (instancetype)subtaskWithTitle:(NSString *)title sortOrder:(double)sortOrder;
+ (nullable instancetype)subtaskFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface SKTask : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, strong) NSDate *createdAt;
@property(nonatomic, strong, nullable) NSDate *completedAt;
@property(nonatomic, strong, nullable) NSDate *deletedAt;
@property(nonatomic) double sortOrder;
@property(nonatomic) BOOL pinned;
@property(nonatomic) NSInteger estimatedPomos;
@property(nonatomic, copy, nullable) NSString *note;
@property(nonatomic, strong, nullable) NSDate *reminderAt;
@property(nonatomic, copy) NSString *repeatRule;
@property(nonatomic, copy) NSArray<NSString *> *tags;
@property(nonatomic, strong) NSMutableArray<SKSubtask *> *subtasks;

+ (instancetype)taskWithTitle:(NSString *)title sortOrder:(double)sortOrder;
+ (nullable instancetype)taskFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface SKFocusRecord : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy, nullable) NSString *chainID;
@property(nonatomic, copy, nullable) NSString *taskID;
@property(nonatomic, copy, nullable) NSString *taskTitleSnapshot;
@property(nonatomic, copy) SKSessionKind kind;
@property(nonatomic, copy) NSString *status;
@property(nonatomic) NSInteger plannedSeconds;
@property(nonatomic) NSInteger actualSeconds;
@property(nonatomic, strong) NSDate *startedAt;
@property(nonatomic, strong) NSDate *endedAt;
@property(nonatomic) BOOL countedAsTomato;
@property(nonatomic, copy, nullable) NSString *logSummary;
@property(nonatomic, copy, nullable) NSString *logDetail;
@property(nonatomic, copy, nullable) NSString *interruptionReason;
@property(nonatomic, strong, nullable) NSDate *deletedAt;

+ (nullable instancetype)recordFromDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;
@end

@interface SKAppStore : NSObject
@property(nonatomic, strong, readonly) NSMutableArray<SKTask *> *tasks;
@property(nonatomic, strong, readonly) NSMutableArray<SKFocusRecord *> *records;
@property(nonatomic, copy, nullable) NSString *selectedTaskID;
@property(nonatomic, strong, nullable) NSDate *lastMeaningfulFocusAt;
@property(nonatomic) BOOL soundEnabled;
@property(nonatomic, copy) NSString *selectedSoundName;
@property(nonatomic) double soundVolume;
@property(nonatomic) NSInteger defaultWorkMinutes;
@property(nonatomic) NSInteger shortBreakMinutes;
@property(nonatomic) BOOL endlessMode;
@property(nonatomic) BOOL showCountdownInMenuBar;
@property(nonatomic) BOOL showDockIcon;
@property(nonatomic) BOOL popupNotifications;
@property(nonatomic) BOOL launchAtLogin;
@property(nonatomic) BOOL recordInterruptionReason;
@property(nonatomic, copy, nullable) NSDictionary *activeTimerSnapshot;

- (instancetype)initWithStorageURL:(NSURL *)storageURL;
+ (NSURL *)defaultStorageURL;
- (void)load;
- (BOOL)save:(NSError * _Nullable * _Nullable)error;
- (SKTask *)addTaskWithTitle:(NSString *)title;
- (void)deleteTask:(SKTask *)task;
- (void)restoreTask:(SKTask *)task;
- (void)permanentlyDeleteTask:(SKTask *)task;
- (void)moveTaskAtIndex:(NSUInteger)index byOffset:(NSInteger)offset;
- (NSArray<SKTask *> *)activeTasks;
- (NSArray<SKTask *> *)deletedTasks;
- (nullable SKTask *)selectedTask;
- (void)addRecord:(SKFocusRecord *)record;
- (void)deleteRecord:(SKFocusRecord *)record;
- (void)restoreRecord:(SKFocusRecord *)record;
- (void)permanentlyDeleteRecord:(SKFocusRecord *)record;
- (NSArray<SKFocusRecord *> *)activeRecords;
- (NSArray<SKFocusRecord *> *)deletedRecords;
- (NSInteger)todayTomatoCountAtDate:(NSDate *)date;
- (NSInteger)todayFocusSecondsAtDate:(NSDate *)date;
@end

@interface SKTimerEngine : NSObject
@property(nonatomic, copy, readonly) SKTimerPhase phase;
@property(nonatomic, copy, readonly) SKSessionKind sessionKind;
@property(nonatomic, readonly) NSInteger plannedSeconds;
@property(nonatomic, readonly) NSInteger storedRemainingSeconds;
@property(nonatomic, readonly) NSInteger accumulatedFocusSeconds;
@property(nonatomic, strong, readonly, nullable) NSDate *sessionStartedAt;
@property(nonatomic, strong, readonly, nullable) NSDate *expectedEndAt;
@property(nonatomic, copy, readonly, nullable) NSString *taskID;
@property(nonatomic, copy, readonly, nullable) NSString *taskTitle;
@property(nonatomic, copy, readonly, nullable) NSString *chainID;

- (void)prepareSessionKind:(SKSessionKind)kind
           durationSeconds:(NSInteger)durationSeconds
                    taskID:(nullable NSString *)taskID
                 taskTitle:(nullable NSString *)taskTitle
                   chainID:(nullable NSString *)chainID;
- (void)prepareTransitionWithDurationSeconds:(NSInteger)durationSeconds
                                      taskID:(nullable NSString *)taskID
                                   taskTitle:(nullable NSString *)taskTitle
                                     chainID:(nullable NSString *)chainID
                                      atDate:(NSDate *)date;
- (void)startAtDate:(NSDate *)date;
- (void)pauseAtDate:(NSDate *)date;
- (void)resumeAtDate:(NSDate *)date;
- (BOOL)updatePreparedDurationSeconds:(NSInteger)durationSeconds;
- (NSInteger)remainingSecondsAtDate:(NSDate *)date;
- (NSInteger)actualFocusSecondsAtDate:(NSDate *)date;
- (BOOL)isWorkSession;
- (BOOL)hasReachedEndAtDate:(NSDate *)date;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;
@end

NS_ASSUME_NONNULL_END
