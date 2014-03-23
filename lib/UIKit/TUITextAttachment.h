//
//  TUITextAttachment.h
//  TwUI
//
//  Created by Wutian on 14-3-23.
//
//

#import <Foundation/Foundation.h>

@interface TUITextAttachment : NSObject

@property (nonatomic, assign) CGSize contentSize;
@property (nonatomic, assign) CGSize placeholderSize;
@property (nonatomic, strong) id contents;
@property (nonatomic, assign) CGFloat fontLeading;
@property (nonatomic, assign) CGFloat fontAscent;
@property (nonatomic, assign) CGFloat fontDescent;

@property (nonatomic, assign) NSInteger tag;

@property (nonatomic, assign) CGRect derivedFrame;

- (CGFloat)ascentForLayout;
- (CGFloat)descentForLayout;

@end

extern CTRunDelegateRef TUICreateEmbeddedObjectRunDelegate(TUITextAttachment * attachment);
