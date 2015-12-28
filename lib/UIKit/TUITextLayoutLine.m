//
//  TUITextLayoutLine.m
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextLayoutLine.h"
#import "TUITextLayoutLine_Private.h"
#import "TUITextLayout_Private.h"

@interface TUITextLayoutLine ()
{
    CTLineRef _lineRef;
    CFRange _lineRefRange;
}

@property (nonatomic, weak) TUITextLayout * layout;
@property (nonatomic, assign) CGFloat width;

@end

@implementation TUITextLayoutLine

- (void)dealloc
{
    if (_lineRef) {
        CFRelease(_lineRef), _lineRef = NULL;
    }
}

- (instancetype)initWithCTLine:(CTLineRef)lineRef origin:(CGPoint)origin layout:(TUITextLayout *)layout
{
    return [self initWithCTLine:lineRef origin:origin layout:layout truncatedLine:NULL];
}

- (instancetype)initWithCTLine:(CTLineRef)lineRef origin:(CGPoint)origin layout:(TUITextLayout *)layout truncatedLine:(CTLineRef)truncatedLineRef
{
    if (self = [self init]) {
        _originalBaselineOrigin = origin;
        _layout = layout;
        _truncated = truncatedLineRef != NULL;
        if (lineRef) {
            _lineRef = CFRetain(truncatedLineRef ? : lineRef);
            
            CFRange range = CTLineGetStringRange(lineRef);
            if (truncatedLineRef) {
                CFRange truncatedRange = CTLineGetStringRange(truncatedLineRef);
                range.length = truncatedRange.length;
            }
            _stringRange = NSMakeRange(range.location, range.length);
            _lineRefRange = CTLineGetStringRange(_lineRef);
            
            [self setupWithCTLine];
        }
    }
    return self;
}

- (void)setupWithCTLine
{
    const CTLineRef lineRef = _lineRef;
    const TUIFontMetrics baselineFontMetrics = _layout.baselineFontMetrics;
    
    CGFloat a, d, l;
    _width = CTLineGetTypographicBounds(lineRef, &a, &d, &l);
    _baselineOrigin = _originalBaselineOrigin;
    _originalLineMetrics = TUIFontMetricsMake(ABS(a), ABS(d), ABS(l));
    _lineMetrics = _originalLineMetrics;
    
    double baselineOriginY = _baselineOrigin.y; // 强制使用 double 进行下列计算，否则在 32 位运行时可能丢失精度
    
    if (baselineFontMetrics.descent != NSNotFound) {
        baselineOriginY -= (_lineMetrics.descent - baselineFontMetrics.descent);
    }
    
    if (baselineFontMetrics.leading != NSNotFound && baselineFontMetrics.leading) {
        // FIXME: 我们应该从当前的 paragraphStyle 决定最大 leading 是多少，而不是写死基准的 3 倍
        _lineMetrics.leading = MIN(_lineMetrics.leading, baselineFontMetrics.leading * 3);
        baselineOriginY -= (_lineMetrics.leading - baselineFontMetrics.leading);
    }
    
    _baselineOrigin.y = floor(baselineOriginY);
    
    // we store values in UIKit coordinates
    _baselineOrigin = [_layout convertPointFromCoreText:_baselineOrigin];
    _originalBaselineOrigin = [_layout convertPointFromCoreText:_originalBaselineOrigin];
    
    if (baselineFontMetrics.ascent == NSNotFound && _layout.retriveFontMetricsAutomatically) {
        _layout.baselineFontMetrics = _lineMetrics;
    }
}

- (CGRect)originalFragmentRect
{
    return TUITextGetLineFragmentRect(_originalBaselineOrigin, _originalLineMetrics, _width);
}

- (CGRect)fragmentRect
{
    return TUITextGetLineFragmentRect(_baselineOrigin, _lineMetrics, _width);
}

- (CTLineRef)lineRef
{
    return _lineRef;
}

static CGRect TUITextGetLineFragmentRect(CGPoint baselineOrigin, TUIFontMetrics lineMetrics, CGFloat width)
{
    return CGRectIntegral(CGRectMake(baselineOrigin.x, baselineOrigin.y - lineMetrics.ascent, width, TUIFontMetricsGetLineHeight(lineMetrics)));
}

@end

@implementation TUITextLayoutLine (LayoutResult)

- (NSInteger)locationDeltaFromRealRangeToLineRefRange
{
    if (!_lineRef) {
        return 0;
    }
    
    // 当 _lineRef 是被截断过的，它包含的 stringRange 可能是错误的，在这里要修正这个错误
    CFRange lineRange = _lineRefRange;
    NSInteger locationDelta = _stringRange.location - lineRange.location;
    locationDelta = MAX(locationDelta, 0);
    
    return locationDelta;
}

- (CGPoint)baselineOriginForCharacterAtIndex:(NSUInteger)characterIndex
{
    CGPoint origin = self.baselineOrigin;
    if (!_lineRef) {
        return origin;
    }
    
    NSInteger locationDelta = [self locationDeltaFromRealRangeToLineRefRange];
    locationDelta = MIN(characterIndex, locationDelta);
    characterIndex -= locationDelta;
    
    CGFloat offset = CTLineGetOffsetForStringIndex(_lineRef, characterIndex, NULL);
    origin.x += offset;
    return origin;
}

- (NSUInteger)characterIndexForBoundingPosition:(CGPoint)position
{
    NSUInteger index = _stringRange.location;
    
    if (_lineRef) {
        index = CTLineGetStringIndexForPosition(_lineRef, position);
        index += [self locationDeltaFromRealRangeToLineRefRange];
    }
    
    return index;
}

- (void)enumerateLayoutRunsUsingBlock:(void (^)(NSUInteger idx, NSDictionary * attributes, NSRange characterRange, BOOL *stop))block
{
    if (!_lineRef || !block) {
        return; // meaningless
    }
    
    NSInteger locationDelta = [self locationDeltaFromRealRangeToLineRefRange];
    
    NSArray * runs = (NSArray *)CTLineGetGlyphRuns(_lineRef);
    [runs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CTRunRef run = (__bridge CTRunRef)obj;
        NSDictionary * attributes = (NSDictionary *)CTRunGetAttributes(run);
        CFRange range = CTRunGetStringRange(run);
        NSRange nsRange = NSMakeRange(range.location, range.length);
        nsRange.location += locationDelta;
        block(idx, attributes, nsRange, stop);
    }];
}

@end
