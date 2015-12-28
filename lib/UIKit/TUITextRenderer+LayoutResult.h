//
//  TUITextRenderer+LayoutResult.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextRenderer.h"

@interface TUITextRenderer (LayoutResult)

@property (nonatomic, assign, readonly) BOOL layoutUpToDate;

@property (nonatomic, assign, readonly) NSRange layoutStringRange;
@property (nonatomic, assign, readonly) NSUInteger layoutLineCount;
@property (nonatomic, assign, readonly) CGSize layoutSize;
@property (nonatomic, assign, readonly) CGFloat layoutHeight;

- (NSUInteger)lineFragmentIndexForCharacterAtIndex:(NSUInteger)characterIndex;

- (CGRect)lineFragmentRectForLineAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange;
- (CGRect)lineFragmentRectForCharacterAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange;

- (CGRect)firstSelectionRectForCharacterRange:(NSRange)characterRange;

- (void)enumerateLineFragmentsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(NSUInteger idx, CGRect rect, NSRange characterRange, BOOL *stop))block;

- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect rect, NSRange characterRange, BOOL *stop))block;
- (CGRect)enumerateSelectionRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect rect, NSRange characterRange, BOOL *stop))block;

- (CGPoint)locationForCharacterAtIndex:(NSUInteger)characterIndex;
- (CGRect)boundingRectForCharacterRange:(NSRange)characterRange;

- (NSRange)characterRangeForBoundingRect:(CGRect)bounds;
- (NSUInteger)characterIndexForPoint:(CGPoint)point;

@end
