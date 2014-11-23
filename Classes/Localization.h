//
//  Localization.h
//  Clutch
//

#import <Foundation/Foundation.h>

typedef enum {
    CLUTCH_DEV_CHECK_UPDATE,
    CLUTCH_DEV_UP_TO_DATE,
    CLUTCH_DEV_NOT_UP_TO_DATE, // Added 19th Jan
    CLUTCH_PERMISSION_ERROR, // Added 19th Jan
    CLUTCH_NO_APPLICATIONS, // Added 19th Jan
    CLUTCH_CRACKING_ALL, // Added 19th Jan
    CLUTCH_ENABLED_YOPA, // Added 19th Jan
    
    CONFIG_DOWNLOADING_FILES, // Added 20th Jan
    CONFIG_NO_MEMORY, // Added 20th Jan
    CONFIG_SAVING, // Added 20th Jan
    CONFIG_USING_DEFAULT, // Added 20th Jan
    
    CRACKING_DIRECTORY_ERROR, // Added 20th Jan
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
    zh, // chinese
    de, // german
    fr, // french
    hr, // serbian/croatian
    ru, // russian
    ar, // arabic
} Lang;


static NSString * const en_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"You're using a Clutch development build, checking for updates..",
    [CLUTCH_DEV_UP_TO_DATE] = @"Your version of Clutch is up to date!",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"Your current version of Clutch is outdated!\nPlease get the latest version!\n",
    [CLUTCH_PERMISSION_ERROR] = @"You must be root to use Clutch.",
    [CLUTCH_NO_APPLICATIONS] = @"There are no encrypted applications on this device.",
    [CLUTCH_CRACKING_ALL] = @"Cracking all encrypted applications on this device.",
    [CLUTCH_ENABLED_YOPA] = @"YOPA is enabled.",
    
    [CONFIG_DOWNLOADING_FILES] = @"Downloading config files...",
    [CONFIG_NO_MEMORY] = @"No memory",
    [CONFIG_SAVING] = @"Saving configuration settings...",
    [CONFIG_USING_DEFAULT] = @"Using default value...",
    
    [CRACKING_DIRECTORY_ERROR] = @"error: could not create working directory.",
    [CRACKING_APPNAME] = @"Cracking %@...",
    [CRACKING_CREATE_WORKING_DIR] = @"Creating working directory...",
    [CRACKING_PERFORMING_ANALYSIS] = @"Performing initial analysis...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"Performing cracking preflight...",
    
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"dumping binary: analyzing load commands",
    [DUMPING_OBTAIN_PTRACE] = @"dumping binary: obtaining ptrace handle",
    [DUMPING_FORKING] = @"dumping binary: forking to begin tracing",
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
    
    [COMPLETE_ELAPSED_TIME] = @"elapsed time: %.02fs",
    [COMPLETE_APPS_CRACKED] = @"\nApplications cracked:\n",
    [COMPLETE_APPS_FAILED] = @"\nApplications that failed:\n",
    [COMPLETE_TOTAL] = @"\nTotal success: \033[0;32m%u\033[0m   Total failed: \033[0;32m%u\033[0m ",
    
};

static NSString * const zh_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"您正使用Clutch 的开发版本，正在检查更新...",
    [CLUTCH_DEV_UP_TO_DATE] = @"您的Clutch 是最新版!",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"您使用的开发版本需要更新！",
    [CLUTCH_PERMISSION_ERROR] = @"Clutch 需要 root",
    [CLUTCH_NO_APPLICATIONS] = @"没有任何正版应用！",
    [CLUTCH_CRACKING_ALL] = @"正破解所有得应用..",
    [CLUTCH_ENABLED_YOPA] = @"[Not yet translated] YOPA is enabled.",
    
    [CONFIG_DOWNLOADING_FILES] = @"正下载组态文件..",
    [CONFIG_NO_MEMORY] = @"错误：内存已满",
    [CONFIG_SAVING] = @"正保存组态文件..",
    [CONFIG_USING_DEFAULT] = @"使用预定的选择..",
    
    [CRACKING_DIRECTORY_ERROR] = @"错误：不能创造工程目录",
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
    
    [COMPLETE_ELAPSED_TIME] = @"执行时间: %.02f 秒",
    [COMPLETE_APPS_CRACKED] = @"\n完成破解的应用:\n",
    [COMPLETE_APPS_FAILED] = @"\n破解失败的应用:\n",
    [COMPLETE_TOTAL] = @"\n成功总计: \033[0;32m%u\033[0m   失败总计: \033[0;32m%u\033[0m ",
};


static NSString * const de_locale[] = {
	[CLUTCH_DEV_CHECK_UPDATE] = @"Du benutzt eine Clutch-Entwicklungsversion, überprüfe auf Updates...",
	[CLUTCH_DEV_UP_TO_DATE] = @"Die Version von Clutch ist aktuell!",
	[CLUTCH_DEV_NOT_UP_TO_DATE] = @"Dein Clutch ist outdated!\nBitte lade dir die neuste Version herunter!\n",
	[CLUTCH_PERMISSION_ERROR] = @"Du musst als root eingeloggt seien um Clutch zu nutzen.",
	[CLUTCH_NO_APPLICATIONS] = @"Es gibt keine encrypteten Applikationen auf diesem Gerät.",
	[CLUTCH_CRACKING_ALL] = @"Cracke alle encrypteten Applikation.",
	[CLUTCH_ENABLED_YOPA] = @"YOPA ist aktiviert.",
	
	[CONFIG_DOWNLOADING_FILES] = @"Lade die Knofigurationsdaten herunter...",
	[CONFIG_NO_MEMORY] = @"Kein freier Speicher.",
	[CONFIG_SAVING] = @"Speichere Konfigurationsdaten...",
	[CONFIG_USING_DEFAULT] = @"Benutze Voreinstellungen...",

	[CRACKING_DIRECTORY_ERROR] = @"Fehler: Konnte keinen Arbeitsordner erstellen.",
	[CRACKING_APPNAME] = @"Cracke %@...",
	[CRACKING_CREATE_WORKING_DIR] = @"Erstelle Arbeitsverzeichnis...",
	[CRACKING_PERFORMING_ANALYSIS] = @"Führe erste Analyse durch...",
	[CRACKING_PERFORMING_PREFLIGHT] = @"Führe das Cracken des preflights durch...",

	[DUMPING_ANALYZE_LOAD_COMMAND] = @"Binary erhalten: Analysiere Ladebefehle",
	[DUMPING_OBTAIN_PTRACE] = @"Binary erhalten: Erhalte ptrace handle",
	[DUMPING_FORKING] = @"Binary erhalten: Pieksen um zu starten",
	[DUMPING_FORK_SUCCESS] = @"Binary erhalten: Erfolgreich gepiekst",
	[DUMPING_OBTAIN_MACH_PORT] = @"Binary erhalten: Erhalte den mach port",
	[DUMPING_CODE_RESIGN] = @"Binary erhalten: Bereite den Code-Resign vor",
	[DUMPING_PREPARE_DUMP] = @"Binary erhalten: Bereite das eigentliche Erhalten vor",
	[DUMPING_ASLR_ENABLED] = @"Binary erhalten: ASLR aktiviert, identifiziere dumping-Verzeichnis manuell",
	[DUMPING_PERFORM_DUMP] = @"Binary erhalten: Führe den Dump durch",
	[DUMPING_PATCH_CRYPTID] = @"Binary erhalten: Cryptid gepatched",
	[DUMPING_NEW_CHECKSUM] = @"Binary erhalten: Schreibe neue checksum-Daten",

	[SWAP_CRACKING_PORTION] = @"Tauschen: Cracke momentan armv%u portion",

	[DUMPING_OVERDRIVE_PATCH_HEADER] = @"Binary erhalten: Mach header gepatched (Overdrive)",
	[DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"Binary erhalten: Maxprot gepatched (Overdrive)",
	[DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"Binary erhalten: Cryptid gepatched (Overdrive)",
	[DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"Binary erhalten: Hänge Overdrive-DYLIB an (Overdrive)",

	[PACKAGING_WAITING_ZIP] = @"Zusammenpacken: Warte auf den zip-thread",
	[PACKAGING_FAILED_KILL_ZIP] = @"Zusammenpacken: Crack fehlgeschlagen, eliminiere zip-thread",
	[PACKAGING_ITUNESMETADATA] = @"Zusammenpacken: Zensiere die iTunesMetadata-Datei",
	[PACKAGING_IPA] = @"Zusammenpacken: Komprimiere die IPA",
	[PACKAGING_COMPRESSION_LEVEL] = @"Zusammenpacken: Kompressionslevel ist %u",

	[COMPLETE_ELAPSED_TIME] = @"Vergangene Zeit: %ums",
	[COMPLETE_APPS_CRACKED] = @"\nApplikationen gecracked:\n",
	[COMPLETE_APPS_FAILED] = @"\nApplikationen, die fehlgeschlagen sind:\n",
	[COMPLETE_TOTAL] = @"\nInsgesamt erfolgreich: \033[0;32m%u\033[0m Insgesamt fehlgeschlagen: \033[0;32m%u\033[0m ",
  
};


static NSString * const fr_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"Vous utilisez une version de dÈveloppement de Clutch, vÈrification des mises ‡ jour...",
    [CLUTCH_DEV_UP_TO_DATE] = @"Votre version de Clutch est ‡ jour !",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"Votre version Clutch n'est pas ‡ jour !\nVeuillez tÈlÈcharger la derniËre version !\n",
    [CLUTCH_PERMISSION_ERROR] = @"Vous devez Ítre root pour utiliser Clutch.",
    [CLUTCH_NO_APPLICATIONS] = @"Il n'y a aucune application cryptÈe sur cet appareil.",
    [CLUTCH_CRACKING_ALL] = @"Crackage de toutes les applications cryptÈes sur cet appareil.",
    [CLUTCH_ENABLED_YOPA] = @"Yopa est activÈ.",
    
    [CONFIG_DOWNLOADING_FILES] = @"TÈlÈchargement des fichiers de configuration...",
    [CONFIG_NO_MEMORY] = @"Pas de mÈmoire",
    [CONFIG_SAVING] = @"Enregistrement des paramËtres de configuration...",
    [CONFIG_USING_DEFAULT] = @"Utilisation de la valeur par dÈfaut...",
    
    [CRACKING_DIRECTORY_ERROR] = @"erreur: impossible de crÈer le rÈpertoire de travail.",
    [CRACKING_APPNAME] = @"Craquage %@...",
    [CRACKING_CREATE_WORKING_DIR] = @"CrÈation du rÈpertoire de travail...",
    [CRACKING_PERFORMING_ANALYSIS] = @"ExÈcute une premiËre analyse...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"ExÈcution du craquage de prÈ-installation...",
    
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"Dumping du binaire: analyse du chargement des commandes",
    [DUMPING_OBTAIN_PTRACE] = @"Dumping du binaire: RÈcupÈration du traitement de ptrace",
    [DUMPING_FORKING] = @"Dumping du binaire: sÈparation pour commencer ‡ tracer",
    [DUMPING_FORK_SUCCESS] = @"Dumping du binaire: sÈparation rÈussie",
    [DUMPING_OBTAIN_MACH_PORT] = @"Dumping du binaire: Obtention du port correspondant",
    [DUMPING_CODE_RESIGN] = @"Dumping du binaire: prÈparation du code",
    [DUMPING_PREPARE_DUMP] = @"Dumping du binaire: prÈparation du vidage",
    [DUMPING_ASLR_ENABLED] = @"Dumping du binaire: ASLR activÈ, identification de l'emplacement de vidage dynamique",
    [DUMPING_PERFORM_DUMP] = @"Dumping du binaire: exÈcution du vidage",
    [DUMPING_PATCH_CRYPTID] = @"Dumping du binaire: cryptid patchÈ",
    [DUMPING_NEW_CHECKSUM] = @" Dumping du binaire: Ècriture de la nouvelle somme de contrÙle",
    
    [SWAP_CRACKING_PORTION] = @"swap: craquage de la partie armv%u",
    
    [DUMPING_OVERDRIVE_PATCH_HEADER] = @"Dumping du binaire: patchage de l'en-tÍte correspondante (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"Dumping du binaire: patch maxprot (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"Dumping du binaire: patch cryptid (overdrive)",
    [DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"Dumping du binaire: attache overdrive DYLIB (overdrive)",
    
    [PACKAGING_WAITING_ZIP] = @"Package: patienter pendant la crÈation du zip",
    [PACKAGING_FAILED_KILL_ZIP] = @"Package: le crack a ÈchouÈ, suppression de la crÈation du zip",
    [PACKAGING_ITUNESMETADATA] = @"Package: suppression d'iTunesMetadata",
    [PACKAGING_IPA] = @"Package: Compression de l'IPA",
    [PACKAGING_COMPRESSION_LEVEL] = @"Package: Compression de niveau %u",
    
    [COMPLETE_ELAPSED_TIME] = @"Temps ÈcoulÈ: %ums",
    [COMPLETE_APPS_CRACKED] = @"\nApplications crackÈes:\n",
    [COMPLETE_APPS_FAILED] = @"\nApplications non crackÈes:\n",
    [COMPLETE_TOTAL] = @"\nSuccËs: \033[0;32m%u\033[0m   EchouÈs: \033[0;32m%u\033[0m ",
    
};

static NSString * const hr_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"Koristite beta verziju Clutch, proveravam ažuriranja",
    [CLUTCH_DEV_UP_TO_DATE] = @"Vaša verzija Clutch je najnovija!",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"Vaša trenutna verzija Clutch nije najnovija!\nMolimo Vas preuzmite najnoviju verziju!\n",
    [CLUTCH_PERMISSION_ERROR] = @"Morate biti root korisnik da biste koristili Clutch.",
    [CLUTCH_NO_APPLICATIONS] = @"Ne postoje enkriptovane aplikacije na Vašem uređaju.",
    [CLUTCH_CRACKING_ALL] = @"Crackujem sve enkriptovane aplikacije.",
    [CLUTCH_ENABLED_YOPA] = @"YOPA je omogućen.",
	
    [CONFIG_DOWNLOADING_FILES] = @"Preuzimam fajlove za konfigurisanje...",
    [CONFIG_NO_MEMORY] = @"Nema memorije",
    [CONFIG_SAVING] = @"Čuvam podešene konfiguracije...",
    [CONFIG_USING_DEFAULT] = @"Koristim podrazumevanu vrednost...",
    
    [CRACKING_DIRECTORY_ERROR] = @"greška: ne mogu da napravim direktorijum za rad.",
    [CRACKING_APPNAME] = @"Crackujem %@...",
    [CRACKING_CREATE_WORKING_DIR] = @"Pravim direktorijum za rad...",
    [CRACKING_PERFORMING_ANALYSIS] = @"Izvršavam početne analize...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"Izvršavam provere pred početak crackovanja...",
	
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"izbacujem binary: Analiziram komande pri učitavanju",
    [DUMPING_OBTAIN_PTRACE] = @"izbacujem binary: uzimam ptrace handle",
    [DUMPING_FORKING] = @"izbacujem binary: forkujem da započnem traženje",
    [DUMPING_FORK_SUCCESS] = @"izbacujem binary: forkovanje uspešno",
    [DUMPING_OBTAIN_MACH_PORT] = @"izbacujem binary: uzimam mach port",
    [DUMPING_CODE_RESIGN] = @"izbacujem binary: spremam potpisivanje koda",
    [DUMPING_PREPARE_DUMP] = @"izbacujem binary: spremam se za izbacivanje",
    [DUMPING_ASLR_ENABLED] = @"izbacujem binary: ASLR omogućen, dinamički identifikujem lokaciju izbacivanja",
    [DUMPING_PERFORM_DUMP] = @"izbacujem binary: izvršavam izbacivanje",
    [DUMPING_PATCH_CRYPTID] = @"izbacujem binary: cryptid je zakrpljen",
    [DUMPING_NEW_CHECKSUM] = @"izbacujem binary: pišem novi checksum",
	
    [SWAP_CRACKING_PORTION] = @"izmenjujem: trenutno crackujem armv%u deo",
    
	[DUMPING_OVERDRIVE_PATCH_HEADER] = @"izbacujem binary: mach header zakrpljen (overdrive)",
	[DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"izbacujem binary: maxprot zakrpljen (overdrive)",
	[DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"izbacujem binary: cryptid zakrpljen (overdrive)",
	[DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"izbacujem binary: vezujem overdrive DYLIB (overdrive)",
    
	[PACKAGING_WAITING_ZIP] = @"pakujem: čekam zip thread",
	[PACKAGING_FAILED_KILL_ZIP] = @"pakujem: crackovanje neuspešno, ubijam zip thread",
	[PACKAGING_ITUNESMETADATA] = @"pakujem: cenzurišem iTunesMetadata",
	[PACKAGING_IPA] = @"pakujem: kompresujem IPA",
	[PACKAGING_COMPRESSION_LEVEL] = @"pakujem: nivo kompresije %u",
    
	[COMPLETE_ELAPSED_TIME] = @"utrošeno vreme» %ums",
	[COMPLETE_APPS_CRACKED] = @"\nUspešno:\n",
	[COMPLETE_APPS_FAILED] = @"\nBezuspešno:\n",
	[COMPLETE_TOTAL] = @"\nUkupno uspešno: \033[0;32m%u\033[0m   Ukupno bezuspešno: \033[0;32m%u\033[0m ",
};


// Translator: OdNairy
static NSString * const ru_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"Вы используете версию для разработчиков, подождите, идёт проверка обновлений..",
    [CLUTCH_DEV_UP_TO_DATE] = @"У вас самая последняя версия Clutch!",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"Ваша версия Clutch устарела!\nПожалуйста, обновите Clutch!\n",
    [CLUTCH_PERMISSION_ERROR] = @"Для работы Clutch необходимы root-права",
    [CLUTCH_NO_APPLICATIONS] = @"Необнаружено зашифрованных приложений на этом устройстве.",
    [CLUTCH_CRACKING_ALL] = @"Идёт взлом всех зашифрованных приложений на этом устровстве.",
    [CLUTCH_ENABLED_YOPA] = @"YOPA активирован.",
    
    [CONFIG_DOWNLOADING_FILES] = @"Скачиваются файлы конфигурации...",
    [CONFIG_NO_MEMORY] = @"Недостаточно памяти",
    [CONFIG_SAVING] = @"Сохраняю файлы конфигурации...",
    [CONFIG_USING_DEFAULT] = @"Будет использовано значение по-умолчанию...",
    
    [CRACKING_DIRECTORY_ERROR] = @"Ошибка: невозможно создать рабочую директорию.",
    [CRACKING_APPNAME] = @"Взламываю %@...",
    [CRACKING_CREATE_WORKING_DIR] = @"Создаю рабочую директорию...",
    [CRACKING_PERFORMING_ANALYSIS] = @"Выполняю первоначальный анализ...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"Выполняю подготовку к взлому...",
    
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"Дамп бинарного файла: анализ команд загрузки",
    [DUMPING_OBTAIN_PTRACE] = @"Дамп бинарного файла: обход ptrace-хендлера",
    [DUMPING_FORKING] = @"Дамп бинарного файла: клонирование перед началом трасировки",
    [DUMPING_FORK_SUCCESS] = @"Дамп бинарного файла: клонирование успешно завершено",
    [DUMPING_OBTAIN_MACH_PORT] = @"Дамп бинарного файла: захват mach port",
    [DUMPING_CODE_RESIGN] = @"Дамп бинарного файла: подготовка к переподпики приложения",
    [DUMPING_PREPARE_DUMP] = @"Дамп бинарного файла: подготовка к дампу",
    [DUMPING_ASLR_ENABLED] = @"Дамп бинарного файла: ASLR включён, определяем место для дампа динамически",
    [DUMPING_PERFORM_DUMP] = @"Дамп бинарного файла: выполняется дамп",
    [DUMPING_PATCH_CRYPTID] = @"Дамп бинарного файла: изменён cryptid",
    [DUMPING_NEW_CHECKSUM] = @" Дамп бинарного файла: запись новой чек-суммы",
    
    [SWAP_CRACKING_PORTION] = @"swap: идёт взлом armv%u архитектуры",
    
    [DUMPING_OVERDRIVE_PATCH_HEADER] = @"Дамп бинарного файла: изменён mach header (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"Дамп бинарного файла: изменён maxprot (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"Дамп бинарного файла: изменён cryptid (overdrive)",
    [DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"Дамп бинарного файла: добавлен overdrive DYLIB (overdrive)",
    
    [PACKAGING_WAITING_ZIP] = @"Сборка: ожидаем завершения архивирования",
    [PACKAGING_FAILED_KILL_ZIP] = @"Сборка: взлом приложения не удался, останавливаем поток архивирования",
    [PACKAGING_ITUNESMETADATA] = @"Сборка: игнорируем iTunesMetadata",
    [PACKAGING_IPA] = @"Сборка: архивирование IPA-файла",
    [PACKAGING_COMPRESSION_LEVEL] = @"Сборка: выбран уровень компрессии %u",
    
    [COMPLETE_ELAPSED_TIME] = @"Затрачено времени: %.02fs",
    [COMPLETE_APPS_CRACKED] = @"\nВзломанные приложения:\n",
    [COMPLETE_APPS_FAILED] = @"\nНеудачные взломы:\n",
    [COMPLETE_TOTAL] = @"\nУдачные взломы: \033[0;32m%u\033[0m   Неудачные взломы: \033[0;32m%u\033[0m ",
    
};


// Translator: iD70my
static NSString * const ar_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"أنت تستخدم نسخة المطورين ، تحقق من وجود تحديثات",
    [CLUTCH_DEV_UP_TO_DATE] = @"هل لديك أخر نسخه من كلاتش!",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"إصدار كلاتش قديم\nالرجاء تحديث كلاتش!\n",
    [CLUTCH_PERMISSION_ERROR] = @"يجب الدخول على الروت لإستخدام كلاتش",
    [CLUTCH_NO_APPLICATIONS] = @"لا توجد تطبيقات مشفرة على هذا الجهاز.",
    [CLUTCH_CRACKING_ALL] = @"جاري تكريك جميع التطبيقات المشفرة على هذا الجهاز.",
    [CLUTCH_ENABLED_YOPA] = @"YOPA مفعلة",
    
    [CONFIG_DOWNLOADING_FILES] = @"تحميل ملفات التكوين...",
    [CONFIG_NO_MEMORY] = @"لا توجد ذاكرة",
    [CONFIG_SAVING] = @"حفظ إعدادات التكوين...",
    [CONFIG_USING_DEFAULT] = @"إستخدم القيمة الافتراضية...",
    
    [CRACKING_DIRECTORY_ERROR] = @"خطأ: لا يمكن إنشاء دليل العمل.",
    [CRACKING_APPNAME] = @"جاري التكريك %@...",
    [CRACKING_CREATE_WORKING_DIR] = @"إنشاء دليل العمل...",
    [CRACKING_PERFORMING_ANALYSIS] = @"أداء التحليل الأولي...",
    [CRACKING_PERFORMING_PREFLIGHT] = @"أداء الكراك الاختبار المبدئي...",
    
    [DUMPING_ANALYZE_LOAD_COMMAND] = @"فضلا إنتظر: تحميل فرق تحليل",
    [DUMPING_OBTAIN_PTRACE] = @"فضلا إنتظر: الحصول على مقبض ptrace",
    [DUMPING_FORKING] = @"فضلا إنتظر: التفرع لبدء الإستنساخ",
    [DUMPING_FORK_SUCCESS] = @"فضلا إنتظر: تم الإستنساخ بنجاح",
    [DUMPING_OBTAIN_MACH_PORT] = @"فضلا إنتظر: الحصول على بورت",
    [DUMPING_CODE_RESIGN] = @"فضلا إنتظر: إعداد الكود النهائي",
    [DUMPING_PREPARE_DUMP] = @"فضلا إنتظر: التحضير للتفريغ",
    [DUMPING_ASLR_ENABLED] = @"فضلا إنتظر: ASLR تفعيل، وتحديد موقع تفريغ حيوي",
    [DUMPING_PERFORM_DUMP] = @"فضلا إنتظر: أداء التفريغ",
    [DUMPING_PATCH_CRYPTID] = @"فضلا إنتظر: مصحح cryptid",
    [DUMPING_NEW_CHECKSUM] = @" كتابة التطبيق الاختباري الجديد",
    
    [SWAP_CRACKING_PORTION] = @"إنتظر: جاري التكريك تم تكريك%u جزء",
    
    [DUMPING_OVERDRIVE_PATCH_HEADER] = @"فضلا إنتظر : تصحيح mach header (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_MAXPROT] = @"فضلا إنتظر : تصحيح maxprot (overdrive)",
    [DUMPING_OVERDRIVE_PATCH_CRYPTID] = @"فضلا إنتظر : تصحيح cryptid (overdrive)",
    [DUMPING_OVERDRIVE_ATTACH_DYLIB] = @"فضلا إنتظر : ربط overdrive DYLIB (overdrive)",
    
    [PACKAGING_WAITING_ZIP] = @"فضلا إنتظر : في إنتظار الضغط",
    [PACKAGING_FAILED_KILL_ZIP] = @"فشل الكراك : وذلك بسبب قتل الضغط \n تعريب @iD70my",
    [PACKAGING_ITUNESMETADATA] = @"فضلا إنتظر : متابعة من iTunesMetadata",
    [PACKAGING_IPA] = @"فضلا إنتظر : ضغط IPA ",
    [PACKAGING_COMPRESSION_LEVEL] = @"فضلا إنتظر : مستوى الضغط %u",
    
    [COMPLETE_ELAPSED_TIME] = @"الوقت المنقضي: %.02fs",
    [COMPLETE_APPS_CRACKED] = @"\nالتطبيقات المكركة:\n",
    [COMPLETE_APPS_FAILED] = @"\nالتطبيقات التي فشلت:\n",
    [COMPLETE_TOTAL] = @"\nمجموع الناجحة: \033[0;32m%u\033[0m   مجموع الفاشلة: \033[0;32m%u\033[0m ",
    
};


/*
 
 locale template
 
 static NSString * const template_locale[] = {
    [CLUTCH_DEV_CHECK_UPDATE] = @"",
    [CLUTCH_DEV_UP_TO_DATE] = @"",
    [CLUTCH_DEV_NOT_UP_TO_DATE] = @"",
    [CLUTCH_PERMISSION_ERROR] = @"",
    [CLUTCH_NO_APPLICATIONS] = @"",
    [CLUTCH_CRACKING_ALL] = @"",
    [CLUTCH_ENABLED_YOPA] = @"",
    
    [CONFIG_DOWNLOADING_FILES] = @"",
    [CONFIG_NO_MEMORY] = @"",
    [CONFIG_SAVING] = @"",
    [CONFIG_USING_DEFAULT] = @"",
 
    [CRACKING_DIRECTORY_ERROR] = @"",
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
-(Lang) defaultLang;
-(void)checkCache;



@end
