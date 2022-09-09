//
//  YYEVAPlayer+HttpURL.m
//  YYEVA_Example
//
//  Created by guoyabin on 2022/9/9.
//  Copyright © 2022 guoyabin. All rights reserved.
//

#import "YYEVAPlayer+HttpURL.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

typedef void(^EVAPlayerDownloaderCompletionBlock)(NSString *file,NSError *err);


@interface YYEVAPlayerDownloadManager : NSObject
@property (nonatomic, strong) NSMutableDictionary *downloadBlock;
+ (instancetype)sharedInstance;
@end

@implementation YYEVAPlayerDownloadManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static YYEVAPlayerDownloadManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.downloadBlock = [NSMutableDictionary dictionary];
    });
    return instance;
}

@end
 

@implementation YYEVAPlayer (HttpURL)
 

- (void)playHttpURL:(NSString *)URL
{
    NSString *yyevaCacheDir = [[self cacheDir] stringByAppendingPathComponent:@"yyevacache"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:yyevaCacheDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:yyevaCacheDir withIntermediateDirectories:YES attributes:@{} error:nil];
    }
    NSString *urlFileName = [[self MD5String:URL] stringByAppendingString:@".mp4"];
    NSString *cacheFile = [yyevaCacheDir stringByAppendingPathComponent:urlFileName];
    
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFile] ){
        [self play:cacheFile];
    } else {
        NSMutableDictionary *downloadBlock = [YYEVAPlayerDownloadManager sharedInstance].downloadBlock;
        __weak typeof(self) weakSelf = self;
        EVAPlayerDownloaderCompletionBlock block = ^(NSString *file,NSError *err){
            if (!weakSelf) {
                return;
            }
            if (err) {
                [weakSelf stopAnimation];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if([weakSelf.delegate respondsToSelector:@selector(evaPlayerDidCompleted:)]){
                        [weakSelf.delegate evaPlayerDidCompleted:weakSelf];
                    }
                });
                
            } else {
                if (![[NSFileManager defaultManager] fileExistsAtPath:cacheFile]) {
                    [[NSFileManager defaultManager] copyItemAtPath:file toPath:cacheFile error:nil];
                }
                [weakSelf play:cacheFile];
            }
            
        };
        
        NSMutableArray *arry = (NSMutableArray *)[downloadBlock objectForKey:URL];
        if (arry) {
            [arry addObject:block];
            return;
        }
        
        arry = [NSMutableArray arrayWithObject:block];
        [downloadBlock setObject:arry forKey:URL];
        
        
        [self playWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URL] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:20.0]
                 completionBlock:^(NSString * file,NSError *err) {
               
            NSArray *blocks = [downloadBlock objectForKey:URL];
            [blocks enumerateObjectsUsingBlock:^(EVAPlayerDownloaderCompletionBlock obj, NSUInteger idx, BOOL * _Nonnull stop) {
                obj(file,err);
            }];
            
        }];
    }
}

- (NSString *)cacheDir
{
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
}

 

- (void)playWithURLRequest:(NSURLRequest *)URLRequest completionBlock:(EVAPlayerDownloaderCompletionBlock)completionBlock{
   
    [[[NSURLSession sharedSession] downloadTaskWithRequest:URLRequest completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (completionBlock) {
            completionBlock(location.path,error);
        }
    }] resume] ;
}


- (NSString *)MD5String:(NSString *)str
{
    const char *cstr = [str UTF8String];
    if (cstr == nil) {
        cstr = "";
    }
    
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}


@end


