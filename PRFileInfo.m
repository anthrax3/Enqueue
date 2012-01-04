#import "PRFileInfo.h"

@implementation PRFileInfo

@synthesize attributes = _attributes;
@synthesize art = _art;
@synthesize tempArt = _tempArt;
@synthesize file = _file;
@synthesize trackid = _trackid;

- (id)init 
{
    if (!(self = [super init])) {return nil;}
    _attributes = nil;
    _art = nil;
    _tempArt = 0;
    _file = 0;
    _trackid = 0;
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"attributes:%@ art:%@ tempArt:%d file:%d",_attributes, _art, _tempArt, _file];
}

+ (PRFileInfo *)fileInfo
{
    return [[[PRFileInfo alloc] init] autorelease];
}

@end