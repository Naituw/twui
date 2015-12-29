//
//  TUITextLayout.m
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextLayout.h"
#import "TUITextLayout_Private.h"
#import "TUITextLayoutLine_Private.h"
#import "TUITextStorage.h"
#import "TUITextLayoutLine.h"

@interface TUITextLayout ()
{
    struct {
        unsigned int needsLayout: 1;
    } _flags;
}

@end

@implementation TUITextLayout

- (instancetype)init
{
    if (self = [super init]) {
        _flags.needsLayout = YES;
        _baselineFontMetrics = TUIFontMetricsNull;
        _fixedFontMetrics = TUIFontMetricsNull;
    }
    return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
{
    if (self = [self init]) {
        self.attributedString = attributedString;
    }
    return self;
}

#pragma mark - Accessors

- (void)setAttributedString:(NSAttributedString *)attributedString
{
    if (_attributedString != attributedString) {
        @synchronized(self) {
            _attributedString = attributedString;
        }
        _flags.needsLayout = YES;
    }
}

- (void)setSize:(CGSize)size
{
    if (!CGSizeEqualToSize(_size, size)) {
        _size = size;
        _flags.needsLayout = YES;
    }
}

- (void)setExclusionPaths:(NSArray *)exclusionPaths
{
    if (_exclusionPaths != exclusionPaths) {
        _exclusionPaths = exclusionPaths;
        _flags.needsLayout = YES;
    }
}

- (void)setMaximumNumberOfLines:(NSUInteger)maximumNumberOfLines
{
    if (_maximumNumberOfLines != maximumNumberOfLines) {
        _maximumNumberOfLines = maximumNumberOfLines;
        _flags.needsLayout = YES;
    }
}

- (void)setBaselineFontMetrics:(TUIFontMetrics)baselineFontMetrics
{
    if (!TUIFontMetricsEqual(_baselineFontMetrics, baselineFontMetrics)) {
        _baselineFontMetrics = baselineFontMetrics;
        _flags.needsLayout = YES;
    }
}

- (void)setFixedFontMetrics:(TUIFontMetrics)fixedFontMetrics
{
    if (!TUIFontMetricsEqual(_fixedFontMetrics, fixedFontMetrics)) {
        _fixedFontMetrics = fixedFontMetrics;
        _flags.needsLayout = YES;
    }
}

#pragma mark - Layout

- (void)setNeedsLayout
{
    _flags.needsLayout = YES;
}

- (TUITextLayoutFrame *)layoutFrame
{
    if (!_layoutFrame || _flags.needsLayout) {
        @synchronized(self) {
            _layoutFrame = [self createLayoutFrame];
        }
        _flags.needsLayout = NO;
    }
    return _layoutFrame;
}

- (TUITextLayoutFrame *)createLayoutFrame
{
    const NSAttributedString * attributedString = _attributedString;
    
    if (!attributedString) {
        return nil;
    }
    
    CTFrameRef ctFrame = NULL;
    
    {
        CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedString);
        CGPathRef path = CGPathCreateWithFrameAndExclusionPaths(CGRectMake(0, 0, _size.width, _size.height), self.exclusionPaths);
        
        ctFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
        CFRelease(path);
        CFRelease(framesetter);
    }
    
    if (!ctFrame) {
        return nil;
    }
    
    TUITextLayoutFrame * layoutFrame = [[TUITextLayoutFrame alloc] initWithCTFrame:ctFrame layout:self];
    
    CFRelease(ctFrame);
    
    return layoutFrame;
}

static CGPathRef CGPathCreateWithFrameAndExclusionPaths(CGRect textFrame, NSArray * exclusionPaths)
{
//    if (exclusionPaths.count)
//    {
//        CGAffineTransform transform = CGAffineTransformMakeTranslation(textFrame.origin.x, textFrame.origin.y);
//        
//        UIBezierPath * path = [UIBezierPath bezierPathWithRect:textFrame];
//        
//        for (UIBezierPath * subpath in exclusionPaths)
//        {
//            UIBezierPath * __strong p = [subpath copy];
//            
//            [p applyTransform:transform];
//            [path appendPath:p];
//        }
//        
//        path.usesEvenOddFillRule = YES;
//        
//        return CGPathCreateMutableCopy(path.CGPath);
//    }
//    else
//    {
        CGMutablePathRef resultPath = CGPathCreateMutable();
        CGPathAddRect(resultPath, NULL, textFrame);
        return resultPath;
//    }
}

@synthesize layoutFrame = _layoutFrame;
@end


@implementation TUITextLayout (LayoutResult)

- (BOOL)layoutUpToDate
{
    return !_flags.needsLayout || !_layoutFrame;
}

- (NSRange)containingStringRange
{
    return [self containingStringRangeWithLineLimited:0];
}

- (NSRange) containingStringRangeWithLineLimited:(NSUInteger)lineLimited{
    
    NSArray* lines = self.layoutFrame.lineFragments;
    NSUInteger length = 0;
    
    if (nil != lines  &&  0 != [lines count]) {
        
        TUITextLayoutLine* line = nil;
        if(0 == lineLimited  ||  lineLimited > [lines count]){
            line = [lines lastObject];
        }
        else {
            line = [lines objectAtIndex:lineLimited-1];
        }
        
        length = NSMaxRange(line.stringRange);
        
    }
    
    
    return NSMakeRange(0, length);
}

- (NSUInteger)containingLineCount
{
    return self.layoutFrame.lineFragments.count;
}

- (CGSize)layoutSize
{
    return self.layoutFrame.layoutSize;
}

- (CGFloat)layoutHeight
{
    return self.layoutSize.height;
}

- (NSUInteger)lineFragmentIndexForCharacterAtIndex:(NSUInteger)characterIndex
{
    return [self.layoutFrame lineFragmentIndexForCharacterAtIndex:characterIndex];
}

- (CGRect)lineFragmentRectForLineAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange
{
    NSArray * fragments = self.layoutFrame.lineFragments;
    if (index >= fragments.count) {
        if (effectiveCharacterRange) {
            *effectiveCharacterRange = NSMakeRange(NSNotFound, 0);
        }
        return CGRectNull;
    }
    TUITextLayoutLine * line = fragments[index];
    
    if (effectiveCharacterRange) {
        *effectiveCharacterRange = line.stringRange;
    }
    
    return line.fragmentRect;
}

- (CGRect)lineFragmentRectForCharacterAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange
{
    NSUInteger lineIndex = [self lineFragmentIndexForCharacterAtIndex:index];
    return [self lineFragmentRectForLineAtIndex:lineIndex effectiveRange:effectiveCharacterRange];;
}

- (TUIFontMetrics)lineFragmentMetricsForLineAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange
{
    NSArray * fragments = self.layoutFrame.lineFragments;
    if (index >= fragments.count) {
        if (effectiveCharacterRange) {
            *effectiveCharacterRange = NSMakeRange(NSNotFound, 0);
        }
        return TUIFontMetricsNull;
    }
    TUITextLayoutLine * line = fragments[index];
    
    if (effectiveCharacterRange) {
        *effectiveCharacterRange = line.stringRange;
    }
    
    return line.lineMetrics;
}

- (CGRect)firstSelectionRectForCharacterRange:(NSRange)characterRange
{
    return [self.layoutFrame firstSelectionRectForCharacterRange:characterRange];
}

- (void)enumerateLineFragmentsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(NSUInteger idx, CGRect, NSRange, BOOL *))block
{
    if (!block) return;
    
    [self.layoutFrame enumerateLineFragmentsForCharacterRange:characterRange usingBlock:block];
}

- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect, NSRange, BOOL *))block
{
    if (!block) {
        return; // meaningless
    }
    
    [self.layoutFrame enumerateEnclosingRectsForCharacterRange:characterRange usingBlock:block];
}

- (CGRect)enumerateSelectionRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect, NSRange, BOOL *))block
{
    return [self.layoutFrame enumerateSelectionRectsForCharacterRange:characterRange usingBlock:block];
}

- (CGPoint)locationForCharacterAtIndex:(NSUInteger)characterIndex
{
    CGRect rect = [self boundingRectForCharacterRange:NSMakeRange(characterIndex, 1)];
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

- (CGRect)boundingRectForCharacterRange:(NSRange)characterRange
{
    return [self enumerateSelectionRectsForCharacterRange:characterRange usingBlock:NULL];
}

@end

@implementation TUITextLayout (HitTesting)

- (NSRange)characterRangeForBoundingRect:(CGRect)bounds
{
    CGPoint topLeftPoint = bounds.origin;
    CGPoint bottomRightPoint = CGPointMake(CGRectGetMaxX(bounds), CGRectGetMaxY(bounds));
    
    // 将 bounds 限制在有效区域内
    topLeftPoint.y = MIN(2, topLeftPoint.y);
    bottomRightPoint.y = MAX(bottomRightPoint.y, self.layoutSize.height - 2);
    
    NSUInteger start = [self characterIndexForPoint:topLeftPoint];
    NSUInteger end = [self characterIndexForPoint:bottomRightPoint];
    
    return NSMakeRange(start, end - start);
}

- (NSUInteger)characterIndexForPoint:(CGPoint)point
{
    const NSString * string = self.attributedString.string;
    const NSUInteger stringLength = string.length;
    const NSArray * lines = self.layoutFrame.lineFragments;
    const NSUInteger lineCount = lines.count;
    
    CGFloat previousLineY = self.size.height;
    
    for (NSInteger i = 0; i < lineCount; i++) {
        TUITextLayoutLine * line = lines[i];
        CGRect fragmentRect = line.fragmentRect;
        
        if (i == 0 && point.y > CGRectGetMaxY(fragmentRect)) {
            return 0; // 在第一行之上
        }
        
        if (i == lineCount - 1 && point.y < CGRectGetMinY(fragmentRect)) {
            return stringLength; // 在最后一行之下
        }
        
        if (point.y < previousLineY && point.y >= CGRectGetMinY(fragmentRect)) {
            // 命中！
            point.x -= line.baselineOrigin.x;
            point.y -= line.baselineOrigin.y;
            
            NSUInteger index = [line characterIndexForBoundingPosition:point];
            
            NSRange stringRange = line.stringRange;
            if (index == NSMaxRange(stringRange) && index > 0) {
                if ([string characterAtIndex:index - 1] == '\n') {
                    index--;
                }
            }
            
            return index;
        }
        
        previousLineY = CGRectGetMinY(fragmentRect);
    }
    
    return 0;
}

@end

@implementation TUITextLayout (Coordinates)

- (CGPoint)convertPointFromCoreText:(CGPoint)point
{
//    point.y = _size.height - point.y;
    return point;
}

- (CGPoint)convertPointToCoreText:(CGPoint)point
{
    // yes, this is the same with -convertPointFromCoreText:, just for readability
//    point.y = _size.height - point.y;
    return point;
}

- (CGRect)convertRectFromCoreText:(CGRect)rect
{
//    rect.origin = [self convertPointFromCoreText:rect.origin];
//    rect.origin.y -= rect.size.height;
    return rect;
}

- (CGRect)convertRectToCoreText:(CGRect)rect
{
//    rect.origin = [self convertPointToCoreText:rect.origin];
//    rect.origin.y -= rect.size.height;
    return rect;
}

@end

BOOL TUINSRangeContainsIndex(NSRange range, NSUInteger index)
{
    BOOL a = (index >= range.location);
    BOOL b = (index <= (range.location + range.length));
    return (a && b);
}
