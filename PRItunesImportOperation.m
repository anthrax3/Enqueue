#import "PRItunesImportOperation.h"
#import "PRDb.h"
#import "PRLibrary.h"
#import "PRPlaylists.h"
#import "PRAlbumArtController.h"
#import "PRTaskManager.h"
#import "PRTask.h"
#import "PRCore.h"
#import "PRTagEditor.h"
#import "NSEnumerator+Extensions.h"
#import "NSFileManager+Extensions.h"


@implementation PRItunesImportOperation

- (id)initWithURL:(NSURL *)URL_ core:(PRCore *)core
{
    if (!(self = [super init])) {return nil;}
    _core = core;
    _db = [core db];
    _tempFileCount = 0;
    _fileTrackIdDictionary = [[NSMutableDictionary dictionary] retain];
    iTunesURL = [URL_ retain];
    return self;
}

+ (id)operationWithURL:(NSURL *)URL core:(PRCore *)core
{
    return [[[PRItunesImportOperation alloc] initWithURL:URL core:core] autorelease];
}

- (void)dealloc
{
    [iTunesURL release];
    [_fileTrackIdDictionary release];
    [super dealloc];
}

- (void)main
{
    NSLog(@"begin import");
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    PRTask *task = [PRTask task];
    [task setTitle:@"Importing iTunes..."];
    [[_core taskManager] addTask:task];
    
    // Get tracks
    NSString *errorDescription;
    NSUInteger format;
    NSData *plistXML = [[[[NSFileManager alloc] init] autorelease] contentsAtPath:[iTunesURL path]];
    NSDictionary *plist = (NSDictionary *)[NSPropertyListSerialization propertyListFromData:plistXML
                                                                           mutabilityOption:NSPropertyListImmutable
                                                                                     format:&format
                                                                           errorDescription:&errorDescription];
    NSMutableArray *tracks = [NSMutableArray arrayWithArray:[[plist objectForKey:@"Tracks"] allValues]];
    // Sort and remove invalid tracks
    NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
    for (int i = 0; i < [tracks count]; i++) {
        NSDictionary *track = [tracks objectAtIndex:i];
        if ([[track objectForKey:@"Movie"] boolValue] ||
            [[track objectForKey:@"Podcast"] boolValue] ||
            [[track objectForKey:@"iTunesU"] boolValue] ||
            [[track objectForKey:@"Books"] boolValue] ||
            [[track objectForKey:@"Audiobooks"] boolValue] ||
            [[track objectForKey:@"TV Shows"] boolValue] ||
            ![track objectForKey:@"Location"] ||
            ![track objectForKey:@"Track ID"] ||
            ![NSURL URLWithString:[track objectForKey:@"Location"]]) {
            [indexesToRemove addIndex:i];
        }
    }
    [tracks removeObjectsAtIndexes:indexesToRemove];
    [tracks sortUsingSelector:@selector(trackSort:)];
    
    // Add tracks
    int index = 0; 
    NSEnumerator *enumerator = [tracks objectEnumerator];
    NSArray *nextTracks = nil;
    while ((nextTracks = [enumerator nextXObjects:300])) {
        index += 300;
        [task setTitle:[NSString stringWithFormat:@"Importing iTunes... %d%%", (int)(((float)index/(float)[tracks count]) * 90)]];
        [self addTracks:nextTracks];
        if ([task shouldCancel]) {goto end;}
    }
    
    // Add playlists
    index = 0;
    for (NSDictionary *i in [plist objectForKey:@"Playlists"]) {
        index += 1;
        int percentage = ((float)index/(float)[[plist objectForKey:@"Playlists"] count]) * 9 + 90;
        [task setTitle:[NSString stringWithFormat:@"Importing iTunes... %d%%", percentage]];
        [self addPlaylist:i];
        if ([task shouldCancel]) {goto end;}
    }
end:;
    [[_core taskManager] removeTask:task];
    [pool drain];
    NSLog(@"end import");
}

- (void)addTracks:(NSArray *)tracks
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    // Filter out existing files
    NSMutableIndexSet *toRemove = [NSMutableIndexSet indexSet];
    void (^blk)(void) = ^{
        for (int i = 0; i < [tracks count]; i++) {
            NSURL *u = [NSURL URLWithString:[[tracks objectAtIndex:i] objectForKey:@"Location"]];
            NSArray *similar = [[_db library] filesWithSimilarURL:u]; 
            for (NSNumber *j in similar) {
                // If similar file is equivalent to current URL, set them to be merged
                NSString *uStr = [[_db library] valueForFile:[j intValue] attribute:PRPathFileAttribute];
                if ([uStr isEqualToString:[u absoluteString]] || [[NSFileManager defaultManager] itemAtURL:u equalsItemAtURL:[NSURL URLWithString:uStr]]) {
                    [_fileTrackIdDictionary setValue:j forKey:[[tracks objectAtIndex:i] objectForKey:@"Track ID"]];
                    [toRemove addIndex:i];
                    break;
                }
            }
        }
    };
    [[NSOperationQueue mainQueue] addBlockAndWait:blk];
    // Filter out duplicate files
    NSMutableArray *URLs = [NSMutableArray array];
    for (int i = 0; i < [tracks count]; i++) {
        NSURL *u = [NSURL URLWithString:[[tracks objectAtIndex:i] objectForKey:@"Location"]];
        NSString *name = nil;
        BOOL err = [u getResourceValue:&name forKey:NSURLNameKey error:nil];
        if (!err || !name || [URLs containsObject:name]) {
            [toRemove addIndex:i];
            continue;
        }
        [URLs addObject:name];
    }
    // Get info
    [[_db albumArtController] clearTempArt];
    NSMutableArray *infoArray = [NSMutableArray array];
    for (int i = 0; i < [tracks count]; i++) {
        NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
        if ([toRemove containsIndex:i]) {
            goto end;
        }
        NSDictionary *track = [tracks objectAtIndex:i];
        NSURL *URL = [NSURL URLWithString:[track objectForKey:@"Location"]];
        PRTagEditor *te = [PRTagEditor tagEditorForURL:URL];
        if (!te) {
            goto end;
        }
        NSMutableDictionary *info = [te info];
        if ([track objectForKey:@"Play Date UTC"]) {
            [[info objectForKey:@"attr"] setObject:[[track objectForKey:@"Play Date UTC"] description] forKey:[NSNumber numberWithInt:PRLastPlayedFileAttribute]];
        }
        if ([track objectForKey:@"Play Count"]) {
            [[info objectForKey:@"attr"] setObject:[track objectForKey:@"Play Count"] forKey:[NSNumber numberWithInt:PRPlayCountFileAttribute]];
        }
        if ([track objectForKey:@"Rating"]) {
            [[info objectForKey:@"attr"] setObject:[track objectForKey:@"Rating"] forKey:[NSNumber numberWithInt:PRRatingFileAttribute]];
        }
        if ([track objectForKey:@"Date Added"]) {
            [[info objectForKey:@"attr"] setObject:[[track objectForKey:@"Date Added"] description] forKey:[NSNumber numberWithInt:PRDateAddedFileAttribute]];
        } else {
            [[info objectForKey:@"attr"] setObject:[[NSDate date] description] forKey:[NSNumber numberWithInt:PRDateAddedFileAttribute]];
        }
        [info setObject:[track objectForKey:@"Track ID"] forKey:@"trackid"];
        // Artwork
        int temp = [[_db albumArtController] saveTempArt:[info objectForKey:@"art"]];
        [info setObject:[NSNumber numberWithInt:temp] forKey:@"tempart"];
        [info removeObjectForKey:@"art"];
        [infoArray addObject:info];
    end:
        [pool2 drain];
    }
    // Add files
    blk = ^{
        [_db begin];
        for (NSMutableDictionary *i in infoArray) {
            PRFile f = [[_db library] addFileWithAttributes:[i objectForKey:@"attr"]];
            [i setObject:[NSNumber numberWithInt:f] forKey:@"file"];
            [_fileTrackIdDictionary setValue:[NSNumber numberWithInt:f] forKey:[i objectForKey:@"trackid"]];
        }
        [_db commit];
        [[NSNotificationCenter defaultCenter] postLibraryChanged];
    };
    [[NSOperationQueue mainQueue] addBlockAndWait:blk];
    // Artwork
    for (NSDictionary *i in infoArray) {
        if (![i objectForKey:@"tempart"]) {continue;}
        [[_db albumArtController] setTempArt:[[i objectForKey:@"tempart"] intValue] forFile:[[i objectForKey:@"file"] intValue]];
    }
    [pool drain];
}

- (void)addPlaylist:(NSDictionary *)playlist
{
    // filter out invalid playlists
    if ([[playlist objectForKey:@"Master"] boolValue] || 
        [playlist objectForKey:@"Distinguished Kind"] ||
        [[playlist objectForKey:@"Folder"] boolValue] ||
        [playlist objectForKey:@"Smart Info"]) {return;}
    // Get playlist items
    NSArray *playlistItems = [playlist objectForKey:@"Playlist Items"];
    if (!playlistItems) {
        playlistItems = [NSArray array];
    }
    // Add playlist items
    void (^blk)(void) = ^{
        [_db begin];
        int newPlaylist = [[_db playlists] addStaticPlaylist];
        if ([playlist objectForKey:@"Name"]) {
            [[_db playlists] setValue:[playlist objectForKey:@"Name"] forPlaylist:newPlaylist attribute:PRTitlePlaylistAttribute];
        }
        for (NSDictionary *i in playlistItems) {
            NSNumber *track = [i objectForKey:@"Track ID"];
            if (!track) {continue;}
            NSNumber *file = [_fileTrackIdDictionary objectForKey:track];
            if (!file || ![[_db library] containsFile:[file intValue]]) {continue;}
            [[_db playlists] appendFile:[file intValue] toPlaylist:newPlaylist];
        }
        [_db commit];
        [[NSNotificationCenter defaultCenter] postPlaylistsChanged];
    };
    [[NSOperationQueue mainQueue] addBlockAndWait:blk];
}

@end