//
//  TUITextRenderer+LayoutResult.m
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextRenderer+LayoutResult.h"

@implementation TUITextRenderer (LayoutResult)

- (BOOL)layoutUpToDate
{
    return self.textLayout.layoutUpToDate;
}

- (NSRange)layoutStringRange
{
    return self.textLayout.containingStringRange;
}

- (NSUInteger)layoutLineCount
{
    return self.textLayout.containingLineCount;
}

- (CGSize)layoutSize
{
    return self.textLayout.layoutSize;
}

- (CGFloat)layoutHeight
{
    return self.textLayout.layoutHeight;
}

- (NSUInteger)lineFragmentIndexForCharacterAtIndex:(NSUInteger)characterIndex
{
    return [self.textLayout lineFragmentIndexForCharacterAtIndex:characterIndex];
}

- (CGRect)lineFragmentRectForLineAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange
{
    CGRect rect = [self.textLayout lineFragmentRectForLineAtIndex:index effectiveRange:effectiveCharacterRange];
    return [self convertRectFromLayout:rect];
}

- (CGRect)lineFragmentRectForCharacterAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange
{
    CGRect rect = [self.textLayout lineFragmentRectForCharacterAtIndex:index effectiveRange:effectiveCharacterRange];
    return [self convertRectFromLayout:rect];
}

- (CGRect)firstSelectionRectForCharacterRange:(NSRange)characterRange
{
    CGRect rect = [self.textLayout firstSelectionRectForCharacterRange:characterRange];
    return [self convertRectFromLayout:rect];
}

- (void)enumerateLineFragmentsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(NSUInteger, CGRect, NSRange, BOOL *))block
{
    if (!block) return;
    
    [self.textLayout enumerateLineFragmentsForCharacterRange:characterRange usingBlock:^(NSUInteger idx, CGRect rect, NSRange characterRange, BOOL *stop) {
        rect = [self convertRectFromLayout:rect];
        block(idx, rect, characterRange, stop);
    }];
}

- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect, NSRange, BOOL *))block
{
    if (!block) return;
    
    [self.textLayout enumerateEnclosingRectsForCharacterRange:characterRange usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
        rect = [self convertRectFromLayout:rect];
        block(rect, characterRange, stop);
    }];
}

- (CGRect)enumerateSelectionRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect, NSRange, BOOL *))block
{
    return [self.textLayout enumerateSelectionRectsForCharacterRange:characterRange usingBlock:^(CGRect rect, NSRange characterRange, BOOL *stop) {
        if (block) {
            rect = [self convertRectFromLayout:rect];
            block(rect, characterRange, stop);
        }
    }];
}

- (CGPoint)locationForCharacterAtIndex:(NSUInteger)characterIndex
{
    CGPoint location = [self.textLayout locationForCharacterAtIndex:characterIndex];
    return [self convertPointFromLayout:location];
}

- (CGRect)boundingRectForCharacterRange:(NSRange)characterRange
{
    CGRect rect = [self.textLayout boundingRectForCharacterRange:characterRange];
    return [self convertRectFromLayout:rect];
}

- (NSRange)characterRangeForBoundingRect:(CGRect)bounds
{
    bounds = [self convertRectToLayout:bounds];
    return [self.textLayout characterRangeForBoundingRect:bounds];
}

- (NSUInteger)characterIndexForPoint:(CGPoint)point
{
    point = [self convertPointToLayout:point];
    return [self.textLayout characterIndexForPoint:point];
}

@end
