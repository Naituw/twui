//
//  TUITextLayoutLine.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import <Foundation/Foundation.h>

@class TUITextLayout;

@interface TUITextLayoutLine : NSObject

- (instancetype)initWithCTLine:(CTLineRef)lineRef origin:(CGPoint)origin layout:(TUITextLayout *)layout;
- (instancetype)initWithCTLine:(CTLineRef)lineRef origin:(CGPoint)origin layout:(TUITextLayout *)layout truncatedLine:(CTLineRef)truncatedLineRef;

@property (nonatomic, weak, readonly) TUITextLayout * layout;
@property (nonatomic, readonly) CGRect originalFragmentRect;
@property (nonatomic, readonly) CGRect fragmentRect;

@property (nonatomic, readonly) CGPoint originalBaselineOrigin;
@property (nonatomic, readonly) CGPoint baselineOrigin;

@property (nonatomic, readonly) NSRange stringRange;

@property (nonatomic, readonly) TUIFontMetrics originalLineMetrics;
@property (nonatomic, readonly) TUIFontMetrics lineMetrics;

@property (nonatomic, readonly) BOOL truncated;

@end

@interface TUITextLayoutLine (LayoutResult)

- (CGPoint)baselineOriginForCharacterAtIndex:(NSUInteger)characterIndex;
- (NSUInteger)characterIndexForBoundingPosition:(CGPoint)position;

- (void)enumerateLayoutRunsUsingBlock:(void (^)(NSUInteger idx, NSDictionary * attributes, NSRange characterRange, BOOL *stop))block;

@end
