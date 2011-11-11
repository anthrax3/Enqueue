#import "NSFileManager+Extensions.h"

@implementation NSFileManager (Extensions)

- (BOOL)itemAtURL:(NSURL *)u1 containsItemAtURL:(NSURL *)u2
{
    FSRef ref, ref2;
    BOOL err = CFURLGetFSRef((CFURLRef)u1, &ref);
    if (!err) {return FALSE;}
    err = CFURLGetFSRef((CFURLRef)u2, &ref2);
    if (!err) {return FALSE;}
    
    while (TRUE) {        
        // Get parent ref
        FSRef parentRef;
        OSErr e = FSGetCatalogInfo(&ref2, kFSCatInfoNone, NULL, NULL, NULL, &parentRef);
        if (e != noErr) {return FALSE;}
        ref2 = parentRef;
        
        // Check if parent ref is valid
        e = FSGetCatalogInfo(&ref2, kFSCatInfoNone, nil, nil, nil, nil );
        if (e != noErr) {return FALSE;}
        
        // Compare refs
        if (FSCompareFSRefs(&ref, &ref2) == noErr) {
            return TRUE;
        }
    }
    return FALSE;

}

- (BOOL)itemAtURL:(NSURL *)u1 equalsItemAtURL:(NSURL *)u2
{
    NSString *name1 = nil;
    NSString *name2 = nil;
    BOOL err = [u1 getResourceValue:&name1 forKey:NSURLNameKey error:nil];
    BOOL err2 = [u2 getResourceValue:&name2 forKey:NSURLNameKey error:nil];
    if (!err || !err2 || !name1 || !name2) {
        return FALSE;
    }
    return [name1 isEqualToString:name2];
}

- (NSArray *)subDirsAtURL:(NSURL *)URL error:(NSError **)error
{
    NSMutableArray *subdirs = [NSMutableArray array];
    NSArray *contents = [self contentsOfDirectoryAtURL:URL
                            includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] 
                                               options:0 
                                                 error:error];
    if (!contents) {return [NSArray array];}
    
    for (NSURL *i in contents) {
        NSNumber *isDir = nil;
        BOOL err = [i getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:error];
        if (!err || !isDir) {continue;}
        
        if ([isDir boolValue]) {
            [subdirs addObject:i];
        }
    }
    return subdirs;
}

@end