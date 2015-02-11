//
//  ZipOperation.h
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

#import <Foundation/Foundation.h>

// key for obtaining the current scan count
extern NSString *kScanCountKey;

// key for obtaining the path of an image
extern NSString *kPathKey;

// NSNotification name to tell the Window controller an image file as found
extern NSString *kLoadImageDidFinish;

@interface ZipOperation : NSOperation


@end
