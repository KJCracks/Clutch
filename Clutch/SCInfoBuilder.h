//
//  SCInfoBuilder.h
//  Clutch
//
//  Created by Anton Titkov on 03.04.15.
//
//

#import "ClutchBundle.h"

NS_ASSUME_NONNULL_BEGIN

struct sinf_atom {
    uint32_t size;  // size of entire atom structure
    uint32_t name;  // name (usually an ASCII value)
    uint8_t blob[]; // (size - 8) byte long data blob
};

struct sinf_kval {
    uint32_t name; // name of structure
    uint32_t val;  // value of structure
};

@interface SCInfoBuilder : NSObject

+ (nullable NSData *)sinfForBundle:(ClutchBundle *)bundle;
+ (NSDictionary *)parseOriginaleSinfForBundle:(ClutchBundle *)bundle;

@end

NS_ASSUME_NONNULL_END
