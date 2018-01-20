//
//  ClutchBundle.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import <Foundation/Foundation.h>
#import "Binary.h"

@class Application;

@interface ClutchBundle : NSBundle
{
    @public
    NSOperationQueue *_dumpQueue;
}

@property (nonatomic, retain) ClutchBundle *parentBundle;
@property (nonatomic, retain, readonly) NSString *workingPath;
@property (nonatomic, retain, readonly) NSString *zipFilename;
@property (nonatomic, retain, readonly) NSString *zipPrefix;
@property (nonatomic, retain, readonly) NSURL *enumURL;
@property (nonatomic, retain, readonly) NSURL *bundleContainerURL;
@property (nonatomic, retain, readonly) Binary *executable;

@property (nonatomic, retain, readonly) NSString* displayName;

- (instancetype)initWithBundleInfo:(NSDictionary *)info;
- (void)dumpToDirectoryURL:(NSURL *)directoryURL;
- (void)prepareForDump;

@end
