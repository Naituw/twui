//
//  TUITextComposedSequence.h
//  TwUI
//
//  Created by wutian on 16/1/2.
//
//

#import <Foundation/Foundation.h>

extern NSString * const TUITextComposedSequenceAttributeName;

/**
 *  Composed Sequence 定义了 attributedString 中，原来的一段文字(replacementCharacters)被替换成新的一段连续的文字序列，这段文字序列对应原来的那段文字（replacementCharacters），不能被分割。
 *  在和文字进行交互时，一个 Sequence 当做一个整体被选择、添加或删除；
 *  在读取 attributedString 的纯文本时，Sequence 应当被替换为 replacementCharacters；
 *  在计算 attributedString 的长度时，Sequence 应当被替换为 replacementCharactersForLength；
 *  在拷贝 attributedString 时，Sequence 应当被替换为 replacementCharactersForCopy。
 */
@interface TUITextComposedSequence : NSObject

+ (instancetype)sequenceWithReplacement:(NSString *)replacement userInfo:(id)userInfo;
+ (instancetype)sequenceWithReplacement:(NSString *)replacement copy:(NSString *)replacementForCopy lengthPlaceholder:(NSString *)replacementForLength userInfo:(id)userInfo;

@property (nonatomic, strong, readonly) NSString * replacementCharacters;
@property (nonatomic, strong, readonly) NSString * replacementCharactersForCopy;
@property (nonatomic, strong, readonly) NSString * replacementCharactersForLength;
@property (nonatomic, strong, readonly) id userInfo;

@end

typedef NS_ENUM(NSInteger, TUITextComposedSequenceReplacementType)
{
    TUITextComposedSequenceReplacementTypeNormal = 0,
    TUITextComposedSequenceReplacementTypeCopy,
    TUITextComposedSequenceReplacementTypeLength,
};

@interface TUITextComposedSequence (ReplacementType)

- (NSString *)replacementCharactersForType:(TUITextComposedSequenceReplacementType)type;

@end

@interface NSAttributedString (TUITextComposedSequence)

/**
 *  返回 attributedString 在某一个 index 包含的 sequence 对象
 *
 *  @param index          查询的 index
 *  @param effectiveRange sequence 的实际范围
 *
 *  @return sequence 对象，可能为 nil
 */
- (TUITextComposedSequence *)tui_composedSequenceAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveRange;

/**
 *  遍历 attributedString 中的 sequence 对象
 *
 *  @param block 遍历使用的 block
 */
- (void)tui_enumerateComposedSequencesWithBlock:(void (^)(TUITextComposedSequence * sequence, NSRange range, BOOL * stop))block;

/**
 *  遍历 attributedString 中的 sequence 对象
 *
 *  @param options 遍历时的选项
 *  @param block   遍历使用的 block
 */
- (void)tui_enumerateComposedSequencesWithOptions:(NSAttributedStringEnumerationOptions)options block:(void (^)(TUITextComposedSequence * sequence, NSRange range, BOOL * stop))block;

/**
 *  遍历 attributedString 特定 range 中的 sequence 对象
 *
 *  @param range   需要遍历的范围
 *  @param options 遍历选项
 *  @param block   遍历使用的 block
 */
- (void)tui_enumerateComposedSequencesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)options block:(void (^)(TUITextComposedSequence * sequence, NSRange range, BOOL * stop))block;

/**
 *  对包含 Sequences 的 attributedString 取纯文本的方法
 *
 *  @return 转换过的纯文本
 */
- (NSString *)tui_stringByReplaceTextComposedSequences;

/**
 *  对包含 Sequences 的 attributedString 取用于拷贝的纯文本的方法
 *
 *  @return 转换过的纯文本，一般用于拷贝
 */
- (NSString *)tui_stringByReplaceTextComposedSequencesForCopy;

/**
 *  对包含 Sequences 的 attributedString 取用于长度计算的纯文本的方法
 *
 *  @return 转换过的纯文本，一般用于计算长度
 */
- (NSString *)tui_stringByReplaceTextComposedSequencesForLength;

/**
 *  对包含 Sequences 的 attributedString 取用于特定用途的纯文本的方法
 *
 *  @return 转换过的纯文本
 */
- (NSString *)tui_stringByReplaceTextComposedSequencesWithType:(TUITextComposedSequenceReplacementType)type;

/**
 *  扩展或收缩一个 range，使 range 的边界不会在一个 composed sequence 的中间
 *
 *  @discussion 扩展还是收缩取决于哪种方式对 range 的总长度影响较小，即向 sequence 较近的一端移动边界
 *
 *  @param range 需要进行转换的 range
 *
 *  @return 转换过的 range，range 的断点不会再处于 composed sequence 之间
 */
- (NSRange)tui_effectiveRangeByRoundingToComposedSequencesForRange:(NSRange)range;

/**
 *  扩展一个 range，使 range 的边界不会在一个 composed sequence 的中间
 *
 *  @param range 需要进行转换的 range
 *
 *  @return 转换过的 range，range 的断点不会再处于 composed sequence 之间
 */
- (NSRange)tui_effectiveRangeByExtendingToComposedSequencesForRange:(NSRange)range;

/**
 *  收缩一个 range，使 range 的边界不会在一个 composed sequence 的中间
 *
 *  @param range 需要进行转换的 range
 *
 *  @return 转换过的 range，range 的断点不会再处于 composed sequence 之间
 */
- (NSRange)tui_effectiveRangeByTrimmingToComposedSequencesForRange:(NSRange)range;

/**
 *  移动一个 index，使其不会处于一个 composed sequence 中间
 *
 *  @discussion 左移还是右移取决于哪种方式对 index 的位置影响较小，即向 sequence 最近的边界移动
 *
 *  @param index 要移动的 index
 *
 *  @return 移动过的 index
 */
- (NSUInteger)tui_effectiveIndexByRoundingToComposedSequenceForIndex:(NSUInteger)index;

/**
 *  将一个添加 composedSequences 后的 range 转换为原来的 range
 *
 *  @param composedRange 包含 composedSequences 的 range
 *
 *  @seealso - (NSRange)tui_attributedRangeByAddingComposedSequencesForPlainTextRange:(NSRange)plainTextRange;
 *
 *  @return 转换后的 range
 */
- (NSRange)tui_plainTextRangeByRemovingComposedSequencesForComposedRange:(NSRange)composedRange;

/**
 *  将一个原始文本 range 转换为添加 composedSequences 后的 range
 *
 *  @param plainTextRange 原始文本的 range
 *
 *  @seealso - (NSRange)tui_plainTextRangeByRemovingComposedSequencesForComposedRange:(NSRange)composedRange;
 *
 *  @return 转换后的 range
 */
- (NSRange)tui_composedRangeByAddingComposedSequencesForPlainTextRange:(NSRange)plainTextRange;

@end

@interface NSMutableAttributedString (TUITextComposedSequence)

/**
 *  为特定范围设置或移除一个 sequence 对象
 *
 *  @discussion 如果 sequence 传入 nil，则会移除 range 中所有的 sequence。否则，会将 range 标记一个 sequence，覆盖原有的值
 *
 *  @param sequence 要设置的 sequence 对象
 *  @param range    要设置的范围
 */
- (void)tui_setComposedSequence:(TUITextComposedSequence *)sequence forRange:(NSRange)range;

@end

@interface TUITextComposedSequence (Editing)

/**
 *  删除操作时，是否需要进行确认
 *
 *  @note 这个属性为满足编辑器特有功能，具体的确认方式由编辑器定义。默认的确认方式为：按一次 backspace 先选中整个 sequence，再按一次才实际删除 sequence
 *
 */
@property (nonatomic, assign) BOOL confirmsDeleteOperation;

@end
