//
//  TUIVisualEffectView.h
//  TwUI
//
//  Created by 吴天 on 16/2/12.
//
//

#import "TUIView.h"

typedef NS_ENUM(NSInteger, TUIVisualEffectMaterial) {
    TUIVisualEffectMaterialLight = 0,
    TUIVisualEffectMaterialDark,
    TUIVisualEffectMaterialTitleBar
};

typedef NS_ENUM(NSInteger, TUIVisualEffectBlendingMode) {
    TUIVisualEffectBlendingModeBehindWindow,
    TUIVisualEffectBlendingModeWithinWindow
};

typedef NS_ENUM(NSInteger, TUIVisualEffectState) {
    TUIVisualEffectStateFollowsWindowActiveState,
    TUIVisualEffectStateActive,
    TUIVisualEffectStateInactive
};

@interface TUIVisualEffectView : TUIView

@property (nonatomic) TUIVisualEffectMaterial material;
@property (nonatomic) TUIVisualEffectBlendingMode blendingMode;
@property (nonatomic) TUIVisualEffectState state;

@end
