//
//  YYEVAAssets.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/13.
//

#import "YYEVAAssets.h"
#import "YYEVADemuxMedia.h"
#import "YYEVAEffectInfo.h"
#import "YSVideoMetalUtils.h"
#import <AVFoundation/AVFoundation.h>
#import "YYEVARegionChecker.h"

#define kSampleBufferQueueMaxCapacity 3

@interface YYEVAAssets() <AVAudioPlayerDelegate>
{
    CFMutableArrayRef _sampleBufferQueue;
}
@property (nonatomic, strong) dispatch_queue_t readVideoBufferQueue;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@property (nonatomic, assign) NSTimeInterval videoDuration;
@property (nonatomic, assign) NSTimeInterval frameDuration;
@property (nonatomic, strong) YYEVADemuxMedia *demuxer;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, strong) YYEVARegionChecker *regionChecker;
@property (nonatomic, assign) NSUInteger frameCount;
@end

@implementation YYEVAAssets
 
+ (NSUInteger)generateUniqueID
{
    static dispatch_queue_t sQueue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sQueue = dispatch_queue_create("com.yy.yyeva.asset", DISPATCH_QUEUE_SERIAL);
    });

    static NSUInteger sUniqueID = 1;
    __block NSUInteger uniqueID;
    dispatch_sync(sQueue, ^() {
        uniqueID = sUniqueID++;
    });
     
    return uniqueID;
}


- (instancetype)initWithFilePath:(NSString *)filePath
{
    if (self = [super init]) {
        _assetID = [YYEVAAssets generateUniqueID];
        _filePath = filePath;
        _demuxer = [[YYEVADemuxMedia alloc] init];
        _regionChecker = [[YYEVARegionChecker alloc] init];
        //解析fileUrl
        _readVideoBufferQueue = dispatch_queue_create("com.yy.eva.ReadBufferQueue", DISPATCH_QUEUE_SERIAL);
        _sampleBufferQueue = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    }
    return self;
}
 
- (void)reloadEffect
{
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    __weak typeof(self) weakSelf = self;
    [_effectInfo.srcs enumerateObjectsUsingBlock:^(YYEVAEffectSource * _Nonnull source, NSUInteger idx, BOOL * _Nonnull stop) {
        [dic setObject:source forKey:@(source.effect_id)];
        id content = [weakSelf.businessEffects objectForKey:source.effect_tag];
        if (content) {
            if (source.type == YYEVAEffectSourceTypeImage) {
                if ([content isKindOfClass:UIImage.class]) {
                    source.sourceImage = content;
                } else if ([content isKindOfClass:NSString.class]) {
                    source.sourceImage = [UIImage imageWithContentsOfFile:content];
                }
            } else if (source.type == YYEVAEffectSourceTypeText) {
                
                NSDictionary *textDict = (NSDictionary *)content;
                NSAttributedString *attrText = [textDict objectForKey:@"attrText"];
                if (attrText) {
                    source.sourceImage = [YSVideoMetalUtils imageWithAttrText:attrText rectSize:CGSizeMake(source.width, source.height)];
                } else {
                    NSString *text = [textDict objectForKey:@"content"];
                    NSTextAlignment alignment = source.alignment;
                    //如果业务有传，使用业务的数据
                    if ([textDict objectForKey:@"align"] != nil) {
                        alignment = [[textDict objectForKey:@"align"] integerValue];
                    }
                    UIColor *color = [UIColor whiteColor];
                    if (source.fontColor) {
                        const char *cStr = [source.fontColor cStringUsingEncoding:NSASCIIStringEncoding];
                        long x = strtol(cStr + 1, NULL, 16);
                        float r = (float)((x >> 16) & 0x000000FF) / 255.0f;
                        float g = (float)((x >> 8) & 0x000000FF) / 255.0f;
                        float b = (float)(x & 0x000000FF) / 255.0f;
                        color = [UIColor colorWithRed:r green:g blue:b alpha:1.0f];
                    }
                    float fontSize = source.fontSize;
                    source.sourceImage = [YSVideoMetalUtils imageWithText:text
                                                                textColor:color
                                                                 fontSize:fontSize
                                                                 rectSize:CGSizeMake(source.width, source.height)
                                                                    align:alignment];
                }
            }
        }
    }];

    if (dic.count > 0 && _effectInfo.frames.count > 0) {
        [_effectInfo.frames enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSArray<YYEVAEffectFrame *> * _Nonnull obj, BOOL * _Nonnull stop) {
            [obj enumerateObjectsUsingBlock:^(YYEVAEffectFrame *frame, NSUInteger idx, BOOL * _Nonnull stop) {
                frame.src = [dic objectForKey:@(frame.effect_id)];
            }];
        }];
    }
}

- (void)playFail:(YYEVAPlayerErrorCode)errCode
{
    if ([self.delegate respondsToSelector:@selector(assetsDidLoadFaild:failure:)]) {
        [self.delegate assetsDidLoadFaild:self failure:[NSError errorWithDomain:NSURLErrorDomain code:errCode userInfo:nil]];
    }
}

//metal:texture
- (BOOL)loadVideo
{
    NSError *err;
    
    if (!self.filePath || ![[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
        [self playFail:FileNotExits];
        return NO;
    }
    NSDictionary *dictionary = [self.demuxer demuxEffectJsonWithFilePath:self.filePath];
    
    YYEVAEffectInfo *effectInfo = [YYEVAEffectInfo effectInfoWithDictionary:dictionary];
    
    _effectInfo = effectInfo;
    
    if (!effectInfo && self.region == YYEVAColorRegion_NoSpecify) {
        YYEVAColorRegion region = [self.regionChecker checkFile:self.filePath];
        _region = region;
    }
    
    if (effectInfo && effectInfo.isEffect) {
        self.isEffectVideo = YES;
    } else {
        self.isEffectVideo = NO;
    }
    
    if (self.isEffectVideo) {
        [self reloadEffect];
        self.size = CGSizeMake(self.effectInfo.videoWidth, self.effectInfo.videoHeight);
    }
    
    //获取视频的分辨率
    if (!CGSizeEqualToSize(effectInfo.rgbFrame.size, CGSizeZero)) {
        self.rgbSize = effectInfo.rgbFrame.size;
    }
    
    //asset
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:self.filePath] options:nil];
    
    if (!asset) {
        NSLog(@"load asset url:%@ failure",self.filePath);
        [self playFail:LoadAssetsFail];
        return NO;
    }
    
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    
    if (!reader) {
        NSLog(@"assetReaderWithAsset:%@ failure",self.filePath);
        [self playFail:LoadAssetsFail];
        return NO;
    }
    AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!assetTrack) {
        NSLog(@"tracksWithMediaType url:%@ failure",self.filePath);
        [self playFail:LoadAssetsFail];
        return NO;
    }
    
    AVAssetTrack *assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!assetAudioTrack) {
        _audioPlayer = nil;
    } else {
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:self.filePath] error:nil];
        self.audioPlayer.volume = _volume;
    }
    
    NSDictionary *outputSettings = @{
        (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        (id)kCVPixelBufferMetalCompatibilityKey: @(YES),
    };
    AVAssetReaderTrackOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:assetTrack outputSettings:outputSettings];
    output.alwaysCopiesSampleData = NO;
    [reader addOutput:output];
    [reader startReading];
     
    NSTimeInterval duration = CMTimeGetSeconds(assetTrack.minFrameDuration);
     
    
    CMTime videoTotalTime = [asset duration];
    if (videoTotalTime.timescale) {
        _videoDuration = videoTotalTime.value / (videoTotalTime.timescale * 1.0f);
    } else {
        _videoDuration = 0.0f;
    }
    
    if (CGSizeEqualToSize(self.rgbSize, CGSizeZero)) {
        self.rgbSize = CGSizeMake(assetTrack.naturalSize.width / 2, assetTrack.naturalSize.height);
        
        if (self.region == YYEVAColorRegion_AlphaMP4_TopGrayBottomColor ||
                   self.region == YYEVAColorRegion_AlphaMP4_TopColorBottomGray) {
            self.rgbSize = CGSizeMake(assetTrack.naturalSize.width, assetTrack.naturalSize.height/2);
        }
    }
     
    _frameDuration = duration;
    _preferredFramesPerSecond = 1 / duration;
    _frameCount = _videoDuration / _frameDuration;
    _frameIndex = -1;
    _reader = reader;
    _output = output;
    
    [self readVideoTracksIntoQueueIfNeed];
    
    return YES;
}
 

- (void)readVideoTracksIntoQueueIfNeed
{
    if (self.reader.status != AVAssetReaderStatusReading) {
        NSLog(@"reader status: %@, error: %@", @(self.reader.status), self.reader.error);
        return;
    }
    
    @synchronized (self) {
        if (CFArrayGetCount(self->_sampleBufferQueue) > kSampleBufferQueueMaxCapacity) {
            return;
        }
    }
    
   dispatch_async(_readVideoBufferQueue, ^{
       do {
           CMSampleBufferRef sampleBufferRef = NULL;
           if (self.reader.status == AVAssetReaderStatusReading) {
               sampleBufferRef = [self.output copyNextSampleBuffer];
           }
           
           if (sampleBufferRef) {
               @synchronized (self) {
                   CFArrayAppendValue(self->_sampleBufferQueue, sampleBufferRef);
                   if(CFArrayGetCount(self->_sampleBufferQueue) > kSampleBufferQueueMaxCapacity){
                       break;
                   }
               }
           } else {
               break;
           }
       } while (YES);
   });
}

- (BOOL)hasNextSampleBuffer
{
   BOOL hasNext = NO;
   @synchronized (self) {
       hasNext = CFArrayGetCount(self->_sampleBufferQueue) > 0 || self.reader.status == AVAssetReaderStatusReading;
   }
   return hasNext;
}

- (CMSampleBufferRef)nextSampleBuffer
{
   CMSampleBufferRef ref = NULL;
   @synchronized (self) {
       if (self->_sampleBufferQueue) {
           if (CFArrayGetCount(self->_sampleBufferQueue) > 0) {
               ref = (CMSampleBufferRef)CFArrayGetValueAtIndex(self->_sampleBufferQueue, 0);
               CFArrayRemoveValueAtIndex(self->_sampleBufferQueue, 0);
               _frameIndex++;
               
               //第一帧读取代表开始
               if (_frameIndex == 0) {
                   if ([self.delegate respondsToSelector:@selector(assetsDidStart:)]) {
                       [self.delegate assetsDidStart:self];
                   }
               }
               
               if (self.delegate && [self.delegate respondsToSelector:@selector(assets:onPlayFrame:frameCount:)]) {
                   [self.delegate assets:self onPlayFrame:_frameIndex frameCount:_frameCount];
               }
           }
       }
   }
   
   [self readVideoTracksIntoQueueIfNeed];
   return ref;
}


- (void)clear
{
    //同步执行
    dispatch_sync(_readVideoBufferQueue, ^{
        if (self.reader && self.reader.status == AVAssetReaderStatusReading) {
            [self.reader cancelReading];
        }
        if (self->_sampleBufferQueue == NULL) {
            return;
        }
        NSInteger count = CFArrayGetCount(self->_sampleBufferQueue);
        if (count > 0) {
            for (NSInteger i = 0; i < count; i++) {
                CMSampleBufferRef ref = (CMSampleBufferRef)CFArrayGetValueAtIndex(self->_sampleBufferQueue, i);
                if (ref) {
                    CMSampleBufferInvalidate(ref);
                    CFRelease(ref);
                    ref = NULL;
                }
            }
        }
        CFArrayRemoveAllValues(self->_sampleBufferQueue);
    });
}

- (void)dealloc
{
    if (self->_sampleBufferQueue!=NULL) {
        CFRelease(self->_sampleBufferQueue);
    }
    self->_sampleBufferQueue = NULL;
    if (self.audioPlayer && [self.audioPlayer isPlaying]) {
        [self.audioPlayer stop];
    }
    self.audioPlayer = nil;
}

- (NSTimeInterval)totalDuration
{
    return self.videoDuration;
}

- (void)resumeAudio
{
    if (!_audioPlayer) {
        return;
    }
    
    if (![_audioPlayer isPlaying]) {
        [_audioPlayer play];
    }
}

- (void)pauseAudio
{
    if (!_audioPlayer) {
        return;
    }
    
    if ([_audioPlayer isPlaying]) {
        [_audioPlayer pause];
    }
}

- (void)tryPlayAudio
{
    if (!_audioPlayer) {
        return;
    }
    
    if ([_audioPlayer isPlaying]) {
        [_audioPlayer pause];
    }
    __weak typeof(self) weakself = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakself.audioPlayer.currentTime = 0.0f;
        [weakself.audioPlayer prepareToPlay];
        [weakself.audioPlayer play];
    });
    
}

- (void)reload
{
    [self tryPlayAudio];
    [self loadVideo];
}
 
- (BOOL)existAudio
{
    return self.audioPlayer != nil;
}

- (void)setVolume:(float)volume
{
    _volume = volume;
    self.audioPlayer.volume = volume;
}
 
@end
