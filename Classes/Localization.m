//
//  Localization.m
//  Clutch
//


#import "Localization.h"
#import "Out.h"

#define langCache @"/etc/clutch-lang-cache.plist"
#define langCacheTmp @"/tmp/clutch-lang-cache.plist"

NSString* msg(Message message) {
    return [[Localization sharedInstance] valueWithMessage:message];
}

@implementation Localization {
    NSArray* _preferredLang;
}

- (NSString*) getLanguage {
    return [_preferredLang objectAtIndex:0];
}

-(NSString*) valueWithMessage:(Message)message {
    switch ([self defaultLang]) {
        case en:
            return en_locale[message];
            break;
        case zh:
            return zh_locale[message];
            break;
        case de:
            return de_locale[message];
    }
}

+ (Localization*) sharedInstance
{
    static dispatch_once_t pred;
    static Localization* shared = nil;
    dispatch_once(&pred, ^{
        shared = [Localization new];
    });
    return shared;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:langCacheTmp]) {
            [[NSFileManager defaultManager] moveItemAtPath:langCacheTmp toPath:langCache error:nil];
        }
        _preferredLang = [[NSArray alloc] initWithContentsOfFile:langCache];
        
    }
    return self;
}
-(Lang) defaultLang {
    static NSString* defaultLang;
    static Lang lang;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        defaultLang = [_preferredLang objectAtIndex:0];
        if ([[defaultLang lowercaseString] hasPrefix:@"zh"]) {
            //chinese
            lang = zh;
        }
        if ([[defaultLang lowercaseString] hasPrefix:@"de"]) {
            //german
            lang = de;
        }
        else {
            lang = en;
        }
    });
    return lang;
}
-(void)checkCache {
    
    if ([_preferredLang count] == 0) {
        setuid(501); //setuid as mobile, get language
        _preferredLang = [NSLocale preferredLanguages];
        [_preferredLang writeToFile:langCacheTmp atomically:YES];
        setuidPerformed = true;
    }
}



@end
