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
    TUIVisualEffectMaterialUltraDark,
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
@property (nonatomic) TUIVisualEffectBlendingMode materialBlendingMode;
@property (nonatomic) TUIVisualEffectState state;

@property (nonatomic, strong) TUIColor * tintColor;
@property (nonatomic) TUIViewBlendingMode tintBlendingMode;

@property (nonatomic, strong) TUIColor * activeBackdropBackgroundColor;
@property (nonatomic, strong) TUIColor * inactiveBackdropBackgroundColor;

@end
