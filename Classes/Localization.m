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
        case zh:
            return zh_locale[message];
            break;
        case de:
            return de_locale[message];
			break;
        case fr:
			return fr_locale[message];
			break;
		case hr:
			return hr_locale[message];
            break;
        case ru:
            return ru_locale[message];
            break;
        case ar:
            return ar_locale[message];
            break;
        case en:
        default:
            return en_locale[message];
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
        DEBUG(@"preferred lang: %@", _preferredLang);
        
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
            // chinese
            lang = zh;
        }
        else if ([[defaultLang lowercaseString] hasPrefix:@"de"]) {
            // german
            lang = de;
        }
        else if ([[defaultLang lowercaseString] hasPrefix:@"fr"]) {
            // french
            lang = fr;
        }
        else if ([[defaultLang lowercaseString] hasPrefix:@"hr"]) {
            // serbian/croatian
            lang = hr;
        }
        else if ([[defaultLang lowercaseString] hasPrefix:@"ru"]){
            // russian
            lang = ru;
        }
        else if ([[defaultLang lowercaseString] hasPrefix:@"ar"]){
            // arabic
            lang = ar;
        }
        else {
            lang = en;
        }
    });
    return lang;
}
-(void)checkCache {
    NSLog(@"checking localization cache");
    if ([_preferredLang count] == 0) {
        int ret = setuid(501); //setuid as mobile, get language
        if (ret == 0)
        {
            // Security broooo
            _preferredLang = [NSLocale preferredLanguages];
            [_preferredLang writeToFile:langCacheTmp atomically:YES];
            setuidPerformed = true;
            
        }
    }
}



@end
