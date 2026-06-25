//
//  YYEVADemuxMedia.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/7.
//

#import "YYEVADemuxMedia.h"
#import <zlib.h>

@interface YYEVADemuxMedia() <NSStreamDelegate>
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) dispatch_queue_t myDemuxQueue;
@end

@implementation YYEVADemuxMedia

- (instancetype)init
{
    if (self = [super init]) {
        _myDemuxQueue = dispatch_queue_create("com.yy.yymobile_eva.demux", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
  
- (NSDictionary *)demuxEffectJsonWithFilePath:(NSString *)file
{
    //文件路径
       //计算文件大小
   //    NSFileManager *fileManager = [NSFileManager defaultManager];
   //    NSDictionary *attriDict = [fileManager attributesOfItemAtPath:path error:nil];
       //获取文件大小
   //    NSString *fileSize = attriDict[NSFileSize];
        
       AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:file]];
       NSArray<AVMetadataItem *> *commonMetadata = asset.metadata;
       bool find = false;
       NSString *jsonStr = nil;
       for (AVMetadataItem *item in commonMetadata) {
           if ([item.value isKindOfClass:NSString.class]) {
               NSString *value = (NSString *)item.value;
               if ([value containsString:@"yyeffectmp4json[["]) {
                   find = true;
                   jsonStr = value;
               }
           }
       }
       NSString *matchStart = @"yyeffectmp4json[[";
       NSString *matchEnd = @"]]yyeffectmp4json";
         
       
       if ([jsonStr containsString:matchStart] && [jsonStr containsString:matchEnd]) {
           NSMutableString *json = [[NSMutableString alloc] initWithString:jsonStr];
           //匹配出中间字符串
           [json replaceOccurrencesOfString:matchStart withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, json.length)];
           
           [json replaceOccurrencesOfString:matchEnd withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, json.length)];
           
           NSString *result = (NSString *)json;
           
           NSDictionary *dict = [self parseWithBase64:result];
           return dict;
           
       }
       
       
    
    
    return nil;
     
}

- (NSDictionary *)parseWithBase64:(NSString *)stringBase64
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:stringBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];

    NSData *zlibData = [self zlibInflate:data];

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:zlibData options:kNilOptions error:nil];

    return json;

}

#pragma mark - VAP vapc box 解析

// 解析VAP格式的配置文件 (从MP4 vapc box中)
// vapc box 结构: [4bytes size][4bytes 'vapc'][JSON data...]
- (NSDictionary *)demuxVapConfigWithFilePath:(NSString *)filePath
{
    NSError *error = nil;
    NSData *fileData = [NSData dataWithContentsOfFile:filePath options:0 error:&error];
    if (error || !fileData) {
        return nil;
    }

    // 搜索 vapc box
    const uint8_t *bytes = fileData.bytes;
    NSUInteger length = fileData.length;
    NSUInteger offset = 0;

    while (offset + 8 < length) {
        // 读取box size (大端序)
        uint32_t boxSize = (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
                          (bytes[offset + 2] << 8) | bytes[offset + 3];

        // 读取box type
        char boxType[5] = {0};
        boxType[0] = bytes[offset + 4];
        boxType[1] = bytes[offset + 5];
        boxType[2] = bytes[offset + 6];
        boxType[3] = bytes[offset + 7];

        if (strcmp(boxType, "vapc") == 0) {
            // 找到 vapc box
            NSUInteger dataOffset = offset + 8;
            NSUInteger dataLength = boxSize > 8 ? boxSize - 8 : length - dataOffset;

            if (dataOffset + dataLength <= length) {
                NSData *vapcData = [fileData subdataWithRange:NSMakeRange(dataOffset, dataLength)];
                NSError *jsonError = nil;
                NSDictionary *configDic = [NSJSONSerialization JSONObjectWithData:vapcData
                                                                        options:kNilOptions
                                                                          error:&jsonError];
                if (jsonError) {
                    NSLog(@"VAP config parse error: %@", jsonError);
                    return nil;
                }
                // 转换为YYEVA格式
                return [self convertVapConfigToYYEVAFormat:configDic];
            }
        }

        // 移动到下一个box
        if (boxSize == 0) {
            // box延伸到文件末尾
            break;
        }
        if (boxSize < 8) {
            // 无效box size
            break;
        }
        offset += boxSize;
    }

    return nil;
}

// 将VAP格式的配置转换为YYEVA格式
- (NSDictionary *)convertVapConfigToYYEVAFormat:(NSDictionary *)vapConfig
{
    NSDictionary *info = [self vap_dictValue:vapConfig key:@"info"];
    if (!info) {
        info = vapConfig; // 兼容某些情况直接是顶层配置
    }

    // 提取基本信息
    NSInteger w = [self vap_integerValue:info key:@"w"];
    NSInteger h = [self vap_integerValue:info key:@"h"];
    NSInteger videoW = [self vap_integerValue:info key:@"videoW"];
    NSInteger videoH = [self vap_integerValue:info key:@"videoH"];
    NSInteger isVapx = [self vap_integerValue:info key:@"isVapx"];

    // rgbFrame 和 alphaFrame
    NSArray *rgbFrameArr = [self vap_arrayValue:info key:@"rgbFrame"];
    NSArray *alphaFrameArr = [self vap_arrayValue:info key:@"aFrame"];

    // 转换为YYEVA格式
    NSMutableDictionary *yyevaConfig = [NSMutableDictionary dictionary];

    // descript 部分
    NSMutableDictionary *descript = [NSMutableDictionary dictionary];
    descript[@"width"] = @(w);
    descript[@"height"] = @(h);
    descript[@"isEffect"] = @(isVapx == 1 ? 1 : 0);
    descript[@"version"] = @"1.0";

    // 如果有videoW/videoH，使用它们覆盖width/height
    if (videoW > 0) {
        descript[@"width"] = @(videoW);
    }
    if (videoH > 0) {
        descript[@"height"] = @(videoH);
    }

    // rgbFrame
    if (rgbFrameArr && rgbFrameArr.count >= 4) {
        descript[@"rgbFrame"] = rgbFrameArr;
    } else {
        // 默认值
        descript[@"rgbFrame"] = @[@0, @0, @(w), @(h)];
    }

    // alphaFrame
    if (alphaFrameArr && alphaFrameArr.count >= 4) {
        descript[@"alphaFrame"] = alphaFrameArr;
    } else {
        // 默认值
        descript[@"alphaFrame"] = @[@0, @0, @(w), @(h)];
    }

    yyevaConfig[@"descript"] = descript;

    // sources (src) 转换
    NSArray *sources = [self vap_arrayValue:vapConfig key:@"src"];
    if (sources) {
        NSMutableArray *effects = [NSMutableArray array];
        for (NSDictionary *source in sources) {
            NSString *srcId = [self vap_stringValue:source key:@"srcId"];
            NSString *srcType = [self vap_stringValue:source key:@"srcType"];
            NSString *srcTag = [self vap_stringValue:source key:@"srcTag"];
            CGFloat sw = [self vap_floatValue:source key:@"w"];
            CGFloat sh = [self vap_floatValue:source key:@"h"];
            NSString *color = [self vap_stringValue:source key:@"color"];
            NSString *fitType = [self vap_stringValue:source key:@"fitType"];

            NSMutableDictionary *effect = [NSMutableDictionary dictionary];
            effect[@"effectId"] = srcId ?: @"0";
            effect[@"effectTag"] = srcTag ?: @"";

            // 类型转换
            if ([srcType isEqualToString:@"txt"]) {
                effect[@"effectType"] = @"txt";
            } else if ([srcType isEqualToString:@"img"]) {
                effect[@"effectType"] = @"img";
            }

            effect[@"effectWidth"] = @(sw);
            effect[@"effectHeight"] = @(sh);

            if (color) {
                effect[@"fontColor"] = color;
            }
            if (fitType) {
                effect[@"scaleMode"] = fitType;
            }

            [effects addObject:effect];
        }
        yyevaConfig[@"effect"] = effects;
    }

    // frames (frame) 转换
    NSArray *frames = [self vap_arrayValue:vapConfig key:@"frame"];
    if (frames) {
        NSMutableArray *datas = [NSMutableArray array];
        for (NSDictionary *frame in frames) {
            NSInteger frameIndex = [self vap_integerValue:frame key:@"i"];
            NSArray *objs = [self vap_arrayValue:frame key:@"obj"];

            if (objs) {
                NSMutableArray *frameData = [NSMutableArray array];
                for (NSDictionary *obj in objs) {
                    NSString *srcId = [self vap_stringValue:obj key:@"srcId"];
                    NSArray *frameRect = [self vap_arrayValue:obj key:@"frame"];
                    NSArray *maskRect = [self vap_arrayValue:obj key:@"mFrame"];

                    NSMutableDictionary *frameObj = [NSMutableDictionary dictionary];
                    frameObj[@"effectId"] = [self findEffectIdBySrcId:srcId inConfig:vapConfig] ?: @"0";

                    if (frameRect && frameRect.count >= 4) {
                        frameObj[@"renderFrame"] = frameRect;
                    }
                    if (maskRect && maskRect.count >= 4) {
                        frameObj[@"outputFrame"] = maskRect;
                    }

                    [frameData addObject:frameObj];
                }

                NSDictionary *frameDict = @{
                    @"frameIndex": @(frameIndex),
                    @"data": frameData
                };
                [datas addObject:frameDict];
            }
        }
        yyevaConfig[@"datas"] = datas;
    }

    return yyevaConfig;
}

// 根据srcId查找对应的effectId
- (NSString *)findEffectIdBySrcId:(NSString *)srcId inConfig:(NSDictionary *)config
{
    NSArray *sources = [self vap_arrayValue:config key:@"src"];
    for (NSInteger i = 0; i < sources.count; i++) {
        NSDictionary *source = sources[i];
        NSString *sid = [self vap_stringValue:source key:@"srcId"];
        if ([sid isEqualToString:srcId]) {
            return [@(i) stringValue];
        }
    }
    return @"0";
}

#pragma mark - VAP 字典安全访问

- (NSDictionary *)vap_dictValue:(NSDictionary *)dict key:(NSString *)key
{
    id value = dict[key];
    if ([value isKindOfClass:[NSDictionary class]]) {
        return value;
    }
    return nil;
}

- (NSArray *)vap_arrayValue:(NSDictionary *)dict key:(NSString *)key
{
    id value = dict[key];
    if ([value isKindOfClass:[NSArray class]]) {
        return value;
    }
    return nil;
}

- (NSString *)vap_stringValue:(NSDictionary *)dict key:(NSString *)key
{
    id value = dict[key];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    return nil;
}

- (NSInteger)vap_integerValue:(NSDictionary *)dict key:(NSString *)key
{
    id value = dict[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value integerValue];
    }
    return 0;
}

- (CGFloat)vap_floatValue:(NSDictionary *)dict key:(NSString *)key
{
    id value = dict[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value floatValue];
    }
    return 0;
}

- (NSString *)findString:(NSString *)match withString:(NSString *)bufStr isStart:(BOOL)isStart
{
    NSMutableString *mediaStr = [NSMutableString string];
     
    if ([bufStr containsString:match]) {
        NSRange range = [bufStr rangeOfString:match];
        if (range.location != NSNotFound) {
            NSLog(@"find match success %d",isStart);
            if (isStart) {
                [mediaStr appendString:[bufStr substringFromIndex:range.location]];
            } else {
                [mediaStr appendString:[bufStr substringWithRange:NSMakeRange(0, range.location + range.length)]];
            }
        }
    } 
    
    return mediaStr;
}



- (NSData *)zlibInflate:(NSData *)data
{
    if ([data length] == 0) {
        return data;
    }
    
    unsigned full_length = (unsigned)[data length];
    unsigned half_length = (unsigned)[data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = (unsigned)[data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit (&strm) != Z_OK) {
        return nil;
    }
    
    while (!done) {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
        }
        
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
            done = YES;
        } else if (status != Z_OK) {
            break;
        }
    }
    
    if (inflateEnd (&strm) != Z_OK) {
        return nil;
    }
    
    // Set real length.
    if (done) {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    
    return nil;
}

@end
