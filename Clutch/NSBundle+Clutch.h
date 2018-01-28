//
//  NSBundle+Clutch.h
//  Clutch
//
//  Created by Anton Titkov on 20.04.15.
//
//

NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (Clutch)

@property (nonatomic, retain, nullable) NSString *clutchBID;
@property (nonatomic, readonly, copy) NSString *bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
