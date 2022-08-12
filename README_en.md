# YYEVA <sup>iOS</sup>  
> Lightweight,High Performance,Cross Platform,MP4 Gift Player

## Intruduction
+ YYEVAPlayer is a lightweight animation library with a simple yet powerful API。Reference [here](https://github.com/yylive/YYEVA/blob/main/YYEVA%E8%AE%BE%E8%AE%A1%E8%A7%84%E8%8C%83.md) can easily export animation resources
+ YYEVA-iOS render with Metal library , providing you with a high-performance, low-cost animation experience.

## Platform support
+ Platform：[Android](https://github.com/yylive/YYEVA-Android), [iOS](https://github.com/yylive/YYEVA-iOS), [Web](https://github.com/yylive/YYEVA-Web) 
+ Generation Tool : [AE plguin](https://github.com/yylive/YYEVA/tree/main/AEP) 
+ [Data structure](https://github.com/yylive/YYEVA/blob/main/%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84.md)
+ [Docs](https://github.com/yylive/YYEVA)

## Usage

### Installation with CocoaPods

To integrate YYEVA into your Xcode project using CocoaPods, specify it in your Podfile:

```ruby
pod 'YYEVA', '~> 1.0.3'
```

### create `YYEVAPlayer` instance

```c++ 
YYEVAPlayer *player = [[YYEVAPlayer alloc] init];
[self.view addSubview:player]; 

//config dynmaic elements 
[player setImageUrl:localPath forKey:@"image_key1"];   
[player setImageUrl:localPath forKey:@"image_key2"];
[player setImageUrl:localPath forKey:@"image_key3"];
[player setText:str.text forKey:@"text_key1"];
 
[player play:file];
     
```

The following interfaces provide the ability to dynamically insert business text or pictures

+ setImageUrl:forKey    
+ setText:forKey 

### QQ exchange group

![qqgroup](https://github.com/yylive/YYEVA/blob/main/img/qqgroup.png)
 

### Dev Team

<table>
  <tbody>
    <tr>
      <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/14030762?v=4&s=80">
        <br>
        <a href="https://github.com/guoyabiniOS">GuoyabiniOS</a>
      </td>
      <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/44636610?v=4&s=80">
        <br>
        <a href="https://github.com/ganpenglong">Ganpenglong</a>
      </td>
    <td align="center" valign="top">
        <img style="border-radius:8px" width="80" height="80" src="https://avatars.githubusercontent.com/u/12680946?v=4&s=80">
        <br>
        <a href="https://github.com/WickyLeung">WickyLeung</a>
      </td> 
     </tr>
  </tbody>
</table>

