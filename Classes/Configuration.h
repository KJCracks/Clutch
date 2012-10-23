@interface ClutchConfiguration : NSObject {

}

+ (BOOL) setValue:(id)value forKey:(NSString *)key;
+ (id) getValue:(NSString *)key;
+ (BOOL) configWithFile:(NSString *)filename;

@end
