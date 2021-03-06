#import <Foundation/Foundation.h>
#include "sqlite3.h"
@class PRLibrary;
@class PRPlaylists;
@class PRQueue;
@class PRPlaybackOrder;
@class PRHistory;
@class PRAlbumArtController;

typedef enum {
    PRConnectionTypeReadOnly,
    PRConnectionTypeReadWrite,
} PRConnectionType;

@interface PRConnection : NSObject
- (instancetype)initWithPath:(NSString *)path type:(PRConnectionType)type;
@property (nonatomic, readonly) PRConnectionType type;
@property (nonatomic, readonly) sqlite3 *sqliteDb;
@property (nonatomic, readwrite) NSInteger userVersion;

- (BOOL)zTransaction:(BOOL(^)(void))block;
- (BOOL)zExecute:(NSString *)string;
- (BOOL)zExecute:(NSString *)string bindings:(NSDictionary *)bindings columns:(NSArray *)columns out:(NSArray **)outValue;
- (BOOL)zExecuteCached:(NSString *)string;
- (BOOL)zExecuteCached:(NSString *)string bindings:(NSDictionary *)bindings columns:(NSArray *)columns out:(NSArray **)outValue;

@property (nonatomic, readonly) PRLibrary *library;
@property (nonatomic, readonly) PRPlaylists *playlists;
@property (nonatomic, readonly) PRQueue *queue;
@property (nonatomic, readonly) PRPlaybackOrder *playbackOrder;
@property (nonatomic, readonly) PRHistory *history;
@property (nonatomic, readonly) PRAlbumArtController *albumArtController;
@end

@protocol PRTable <NSObject>
- (instancetype)initWithConnection:(PRConnection *)connection;
@end
