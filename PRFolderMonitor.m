#import "PRFolderMonitor.h"
#include <CoreServices/CoreServices.h>
#import "PRDb.h"
#import "PRCore.h"
#import "PRImportOperation.h"
#import "PRRescanOperation.h"
#import "PRDefaults.h"
#import "NSFileManager+Extensions.h"


@implementation PRFolderMonitor

#pragma mark - Initialization

- (id)initWithCore:(PRCore *)core_ {
    if (!(self = [super init])) {return nil;}
    _core = core_;
    stream = nil;
    [self monitor];
    return self;
}

#pragma mark - Accessors

@synthesize core = _core;
@dynamic monitoredFolders;

- (NSArray *)monitoredFolders {
    return [[PRDefaults sharedDefaults] valueForKey:PRDefaultsMonitoredFolders];
}

- (void)setMonitoredFolders:(NSArray *)folders {
    [[PRDefaults sharedDefaults] setValue:folders forKey:PRDefaultsMonitoredFolders];
    [[PRDefaults sharedDefaults] setValue:@0 forKey:PRDefaultsLastEventStreamEventId];
    [self monitor];
}

- (void)addFolder:(NSURL *)URL {
    if ([[self monitoredFolders] containsObject:URL]) {
        return;
    }
    NSMutableArray *folders = [NSMutableArray arrayWithArray:[self monitoredFolders]];
    [folders addObject:URL];
    [self setMonitoredFolders:[NSArray arrayWithArray:folders]];
}

- (void)removeFolder:(NSURL *)URL {
    if ([[self monitoredFolders] containsObject:URL]) {
        NSMutableArray *folders = [NSMutableArray arrayWithArray:[self monitoredFolders]];
        [folders removeObjectAtIndex:[folders indexOfObject:URL]];
        [self setMonitoredFolders:[NSArray arrayWithArray:folders]];        
    }
}

#pragma mark - Action

- (void)monitor {
    // stop old event monitor
    if (stream) {
        FSEventStreamStop(stream);
        FSEventStreamInvalidate(stream);
        FSEventStreamRelease(stream);
        stream = nil;
    }
    
    // get new paths
    if ([[self monitoredFolders] count] == 0) {
        return;
    }
    NSMutableArray *paths = [NSMutableArray array];
    for (NSURL *i in [self monitoredFolders]) {
        [paths addObject:[i path]];
    }
    // if no event id. add URLs and re-monitor
    if ([[[PRDefaults sharedDefaults] valueForKey:PRDefaultsLastEventStreamEventId] unsignedLongLongValue] == 0) {
        PRRescanOperation *op = [PRRescanOperation operationWithURLs:[self monitoredFolders] core:_core];
        [op setEventId:FSEventsGetCurrentEventId()];
        [op setMonitor:YES];
        [[_core opQueue] addOperation:op];
        return;
    }
    // create and schedule new monitor
    FSEventStreamContext context;
    context.info = (__bridge void *)(self);
    context.version = 0;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    stream = FSEventStreamCreate(NULL, &eventCallback, &context, (__bridge CFArrayRef)paths,
                                 [[[PRDefaults sharedDefaults] valueForKey:PRDefaultsLastEventStreamEventId] unsignedLongLongValue],
                                 5.0, kFSEventStreamCreateFlagNone);
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
}

- (void)rescan {
    PRRescanOperation *op = [PRRescanOperation operationWithURLs:[self monitoredFolders] core:_core];
    [op setEventId:FSEventsGetCurrentEventId()];
    [[_core opQueue] addOperation:op];
}

@end

void eventCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents,
                   void *eventPaths, const FSEventStreamEventFlags eventFlags[],
                   const FSEventStreamEventId eventIds[]) {
    PRFolderMonitor *folderMonitor = (__bridge PRFolderMonitor *)clientCallBackInfo;
    PRCore *core = [folderMonitor core];
    NSFileManager *fm = [[NSFileManager alloc] init];
    char **paths = eventPaths;
    NSLog(@"-");
    NSMutableArray *URLs = [NSMutableArray array];
    for (int i = 0; i < numEvents; i++) {
        NSURL *URL = [NSURL fileURLWithPath:[NSString stringWithCString:paths[i] encoding:NSUTF8StringEncoding]];
        NSLog(@"Change %llu in %s, flags %lu\n", eventIds[i], paths[i], (unsigned long)eventFlags[i]);
        
        // if old event
        if ((eventFlags[i] & kFSEventStreamEventFlagHistoryDone) != 0) { 
            continue;
        }
        
        // if not in monitored folders
        BOOL valid = NO;
        for (NSURL *j in [folderMonitor monitoredFolders]) {
            if ([fm itemAtURL:j containsItemAtURL:URL] || [fm itemAtURL:j equalsItemAtURL:URL]) {
                valid = YES;
            }
        }
        if (!valid) {
            continue;
        }
        [URLs addObject:URL];
    }
    PRRescanOperation *op = [PRRescanOperation operationWithURLs:URLs core:core];
    [op setEventId:eventIds[numEvents - 1]];
    [[core opQueue] addOperation:op];
}
