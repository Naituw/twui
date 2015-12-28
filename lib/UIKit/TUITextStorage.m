//
//  TUITextStorage.m
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import "TUITextStorage.h"

@interface TUITextStorage ()
{
    CFMutableAttributedStringRef _attributedString;
    
    struct {
        unsigned int didProcessEditing:1;
    } _delegateHas;
}

@end

@implementation TUITextStorage

- (void)dealloc
{
    if (_attributedString)
    {
        CFRelease(_attributedString), _attributedString = NULL;
    }
}

- (id)init
{
    if (self = [super init])
    {
        _attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    }
    return self;
}

- (void)setDelegate:(id<TUITextStorageDelegate>)delegate
{
    if (_delegate != delegate)
    {
        _delegate = delegate;
        
        _delegateHas.didProcessEditing = [delegate respondsToSelector:@selector(tui_textStorage:didProcessEditing:range:changeInLength:)];
    }
}

- (NSString *)string
{
    if (!_attributedString) return nil;
    
    return (NSString *)CFAttributedStringGetString(_attributedString);
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    if (!_attributedString) return nil;
    
    if (location >= self.length) return nil;
    
    CFRange cfRange = CFRangeMake(0, 0);
    
    NSDictionary * attrs = (NSDictionary *)CFAttributedStringGetAttributes(_attributedString, location, &cfRange);
    
    if (range)
    {
        (*range).location = cfRange.location;
        (*range).length = cfRange.length;
    }
    
    return attrs;
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    if (range.location == self.length && range.length == 0)
    {
        range = range;
    }
    else
    {
        range = NSIntersectionRange(range, NSMakeRange(0, self.length));
    }
    
    CFAttributedStringReplaceString(_attributedString, CFRangeMake(range.location, range.length), (CFStringRef)str);
    
    if (_delegateHas.didProcessEditing)
    {
        [_delegate tui_textStorage:self didProcessEditing:TUITextStorageEditedCharacters range:range changeInLength:(str.length - range.length)];
    }
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    range = NSIntersectionRange(range, NSMakeRange(0, self.length));
    
    CFAttributedStringSetAttributes(_attributedString, CFRangeMake(range.location, range.length), (CFDictionaryRef)attrs, true);
    
    if (_delegateHas.didProcessEditing)
    {
        [_delegate tui_textStorage:self didProcessEditing:TUITextStorageEditedAttributes range:range changeInLength:0];
    }
}

@end
