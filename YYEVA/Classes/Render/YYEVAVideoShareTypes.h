//
//  YYEVAVideoShareTypes.h
//
//  Created by guoyabin on 2022/4/21.
//
 
#import <simd/simd.h>
 
   
typedef struct{
    vector_float4 positon;
    vector_float2 texturCoordinate;
}YSVideoMetalVertex;


typedef struct{
    vector_float4 positon;
    vector_float2 rgbTexturCoordinate;
    vector_float2 alphaTexturCoordinate;
}YSVideoMetalMaskVertex;

//YSVideoMetalElementVertex
//    vector_float4 positon;  4  -> 画在哪里？
//    vector_float2 sourceTextureCoordinate; 2 -> sourceCoordinates 整个纹理坐标 0->1
//    vector_float2 maskTextureCoordinate; 2  ->  mask的坐标

typedef struct{
    vector_float4 positon;
    vector_float2 sourceTextureCoordinate;
    vector_float2 maskTextureCoordinate; 
    
}YSVideoMetalElementVertex;

  
typedef struct{
    matrix_float3x3 matrix;
    vector_float3 offset;
}YSVideoMetalConvertMatrix;


//顶点函数输入索引
typedef enum
{
    YSVideoMetalVertexInputIndexVertices     = 0,
} YSVideoMetalVertexInputIndex;

//片元函数缓存区索引
typedef enum CCFragmentBufferIndex
{
    YSVideoMetalFragmentBufferIndexMatrix     = 0,
} YSVideoMetalFragmentBufferIndex;

//片元函数纹理索引
typedef enum
{
    //Y纹理
    YSVideoMetalFragmentTextureIndexTextureY     = 0,
    //UV纹理
    YSVideoMetalFragmentTextureIndexTextureUV     = 1,
} YSVideoMetalFragmentTextureIndex;

 

struct YSVideoElementFragmentParameter {
    
    int needOriginRGB;
    vector_float4 fillColor;
};
 


