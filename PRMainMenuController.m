#import "PRMainMenuController.h"
#import "PRCore.h"
#import "PRNowPlayingController.h"
#import "PRMainWindowController.h"
#import "PRLibraryViewController.h"
#import "PRTableViewController.h"
#import "PRPlaylistsViewController.h"
#import "PRControlsViewController.h"
#import "PRNowPlayingController.h"
#import "PRMoviePlayer.h"
#import "PRFolderMonitor.h"
#import "NSWindow+Extensions.h"
#import "PRFullRescanOperation.h"
#import "PRLibrary.h"


@implementation PRMainMenuController

// == Initialization =============================

- (id)initWithCore:(PRCore *)core_ {
    if (!(self = [super init])) {return nil;}
    core = core_;
    
    mainMenu = [core mainMenu];
    enqueueMenu = [[mainMenu itemWithTag:1] submenu];
    fileMenu = [[mainMenu itemWithTitle:@"File"] submenu];
    editMenu = [[mainMenu itemWithTitle:@"Edit"] submenu];
    viewMenu = [[mainMenu itemWithTitle:@"View"] submenu];
    controlsMenu = [[mainMenu itemWithTitle:@"Controls"] submenu];
    windowMenu = [[mainMenu itemWithTitle:@"Window"] submenu];
    helpMenu = [[mainMenu itemWithTitle:@"Help"] submenu];
    
    [fileMenu setDelegate:self];
    [enqueueMenu setDelegate:self];
    [viewMenu setDelegate:self];
    [controlsMenu setDelegate:self];
    
    // Enqueue Menu
    NSMenuItem *menuItem = [enqueueMenu itemWithTitle:@"Preferences..."];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(showPreferences)];
    
    // Library Menu
    menuItem = [fileMenu itemWithTag:1];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(newPlaylist)];
    
    menuItem = [fileMenu itemWithTag:2];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(newSmartPlaylist)];
    
    menuItem = [fileMenu itemWithTag:3];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(open)];
    
    menuItem = [fileMenu itemWithTag:4];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(itunesImport)];
    
    menuItem = [fileMenu itemWithTag:5];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(rescanLibrary)];
    
    menuItem = [fileMenu itemWithTag:6];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(duplicateFiles)];
    
    menuItem = [fileMenu itemWithTag:7];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(missingFiles)];
    
    menuItem = [fileMenu itemWithTag:8];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(rescanFullLibrary)];
    
    // Edit Menu
    menuItem = [editMenu itemWithTag:8];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(find)];
    
    // View Menu
    menuItem = [viewMenu itemWithTag:1];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(viewAsList)];
    
    menuItem = [viewMenu itemWithTag:2];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(viewAsAlbumList)];
    
    menuItem = [viewMenu itemWithTag:3];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(toggleArtwork)];
    
    menuItem = [viewMenu itemWithTag:4];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(showInfo)];
    
    menuItem = [viewMenu itemWithTag:5];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(showCurrentSong)];
    
    menuItem = [viewMenu itemWithTag:6];
    [menuItem setTarget:nil];
    [menuItem setAction:@selector(toggleFullScreen:)];
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_6) {
        [menuItem setHidden:TRUE];
    }
    
    menuItem = [viewMenu itemWithTag:7];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(toggleMiniPlayer)];
    
    // Controls Menu
    menuItem = [controlsMenu itemWithTag:1];
    [menuItem setTarget:[core now]];
    [menuItem setAction:@selector(playPause)];
    
    menuItem = [controlsMenu itemWithTag:2];
    [menuItem setTarget:[core now]];
    [menuItem setAction:@selector(playNext)];
    
    menuItem = [controlsMenu itemWithTag:3];
    [menuItem setTarget:[core now]];
    [menuItem setAction:@selector(playPrevious)];
    
    menuItem = [controlsMenu itemWithTag:4];
    [menuItem setTarget:[[core now] mov]];
    [menuItem setAction:@selector(increaseVolume)];
    
    menuItem = [controlsMenu itemWithTag:5];
    [menuItem setTarget:[[core now] mov]];
    [menuItem setAction:@selector(decreaseVolume)];
    
    menuItem = [controlsMenu itemWithTag:6];
    [menuItem bind:@"value" toObject:[core now] withKeyPath:@"shuffle" options:nil];
    
    menuItem = [controlsMenu itemWithTag:7];
    [menuItem bind:@"value" toObject:[core now] withKeyPath:@"repeat" options:nil];
    return self;
}

- (void)dealloc {
    [super dealloc];
}

// == Accessors ==================================

- (NSMenu *)dockMenu {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"dockmenu"] autorelease];
    NSMenuItem *item;
    NSString *title;
    
    if ([[core now] currentItem]) {
        title = [[[core db] library] valueForItem:[[core now] currentItem] attr:PRItemAttrTitle];
        title = [NSString stringWithFormat:@"♫ %@",title];
        item = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
        [item setEnabled:FALSE];
        [menu addItem:item];
        
        title = [[[core db] library] artistValueForItem:[[core now] currentItem]];
        item = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
        [item setEnabled:FALSE];
        [menu addItem:item];
        
        title = [[[core db] library] valueForItem:[[core now] currentItem] attr:PRItemAttrAlbum];
        item = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
        [item setEnabled:FALSE];
        [menu addItem:item];
        
        [menu addItem:[NSMenuItem separatorItem]];
    }
    
    if ([[[core now] mov] isPlaying]) {
        title = @"Pause";
    } else {
        title = @"Play";
    }
    item = [[[NSMenuItem alloc] initWithTitle:title action:@selector(playPause) keyEquivalent:@""] autorelease];
    [item setTarget:[core now]];
    [menu addItem:item];

    item = [[[NSMenuItem alloc] initWithTitle:@"Next" action:@selector(playNext) keyEquivalent:@""] autorelease];
    [item setTarget:[core now]];
    [menu addItem:item];
    
    item = [[[NSMenuItem alloc] initWithTitle:@"Previous" action:@selector(playPrevious) keyEquivalent:@""] autorelease];
    [item setTarget:[core now]];
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[[NSMenuItem alloc] initWithTitle:@"Shuffle" action:@selector(toggleShuffle) keyEquivalent:@""] autorelease];
    [item setTarget:[core now]];
    [item setState:[[core now] shuffle]];
    [menu addItem:item];
    
    item = [[[NSMenuItem alloc] initWithTitle:@"Repeat" action:@selector(toggleRepeat) keyEquivalent:@""] autorelease];
    [item setTarget:[core now]];
    [item setState:[[core now] repeat]];
    [menu addItem:item];
    
    return menu;
}

// == Action =====================================

- (void)showPreferences {
    [[core win] setCurrentMode:PRPreferencesMode];
}
         
- (void)newPlaylist {
    [[core win] setCurrentMode:PRPlaylistsMode];
    [[[core win] playlistsViewController] newStaticPlaylist];
}

- (void)newSmartPlaylist {
    [[core win] setCurrentMode:PRPlaylistsMode];
    [[[core win] playlistsViewController] newSmartPlaylist];
}

- (void)open {
    [core showOpenPanel:nil];
}

- (void)itunesImport {
    [core itunesImport:nil];
}

- (void)rescanLibrary {
    [[core folderMonitor] rescan];
}

- (void)rescanFullLibrary {
    [[core opQueue] addOperation:[PRFullRescanOperation operationWithCore:core]];
}

- (void)duplicateFiles {
    
}

- (void)missingFiles {
    
}

- (void)find {
    [[core win] find];
}

- (void)viewAsList {
    [[[core win] libraryViewController] setLibraryViewMode:PRListMode];
}

- (void)viewAsAlbumList {
    [[[core win] libraryViewController] setLibraryViewMode:PRAlbumListMode];
}

- (void)toggleMiniPlayer {
    [[core win] toggleMiniPlayer];
}

- (void)toggleArtwork {
    [[core win] setShowsArtwork:![[core win] showsArtwork]];
}

- (void)showInfo {
    [[[core win] libraryViewController] infoViewToggle];
}

- (void)showCurrentSong {
    [[[core win] controlsViewController] showInLibrary];
}

// == Menu Delegate ==============================

- (void)menuNeedsUpdate:(NSMenu *)menu {
    NSString *title;
    if (![[[core now] mov] isPlaying]) {
        title = @"Play";
    } else {
        title = @"Pause";
    }
    [[controlsMenu itemWithTag:1] setTitle:title];
    if ([[core win] showsArtwork]) {
        title = @"Hide Artwork";
    } else {
        title = @"Show Artwork";
    }
    [[viewMenu itemWithTag:3] setTitle:title];
    if ([[[core win] libraryViewController] infoViewVisible]) {
        title = @"Hide Info Pane";
    } else {
        title = @"Show Info Pane";
    }
    [[viewMenu itemWithTag:4] setTitle:title];
    if ([[core win] miniPlayer]) {
        title = @"Switch to Main Player";
    } else {
        title = @"Switch to Mini Player";
    }
    [[viewMenu itemWithTag:7] setTitle:title];
    
    NSMenu *browser = [[[[core win] libraryViewController] currentViewController] browserHeaderMenu];
    [browser setAutoenablesItems:FALSE];
    [[viewMenu itemWithTitle:@"Browser"] setSubmenu:browser];
    [[viewMenu itemWithTitle:@"Browser"] setEnabled:([[core win] currentMode] == PRLibraryMode && ![[core win] miniPlayer])];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    NSArray *items = [NSArray arrayWithObjects:
                      [viewMenu itemWithTag:1],
                      [viewMenu itemWithTag:2],
                      [viewMenu itemWithTag:4],
                      nil];
    for (NSMenuItem *i in items) {
        if (menuItem == i && [[core win] currentMode] != PRLibraryMode) {
            return FALSE;
        }
    }
    
    if (menuItem == [fileMenu itemWithTag:3] ||
        menuItem == [fileMenu itemWithTag:4] ||
        menuItem == [fileMenu itemWithTag:5] ||
        menuItem == [fileMenu itemWithTag:8]) {
        return [[[core opQueue] operations] count] == 0;
    } else if (menuItem == [viewMenu itemWithTag:1] || 
               menuItem == [viewMenu itemWithTag:2] ||
               menuItem == [viewMenu itemWithTag:3] ||
               menuItem == [viewMenu itemWithTag:4] ||
               menuItem == [viewMenu itemWithTag:5] ||
               menuItem == [editMenu itemWithTag:8] ||
               menuItem == [fileMenu itemWithTag:1]) {
        return ![[core win] miniPlayer];
    } else if (menuItem == [viewMenu itemWithTag:7]) {
        return ![[[core win] window] isFullScreen];
    }
    return TRUE;
}

@end
