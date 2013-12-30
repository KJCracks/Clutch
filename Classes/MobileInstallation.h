/*
 * MobileInstallation framework header.
 *
 * Copyright (c) 2013, Cykey (David Murray)
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the <organization> nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef MOBILEINSTALLATION_H_
#define MOBILEINSTALLATION_H_

#include <CoreFoundation/CoreFoundation.h>

#if __cplusplus
extern "C" {
#endif
    
#pragma mark - Definitions
    
    typedef void (*MobileInstallationCallback)(CFDictionaryRef information);
    
#pragma mark - API
    
    /*
     * 'ReturnAttributes' is one (or an array) of the keys in the dictionary returned by MobileInstallationLookup(NULL).
     * Or 'BundleIDs' which tells installd to return only the bundle identifiers.
     * Extra keys:
     *  - SharedDirSize
     *  - StaticDiskUsage <- This is the number of bytes used by the app itself.
     *  - DynamicDiskUsage <- Documents & data that the app has.
     *  - ApplicationSINF
     *  - iTunesMetadata
     *  - iTunesArtwork
     *  - GeoJSON
     *  - NewsstandArtwork
     * Example usage:
     *   NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:@"BundleIDs", @"ReturnAttributes", nil];
     *   CFDictionaryRef data = MobileInstallationLookup((CFDictionaryRef)attributes);
     */
    
    NSDictionary* MobileInstallationLookup(NSDictionary *options);
    
    /*
     * @param bundleIdentifier: (Required) The application's bundle identfier that you wish to uninstall.
     * @param parameters: (Optional) A dictionary of paramenters. You can safely pass NULL.
     * @param callback: (Optional) A callback function. You can safely pass NULL.
     * @param unknown: (Optional) Unknown. You can safely pass NULL.
     * @return:
     *  -1: Something went wrong. E.g your program doesn't have the necessary entitlements.
     *   0: Everything is okay.
     *
     * Your program needs the "com.apple.private.mobileinstall.allowedSPI" entitlement to use this function with an array containing the 'Uninstall' string.
     *
     * Example:
     *  <key>com.apple.private.mobileinstall.allowedSPI</key>
     *  <true/>
     *  <array>
     *      <string>Uninstall</string>
     *  </array>
     *
     */
    
    int MobileInstallationUninstall(CFStringRef bundleIdentifier, CFDictionaryRef parameters, MobileInstallationCallback callback, void *unknown);
    
    /*
     * @param path: (Required) The path to the IPA file that you wish to install.
     * @param parameters: (Optional) A dictionary of paramenters. You can safely pass NULL.
     * @param callback: (Optional) A callback function. You can safely pass NULL.
     * @param unknown: (Optional) Unknown. You can safely pass NULL.
     * @return:
     *  -1: Something went wrong. E.g your program doesn't have the necessary entitlements or the path is wrong.
     *   0: Everything is okay.
     *
     *  Your program needs the "com.apple.private.mobileinstall.allowedSPI" entitlement to use this function with an array containing the 'Install' string.
     *
     *  <key>com.apple.private.mobileinstall.allowedSPI</key>
     *  <array>
     *      <string>Install</string>
     *  </array>
     */
    
    int MobileInstallationInstall(CFStringRef path, CFDictionaryRef parameters, MobileInstallationCallback callback, void *unknown);
    
    /* Same as MobileInstallationInstall. */
    
    int MobileInstallationUpgrade(CFStringRef path, CFDictionaryRef parameters, MobileInstallationCallback callback, void *unknown);
    
    /*
     * Used to rebuild the application map.
     * See http://gitweb.saurik.com/uikittools.git/blob/HEAD:/extrainst_.mm#l114
     * for more information.
     */
    
    int _MobileInstallationRebuildMap(CFBooleanRef rebuildUser, CFBooleanRef rebuildSystem, CFBooleanRef rebuildInternal);
    
#if __cplusplus
}
#endif

#endif /* MOBILEINSTALLATION_H_ */