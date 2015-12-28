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

#import <Foundation/Foundation.h>

typedef struct TUIEdgeInsets {
	CGFloat top, left, bottom, right;  // specify amount to inset (positive) for each of the edges. values can be negative to 'outset'
} TUIEdgeInsets;

static inline TUIEdgeInsets TUIEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right) {
	TUIEdgeInsets insets = {top, left, bottom, right};
	return insets;
}

static inline CGRect TUIEdgeInsetsInsetRect(CGRect rect, TUIEdgeInsets insets) {
	rect.origin.x    += insets.left;
	rect.origin.y    += insets.bottom;
	rect.size.width  -= (insets.left + insets.right);
	rect.size.height -= (insets.top  + insets.bottom);
	return rect;
}

static inline TUIEdgeInsets TUIEdgeInsetsInvert(TUIEdgeInsets insets) {
    return (TUIEdgeInsets){-insets.top, -insets.left, -insets.bottom, -insets.right};
}

static inline BOOL TUIEdgeInsetsEqualToEdgeInsets(TUIEdgeInsets insets1, TUIEdgeInsets insets2) {
    return insets1.left == insets2.left && insets1.top == insets2.top && insets1.right == insets2.right && insets1.bottom == insets2.bottom;
}

extern const TUIEdgeInsets TUIEdgeInsetsZero;

/**
 * @brief Constrain a point to a rectangular region
 * 
 * If the provided @p point lies outside the @p rect, it is adjusted to the
 * nearest point that lies inside the @p rect.
 * 
 * @param point a point
 * @param rect the constraining rect
 * @return constrained point
 */
static inline CGPoint CGPointConstrainToRect(CGPoint point, CGRect rect) {
  return CGPointMake(MAX(rect.origin.x, MIN((rect.origin.x + rect.size.width), point.x)), MAX(rect.origin.y, MIN((rect.origin.y + rect.size.height), point.y)));
}

struct TUIFontMetrics {
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
};
typedef struct TUIFontMetrics TUIFontMetrics;

static inline TUIFontMetrics TUIFontMetricsMake(CGFloat a, CGFloat d, CGFloat l)
{
    TUIFontMetrics metrics;
    metrics.ascent = a;
    metrics.descent = d;
    metrics.leading = l;
    return metrics;
}

extern const TUIFontMetrics TUIFontMetricsZero;
extern const TUIFontMetrics TUIFontMetricsNull;

static inline TUIFontMetrics TUIFontMetricsMakeFromNSFont(NSFont * font)
{
    if (!font) {
        return TUIFontMetricsNull;
    }
    
    TUIFontMetrics metrics;
    metrics.ascent = ABS(font.ascender);
    metrics.descent = ABS(font.descender);
    metrics.leading = ABS(font.leading) - metrics.ascent - metrics.descent;
    return metrics;
}
static inline TUIFontMetrics TUIFontMetricsMakeFromCTFont(CTFontRef font)
{
    return TUIFontMetricsMake(ABS(CTFontGetAscent(font)), ABS(CTFontGetDescent(font)), ABS(CTFontGetLeading(font)));
}

static inline TUIFontMetrics TUIFontMetricsMakeWithTargetLineHeight(TUIFontMetrics metrics, CGFloat targetLineHeight)
{
    return TUIFontMetricsMake(targetLineHeight - metrics.descent - metrics.leading, metrics.descent, metrics.leading);
}

static inline CGFloat TUIFontMetricsGetLineHeight(TUIFontMetrics metrics)
{
    return ceil(metrics.ascent + metrics.descent + metrics.leading);
}

static inline BOOL TUIFontMetricsEqual(TUIFontMetrics m1, TUIFontMetrics m2)
{
    return m1.ascent == m2.ascent && m1.descent == m2.descent && m1.leading == m2.leading;
}

extern TUIFontMetrics TUIFontMetricsGetDefault(NSInteger pointSize);

@interface NSCoder (TUIFontMetricsKeyedCoding)

- (void)tui_encodeFontMetrics:(TUIFontMetrics)metrics forKey:(NSString *)key;
- (TUIFontMetrics)tui_decodeFontMetricsForKey:(NSString *)key;

@end

#import "TUIFont.h"

static inline TUIFontMetrics TUIFontMetricsMakeFromTUIFont(TUIFont * font)
{
    if (!font) {
        return TUIFontMetricsNull;
    }
    return TUIFontMetricsMake(font.ascender, font.descender, font.leading);
}
