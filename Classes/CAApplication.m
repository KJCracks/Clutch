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
    
   NSString *applicationBaseDirectory,
            *applicationDirectory,
            *applicationDisplayName,
            *applicationName,
            *applicationBaseName,
            *realUniqueID,
            *applicationVersion,
            *applicationBundleID;

    UIImage *applicationIcon;
    NSDictionary *dictRep;
    
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
        applicationBaseDirectory = info[@"ApplicationBaseDirectory"];
        applicationDirectory = info[@"ApplicationDirectory"];
        applicationDisplayName = info[@"ApplicationDisplayName"];
        applicationName = info[@"ApplicationName"];
        applicationBaseName = info[@"ApplicationBasename"];
        realUniqueID = info[@"RealUniqueID"];
        applicationVersion = info[@"ApplicationVersion"];
        applicationBundleID = info[@"ApplicationBundleID"];
        applicationIcon = [self getApplicationIcon];
        dictRep = info;
        isCracking = NO;
    }
    return self;
}

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (((t1.tv_sec - t2.tv_sec) * 1000000) +
            (t1.tv_usec - t2.tv_usec))/1000;
}
- (BOOL)crack {
    CABinary* binary = [[CABinary alloc] init];
    binary
}
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



- (NSString *)applicationBaseDirectory
{
    return applicationBaseDirectory;
}

- (NSString *)applicationDirectory
{
    return applicationDirectory;
}

- (NSString *)applicationDisplayName
{
    return applicationDisplayName;
}

- (NSString *)applicationName
{
    return applicationName;
}

- (NSString *)applicationBaseName
{
    return applicationBaseName;
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

- (NSString *)applicationBundleID
{
    return applicationBundleID;
}

- (UIImage *)getApplicationIcon
{
    NSDictionary *infoDictionary = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Info.plist", applicationDirectory]];
    
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
        
        image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@%@", applicationDirectory,iconName,[iconName pathExtension].length>0?@"":@".png"]];
        
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

@end
