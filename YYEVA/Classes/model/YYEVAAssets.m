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
   
#define kSampleBufferQueueMaxCapacity 3

@interface YYEVAAssets()
{
    CFMutableArrayRef _sampleBufferQueue;
}
@property (nonatomic, strong) dispatch_queue_t readVideoBufferQueue;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@property (nonatomic, assign) NSTimeInterval videoDuration;
@property (nonatomic, assign) NSTimeInterval frameDuration;
@property (nonatomic, strong) YYEVADemuxMedia *demuxer;
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
                source.sourceImage = [UIImage imageWithContentsOfFile:content];
            } else if (source.type == YYEVAEffectSourceTypeText) {
                UIColor *color = [UIColor whiteColor];
                if (source.fontColor) {
                    const char *cStr = [source.fontColor cStringUsingEncoding:NSASCIIStringEncoding];
                    long x = strtol(cStr + 1, NULL, 16);
                    float r = (float)((x >> 16) & 0x000000FF) / 255.0f;
                    float g = (float)((x >> 8) & 0x000000FF) / 255.0f;
                    float b = (float)(x & 0x000000FF) / 255.0f;
                    color = [UIColor colorWithRed:r green:g blue:b alpha:1.0f];
                }
                source.sourceImage = [YSVideoMetalUtils imageWithText:content
                                                            textColor:color
                                                             fontSize:source.fontSize
                                                             rectSize:CGSizeMake(source.width, source.height)];
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

//metal:texture
- (void)loadVideo
{
    if (!self.filePath || ![[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
        NSLog(@"filepath not exits:%@",self.filePath);
        return;
    }
      
    NSDictionary *dictionary = [self.demuxer demuxEffectJsonWithFilePath:self.filePath];
    
    YYEVAEffectInfo *effectInfo = [YYEVAEffectInfo effectInfoWithDictionary:dictionary];
    
    _effectInfo = effectInfo;
    
    if (effectInfo) {
        self.isEffectVideo = YES;
    } else {
        self.isEffectVideo = NO;
    }
    
    
    if (self.isEffectVideo) {
        [self reloadEffect];
        self.size = CGSizeMake(self.effectInfo.videoWidth, self.effectInfo.videoHeight);
    }
    
    //asset
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:self.filePath] options:nil];
    
    if (!asset) {
        NSLog(@"load asset url:%@ failure",self.filePath);
        return;
    }
    
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    
    if (!reader) {
        NSLog(@"assetReaderWithAsset:%@ failure",self.filePath);
        return;
    }
    AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!assetTrack) {
        NSLog(@"tracksWithMediaType url:%@ failure",self.filePath);
        return;
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
    _frameDuration = duration;
    _preferredFramesPerSecond = 1 / duration;
    _frameIndex = -1;
    _reader = reader;
    _output = output;
}
 

- (void)readVideoTracksIntoQueueIfNeed
{
   dispatch_async(_readVideoBufferQueue, ^{
       do {
           @synchronized (self) {
               
               if (CFArrayGetCount(self->_sampleBufferQueue) > kSampleBufferQueueMaxCapacity) {
                   break;
               }
           }
           
           CMSampleBufferRef sampleBufferRef = [self.output copyNextSampleBuffer];
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
       if (CFArrayGetCount(self->_sampleBufferQueue) > 0) {
           
           ref = (CMSampleBufferRef)CFArrayGetValueAtIndex(self->_sampleBufferQueue, 0);
           CFArrayRemoveValueAtIndex(self->_sampleBufferQueue, 0);
            
           _frameIndex++;
       }
   }
   [self readVideoTracksIntoQueueIfNeed];
   return ref;
}


- (void)clear
{
    [self.reader cancelReading];
    CFArrayRemoveAllValues(self->_sampleBufferQueue);
}

- (void)dealloc
{
    [self clear];
    CFRelease(self->_sampleBufferQueue);
    self->_sampleBufferQueue = NULL;
}

- (NSTimeInterval)totalDuration
{
    return self.videoDuration;
}
@end
