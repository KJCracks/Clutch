//
//  Application.m
//  Hand Brake
//
//  Created by Ninja on 28/02/2013.
//  Copyright (c) 2013 Hackulous. All rights reserved.
//

#import "CAApplication.h"
#import "CABinary.h"

@interface CAApplication ()
{
    
    NSString *applicationContainer,    // /private/var/mobile/Applications/C320A08E-1295-4F40-8B4F-9D8A5634CE92/
    *applicationDisplayName,           // what you see on SpringBoard
    *applicationName,                  // AppAddict.app - .app = AppAddict
    *appDirectory,                     // AppAddict.app
    *realUniqueID,                     // C320A08E-1295-4F40-8B4F-9D8A5634CE92
    *applicationVersion,               // 1.0
    *applicationBundleID,              // com.apple.purpleshit
    *applicationExecutableName;        // Clutch-1.3.2-git4
    
    UIImage *applicationIcon;
    NSDictionary *dictRep;
    NSData *applicationSINF;
}

@end

@implementation CAApplication

-(void)alertMessage:(NSString *)message info:(NSString *)info
{
    UIAlertView *alert=[[UIAlertView alloc]initWithTitle:self.applicationDisplayName message:info delegate:nil cancelButtonTitle:@"okie" otherButtonTitles:nil];
    if (message!=nil)
        [alert performSelector:@selector(setSubtitle:) withObject:message];
    [alert show];
}

- (id)initWithAppInfo:(NSDictionary *)info
{
    if (self = [super init]) {
        applicationContainer = info[@"ApplicationContainer"];
        applicationDisplayName = info[@"ApplicationDisplayName"];
        applicationName = info[@"ApplicationName"];
        appDirectory = info[@"ApplicationBasename"];
        realUniqueID = info[@"RealUniqueID"];
        applicationVersion = info[@"ApplicationVersion"];
        applicationBundleID = info[@"ApplicationBundleID"];
        applicationExecutableName = info[@"ApplicationExecutableName"];
        applicationIcon = [self getApplicationIcon];
        applicationSINF = info[@"ApplicationSINF"];
        dictRep = info;
        isCracking = NO;
    }
    return self;
}

NSInteger diff_ms(struct timeval t1, struct timeval t2)
{
    return (((t1.tv_sec - t2.tv_sec) * 1000000) +
            (t1.tv_usec - t2.tv_usec))/1000;
}

- (NSString *)applicationContainer
{
    return applicationContainer;
}

- (NSString *)applicationDisplayName
{
    return applicationDisplayName;
}

- (NSString *)applicationName
{
    return applicationName;
}

- (NSString *)appDirectory
{
    return appDirectory;
}

- (NSString *)realUniqueID
{
    return realUniqueID;
}

- (UIImage *)applicationIcon
{
    return applicationIcon;
}

- (NSString *)applicationVersion
{
    return applicationVersion;
}
- (NSString *)applicationExecutableName
{
    return applicationExecutableName;
}
- (NSString *)applicationBundleID
{
    return applicationBundleID;
}

- (NSData *)applicationSINF
{
    return applicationSINF;
}

- (UIImage *)getApplicationIcon
{
    NSDictionary *infoDictionary = [NSDictionary dictionaryWithContentsOfFile:[[applicationContainer stringByAppendingPathComponent:appDirectory] stringByAppendingPathComponent:@"Info.plist"]];
    
    NSArray *iconPaths = [infoDictionary objectForKey:@"CFBundleIconFiles"];
    
    if (iconPaths == NULL) {
        iconPaths = [[[infoDictionary objectForKey:@"CFBundleIcons"] objectForKey:@"CFBundlePrimaryIcon"] objectForKey:@"CFBundleIconFiles"];
    }
    
    if (iconPaths == NULL) {
        iconPaths = [infoDictionary objectForKey:@"Icon files"];
    }
    
    UIImage *image;
    
    for (int i = 0; i < [iconPaths count]; i++) {
        
        NSString *iconName = [iconPaths objectAtIndex:i];
        
        image = [UIImage imageWithContentsOfFile:[[applicationContainer stringByAppendingPathComponent:appDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",iconName,[iconName pathExtension].length>0?@"":@".png"]]];
        
        CGFloat width = image.size.width;
        CGFloat height = image.size.height;
        
        if ([UIScreen mainScreen].scale == 2) {
            if (width == (float)114 && height == (float)114) {
                break;
            }
        } else {
            if (width == (float)57 && height == (float)57) {
                break;
            }
        }
    }
    
    if (image ==nil) {
        image = [UIImage imageNamed:@"DefaultIcon"];
    }
    
    return image;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, appName: %@, bundleID: %@>",NSStringFromClass([self class]),self,self.applicationName,self.applicationBundleID];
}

#pragma mark Cracking stuff

- (void)crackWithDelegate:(id <CAApplicationDelegate>)delegate additionalLibs:(NSArray *)libs
{
    isCracking=YES;
    
    progress = @{@"status":@"",@"progress":@0};
    
    [delegate crackingProcessStarted:self];
    
    //weed is bad
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(globalQueue, ^{
        NSString *ipapath = nil;
        NSError *error = nil;
        
        //ipapath = crack_application(applicationBaseDirectory, applicationBaseName, applicationVersion,&error);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            isCracking=NO;
            
            [delegate crackingProcessFinished:self];
            
            
            if (error != nil) {
                [self alertMessage:@"Could not crack IPA :(" info:error.userInfo[@"description"]];
            }
            else{
                //int dif = diff_ms(end,start);
                [self alertMessage:[NSString stringWithFormat:@"Cracked IPA at: %@", ipapath] info:nil];
            }
        });
    });
}

@end
