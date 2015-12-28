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

#import "TUIGeometry.h"

const TUIEdgeInsets TUIEdgeInsetsZero = { 0.0, 0.0, 0.0, 0.0 };

const TUIFontMetrics TUIFontMetricsZero = {0, 0, 0};
const TUIFontMetrics TUIFontMetricsNull = {NSNotFound, NSNotFound, NSNotFound};

@implementation NSCoder (TUIFontMetricsKeyedCoding)

- (void)tui_encodeFontMetrics:(TUIFontMetrics)metrics forKey:(NSString *)key
{
    NSRect concrete = NSMakeRect(metrics.ascent, metrics.descent, metrics.leading, 0);
    
    [self encodeRect:concrete forKey:key];
}

- (TUIFontMetrics)tui_decodeFontMetricsForKey:(NSString *)key
{
    NSRect concrete = [self decodeRectForKey:key];
    
    return TUIFontMetricsMake(concrete.origin.x, concrete.origin.y, concrete.size.width);
}

@end

static TUIFontMetrics TUICachedFontMetrics[13];

TUIFontMetrics TUIFontMetricsGetDefault(NSInteger pointSize)
{
    if (pointSize < 8 || pointSize > 20)
    {
        NSFont * font = [NSFont systemFontOfSize:pointSize];
        return TUIFontMetricsMakeFromNSFont(font);
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            for (NSInteger i = 0; i < 13; i++) {
                NSUInteger pointSize = i + 8;
                NSFont * font = [NSFont systemFontOfSize:pointSize];
                TUICachedFontMetrics[i] = TUIFontMetricsMakeFromNSFont(font);
            }
        }
    });
    
    return TUICachedFontMetrics[pointSize - 8];
}
