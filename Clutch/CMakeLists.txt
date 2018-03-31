set( CLUTCH_SOURCE_FILES
    ARM64Dumper.h
    ARM64Dumper.m
    ARMDumper.h
    ARMDumper.m
    ASLRDisabler.h
    ASLRDisabler.m
    Application.h
    Application.m
    ApplicationsManager.h
    ApplicationsManager.m
    Binary.h
    Binary.m
    BinaryDumpProtocol.h
    BundleDumpOperation.h
    BundleDumpOperation.m
    Clutch-Prefix.pch
    Clutch.entitlements
    ClutchBundle.h
    ClutchBundle.m
    ClutchCommands.h
    ClutchCommands.m
    ClutchPrint.h
    ClutchPrint.m
    Device.h
    Device.m
    Dumper.h
    Dumper.m
    Extension.h
    Extension.m
    FBApplicationInfo.h
    FinalizeDumpOperation.h
    FinalizeDumpOperation.m
    Framework.h
    Framework.m
    Framework64Dumper.h
    Framework64Dumper.m
    FrameworkDumper.h
    FrameworkDumper.m
    FrameworkLoader.h
    FrameworkLoader.m
    Info.plist
    Info.plist.in
    LSApplicationWorkspace.h
    NSBundle+Clutch.h
    NSBundle+Clutch.m
    NSData+Reading.h
    NSData+Reading.m
    NSFileHandle+Private.h
    NSFileHandle+Private.m
    NSTask.h
    SCInfoBuilder.h
    SCInfoBuilder.m
    ZipArchive.h
    ZipArchive.m
    ZipOperation.h
    ZipOperation.m
    mach_vm.h
    main.m
    move_and_sign.sh
    optool-defines.h
    optool-headers.h
    optool-headers.m
    optool-operations.h
    optool-operations.m
    optool.h
    scinfo.h
    scinfo.m
    sha1.c
    sha1.h 
)

foreach( CLUTCH_SOURCE_FILE ${CLUTCH_SOURCE_FILES} )
    target_sources( Clutch PRIVATE ${CMAKE_CURRENT_LIST_DIR}/${CLUTCH_SOURCE_FILE} )
endforeach( CLUTCH_SOURCE_FILE )

configure_file( ${CMAKE_CURRENT_LIST_DIR}/Clutch.entitlements ${CMAKE_CURRENT_BINARY_DIR}/Clutch.entitlements COPYONLY )
configure_file( ${CMAKE_CURRENT_LIST_DIR}/Info.plist.in ${CMAKE_CURRENT_BINARY_DIR}/Info.plist )