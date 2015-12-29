//
//  TUITextLayoutFrame.m
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextLayoutFrame.h"
#import "TUITextLayout.h"
#import "TUITextLayout_Private.h"
#import "TUITextLayoutLine.h"
#import "TUITextLayoutLine_Private.h"

@interface TUITextLayoutFrame ()

@property (nonatomic, weak) TUITextLayout * layout;

@property (nonatomic, assign) TUIFontMetrics baselineMetrics;
@property (nonatomic, strong) NSArray * lineFragments;

@end

@implementation TUITextLayoutFrame

- (instancetype)initWithCTFrame:(CTFrameRef)frameRef layout:(TUITextLayout *)layout
{
    if (self = [self init]) {
        _layout = layout;
        if (frameRef) {
            [self setupWithCTFrame:frameRef];
        }
    }
    return self;
}

- (void)setupWithCTFrame:(CTFrameRef)frameRef
{
    const NSUInteger maximumNumberOfLines = _layout.maximumNumberOfLines;
    const TUIFontMetrics fixedFontMetrics = _layout.fixedFontMetrics;
    
    NSArray * lines = (NSArray *)CTFrameGetLines(frameRef);
    NSUInteger lineCount = lines.count;
    CGPoint lineOrigins[lineCount];
    
    if (TUIFontMetricsEqual(fixedFontMetrics, TUIFontMetricsNull)) {
        CTFrameGetLineOrigins(frameRef, CFRangeMake(0, lineCount), lineOrigins);
    } else {
        CGFloat y = _layout.size.height;
        for (NSUInteger i = 0; i < lineCount; i++) {
            y -= fixedFontMetrics.ascent;
            lineOrigins[i] = CGPointMake(0, y);
            y -= fixedFontMetrics.descent;
            y -= fixedFontMetrics.leading;
        }
    }
    
    NSMutableArray * lineFragments = [NSMutableArray array];
    
    for (NSInteger i = 0; i < lineCount; i++) {
        CTLineRef lineRef = (__bridge CTLineRef)lines[i];
        
        CTLineRef truncatedLineRef = NULL;
        
        if (maximumNumberOfLines) {
            if (i == maximumNumberOfLines - 1) {
                // this line may need to be truncated
                BOOL truncated = NO;
                truncatedLineRef = (__bridge CTLineRef)[self textLayout:_layout truncateLine:lineRef atIndex:i truncated:&truncated];
                if (!truncated) {
                    truncatedLineRef = NULL;
                }
            } else if (i >= maximumNumberOfLines) {
                break;
            }
        }
        
        TUITextLayoutLine * lineFragment = [[TUITextLayoutLine alloc] initWithCTLine:lineRef origin:lineOrigins[i] layout:_layout truncatedLine:truncatedLineRef];
        [lineFragments addObject:lineFragment];
    }
    
    self.baselineMetrics = _layout.baselineFontMetrics;
    self.lineFragments = lineFragments;
    
    [self updateLayoutSize];
}

- (void)updateLayoutSize
{
    CGFloat __block minY = 0.0, __block width = 0.0;
    
    NSUInteger fragmentCount = _lineFragments.count;
    
    [_lineFragments enumerateObjectsUsingBlock:^(TUITextLayoutLine * line, NSUInteger idx, BOOL *stop) {
        
        CGRect fragmentRect = line.fragmentRect;
        
        if (idx == fragmentCount - 1) {
            minY = CGRectGetMinY(fragmentRect);
        }
        
        width = MAX(width, CGRectGetMaxX(fragmentRect));
        
    }];
    
    _layoutSize = CGSizeMake(ceil(width), ceil(_layout.size.height - minY + 1));
}

#pragma mark - Line Truncating

- (id)textLayout:(TUITextLayout *)textLayout truncateLine:(CTLineRef)lineRef atIndex:(NSUInteger)index truncated:(BOOL *)truncated
{
    if (!lineRef) {
        if (truncated) {
            *truncated = NO;
        }
        return nil;
    }
    
    const CFRange stringRange = CTLineGetStringRange(lineRef);
    
    if (stringRange.length == 0) {
        if (truncated) {
            *truncated = NO;
        }
        return (__bridge id)lineRef;
    }
    
    CGFloat truncateWidth = textLayout.size.width;
    
    // 给 delegate 一个机会来决定是否要截得比 layout 宽度更窄
    const CGFloat delegateMaxWidth = [self textLayout:textLayout maximumWidthForTruncatedLine:lineRef atIndex:index];
    BOOL needsTruncate = NO;
    
    if (delegateMaxWidth < truncateWidth && delegateMaxWidth > 0) {
        CGFloat lineWidth = CTLineGetTypographicBounds(lineRef, NULL, NULL, NULL);
        if (lineWidth > delegateMaxWidth) {
            truncateWidth = delegateMaxWidth;
            needsTruncate = YES;
        }
    }
    
    // 如果询问 delegate 的结果是无需截断，那么通过 range 判断一次
    if (!needsTruncate) {
        if (stringRange.location + stringRange.length < textLayout.attributedString.length) {
            // 如果最后一行的最后一个字不是整段文字的最后一个字，说明文字被截断了
            needsTruncate = YES;
        }
    }
    
    if (!needsTruncate) {
        // 依旧不需要截断
        if (truncated) {
            *truncated = NO;
        }
        return (__bridge id)lineRef;
    }
    
    const NSAttributedString * attributedString = textLayout.attributedString;
    
    // Get correct truncationType and attribute position
    CTLineTruncationType truncationType = kCTLineTruncationEnd;
    NSUInteger truncationAttributePosition = stringRange.location;
    truncationAttributePosition += (stringRange.length - 1);
    
    // Get the attributes and use them to create the truncation token string
    NSDictionary * attrs = [attributedString attributesAtIndex:truncationAttributePosition effectiveRange:NULL];
    attrs = [attrs dictionaryWithValuesForKeys:@[(id)kCTFontAttributeName, (id)kCTParagraphStyleAttributeName, (id)kCTForegroundColorAttributeName, TUITextDefaultForegroundColorAttributeName]];
    
    // Filter all NSNull values
    NSMutableDictionary * tokenAttributes = [NSMutableDictionary dictionary];
    [attrs enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if (![obj isKindOfClass:[NSNull class]]) {
            [tokenAttributes setObject:obj forKey:key];
        }
    }];
    
    CGColorRef cgColor = (__bridge CGColorRef)[tokenAttributes objectForKey:TUITextDefaultForegroundColorAttributeName];
    if (cgColor) {
        [tokenAttributes setValue:(__bridge id)cgColor forKey:(NSString *)kCTForegroundColorAttributeName];
    }
    
    // \u2026 is the Unicode horizontal ellipsis character code
    // 如果设置了truncationString，则用自定义的
    NSAttributedString *tokenString = [[NSAttributedString alloc] initWithString:@"\u2026" attributes:tokenAttributes];
    if (_layout.truncationString) {
        tokenString = _layout.truncationString;
    }
    CTLineRef truncationToken = CTLineCreateWithAttributedString((CFAttributedStringRef)tokenString);
    
    // Append truncationToken to the string
    // because if string isn't too long, CT wont add the truncationToken on it's own
    // There is no change of a double truncationToken because CT only add the token if it removes characters (and the one we add will go first)
    NSMutableAttributedString *truncationString = [[attributedString attributedSubstringFromRange:NSMakeRange(stringRange.location, stringRange.length)] mutableCopy];
    if (stringRange.length > 0)
    {
        // Remove any newline at the end (we don't want newline space between the text and the truncation token). There can only be one, because the second would be on the next line.
        unichar lastCharacter = [[truncationString string] characterAtIndex:stringRange.length - 1];
        if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastCharacter])
        {
            [truncationString deleteCharactersInRange:NSMakeRange(stringRange.length - 1, 1)];
        }
        
    }
    
    [truncationString appendAttributedString:tokenString];
    CTLineRef truncationLine = CTLineCreateWithAttributedString((CFAttributedStringRef)truncationString);
    
    // Truncate the line in case it is too long.
    CTLineRef truncatedLine;
    truncatedLine = CTLineCreateTruncatedLine(truncationLine, truncateWidth, truncationType, truncationToken);
    
    CFRelease(truncationLine);
    if (!truncatedLine)
    {
        // If the line is not as wide as the truncationToken, truncatedLine is NULL
        truncatedLine = CFRetain(truncationToken);
    }
    
    CFRelease(truncationToken);
    
    if (truncated) {
        *truncated = YES;
    }
    
    return CFBridgingRelease(truncatedLine);
}

- (CGFloat)textLayout:(TUITextLayout *)textLayout maximumWidthForTruncatedLine:(CTLineRef)lineRef atIndex:(NSUInteger)index
{
    if ([textLayout.delegate respondsToSelector:@selector(textLayout:maximumWidthForLineTruncationAtIndex:)]) {
        CGFloat width = [textLayout.delegate textLayout:textLayout maximumWidthForLineTruncationAtIndex:index];
        return floor(width);
    }
    
    return textLayout.size.width;
}

@end

@implementation TUITextLayoutFrame (LayoutResult)

- (NSUInteger)lineFragmentIndexForCharacterAtIndex:(NSUInteger)characterIndex
{
    NSUInteger __block lineIndex = NSNotFound;
    
    [self.lineFragments enumerateObjectsUsingBlock:^(TUITextLayoutLine * line, NSUInteger idx, BOOL *stop) {
        if (TUINSRangeContainsIndex(line.stringRange, characterIndex) &&
            characterIndex != NSMaxRange(line.stringRange)) {
            lineIndex = idx;
            *stop = YES;
        }
    }];
    
    return lineIndex;
}

- (CGRect)firstSelectionRectForCharacterRange:(NSRange)characterRange
{
    CGRect __block selectionRect = CGRectNull;
    
    [self enumerateSelectionRectsForCharacterRange:characterRange usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
        selectionRect = rect;
        *stop = YES;
    }];
    
    return selectionRect;
}

- (void)enumerateLineFragmentsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(NSUInteger idx, CGRect, NSRange, BOOL *))block
{
    if (!block) return;
    
    [self.lineFragments enumerateObjectsUsingBlock:^(TUITextLayoutLine * line, NSUInteger idx, BOOL *stop) {
        block(idx, line.fragmentRect, line.stringRange, stop);
    }];
}

- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect, NSRange, BOOL *))block
{
    if (!block) {
        return; // meaningless
    }
    
    NSArray * lineFragments = self.lineFragments;
    const NSUInteger lineCount = lineFragments.count;
    
    [lineFragments enumerateObjectsUsingBlock:^(TUITextLayoutLine * line, NSUInteger idx, BOOL *stop) {
        
        const NSRange lineRange = line.stringRange;
        const CGRect lineFragmentRect = line.fragmentRect;
        
        const NSUInteger lineStartIndex = lineRange.location;
        const NSUInteger lineEndIndex = NSMaxRange(lineRange);
        
        NSUInteger characterStartIndex = characterRange.location;
        NSUInteger characterEndIndex = NSMaxRange(characterRange);
        
        if (characterStartIndex >= lineEndIndex) {
            return; // 如果请求的 range 在当前行之后，直接结束
        }
        
        if (idx == lineCount - 1) {
            // if is last line, keep characterEndIndex in range
            characterEndIndex = MIN(lineEndIndex, characterEndIndex);
        }
        
        const BOOL containsStartIndex = TUINSRangeContainsIndex(lineRange, characterStartIndex);
        const BOOL containsEndIndex = TUINSRangeContainsIndex(lineRange, characterEndIndex);
        
        if (containsStartIndex && containsEndIndex) {
            // 一共只有一行
            if (characterStartIndex != characterEndIndex) {
                CGFloat startOffset = [line baselineOriginForCharacterAtIndex:characterStartIndex].x;
                CGFloat endOffset = [line baselineOriginForCharacterAtIndex:characterEndIndex].x;
                CGRect rect = lineFragmentRect;
                rect.origin.x += startOffset;
                rect.size.width = endOffset - startOffset;
                
                block(rect, NSMakeRange(characterStartIndex, characterEndIndex - characterStartIndex), stop);
            }
            *stop = YES;
        } else if (containsStartIndex) {
            // 多行时的第一行
            if (characterStartIndex != NSMaxRange(lineRange)) {
                CGFloat startOffset = [line baselineOriginForCharacterAtIndex:characterStartIndex].x;
                CGRect rect = lineFragmentRect;
                rect.origin.x += startOffset;
                rect.size.width -= startOffset;
                
                block(rect, NSMakeRange(characterStartIndex, lineEndIndex - characterStartIndex), stop);
            }
        } else if (containsEndIndex) {
            // 多行时的最后一行
            CGFloat endOffset = [line baselineOriginForCharacterAtIndex:characterEndIndex].x;
            CGRect rect = lineFragmentRect;
            rect.size.width = endOffset;
            
            block(rect, NSMakeRange(lineStartIndex, characterEndIndex - lineStartIndex), stop);
        } else if (TUINSRangeContainsIndex(characterRange, lineRange.location)) {
            // 多行时的中间行
            block(lineFragmentRect, lineRange, stop);
        }
        
        if (containsEndIndex) {
            *stop = YES; // nothing more
        }
    }];
}

- (CGRect)enumerateSelectionRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect, NSRange, BOOL *))block
{
    CGSize containerSize = self.layout.size;
    CGRect __block boundingRect = CGRectNull;
    
    [self enumerateEnclosingRectsForCharacterRange:characterRange usingBlock:^(CGRect rect, NSRange lineRange, BOOL *stop) {
        if (NSMaxRange(lineRange) < NSMaxRange(characterRange)) {
            rect.size.width = containerSize.width - CGRectGetMinX(rect);
        }
        if (block) {
            if (!CGRectIsNull(boundingRect)) {
                CGFloat deltaHeight = CGRectGetMinY(boundingRect) - CGRectGetMaxY(rect);
                rect.size.height += deltaHeight;
            }
            block(rect, characterRange, stop);
        }
        boundingRect = CGRectUnion(boundingRect, rect);
    }];
    
    return boundingRect;
}

@end
