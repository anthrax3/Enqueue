#import "PRMediaKeyController.h"
#import "PRCore.h"
#import "SPMediaKeyTap.h"
#import "PRUserDefaults.h"
#import "PRNowPlayingController.h"


@implementation PRMediaKeyController

- (id)initWithCore:(PRCore *)core {
    if (!(self = [super init])) {return nil;}
    _core = core;
    _tap = [[SPMediaKeyTap alloc] initWithDelegate:self];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kMediaKeyUsingBundleIdentifiersDefaultsKey:[SPMediaKeyTap defaultMediaKeyUserBundleIdentifiers]}];
    [_tap startWatchingMediaKeys];
    return self;
}

- (void)dealloc {
    [_tap stopWatchingMediaKeys];
    
    [_tap release];
    [super dealloc];
}

- (void)mediaKeyTap:(SPMediaKeyTap *)keyTap receivedMediaKeyEvent:(NSEvent *)event {
    if ([event type] != NSSystemDefined || [event subtype] != SPSystemDefinedEventMediaKeys) {
        return;
    }
	int keyCode = (([event data1] & 0xFFFF0000) >> 16);
	int keyFlags = ([event data1] & 0x0000FFFF);
	int keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
    
	if (keyState == 1 && [[PRUserDefaults userDefaults] mediaKeys]) {
		switch (keyCode) {
        case NX_KEYTYPE_PLAY:
            [[_core now] playPause];
            return;
        case NX_KEYTYPE_FAST:
            [[_core now] playNext];
            return;
        case NX_KEYTYPE_REWIND:
            [[_core now] playPrevious];
            return;
		}
	}
}

@end