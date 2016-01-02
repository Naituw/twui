//
//  TUITextComposedSequence.m
//  TwUI
//
//  Created by wutian on 16/1/2.
//
//

#import "TUITextComposedSequence.h"

NSString * const TUITextComposedSequenceAttributeName = @"TUITextComposedSequenceAttributeName";

@interface TUITextComposedSequence ()
{
    struct {
        unsigned int confirmsDeleteOperation: 1;
    } _flags;
}

@property (nonatomic, strong) NSString * replacementCharacters;
@property (nonatomic, strong) NSString * replacementCharactersForCopy;
@property (nonatomic, strong) NSString * replacementCharactersForLength;
@property (nonatomic, strong) id userInfo;

@end

@implementation TUITextComposedSequence

+ (instancetype)sequenceWithReplacement:(NSString *)replacement userInfo:(id)userInfo
{
    return [self sequenceWithReplacement:replacement copy:nil lengthPlaceholder:nil userInfo:nil];
}

+ (instancetype)sequenceWithReplacement:(NSString *)replacement copy:(NSString *)replacementForCopy lengthPlaceholder:(NSString *)replacementForLength userInfo:(id)userInfo
{
    TUITextComposedSequence * sequence = [[TUITextComposedSequence alloc] init];
    
    sequence.replacementCharacters = replacement;
    sequence.replacementCharactersForCopy = replacementForCopy;
    sequence.replacementCharactersForLength = replacementForLength;
    sequence.userInfo = userInfo;
    
    return sequence;
}

- (NSString *)replacementCharactersForCopy
{
    if (!_replacementCharactersForCopy) {
        return _replacementCharacters;
    }
    return _replacementCharactersForCopy;
}

- (NSString *)replacementCharactersForLength
{
    if (!_replacementCharactersForLength) {
        return _replacementCharacters;
    }
    return _replacementCharactersForLength;
}

@synthesize replacementCharactersForCopy = _replacementCharactersForCopy;
@synthesize replacementCharactersForLength = _replacementCharactersForLength;
@end

@implementation TUITextComposedSequence (ReplacementType)

- (NSString *)replacementCharactersForType:(TUITextComposedSequenceReplacementType)type
{
    switch (type) {
        case TUITextComposedSequenceReplacementTypeCopy: return self.replacementCharactersForCopy;
        case TUITextComposedSequenceReplacementTypeLength: return self.replacementCharactersForLength;
        default: return self.replacementCharacters;
    }
}

@end

@implementation NSAttributedString (TUITextComposedSequence)

- (TUITextComposedSequence *)tui_composedSequenceAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)effectiveRange
{
    if (index >= self.length) {
        return nil;
    }
    
    id value = [self attribute:TUITextComposedSequenceAttributeName atIndex:index longestEffectiveRange:effectiveRange inRange:NSMakeRange(0, self.length)];
    if ([value isKindOfClass:[TUITextComposedSequence class]]) {
        return value;
    }
    return nil;
}

- (void)tui_enumerateComposedSequencesWithBlock:(void (^)(TUITextComposedSequence *, NSRange, BOOL *))block
{
    [self tui_enumerateComposedSequencesWithOptions:0 block:block];
}

- (void)tui_enumerateComposedSequencesWithOptions:(NSAttributedStringEnumerationOptions)options block:(void (^)(TUITextComposedSequence *, NSRange, BOOL *))block
{
    [self tui_enumerateComposedSequencesInRange:NSMakeRange(0, self.length) options:options block:block];
}

- (void)tui_enumerateComposedSequencesInRange:(NSRange)range options:(NSAttributedStringEnumerationOptions)options block:(void (^)(TUITextComposedSequence * sequence, NSRange range, BOOL * stop))block
{
    if (!block) return;
    
    NSInteger stringLength = self.length;
    
    if (range.location == NSNotFound ||
        range.location > stringLength)
    {
        return;
    }
    
    if (range.location + range.length > stringLength)
    {
        range.length = stringLength - range.location;
    }
    
    [self enumerateAttribute:TUITextComposedSequenceAttributeName inRange:range options:options usingBlock:^(id value, NSRange range, BOOL *stop) {
        if ([value isKindOfClass:[TUITextComposedSequence class]]) {
            block(value, range, stop);
        }
    }];
    
}

- (NSString *)tui_stringByReplaceTextComposedSequencesWithType:(TUITextComposedSequenceReplacementType)type
{
    NSMutableString * result = [NSMutableString stringWithString:self.string];
    
    [self tui_enumerateComposedSequencesWithOptions:NSAttributedStringEnumerationReverse block:^(TUITextComposedSequence *sequence, NSRange range, BOOL *stop) {
        NSString * replacement = [sequence replacementCharactersForType:type];
        
        if (!replacement) replacement = @"";
        
        [result replaceCharactersInRange:range withString:replacement];
    }];
    
    return result;
}

- (NSString *)tui_stringByReplaceTextComposedSequences
{
    return [self tui_stringByReplaceTextComposedSequencesWithType:TUITextComposedSequenceReplacementTypeNormal];
}
- (NSString *)tui_stringByReplaceTextComposedSequencesForCopy
{
    return [self tui_stringByReplaceTextComposedSequencesWithType:TUITextComposedSequenceReplacementTypeCopy];
}
- (NSString *)tui_stringByReplaceTextComposedSequencesForLength
{
    return [self tui_stringByReplaceTextComposedSequencesWithType:TUITextComposedSequenceReplacementTypeLength];
}

- (NSRange)tui_effectiveRangeByRoundingToComposedSequencesForRange:(NSRange)range
{
    return [self _tui_effectiveRangeByRoundingToComposedSequencesForRange:range leftDirection:0 rightDirection:0];
}

- (NSRange)tui_effectiveRangeByExtendingToComposedSequencesForRange:(NSRange)range
{
    return [self _tui_effectiveRangeByRoundingToComposedSequencesForRange:range leftDirection:-1 rightDirection:1];
}

- (NSRange)tui_effectiveRangeByTrimmingToComposedSequencesForRange:(NSRange)range
{
    return [self _tui_effectiveRangeByRoundingToComposedSequencesForRange:range leftDirection:1 rightDirection:-1];
}

- (NSRange)_tui_effectiveRangeByRoundingToComposedSequencesForRange:(NSRange)range leftDirection:(NSUInteger)leftDirection rightDirection:(NSUInteger)rightDirection
{
    if (range.length == 0) {
        return NSMakeRange([self tui_effectiveIndexByRoundingToComposedSequenceForIndex:range.location direction:0], 0);
    }
    
    NSUInteger start = range.location;
    NSUInteger end = range.location + range.length;
    
    NSRange leftSequenceRange, rightSequenceRange;
    TUITextComposedSequence * leftSequence = [self tui_composedSequenceAtIndex:start effectiveRange:&leftSequenceRange];
    TUITextComposedSequence * rightSequence = [self tui_composedSequenceAtIndex:end effectiveRange:&rightSequenceRange];
    
    if (leftSequence && leftSequence == rightSequence && NSEqualRanges(leftSequenceRange, rightSequenceRange)) {
        // range 完全被一个 sequence 包含，直接返回这个 sequence 的 range
        return leftSequenceRange;
    }
    
    if (leftSequence) {
        start = [self _tui_effectiveIndexByRoundingToComposedSequenceForIndex:start direction:leftDirection sequenceRange:leftSequenceRange];
    }
    
    if (rightSequence) {
        end = [self _tui_effectiveIndexByRoundingToComposedSequenceForIndex:end direction:rightDirection sequenceRange:rightSequenceRange];
    }
    
    return NSMakeRange(start, end - start);
}

- (NSUInteger)tui_effectiveIndexByRoundingToComposedSequenceForIndex:(NSUInteger)index
{
    return [self tui_effectiveIndexByRoundingToComposedSequenceForIndex:index direction:0];
}

/**
 *  移动一个 index，使其不会处于一个 composed sequence 中间
 *
 *  @param index     需要移动的 index
 *  @param direction 移动的方向，-1 为向左，1 为向右，0 为自动向较近的一端
 *
 *  @return 转换过的 index
 */
- (NSUInteger)tui_effectiveIndexByRoundingToComposedSequenceForIndex:(NSUInteger)index direction:(NSInteger)direction
{
    NSRange sequenceRange;
    TUITextComposedSequence * sequence = [self tui_composedSequenceAtIndex:index effectiveRange:&sequenceRange];
    
    if (sequence) {
        index = [self _tui_effectiveIndexByRoundingToComposedSequenceForIndex:index direction:direction sequenceRange:sequenceRange];
    }
    
    return index;
}

- (NSUInteger)_tui_effectiveIndexByRoundingToComposedSequenceForIndex:(NSUInteger)index direction:(NSInteger)direction sequenceRange:(NSRange)sequenceRange
{
    NSUInteger start = sequenceRange.location;
    NSUInteger end = start + sequenceRange.length;
    
    if (direction < 0) {
        index = start;
    } else if (direction > 0) {
        if (index != start) {
            index = end;
        }
    } else {
        index = (index - start) < (end - index) ? start : end;
    }
    
    return index;
}

- (NSRange)tui_plainTextRangeByRemovingComposedSequencesForComposedRange:(NSRange)composedRange
{
    return [self tui_plainTextRangeByRemovingComposedSequencesForComposedRange:composedRange replacementType:TUITextComposedSequenceReplacementTypeNormal];
}

- (NSRange)tui_plainTextRangeByRemovingComposedSequencesForComposedRange:(NSRange)composedRange replacementType:(TUITextComposedSequenceReplacementType)type
{
    composedRange = [self tui_effectiveRangeByRoundingToComposedSequencesForRange:composedRange];
    NSRange __block plainTextRange = composedRange;
    
    // range 之前的 sequence 会影响 plainTextRange 的 location
    [self tui_enumerateComposedSequencesInRange:NSMakeRange(0, composedRange.location) options:0 block:^(TUITextComposedSequence *sequence, NSRange range, BOOL *stop) {
        plainTextRange.location += ([sequence replacementCharactersForType:type].length - range.length);
    }];
    
    // range 之中的 sequence 会影响 plainTextRange 的 length
    [self tui_enumerateComposedSequencesInRange:composedRange options:0 block:^(TUITextComposedSequence *sequence, NSRange range, BOOL *stop) {
        plainTextRange.length += ([sequence replacementCharactersForType:type].length - range.length);
    }];
    
    return plainTextRange;
}

- (NSRange)tui_composedRangeByAddingComposedSequencesForPlainTextRange:(NSRange)plainTextRange
{
    return [self tui_composedRangeByAddingComposedSequencesForPlainTextRange:plainTextRange replacementType:TUITextComposedSequenceReplacementTypeNormal];
}

- (NSRange)tui_composedRangeByAddingComposedSequencesForPlainTextRange:(NSRange)plainTextRange replacementType:(TUITextComposedSequenceReplacementType)type
{
    NSRange __block composedRange = plainTextRange;
    
    [self tui_enumerateComposedSequencesWithBlock:^(TUITextComposedSequence *sequence, NSRange range, BOOL *stop) {
        
        const NSRange sequenceRange = range;
        const NSString * replacement = [sequence replacementCharactersForType:type];
        const NSUInteger replacementLength = replacement.length;
        const NSRange replacementRange = NSMakeRange(sequenceRange.location, replacementLength);
        
        if (NSMaxRange(replacementRange) <= composedRange.location) {
            
            // composedRange 之前的 sequence，影响 composedRange 的 location
            composedRange.location -= (replacementRange.length - sequenceRange.length);
            
        } else if (replacementRange.location >= NSMaxRange(composedRange)) {
            
            // composedRange 之后的 sequence，不影响 composedRange，
            // 由于是有序遍历，说明没有可以影响 composedRange 的 sequence 了
            *stop = YES;
            
        } else if (replacementRange.location >= composedRange.location && NSMaxRange(replacementRange) <= NSMaxRange(composedRange)) {
            
            // composedRange 完整包含的 sequence，影响 composedRange 的 length
            composedRange.length -= (replacementRange.length - sequenceRange.length);
            
        } else {
            
            // 否则 sequence 至少有一部分在 composedRange 外，一部分在 composedRange 里
            // 这里把 sequence 分成 3 部分：
            // left:   sequence 在 composedRange 外面左边的长度，影响 composedRange 的 location
            // inside: sequence 在 composedRange 之中的长度，影响 composedRange 的 length
            // right:  sequence 在 composedRange 外面右边的长度，不影响 composedRange
            
            NSInteger left = composedRange.location - replacementRange.location;
            left = MAX(left, 0);
            
            NSInteger right = NSMaxRange(replacementRange) - NSMaxRange(composedRange);
            right = MAX(right, 0);
            
            NSInteger inside = replacementRange.length - left - right;
            
            if (left >= 0 && right >= 0) {
                // composedRange 完全在 sequence 里面
                if (composedRange.length > 0) {
                    composedRange = sequenceRange;
                } else {
                    composedRange = NSMakeRange(NSMaxRange(sequenceRange), 0);
                }
            } else if (left > 0) {
                // composedRange 左边缘和 sequence 重合，则将左边缘移到 sequence 右边即可
                composedRange.location = NSMaxRange(sequenceRange);
                composedRange.length -= inside;
            } else {
                NSAssert(right > 0, @"right must not 0 at this point");
                // composedRange 右边缘和 sequence 重合，则将右边缘移到 sequence 右边即可
                composedRange.length += right;
            }
        }
    }];
    
    return composedRange;
}

@end

@implementation NSMutableAttributedString (TUITextComposedSequence)

- (void)tui_setComposedSequence:(TUITextComposedSequence *)sequence forRange:(NSRange)range
{
    NSInteger stringLength = self.length;
    
    if (range.location == NSNotFound ||
        range.location > stringLength)
    {
        range.location = 0;
    }
    
    if (range.location + range.length > stringLength)
    {
        range.length = stringLength - range.location;
    }
    
    if (sequence) {
        [self addAttribute:TUITextComposedSequenceAttributeName value:sequence range:range];
    } else {
        [self removeAttribute:TUITextComposedSequenceAttributeName range:range];
    }
}

@end

@implementation TUITextComposedSequence (Editing)

- (void)setConfirmsDeleteOperation:(BOOL)confirmsDeleteOperation
{
    _flags.confirmsDeleteOperation = confirmsDeleteOperation;
}

- (BOOL)confirmsDeleteOperation
{
    return _flags.confirmsDeleteOperation;
}

@end
