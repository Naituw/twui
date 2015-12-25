/*
 Copyright 2011 Twitter, Inc.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this work except in compliance with the License.
 You may obtain a copy of the License in the LICENSE file, or at:
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "TUIFont.h"

@implementation TUIFont

- (id)initWithCTFont:(CTFontRef)f
{
    if((self = [super init]))
    {
        _ctFont = f;
        CFRetain(_ctFont);
    }
    return self;
}

- (void)dealloc
{
    if(_ctFont)
        CFRelease(_ctFont);
}

static NSRange MakeNSRangeFromEndpoints(NSUInteger first, NSUInteger last) {
    return NSMakeRange(first, last - first + 1);
}

static NSArray * defaultFallbacks = nil;
static NSDictionary *CachedFontDescriptors = nil;

+ (void)initialize
{
    if(self == [TUIFont class]) {
        NSMutableArray * fallbacks = [NSMutableArray array];
        
        NSArray * externalFons = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TUIExternalFonts"];
        [externalFons enumerateObjectsUsingBlock:^(NSString * fontName, NSUInteger idx, BOOL *stop) {
            NSURL * path = [[NSBundle mainBundle] URLForResource:fontName withExtension:nil];
            NSArray * descriptors = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((CFURLRef)path));
            [fallbacks addObjectsFromArray:descriptors];
        }];
        
        // fallback stuff prevents massive stalls
        NSRange range = MakeNSRangeFromEndpoints(0x2100, 0x214F);
        NSCharacterSet *letterlikeSymbolsSet = [NSCharacterSet characterSetWithRange:range];
        [fallbacks addObject:[NSFontDescriptor fontDescriptorWithFontAttributes:
                              [NSDictionary dictionaryWithObjectsAndKeys:
                               @"ArialUnicodeMS", NSFontNameAttribute,
                               letterlikeSymbolsSet, NSFontCharacterSetAttribute,
                               nil]]];
        
        defaultFallbacks = fallbacks;
        
        NSString *normalFontName = [self defaultFontName];
        NSString *lightFontName = [self lightDefaultFontName];
        NSString *mediumFontName = [self defaultFontName];
        NSString *boldFontName = [self boldDefaultFontName];
        
        NSFontDescriptor *D_HelveticaNeue = [self fontDescriptorWithName:normalFontName];
        NSFontDescriptor *D_HelveticaNeue_Light = [self fontDescriptorWithName:lightFontName];
        NSFontDescriptor *D_HelveticaNeue_Medium = [self fontDescriptorWithName:mediumFontName];
        NSFontDescriptor *D_HelveticaNeue_Bold = [self fontDescriptorWithName:boldFontName];
        
        CachedFontDescriptors = [NSDictionary dictionaryWithObjectsAndKeys:
                                 D_HelveticaNeue, normalFontName,
                                 D_HelveticaNeue_Light, lightFontName,
                                 D_HelveticaNeue_Medium, mediumFontName,
                                 D_HelveticaNeue_Bold, boldFontName,
                                 nil];
    }
}

+ (NSFontDescriptor *)fontDescriptorWithName:(NSString *)fontName
{
    NSFontDescriptor *desc = [CachedFontDescriptors objectForKey:fontName];

    if(!desc) {
        NSMutableArray * fallbacks = [NSMutableArray array];
        [fallbacks addObjectsFromArray:defaultFallbacks];
        
        NSString * chineseFontName = [[self chineseFallbackFontNameMap] objectForKey:fontName];
        if (chineseFontName) {
            // fallback for chinese characters
            NSRange range = MakeNSRangeFromEndpoints(0x4E00, 0x9FA5);
            NSMutableCharacterSet * chineseCharacterSet = [NSMutableCharacterSet characterSetWithRange:range];
            [chineseCharacterSet addCharactersInRange:MakeNSRangeFromEndpoints(0x3000, 0x303F)];
            [chineseCharacterSet addCharactersInRange:MakeNSRangeFromEndpoints(0xFF00, 0xFFEF)];
            [fallbacks addObject:[[NSFontDescriptor alloc] initWithFontAttributes:@{NSFontNameAttribute: chineseFontName, NSFontCharacterSetAttribute: chineseCharacterSet}]];
        }
        
        desc = [NSFontDescriptor fontDescriptorWithFontAttributes:
                [NSDictionary dictionaryWithObjectsAndKeys:
                 fontName, NSFontNameAttribute,
                 fallbacks, NSFontCascadeListAttribute, // oh thank you jesus
                 nil]];
    }

    return desc;
}

+ (TUIFont *)fontWithNSFont:(NSFont *)font
{
    return [[TUIFont alloc] initWithCTFont:(CTFontRef)font];
}

+ (TUIFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize
{
    NSFontDescriptor *desc = [self fontDescriptorWithName:fontName];
    CTFontRef font = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)desc, fontSize, NULL);
    TUIFont *uiFont = [[TUIFont alloc] initWithCTFont:font];
    CFRelease(font);
    
    return uiFont;
}

+ (TUIFont *)systemFontOfSize:(CGFloat)fontSize
{
    TUIFont *uifont = [[TUIFont alloc] initWithCTFont:(CTFontRef)[NSFont systemFontOfSize:fontSize]];
    return uifont;
}

+ (TUIFont *)boldSystemFontOfSize:(CGFloat)fontSize
{
    TUIFont *uifont = [[TUIFont alloc] initWithCTFont:(CTFontRef)[NSFont boldSystemFontOfSize:fontSize]];
    return uifont;
}

- (NSString *)familyName { return (__bridge_transfer NSString *)CTFontCopyFamilyName(_ctFont); }
- (NSString *)fontName { return (__bridge_transfer NSString *)CTFontCopyPostScriptName(_ctFont); }
- (CGFloat)pointSize { return CTFontGetSize(_ctFont); }
- (CGFloat)ascender { return CTFontGetAscent(_ctFont); }
- (CGFloat)descender { return CTFontGetDescent(_ctFont); }
- (CGFloat)leading { return CTFontGetLeading(_ctFont); }
- (CGFloat)capHeight { return CTFontGetCapHeight(_ctFont); }
- (CGFloat)xHeight { return CTFontGetXHeight(_ctFont); }

- (TUIFont *)fontWithSize:(CGFloat)fontSize
{
    return nil;
}

- (CTFontRef)ctFont
{
    return _ctFont;
}

+ (NSString *)defaultFontName
{
    static NSString * name = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFont * f = [NSFont systemFontOfSize:14];
        if (f) {
            name = f.fontName;
        }
        
        if (!name) {
            name = @"Helvetica Neue";
        }
    });
    return name;
}

+ (NSString *)fontNameWithTrait:(NSString *)trait defaultFontName:(NSString *)fontName
{
    if ([NSFont respondsToSelector:@selector(systemFontOfSize:weight:)] && [fontName isEqual:[self defaultFontName]]) {
        CGFloat weight = NSFontWeightRegular;
        if ([trait isEqualToString:@"Bold"]) {
            weight = NSFontWeightBold;
        } else if ([trait isEqualToString:@"Light"]) {
            weight = NSFontWeightLight;
        } else if ([trait isEqualToString:@"Medium"]) {
            weight = NSFontWeightMedium;
        }
        NSFont * font = [NSFont systemFontOfSize:14 weight:weight];
        return font ? font.fontName : fontName;
    } else {
        NSString * const originalFontName = fontName;
        NSString * regularSuffix = @"-Regular";
        if ([fontName hasSuffix:regularSuffix]) {
            fontName = [fontName substringToIndex:fontName.length - regularSuffix.length];
        }
        NSString * name = [NSString stringWithFormat:@"%@-%@", fontName, trait];
        NSFont * font = [NSFont fontWithName:name size:14];
        name = font ? font.fontName : originalFontName;
        
        return name;
    }
}

+ (NSString *)lightDefaultFontName
{
    static NSString * name = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        name = [self fontNameWithTrait:@"Light" defaultFontName:[self defaultFontName]];
    });
    return name;
}

+ (NSString *)mediumDefaultFontName
{
    static NSString * name = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        name = [self fontNameWithTrait:@"Medium" defaultFontName:[self defaultFontName]];
    });
    return name;
}

+ (NSString *)boldDefaultFontName
{
    static NSString * name = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        name = [self fontNameWithTrait:@"Bold" defaultFontName:[self defaultFontName]];
    });
    return name;
}

+ (NSDictionary *)chineseFallbackFontNameMap
{
    static NSDictionary * fallbacks = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary * map = [NSMutableDictionary dictionary];
        
        NSString * fontName = [self defaultFontName];
        NSFont * defaultFont = [NSFont fontWithName:fontName size:14];
        NSString * chineseFontName = CFBridgingRelease(CTFontCopyPostScriptName(CTFontCreateForString((CTFontRef)defaultFont, (CFStringRef)@"你好", (CFRange){0, 2})));
        if (chineseFontName) {
            [map setObject:chineseFontName forKey:fontName];
            [map setObject:[self fontNameWithTrait:@"Light" defaultFontName:chineseFontName] forKey:[self fontNameWithTrait:@"Light" defaultFontName:fontName]];
            [map setObject:[self fontNameWithTrait:@"Medium" defaultFontName:chineseFontName] forKey:[self fontNameWithTrait:@"Medium" defaultFontName:fontName]];
            [map setObject:[self fontNameWithTrait:@"Medium" defaultFontName:chineseFontName] forKey:[self fontNameWithTrait:@"Bold" defaultFontName:fontName]]; // PingFang & STHeiti both don't have an bold-face, use Medium here
        }
        
        fallbacks = map;
    });
    
    return fallbacks;
}

@end
