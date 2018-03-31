//
//  ClutchBundle.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Binary.h"

NS_ASSUME_NONNULL_BEGIN

@interface ClutchBundle : NSBundle

@property (nonatomic, retain) ClutchBundle *parentBundle;
@property (nonatomic, retain, readonly) NSString *workingPath;
@property (nonatomic, retain, readonly) NSString *zipFilename;
@property (nonatomic, retain, readonly) NSString *zipPrefix;
@property (nonatomic, retain, readonly) NSURL *enumURL;
@property (nonatomic, retain, readonly) NSURL *bundleContainerURL;
@property (nonatomic, retain, readonly) Binary *executable;
@property (nonatomic, retain) NSOperationQueue *dumpQueue;
@property (nonatomic, retain, readonly) NSString *displayName;

- (nullable instancetype)initWithBundleInfo:(NSDictionary *)info NS_DESIGNATED_INITIALIZER;
- (void)dumpToDirectoryURL:(NSURL *)directoryURL;
- (void)prepareForDump;

@end

NS_ASSUME_NONNULL_END
