#import <Foundation/Foundation.h>
@class PRFileInfo;


typedef enum {
    PRFileTypeUnknown,
    PRFileTypeAPE,
    PRFileTypeASF,
    PRFileTypeFLAC,
    PRFileTypeMP4,
    PRFileTypeMPC,
    PRFileTypeMPEG,
    PRFileTypeOggFLAC,
    PRFileTypeOggVorbis,
    PRFileTypeOggSpeex,
    PRFileTypeAIFF,
    PRFileTypeWAV,
    PRFileTypeTrueAudio,
    PRFileTypeWavPack,
} PRFileType;


@interface PRTagger : NSObject
/* Tags */
+ (PRFileInfo *)infoForURL:(NSURL *)URL;
+ (NSMutableDictionary *)tagsForURL:(NSURL *)URL;
+ (void)setTag:(id)tag forAttribute:(PRItemAttr *)attr URL:(NSURL *)URL;

/* Properties */
+ (NSDate *)lastModifiedAtURL:(NSURL *)URL;
+ (NSDate *)lastModifiedForFileAtPath:(NSString *)path;
+ (NSData *)checkSumForFileAtPath:(NSString *)path;
+ (NSNumber *)sizeForFileAtPath:(NSString *)path;
@end
