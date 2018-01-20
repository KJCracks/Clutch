@interface LSApplicationProxy : NSObject <NSSecureCoding>

@property (nonatomic, readonly) NSString *itemName;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *applicationType;

@end
