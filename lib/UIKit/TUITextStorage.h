//
//  TUITextStorage.h
//  TwUI
//
//  Created by 吴天 on 15/12/28.
//
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, TUITextStorageEditActions)
{
    TUITextStorageEditedAttributes = (1 << 0),
    TUITextStorageEditedCharacters = (1 << 1),
};

@protocol TUITextStorageDelegate;

@interface TUITextStorage : NSMutableAttributedString

@property (nonatomic, weak) id<TUITextStorageDelegate> delegate;

@end

@protocol TUITextStorageDelegate <NSObject>

- (void)tui_textStorage:(TUITextStorage *)textStorage didProcessEditing:(TUITextStorageEditActions)editActions range:(NSRange)editedRange changeInLength:(NSInteger)delta;

@end

