#import "PRCore.h"
#import "PRDb.h"
#import "PRNowPlayingController.h"
#import "PRMainWindowController.h"
#import "PRImportOperation.h"
#import "PRItunesImportOperation.h"
#import "PRFolderMonitor.h"
#import "PRTaskManager.h"
#import "PRDefaults.h"
#import "PRGrowl.h"
#import "PRHotKeyController.h"
#import "PRLastfm.h"
#import "PRVacuumOperation.h"
#import "PRMainMenuController.h"
#import "PRMediaKeyController.h"
#import "PRFullRescanOperation.h"
#import "PRTrialSheetController.h"
#import "PRWelcomeSheetController.h"
#import "NSFileManager+DirectoryLocations.h"
#include "PREnableLogger.h"



@implementation PRCore

#pragma mark - Initialization

- (id)init {
    if (!(self = [super init])) {return nil;}
    // Prevent multiple instances of application
    _connection = [NSConnection connectionWithReceivePort:[NSPort port] sendPort:[NSPort port]];
    if (![_connection registerName:@"enqueue"]) {
        [[PRLog sharedLog] presentFatalError:[self multipleInstancesError]];
    }
    
    NSString *path = [[PRDefaults sharedDefaults] applicationSupportPath];
    if (![[[NSFileManager alloc] init] findOrCreateDirectoryAtPath:path error:nil]) {
        [[PRLog sharedLog] presentFatalError:[self couldNotCreateDirectoryError:path]];
    }
    
    _opQueue = [[NSOperationQueue alloc] init];
    [_opQueue setMaxConcurrentOperationCount:1];
    [_opQueue setSuspended:TRUE];
    _taskManager = [[PRTaskManager alloc] init];
    _db = [[PRDb alloc] initWithCore:self];
    _now = [[PRNowPlayingController alloc] initWithDb:_db]; // requires: db
    _folderMonitor = [[PRFolderMonitor alloc] initWithCore:self]; // requires: opQueue, db & taskManager
    _win = [[PRMainWindowController alloc] initWithCore:self]; // requires: db, now, taskManager, folderMonitor
    _growl  = [[PRGrowl alloc] initWithCore:self];
    _lastfm = [[PRLastfm alloc] initWithCore:self];
    _keys = [[PRMediaKeyController alloc] initWithCore:self];
    _hotKeys = [[PRHotKeyController alloc] initWithCore:self];
    return self;
}

- (void)dealloc {
    [_connection invalidate];
}

- (void)awakeFromNib {
    [_win showWindow:nil];
	[_opQueue setSuspended:FALSE];
    
//    PRTrialSheetController *trialSheet = [[PRTrialSheetController alloc] initWithCore:self]; 
//    [trialSheet beginSheetModalForWindow:[_win window] completionHandler:^{}];
    if ([[PRDefaults sharedDefaults] boolForKey:PRDefaultsShowWelcomeSheet]) {
        [[PRDefaults sharedDefaults] setBool:FALSE forKey:PRDefaultsShowWelcomeSheet];
        PRWelcomeSheetController *welcomeSheet = [[PRWelcomeSheetController alloc] initWithCore:self];
        [welcomeSheet beginSheetModalForWindow:[_win window] completionHandler:^{}];
    }
}

#pragma mark - Accessors

@synthesize db = _db, 
now = _now, 
win = _win, 
opQueue = _opQueue, 
folderMonitor = _folderMonitor, 
taskManager = _taskManager, 
mainMenu = _mainMenu, 
lastfm = _lastfm,
keys = _keys,
hotKeys = _hotKeys;

#pragma mark - Action

- (void)itunesImport:(id)sender {
    NSString *folderPath = [[NSHomeDirectory() stringByAppendingPathComponent:@"Music"] stringByAppendingPathComponent:@"iTunes"];;
    NSString *filePath = [folderPath stringByAppendingPathComponent:@"iTunes Music Library.xml"];
    if ([[[NSFileManager alloc] init] fileExistsAtPath:filePath]) {
        PRItunesImportOperation *op = [PRItunesImportOperation operationWithURL:[NSURL fileURLWithPath:filePath] core:self];
        [_opQueue addOperation:op];
    } else {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setCanChooseFiles:YES];
        [panel setCanChooseDirectories:NO];
        [panel setCanCreateDirectories:NO];
        [panel setTreatsFilePackagesAsDirectories:NO];
        [panel setAllowsMultipleSelection:NO];
        [panel setPrompt:@"Import"];
        [panel setMessage:@"Select the 'iTunes Music Library.xml' file to import."];
        [panel setDirectoryURL:[NSURL fileURLWithPath:filePath]];
        [panel setAllowedFileTypes:@[@"xml"]];
        [panel beginSheetModalForWindow:[_win window] completionHandler:^(NSInteger result) {
            if (result == NSCancelButton || [[panel URLs] count] == 0) {return;}
            PRItunesImportOperation *op = [PRItunesImportOperation operationWithURL:[[panel URLs] objectAtIndex:0] core:self];
            [_opQueue addOperation:op];
        }];
    }
}

- (IBAction)showOpenPanel:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:YES];
    [panel setCanCreateDirectories:NO];
    [panel setTreatsFilePackagesAsDirectories:NO];
    [panel setAllowsMultipleSelection:YES];
    void (^handler)(NSInteger result) = ^(NSInteger result) {
        if (result == NSCancelButton) {return;}
        NSMutableArray *paths = [NSMutableArray array];
        for (NSURL *i in [panel URLs]) {
            [paths addObject:[i path]];
        }
        PRImportOperation *op = [[PRImportOperation alloc] initWithURLs:[panel URLs] core:self];
        [_opQueue addOperation:op];
    };
    [panel beginSheetModalForWindow:[_win window] completionHandler:handler];
}

#pragma mark - NSApplication Delegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        [[_win window] makeKeyAndOrderFront:nil];
    }
    return TRUE;
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)filename {
	NSLog(@"openingFiles:%@",filename);
    NSArray *URLs = @[[NSURL fileURLWithPath:filename]];
    PRImportOperation *op = [PRImportOperation operationWithURLs:URLs core:self];
    [_opQueue addOperation:op];
    return TRUE;
}

- (void)application:(NSApplication *)application openFiles:(NSArray *)filenames {
	NSLog(@"openingFiles:%@",filenames);
    NSMutableArray *URLs = [NSMutableArray array];
    for (NSString *i in filenames) {
        [URLs addObject:[NSURL fileURLWithPath:i]];
    }
    PRImportOperation *op = [PRImportOperation operationWithURLs:URLs core:self];
    [_opQueue addOperation:op]; 
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    NSMenu *menu = [[_win mainMenuController] dockMenu];
    if (menu) {
        return menu;
    }
    return nil;
}

#pragma mark - Error

- (NSError *)multipleInstancesError {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Another instance of Enqueue appears to be running.", NSLocalizedDescriptionKey,
                              @"Close the other instance and try again.", NSLocalizedRecoverySuggestionErrorKey, nil];
    return [NSError errorWithDomain:PREnqueueErrorDomain code:0 userInfo:userInfo];
}

- (NSError *)couldNotCreateDirectoryError:(NSString *)directory; {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"Enqueue could not create the following directory and must close.", NSLocalizedDescriptionKey,
                              directory, NSLocalizedRecoverySuggestionErrorKey,
                              nil];
    return [NSError errorWithDomain:PREnqueueErrorDomain code:0 userInfo:userInfo];
}

@end
