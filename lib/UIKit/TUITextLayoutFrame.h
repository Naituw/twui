//
//  TUITextLayoutFrame.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import <Foundation/Foundation.h>

@class TUITextLayout;

@interface TUITextLayoutFrame : NSObject

- (instancetype)initWithCTFrame:(CTFrameRef)frameRef layout:(TUITextLayout *)layout;

@property (nonatomic, assign, readonly) TUIFontMetrics baselineMetrics;
@property (nonatomic, strong, readonly) NSArray * lineFragments;

@property (nonatomic, assign, readonly) CGSize layoutSize;

@end

@interface TUITextLayoutFrame (LayoutResult)

- (NSUInteger)lineFragmentIndexForCharacterAtIndex:(NSUInteger)characterIndex;

- (CGRect)firstSelectionRectForCharacterRange:(NSRange)characterRange;

- (void)enumerateLineFragmentsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(NSUInteger idx, CGRect rect, NSRange characterRange, BOOL *stop))block;

- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect rect, NSRange characterRange, BOOL *stop))block;
- (CGRect)enumerateSelectionRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect rect, NSRange characterRange, BOOL *stop))block;

@end
