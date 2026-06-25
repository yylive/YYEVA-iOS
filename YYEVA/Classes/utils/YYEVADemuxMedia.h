//
//  YYEVADemuxMedia.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/7.
//

#import <Foundation/Foundation.h>
#import "YYEVAAssets.h"
#import "YYEVAEffectInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface YYEVADemuxMedia : NSObject
// 解析YYEVA格式的配置文件 (从MP4元数据中)
- (NSDictionary *)demuxEffectJsonWithFilePath:(NSString *)url;
// 解析VAP格式的配置文件 (从MP4 vapc box中)
- (NSDictionary *)demuxVapConfigWithFilePath:(NSString *)url;
@end

NS_ASSUME_NONNULL_END
