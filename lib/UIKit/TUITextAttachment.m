//
//  TUITextAttachment.m
//  TwUI
//
//  Created by Wutian on 14-3-23.
//
//

#import "TUITextAttachment.h"

@implementation TUITextAttachment

- (CGFloat)ascentForLayout
{
    return _fontAscent;
}

- (CGFloat)descentForLayout
{
    return _fontDescent;
}

@end

static void tui_embeddedObjectDeallocCallback(void *context)
{
    
}

static CGFloat tui_embeddedObjectGetAscentCallback(void *context)
{
	if ([(__bridge id)context isKindOfClass:[TUITextAttachment class]])
	{
		return [(__bridge TUITextAttachment *)context ascentForLayout];
	}
	return 20;
}
static CGFloat tui_embeddedObjectGetDescentCallback(void *context)
{
	if ([(__bridge id)context isKindOfClass:[TUITextAttachment class]])
	{
		return [(__bridge TUITextAttachment *)context descentForLayout];
	}
	return 4;
}

static CGFloat tui_embeddedObjectGetWidthCallback(void * context)
{
	if ([(__bridge id)context isKindOfClass:[TUITextAttachment class]])
	{
		return [(__bridge TUITextAttachment *)context placeholderSize].width;
	}
	return 22;
}

CTRunDelegateRef TUICreateEmbeddedObjectRunDelegate(TUITextAttachment * attachment)
{
    CTRunDelegateCallbacks callbacks;
	callbacks.version = kCTRunDelegateCurrentVersion;
	callbacks.dealloc = tui_embeddedObjectDeallocCallback;
	callbacks.getAscent = tui_embeddedObjectGetAscentCallback;
	callbacks.getDescent = tui_embeddedObjectGetDescentCallback;
	callbacks.getWidth = tui_embeddedObjectGetWidthCallback;
	return CTRunDelegateCreate(&callbacks, (void *)attachment);
}