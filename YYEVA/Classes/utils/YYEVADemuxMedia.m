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
