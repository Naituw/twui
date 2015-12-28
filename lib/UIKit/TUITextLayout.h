//
//  TUITextLayout.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import <Foundation/Foundation.h>
#import "TUIGeometry.h"

@class TUITextStorage;
@protocol TUITextLayoutDelegate;

@interface TUITextLayout : NSObject

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString;

@property (nonatomic, strong) NSAttributedString * attributedString;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, copy) NSArray * exclusionPaths;

@property (nonatomic, assign) NSUInteger maximumNumberOfLines;
@property (nonatomic, strong) NSAttributedString *truncationString;

@property (nonatomic, assign) TUIFontMetrics baselineFontMetrics;
@property (nonatomic, assign) TUIFontMetrics fixedFontMetrics;

- (void)setNeedsLayout;

@property (nonatomic, weak) id<TUITextLayoutDelegate> delegate;

@property (nonatomic, assign) BOOL retriveFontMetricsAutomatically;

@end

@protocol TUITextLayoutDelegate <NSObject>

@optional
- (CGFloat)textLayout:(TUITextLayout *)layout maximumWidthForLineTruncationAtIndex:(NSUInteger)index;

@end

@interface TUITextLayout (LayoutResult)

/**
 *  布局是否已更新到最新状态
 */
@property (nonatomic, assign, readonly) BOOL layoutUpToDate;

/**
 *  布局中包含文字的对应字符串 range
 */
@property (nonatomic, assign, readonly) NSRange containingStringRange;
- (NSRange) containingStringRangeWithLineLimited:(NSUInteger)lineLimited;

/**
 *  布局中包含的文字行数
 */
@property (nonatomic, assign, readonly) NSUInteger containingLineCount;

/**
 *  布局后文字所占区域的总大小
 */
@property (nonatomic, assign, readonly) CGSize layoutSize;

/**
 *  布局后文字所占区域的总高度，等于 layoutSize.height
 */
@property (nonatomic, assign, readonly) CGFloat layoutHeight;

/**
 *  获取一个文字 index 对应的行数
 *
 *  @param characterIndex 文字 index
 *
 *  @return 行的 index
 */
- (NSUInteger)lineFragmentIndexForCharacterAtIndex:(NSUInteger)characterIndex;

/**
 *  获取某一行文字在 layout 中的 frame，并可以返回这一行文字对应的字符串范围
 *
 *  @param index                   行的 index
 *  @param effectiveCharacterRange 这一行文字对应的字符串范围
 *
 *  @return 这一行的 frame，如果 index 无效，将返回 CGRectNull
 */
- (CGRect)lineFragmentRectForLineAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange;

/**
 *  后去某一文字 index 对应的 行 在 layout 中的 frame，并可以返回这一行文字对应的字符串范围
 *
 *  @param index                   文字的 index
 *  @param effectiveCharacterRange 文字所在行中的文字对应的字符串范围
 *
 *  @return 这一行的 frame，如果 index 无效，将返回 CGRectNull
 */
- (CGRect)lineFragmentRectForCharacterAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange;

/**
 *  获取某一行文字的 Metrics
 *
 *  @param index                   行的 index
 *  @param effectiveCharacterRange 文字所在行中的文字对应的字符串范围
 *
 *  @return 这一行的 Metrics，如果 index 无效，将返回 TUIFontMetricsNull
 */
- (TUIFontMetrics)lineFragmentMetricsForLineAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveCharacterRange;

/**
 *  某一字符串范围对应的 frame，如果该范围中包含多行文字，则返回第一行的 frame
 *
 *  @param characterRange 字符串的范围
 *
 *  @return 文字的 frame，如果 range 无效，将返回 CGRectNull
 */
- (CGRect)firstSelectionRectForCharacterRange:(NSRange)characterRange;

/**
 *  遍历某一字符串范围对应的行的信息
 *
 *  @param characterRange 字符串范围
 *  @param block          传入参数分别为：行的index、行的frame、行中文字对应的字符串范围
 */
- (void)enumerateLineFragmentsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(NSUInteger idx, CGRect rect, NSRange characterRange, BOOL *stop))block;

/**
 *  遍历某一字符串范围中文字的 frame 等信息
 *
 *  @param characterRange 字符串范围
 *  @param block          如果文字存在于多行中，会被调用多次。传入参数分别为：文字的 frame、文字对应的字符串范围
 */
- (void)enumerateEnclosingRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect rect, NSRange characterRange, BOOL *stop))block;

/**
 *  遍历某一字符串范围中文字的 frame 等信息，用于选择区域的绘制等操作
 *
 *  @discussion 和 EnclosingRect 不同，SelectionRect 不会重叠、换行时 frame 会延伸到 layout 边缘，展示起来更为美观。但这需要额外的计算，如果不需要这些特性，建议直接使用 EnclosingRect
 *
 *  @param characterRange 字符串范围
 *  @param block          如果文字存在于多行中，会被调用多次。传入参数分别为：文字的 frame、文字对应的字符串范围
 *
 *  @return 整个区域的 bounding 区域
 */
- (CGRect)enumerateSelectionRectsForCharacterRange:(NSRange)characterRange usingBlock:(void (^)(CGRect rect, NSRange characterRange, BOOL *stop))block;

/**
 *  获取某一字符串 index 对应文字在 layout 中的坐标
 *
 *  @param characterIndex 字符串 index
 *
 *  @return layout 中的坐标，取 glyph 的中心点
 */
- (CGPoint)locationForCharacterAtIndex:(NSUInteger)characterIndex;

/**
 *  获取一个 frame，它包含传入字符串范围中的所有文字
 *
 *  @param characterRange 字符串范围
 *
 *  @return 包含所有文字的 frame
 */
- (CGRect)boundingRectForCharacterRange:(NSRange)characterRange;

@end

@interface TUITextLayout (HitTesting)

/**
 *  获取一个区域中包含的文字对应的字符串范围
 *
 *  @param bounds 要查询的区域
 *
 *  @return 字符串范围
 */
- (NSRange)characterRangeForBoundingRect:(CGRect)bounds;

/**
 *  获取某一坐标上的文字对应的字符串 index
 *
 *  @param point 坐标点
 *
 *  @return 字符串 index
 */
- (NSUInteger)characterIndexForPoint:(CGPoint)point;

@end

extern BOOL TUINSRangeContainsIndex(NSRange range, NSUInteger index);
