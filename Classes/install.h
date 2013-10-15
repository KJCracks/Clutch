//
//  install.h
//  Clutch
//
//  Created by Terence Tan on 15/10/13.
//
//

#import <Foundation/Foundation.h>

NSString* generateUuidString();
NSString* install_and_crack(NSString* ipa, NSString* binary, NSString* outbinary);