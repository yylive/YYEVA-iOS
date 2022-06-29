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
- (NSDictionary *)demuxEffectJsonWithFilePath:(NSString *)url;
@end

NS_ASSUME_NONNULL_END
