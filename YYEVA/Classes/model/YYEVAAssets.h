//
//  YYEVAAssets.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/13.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import "YYEVAEffectInfo.h"
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface YYEVAAssets : NSObject

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

@property (nonatomic, assign) BOOL isEffectVideo;

@property (nonatomic, strong) NSDictionary *businessEffects;
/**
 【本地普通视频】使用此初始化方法
 如果不是本地路径，返回nil
 */
- (instancetype)initWithFilePath:(NSString *)filePath;
 
- (BOOL)loadVideo;
  
- (CMSampleBufferRef)nextSampleBuffer;

- (BOOL)hasNextSampleBuffer;

- (NSTimeInterval)totalDuration;

- (void)clear;

- (void)tryPlayAudio;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
