#import <Foundation/Foundation.h>

@interface FBBundleInfo : NSObject {
    id _proxy;
    NSString *_displayName;
    NSString *_bundleIdentifier;
    NSString *_bundleVersion;
    NSString *_bundleType;
    NSURL *_bundleURL;
}

@property (retain, nonatomic) NSURL *bundleURL;                  // @synthesize bundleURL=_bundleURL;
@property (copy, nonatomic) NSString *bundleType;                // @synthesize bundleType=_bundleType;
@property (copy, nonatomic) NSString *bundleVersion;             // @synthesize bundleVersion=_bundleVersion;
@property (copy, nonatomic) NSString *bundleIdentifier;          // @synthesize bundleIdentifier=_bundleIdentifier;
@property (copy, nonatomic) NSString *displayName;               // @synthesize displayName=_displayName;
@property (readonly, retain, nonatomic, getter=_proxy) id proxy; // @synthesize proxy=_proxy;

- (instancetype)initWithApplicationProxy:(id)arg1;

@end

@interface FBApplicationInfo : FBBundleInfo {
    NSURL *_executableURL;
    NSURL *_bundleContainerURL;
    NSURL *_dataContainerURL;
    NSURL *_sandboxURL;
    double _lastModifiedDate;
    NSString *_preferenceDomain;
    NSString *_signerIdentity;
    NSDictionary *_environmentVariables;
    NSDictionary *_entitlements;
    _Bool _provisioningProfileValidated;
    NSString *_sdkVersion;
    NSArray *_customMachServices;
    unsigned long long _type;
    NSArray *_requiredCapabilities;
    NSArray *_tags;
    NSArray *_deviceFamilies;
    _Bool _enabled;
    _Bool _newsstand;
    _Bool _restricted;
    _Bool _beta;
    NSSet *_backgroundModes;
    NSSet *_supportedInterfaceOrientations;
    _Bool _exitsOnSuspend;
    _Bool _requiresPersistentWiFi;
    float _minimumBrightnessLevel;
    NSArray *_externalAccessoryProtocols;
    long long _ratingRank;
    NSArray *_folderNames;
    NSString *_fallbackFolderName;
    _Bool _installing;
    _Bool _uninstalling;
    NSObject<OS_dispatch_queue> *_workQueue;
}

@property (nonatomic, getter=_isUninstalling, setter=_setUninstalling:)
    _Bool uninstalling; // @synthesize uninstalling=_uninstalling;
@property (nonatomic, getter=_isInstalling, setter=_setInstalling:)
    _Bool installing;                                 // @synthesize installing=_installing;
@property (readonly, nonatomic) long long ratingRank; // @synthesize ratingRank=_ratingRank;
@property (readonly, retain, nonatomic)
    NSArray *externalAccessoryProtocols; // @synthesize externalAccessoryProtocols=_externalAccessoryProtocols;
@property (readonly, nonatomic)
    float minimumBrightnessLevel; // @synthesize minimumBrightnessLevel=_minimumBrightnessLevel;
@property (readonly, nonatomic)
    _Bool requiresPersistentWiFi; // @synthesize requiresPersistentWiFi=_requiresPersistentWiFi;
@property (readonly, nonatomic, getter=isExitsOnSuspend)
    _Bool exitsOnSuspend;                                              // @synthesize exitsOnSuspend=_exitsOnSuspend;
@property (readonly, nonatomic, getter=isBeta) _Bool beta;             // @synthesize beta=_beta;
@property (readonly, nonatomic, getter=isRestricted) _Bool restricted; // @synthesize restricted=_restricted;
@property (readonly, nonatomic, getter=isNewsstand) _Bool newsstand;   // @synthesize newsstand=_newsstand;
@property (readonly, nonatomic, getter=isEnabled) _Bool enabled;       // @synthesize enabled=_enabled;
@property (readonly, retain, nonatomic) NSArray *tags;                 // @synthesize tags=_tags;
@property (readonly, retain, nonatomic) NSArray *deviceFamilies;       // @synthesize deviceFamilies=_deviceFamilies;
@property (readonly, retain, nonatomic)
    NSArray *requiredCapabilities;                       // @synthesize requiredCapabilities=_requiredCapabilities;
@property (readonly, nonatomic) unsigned long long type; // @synthesize type=_type;
@property (readonly, retain, nonatomic)
    NSArray *customMachServices;                            // @synthesize customMachServices=_customMachServices;
@property (readonly, copy, nonatomic) NSString *sdkVersion; // @synthesize sdkVersion=_sdkVersion;
@property (readonly, nonatomic, getter=isProvisioningProfileValidated)
    _Bool provisioningProfileValidated; // @synthesize provisioningProfileValidated=_provisioningProfileValidated;
@property (readonly, retain, nonatomic) NSDictionary *entitlements; // @synthesize entitlements=_entitlements;
@property (readonly, retain, nonatomic)
    NSDictionary *environmentVariables; // @synthesize environmentVariables=_environmentVariables;
@property (readonly, copy, nonatomic) NSString *signerIdentity;   // @synthesize signerIdentity=_signerIdentity;
@property (readonly, copy, nonatomic) NSString *preferenceDomain; // @synthesize preferenceDomain=_preferenceDomain;
@property (readonly, nonatomic) double lastModifiedDate;          // @synthesize lastModifiedDate=_lastModifiedDate;
@property (readonly, retain, nonatomic) NSURL *sandboxURL;        // @synthesize sandboxURL=_sandboxURL;
@property (readonly, retain, nonatomic) NSURL *dataContainerURL;  // @synthesize dataContainerURL=_dataContainerURL;
@property (readonly, retain, nonatomic)
    NSURL *bundleContainerURL;                                // @synthesize bundleContainerURL=_bundleContainerURL;
@property (readonly, retain, nonatomic) NSURL *executableURL; // @synthesize executableURL=_executableURL;
- (id)_localizedGenreFromDictionary:(id)arg1;
- (id)_localizedGenreNameForID:(long long)arg1;
- (void)_cacheFolderNamesForSystemApp:(id)arg1;
- (id)_configureEnvironment:(id)arg1;
@property (nonatomic, readonly) long long _computeRatingRank;
@property (nonatomic, readonly, strong) id _copyiTunesMetadata;
- (void)_buildDefaultsFromInfoPlist:(id)arg1;
- (id)_computeSupportedInterfaceOrientations:(id)arg1;
- (void)_acceptApplicationSignatureIdentity;
@property (nonatomic, readonly, strong) id _preferenceDomain;
- (double)_lastModifiedDateForPath:(id)arg1;
- (unsigned long long)_applicationType:(id)arg1;
@property (nonatomic, readonly, strong) id description;
- (_Bool)builtOnOrAfterSDKVersion:(id)arg1;
- (void)acceptApplicationSignatureIdentity;
- (_Bool)supportsInterfaceOrientation:(long long)arg1;
- (_Bool)supportsBackgroundMode:(id)arg1;
@property (readonly, retain, nonatomic)
    NSString *fallbackFolderName;                             // @synthesize fallbackFolderName=_fallbackFolderName;
@property (readonly, retain, nonatomic) NSArray *folderNames; // @synthesize folderNames=_folderNames;
@property (readonly, nonatomic) long long signatureState;     // @dynamic signatureState;
- (void)dealloc;
- (instancetype)initWithApplicationProxy:(id)arg1;

@end
