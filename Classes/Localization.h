//
//  Localization.h
//  Clutch
//

#import <Foundation/Foundation.h>

typedef enum {
    
    
    CLUTCH_DEV_CHECK_UPDATE,
    CLUTCH_DEV_UP_TO_DATE,
    
    CRACKING_APPNAME,
    CRACKING_CREATE_WORKING_DIR,
    CRACKING_PERFORMING_ANALYSIS,
    CRACKING_PERFORMING_PREFLIGHT,
    DUMPING_ANALYZE_LOAD_COMMAND,
    DUMPING_OBTAIN_PTRACE,
    DUMPING_FORKING,
    DUMPING_FORK_SUCCESS,
    DUMPING_OBTAIN_MACH_PORT,
    DUMPING_CODE_RESIGN,
    DUMPING_PREPARE_DUMP,
    DUMPING_ASLR_ENABLED,
    DUMPING_PERFORM_DUMP,
    DUMPING_PATCH_CRYPTID,
    DUMPING_NEW_CHECKSUM,
    
    DUMPING_OVERDRIVE_PATCH_HEADER,
    DUMPING_OVERDRIVE_PATCH_MAXPROT,
    DUMPING_OVERDRIVE_PATCH_CRYPTID,
    DUMPING_OVERDRIVE_ATTACH_DYLIB,
    
    SWAP_CRACKING_PORTION,
    
    PACKAGING_WAITING_ZIP,
    PACKAGING_FAILED_KILL_ZIP,
    PACKAGING_ITUNESMETADATA,
    PACKAGING_IPA,
    PACKAGING_COMPRESSION_LEVEL,
    
    COMPLETE_ELAPSED_TIME,
    COMPLETE_APPS_CRACKED,
    COMPLETE_APPS_FAILED,
    COMPLETE_TOTAL,
    
} Message;

typedef enum {
    en,
    zh //chinese
} Lang;


static NSString * const en_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"You're using a Clutch development build, checking for updates..",
    [CLUTCH_DEV_UP_TO_DATE] = @"Your version of Clutch is up to date!",
    
    [CRACKING_APPNAME] = @"Cracking %@...",
    [CRACKING_CREATE_WORKING_DIR] = @"Creating working directory...",
    [CRACKING_PERFORMING_ANALYSIS] = @"Performing initial analysis...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"Performing cracking preflight...",
    
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"dumping binary: analyzing load commands",
    [DUMPING_OBTAIN_PTRACE] = @"dumping binary: obtaining ptrace handle",
    [DUMPING_FORKING] = @" umping binary: forking to begin tracing",
    [DUMPING_FORK_SUCCESS] = @"dumping binary: successfully forked",
    [DUMPING_OBTAIN_MACH_PORT] = @"dumping binary: obtaining mach port",
    [DUMPING_CODE_RESIGN] = @"dumping binary: preparing code resign",
    [DUMPING_PREPARE_DUMP] = @"dumping binary: preparing to dump",
    [DUMPING_ASLR_ENABLED] = @"dumping binary: ASLR enabled, identifying dump location dynamically",
    [DUMPING_PERFORM_DUMP] = @"dumping binary: performing dump",
    [DUMPING_PATCH_CRYPTID] = @"dumping binary: patched cryptid",
    [DUMPING_NEW_CHECKSUM] = @" dumping binary: writing new checksum",
    
    [SWAP_CRACKING_PORTION] = @"swap: currently cracking armv%u portion",
    
    [DUMPING_OVERDRIVE_PATCH_HEADER] = @"dumping binary: patched mach header (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"dumping binary: patched maxprot (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"dumping binary: patched cryptid (overdrive)",
    [DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"dumping binary: attaching overdrive DYLIB (overdrive)",
    
    [PACKAGING_WAITING_ZIP] = @"packaging: waiting for zip thread",
    [PACKAGING_FAILED_KILL_ZIP] = @"packaging: crack failed, killing zip thread",
    [PACKAGING_ITUNESMETADATA] = @"packaging: censoring iTunesMetadata",
    [PACKAGING_IPA] = @"packaging: compressing IPA",
    [PACKAGING_COMPRESSION_LEVEL] = @"packaging: compression level %u",
    
    [COMPLETE_ELAPSED_TIME] = @"elapsed time: %ums",
    [COMPLETE_APPS_CRACKED] = @"\nApplications cracked:\n",
    [COMPLETE_APPS_FAILED] = @"\nApplications that failed:\n",
    [COMPLETE_TOTAL] = @"\nTotal success: \033[0;32m%u\033[0m   Total failed: \033[0;32m%u\033[0m ",
    
};

static NSString * const zh_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"您正使用Clutch 的开发版本，正在检查更新...",
    [CLUTCH_DEV_UP_TO_DATE] = @"您的Clutch 是最新版!",
    
    [CRACKING_APPNAME] = @"正在破解 %@",
    [CRACKING_CREATE_WORKING_DIR] = @"正在创建工作目录...",
    [CRACKING_PERFORMING_ANALYSIS] = @"正在进行初始化解析...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"进行破解前准备...",
    
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"破解：分析 load 命令",
    [DUMPING_OBTAIN_PTRACE] = @"破解：正取得 ptrace 句柄",
    [DUMPING_FORKING] = @"破解： 正在分支",
    [DUMPING_FORK_SUCCESS] = @"破解：分支成功！",
    [DUMPING_OBTAIN_MACH_PORT] = @"破解：正在获取 mach 端口",
    [DUMPING_CODE_RESIGN] = @"破解：正在重新签名",
    [DUMPING_PREPARE_DUMP] = @"破解：开始转储",
    [DUMPING_ASLR_ENABLED] = @"破解：软件有 ASLR，正寻找动态转储点",
    [DUMPING_PERFORM_DUMP] = @"破解：进行转储",
    [DUMPING_PATCH_CRYPTID] = @"破解：破解 crytid",
    [DUMPING_NEW_CHECKSUM] = @"破解：写入新的校验",
    
    [SWAP_CRACKING_PORTION] = @"转换: 开始破解 armv%u 部分",
    
    [DUMPING_OVERDRIVE_PATCH_HEADER] = @"转储中: 破解mach头... （屏蔽反破解）",
    [DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"转储中: 破解maxprot…  （屏蔽反破解）",
    [DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"转储中: 破解加密位",
    [DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"转储中: 挂载屏蔽反破解动态库",
    
    [PACKAGING_WAITING_ZIP] = @"包装：等待压缩线程",
    [PACKAGING_FAILED_KILL_ZIP] = @"包装：破解失败, 停止压缩线程",
    [PACKAGING_ITUNESMETADATA] = @"包装：过滤 iTunesMetadata 文件",
    [PACKAGING_IPA] = @"包装：正在打包文件",
    [PACKAGING_COMPRESSION_LEVEL] = @"包装：压缩级别 - 0",
    
    [COMPLETE_ELAPSED_TIME] = @"执行时间: %u 毫秒",
    [COMPLETE_APPS_CRACKED] = @"\n完成破解的应用:\n",
    [COMPLETE_APPS_FAILED] = @"\n破解失败的应用:\n",
    [COMPLETE_TOTAL] = @"\n成功总计: \033[0;32m%u\033[0m   失败总计: \033[0;32m%u\033[0m ",
};


/*
 
 locale template
 
 static NSString * const template_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"",
    [CLUTCH_DEV_UP_TO_DATE] = @"",
    [CRACKING_APPNAME] = @"",
    [CRACKING_CREATE_WORKING_DIR] = @"",
    [CRACKING_PERFORMING_ANALYSIS] = @"",
    [CRACKING_PERFORMING_PREFLIGHT] = @"",
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"",
    [DUMPING_OBTAIN_PTRACE] = @"",
    [DUMPING_FORKING] = @"",
    [DUMPING_FORK_SUCCESS] = @"",
    [DUMPING_OBTAIN_MACH_PORT] = @"",
    [DUMPING_CODE_RESIGN] = @"",
    [DUMPING_PREPARE_DUMP] = @"",
    [DUMPING_ASLR_ENABLED] = @"",
    [DUMPING_PERFORM_DUMP] = @"",
    [DUMPING_PATCH_CRYPTID] = @"",
    [DUMPING_NEW_CHECKSUM] = @"",
    [SWAP_CRACKING_PORTION] = @"",
 
 [DUMPING_OVERDRIVE_PATCH_HEADER] = @"",
 [DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"",
 [DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"",
 [DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"",
 
 [PACKAGING_WAITING_ZIP] = @"",
 [PACKAGING_FAILED_KILL_ZIP] = @"",
 [PACKAGING_ITUNESMETADATA] = @"",
 [PACKAGING_IPA] = @"",
 [PACKAGING_COMPRESSION_LEVEL] = @"",
 
 [COMPLETE_ELAPSED_TIME] = @"",
 [COMPLETE_APPS_CRACKED] = @"",
 [COMPLETE_APPS_FAILED] = @"",
 [COMPLETE_TOTAL] = @"",
};*/


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"

NSString* msg(Message message);

#define MSG(M, ...) fprintf(stderr, "%s \n", [[NSString stringWithFormat:msg(M), ##__VA_ARGS__] UTF8String]);

@interface Localization : NSObject {
    @public
    BOOL* setuidPerformed;
}
+ (Localization*) sharedInstance;
-(NSString*) valueWithMessage:(Message)message;
-(void)checkCache;



@end

