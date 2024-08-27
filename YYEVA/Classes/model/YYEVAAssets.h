//
//  YYEVAAssets.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/13.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <AVFoundation/AVFoundation.h>
#import "YYEVACommon.h"

NS_ASSUME_NONNULL_BEGIN

@class YYEVAAssets;
@class YYEVAEffectInfo;
@protocol YYEVAAssetsDelegate <NSObject>

- (void)assetsDidStart:(YYEVAAssets *)asset;
- (void)assetsDidLoadFaild:(YYEVAAssets *)asset failure:(NSError *)error;
- (void)assets:(YYEVAAssets *)asset onPlayFrame:(NSInteger)frame frameCount:(NSInteger)frameCount;

@end

@interface YYEVAAssets : NSObject
@property (nonatomic, weak) id<YYEVAAssetsDelegate> delegate;
/**
 唯一标识符，目前用于判断统计回调里的数据属于哪个数据源
 */
@property (nonatomic, assign, readonly) NSUInteger assetID;
/**
 数据源地址
 */
@property (nonatomic, strong, readonly) NSString *filePath;
@property (nonatomic, assign) CGSize rgbSize;
@property (nonatomic, strong, readonly) YYEVAEffectInfo *effectInfo; //融合信息
@property (nonatomic, assign, readonly) NSUInteger frameIndex;
@property (nonatomic, assign, readonly) NSUInteger preferredFramesPerSecond;
@property (nonatomic, assign) CGSize size;       //视频宽高
@property (nonatomic, assign) BOOL isEffectVideo; //是否是动态视频
@property (nonatomic, strong) NSDictionary *businessEffects;
@property (nonatomic, assign) YYEVAColorRegion region;
@property (nonatomic, assign) float volume;

/**
 【本地普通视频】使用此初始化方法
 如果不是本地路径，返回nil
 */
- (instancetype)initWithFilePath:(NSString *)filePath;
/**
    开始加载资源
 */
- (BOOL)loadVideo;
- (CMSampleBufferRef)nextSampleBuffer;
- (BOOL)hasNextSampleBuffer;
- (NSTimeInterval)totalDuration;
- (void)clear;
- (void)tryPlayAudio;
- (void)pauseAudio;
- (void)resumeAudio;
- (void)reload;
- (BOOL)existAudio;

@end

NS_ASSUME_NONNULL_END
